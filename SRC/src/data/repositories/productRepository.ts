/**
 * Product Repository
 * WO-002 T2.2: Implementing repository pattern for Products
 * WO-FE-006: Implementing Mapper Layer for Schema v2 Compatibility
 * 
 * Uses SupabaseAdapter to provide data access for Products
 * Handles fallback to localStorage automatically via adapter
 * 
 * @module data/repositories/productRepository
 */

import { Product } from '../../types';
import { Database } from '../../types/database.types';
import { Decimal } from 'decimal.js';
import { createSupabaseRepository, EntityRepository, RepositoryMappers } from './supabaseAdapter';
import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { logger } from '../../utils/logger';

// Constants
const TABLE_NAME = 'products';
const STORAGE_KEY = 'tienda-inventory'; // Legacy key for compatibility

// Type Alias for DB Row
type ProductDB = Database['public']['Tables']['products']['Row'];

/**
 * Mapper Implementation for Product
 * Enforces:
 * 1. Decimal (Domain) <-> number (DB)
 * 2. stock (Domain) <-> current_stock (DB)
 * 3. category (string) <-> category_id (UUID/null)
 */
export const productMapper: RepositoryMappers<ProductDB, Product> = {
    toDomain: (row: ProductDB): Product => {
        return {
            id: row.id,
            name: row.name,
            price: new Decimal(row.price),
            // Map current_stock (DB) to stock (Domain)
            stock: new Decimal(row.current_stock),
            measurementUnit: row.measurement_unit as any, // Cast specific enum if needed
            // Handle Category: DB has UUID or null. Domain expects string.
            // If DB has ID, we can't easily turn it into a name here without a join or cache.
            // For now, we leave it undefined or empty string if it acts as a label.
            // As per ADR: "Ignorar/nulear category_id para evitar crash".
            category: undefined,
            brand: undefined, // Not in DB schema v2 currently?
            minStock: row.min_stock,
            cost: row.cost_price ? new Decimal(row.cost_price) : undefined,
            // Extra fields
            isWeighable: row.measurement_unit !== 'un', // Simple heuristic or add DB field?
            createdAt: row.created_at,
            updatedAt: row.updated_at,
            storeId: row.store_id,
            notifiedLowStock: row.low_stock_alerted || false
        };
    },
    toPersistence: (entity: Product): ProductDB => {
        return {
            id: entity.id,
            name: entity.name,
            price: entity.price.toNumber(),
            // Map stock (Domain) to current_stock (DB)
            current_stock: entity.stock.toNumber(),
            measurement_unit: entity.measurementUnit,
            // ADR: Force null for category_id to avoid "invalid input syntax for type uuid"
            category_id: null,
            min_stock: entity.minStock,
            cost_price: entity.cost ? entity.cost.toNumber() : null,
            created_at: entity.createdAt || new Date().toISOString(),
            updated_at: new Date().toISOString(),
            store_id: entity.storeId || '', // Should ensure this is set
            // Fields with defaults or potential mappings
            barcode: entity.plu || null,
            description: null,
            image_url: null,
            is_active: true,
            low_stock_alerted: entity.notifiedLowStock || false,
            tax_rate: 0 // Default for now
        };
    }
};

/**
 * Interface extending base repository with product-specific methods
 */
interface InventoryMovementHistory {
    id: string;
    type: string;
    quantity: number;
    reason?: string;
    date: string;
    user: string;
}

/**
 * Interface extending base repository with product-specific methods
 */
export interface ProductRepository extends EntityRepository<Product> {
    getByPlu(plu: string, storeId?: string): Promise<Product | null>;
    searchByName(query: string, storeId?: string): Promise<Product[]>;
    updateStock(id: string, quantity: number): Promise<boolean>;
    registerMovement(movement: {
        productId: string;
        type: 'entrada' | 'salida' | 'ajuste' | 'venta' | 'devolucion';
        quantity: number;
        reason?: string;
        storeId?: string;
        employeeId?: string;
    }): Promise<boolean>;
    getMovementHistory(productId: string, limit?: number): Promise<InventoryMovementHistory[]>;
}

// Create base repository with Mappers
// Generics: <TDomain, TPersistence>
const baseRepository = createSupabaseRepository<Product, ProductDB>(
    TABLE_NAME,
    STORAGE_KEY,
    productMapper
);

/**
 * Extended Product Repository implementation
 */
export const productRepository: ProductRepository = {
    ...baseRepository,

    /**
     * Get product by PLU
     */
    async getByPlu(plu: string, storeId?: string): Promise<Product | null> {
        // Since we are using mappers, getAll returns Product[] (Domain objects)
        const all = await baseRepository.getAll(storeId);
        return all.find(p => p.plu === plu) || null;
    },

    /**
     * Search products by name (case insensitive)
     */
    async searchByName(query: string, storeId?: string): Promise<Product[]> {
        const all = await baseRepository.getAll(storeId);
        const lowerQuery = query.toLowerCase();
        return all.filter(p => p.name.toLowerCase().includes(lowerQuery));
    },

    /**
     * Update product stock
     * Note: logic should usually be handled by inventory movements, 
     * this is a direct update method for corrections
     */
    async updateStock(id: string, quantity: number): Promise<boolean> {
        const product = await baseRepository.getById(id);
        if (!product) return false;

        // Repository 'update' takes Partial<Product>. Adapter handles mapping to persistence.
        const updated = await baseRepository.update(id, {
            stock: new Decimal(quantity)
        } as Partial<Product>);

        return updated !== null;
    },

    /**
     * Get movement history (Kardex)
     */
    async getMovementHistory(productId: string, limit: number = 50): Promise<any[]> {
        // Online first strategy for history
        const isOnline = isSupabaseConfigured() && navigator.onLine;
        let remoteHistory: any[] = [];

        if (isOnline) {
            const supabase = getSupabaseClient();
            if (supabase) {
                const { data, error } = await supabase
                    .from('inventory_movements')
                    .select('*, employees(name)')
                    .eq('product_id', productId)
                    .order('created_at', { ascending: false })
                    .limit(limit);

                if (!error && data) {
                    remoteHistory = data.map((m: any): InventoryMovementHistory => ({
                        id: m.id,
                        type: m.movement_type,
                        quantity: m.quantity,
                        reason: m.reason,
                        date: m.created_at,
                        user: m.employees?.name || 'Sistema'
                    }));
                } else {
                    logger.error('[ProductRepo] Failed to fetch history', error);
                }
            }
        }

        // Fetch Local Pending Movements (Offline / Audit Mode)
        try {
            const { getPendingMovements } = await import('../syncQueue');
            const pending = await getPendingMovements(productId);

            // Transform pending to match InventoryMovementHistory if not already
            const formattedPending = pending.map(p => ({
                id: p.id,
                type: p.movement_type,
                quantity: p.quantity,
                reason: p.reason,
                date: p.created_at,
                user: p.employees?.name || 'Pendiente'
            }));

            // Merge: Pending first (newest), then Remote
            return [...formattedPending, ...remoteHistory];

        } catch (e) {
            logger.warn('[ProductRepo] Failed to load local history', e);
            return remoteHistory;
        }
    },

    /**
     * Register an inventory movement (Entrada, Salida, Ajuste)
     */
    async registerMovement(
        movement: {
            productId: string;
            type: 'entrada' | 'salida' | 'ajuste' | 'venta' | 'devolucion';
            quantity: number;
            reason?: string;
            storeId?: string;
            employeeId?: string;
        }
    ): Promise<boolean> {
        const isOnline = isSupabaseConfigured() && navigator.onLine;

        // 1. Online: Insert into inventory_movements (Trigger updates stock)
        if (isOnline) {
            const supabase = getSupabaseClient();
            if (supabase) {
                const { error } = await supabase.from('inventory_movements').insert({
                    product_id: movement.productId,
                    movement_type: movement.type,
                    quantity: movement.quantity,
                    reason: movement.reason,
                    created_by: movement.employeeId
                });

                if (!error) return true;
                logger.error('[ProductRepo] Failed to register movement online', error);
                // Fallback to offline if online fails? Maybe.
            }
        }

        // 2. Offline / Fallback: Add to Sync Queue AND Update Local Product
        try {
            // Import addToSyncQueue dynamically to avoid circular deps if any (though here it's fine)
            const { addToSyncQueue } = await import('../syncQueue');

            // Queue movement
            await addToSyncQueue('CREATE_MOVEMENT', {
                product_id: movement.productId,
                movement_type: movement.type,
                quantity: movement.quantity,
                reason: movement.reason,
                created_by: movement.employeeId
            });

            // Update local product stock manually since trigger won't run
            const product = await baseRepository.getById(movement.productId);
            if (product) {
                // Ensure Decimal using Domain type
                const currentStock = new Decimal(product.stock);
                let newStock = currentStock.toNumber();

                // Logic must match DB trigger
                if (['entrada', 'devolucion', 'ajuste'].includes(movement.type)) {
                    // For 'ajuste', DB trigger adds quantity (assuming quantity is delta or signed?)
                    newStock += movement.quantity;
                } else if (['salida', 'venta'].includes(movement.type)) {
                    newStock -= movement.quantity;
                }

                // Update using Domain Object Partial (Adapter maps to Persistence)
                await baseRepository.update(product.id, {
                    stock: new Decimal(newStock)
                } as Partial<Product>);
            }

            return true;
        } catch (e) {
            logger.error('[ProductRepo] Exception in registerMovement fallback', e);
            throw e; // Re-throw to let caller know
        }
    }
};

export default productRepository;

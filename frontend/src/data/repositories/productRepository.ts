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
 * Measurement Unit Translation
 * Frontend uses short codes, DB uses full names
 */
const MEASUREMENT_UNIT_TO_DB: Record<string, string> = {
    'un': 'unidad',
    'kg': 'kg',
    'lb': 'lb',
    'g': 'g'
};

const MEASUREMENT_UNIT_FROM_DB: Record<string, string> = {
    'unidad': 'un',
    'kg': 'kg',
    'lb': 'lb',
    'g': 'g'
};

/**
 * Translate measurementUnit from Frontend to DB format
 */
function translateMeasurementUnitToDB(unit: string): string {
    return MEASUREMENT_UNIT_TO_DB[unit] || unit;
}

/**
 * Translate measurementUnit from DB to Frontend format
 */
function translateMeasurementUnitFromDB(unit: string): string {
    return MEASUREMENT_UNIT_FROM_DB[unit] || unit;
}

/**
 * ProductMapper: Bidirectional transformer
 * CRITICAL: Does NOT allow empty/invalid storeId
 * 
 * Field Mapping:
 * 1. price (Decimal) <-> price (numeric)
 * 2. stock (Domain) <-> current_stock (DB)
 * 3. cost (Domain) <-> cost_price (DB)
 * 4. measurementUnit ('un') <-> measurement_unit ('unidad')
 */
export const productMapper: RepositoryMappers<ProductDB, Product> = {
    toDomain: (row: ProductDB): Product => {
        return {
            id: row.id,
            name: row.name,
            plu: row.plu || undefined, // CRITICAL: Map PLU for POS search functionality
            price: new Decimal(row.price),
            // Map current_stock (DB) to stock (Domain)
            stock: new Decimal(row.current_stock),
            // Translate DB unit to Frontend unit
            measurementUnit: translateMeasurementUnitFromDB(row.measurement_unit) as any, // Cast specific enum if needed
            // Handle Category: Now properly mapped to text column
            category: row.category || undefined,
            brand: row.brand || undefined,
            minStock: row.min_stock,
            // Map cost_price (DB) to cost (Domain)
            cost: row.cost_price ? new Decimal(row.cost_price) : undefined,
            // Extra fields
            isWeighable: row.is_weighable ?? (row.measurement_unit !== 'unidad'),
            createdAt: row.created_at,
            updatedAt: row.updated_at,
            storeId: row.store_id,
            // Map low_stock_alerted (DB) to notifiedLowStock (Domain)
            notifiedLowStock: row.low_stock_alerted || false
        };
    },
    toPersistence: (entity: Product): ProductDB => {
        // ===== VALIDATION CHECKPOINT =====
        // This is the "aduana" - block dirty data before it reaches persistence

        if (!entity.storeId || entity.storeId.trim() === '') {
            // Assuming RLSViolationError and ValidationError are defined elsewhere
            const error = new Error('Cannot persist Product without valid storeId. This would fail RLS policies.');
            logger.error('[ProductRepo] RLSViolationError:', error.message);
            throw error;
        }

        // Validate UUID format (basic check)
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        if (!uuidRegex.test(entity.storeId)) {
            const error = new Error(`Invalid UUID format for storeId: "${entity.storeId}"`);
            logger.error('[ProductRepo] ValidationError:', error.message);
            throw error;
        }

        return {
            id: entity.id,
            name: entity.name,
            price: entity.price.toNumber(),
            // Map stock (Domain) to current_stock (DB)
            current_stock: entity.stock.toNumber(),
            // Translate Frontend unit to DB unit
            measurement_unit: translateMeasurementUnitToDB(entity.measurementUnit),
            // Correct mapping for Schema V2 (Text category)
            category: entity.category || null,
            brand: entity.brand || null,
            min_stock: entity.minStock,
            // Map cost (Domain) to cost_price (DB)
            cost_price: entity.cost ? entity.cost.toNumber() : null,
            created_at: entity.createdAt || new Date().toISOString(),
            updated_at: new Date().toISOString(),
            // NO FALLBACK - storeId is validated above
            store_id: entity.storeId,
            // Fields with defaults or potential mappings
            plu: entity.plu || null,
            is_weighable: entity.isWeighable || false,
            // Map notifiedLowStock (Domain) to low_stock_alerted (DB)
            low_stock_alerted: entity.notifiedLowStock || false,
            // Supplier FK - preserve existing value
            supplier_id: entity.supplierId || null
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
        supplierId?: string;
        invoiceRef?: string;
        paymentType?: 'contado' | 'credito';
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
            supplierId?: string;
            invoiceRef?: string;
            paymentType?: 'contado' | 'credito';
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
                    created_by: movement.employeeId,
                    supplier_id: movement.supplierId || null,
                    invoice_reference: movement.invoiceRef || null,
                    payment_type: movement.paymentType || null
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
                created_by: movement.employeeId,
                supplier_id: movement.supplierId || null,
                invoice_reference: movement.invoiceRef || null,
                payment_type: movement.paymentType || null
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

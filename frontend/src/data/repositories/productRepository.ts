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
import { createIndexedDBDataSource } from '../sources/IndexedDBDataSource';
import type { LocalDataSource } from '../interfaces/DataSource';

// IDB Cache Layer — replaces localStorage for product data
const productCache: LocalDataSource<Product> = createIndexedDBDataSource<Product>('products');

// Constants
const TABLE_NAME = 'products';
const STORAGE_KEY = 'tienda-inventory'; // Legacy key for compatibility

// Type Alias for DB Row
type ProductDB = Database['public']['Tables']['products']['Row'];

// Measurement Units: DB uses 'unidad', Frontend domain uses 'un'
// Translation happens in mapper (toDomain/toPersistence) — QA-FIX-001

/**
 * ProductMapper: Bidirectional transformer
 * CRITICAL: Does NOT allow empty/invalid storeId
 * 
 * Field Mapping:
 * 1. price (Decimal) <-> price (numeric)
 * 2. stock (Domain) <-> current_stock (DB)
 * 3. cost (Domain) <-> cost_price (DB)
 * 4. measurementUnit ('un') <-> measurement_unit ('unidad') [translated in mapper]
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
            // QA-FIX-001: Translate DB 'unidad' -> Domain 'un'
            measurementUnit: (row.measurement_unit === 'unidad' ? 'un' : (row.measurement_unit || 'un')) as Product['measurementUnit'],
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
            // QA-FIX-001: Translate Domain 'un' -> DB 'unidad'
            measurement_unit: entity.measurementUnit === 'un' ? 'unidad' : entity.measurementUnit,
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
     * Get all products — Network-First Strategy
     * QA-FIX-006: Changed from Cache-Ahead to Network-First
     * 1. ONLINE: Fetch from Supabase (source of truth), update IDB cache
     * 2. OFFLINE: Return from IDB cache (or legacy localStorage fallback)
     */
    async getAll(storeId?: string): Promise<Product[]> {
        // 1. ONLINE: Always fetch fresh from Supabase
        if (navigator.onLine && isSupabaseConfigured()) {
            try {
                const fresh = await baseRepository.getAll(storeId);
                if (fresh.length > 0) {
                    // Update IDB cache with fresh data
                    productCache.saveBulk(fresh).catch(e =>
                        logger.warn('[ProductRepo] IDB cache update failed:', e)
                    );
                }
                return fresh;
            } catch (e) {
                logger.warn('[ProductRepo] Supabase fetch failed, falling back to cache', e);
                // Fall through to IDB cache on network error
            }
        }

        // 2. OFFLINE or network error: Try IDB cache
        const cached = await productCache.getAll();
        if (cached.length > 0) {
            return cached;
        }

        // 3. Last resort: legacy localStorage fallback via baseRepository
        return baseRepository.getAll(storeId);
    },

    /**
     * Get product by ID — IDB first, then Supabase
     */
    async getById(id: string): Promise<Product | null> {
        // 1. Check IDB
        const cached = await productCache.getById(id);
        if (cached) return cached;

        // 2. Fall through to Supabase/localStorage
        return baseRepository.getById(id);
    },

    /**
     * Get product by PLU — Uses IDB index for O(1) lookup
     */
    async getByPlu(plu: string, storeId?: string): Promise<Product | null> {
        // 1. Fast indexed lookup in IDB
        const results = await productCache.getByIndex('by_plu', plu);
        if (results.length > 0) return results[0];

        // 2. Fallback: full scan (legacy path)
        const all = await this.getAll(storeId);
        return all.find(p => p.plu === plu) || null;
    },

    /**
     * Search products by name (case insensitive)
     */
    async searchByName(query: string, storeId?: string): Promise<Product[]> {
        const all = await this.getAll(storeId);
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

        // FRD-012 Línea 24: "Operaciones offline: Solo ventas POS"
        // Movimientos de inventario REQUIEREN conexión activa.
        if (!isOnline) {
            logger.error('[ProductRepo] ❌ OFFLINE_NOT_ALLOWED: Inventory movements require active connection (FRD-012)');
            throw new Error('OFFLINE_NOT_ALLOWED: Los movimientos de inventario requieren conexión a internet.');
        }

        // Online: Insert into inventory_movements (Trigger updates stock)
        const supabase = getSupabaseClient();
        if (!supabase) {
            throw new Error('Supabase client not available');
        }

        const { error } = await supabase.from('inventory_movements').insert({
            product_id: movement.productId,
            movement_type: movement.type,
            quantity: movement.quantity,
            reason: movement.reason,
            created_by: movement.employeeId || null,
            supplier_id: movement.supplierId || null,
            invoice_reference: movement.invoiceRef || null,
            payment_type: movement.paymentType || null
        });

        if (error) {
            logger.error('[ProductRepo] Failed to register movement', error);
            throw error;
        }

        return true;
    }
};

export default productRepository;

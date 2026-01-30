/**
 * Product Repository
 * WO-002 T2.2: Implementing repository pattern for Products
 * 
 * Uses SupabaseAdapter to provide data access for Products
 * Handles fallback to localStorage automatically via adapter
 * 
 * @module data/repositories/productRepository
 */

import { Product } from '../../types';
import { Decimal } from 'decimal.js';
import { createSupabaseRepository, EntityRepository } from './supabaseAdapter';
import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { logger } from '../../utils/logger';

// Constants
const TABLE_NAME = 'products';
const STORAGE_KEY = 'tienda-inventory'; // Legacy key for compatibility

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

// Create base repository
const baseRepository = createSupabaseRepository<Product>(TABLE_NAME, STORAGE_KEY);

/**
 * Extended Product Repository implementation
 */
export const productRepository: ProductRepository = {
    ...baseRepository,

    /**
     * Get product by PLU
     */
    async getByPlu(plu: string, storeId?: string): Promise<Product | null> {
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

        const updated = await baseRepository.update(id, {
            stock: new Decimal(quantity) // Ensure Decimal if entity uses it, or number if mapped
        } as Partial<Product>);

        return updated !== null;
    },

    /**
     * Get movement history (Kardex)
     */
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
        // Import dynamically to avoid circular dependencies if any
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
            // Note: Pending are already sorted desc by timestamp
            // Also deduplicate if needed (though IDs should differ)
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
                // WARN: product.stock might be a number (raw JSON) or Decimal depending on hydration
                const currentStock = new Decimal(product.stock);
                let newStock = currentStock.toNumber();
                // Logic must match DB trigger
                if (['entrada', 'devolucion', 'ajuste'].includes(movement.type)) {
                    // For 'ajuste', DB trigger adds quantity (assuming quantity is delta or signed?)
                    // DB trigger says: ELSIF NEW.movement_type = 'ajuste' THEN UPDATE SET current_stock = current_stock + NEW.quantity
                    // So 'ajuste' quantity should be signed (negative for reduction).
                    // But my UI might pass absolute. I need to be careful.
                    // Re-reading trigger: 'ajuste' adds quantity. So if I want to reduce, I pass negative.
                    newStock += movement.quantity;
                } else if (['salida', 'venta'].includes(movement.type)) {
                    newStock -= movement.quantity;
                }

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

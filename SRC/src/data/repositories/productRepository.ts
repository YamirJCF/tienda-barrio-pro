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
import { createSupabaseRepository, EntityRepository } from './supabaseAdapter';
import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { logger } from '../../utils/logger';

// Constants
const TABLE_NAME = 'products';
const STORAGE_KEY = 'tienda-inventory'; // Legacy key for compatibility

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
    getMovementHistory(productId: string, limit?: number): Promise<any[]>;
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
            stock: quantity // Changed from currentStock to stock to match type
        } as any);

        return updated !== null;
    },

    /**
     * Get movement history (Kardex)
     */
    async getMovementHistory(productId: string, limit: number = 50): Promise<any[]> {
        const isOnline = isSupabaseConfigured() && navigator.onLine;

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
                    return data.map(m => ({
                        id: m.id,
                        type: m.movement_type,
                        quantity: m.quantity,
                        reason: m.reason,
                        date: m.created_at,
                        user: m.employees?.name || 'Sistema'
                    }));
                }
                logger.error('[ProductRepo] Failed to fetch history', error);
            }
        }

        return [];
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
            let newStock = product.stock.toNumber(); // Decimal to number
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
                stock: newStock
            } as any);
        }

        return true;
    }
};

export default productRepository;

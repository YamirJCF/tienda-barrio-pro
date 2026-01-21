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
            currentStock: quantity // Map to DB column logic handled in adapter/store
        } as any);

        return updated !== null;
    }
};

export default productRepository;

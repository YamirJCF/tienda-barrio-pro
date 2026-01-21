/**
 * Sale Repository
 * WO-002 T2.2: Implementing repository pattern for Sales
 * 
 * Uses SupabaseAdapter to provide data access for Sales
 * Favor RPC `procesar_venta` for atomic creation
 * 
 * @module data/repositories/saleRepository
 */

import { Sale } from '../../types';
import { createSupabaseRepository, EntityRepository } from './supabaseAdapter';
import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { logger } from '../../utils/logger';

// Constants
const TABLE_NAME = 'sales';
const STORAGE_KEY = 'tienda-sales';

/**
 * Interface extending base repository with sale-specific methods
 */
export interface SaleRepository extends EntityRepository<Sale> {
    processSale(saleData: any, storeId: string): Promise<{ success: boolean; id?: string; error?: string }>;
    getByDateRange(startDate: string, endDate: string, storeId?: string): Promise<Sale[]>;
}

// Create base repository
const baseRepository = createSupabaseRepository<Sale>(TABLE_NAME, STORAGE_KEY);

/**
 * Extended Sale Repository implementation
 */
export const saleRepository: SaleRepository = {
    ...baseRepository,

    /**
     * Process a new sale (Atomic Transaction)
     * Uses RPC 'procesar_venta' if online, fallback to localStorage if offline
     */
    async processSale(saleData: any, storeId: string): Promise<{ success: boolean; id?: string; error?: string }> {
        // 1. Check if we can use Supabase RPC
        if (isSupabaseConfigured()) {
            const supabase = getSupabaseClient();
            if (supabase) {
                try {
                    const { data, error } = await supabase.rpc('procesar_venta', {
                        p_store_id: storeId,
                        p_items: saleData.items,
                        p_payment_method: saleData.paymentMethod,
                        p_amount_received: saleData.amountReceived,
                        p_client_id: saleData.clientId,
                        p_employee_id: saleData.employeeId
                    });

                    if (error) {
                        logger.error('[SaleRepo] RPC error:', error);
                        // Don't fallback automatically for server errors to avoid double billing risks
                        // unless connection error is explicit. For now, return error.
                        return { success: false, error: error.message };
                    }

                    if (data && data.success) {
                        // Fetch the full object locally to match return type if needed, 
                        // but usually ID is enough.
                        return { success: true, id: data.id };
                    } else {
                        return { success: false, error: data?.error || 'Unknown RPC error' };
                    }

                } catch (e) {
                    logger.error('[SaleRepo] RPC exception:', e);
                    // Network errors -> Fallback to localStorage
                }
            }
        }

        // 2. Fallback: LocalStorage (Offline Mode)
        // This is essentially "Optimistic UI" for the store perspective
        try {
            // Generate ID
            const newId = crypto.randomUUID();
            const newSale = {
                ...saleData,
                id: newId,
                syncStatus: 'pending' // Mark for synchronization (WO-003)
            };

            const existing = await baseRepository.getAll(storeId);
            existing.push(newSale); // Adapter handles writing to localStorage via `set`

            // Need direct access to adapter to specific key? 
            // Actually baseRepository.create does this but without the complex logic.
            // Let's use baseRepository.create but we need to pass the full object with ID mapping

            // Since baseRepository methods are tailored for simple CRUD, 
            // for complex transaction fallback we might need custom logic or just trust creating the header.
            // Ideally WO-003 will handle the robust SyncQueue.
            // For now, simple create:
            await baseRepository.create(newSale);

            return { success: true, id: newId };
        } catch (e) {
            return { success: false, error: 'Offline save failed' };
        }
    },

    /**
     * Get sales by date range
     */
    async getByDateRange(startDate: string, endDate: string, storeId?: string): Promise<Sale[]> {
        const all = await baseRepository.getAll(storeId);
        return all.filter(s => {
            // Basic date string comparison assuming YYYY-MM-DD format or ISO
            return s.date >= startDate && s.date <= endDate;
        });
    }
};

export default saleRepository;

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
import { addToSyncQueue } from '../syncQueue';

// Constants
const TABLE_NAME = 'sales';
const STORAGE_KEY = 'tienda-sales';

/**
 * Interface extending base repository with sale-specific methods
 */
interface SalePayload {
    items: {
        productId: string;
        productName: string;
        quantity: number;
        price: any; // Decimal or number
        subtotal: any; // Decimal or number
    }[];
    total: any; // Decimal or number
    paymentMethod: 'cash' | 'nequi' | 'fiado' | 'mixed';
    payments?: { method: 'cash' | 'nequi' | 'fiado', amount: number, reference?: string }[];
    amountReceived?: any; // Decimal or number
    clientId?: string;
    employeeId?: string;
}

export interface SaleRepository extends EntityRepository<Sale> {
    processSale(saleData: SalePayload, storeId: string): Promise<{ success: boolean; id?: string; error?: string }>;
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
     * Uses RPC 'procesar_venta' if online, fallback to Sync Queue if offline
     */
    async processSale(saleData: SalePayload, storeId: string): Promise<{ success: boolean; id?: string; error?: string }> {
        const isOnline = navigator.onLine && isSupabaseConfigured();

        // 1. Try Online (RPC)
        if (isOnline) {
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
                        // If network error, fall through to offline handling
                        // Supabase network errors often don't throw but return error object with message
                        if (error.message && (error.message.includes('FetchError') || error.message.includes('Network request failed'))) {
                            // Fallthrough
                        } else {
                            return { success: false, error: error.message };
                        }
                    } else {
                        if (data && data.success) {
                            return { success: true, id: data.id };
                        } else {
                            return { success: false, error: data?.error || 'Unknown RPC error' };
                        }
                    }

                } catch (e) {
                    logger.error('[SaleRepo] RPC exception:', e);
                    // Fallthrough to offline
                }
            }
        }

        // 2. Offline Mode (Sync Queue)
        // Add to IndexedDB queue for later processing
        try {
            // Generate ID client-side for UI consistency
            const newId = crypto.randomUUID();
            const enrichedPayload = { ...saleData, storeId, id: newId };

            const queued = await addToSyncQueue('CREATE_SALE', enrichedPayload);

            if (queued) {
                return { success: true, id: newId };
                // Note: UI should treating this as "Pending Sync"
            } else {
                return { success: false, error: 'Queue full or storage error' };
            }

        } catch (e: any) {
            return { success: false, error: e.message || 'Offline save failed' };
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

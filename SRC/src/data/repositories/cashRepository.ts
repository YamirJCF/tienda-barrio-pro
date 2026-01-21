/**
 * Cash Repository
 * WO-003 T3.1: Cash Control Repository
 * 
 * Handles interaction with 'cash_control_events' and 'cash_register'
 * Primarily uses RPC `registrar_evento_caja` for atomic operations
 *
 * @module data/repositories/cashRepository
 */

import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { logger } from '../../utils/logger';
import { addToSyncQueue } from '../syncQueue';

export interface CashControlEvent {
    id?: string;
    store_id: string;
    type: 'open' | 'close';
    amount_declared: number;
    amount_expected?: number;
    difference?: number;
    authorized_by_id?: string;
    authorized_by_name: string;
    authorized_by_type: 'admin' | 'employee';
    created_at?: string;
}

export interface CashRepository {
    getStoreStatus(storeId: string): Promise<{ isOpen: boolean; openingAmount: number; lastEvent?: CashControlEvent }>;
    registerEvent(event: CashControlEvent): Promise<{ success: boolean; data?: any; error?: string }>;
}

export const cashRepository: CashRepository = {

    /**
     * Check if store is currently open by querying today's events
     */
    async getStoreStatus(storeId: string): Promise<{ isOpen: boolean; openingAmount: number; lastEvent?: CashControlEvent }> {
        const isOnline = navigator.onLine && isSupabaseConfigured();

        // Default closed state
        let status = { isOpen: false, openingAmount: 0, lastEvent: undefined as CashControlEvent | undefined };

        // 1. Try Online
        if (isOnline) {
            const supabase = getSupabaseClient()!;
            try {
                const today = new Date().toISOString().split('T')[0];

                // Fetch today's register status
                const { data, error } = await supabase
                    .from('cash_register')
                    .select('*')
                    .eq('store_id', storeId)
                    .eq('date', today);

                if (!error && data) {
                    const opening = data.find(r => r.type === 'opening');
                    const closing = data.find(r => r.type === 'closing');

                    if (opening && !closing) {
                        status.isOpen = true;
                        status.openingAmount = Number(opening.amount);
                        status.lastEvent = {
                            store_id: storeId,
                            type: 'open',
                            amount_declared: Number(opening.amount),
                            authorized_by_name: 'Unknown', // Not stored in summary table
                            authorized_by_type: 'employee'
                        };
                    }
                }
                return status;

            } catch (e) {
                logger.error('[CashRepo] Online status check failed', e);
            }
        }

        // 2. Fallback to LocalStorage (Optimistic)
        // We look for the most recent event in local cache or queue
        try {
            const storedStatus = localStorage.getItem('tienda-store-status');
            if (storedStatus) {
                const parsed = JSON.parse(storedStatus);
                // Validate if it's from today
                const today = new Date().toISOString().split('T')[0];
                if (parsed.date === today) {
                    return {
                        isOpen: parsed.isOpen,
                        openingAmount: parsed.openingAmount || 0,
                        lastEvent: parsed.lastEvent
                    };
                }
            }
        } catch (e) {
            logger.error('[CashRepo] Local status check failed', e);
        }

        return status;
    },

    /**
     * Register an Open or Close event
     */
    async registerEvent(event: CashControlEvent): Promise<{ success: boolean; data?: any; error?: string }> {
        const isOnline = navigator.onLine && isSupabaseConfigured();

        // 1. Try Online RPC
        if (isOnline) {
            const supabase = getSupabaseClient()!;
            try {
                // RPC: registrar_evento_caja
                const { data, error } = await supabase.rpc('registrar_evento_caja', {
                    p_store_id: event.store_id,
                    p_event_type: event.type,
                    p_amount_declared: event.amount_declared,
                    p_authorized_by_name: event.authorized_by_name,
                    p_authorized_by_type: event.authorized_by_type,
                    p_authorized_by_id: event.authorized_by_id
                });

                if (error) {
                    logger.error('[CashRepo] RPC error', error);
                    // If network issue, fallthrough to offline
                    if (!error.message.includes('FetchError')) {
                        return { success: false, error: error.message };
                    }
                } else {
                    if (data.success) {
                        // Update Local Cache immediately for UI
                        cacheStatusLocally(event.store_id, event);
                        return { success: true, data };
                    } else {
                        return { success: false, error: data.error };
                    }
                }

            } catch (e: any) {
                logger.error('[CashRepo] RPC exception', e);
            }
        }

        // 2. Offline: Queue it
        try {
            await addToSyncQueue('CASH_EVENT', event);
            cacheStatusLocally(event.store_id, event);
            return { success: true, data: { offline: true } };
        } catch (e: any) {
            return { success: false, error: e.message };
        }
    }
};

// Helper: Cache status for offline persistence
function cacheStatusLocally(storeId: string, event: CashControlEvent) {
    const today = new Date().toISOString().split('T')[0];
    const status = {
        date: today,
        isOpen: event.type === 'open',
        openingAmount: event.type === 'open' ? event.amount_declared : 0,
        lastEvent: event
    };
    localStorage.setItem('tienda-store-status', JSON.stringify(status));
}

export default cashRepository;

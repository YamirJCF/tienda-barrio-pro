/**
 * Cash Repository
 * WO-003 T3.1: Cash Control Repository
 * WO-FE-008: Refactored for Schema v2 (cash_sessions, RPCs)
 * 
 * Handles interaction with 'cash_sessions'
 * Uses RPC `abrir_caja` and `cerrar_caja` for atomic operations
 *
 * @module data/repositories/cashRepository
 */

import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { logger } from '../../utils/logger';
import { addToSyncQueue } from '../syncQueue';

// Interface adapted to what the UI Store expects, but mapped to DB
export interface CashControlEvent {
    id?: string; // Session ID (for close) or Generated ID
    store_id: string;
    type: 'open' | 'close';
    amount_declared: number;
    amount_expected?: number;
    difference?: number;
    authorized_by_id?: string; // Employee ID
    authorized_by_name: string;
    authorized_by_type: 'admin' | 'employee';
    created_at?: string;
}

export interface CashRepository {
    getStoreStatus(storeId: string): Promise<{ isOpen: boolean; openingAmount: number; lastEvent?: CashControlEvent; sessionId?: string }>;
    registerEvent(event: CashControlEvent): Promise<{ success: boolean; data?: any; error?: string }>;
}

export const cashRepository: CashRepository = {

    /**
     * Check if store is currently open by querying active cash_sessions
     */
    async getStoreStatus(storeId: string): Promise<{ isOpen: boolean; openingAmount: number; lastEvent?: CashControlEvent; sessionId?: string }> {
        const isOnline = navigator.onLine && isSupabaseConfigured();

        // Default closed state
        let status = { isOpen: false, openingAmount: 0, lastEvent: undefined as CashControlEvent | undefined, sessionId: undefined as string | undefined };

        // 1. Try Online
        if (isOnline) {
            const supabase = getSupabaseClient()!;
            try {
                // Fetch active session
                // Schema v2: cash_sessions has status 'open' or 'closed'
                const { data, error } = await supabase
                    .from('cash_sessions')
                    .select('*')
                    .eq('store_id', storeId)
                    .eq('status', 'open')
                    .order('opened_at', { ascending: false }) // Get most recent open
                    .limit(1);

                if (!error && data && data.length > 0) {
                    const session = data[0];
                    status.isOpen = true;
                    status.openingAmount = Number(session.opening_balance);
                    status.sessionId = session.id;
                    status.lastEvent = {
                        id: session.id,
                        store_id: session.store_id,
                        type: 'open',
                        amount_declared: Number(session.opening_balance),
                        authorized_by_name: 'Unknown', // Not fetched here
                        authorized_by_type: 'employee',
                        authorized_by_id: session.opened_by
                    };
                }
                return status;

            } catch (e) {
                logger.error('[CashRepo] Online status check failed', e);
            }
        }

        // 2. Fallback to LocalStorage (Optimistic)
        try {
            const storedStatus = localStorage.getItem('tienda-store-status');
            if (storedStatus) {
                const parsed = JSON.parse(storedStatus);
                // Basic validation: check date? Or just trust local state for offline flow?
                // Ideally, we trust local state if recent.
                return {
                    isOpen: parsed.isOpen,
                    openingAmount: parsed.openingAmount || 0,
                    lastEvent: parsed.lastEvent,
                    sessionId: parsed.sessionId
                };
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
        // ===== VALIDATION CHECKPOINT (Fase 2 Blindaje) =====
        if (!event.store_id || event.store_id.trim() === '') {
            const errorMsg = 'Cannot register CashEvent without valid store_id. This would fail RLS policies.';
            console.error('🚫 [CashRepo] RLSViolationError:', errorMsg);
            return { success: false, error: errorMsg };
        }

        // Validate UUID format
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        if (!uuidRegex.test(event.store_id)) {
            const errorMsg = `Invalid UUID format for store_id: "${event.store_id}"`;
            console.error('🚫 [CashRepo] ValidationError:', errorMsg);
            return { success: false, error: errorMsg };
        }

        const isOnline = navigator.onLine && isSupabaseConfigured();

        // 1. Try Online RPC
        if (isOnline) {
            const supabase = getSupabaseClient()!;
            try {
                let rpcName = '';
                let rpcArgs = {};

                if (event.type === 'open') {
                    rpcName = 'abrir_caja';
                    rpcArgs = {
                        p_store_id: event.store_id,
                        p_employee_id: event.authorized_by_id, // Opened by
                        p_opening_balance: event.amount_declared
                    };
                } else if (event.type === 'close') {
                    rpcName = 'cerrar_caja';
                    // We need session ID for closing. Inherited from event.id or passed context?
                    // Assuming event.id is the sessionId when type is close (caller must ensure this)
                    if (!event.id) {
                        return { success: false, error: "Session ID required for closing" };
                    }
                    rpcArgs = {
                        p_session_id: event.id,
                        p_employee_id: event.authorized_by_id,
                        p_actual_balance: event.amount_declared
                    };
                } else {
                    return { success: false, error: "Invalid event type" };
                }

                const { data, error } = await supabase.rpc(rpcName as any, rpcArgs);

                if (error) {
                    logger.error('[CashRepo] RPC error', error);
                    if (!error.message.includes('FetchError')) {
                        return { success: false, error: error.message };
                    }
                } else {
                    // Success
                    const response = data as any;
                    if (response.success) {
                        // Cache locally
                        const sessionId = response.session_id || event.id; // Get ID from response if open

                        const statusCache = {
                            date: new Date().toISOString().split('T')[0],
                            isOpen: event.type === 'open',
                            openingAmount: event.type === 'open' ? event.amount_declared : 0,
                            lastEvent: event,
                            sessionId: sessionId
                        };
                        localStorage.setItem('tienda-store-status', JSON.stringify(statusCache));

                        return { success: true, data: response };
                    } else {
                        return { success: false, error: response.error || 'Operation failed' };
                    }
                }

            } catch (e: any) {
                logger.error('[CashRepo] RPC exception', e);
            }
        }

        // 2. Offline: Queue it
        try {
            // Note: complex offline logic for session IDs might be needed. 
            // For now, we queue generic 'CASH_EVENT' and let Sync Queue handle re-mapping if possible.
            await addToSyncQueue('CASH_EVENT', event);

            // Optimistic Update
            const statusCache = {
                date: new Date().toISOString().split('T')[0],
                isOpen: event.type === 'open',
                openingAmount: event.type === 'open' ? event.amount_declared : 0,
                lastEvent: event,
                sessionId: event.id || 'offline-pending' // Provisional ID
            };
            localStorage.setItem('tienda-store-status', JSON.stringify(statusCache));

            return { success: true, data: { offline: true } };
        } catch (e: any) {
            return { success: false, error: e.message };
        }
    }
};

export default cashRepository;

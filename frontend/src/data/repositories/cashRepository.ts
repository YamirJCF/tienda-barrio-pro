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

import { Decimal } from 'decimal.js';
import type { CashTransaction } from '../../types';

import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { logger } from '../../utils/logger';

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
    getSessionTransactions(sessionId: string): Promise<CashTransaction[]>;
    addMovement(transaction: CashTransaction, sessionId: string): Promise<{ success: boolean; error?: string }>;
}

export const cashRepository: CashRepository = {

    /**
     * Check if store is currently open by querying active cash_sessions
     */
    async getStoreStatus(storeId: string): Promise<{ isOpen: boolean; openingAmount: number; lastEvent?: CashControlEvent; sessionId?: string }> {
        const isOnline = navigator.onLine && isSupabaseConfigured();

        // Default closed state
        let status = { isOpen: false, openingAmount: 0, lastEvent: undefined as CashControlEvent | undefined, sessionId: undefined as string | undefined };

        // 1. Try Online via RPC (Security Definer - Bypasses RLS)
        // This prevents "Blind Spots" where session exists but RLS hides it
        if (isOnline) {
            const supabase = getSupabaseClient()!;
            try {
                // Try Robust RPC first
                const { data, error } = await supabase.rpc('get_active_cash_session', { p_store_id: storeId });

                if (!error && data) {
                    const result = data as any;
                    if (result.isOpen) {
                        status.isOpen = true;
                        status.openingAmount = Number(result.openingAmount);
                        status.sessionId = result.sessionId;
                        status.lastEvent = {
                            id: result.sessionId,
                            store_id: storeId,
                            type: 'open',
                            amount_declared: Number(result.openingAmount),
                            authorized_by_name: 'Unknown',
                            authorized_by_type: 'employee',
                            authorized_by_id: result.openedBy
                        };
                        return status;
                    } else {
                        // RPC Authoritatively says "Closed" -> Trust it.
                        // Do NOT fallback to LocalStorage (which might have stale "Open" state)
                        return status; // Default is closed
                    }
                } else {
                    // Fallback to legacy select if RPC fails or not exists (backward compat)
                    // ... existing select logic ...
                    const { data: legacyData, error: legacyError } = await supabase
                        .from('cash_sessions')
                        .select('*')
                        .eq('store_id', storeId)
                        .eq('status', 'open')
                        .order('opened_at', { ascending: false })
                        .limit(1);

                    if (!legacyError && legacyData && legacyData.length > 0) {
                        const session = legacyData[0];
                        status.isOpen = true;
                        status.openingAmount = Number(session.opening_balance);
                        status.sessionId = session.id;
                        status.lastEvent = {
                            id: session.id,
                            store_id: session.store_id,
                            type: 'open',
                            amount_declared: Number(session.opening_balance),
                            authorized_by_name: 'Unknown',
                            authorized_by_type: 'employee',
                            authorized_by_id: session.opened_by
                        };
                        return status;
                    }
                }
            } catch (e) {
                logger.error('[CashRepo] Online status check failed', e);
            }
        }

        // 2. Fallback to LocalStorage (Optimistic)
        try {
            const storedStatus = localStorage.getItem('tienda-store-status');
            if (storedStatus) {
                const parsed = JSON.parse(storedStatus);
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
        if (!event.store_id || event.store_id.trim() === '') {
            const errorMsg = 'Cannot register CashEvent without valid store_id. This would fail RLS policies.';
            console.error('🚫 [CashRepo] RLSViolationError:', errorMsg);
            return { success: false, error: errorMsg };
        }

        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        if (!uuidRegex.test(event.store_id)) {
            const errorMsg = `Invalid UUID format for store_id: "${event.store_id}"`;
            console.error('🚫 [CashRepo] ValidationError:', errorMsg);
            return { success: false, error: errorMsg };
        }

        if (!navigator.onLine) {
            logger.warn('[CashRepo] Cash operation blocked - requires connection');
            return {
                success: false,
                error: 'Abrir o cerrar caja requiere conexión a internet'
            };
        }

        const isOnline = navigator.onLine && isSupabaseConfigured();

        if (isOnline) {
            const supabase = getSupabaseClient()!;
            try {
                let rpcName = '';
                let rpcArgs = {};

                if (event.type === 'open') {
                    // VALIDATION: Ensure employee ID is UUID (prevents 22P02 error)
                    if (event.authorized_by_id && !uuidRegex.test(event.authorized_by_id)) {
                        return {
                            success: false,
                            error: `Invalid Employee UUID: ${event.authorized_by_id}. (Check AuthStore prefixes)`
                        };
                    }

                    rpcName = 'abrir_caja';
                    rpcArgs = {
                        p_store_id: event.store_id,
                        p_employee_id: event.authorized_by_id, // Opened by
                        p_opening_balance: event.amount_declared
                    };
                } else if (event.type === 'close') {
                    rpcName = 'cerrar_caja';
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
                    const response = data as any;
                    if (response.success) {
                        const sessionId = response.session_id || event.id;

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

        return { success: false, error: 'Error al procesar operación de caja' };
    },

    /**
     * Get transactions for a specific session
     */
    async getSessionTransactions(sessionId: string): Promise<CashTransaction[]> {
        const supabase = getSupabaseClient()!;
        try {
            const { data, error } = await supabase
                .from('cash_movements')
                .select('*')
                .eq('session_id', sessionId)
                .order('created_at', { ascending: true });

            if (error) {
                logger.error('[CashRepo] Fetch transactions error', error);
                return [];
            }

            return (data || []).map(row => ({
                id: row.id,
                type: row.movement_type === 'ingreso' ? 'income' : 'expense',
                amount: new Decimal(row.amount),
                description: row.description,
                timestamp: row.created_at,
                relatedSaleId: row.sale_id,
                category: 'General'
            }));

        } catch (e) {
            logger.error('[CashRepo] Exception fetching transactions', e);
            return [];
        }
    },

    /**
     * Add a manual movement (expense or income)
     */
    async addMovement(transaction: CashTransaction, sessionId: string): Promise<{ success: boolean; error?: string }> {
        const supabase = getSupabaseClient()!;
        try {
            const movementType = transaction.type === 'income' ? 'ingreso' : 'gasto';

            const { error } = await supabase
                .from('cash_movements')
                .insert({
                    session_id: sessionId,
                    movement_type: movementType,
                    amount: transaction.amount.toNumber(),
                    description: transaction.description,
                    created_at: transaction.timestamp,
                    sale_id: transaction.relatedSaleId || null
                });

            if (error) {
                return { success: false, error: error.message };
            }
            return { success: true };
        } catch (e: any) {
            return { success: false, error: e.message };
        }
    }
};

export default cashRepository;

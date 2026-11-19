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

import { getSupabaseClient, isSupabaseConfigured, requireSupabase } from '../supabaseClient';
import { logger } from '../../utils/logger';

// Interface adapted to what the UI Store expects, but mapped to DB
export interface CashControlEvent {
    id?: string; // Session ID (for close) or Generated ID
    store_id: string;
    type: 'open' | 'close';
    amount_declared: number;
    declared_nequi?: number;
    declared_llave_bre?: number;
    amount_expected?: number;
    difference?: number;
    authorized_by_id?: string; // Actor ID
    authorized_by_name: string;
    authorized_by_type: 'admin' | 'employee';
    created_at?: string;
}

export interface StoreCashStatus {
    isOpen: boolean;
    openingAmount: number;
    lastEvent?: CashControlEvent;
    sessionId?: string;
    openedByName?: string;
    openedByRole?: string;
    closingAttempts?: number;
    isExpired24h?: boolean;
    lifecycleState?: 'open' | 'Expirado/Bloqueado' | 'closed';
    pendingForcedSession?: {
        sessionId: string;
        openedBy?: string;
        openedByName?: string;
        openedByRole?: string;
        openedAt: string;
        closingAttempts?: number;
        lifecycleState?: string;
    } | null;
}

export interface CashRepository {
    getStoreStatus(storeId: string): Promise<StoreCashStatus>;
    registerEvent(event: CashControlEvent): Promise<{ success: boolean; data?: any; error?: string; code?: string }>;
    getSessionTransactions(sessionId: string): Promise<CashTransaction[]>;
    addMovement(transaction: CashTransaction, sessionId: string): Promise<{ success: boolean; error?: string }>;
    getPendingForcedSessions(storeId?: string): Promise<{ id: string; openedAt: string; channels: string[] }[]>;
    reconcileForcedSession(sessionId: string, employeeId: string, actualBalance: number | null): Promise<void>;
}

export const cashRepository: CashRepository = {

    /**
     * Check if store is currently open by querying active cash_sessions
     */
    async getStoreStatus(storeId: string): Promise<StoreCashStatus> {
        const isOnline = navigator.onLine && isSupabaseConfigured();

        // Default closed state
        const status: StoreCashStatus = {
            isOpen: false,
            openingAmount: 0,
            lastEvent: undefined,
            sessionId: undefined,
            pendingForcedSession: null,
        };

        // 1. Try Online via RPC (Regla 3: Cero fallbacks silenciosos a query parcial ni localStorage cuando está online)
        if (isOnline) {
            const supabase = getSupabaseClient()!;
            const { data, error } = await supabase.rpc('get_active_cash_session', { p_store_id: storeId });

            if (error) {
                logger.error('[CashRepo] get_active_cash_session RPC failed online:', error);
                throw new Error(error.message || 'Error consultando estado de caja en servidor');
            }

            if (data) {
                const result = data as any;
                if (result.isOpen) {
                    const isAdminOpener = result.openedByRole === 'owner' || result.openedByRole === 'manager';
                    status.isOpen = true;
                    status.openingAmount = Number(result.openingAmount);
                    status.sessionId = result.sessionId;
                    status.openedByName = result.openedByName;
                    status.openedByRole = result.openedByRole;
                    status.closingAttempts = Number(result.closingAttempts ?? 0);
                    status.isExpired24h = Boolean(result.isExpired24h);
                    status.lifecycleState = result.lifecycleState || (status.isExpired24h ? 'Expirado/Bloqueado' : 'open');
                    status.lastEvent = {
                        id: result.sessionId,
                        store_id: storeId,
                        type: 'open',
                        amount_declared: Number(result.openingAmount),
                        authorized_by_name: result.openedByName || 'Usuario',
                        authorized_by_type: isAdminOpener ? 'admin' : 'employee',
                        authorized_by_id: result.openedBy,
                        created_at: result.openedAt
                    };
                    return status;
                } else {
                    status.pendingForcedSession = result.pendingForcedSession ?? null;
                    return status;
                }
            }

            return status;
        }

        // 2. Fallback to LocalStorage (Offline)
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
    async registerEvent(event: CashControlEvent): Promise<{ success: boolean; data?: any; error?: string; code?: string }> {
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
                let rpcArgs: Record<string, any> = {};

                if (event.type === 'open') {
                    if (event.authorized_by_id && !uuidRegex.test(event.authorized_by_id)) {
                        return {
                            success: false,
                            error: `Invalid Employee UUID: ${event.authorized_by_id}. (Check AuthStore prefixes)`
                        };
                    }

                    rpcName = 'abrir_caja';
                    rpcArgs = {
                        p_store_id: event.store_id,
                        p_employee_id: event.authorized_by_id,
                        p_opening_balance: event.amount_declared
                    };
                } else if (event.type === 'close') {
                    rpcName = 'cerrar_caja';
                    if (!event.id) {
                        return { success: false, error: "Session ID required for closing" };
                    }
                    rpcArgs = {
                        p_session_id: event.id,
                        p_employee_id: event.authorized_by_id ?? null,
                        p_actual_balance: event.amount_declared,
                        p_declared_nequi: event.declared_nequi ?? 0,
                        p_declared_llave_bre: event.declared_llave_bre ?? 0
                    };
                } else {
                    return { success: false, error: "Invalid event type" };
                }

                const { data, error } = await supabase.rpc(rpcName as any, rpcArgs);

                if (error) {
                    logger.error('[CashRepo] RPC error', error);
                    const msg = error.message || '';

                    // Transacción dedicada para persistir rechazo por propiedad estricta tras rollback de RPC
                    if (msg.includes('SHIFT_OWNERSHIP_VIOLATION')) {
                        try {
                            await supabase.rpc('rpc_log_security_event', {
                                p_event_type: 'UNAUTHORIZED_SHIFT_CLOSE',
                                p_store_id: event.store_id,
                                p_metadata: {
                                    session_id: event.id,
                                    reason: msg
                                }
                            });
                        } catch {
                            // No ocultar la excepción principal
                        }
                        return { success: false, code: 'SHIFT_OWNERSHIP_VIOLATION', error: msg };
                    }

                    if (!msg.includes('FetchError')) {
                        return { success: false, error: msg };
                    }
                } else {
                    const response = data as any;
                    if (response?.success) {
                        const sessionId = response.session_id || response.data?.session_id || event.id;

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
                        return {
                            success: false,
                            code: response?.code,
                            data: response,
                            error: response?.message || response?.error || 'Operation failed'
                        };
                    }
                }

            } catch (e: any) {
                logger.error('[CashRepo] RPC exception', e);
                return { success: false, error: e?.message || 'Error al procesar operación de caja' };
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

            return (data || []).map((row: any) => ({
                id: row.id,
                type: row.movement_type === 'ingreso' ? 'income' : 'expense',
                movementType: row.movement_type,
                amount: new Decimal(row.amount),
                description: row.description,
                timestamp: row.created_at,
                relatedSaleId: row.sale_id,
                paymentMethod: row.payment_method || 'efectivo',
                category: row.category || 'General',
                voucherRef: row.voucher_ref ?? null,
                actorName: row.actor_name ?? null,
                actorRole: row.actor_role ?? null,
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
            if (transaction.type === 'expense') {
                const { data, error } = await supabase.rpc('rpc_registrar_gasto_v2', {
                    p_session_id: sessionId,
                    p_amount: transaction.amount.toNumber(),
                    p_description: transaction.description,
                    p_category: transaction.category || 'Servicios',
                    p_payment_method: transaction.paymentMethod || 'efectivo',
                    p_voucher_ref: transaction.voucherRef || undefined
                });

                if (error) {
                    return { success: false, error: error.message };
                }
                const res = data as any;
                if (res && res.success === false) {
                    return { success: false, error: res.error || res.message || 'Error al registrar gasto' };
                }
                return { success: true };
            }

            const movementType = 'ingreso';

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
    },

    async getPendingForcedSessions(storeId?: string): Promise<{ id: string; openedAt: string; channels: string[] }[]> {
        const supabase = requireSupabase();
        let query = supabase
            .from('cash_sessions')
            .select('id, opened_at')
            .eq('status', 'closed')
            .eq('forced_close', true)
            .is('actual_balance', null);

        if (storeId) {
            query = query.eq('store_id', storeId);
        }

        const { data: sessions, error } = await query.order('opened_at', { ascending: true });

        if (error) throw error;

        return (sessions ?? []).map((s: any) => ({
            id: s.id,
            openedAt: s.opened_at,
            channels: ['efectivo'],
        }));
    },

    async reconcileForcedSession(sessionId: string, employeeId: string, actualBalance: number | null): Promise<void> {
        const supabase = requireSupabase();
        const { data, error } = await supabase.rpc('rpc_reconciliar_cierre_forzado', {
            p_session_id: sessionId,
            p_employee_id: employeeId,
            p_actual_balance: actualBalance,
        });

        if (error) throw error;
        if (!(data as any)?.success) throw new Error('RECONCILIATION_FAILED');
    }
};

export default cashRepository;

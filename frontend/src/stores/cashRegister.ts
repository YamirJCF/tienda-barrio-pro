import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import Decimal from 'decimal.js';
import { logger } from '../utils/logger';
import { cashRepository } from '../data/repositories/cashRepository';
import { isSupabaseConfigured, requireSupabase } from '../data/supabaseClient';
import { useNotificationsStore } from './notificationsStore';
import { useAuthStore } from './auth';

import type { CashTransaction, CashSession } from '../types';

export const useCashRegisterStore = defineStore('cashRegister', () => {
    // State
    const currentSession = ref<CashSession | null>(null);
    const sessionHistory = ref<CashSession[]>([]);
    const lastSyncError = ref<string | null>(null);
    const pendingForcedSessionInfo = ref<{
        sessionId: string;
        openedBy?: string;
        openedByName?: string;
        openedByRole?: string;
        openedAt: string;
        closingAttempts?: number;
        lifecycleState?: string;
    } | null>(null);

    // Computed
    const isOpen = computed(() => currentSession.value?.status === 'open');

    const currentBalance = computed(() => {
        if (!currentSession.value) return new Decimal(0);

        const opening = new Decimal(currentSession.value.openingBalance);

        const totalIncome = currentSession.value.transactions
            .filter(t => t.type === 'income')
            .reduce((sum, t) => sum.plus(new Decimal(t.amount)), new Decimal(0));

        const totalExpenses = currentSession.value.transactions
            .filter(t => t.type === 'expense')
            .reduce((sum, t) => sum.plus(new Decimal(t.amount)), new Decimal(0));

        return opening.plus(totalIncome).minus(totalExpenses);
    });

    const balancesByMethod = computed(() => {
        if (!currentSession.value) return {};

        const balances: Record<string, Decimal> = {
            'efectivo': new Decimal(currentSession.value.openingBalance)
        };

        for (const t of currentSession.value.transactions) {
            const method = t.paymentMethod || 'efectivo';
            if (!balances[method]) balances[method] = new Decimal(0);

            if (t.type === 'income') {
                balances[method] = balances[method].plus(t.amount);
            } else if (t.type === 'expense') {
                balances[method] = balances[method].minus(t.amount);
            }
        }

        return balances;
    });

    const totalExpenses = computed(() => {
        if (!currentSession.value) return new Decimal(0);
        return currentSession.value.transactions
            .filter(t => t.type === 'expense')
            .reduce((sum, t) => sum.plus(new Decimal(t.amount)), new Decimal(0));
    });

    const totalIncome = computed(() => {
        if (!currentSession.value) return new Decimal(0);
        return currentSession.value.transactions
            .filter(t => t.type === 'income')
            .reduce((sum, t) => sum.plus(new Decimal(t.amount)), new Decimal(0));
    });

    // FRD-017 / SDD-017: Stale Shift Detection (24 Hours -> Expirado/Bloqueado)
    const isStaleSession = computed(() => {
        if (!currentSession.value || currentSession.value.status !== 'open') return false;
        if (currentSession.value.isExpired24h) return true;

        const openingTimestamp = new Date(currentSession.value.openingTime).getTime();
        const nowTimestamp = Date.now();
        const TWENTY_FOUR_HOURS_MS = 24 * 60 * 60 * 1000;

        return (nowTimestamp - openingTimestamp) >= TWENTY_FOUR_HOURS_MS;
    });

    const lifecycleState = computed<'open' | 'Expirado/Bloqueado' | 'closed'>(() => {
        if (!currentSession.value) return pendingForcedSessionInfo.value ? 'Expirado/Bloqueado' : 'closed';
        if (currentSession.value.status === 'closed') return 'closed';
        return isStaleSession.value ? 'Expirado/Bloqueado' : 'open';
    });

    const closingAttemptsRemaining = computed(() => {
        const used = currentSession.value?.closingAttempts ?? 0;
        return Math.max(0, 3 - used);
    });

    // Human-readable date of the stale session for UI display
    const staleSessionDate = computed(() => {
        if (!currentSession.value) return '';
        return new Date(currentSession.value.openingTime).toLocaleDateString('es-CO', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
    });

    // Methods
    const syncFromBackend = async (storeId: string, options?: { throwOnError?: boolean }) => {
        const throwOnError = Boolean(options?.throwOnError);
        // OFFLINE-FIRST: Preserve existing session without attempting sync
        const hasExistingSession = currentSession.value?.status === 'open';
        lastSyncError.value = null;

        // If we have a session and are offline, don't even try to sync (unless caller demands fail-closed)
        if (!navigator.onLine && hasExistingSession && !throwOnError) {
            logger.log('⚠️ [CashRegisterStore] Offline detected - preserving local session');
            return true;
        }

        try {
            // If Supabase not configured, preserve existing state
            if (!isSupabaseConfigured()) {
                console.warn('⚠️ [CashRegisterStore] Supabase not configured - preserving local session');
                return hasExistingSession;
            }

            // Lazy RPC Call for Forced Closure (FRD-017)
            if (isStaleSession.value) {
                try {
                    const supabase = requireSupabase();
                    await supabase.rpc('rpc_check_and_force_close_shifts');
                    logger.log('🔄 [CashRegisterStore] Stale session detected. Force close RPC executed.');
                } catch (rpcError) {
                    console.error('🚫 [CashRegisterStore] Failed to execute forced close RPC:', rpcError);
                }
            }

            const status = await cashRepository.getStoreStatus(storeId);
            pendingForcedSessionInfo.value = status.pendingForcedSession ?? null;

            if (status.isOpen && status.sessionId) {
                const openingTime = status.lastEvent?.created_at || new Date().toISOString();
                const computedExpired = Boolean(
                    status.isExpired24h ||
                    (Date.now() - new Date(openingTime).getTime() >= 24 * 60 * 60 * 1000)
                );

                // Reconstruct session from server truth (sin exponer expected_balance ni difference)
                currentSession.value = {
                    id: status.sessionId,
                    storeId: storeId,
                    employeeId: status.lastEvent?.authorized_by_id || 'unknown',
                    openedByName: status.openedByName || status.lastEvent?.authorized_by_name,
                    openedByRole: status.openedByRole,
                    status: 'open',
                    openingTime,
                    openingBalance: new Decimal(status.openingAmount),
                    closingAttempts: status.closingAttempts ?? 0,
                    isExpired24h: computedExpired,
                    lifecycleState: status.lifecycleState || (computedExpired ? 'Expirado/Bloqueado' : 'open'),
                    transactions: [],
                    notes: ''
                };

                // Fetch transactions from DB (Source of Truth):
                // Admin consulta cash_movements completo; Empleado consulta únicamente sus movimientos propios vía RPC acotado (SDD-003-01 §6.2)
                const authStore = useAuthStore();
                if (authStore.isAdmin) {
                    const transactions = await cashRepository.getSessionTransactions(status.sessionId!);
                    if (transactions.length > 0) {
                        currentSession.value.transactions = transactions;
                    }
                } else {
                    const ownRes = await cashRepository.getOwnShiftMovements(storeId, 'all', 200, 0);
                    currentSession.value.transactions = ownRes.data
                        .filter((m) => m.source === 'expense' || m.source === 'payment' || m.source === 'refund')
                        .map((m) => {
                            if (m.source === 'refund') {
                                return {
                                    id: m.id,
                                    type: 'expense' as const,
                                    movementType: 'reembolso' as const,
                                    amount: new Decimal(m.amount),
                                    description: m.description,
                                    timestamp: m.created_at,
                                    paymentMethod: (m.payment_method as 'efectivo' | 'nequi' | 'llave_bre') || 'efectivo',
                                    category: m.category || 'Reembolso',
                                    voucherRef: m.voucher_ref ?? null,
                                    actorName: m.actor_name,
                                    actorRole: m.actor_role,
                                };
                            }
                            if (m.source === 'expense') {
                                return {
                                    id: m.id,
                                    type: 'expense' as const,
                                    movementType: 'gasto' as const,
                                    amount: new Decimal(m.amount),
                                    description: m.description,
                                    timestamp: m.created_at,
                                    paymentMethod: (m.payment_method as 'efectivo' | 'nequi' | 'llave_bre') || 'efectivo',
                                    category: m.category || 'General',
                                    voucherRef: m.voucher_ref ?? null,
                                    actorName: m.actor_name,
                                    actorRole: m.actor_role,
                                };
                            }
                            const isSupplierPayment =
                                (m.category || '').toLowerCase().includes('proveedor') ||
                                (m.description || '').toUpperCase().startsWith('PAGO PROVEEDOR');
                            return {
                                id: m.id,
                                type: isSupplierPayment ? ('expense' as const) : ('income' as const),
                                movementType: isSupplierPayment ? ('pago_proveedor' as const) : ('ingreso' as const),
                                amount: new Decimal(m.amount),
                                description: m.description,
                                timestamp: m.created_at,
                                paymentMethod: (m.payment_method as 'efectivo' | 'nequi' | 'llave_bre') || 'efectivo',
                                category: m.category || (isSupplierPayment ? 'Pago a Proveedor' : 'Abono / Ingreso'),
                                voucherRef: m.voucher_ref ?? null,
                                actorName: m.actor_name,
                                actorRole: m.actor_role,
                            };
                        });
                }

                lastSyncError.value = null;
                return true;
            } else {
                // Backend authoritatively says "no open session"
                if (hasExistingSession) {
                    console.warn('⚠️ [CashRegisterStore] Backend says closed — clearing stale local session');
                }
                currentSession.value = null;
                lastSyncError.value = null;
                return false;
            }
        } catch (e: any) {
            console.error('🚫 [CashRegisterStore] Sync failed:', e);
            lastSyncError.value = e?.message || 'Error al sincronizar el estado de la caja';
            if (throwOnError) {
                throw e;
            }
            // FRD-012: ALWAYS preserve existing session on error when resilient offline sync
            if (hasExistingSession) {
                logger.log('✅ [CashRegisterStore] Network error - preserving existing session');
                return true;
            }
            return false;
        }
    };

    const openRegister = async (employeeId: string, storeId: string, amount: Decimal | number, notes?: string) => {
        if (isOpen.value) throw new Error("La caja ya está abierta");

        // ===== VALIDATION CHECKPOINT (Puente Store-Repositorio) =====
        if (!storeId || storeId.trim() === '') {
            const error = new Error('Cannot open register without valid storeId. This would fail RLS policies.');
            console.error('🚫 [CashRegisterStore] RLSViolationError:', error.message);
            throw error;
        }

        const newSession: CashSession = {
            id: crypto.randomUUID(),
            storeId, // Required for RLS
            employeeId,
            status: 'open',
            openingTime: new Date().toISOString(),
            openingBalance: new Decimal(amount),
            closingAttempts: 0,
            isExpired24h: false,
            lifecycleState: 'open',
            transactions: [],
            notes
        };

        // ===== REPOSITORY INTEGRATION (Regla 3: Cero Fallos Silenciosos) =====
        try {
            const result = await cashRepository.registerEvent({
                id: newSession.id,
                store_id: storeId,
                type: 'open',
                amount_declared: Number(new Decimal(amount)),
                authorized_by_id: employeeId,
                authorized_by_name: 'Usuario',
                authorized_by_type: 'employee'
            });

            if (!result.success) {
                if (result.error && (result.error.includes('Ya existe una caja abierta') || result.error.includes('CASH_ALREADY_OPEN'))) {
                    console.warn('⚠️ [CashRegisterStore] Backend reported register already open. Syncing...');
                    await syncFromBackend(storeId);
                    if (isOpen.value) return;
                }

                console.error('🚫 [CashRegisterStore] Repository registration failed:', result.error);
                throw new Error(result.error || 'Failed to register opening event');
            }

            if (result.data?.session_id) {
                newSession.id = result.data.session_id;
                logger.log('✅ [CashRegisterStore] Session ID synced from backend:', newSession.id);
            }
            if (result.data?.opened_by) {
                newSession.employeeId = result.data.opened_by;
            }
            if (result.data?.opened_by_name) {
                newSession.openedByName = result.data.opened_by_name;
            }
            if (result.data?.opened_by_role) {
                newSession.openedByRole = result.data.opened_by_role;
            }
            if (result.data?.opened_at) {
                newSession.openingTime = result.data.opened_at;
            }

        } catch (e: any) {
            if (e.message && (e.message.includes('Ya existe una caja abierta') || e.message.includes('CASH_ALREADY_OPEN'))) {
                console.warn('⚠️ [CashRegisterStore] Backend reported register already open (caught). Syncing...');
                await syncFromBackend(storeId);
                if (isOpen.value) return;
            }

            console.error('🚫 [CashRegisterStore] Repository call failed:', e.message);
            throw e;
        }

        currentSession.value = newSession;
    };

    const closeRegister = async (
        declaredTotals: Decimal | number | { efectivo: Decimal | number; nequi?: Decimal | number; llave_bre?: Decimal | number },
        notes?: string,
        storeIdOverride?: string
    ): Promise<{
        success: boolean;
        code?: string;
        attemptsUsed?: number;
        attemptsRemaining?: number;
        message?: string;
        sealedWithAlert?: boolean;
        closedByName?: string;
        closedByRole?: string;
    }> => {
        const targetSession = currentSession.value;
        const targetPendingForced = !targetSession ? pendingForcedSessionInfo.value : null;

        if (!targetSession && !targetPendingForced) {
            throw new Error("No hay una sesión de caja activa");
        }

        const sessionId = targetSession?.id || targetPendingForced!.sessionId;
        const storeId = targetSession?.storeId || storeIdOverride || '';
        const openerId = targetSession?.employeeId || targetPendingForced?.openedBy || '';
        const openerName = targetSession?.openedByName || targetPendingForced?.openedByName || 'Usuario';

        const isMultichannelPayload = typeof declaredTotals === 'object' && declaredTotals !== null && 'efectivo' in declaredTotals;
        const declaredEfectivo = isMultichannelPayload
            ? new Decimal((declaredTotals as any).efectivo)
            : new Decimal(declaredTotals as Decimal | number);
        const declaredNequi = isMultichannelPayload && (declaredTotals as any).nequi !== undefined
            ? new Decimal((declaredTotals as any).nequi)
            : new Decimal(0);
        const declaredLlaveBre = isMultichannelPayload && (declaredTotals as any).llave_bre !== undefined
            ? new Decimal((declaredTotals as any).llave_bre)
            : new Decimal(0);

        const result = await cashRepository.registerEvent({
            id: sessionId,
            store_id: storeId,
            type: 'close',
            amount_declared: Number(declaredEfectivo),
            declared_nequi: Number(declaredNequi),
            declared_llave_bre: Number(declaredLlaveBre),
            authorized_by_id: openerId,
            authorized_by_name: openerName,
            authorized_by_type: 'employee'
        });

        // Cierre Asistido (Intentos 1 y 2): servidor no sella ni revela esperado/diferencia
        if (!result.success && result.code === 'COUNT_MISMATCH_RETRY') {
            const previousAttempts = targetSession?.closingAttempts ?? targetPendingForced?.closingAttempts ?? 0;
            const attemptsUsed = Number(result.data?.attempts_used ?? (previousAttempts + 1));
            const attemptsRemaining = Number(result.data?.attempts_remaining ?? Math.max(0, 3 - attemptsUsed));
            if (targetSession) {
                targetSession.closingAttempts = attemptsUsed;
            } else if (pendingForcedSessionInfo.value) {
                pendingForcedSessionInfo.value.closingAttempts = attemptsUsed;
            }

            return {
                success: false,
                code: 'COUNT_MISMATCH_RETRY',
                attemptsUsed,
                attemptsRemaining,
                message: result.error || 'El conteo no coincide con el registro del turno. Revisa y vuelve a intentar.'
            };
        }

        if (!result.success) {
            console.error('🚫 [CashRegisterStore] Repository close failed:', result.error);
            throw new Error(result.error || 'Error al cerrar caja en el servidor');
        }

        const serverData = result.data?.data ?? result.data ?? {};
        if (targetSession) {
            targetSession.status = 'closed';
            targetSession.lifecycleState = 'closed';
            targetSession.closingTime = serverData.closed_at || new Date().toISOString();
            targetSession.closingBalance = declaredEfectivo.plus(declaredNequi).plus(declaredLlaveBre);
            targetSession.closingAttempts = Number(serverData.closing_attempts ?? targetSession.closingAttempts ?? 0);
            if (notes) targetSession.notes = targetSession.notes ? `${targetSession.notes}\n${notes}` : notes;

            sessionHistory.value.push({ ...targetSession });
            currentSession.value = null;
        }
        pendingForcedSessionInfo.value = null;

        return {
            success: true,
            sealedWithAlert: Boolean(serverData.sealed_with_alert),
            closedByName: serverData.closed_by_name,
            closedByRole: serverData.closed_by_role,
        };
    };

    const registerExpense = async (
        amount: Decimal | number,
        description: string,
        category: string = 'Servicios',
        paymentMethod: string = 'efectivo',
        voucherRef?: string
    ) => {
        if (!currentSession.value) throw new Error('NO_OPEN_SESSION: La caja está cerrada');

        const transaction: CashTransaction = {
            id: crypto.randomUUID(),
            type: 'expense',
            movementType: 'gasto',
            amount: new Decimal(amount),
            description,
            category,
            paymentMethod,
            voucherRef: voucherRef || null,
            timestamp: new Date().toISOString()
        };

        // Persist to Backend (Obligatory)
        const result = await cashRepository.addMovement(transaction, currentSession.value.id);

        if (!result.success) {
            console.error('🚫 [CashRegisterStore] Failed to persist expense:', result.error);
            const err: any = new Error(result.error || 'Fallo al guardar gasto');
            err.code = result.code;
            throw err;
        }

        // Refrescar Read Model autoritativo desde rpc_obtener_gastos_turno (Backend Authority)
        const opexReadModel = await cashRepository.getSessionOpexExpenses(currentSession.value.id);
        const nonOpexTransactions = currentSession.value.transactions.filter(
            (t) => !(t.type === 'expense' && (!t.movementType || t.movementType === 'gasto'))
        );
        const opexTransactions: CashTransaction[] = opexReadModel.data.map((row) => ({
            id: row.id,
            type: 'expense',
            movementType: 'gasto',
            amount: new Decimal(row.amount),
            description: row.description,
            category: row.category,
            paymentMethod: row.payment_method,
            voucherRef: row.voucher_ref ?? null,
            actorName: row.actor_name,
            actorRole: row.actor_role,
            timestamp: row.created_at,
        }));
        currentSession.value.transactions = [...nonOpexTransactions, ...opexTransactions];

        return opexReadModel;
    };

    const addIncome = async (amount: Decimal | number, description: string, saleId?: string) => {
        if (!currentSession.value) return;

        const transaction: CashTransaction = {
            id: crypto.randomUUID(),
            type: 'income',
            movementType: 'ingreso',
            amount: new Decimal(amount),
            description,
            timestamp: new Date().toISOString(),
            relatedSaleId: saleId
        };

        // Only persist if NOT a sale (Trigger/RPC handles sales)
        if (!saleId) {
            const result = await cashRepository.addMovement(transaction, currentSession.value.id);
            if (!result.success) {
                console.error('🚫 [CashRegisterStore] Failed to persist income:', result.error);
                throw new Error(result.error || 'Error al registrar ingreso en caja');
            }
        }

        currentSession.value.transactions.push(transaction);
    };

    const fetchPendingForcedSessions = async (storeId?: string) => {
        return await cashRepository.getPendingForcedSessions(storeId);
    };

    const reconcileForcedClose = async (sessionId: string, employeeId: string, actualBalance: number | null) => {
        await cashRepository.reconcileForcedSession(sessionId, employeeId, actualBalance);
        if (pendingForcedSessionInfo.value?.sessionId === sessionId) {
            pendingForcedSessionInfo.value = null;
        }
    };

    const fetchOwnShiftMovements = async (
        storeId: string,
        paymentMethod: 'all' | 'efectivo' | 'digitales' | 'nequi' | 'llave_bre' | 'fiado' | 'consumo_personal' = 'all',
        limit = 50,
        offset = 0
    ) => {
        return await cashRepository.getOwnShiftMovements(storeId, paymentMethod, limit, offset);
    };

    return {
        currentSession,
        sessionHistory,
        pendingForcedSessionInfo,
        lastSyncError,
        isOpen,
        currentBalance,
        balancesByMethod,
        totalExpenses,
        totalIncome,
        isStaleSession,
        lifecycleState,
        closingAttemptsRemaining,
        staleSessionDate,
        openRegister,
        closeRegister,
        registerExpense,
        addIncome,
        syncFromBackend,
        fetchPendingForcedSessions,
        reconcileForcedClose,
        fetchOwnShiftMovements
    };
}, {
    persist: {
        key: 'tienda-cash-register',

        // paths: ['currentSession', 'sessionHistory'], // Removed to fix lint, serializer handles state
        serializer: {
            serialize: (state) => {
                return JSON.stringify(state);
            },
            deserialize: (value) => {
                const state = JSON.parse(value);
                // Hydrate Decimals
                if (state.currentSession) {
                    state.currentSession.openingBalance = new Decimal(state.currentSession.openingBalance);
                    if (state.currentSession.closingBalance) state.currentSession.closingBalance = new Decimal(state.currentSession.closingBalance);
                    if (state.currentSession.calculatedBalance) state.currentSession.calculatedBalance = new Decimal(state.currentSession.calculatedBalance);
                    if (state.currentSession.discrepancy) state.currentSession.discrepancy = new Decimal(state.currentSession.discrepancy);



                    // Resilience: Ensure transactions exists
                    if (!state.currentSession.transactions) {
                        state.currentSession.transactions = [];
                    }

                    state.currentSession.transactions = state.currentSession.transactions.map((t: CashTransaction | any) => ({
                        ...t,
                        amount: new Decimal(t.amount)
                    }));
                }
                if (state.sessionHistory) {
                    state.sessionHistory = state.sessionHistory.map((s: CashSession | any) => {
                        s.openingBalance = new Decimal(s.openingBalance);
                        if (s.closingBalance) s.closingBalance = new Decimal(s.closingBalance);
                        if (s.calculatedBalance) s.calculatedBalance = new Decimal(s.calculatedBalance);
                        if (s.discrepancy) s.discrepancy = new Decimal(s.discrepancy);
                        s.transactions = s.transactions.map((t: CashTransaction | any) => ({
                            ...t,
                            amount: new Decimal(t.amount)
                        }));
                        return s;
                    });
                }
                return state;
            }
        }
    }
});

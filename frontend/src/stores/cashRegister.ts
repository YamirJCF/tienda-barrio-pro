import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import Decimal from 'decimal.js';

import type { CashTransaction, CashSession } from '../types';

export const useCashRegisterStore = defineStore('cashRegister', () => {
    // State
    const currentSession = ref<CashSession | null>(null);
    const sessionHistory = ref<CashSession[]>([]);

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

    // FRD-004/FRD-015: Stale Shift Detection
    // A session is "stale" if it was opened on a previous date and is still open
    const isStaleSession = computed(() => {
        if (!currentSession.value || currentSession.value.status !== 'open') return false;
        const openedDate = new Date(currentSession.value.openingTime).toDateString();
        const today = new Date().toDateString();
        return openedDate !== today;
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
    const syncFromBackend = async (storeId: string) => {
        // OFFLINE-FIRST: Preserve existing session without attempting sync
        const hasExistingSession = currentSession.value?.status === 'open';

        // If we have a session and are offline, don't even try to sync
        if (!navigator.onLine && hasExistingSession) {
            console.log('⚠️ [CashRegisterStore] Offline detected - preserving local session');
            return true;
        }

        try {
            const { cashRepository } = await import('../data/repositories/cashRepository');
            const { isSupabaseConfigured } = await import('../data/supabaseClient');

            // If Supabase not configured, preserve existing state
            if (!isSupabaseConfigured()) {
                console.warn('⚠️ [CashRegisterStore] Supabase not configured - preserving local session');
                return hasExistingSession;
            }

            const status = await cashRepository.getStoreStatus(storeId);

            if (status.isOpen && status.sessionId) {
                // Reconstruct session from status
                currentSession.value = {
                    id: status.sessionId,
                    storeId: storeId,
                    employeeId: status.lastEvent?.authorized_by_id || 'unknown',
                    status: 'open',
                    openingTime: status.lastEvent?.created_at || new Date().toISOString(),
                    openingBalance: new Decimal(status.openingAmount),

                    transactions: [], // Initialize empty to prevent UI crash before fetch
                    notes: ''
                };

                // Fetch transactions from DB (Source of Truth) to populate history
                const transactions = await cashRepository.getSessionTransactions(status.sessionId!);
                if (transactions.length > 0) {
                    currentSession.value.transactions = transactions;
                }

                return true;
            } else {
                // Backend says closed - but ONLY clear if we don't have existing session
                // This handles the case where:
                // 1. User opened cash offline
                // 2. Backend doesn't know about it yet
                // 3. We shouldn't close the local session just because backend is out of sync
                if (hasExistingSession) {
                    console.warn('⚠️ [CashRegisterStore] Backend closed, but preserving existing local session (offline resilience)');
                    return true;
                }

                // No existing session and backend is closed - that's fine
                currentSession.value = null;
                return false;
            }
        } catch (e) {
            console.error('🚫 [CashRegisterStore] Sync failed:', e);
            // FRD-012: ALWAYS preserve existing session on error
            if (hasExistingSession) {
                console.log('✅ [CashRegisterStore] Network error - preserving existing session');
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
            transactions: [],
            notes
        };

        // ===== REPOSITORY INTEGRATION (Aduana Obligatoria) =====
        try {
            const { cashRepository } = await import('../data/repositories/cashRepository');
            const result = await cashRepository.registerEvent({
                id: newSession.id,
                store_id: storeId,
                type: 'open',
                amount_declared: Number(new Decimal(amount)),
                authorized_by_id: employeeId,
                authorized_by_name: 'Employee', // TODO: Get name from employee store
                authorized_by_type: 'employee'
            });

            if (!result.success) {
                // Handle "Already Open" gracefully
                if (result.error && (result.error.includes('Ya existe una caja abierta') || result.error.includes('CASH_ALREADY_OPEN'))) {
                    console.warn('⚠️ [CashRegisterStore] Backend reported register already open. Syncing...');
                    await syncFromBackend(storeId);
                    if (isOpen.value) return; // Recovered successfully
                }

                console.error('🚫 [CashRegisterStore] Repository registration failed:', result.error);
                throw new Error(result.error || 'Failed to register opening event');
            }

        } catch (e: any) {
            // Handle "Already Open" gracefully (if thrown directly)
            if (e.message && (e.message.includes('Ya existe una caja abierta') || e.message.includes('CASH_ALREADY_OPEN'))) {
                console.warn('⚠️ [CashRegisterStore] Backend reported register already open (caught). Syncing...');
                await syncFromBackend(storeId);
                if (isOpen.value) return; // Recovered successfully
            }

            console.error('🚫 [CashRegisterStore] Repository call failed:', e.message);
            // Continue with local state but log warning
            console.warn('⚠️ [CashRegisterStore] Continuing with local state only');
        }

        currentSession.value = newSession;
    };

    const closeRegister = async (physicalCount: Decimal | number, notes?: string) => {
        if (!currentSession.value) throw new Error("No hay una sesión de caja activa");

        const session = currentSession.value;
        const calculated = currentBalance.value;
        const physical = new Decimal(physicalCount);

        session.status = 'closed';
        session.closingTime = new Date().toISOString();
        session.closingBalance = physical;
        session.calculatedBalance = calculated;
        session.discrepancy = physical.minus(calculated);
        if (notes) session.notes = session.notes ? `${session.notes}\n${notes}` : notes;

        // ===== REPOSITORY INTEGRATION (Aduana Obligatoria) =====
        try {
            const { cashRepository } = await import('../data/repositories/cashRepository');
            const result = await cashRepository.registerEvent({
                id: session.id, // Use existing session ID for closing
                store_id: session.storeId,
                type: 'close',
                amount_declared: Number(physical),
                amount_expected: Number(calculated),
                difference: Number(session.discrepancy),
                authorized_by_id: session.employeeId,
                authorized_by_name: 'Employee',
                authorized_by_type: 'employee'
            });

            if (!result.success) {
                console.error('🚫 [CashRegisterStore] Repository close failed:', result.error);
                // Don't throw - still archive locally
            }
        } catch (e: any) {
            console.error('🚫 [CashRegisterStore] Repository close call failed:', e.message);
            console.warn('⚠️ [CashRegisterStore] Session closed locally only');
        }

        // Archive session
        sessionHistory.value.push({ ...session });
        currentSession.value = null;

        return session;
    };

    const registerExpense = async (amount: Decimal | number, description: string, category: string = 'General') => {
        if (!currentSession.value) throw new Error("La caja está cerrada");

        const transaction: CashTransaction = {
            id: crypto.randomUUID(),
            type: 'expense',
            amount: new Decimal(amount),
            description,
            category,
            timestamp: new Date().toISOString()
        };

        // Persist to Backend (Obligatory)
        const { cashRepository } = await import('../data/repositories/cashRepository');
        const result = await cashRepository.addMovement(transaction, currentSession.value.id);

        if (!result.success) {
            console.error('🚫 [CashRegisterStore] Failed to persist expense:', result.error);
            // We still update locally but warn? Or throw?
            // Throwing allows UI to show error
            throw new Error(result.error || 'Fallo al guardar gasto');
        }

        currentSession.value.transactions.push(transaction);
    };

    const addIncome = async (amount: Decimal | number, description: string, saleId?: string) => {
        if (!currentSession.value) return;

        const transaction: CashTransaction = {
            id: crypto.randomUUID(),
            type: 'income',
            amount: new Decimal(amount),
            description,
            timestamp: new Date().toISOString(),
            relatedSaleId: saleId
        };

        // Note: If saleId is present, this is a UI-only update. 
        // The backend source of truth is the trigger.
        // Only persist if NOT a sale (Trigger handles sales)
        if (!saleId) {
            const { cashRepository } = await import('../data/repositories/cashRepository');
            const result = await cashRepository.addMovement(transaction, currentSession.value.id);
            if (!result.success) {
                console.error('🚫 [CashRegisterStore] Failed to persist income:', result.error);
                // Throw or swallow? Swallow generic income for now logic-wise, but logging is good.
            }
        }

        currentSession.value.transactions.push(transaction);
    };

    return {
        currentSession,
        sessionHistory,
        isOpen,
        currentBalance,
        totalExpenses,
        totalIncome,
        isStaleSession,
        staleSessionDate,
        openRegister,
        closeRegister,
        registerExpense,
        addIncome,
        syncFromBackend
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

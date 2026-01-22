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

    // Methods
    const openRegister = (employeeId: string, amount: Decimal | number, notes?: string) => {
        if (isOpen.value) throw new Error("La caja ya está abierta");

        const newSession: CashSession = {
            id: crypto.randomUUID(),
            employeeId,
            status: 'open',
            openingTime: new Date().toISOString(),
            openingBalance: new Decimal(amount),
            transactions: [],
            notes
        };

        currentSession.value = newSession;
    };

    const closeRegister = (physicalCount: Decimal | number, notes?: string) => {
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

        // Archive session
        sessionHistory.value.push({ ...session });
        currentSession.value = null;

        return session; // Return the closed session summary
    };

    const registerExpense = (amount: Decimal | number, description: string, category: string = 'General') => {
        if (!currentSession.value) throw new Error("La caja está cerrada");

        const transaction: CashTransaction = {
            id: crypto.randomUUID(),
            type: 'expense',
            amount: new Decimal(amount),
            description,
            category,
            timestamp: new Date().toISOString()
        };

        currentSession.value.transactions.push(transaction);
    };

    const addIncome = (amount: Decimal | number, description: string, saleId?: string) => {
        if (!currentSession.value) return;

        const transaction: CashTransaction = {
            id: crypto.randomUUID(),
            type: 'income',
            amount: new Decimal(amount),
            description,
            timestamp: new Date().toISOString(),
            relatedSaleId: saleId
        };

        currentSession.value.transactions.push(transaction);
    };

    return {
        currentSession,
        sessionHistory,
        isOpen,
        currentBalance,
        totalExpenses,
        totalIncome,
        openRegister,
        closeRegister,
        registerExpense,
        addIncome
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

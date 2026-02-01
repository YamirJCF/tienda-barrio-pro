import { describe, it, expect, beforeEach, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useCashRegisterStore } from '../../stores/cashRegister';
import { Decimal } from 'decimal.js';

describe('CashRegister Store (Logic Verification)', () => {
    beforeEach(() => {
        setActivePinia(createPinia());
    });

    it('should open register correctly', () => {
        const store = useCashRegisterStore();
        store.openRegister('emp-001', 100000, 'Morning Shift');

        expect(store.isOpen).toBe(true);
        expect(store.currentSession?.openingBalance.toNumber()).toBe(100000);
        expect(store.currentBalance.toNumber()).toBe(100000);
    });

    it('should track income and expenses', () => {
        const store = useCashRegisterStore();
        store.openRegister('emp-001', 100000); // 100k

        // Add Income (Sale)
        store.addIncome(50000, 'Sale #1');

        // register Expense
        store.registerExpense(20000, 'Pago Proveedor', 'Suppliers');

        expect(store.totalIncome.toNumber()).toBe(50000);
        expect(store.totalExpenses.toNumber()).toBe(20000);

        // Balance = 100 + 50 - 20 = 130
        expect(store.currentBalance.toNumber()).toBe(130000);
    });

    it('should close register and calculate discrepancy', () => {
        const store = useCashRegisterStore();
        store.openRegister('emp-001', 100000);
        store.addIncome(50000, 'Sale');
        // Calculated: 150k

        // Close with PHYSICAL count of 149000 (Missing 1000)
        const session = store.closeRegister(149000, 'Lost a coin');

        expect(store.isOpen).toBe(false);
        expect(session.closingBalance?.toNumber()).toBe(149000);
        expect(session.discrepancy?.toNumber()).toBe(-1000);
        expect(session.status).toBe('closed');
    });
});

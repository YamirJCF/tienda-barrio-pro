import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';
import { expensesSerializer } from '../data/serializers';

export interface Expense {
    id: number;
    description: string;
    amount: Decimal;
    category: string;
    note: string;
    timestamp: string;
    date: string; // YYYY-MM-DD
}

export const useExpensesStore = defineStore('expenses', () => {
    const expenses = ref<Expense[]>([]);
    const nextId = ref(1);

    // Computed
    const todayDate = computed(() => {
        return new Date().toISOString().split('T')[0];
    });

    const todayExpenses = computed(() => {
        return expenses.value.filter(e => e.date === todayDate.value);
    });

    const todayTotal = computed(() => {
        return todayExpenses.value.reduce((sum, e) => sum.plus(e.amount), new Decimal(0));
    });

    const todayCount = computed(() => todayExpenses.value.length);

    // Methods
    const addExpense = (data: Omit<Expense, 'id' | 'timestamp' | 'date'>) => {
        const now = new Date();
        const newExpense: Expense = {
            ...data,
            id: nextId.value++,
            timestamp: now.toISOString(),
            date: now.toISOString().split('T')[0],
        };
        expenses.value.push(newExpense);
        return newExpense;
    };

    const deleteExpense = (id: number) => {
        const index = expenses.value.findIndex(e => e.id === id);
        if (index !== -1) {
            expenses.value.splice(index, 1);
        }
    };

    const getExpensesByDate = (date: string) => {
        return expenses.value.filter(e => e.date === date);
    };

    const getTotalByDate = (date: string) => {
        return getExpensesByDate(date).reduce((sum, e) => sum.plus(e.amount), new Decimal(0));
    };

    // Clear expenses for the day (when closing cash register)
    const clearTodayExpenses = () => {
        expenses.value = expenses.value.filter(e => e.date !== todayDate.value);
    };

    return {
        expenses,
        nextId,
        todayDate,
        todayExpenses,
        todayTotal,
        todayCount,
        addExpense,
        deleteExpense,
        getExpensesByDate,
        getTotalByDate,
        clearTodayExpenses,
    };
}, {
    persist: {
        key: 'tienda-expenses',
        storage: localStorage,
        serializer: expensesSerializer,
    },
});


import type { Expense } from '../../stores/expenses';
import { toDecimal } from './decimalSerializer';
import { Decimal } from 'decimal.js';

interface SerializedExpense {
    id: number;
    description: string;
    amount: string;
    category: string;
    note: string;
    timestamp: string;
    date: string;
}

export interface ExpensesState {
    expenses: Expense[];
    nextId: number;
}

interface SerializedExpensesState {
    expenses: SerializedExpense[];
    nextId: number;
}

export const serializeExpense = (expense: Expense): SerializedExpense => ({
    id: expense.id,
    description: expense.description,
    amount: expense.amount.toString(),
    category: expense.category,
    note: expense.note,
    timestamp: expense.timestamp,
    date: expense.date,
});

export const deserializeExpense = (data: SerializedExpense): Expense => ({
    id: data.id,
    description: data.description,
    amount: toDecimal(data.amount),
    category: data.category,
    note: data.note,
    timestamp: data.timestamp,
    date: data.date,
});

export const expensesSerializer = {
    serialize: (state: ExpensesState): string => {
        const serialized: SerializedExpensesState = {
            expenses: state.expenses.map(serializeExpense),
            nextId: state.nextId,
        };
        return JSON.stringify(serialized);
    },

    deserialize: (value: string): ExpensesState => {
        const data: SerializedExpensesState = JSON.parse(value);
        return {
            expenses: data.expenses.map(deserializeExpense),
            nextId: data.nextId,
        };
    },
};

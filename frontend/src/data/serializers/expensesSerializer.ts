import type { Expense } from '../repositories/expenseRepository';
import { toDecimal } from './decimalSerializer';
import { Decimal } from 'decimal.js';

interface SerializedExpense {
  id: string;
  description: string;
  amount: string;
  category: string;
  timestamp: string;
}

export interface ExpensesState {
  expenses: Expense[];
  // nextId removed as we use UUIDs
}

interface SerializedExpensesState {
  expenses: SerializedExpense[];
}

export const serializeExpense = (expense: Expense): SerializedExpense => ({
  id: expense.id,
  description: expense.description,
  amount: expense.amount.toString(),
  category: expense.category,
  timestamp: expense.created_at || new Date().toISOString(),
});

export const deserializeExpense = (data: SerializedExpense): Expense => ({
  id: data.id,
  store_id: '', // Mising in serialization, will need to be re-hydrated or ignored if just for display
  description: data.description,
  amount: toDecimal(data.amount).toNumber(),
  category: data.category,
  created_at: data.timestamp
});

export const expensesSerializer = {
  serialize: (state: ExpensesState): string => {
    const serialized: SerializedExpensesState = {
      expenses: state.expenses.map(serializeExpense),
    };
    return JSON.stringify(serialized);
  },

  deserialize: (value: string): ExpensesState => {
    const data: SerializedExpensesState = JSON.parse(value);
    return {
      expenses: data.expenses.map(deserializeExpense),
    };
  },
};

import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';
import { expenseRepository, type Expense } from '../data/repositories/expenseRepository';
import { useAuthStore } from './auth';
import { logger } from '../utils/logger';

export const useExpensesStore = defineStore('expenses', () => {
  const expenses = ref<Expense[]>([]);
  const isLoading = ref(false);
  const error = ref<string | null>(null);

  const todayTotal = computed(() => {
    return expenses.value.reduce((acc, expense) => {
      return acc.plus(new Decimal(expense.amount));
    }, new Decimal(0));
  });

  const fetchTodayExpenses = async () => {
    const authStore = useAuthStore();
    if (!authStore.currentUser?.storeId) return;

    isLoading.value = true;
    try {
      expenses.value = await expenseRepository.getTodayExpenses(authStore.currentUser.storeId);
    } catch (e: any) {
      error.value = e.message;
      logger.error('[ExpensesStore] Fetch failed', e);
    } finally {
      isLoading.value = false;
    }
  };

  const addExpense = async (data: { amount: number, description: string, category: string }) => {
    const authStore = useAuthStore();
    if (!authStore.currentUser?.storeId) return null;

    isLoading.value = true;
    try {
      const newExpense = await expenseRepository.createExpense({
        store_id: authStore.currentUser.storeId,
        amount: data.amount,
        description: data.description,
        category: data.category,
        created_by: authStore.currentUser.id
      });

      if (newExpense) {
        // Optimistic update if repo returns it (it should)
        // If offline it might return null depending on repo implementation, but we standardized it
        // Actually repo generic create returns T
        expenses.value.push(newExpense);
      }
      return newExpense;
    } catch (e: any) {
      error.value = e.message;
      throw e;
    } finally {
      isLoading.value = false;
    }
  };

  const clearTodayExpenses = () => {
    expenses.value = [];
  };

  return {
    expenses,
    isLoading,
    error,
    todayTotal,
    fetchTodayExpenses,
    addExpense,
    clearTodayExpenses
  };
});

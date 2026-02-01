/**
 * SPEC-009: Store para registrar cierres de caja
 * Persistencia en localStorage de todos los arqueos realizados
 */
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

export interface CashClose {
  id: string;
  openedAt: string;
  closedAt: string;
  initialAmount: number;
  expectedAmount: number;
  actualAmount: number;
  difference: number;
  totalSales: number;
  totalCashSales: number;
  totalCardSales: number;
  salesCount: number;
  closedBy?: string;
  notes?: string;
}

export const useCashClosesStore = defineStore(
  'cashCloses',
  () => {
    // State
    const closes = ref<CashClose[]>([]);

    // Computed
    const closesByDate = computed(() =>
      [...closes.value].sort(
        (a, b) => new Date(b.closedAt).getTime() - new Date(a.closedAt).getTime(),
      ),
    );

    const totalDifferences = computed(() => closes.value.reduce((sum, c) => sum + c.difference, 0));

    const closesThisMonth = computed(() => {
      const now = new Date();
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
      return closes.value.filter((c) => new Date(c.closedAt) >= startOfMonth);
    });

    // Actions
    const addClose = (close: Omit<CashClose, 'id'>): CashClose => {
      const newClose: CashClose = {
        ...close,
        id: `close-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      };
      closes.value.push(newClose);
      return newClose;
    };

    const removeClose = (id: string) => {
      const index = closes.value.findIndex((c) => c.id === id);
      if (index !== -1) {
        closes.value.splice(index, 1);
      }
    };

    const getClosesByDateRange = (startDate: Date, endDate: Date): CashClose[] => {
      return closes.value.filter((c) => {
        const closeDate = new Date(c.closedAt);
        return closeDate >= startDate && closeDate <= endDate;
      });
    };

    return {
      closes,
      closesByDate,
      totalDifferences,
      closesThisMonth,
      addClose,
      removeClose,
      getClosesByDateRange,
    };
  },
  {
    persist: {
      key: 'tienda-cash-closes',
      storage: localStorage,
    },
  },
);

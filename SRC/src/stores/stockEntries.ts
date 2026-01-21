/**
 * T-014: Store para registrar entradas de stock
 * Persistencia en localStorage de todas las entradas de inventario
 */
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

export interface StockEntry {
  id: string;
  productId: number;
  productName: string;
  quantity: number; // Puede ser positivo (entrada) o negativo (salida/ajuste)
  type: 'purchase' | 'sale' | 'adjustment' | 'return' | 'loss';
  reason?: string;
  unitCost?: number;
  totalCost?: number;
  createdAt: string;
  createdBy?: string;
}

export const useStockEntriesStore = defineStore(
  'stockEntries',
  () => {
    // State
    const entries = ref<StockEntry[]>([]);

    // Computed
    const entriesByDate = computed(() =>
      [...entries.value].sort(
        (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
      ),
    );

    const entriesByProduct = computed(
      () => (productId: number) => entries.value.filter((e) => e.productId === productId),
    );

    const totalPurchases = computed(() =>
      entries.value
        .filter((e) => e.type === 'purchase')
        .reduce((sum, e) => sum + (e.totalCost || 0), 0),
    );

    // Actions
    const addEntry = (entry: Omit<StockEntry, 'id' | 'createdAt'>): StockEntry => {
      const newEntry: StockEntry = {
        ...entry,
        id: `entry-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
        createdAt: new Date().toISOString(),
      };
      entries.value.push(newEntry);
      return newEntry;
    };

    const removeEntry = (id: string) => {
      const index = entries.value.findIndex((e) => e.id === id);
      if (index !== -1) {
        entries.value.splice(index, 1);
      }
    };

    const getEntriesForProduct = (productId: number): StockEntry[] => {
      return entries.value.filter((e) => e.productId === productId);
    };

    const getEntriesByDateRange = (startDate: Date, endDate: Date): StockEntry[] => {
      return entries.value.filter((e) => {
        const entryDate = new Date(e.createdAt);
        return entryDate >= startDate && entryDate <= endDate;
      });
    };

    // Clear all entries (for testing/reset)
    const clearAllEntries = () => {
      entries.value = [];
    };

    return {
      entries,
      entriesByDate,
      entriesByProduct,
      totalPurchases,
      addEntry,
      removeEntry,
      getEntriesForProduct,
      getEntriesByDateRange,
      clearAllEntries,
    };
  },
  {
    persist: {
      key: 'tienda-stock-entries',
      storage: localStorage,
    },
  },
);

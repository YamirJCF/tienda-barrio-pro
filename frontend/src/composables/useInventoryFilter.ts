import { ref, computed, watch } from 'vue';
import { useInventoryStore } from '../stores/inventory';
import { Decimal } from 'decimal.js';
import { parseShortcuts, type ShortcutFilters } from '../utils/inventoryShortcutParser';

export type InventorySortOption =
  | 'created_desc'
  | 'urgency_asc'
  | 'name_asc'
  | 'name_desc'
  | 'stock_asc'
  | 'stock_desc'
  | 'price_asc'
  | 'price_desc';

export interface ComparisonRule {
  op: '<' | '<=' | '>' | '>=' | '=';
  value: number;
}

// Persistencia en memoria de sesión para el ordenamiento (D4)
const persistedSortBy = ref<InventorySortOption>('created_desc');

export function resetInventorySortBaseline() {
  persistedSortBy.value = 'created_desc';
}

export function useInventoryFilter() {
  const inventoryStore = useInventoryStore();

  // State
  const searchQuery = ref('');
  const selectedCategory = ref('all');
  const onlyLowStock = ref(false);
  const includeInactive = ref(false);
  const sortBy = persistedSortBy;

  // Nuevas reglas de atajos internos (Opción C)
  const brandFilter = ref<string | null>(null);
  const pluFilter = ref<string | null>(null);
  const stockRule = ref<ComparisonRule | null>(null);
  const priceRule = ref<ComparisonRule | null>(null);

  // Callback de notificación si una categoría desaparece
  let onCategoryRemovedCallback: ((cat: string) => void) | null = null;
  const onCategoryRemoved = (cb: (cat: string) => void) => {
    onCategoryRemovedCallback = cb;
  };

  // Helper: Safely convert Decimal or unknown to numeric value
  const toNum = (val: any): number => {
    if (val instanceof Decimal) return val.toNumber();
    if (val && typeof val === 'object' && typeof val.toNumber === 'function') {
      return val.toNumber();
    }
    const n = Number(val);
    return isNaN(n) ? 0 : n;
  };

  // Helper: Check if product is in low stock condition
  const isProductLowStock = (stock: any, minStock: any): boolean => {
    return toNum(stock) <= toNum(minStock);
  };

  // Helper: Match comparison rule
  const matchesRule = (val: number, rule: ComparisonRule | null): boolean => {
    if (!rule) return true;
    switch (rule.op) {
      case '<':
        return val < rule.value;
      case '<=':
        return val <= rule.value;
      case '>':
        return val > rule.value;
      case '>=':
        return val >= rule.value;
      case '=':
        return val === rule.value;
    }
  };

  // Computed: Dynamic category list based on current visibility (active vs all)
  const categories = computed(() => {
    const pool = inventoryStore.products.filter(
      (p) => includeInactive.value || p.isActive !== false
    );
    const cats = new Set(pool.map((p) => p.category || 'Sin categoría'));
    return ['all', ...Array.from(cats)];
  });

  // Watcher: Auto-restablecimiento a 'all' si la categoría seleccionada desaparece
  watch(categories, (newCats) => {
    if (selectedCategory.value !== 'all' && !newCats.includes(selectedCategory.value)) {
      const removed = selectedCategory.value;
      selectedCategory.value = 'all';
      if (onCategoryRemovedCallback) {
        onCategoryRemovedCallback(removed);
      }
    }
  });

  // Computed: Count active filters (diverging from baseline defaults - orden no cuenta)
  const activeFiltersCount = computed(() => {
    let count = 0;
    if (selectedCategory.value !== 'all') count++;
    if (onlyLowStock.value) count++;
    if (includeInactive.value) count++;
    if (brandFilter.value !== null) count++;
    if (pluFilter.value !== null) count++;
    if (stockRule.value !== null) count++;
    if (priceRule.value !== null) count++;
    return count;
  });

  // Method: Reset all filters to initial baseline (sortBy se conserva por D4)
  const resetFilters = () => {
    searchQuery.value = '';
    selectedCategory.value = 'all';
    onlyLowStock.value = false;
    includeInactive.value = false;
    brandFilter.value = null;
    pluFilter.value = null;
    stockRule.value = null;
    priceRule.value = null;
  };

  // Method: Aplicar string de atajos internos y actualizar estado
  const applyShortcutString = (rawInput: string, isAdmin: boolean) => {
    const res = parseShortcuts(rawInput, { isAdmin });

    if (res.filters.onlyLowStock !== undefined) {
      onlyLowStock.value = res.filters.onlyLowStock;
    }
    if (res.filters.stockRule !== undefined) {
      stockRule.value = res.filters.stockRule;
    }
    if (res.filters.priceRule !== undefined) {
      priceRule.value = res.filters.priceRule;
    }
    if (res.filters.brandFilter !== undefined) {
      brandFilter.value = res.filters.brandFilter;
    }
    if (res.filters.pluFilter !== undefined) {
      pluFilter.value = res.filters.pluFilter;
    }
    if (res.filters.includeInactive !== undefined) {
      includeInactive.value = res.filters.includeInactive;
    }

    // Texto libre restante actualiza searchQuery
    searchQuery.value = res.freeText;

    return {
      remainingText: res.freeText,
      errors: res.errors,
      warnings: res.warnings,
    };
  };

  // Computed: Filtered and sorted products reactive projection (100% in-memory)
  const filteredProducts = computed(() => {
    let products = inventoryStore.products;

    // 1. Inactive filter (unless includeInactive is enabled by Admin)
    if (!includeInactive.value) {
      products = products.filter((p) => p.isActive !== false);
    }

    // 2. Search filter (text match on name, plu, brand, category con lógica AND)
    const query = searchQuery.value.trim().toLowerCase();
    if (query) {
      const words = query.split(/\s+/).filter(Boolean);
      products = products.filter((p) => {
        const name = (p.name || '').toLowerCase();
        const plu = (p.plu || '').toLowerCase();
        const brand = (p.brand || '').toLowerCase();
        const category = (p.category || '').toLowerCase();

        return words.every(
          (w) =>
            name.includes(w) ||
            plu.includes(w) ||
            brand.includes(w) ||
            category.includes(w)
        );
      });
    }

    // 3. Category filter
    if (selectedCategory.value !== 'all') {
      products = products.filter(
        (p) => (p.category || 'Sin categoría') === selectedCategory.value
      );
    }

    // 4. Low stock filter
    if (onlyLowStock.value) {
      products = products.filter((p) => isProductLowStock(p.stock, p.minStock));
    }

    // 5. Atajos internos específicos
    if (stockRule.value) {
      products = products.filter((p) =>
        matchesRule(toNum(p.stock), stockRule.value)
      );
    }

    if (priceRule.value) {
      products = products.filter((p) =>
        matchesRule(toNum(p.price), priceRule.value)
      );
    }

    if (brandFilter.value) {
      const bQuery = brandFilter.value.toLowerCase();
      products = products.filter((p) =>
        (p.brand || '').toLowerCase().includes(bQuery)
      );
    }

    if (pluFilter.value) {
      products = products.filter((p) =>
        (p.plu || '').startsWith(pluFilter.value!)
      );
    }

    // 6. Sorting
    const sortedProducts = [...products].sort((a, b) => {
      switch (sortBy.value) {
        case 'urgency_asc': {
          const urgencyA = toNum(a.stock) - toNum(a.minStock);
          const urgencyB = toNum(b.stock) - toNum(b.minStock);
          if (urgencyA !== urgencyB) {
            return urgencyA - urgencyB;
          }
          return (a.name || '').localeCompare(b.name || '', 'es', {
            sensitivity: 'base',
          });
        }
        case 'name_asc':
          return (a.name || '').localeCompare(b.name || '', 'es', {
            sensitivity: 'base',
          });
        case 'name_desc':
          return (b.name || '').localeCompare(a.name || '', 'es', {
            sensitivity: 'base',
          });
        case 'stock_asc':
          return toNum(a.stock) - toNum(b.stock);
        case 'stock_desc':
          return toNum(b.stock) - toNum(a.stock);
        case 'price_asc':
          return toNum(a.price) - toNum(b.price);
        case 'price_desc':
          return toNum(b.price) - toNum(a.price);
        case 'created_desc':
        default: {
          const dateA = a.createdAt ? new Date(a.createdAt).getTime() : 0;
          const dateB = b.createdAt ? new Date(b.createdAt).getTime() : 0;
          return dateB - dateA;
        }
      }
    });

    return sortedProducts;
  });

  // Helpers
  const getCategoryLabel = (category: string) => {
    if (category === 'all') return 'Todas';
    return category;
  };

  return {
    searchQuery,
    selectedCategory,
    onlyLowStock,
    includeInactive,
    sortBy,
    brandFilter,
    pluFilter,
    stockRule,
    priceRule,
    activeFiltersCount,
    resetFilters,
    applyShortcutString,
    onCategoryRemoved,
    categories,
    filteredProducts,
    getCategoryLabel,
  };
}

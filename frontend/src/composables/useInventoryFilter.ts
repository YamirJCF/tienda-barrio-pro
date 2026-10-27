import { ref, computed } from 'vue';
import { useInventoryStore } from '../stores/inventory';
import { Decimal } from 'decimal.js';

export type InventorySortOption =
    | 'created_desc'
    | 'name_asc'
    | 'name_desc'
    | 'stock_asc'
    | 'stock_desc'
    | 'price_asc'
    | 'price_desc';

export function useInventoryFilter() {
    const inventoryStore = useInventoryStore();

    // State
    const searchQuery = ref('');
    const selectedCategory = ref('all');
    const onlyLowStock = ref(false);
    const includeInactive = ref(false);
    const sortBy = ref<InventorySortOption>('created_desc');

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

    // Computed: Dynamic category list based on current visibility (active vs all)
    const categories = computed(() => {
        const pool = inventoryStore.products.filter(
            (p) => includeInactive.value || p.isActive !== false
        );
        const cats = new Set(pool.map((p) => p.category || 'Sin categoría'));
        return ['all', ...Array.from(cats)];
    });

    // Computed: Count active filters (diverging from baseline defaults)
    const activeFiltersCount = computed(() => {
        let count = 0;
        if (selectedCategory.value !== 'all') count++;
        if (onlyLowStock.value) count++;
        if (includeInactive.value) count++;
        if (sortBy.value !== 'created_desc') count++;
        return count;
    });

    // Method: Reset all filters to initial baseline
    const resetFilters = () => {
        searchQuery.value = '';
        selectedCategory.value = 'all';
        onlyLowStock.value = false;
        includeInactive.value = false;
        sortBy.value = 'created_desc';
    };

    // Computed: Filtered and sorted products reactive projection (100% in-memory)
    const filteredProducts = computed(() => {
        let products = inventoryStore.products;

        // 1. Inactive filter (unless includeInactive is enabled by Admin)
        if (!includeInactive.value) {
            products = products.filter((p) => p.isActive !== false);
        }

        // 2. Search filter (text match on name, plu, brand)
        const query = searchQuery.value.trim().toLowerCase();
        if (query) {
            products = products.filter((p) => {
                const nameMatch = p.name ? p.name.toLowerCase().includes(query) : false;
                const pluMatch = p.plu ? p.plu.toLowerCase().includes(query) : false;
                const brandMatch = p.brand ? p.brand.toLowerCase().includes(query) : false;
                return nameMatch || pluMatch || brandMatch;
            });
        }

        // 3. Category filter
        if (selectedCategory.value !== 'all') {
            products = products.filter((p) => (p.category || 'Sin categoría') === selectedCategory.value);
        }

        // 4. Low stock filter
        if (onlyLowStock.value) {
            products = products.filter((p) => isProductLowStock(p.stock, p.minStock));
        }

        // 5. Sorting
        const sortedProducts = [...products].sort((a, b) => {
            switch (sortBy.value) {
                case 'name_asc':
                    return (a.name || '').localeCompare(b.name || '', 'es', { sensitivity: 'base' });
                case 'name_desc':
                    return (b.name || '').localeCompare(a.name || '', 'es', { sensitivity: 'base' });
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
        activeFiltersCount,
        resetFilters,
        categories,
        filteredProducts,
        getCategoryLabel,
    };
}

import { ref, computed } from 'vue';
import { useInventoryStore } from '../stores/inventory';

export function useInventoryFilter() {
    const inventoryStore = useInventoryStore();

    // State
    const searchQuery = ref('');
    const selectedCategory = ref('all');

    // Computed
    const categories = computed(() => {
        const cats = new Set(inventoryStore.products.map((p) => p.category || 'Sin categoría'));
        return ['all', ...Array.from(cats)];
    });

    const filteredProducts = computed(() => {
        let products = inventoryStore.products;

        // Filter by search
        if (searchQuery.value.trim()) {
            products = inventoryStore.searchProducts(searchQuery.value);
        }

        // Filter by category
        if (selectedCategory.value !== 'all') {
            products = products.filter((p) => (p.category || 'Sin categoría') === selectedCategory.value);
        }

        return products;
    });

    // Helpers
    const getCategoryLabel = (category: string) => {
        if (category === 'all') return 'Todas';
        return category;
    };

    return {
        searchQuery,
        selectedCategory,
        categories,
        filteredProducts,
        getCategoryLabel,
    };
}

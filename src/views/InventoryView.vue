<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useInventoryStore } from '../stores/inventory';
import ProductFormModal from '../components/ProductFormModal.vue';
import BottomNav from '../components/BottomNav.vue';
import { Decimal } from 'decimal.js';

const router = useRouter();
const inventoryStore = useInventoryStore();

// Initialize inventory
onMounted(() => {
  inventoryStore.initializeSampleData();
});

// State
const searchQuery = ref('');
const selectedCategory = ref('all');
const showProductModal = ref(false);
const editingProductId = ref<number | undefined>(undefined);

// Computed
const categories = computed(() => {
  const cats = new Set(inventoryStore.products.map(p => p.category || 'Sin categoría'));
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
    products = products.filter(p => 
      (p.category || 'Sin categoría') === selectedCategory.value
    );
  }

  return products;
});

// Methods
const goToDashboard = () => {
  router.push('/');
};

const formatCurrency = (val: Decimal) => {
  return val.toDecimalPlaces(0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
};

const openNewProduct = () => {
  editingProductId.value = undefined;
  showProductModal.value = true;
};

const openEditProduct = (id: number) => {
  editingProductId.value = id;
  showProductModal.value = true;
};

const deleteProduct = (id: number) => {
  if (confirm('¿Estás seguro de eliminar este producto?')) {
    inventoryStore.deleteProduct(id);
  }
};

const getCategoryLabel = (category: string) => {
  if (category === 'all') return 'Todas';
  return category;
};
</script>

<template>
  <div class="flex flex-col h-screen bg-background-light dark:bg-background-dark pb-24">
    <!-- Header with Search -->
    <header class="sticky top-0 z-30 bg-white dark:bg-surface-dark border-b border-gray-200 dark:border-gray-800 shadow-sm">
      <div class="px-4 py-3 flex items-center gap-3">
        <button
          @click="goToDashboard"
          aria-label="Volver al Dashboard"
          class="flex items-center justify-center -ml-2 p-2 rounded-full text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <span class="material-symbols-outlined">arrow_back</span>
        </button>
        <div class="relative flex-1">
          <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
            <span class="material-symbols-outlined text-gray-400 text-[20px]">search</span>
          </div>
          <input
            v-model="searchQuery"
            type="text"
            class="block w-full rounded-lg border-none bg-gray-100 dark:bg-slate-800 py-2 pl-10 pr-3 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-primary placeholder-slate-500"
            placeholder="Buscar producto..."
          />
        </div>
        <button class="p-2 rounded-full bg-gray-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300">
          <span class="material-symbols-outlined text-[20px]">filter_list</span>
        </button>
      </div>

      <!-- Category Tags -->
      <div class="flex gap-2 overflow-x-auto px-4 pb-3 no-scrollbar">
        <button
          v-for="cat in categories"
          :key="cat"
          class="whitespace-nowrap rounded-full px-4 py-1.5 text-xs font-medium shadow-sm transition-colors"
          :class="selectedCategory === cat 
            ? 'bg-primary text-white' 
            : 'bg-white dark:bg-slate-800 border border-gray-200 dark:border-gray-700 text-slate-600 dark:text-slate-300 hover:bg-gray-50 dark:hover:bg-slate-700'"
          @click="selectedCategory = cat"
        >
          {{ getCategoryLabel(cat) }}
        </button>
      </div>
    </header>

    <!-- Products List -->
    <main class="flex-1 overflow-y-auto p-4 flex flex-col gap-3">
      <div class="flex justify-between items-end px-1">
        <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
          Productos ({{ filteredProducts.length }})
        </span>
        <span v-if="inventoryStore.lowStockProducts.length > 0" class="text-xs font-medium text-red-500">
          {{ inventoryStore.lowStockProducts.length }} con stock bajo
        </span>
      </div>

      <!-- Empty State -->
      <div v-if="filteredProducts.length === 0" class="flex flex-col items-center justify-center h-64 text-gray-400">
        <span class="material-symbols-outlined text-6xl mb-3 opacity-30">inventory_2</span>
        <p class="text-sm">{{ searchQuery ? 'No se encontraron productos' : 'No hay productos aún' }}</p>
        <button
          v-if="!searchQuery"
          class="mt-4 px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium"
          @click="openNewProduct"
        >
          Crear primer producto
        </button>
      </div>

      <!-- Product Cards -->
      <article
        v-for="product in filteredProducts"
        :key="product.id"
        class="bg-white dark:bg-surface-dark rounded-xl p-4 shadow-sm border border-gray-100 dark:border-gray-800 flex flex-col gap-3 active:scale-[0.99] transition-transform"
        @click="openEditProduct(product.id)"
      >
        <div class="flex justify-between items-start gap-4">
          <div class="flex-1">
            <h3 class="text-slate-900 dark:text-white text-base font-bold leading-tight">{{ product.name }}</h3>
            <div class="flex items-center gap-2 mt-1">
              <span v-if="product.brand" class="text-slate-500 text-xs font-medium">{{ product.brand }}</span>
              <span v-if="product.brand && product.plu" class="text-slate-300">|</span>
              <span v-if="product.plu" class="text-slate-400 text-xs font-mono">PLU: {{ product.plu }}</span>
            </div>
            <span v-if="product.category" class="inline-block mt-1 px-2 py-0.5 bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300 text-[10px] font-medium rounded">
              {{ product.category }}
            </span>
          </div>
          <div class="text-right">
            <span class="text-slate-900 dark:text-white font-bold text-sm bg-gray-100 dark:bg-slate-700 px-2 py-1 rounded block w-fit ml-auto">
              ${{ formatCurrency(product.price) }}
            </span>
          </div>
        </div>
        <div class="flex items-center justify-between pt-2 border-t border-gray-50 dark:border-gray-800">
          <span
            :class="product.stock <= product.minStock ? 'text-red-500' : 'text-primary'"
            class="font-bold text-lg leading-none"
          >
            {{ product.stock }} <span class="text-xs font-medium opacity-70">{{ product.unit }}</span>
          </span>
          <button
            class="text-slate-400 hover:text-red-500 p-2 -mr-2 rounded-full hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
            @click.stop="deleteProduct(product.id)"
          >
            <span class="material-symbols-outlined text-[20px]">delete</span>
          </button>
        </div>
      </article>
    </main>

    <!-- FAB (Floating Action Button) -->
    <div class="absolute bottom-24 right-4 z-40">
      <button
        class="flex h-14 w-14 items-center justify-center rounded-full bg-primary text-white shadow-lg shadow-blue-500/40 hover:bg-blue-600 transition-all active:scale-90"
        @click="openNewProduct"
      >
        <span class="material-symbols-outlined text-[32px]">add</span>
      </button>
    </div>

    <!-- Bottom Navigation -->
    <BottomNav />

    <!-- Product Form Modal -->
    <ProductFormModal
      v-model="showProductModal"
      :product-id="editingProductId"
      @saved="showProductModal = false"
    />
  </div>
</template>

<style scoped>
.no-scrollbar::-webkit-scrollbar {
  display: none;
}
.no-scrollbar {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
</style>
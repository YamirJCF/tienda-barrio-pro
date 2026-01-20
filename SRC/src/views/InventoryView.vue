<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useInventoryStore } from '../stores/inventory';
import { useAuthStore } from '../stores/auth';
import ProductFormModal from '../components/ProductFormModal.vue';
import BottomNav from '../components/BottomNav.vue';
import NoPermissionOverlay from '../components/ui/NoPermissionOverlay.vue';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useQuantityFormat } from '../composables/useQuantityFormat';
import { Decimal } from 'decimal.js';

const router = useRouter();
const inventoryStore = useInventoryStore();
const authStore = useAuthStore();
const { formatCurrency } = useCurrencyFormat();
const { formatStock } = useQuantityFormat();

// Permisos del usuario
const canViewInventory = computed(() => authStore.canViewInventory);

// WO-006: initializeSampleData ELIMINADA - SPEC-007

// State
const searchQuery = ref('');
const selectedCategory = ref('all');
const showProductModal = ref(false);
const editingProductId = ref<number | undefined>(undefined);
// T-010: State para modal de eliminar
const showDeleteModal = ref(false);
const productToDelete = ref<{ id: number; name: string } | null>(null);

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

const openNewProduct = () => {
  editingProductId.value = undefined;
  showProductModal.value = true;
};

const openEditProduct = (id: number) => {
  editingProductId.value = id;
  showProductModal.value = true;
};

const deleteProduct = (id: number) => {
  const product = inventoryStore.products.find(p => p.id === id);
  if (product) {
    productToDelete.value = { id, name: product.name };
    showDeleteModal.value = true;
  }
};

// T-010: Confirmar eliminación
const confirmDelete = () => {
  if (productToDelete.value) {
    inventoryStore.deleteProduct(productToDelete.value.id);
  }
  showDeleteModal.value = false;
  productToDelete.value = null;
};

const cancelDelete = () => {
  showDeleteModal.value = false;
  productToDelete.value = null;
};

const getCategoryLabel = (category: string) => {
  if (category === 'all') return 'Todas';
  return category;
};
</script>

<template>
  <div class="flex flex-col h-screen bg-background-light dark:bg-background-dark pb-24 relative">

    <!-- No Permission Overlay -->
    <NoPermissionOverlay v-if="!canViewInventory"
      message="No tienes permiso para ver el inventario. Contacta a tu administrador si necesitas acceso."
      @go-back="goToDashboard" />

    <!-- Header with Search -->
    <header
      class="sticky top-0 z-30 bg-white dark:bg-surface-dark border-b border-gray-200 dark:border-gray-800 shadow-sm">
      <div class="px-4 py-3 flex items-center gap-3">
        <button @click="goToDashboard" aria-label="Volver al Dashboard"
          class="flex items-center justify-center -ml-2 p-2 rounded-full text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors">
          <span class="material-symbols-outlined">arrow_back</span>
        </button>
        <div class="relative flex-1">
          <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
            <span class="material-symbols-outlined text-gray-400 text-[20px]">search</span>
          </div>
          <input v-model="searchQuery" type="text"
            class="block w-full rounded-lg border-none bg-gray-100 dark:bg-slate-800 py-2 pl-10 pr-3 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-primary placeholder-slate-500"
            placeholder="Buscar producto..." />
        </div>
        <button class="p-2 rounded-full bg-gray-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300">
          <span class="material-symbols-outlined text-[20px]">filter_list</span>
        </button>
      </div>

      <!-- Category Tags -->
      <div class="flex gap-2 overflow-x-auto px-4 pb-3 no-scrollbar">
        <button v-for="cat in categories" :key="cat"
          class="whitespace-nowrap rounded-full px-4 py-1.5 text-xs font-medium shadow-sm transition-colors"
          :class="selectedCategory === cat
            ? 'bg-primary text-white'
            : 'bg-white dark:bg-slate-800 border border-gray-200 dark:border-gray-700 text-slate-600 dark:text-slate-300 hover:bg-gray-50 dark:hover:bg-slate-700'" @click="selectedCategory = cat">
          {{ getCategoryLabel(cat) }}
        </button>
      </div>
    </header>

    <!-- Products List -->
    <main class="flex-1 overflow-y-auto p-4 flex flex-col gap-3 no-scrollbar">
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
        <button v-if="!searchQuery" class="mt-4 px-4 py-2 bg-primary text-white rounded-lg text-sm font-medium"
          @click="openNewProduct">
          Crear primer producto
        </button>
      </div>

      <!-- Product Cards with Virtual Scrolling -->
      <RecycleScroller v-if="filteredProducts.length > 0" class="flex-1" :items="filteredProducts" :item-size="140"
        key-field="id" v-slot="{ item: product }">
        <article
          class="bg-white dark:bg-surface-dark rounded-xl p-4 shadow-sm border border-gray-100 dark:border-gray-800 flex flex-col gap-3 active:scale-[0.99] transition-transform mb-3 mx-4"
          @click="openEditProduct(product.id)">
          <div class="flex justify-between items-start gap-4">
            <div class="flex-1">
              <h3 class="text-slate-900 dark:text-white text-base font-bold leading-tight">{{ product.name }}</h3>
              <div class="flex items-center gap-2 mt-1">
                <span v-if="product.brand" class="text-slate-500 text-xs font-medium">{{ product.brand }}</span>
                <span v-if="product.brand && product.plu" class="text-slate-300">|</span>
                <span v-if="product.plu" class="text-slate-400 text-xs font-mono">PLU: {{ product.plu }}</span>
              </div>
              <span v-if="product.category"
                class="inline-block mt-1 px-2 py-0.5 bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300 text-[10px] font-medium rounded">
                {{ product.category }}
              </span>
            </div>
            <div class="text-right">
              <span
                class="text-slate-900 dark:text-white font-bold text-sm bg-gray-100 dark:bg-slate-700 px-2 py-1 rounded block w-fit ml-auto">
                ${{ formatCurrency(product.price) }}
              </span>
            </div>
          </div>
          <div class="flex items-center justify-between pt-2 border-t border-gray-50 dark:border-gray-800">
            <span
              :class="product.stock.lte ? product.stock.lte(product.minStock) ? 'text-red-500' : 'text-primary' : product.stock <= product.minStock ? 'text-red-500' : 'text-primary'"
              class="font-bold text-lg leading-none">
              {{ formatStock(product.stock, product.measurementUnit) }} <span class="text-xs font-medium opacity-70">{{
                product.measurementUnit || 'un' }}</span>
            </span>
            <button
              class="text-slate-400 hover:text-red-500 p-2 -mr-2 rounded-full hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
              @click.stop="deleteProduct(product.id)">
              <span class="material-symbols-outlined text-[20px]">delete</span>
            </button>
          </div>
        </article>
      </RecycleScroller>
    </main>

    <!-- FAB (Floating Action Buttons) -->
    <div class="fixed bottom-24 right-4 z-40 flex flex-col gap-3">
      <!-- Stock Entry FAB -->
      <button
        class="flex h-12 w-12 items-center justify-center rounded-full bg-emerald-500 text-white shadow-lg shadow-emerald-500/40 hover:bg-emerald-600 transition-all active:scale-90"
        @click="router.push('/stock-entry')" title="Entrada de inventario">
        <span class="material-symbols-outlined text-[24px]">inventory</span>
      </button>
      <!-- Add Product FAB -->
      <button
        class="flex h-14 w-14 items-center justify-center rounded-full bg-primary text-white shadow-lg shadow-blue-500/40 hover:bg-blue-600 transition-all active:scale-90"
        @click="openNewProduct" title="Agregar producto">
        <span class="material-symbols-outlined text-[32px]">add</span>
      </button>
    </div>

    <!-- Bottom Navigation -->
    <BottomNav />

    <!-- Product Form Modal -->
    <ProductFormModal v-model="showProductModal" :product-id="editingProductId" @saved="showProductModal = false" />

    <!-- T-010: Modal de Confirmación de Eliminación -->
    <Teleport to="body">
      <Transition name="modal">
        <div v-if="showDeleteModal" class="fixed inset-0 z-[100] flex items-center justify-center p-4">
          <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" @click="cancelDelete"></div>
          <div class="relative w-full max-w-sm bg-white dark:bg-slate-800 rounded-2xl shadow-2xl p-6">
            <div class="flex flex-col items-center text-center gap-4">
              <div class="flex h-14 w-14 items-center justify-center rounded-full bg-red-100 dark:bg-red-900/30">
                <span class="material-symbols-outlined text-2xl text-red-500">delete</span>
              </div>
              <h3 class="text-lg font-bold text-slate-900 dark:text-white">¿Eliminar producto?</h3>
              <p class="text-sm text-slate-600 dark:text-slate-300">
                <span class="font-semibold">{{ productToDelete?.name }}</span> será eliminado permanentemente.
              </p>
              <div class="flex gap-3 w-full mt-2">
                <button @click="cancelDelete"
                  class="flex-1 h-11 rounded-xl border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300 font-semibold hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors">
                  Cancelar
                </button>
                <button @click="confirmDelete"
                  class="flex-1 h-11 rounded-xl bg-red-500 hover:bg-red-600 text-white font-semibold transition-colors">
                  Eliminar
                </button>
              </div>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
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
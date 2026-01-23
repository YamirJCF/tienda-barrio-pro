<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useInventoryStore } from '../stores/inventory';
import { useAuthStore } from '../stores/auth';
import { useInventoryFilter } from '../composables/useInventoryFilter';
import ProductFormModal from '../components/ProductFormModal.vue';
import BottomNav from '../components/BottomNav.vue';
import NoPermissionOverlay from '../components/ui/NoPermissionOverlay.vue';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useQuantityFormat } from '../composables/useQuantityFormat';
import { Decimal } from 'decimal.js';
import KardexModal from '../components/inventory/KardexModal.vue';
import BaseInput from '../components/ui/BaseInput.vue';
import BaseButton from '../components/ui/BaseButton.vue';
import BaseModal from '../components/ui/BaseModal.vue';

const router = useRouter();
const inventoryStore = useInventoryStore();
const authStore = useAuthStore();
const { formatCurrency } = useCurrencyFormat();
const { formatStock } = useQuantityFormat();

// Permisos del usuario
const canViewInventory = computed(() => authStore.canViewInventory);
const canManageInventory = computed(() => authStore.canManageInventory);

// State
// Composable: Inventory Filter
const {
  searchQuery,
  selectedCategory,
  categories,
  filteredProducts,
  getCategoryLabel
} = useInventoryFilter();

// State
const showProductModal = ref(false);
// WO-001: Changed from number to string for UUID
const editingProductId = ref<string | undefined>(undefined);
const showDeleteModal = ref(false);
const productToDelete = ref<{ id: string; name: string } | null>(null);

// T1.4: Kardex State
const showKardexModal = ref(false);
const kardexProduct = ref<{ id: string; name: string } | null>(null);

// Lifecycle
onMounted(() => {
  inventoryStore.initialize();
});

// Methods
const goToDashboard = () => {
  router.push('/');
};

const openNewProduct = () => {
  editingProductId.value = undefined;
  showProductModal.value = true;
};

const openEditProduct = (id: string) => {
  editingProductId.value = id;
  showProductModal.value = true;
};

const openKardex = (product: { id: string; name: string }) => {
  kardexProduct.value = product;
  showKardexModal.value = true;
};

const deleteProduct = (id: string) => {
// ...
  const product = inventoryStore.products.find((p) => p.id === id);
  if (product) {
    productToDelete.value = { id, name: product.name };
    showDeleteModal.value = true;
  }
};

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
        <div class="flex-1">
          <BaseInput
            v-model="searchQuery"
            placeholder="Buscar producto..."
            icon="search"
            class="w-full"
          />
        </div>
        <button class="p-2 rounded-full bg-gray-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300">
          <span class="material-symbols-outlined text-[20px]">filter_list</span>
        </button>
      </div>

      <!-- Category Tags -->
      <div class="flex gap-2 overflow-x-auto px-4 pb-3 [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]">
        <BaseButton 
          v-for="cat in categories" 
          :key="cat"
          @click="selectedCategory = cat"
          :variant="selectedCategory === cat ? 'primary' : 'outline'"
          size="sm"
          class="!rounded-full whitespace-nowrap"
        >
          {{ getCategoryLabel(cat) }}
        </BaseButton>
      </div>
    </header>

    <!-- Products List -->
    <main class="flex-1 overflow-y-auto p-4 flex flex-col gap-3 [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]">
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
        <p class="text-sm">
          {{ searchQuery ? 'No se encontraron productos' : 'No hay productos aún' }}
        </p>
        <BaseButton 
          v-if="!searchQuery" 
          @click="openNewProduct"
          class="mt-4"
          variant="primary"
        >
          Crear primer producto
        </BaseButton>
      </div>

      <!-- Product Cards with Virtual Scrolling -->
      <RecycleScroller v-if="filteredProducts.length > 0" class="flex-1" :items="filteredProducts" :item-size="140"
        key-field="id" v-slot="{ item: product }">
        <article
          class="bg-white dark:bg-surface-dark rounded-xl p-4 shadow-sm border border-gray-100 dark:border-gray-800 flex flex-col gap-3 transition-transform mb-3 mx-4"
          :class="{
            'active:scale-[0.99] cursor-pointer': canManageInventory,
            'cursor-default': !canManageInventory,
          }" @click="canManageInventory ? openEditProduct(product.id) : null">
          <div class="flex justify-between items-start gap-4">
            <div class="flex-1">
              <h3 class="text-slate-900 dark:text-white text-base font-bold leading-tight">
                {{ product.name }}
              </h3>
              <div class="flex items-center gap-2 mt-1">
                <span v-if="product.brand" class="text-slate-500 text-xs font-medium">{{
                  product.brand
                }}</span>
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
            <span :class="product.stock.lte
              ? product.stock.lte(product.minStock)
                ? 'text-red-500'
                : 'text-primary'
              : product.stock <= product.minStock
                ? 'text-red-500'
                : 'text-primary'
              " class="font-bold text-lg leading-none">
              {{ formatStock(product.stock, product.measurementUnit) }}
              <span class="text-xs font-medium opacity-70">{{
                product.measurementUnit || 'un'
              }}</span>
            </span>
            <div class="flex gap-1">
              <button
                class="text-slate-400 hover:text-primary p-2 rounded-full hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-colors"
                @click.stop="openKardex(product)"
                title="Ver historial">
                <span class="material-symbols-outlined text-[20px]">history</span>
              </button>
              <button v-if="canManageInventory"
                class="text-slate-400 hover:text-red-500 p-2 -mr-2 rounded-full hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
                @click.stop="deleteProduct(product.id)">
                <span class="material-symbols-outlined text-[20px]">delete</span>
              </button>
            </div>
          </div>
        </article>
      </RecycleScroller>
    </main>

    <!-- FAB (Floating Action Buttons) -->
    <div class="fixed bottom-24 right-4 z-40 flex flex-col gap-3">
      <!-- Stock Entry FAB - Only if canManageInventory -->
      <BaseButton 
        v-if="canManageInventory"
        @click="router.push('/stock-entry')"
        variant="success"
        class="size-12 !rounded-full shadow-lg shadow-emerald-500/40"
        icon="inventory"
      />
      
      <!-- Add Product FAB - Only if canManageInventory -->
      <BaseButton 
        v-if="canManageInventory"
        @click="openNewProduct"
        variant="primary"
        class="size-14 !rounded-full shadow-lg shadow-blue-500/40"
        icon="add"
      />
    </div>

    <!-- Bottom Navigation -->
    <BottomNav />

    <!-- Product Form Modal -->
    <ProductFormModal v-model="showProductModal" :product-id="editingProductId" @saved="showProductModal = false" />
    
    <!-- T1.4: Kardex Modal -->
    <KardexModal 
      v-model="showKardexModal"
      :product-id="kardexProduct?.id || null"
      :product-name="kardexProduct?.name || null"
    />

    <!-- T-010: Modal de Confirmación de Eliminación -->
    <BaseModal
      v-model="showDeleteModal"
      title="¿Eliminar producto?"
    >
        <div class="p-6 text-center">
            <div class="flex h-14 w-14 items-center justify-center rounded-full bg-red-100 dark:bg-red-900/30 mx-auto mb-4">
               <span class="material-symbols-outlined text-2xl text-red-500">delete</span>
            </div>
            <p class="text-sm text-slate-600 dark:text-slate-300">
               <span class="font-semibold">{{ productToDelete?.name }}</span> será eliminado
               permanentemente.
            </p>
        </div>

        <template #footer>
            <div class="p-6 pt-0 flex gap-3">
                <BaseButton
                    @click="cancelDelete"
                    variant="secondary"
                    class="flex-1"
                >
                    Cancelar
                </BaseButton>
                <BaseButton
                    @click="confirmDelete"
                    variant="danger"
                    class="flex-1"
                >
                    Eliminar
                </BaseButton>
            </div>
        </template>
    </BaseModal>
  </div>
</template>



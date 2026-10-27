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
import BatchHistoryModal from '../components/inventory/BatchHistoryModal.vue';
import { useToast } from 'vue-toastification';
import BaseInput from '../components/ui/BaseInput.vue';
import BaseButton from '../components/ui/BaseButton.vue';
import BaseModal from '../components/ui/BaseModal.vue';
import BaseListSkeleton from '../components/ui/BaseListSkeleton.vue';
import BaseEmptyState from '../components/ui/BaseEmptyState.vue';
import { 
  ArrowLeft, 
  Search, 
  Filter, 
  AlertCircle, 
  Package, 
  Plus, 
  History, 
  Trash2,
  Archive,
  Layers
} from 'lucide-vue-next';

const router = useRouter();
const inventoryStore = useInventoryStore();
const authStore = useAuthStore();
const { formatCurrency } = useCurrencyFormat();
const { formatStock } = useQuantityFormat();
const toast = useToast();

// Permisos del usuario
const canViewInventory = computed(() => authStore.canViewInventory);
const canManageInventory = computed(() => authStore.canManageInventory);

// Admin role check
const isAdmin = computed(() => authStore.isAdmin);

// State
// Composable: Inventory Filter (Gobernanza SWR Nivel 2 y Reactividad 100% en Memoria)
const {
  searchQuery,
  selectedCategory,
  onlyLowStock,
  includeInactive,
  sortBy,
  activeFiltersCount,
  resetFilters,
  categories,
  filteredProducts,
  getCategoryLabel
} = useInventoryFilter();

// Alerta de stock bajo verificada contra la regla de negocio (stock <= minStock && isActive !== false)
const realLowStockCount = computed(() => {
  return inventoryStore.products.filter(p => {
    const isAct = p.isActive !== false;
    const s = p.stock instanceof Decimal ? p.stock.toNumber() : Number(p.stock || 0);
    const m = typeof p.minStock === 'number' ? p.minStock : Number(p.minStock || 0);
    return isAct && s <= m;
  }).length;
});

// Modal de Filtros Avanzados
const showFilterModal = ref(false);

// State
const showProductModal = ref(false);
// WO-001: Changed from number to string for UUID
const editingProductId = ref<string | undefined>(undefined);
const showDeleteModal = ref(false);
const productToDelete = ref<{ id: string; name: string } | null>(null);

// T1.4: Kardex State
const showKardexModal = ref(false);
const kardexProduct = ref<{ id: string; name: string } | null>(null);

// T1.5: Batch History State
const showBatchModal = ref(false);
const batchProduct = ref<{ id: string; name: string } | null>(null);

// Tarea 3: UX Destello (Creación)
const newlyCreatedId = ref<string | null>(null);

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

const openBatchHistory = (product: { id: string; name: string }) => {
  batchProduct.value = product;
  showBatchModal.value = true;
};

const deleteProduct = (id: string) => {
// ...
  const product = inventoryStore.products.find((p) => p.id === id);
  if (product) {
    productToDelete.value = { id, name: product.name };
    showDeleteModal.value = true;
  }
};

const confirmDelete = async () => {
  if (productToDelete.value) {
    try {
      const success = await inventoryStore.deleteProduct(productToDelete.value.id);
      if (success) {
        toast.success('Producto eliminado correctamente');
      }
    } catch (e: any) {
      toast.error(e.message || 'Error desconocido al eliminar');
    }
  }
  showDeleteModal.value = false;
  productToDelete.value = null;
};

const cancelDelete = () => {
  showDeleteModal.value = false;
  productToDelete.value = null;
};

const handleProductSaved = (product: { id: string }, action: 'create' | 'update') => {
  showProductModal.value = false;
  if (action === 'create') {
    newlyCreatedId.value = product.id;
    setTimeout(() => {
      if (newlyCreatedId.value === product.id) {
        newlyCreatedId.value = null;
      }
    }, 3000);
  }
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
          class="flex items-center justify-center -ml-2 p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors">
          <ArrowLeft :size="24" :stroke-width="1.5" />
        </button>
        <div class="flex-1">
          <BaseInput
            v-model="searchQuery"
            placeholder="Buscar producto..."
            class="w-full"
          >
            <template #prefix>
               <Search :size="18" :stroke-width="1.5" class="text-slate-400" />
            </template>
          </BaseInput>
        </div>
        <button 
          @click="showFilterModal = true"
          aria-label="Abrir filtros de inventario"
          class="relative p-2 rounded-xl bg-gray-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:ring-2 hover:ring-primary/20 transition-all">
          <Filter :size="20" :stroke-width="1.5" />
          <span 
            v-if="activeFiltersCount > 0" 
            class="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-blue-600 text-[10px] font-bold text-white shadow-sm">
            {{ activeFiltersCount }}
          </span>
        </button>
      </div>

      <!-- Category Tags + Quick Filters -->
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

        <!-- Quick Low Stock Chip -->
        <BaseButton 
          @click="onlyLowStock = !onlyLowStock"
          :variant="onlyLowStock ? 'danger' : 'outline'"
          size="sm"
          class="!rounded-full whitespace-nowrap flex items-center gap-1.5"
        >
          <AlertCircle :size="14" />
          <span>Stock Bajo</span>
          <span v-if="realLowStockCount > 0" class="ml-0.5 px-1.5 py-0.5 rounded-full text-[10px] bg-red-100 dark:bg-red-900/50 text-red-600 dark:text-red-300 font-bold">
            {{ realLowStockCount }}
          </span>
        </BaseButton>
      </div>
    </header>

    <!-- Products List -->
    <main class="flex-1 overflow-y-auto p-4 flex flex-col gap-3 [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]">
      <div class="flex justify-between items-end px-1">
        <span class="text-xs font-bold text-slate-500 uppercase tracking-widest">
          Productos ({{ filteredProducts.length }})
        </span>
        <button 
          v-if="realLowStockCount > 0" 
          @click="onlyLowStock = !onlyLowStock"
          class="text-xs font-medium text-red-500 flex items-center gap-1 hover:underline cursor-pointer"
        >
          <AlertCircle :size="12" />
          {{ realLowStockCount }} con stock bajo
        </button>
      </div>



      <!-- Loading State -->
      <BaseListSkeleton v-if="inventoryStore.isLoading" :count="6" type="card" class="px-1" />

      <!-- Empty State -->
      <BaseEmptyState
        v-else-if="filteredProducts.length === 0"
        :title="activeFiltersCount > 0 || searchQuery ? 'No se encontraron productos' : 'No hay productos aún'"
        :description="activeFiltersCount > 0 || searchQuery ? 'Intenta modificar o restablecer los filtros aplicados' : 'Agrega tu primer producto para comenzar'"
        :icon="Package"
        :action-label="activeFiltersCount > 0 || searchQuery ? 'Restablecer filtros' : 'Crear primer producto'"
        @action="activeFiltersCount > 0 || searchQuery ? resetFilters() : openNewProduct()"
      />

      <!-- Product Cards with Virtual Scrolling -->
      <RecycleScroller v-else class="flex-1" :items="filteredProducts" :item-size="140"
        key-field="id" v-slot="{ item: product }">
        <article
          class="bg-white dark:bg-surface-dark rounded-2xl px-4 py-3 shadow-soft hover:shadow-soft-md border border-gray-200 dark:border-gray-700 flex flex-col transition-all duration-200 mx-4 mb-2 h-[128px] overflow-hidden"
          :class="{
            'active:scale-[0.99] cursor-pointer': canManageInventory,
            'cursor-default': !canManageInventory,
            'highlight-new': product.id === newlyCreatedId
          }" @click="canManageInventory ? openEditProduct(product.id) : null">
          <!-- Row 1: Product Info + Price -->
          <div class="flex justify-between items-start gap-3 min-h-0">
            <div class="flex-1 min-w-0">
              <h3 class="text-slate-900 dark:text-white text-sm font-bold leading-tight truncate">
                {{ product.name }}
              </h3>
              <div class="flex items-center gap-1.5 mt-1 flex-wrap">
                <span v-if="product.brand" class="text-slate-500 text-[11px] font-medium truncate max-w-[100px]">{{
                  product.brand
                }}</span>
                <span v-if="product.brand && product.plu" class="text-slate-300 text-[10px]">|</span>
                <span v-if="product.plu" class="text-slate-400 text-[11px] font-mono tracking-tight">
                  {{ product.plu }}
                </span>
                <span v-if="product.category"
                  class="px-1.5 py-0.5 bg-gray-100 dark:bg-gray-800 text-slate-500 dark:text-slate-400 text-[9px] font-bold rounded uppercase tracking-wide">
                  {{ product.category }}
                </span>
              </div>
            </div>
            <div class="shrink-0">
              <span
                class="text-slate-900 dark:text-white font-mono font-bold text-base bg-gray-50 dark:bg-slate-700/50 px-2.5 py-1 rounded-xl border border-gray-100 dark:border-gray-600 block">
                ${{ formatCurrency(product.price) }}
              </span>
            </div>
          </div>
          <!-- Row 2: Stock + Actions (pinned to bottom) -->
          <div class="flex items-center justify-between pt-2 mt-auto border-t border-gray-100 dark:border-gray-700/50">
            <span :class="product.stock.lte
              ? product.stock.lte(product.minStock)
                ? 'text-red-500'
                : 'text-emerald-600'
              : product.stock <= product.minStock
                ? 'text-red-500'
                : 'text-emerald-600'
              " class="font-mono font-bold text-base leading-none tracking-tight flex items-baseline gap-1">
              {{ formatStock(product.stock, product.measurementUnit) }}
              <span class="text-[10px] font-sans font-medium text-slate-400 uppercase">{{
                product.measurementUnit || 'un'
              }}</span>
            </span>
            <div class="flex gap-1">
              <button
                class="text-slate-400 hover:text-indigo-600 p-1.5 rounded-lg hover:bg-indigo-50 dark:hover:bg-indigo-900/20 transition-colors"
                @click.stop="openKardex(product)"
                title="Ver historial">
                <History :size="16" :stroke-width="2" />
              </button>
              <button
                class="text-slate-400 hover:text-emerald-600 p-1.5 rounded-lg hover:bg-emerald-50 dark:hover:bg-emerald-900/20 transition-colors"
                @click.stop="openBatchHistory(product)"
                title="Ver Lotes (FIFO)">
                <Layers :size="16" :stroke-width="2" />
              </button>
              <button v-if="canManageInventory"
                class="text-slate-400 hover:text-red-500 p-1.5 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
                @click.stop="deleteProduct(product.id)">
                <Trash2 :size="16" :stroke-width="2" />
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
        class="size-12 !rounded-2xl shadow-lg shadow-emerald-500/40 flex items-center justify-center p-0"
      >
        <Archive :size="24" :stroke-width="1.5" />
      </BaseButton>
      
      <!-- Add Product FAB - Only if canManageInventory -->
      <BaseButton 
        v-if="canManageInventory"
        @click="openNewProduct"
        variant="primary"
        class="size-14 !rounded-2xl shadow-lg shadow-blue-500/40 flex items-center justify-center p-0"
      >
        <Plus :size="28" :stroke-width="1.5" />
      </BaseButton>
    </div>

    <!-- Bottom Navigation -->
    <BottomNav />

    <!-- Product Form Modal -->
    <ProductFormModal v-model="showProductModal" :product-id="editingProductId" @saved="handleProductSaved" />
    
    <!-- T1.4: Kardex Modal -->
    <KardexModal 
      v-model="showKardexModal"
      :product-id="kardexProduct?.id || null"
      :product-name="kardexProduct?.name || null"
    />

    <!-- T1.5: Batch History Modal -->
    <BatchHistoryModal 
      v-model="showBatchModal"
      :product-id="batchProduct?.id || null"
      :product-name="batchProduct?.name || null"
    />

    <!-- Modal de Filtros Avanzados de Inventario (UXD-006 / SDD-006) -->
    <BaseModal
      v-model="showFilterModal"
      title="Filtros de Catálogo"
    >
      <div class="p-6 space-y-4">
        <!-- Low Stock Switch -->
        <div class="flex items-center justify-between p-3 bg-gray-50 dark:bg-slate-800/60 rounded-xl border border-gray-100 dark:border-gray-700">
          <div>
            <span class="text-sm font-semibold text-slate-800 dark:text-white block">Solo Stock Bajo</span>
            <span class="text-xs text-slate-500">Muestra exclusivamente artículos con existencia &le; stock mínimo</span>
          </div>
          <input
            type="checkbox"
            v-model="onlyLowStock"
            class="h-5 w-5 rounded border-gray-300 text-blue-600 focus:ring-blue-500 accent-blue-600 cursor-pointer"
          />
        </div>

        <!-- Inactive Switch (Admin only) -->
        <div v-if="isAdmin" class="flex items-center justify-between p-3 bg-gray-50 dark:bg-slate-800/60 rounded-xl border border-gray-100 dark:border-gray-700">
          <div>
            <span class="text-sm font-semibold text-slate-800 dark:text-white block">Incluir Inactivos / Dados de baja</span>
            <span class="text-xs text-slate-500">Visibilidad administrativa de artículos descontinuados</span>
          </div>
          <input
            type="checkbox"
            v-model="includeInactive"
            class="h-5 w-5 rounded border-gray-300 text-blue-600 focus:ring-blue-500 accent-blue-600 cursor-pointer"
          />
        </div>

        <!-- Criterio de Ordenamiento -->
        <div>
          <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">Criterio de Ordenamiento</label>
          <select
            v-model="sortBy"
            class="w-full text-sm rounded-xl border border-gray-300 dark:border-gray-600 bg-white dark:bg-slate-700 text-slate-800 dark:text-white px-3 py-2.5 focus:ring-2 focus:ring-primary focus:outline-none"
          >
            <option value="created_desc">Más recientes primero (Predeterminado)</option>
            <option value="name_asc">Nombre (A &rarr; Z)</option>
            <option value="name_desc">Nombre (Z &rarr; A)</option>
            <option value="stock_asc">Stock (Menor a Mayor)</option>
            <option value="stock_desc">Stock (Mayor a Menor)</option>
            <option value="price_asc">Precio (Menor a Mayor)</option>
            <option value="price_desc">Precio (Mayor a Menor)</option>
          </select>
        </div>

        <!-- Filtro por Categoría -->
        <div>
          <label class="block text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">Categoría</label>
          <select
            v-model="selectedCategory"
            class="w-full text-sm rounded-xl border border-gray-300 dark:border-gray-600 bg-white dark:bg-slate-700 text-slate-800 dark:text-white px-3 py-2.5 focus:ring-2 focus:ring-primary focus:outline-none"
          >
            <option v-for="cat in categories" :key="cat" :value="cat">
              {{ getCategoryLabel(cat) }}
            </option>
          </select>
        </div>
      </div>

      <template #footer>
        <div class="p-6 pt-0 flex gap-3">
          <BaseButton
            @click="resetFilters"
            variant="secondary"
            class="flex-1"
          >
            Restablecer
          </BaseButton>
          <BaseButton
            @click="showFilterModal = false"
            variant="primary"
            class="flex-1"
          >
            Listo
          </BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- T-010: Modal de Confirmación de Eliminación -->
    <BaseModal
      v-model="showDeleteModal"
      title="¿Eliminar producto?"
    >
        <div class="p-6 text-center">
            <div class="flex h-14 w-14 items-center justify-center rounded-full bg-red-100 dark:bg-red-900/30 mx-auto mb-4">
               <Trash2 :size="24" :stroke-width="1.5" class="text-red-500" />
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



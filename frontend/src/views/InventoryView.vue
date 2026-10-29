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
import BaseButton from '../components/ui/BaseButton.vue';
import BaseModal from '../components/ui/BaseModal.vue';
import BaseListSkeleton from '../components/ui/BaseListSkeleton.vue';
import BaseEmptyState from '../components/ui/BaseEmptyState.vue';
import BaseDropdown, { type DropdownOption } from '../components/ui/BaseDropdown.vue';
import InventorySearchBar from '../components/inventory/InventorySearchBar.vue';
import { 
  ArrowLeft, 
  Package, 
  Plus, 
  History, 
  Trash2, 
  Archive, 
  Layers,
  EyeOff
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
// Composable: Inventory Filter (Gobernanza SWR Nivel 2 y Filtros 100% en Memoria)
const {
  searchQuery,
  selectedCategory,
  onlyLowStock,
  includeInactive,
  sortBy,
  activeFiltersCount,
  resetFilters,
  applyShortcutString,
  onCategoryRemoved,
  categories,
  filteredProducts,
  getCategoryLabel
} = useInventoryFilter();

// Opciones de Categorías para el Dropdown
const categoryOptions = computed<DropdownOption[]>(() => {
  return categories.value.map((cat) => ({
    value: cat,
    label: getCategoryLabel(cat),
  }));
});

// Opciones de Ordenamiento (8 opciones - Opción B incorporada)
const sortOptions: DropdownOption[] = [
  { value: 'created_desc', label: 'Más recientes' },
  { value: 'urgency_asc', label: 'Más urgentes (Reponer)' },
  { value: 'name_asc', label: 'Nombre (A → Z)' },
  { value: 'name_desc', label: 'Nombre (Z → A)' },
  { value: 'stock_asc', label: 'Stock (Menor a Mayor)' },
  { value: 'stock_desc', label: 'Stock (Mayor a Menor)' },
  { value: 'price_asc', label: 'Precio (Menor a Mayor)' },
  { value: 'price_desc', label: 'Precio (Mayor a Menor)' },
];

// Atajos internos (Opción C): Errores y Advertencias
const shortcutErrors = ref<string[]>([]);
const shortcutWarnings = ref<string[]>([]);

const handleShortcutSubmit = (rawInput: string) => {
  shortcutErrors.value = [];
  shortcutWarnings.value = [];
  const res = applyShortcutString(rawInput, isAdmin.value);
  shortcutErrors.value = res.errors;
  shortcutWarnings.value = res.warnings;
};

const handleSearchClear = () => {
  shortcutErrors.value = [];
  shortcutWarnings.value = [];
  searchQuery.value = '';
};

// State Modales
const showProductModal = ref(false);
const editingProductId = ref<string | undefined>(undefined);
const showDeleteModal = ref(false);
const productToDelete = ref<{ id: string; name: string } | null>(null);

// T1.4: Kardex State
const showKardexModal = ref(false);
const kardexProduct = ref<{ id: string; name: string } | null>(null);

// T1.5: Batch History State
const showBatchModal = ref(false);
const batchProduct = ref<{ id: string; name: string } | null>(null);

// UX Destello (Creación)
const newlyCreatedId = ref<string | null>(null);

// Lifecycle
onMounted(() => {
  inventoryStore.initialize();
  onCategoryRemoved((cat) => {
    toast.info(`La categoría '${cat}' ya no tiene productos asociados.`);
  });
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

    <!-- Header con Búsqueda y Filtros Compactos (Opción A + C) -->
    <header class="sticky top-0 z-30 bg-white dark:bg-surface-dark border-b border-gray-200 dark:border-gray-800 shadow-sm">
      <!-- Fila 1: Volver + Barra de Búsqueda con Atajos Internos -->
      <div class="px-4 pt-3 pb-2 flex items-center gap-2">
        <button 
          @click="goToDashboard" 
          aria-label="Volver al Dashboard"
          class="flex items-center justify-center -ml-1.5 p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <ArrowLeft :size="22" :stroke-width="1.5" />
        </button>

        <div class="flex-1 min-w-0">
          <InventorySearchBar
            v-model="searchQuery"
            :errors="shortcutErrors"
            :warnings="shortcutWarnings"
            @submit-shortcuts="handleShortcutSubmit"
            @clear="handleSearchClear"
          />
        </div>
      </div>

      <!-- Fila 2: Desplegables de Categoría, Orden y Botón Admin Inactivos -->
      <div class="px-4 pb-3 flex items-center gap-2 flex-wrap">
        <!-- Desplegable Categoría -->
        <BaseDropdown
          v-model="selectedCategory"
          :options="categoryOptions"
          prefix-label="Categoría"
        />

        <!-- Desplegable Orden (con opción "Más urgentes") -->
        <BaseDropdown
          v-model="sortBy"
          :options="sortOptions"
          prefix-label="Orden"
        />

        <!-- Botón Ver Inactivos (Solo Admin) -->
        <button
          v-if="isAdmin"
          type="button"
          @click="includeInactive = !includeInactive"
          :title="includeInactive ? 'Ocultar inactivos' : 'Ver productos inactivos (Admin)'"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold border transition-all cursor-pointer active:scale-95 ml-auto"
          :class="includeInactive
            ? 'bg-indigo-600 text-white border-indigo-600 shadow-sm'
            : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border-gray-200 dark:border-slate-700 hover:border-slate-400'"
        >
          <EyeOff :size="13" />
          <span>Inactivos</span>
        </button>
      </div>
    </header>

    <!-- Products List -->
    <main class="flex-1 overflow-y-auto p-4 flex flex-col gap-3 [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]">
      <div class="flex justify-between items-center px-1">
        <span class="text-xs font-bold text-slate-500 uppercase tracking-widest">
          Productos ({{ filteredProducts.length }})
        </span>

        <!-- Botón rápido para limpiar filtros si hay alguno activo -->
        <button 
          v-if="activeFiltersCount > 0 || searchQuery"
          @click="resetFilters"
          class="text-xs font-medium text-primary hover:underline cursor-pointer"
        >
          Limpiar filtros
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
    
    <!-- Kardex Modal -->
    <KardexModal 
      v-model="showKardexModal"
      :product-id="kardexProduct?.id || null"
      :product-name="kardexProduct?.name || null"
    />

    <!-- Batch History Modal -->
    <BatchHistoryModal 
      v-model="showBatchModal"
      :product-id="batchProduct?.id || null"
      :product-name="batchProduct?.name || null"
    />

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

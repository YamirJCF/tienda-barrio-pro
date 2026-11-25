<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useInventoryStore } from '../stores/inventory';
import { useAuthStore } from '../stores/auth';
import { useInventoryFilter } from '../composables/useInventoryFilter';
import ProductFormModal, { type ProductFichaTab } from '../components/ProductFormModal.vue';
import BottomNav from '../components/BottomNav.vue';
import NoPermissionOverlay from '../components/ui/NoPermissionOverlay.vue';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useQuantityFormat } from '../composables/useQuantityFormat';
import { useNotifications } from '../composables/useNotifications';
import BaseButton from '../components/ui/BaseButton.vue';
import BaseListSkeleton from '../components/ui/BaseListSkeleton.vue';
import BaseEmptyState from '../components/ui/BaseEmptyState.vue';
import BaseDropdown, { type DropdownOption } from '../components/ui/BaseDropdown.vue';
import InventorySearchBar from '../components/inventory/InventorySearchBar.vue';
import {
  ArrowLeft,
  Package,
  Plus,
  Archive,
  EyeOff,
  ChevronRight,
} from 'lucide-vue-next';

const router = useRouter();
const route = useRoute();
const inventoryStore = useInventoryStore();
const authStore = useAuthStore();
const { formatWithSign } = useCurrencyFormat();
const { formatStock } = useQuantityFormat();
const { showInfo } = useNotifications();

const canManageInventory = computed(() => authStore.canManageInventory);
const isAdmin = computed(() => authStore.isAdmin);

const {
  searchQuery,
  selectedCategory,
  includeInactive,
  sortBy,
  activeFiltersCount,
  resetFilters,
  applyShortcutString,
  onCategoryRemoved,
  categories,
  filteredProducts,
  getCategoryLabel,
} = useInventoryFilter();

const categoryOptions = computed<DropdownOption[]>(() => {
  return categories.value.map((cat) => ({
    value: cat,
    label: getCategoryLabel(cat),
  }));
});

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

// State Ficha Unificada
const showProductModal = ref(false);
const editingProductId = ref<string | undefined>(undefined);
const initialFichaTab = ref<ProductFichaTab>('data');
const newlyCreatedId = ref<string | null>(null);

const resolveValidTab = (raw: unknown): ProductFichaTab => {
  if (raw === 'batches' || raw === 'kardex' || raw === 'data') return raw;
  return 'data';
};

const applyDeepLink = () => {
  const productParam = typeof route.query.product === 'string' ? route.query.product : '';
  if (!productParam || !canManageInventory.value) return;
  const exists = inventoryStore.getProductById(productParam);
  if (!exists) return;
  editingProductId.value = productParam;
  initialFichaTab.value = resolveValidTab(route.query.tab);
  showProductModal.value = true;
};

onMounted(async () => {
  await inventoryStore.initialize();
  applyDeepLink();
  onCategoryRemoved((cat) => {
    showInfo(`La categoría '${cat}' ya no tiene productos asociados.`);
  });
});

watch(
  () => [route.query.product, route.query.tab, inventoryStore.products.length],
  () => {
    applyDeepLink();
  }
);

const goToDashboard = () => {
  router.push('/');
};

const openNewProduct = () => {
  editingProductId.value = undefined;
  initialFichaTab.value = 'data';
  showProductModal.value = true;
};

const openProductFicha = (id: string, tab: ProductFichaTab = 'data') => {
  editingProductId.value = id;
  initialFichaTab.value = tab;
  showProductModal.value = true;
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
    <NoPermissionOverlay
      v-if="!canManageInventory"
      message="No tienes permiso para ver el inventario. Contacta a tu administrador si necesitas acceso."
      @go-back="goToDashboard"
    />

    <header class="sticky top-0 z-30 bg-surface-light dark:bg-surface-dark border-b border-slate-200 dark:border-slate-800 shadow-sm">
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

      <div class="px-4 pb-3 flex items-center gap-2 flex-wrap">
        <BaseDropdown
          v-model="selectedCategory"
          :options="categoryOptions"
          prefix-label="Categoría"
        />

        <BaseDropdown
          v-model="sortBy"
          :options="sortOptions"
          prefix-label="Orden"
        />

        <button
          v-if="isAdmin"
          type="button"
          @click="includeInactive = !includeInactive"
          :title="includeInactive ? 'Ocultar inactivos' : 'Ver productos inactivos (Admin)'"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold border transition-all cursor-pointer active:scale-95 ml-auto"
          :class="includeInactive
            ? 'bg-indigo-600 text-white border-indigo-600 shadow-sm'
            : 'bg-surface-light dark:bg-slate-800 text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:border-slate-400'"
        >
          <EyeOff :size="13" />
          <span>Inactivos</span>
        </button>
      </div>
    </header>

    <main class="flex-1 overflow-y-auto p-4 flex flex-col gap-3 [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]">
      <div class="flex justify-between items-center px-1">
        <span class="text-xs font-bold text-slate-500 uppercase tracking-widest font-mono tabular-nums">
          Productos ({{ filteredProducts.length }})
        </span>

        <button
          v-if="activeFiltersCount > 0 || searchQuery"
          @click="resetFilters"
          class="text-xs font-medium text-primary hover:underline cursor-pointer"
        >
          Limpiar filtros
        </button>
      </div>

      <BaseListSkeleton v-if="inventoryStore.isLoading" :count="6" type="card" class="px-1" />

      <BaseEmptyState
        v-else-if="filteredProducts.length === 0"
        :title="activeFiltersCount > 0 || searchQuery ? 'No se encontraron productos' : 'No hay productos aún'"
        :description="activeFiltersCount > 0 || searchQuery ? 'Intenta modificar o restablecer los filtros aplicados' : 'Agrega tu primer producto para comenzar'"
        :icon="Package"
        :action-label="activeFiltersCount > 0 || searchQuery ? 'Restablecer filtros' : 'Crear primer producto'"
        @action="activeFiltersCount > 0 || searchQuery ? resetFilters() : openNewProduct()"
      />

      <RecycleScroller
        v-else
        class="flex-1"
        :items="filteredProducts"
        :item-size="132"
        key-field="id"
        v-slot="{ item: product }"
      >
        <article
          :data-testid="`inventory-card-${product.id}`"
          class="bg-surface-light dark:bg-surface-dark rounded-2xl px-4 py-3 shadow-soft hover:shadow-soft-md border border-slate-200 dark:border-slate-800 flex flex-col transition-all duration-200 mx-4 mb-2 h-[120px] overflow-hidden"
          :class="{
            'active:scale-[0.99] cursor-pointer': canManageInventory,
            'cursor-default': !canManageInventory,
            'highlight-new': product.id === newlyCreatedId
          }"
          @click="canManageInventory ? openProductFicha(product.id, 'data') : null"
        >
          <div class="flex justify-between items-start gap-3 min-h-0">
            <div class="flex-1 min-w-0">
              <h3 class="text-slate-900 dark:text-white text-sm font-bold leading-tight truncate">
                {{ product.name }}
              </h3>
              <div class="flex items-center gap-1.5 mt-1 flex-wrap">
                <span v-if="product.brand" class="text-slate-500 text-[11px] font-medium truncate max-w-[100px]">
                  {{ product.brand }}
                </span>
                <span v-if="product.brand && product.plu" class="text-slate-300 text-[10px]">|</span>
                <span v-if="product.plu" class="text-slate-400 text-[11px] font-mono tabular-nums tracking-tight">
                  {{ product.plu }}
                </span>
                <span
                  v-if="product.category"
                  class="px-1.5 py-0.5 bg-background-light dark:bg-background-dark text-slate-500 dark:text-slate-400 text-[9px] font-bold rounded uppercase tracking-wide border border-slate-200 dark:border-slate-700"
                >
                  {{ product.category }}
                </span>
              </div>
            </div>
            <div class="shrink-0">
              <span class="text-slate-900 dark:text-white font-mono tabular-nums font-bold text-base bg-background-light dark:bg-background-dark px-2.5 py-1 rounded-xl border border-slate-200 dark:border-slate-700 block">
                {{ formatWithSign(product.price) }}
              </span>
            </div>
          </div>

          <div class="flex items-center justify-between pt-2 mt-auto border-t border-slate-100 dark:border-slate-800">
            <span
              :class="product.stock.lte
                ? product.stock.lte(product.minStock)
                  ? 'text-red-500'
                  : 'text-emerald-600 dark:text-emerald-400'
                : product.stock <= product.minStock
                  ? 'text-red-500'
                  : 'text-emerald-600 dark:text-emerald-400'"
              class="font-mono tabular-nums font-bold text-base leading-none tracking-tight flex items-baseline gap-1"
            >
              {{ formatStock(product.stock, product.measurementUnit) }}
              <span class="text-[10px] font-sans font-medium text-slate-400 uppercase">
                {{ product.measurementUnit || 'un' }}
              </span>
            </span>

            <span class="inline-flex items-center gap-1 text-[11px] font-semibold text-slate-400">
              <span>Ficha · Lotes</span>
              <ChevronRight :size="14" />
            </span>
          </div>
        </article>
      </RecycleScroller>
    </main>

    <div class="fixed bottom-24 right-4 z-40 flex flex-col gap-3">
      <BaseButton
        v-if="canManageInventory"
        @click="router.push('/stock-entry')"
        variant="success"
        class="size-12 !rounded-2xl shadow-lg shadow-emerald-500/40 flex items-center justify-center p-0"
      >
        <Archive :size="24" :stroke-width="1.5" />
      </BaseButton>

      <BaseButton
        v-if="canManageInventory"
        @click="openNewProduct"
        variant="primary"
        class="size-14 !rounded-2xl shadow-lg shadow-blue-500/40 flex items-center justify-center p-0"
      >
        <Plus :size="28" :stroke-width="1.5" />
      </BaseButton>
    </div>

    <BottomNav />

    <!-- Ficha Unificada de Producto (3 pestañas en edición) -->
    <ProductFormModal
      v-model="showProductModal"
      :product-id="editingProductId"
      :initial-tab="initialFichaTab"
      @saved="handleProductSaved"
    />
  </div>
</template>

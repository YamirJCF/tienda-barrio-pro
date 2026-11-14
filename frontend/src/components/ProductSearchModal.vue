<script setup lang="ts">
import { ref, computed, watch, onUnmounted } from 'vue';
import { useInventoryStore } from '../stores/inventory';
import { useAuthStore } from '../stores/auth';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import type { Product } from '../types';
import BaseModal from './ui/BaseModal.vue';
import BaseInput from './ui/BaseInput.vue';
import { Search, SearchX, Loader2, AlertTriangle, ChevronDown } from 'lucide-vue-next';

// Props
interface Props {
  modelValue: boolean;
}

const PRODUCTS_PAGE_SIZE = 7;

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  select: [product: Product];
}>();

const inventoryStore = useInventoryStore();
const authStore = useAuthStore();
const { formatCurrency } = useCurrencyFormat();

// State
const searchQuery = ref('');
const searchInput = ref<any>(null);
const pagedProducts = ref<Product[]>([]);
const totalProductsCount = ref(0);
const isLoadingProductsPage = ref(false);
const isLoadingMoreProducts = ref(false);
const productsPageError = ref<string | null>(null);

let activeFetchSeq = 0;
let inFlightQueryKey = '';
let debounceTimeout: ReturnType<typeof setTimeout> | null = null;

// Computed
const displayedProducts = computed(() => pagedProducts.value);

const remainingProductsCount = computed(() => {
  return Math.max(0, totalProductsCount.value - pagedProducts.value.length);
});

const resolveStoreId = (): string => {
  return (
    authStore.currentStore?.id ||
    authStore.currentUser?.storeId ||
    inventoryStore.products[0]?.storeId ||
    ''
  );
};

// Methods
const loadProductsPage = async (reset: boolean = false) => {
  const storeId = resolveStoreId();
  if (!storeId) {
    productsPageError.value = 'No se identificó la tienda activa para buscar productos.';
    return;
  }

  if (
    !reset &&
    (isLoadingProductsPage.value || isLoadingMoreProducts.value || remainingProductsCount.value <= 0)
  ) {
    return;
  }

  const nextOffset = reset ? 0 : pagedProducts.value.length;
  const normalizedQuery = searchQuery.value.trim();
  const queryKey = `${storeId}|${nextOffset}|${normalizedQuery}|${reset}`;
  if ((isLoadingProductsPage.value || isLoadingMoreProducts.value) && inFlightQueryKey === queryKey) {
    return;
  }

  const seq = ++activeFetchSeq;
  inFlightQueryKey = queryKey;
  productsPageError.value = null;

  if (reset) {
    isLoadingProductsPage.value = true;
  } else {
    isLoadingMoreProducts.value = true;
  }

  try {
    const result = await inventoryStore.fetchProductsPage({
      storeId,
      limit: PRODUCTS_PAGE_SIZE,
      offset: nextOffset,
      search: normalizedQuery,
    });

    if (seq !== activeFetchSeq) return;

    if (reset) {
      pagedProducts.value = result.data;
    } else {
      const existingIds = new Set(pagedProducts.value.map((p) => p.id));
      const newItems = result.data.filter((p) => !existingIds.has(p.id));
      pagedProducts.value = [...pagedProducts.value, ...newItems];
    }
    totalProductsCount.value = result.count;
  } catch (e: any) {
    if (seq !== activeFetchSeq) return;
    productsPageError.value = e?.message || 'Error al cargar productos';
  } finally {
    if (seq === activeFetchSeq) {
      isLoadingProductsPage.value = false;
      isLoadingMoreProducts.value = false;
      inFlightQueryKey = '';
    }
  }
};

const loadMoreProducts = () => {
  loadProductsPage(false);
};

const handleProductListScroll = (event: Event) => {
  const target = event.target as HTMLElement | null;
  if (!target) return;
  if (
    target.scrollHeight > target.clientHeight &&
    target.scrollTop + target.clientHeight >= target.scrollHeight - 24
  ) {
    loadMoreProducts();
  }
};

const retryLoadProducts = () => {
  loadProductsPage(pagedProducts.value.length === 0);
};

const resetModalState = () => {
  if (debounceTimeout) {
    clearTimeout(debounceTimeout);
    debounceTimeout = null;
  }
  activeFetchSeq++;
  inFlightQueryKey = '';
  searchQuery.value = '';
  pagedProducts.value = [];
  totalProductsCount.value = 0;
  isLoadingProductsPage.value = false;
  isLoadingMoreProducts.value = false;
  productsPageError.value = null;
};

const close = () => {
  resetModalState();
  emit('update:modelValue', false);
};

const selectProduct = (product: Product) => {
  emit('select', product);
  close();
};

watch(searchQuery, () => {
  if (debounceTimeout) {
    clearTimeout(debounceTimeout);
    debounceTimeout = null;
  }
  if (!props.modelValue) return;
  debounceTimeout = setTimeout(() => {
    loadProductsPage(true);
  }, 200);
});

watch(
  () => props.modelValue,
  (isOpen) => {
    if (isOpen) {
      resetModalState();
      loadProductsPage(true);
      setTimeout(() => {
        searchInput.value?.focus();
      }, 100);
    } else {
      resetModalState();
    }
  },
  { immediate: true },
);

onUnmounted(() => {
  if (debounceTimeout) {
    clearTimeout(debounceTimeout);
    debounceTimeout = null;
  }
});
</script>

<template>
  <BaseModal
    :model-value="modelValue"
    @update:model-value="close"
    max-height="85vh"
    content-class="flex flex-col min-h-0"
  >
    <template #header>
      <div class="flex-none w-full">
        <BaseInput
          ref="searchInput"
          v-model="searchQuery"
          placeholder="Buscar por nombre (desde inicio) o PLU..."
          :icon="Search"
        />
        <div class="flex items-center justify-between mt-2 px-1">
          <span class="text-[11px] font-medium text-gray-500 dark:text-gray-400">
            {{ searchQuery.trim() ? 'Coincidencias iniciales / PLU' : 'Catálogo disponible' }}
          </span>
          <span
            data-testid="pos-product-count"
            class="text-[11px] font-semibold text-gray-500 dark:text-gray-400"
          >
            {{ displayedProducts.length }} de {{ totalProductsCount }}
          </span>
        </div>
      </div>
    </template>

    <!-- Content (Scrollable Results List with 7-by-7 pagination) -->
    <div
      data-testid="pos-product-list"
      @scroll="handleProductListScroll"
      class="flex-1 min-h-0 overflow-y-auto p-3"
    >
      <!-- Loading Indicator -->
      <div
        v-if="isLoadingProductsPage && displayedProducts.length === 0"
        class="flex flex-col items-center justify-center h-36 text-gray-400 gap-2"
      >
        <Loader2 :size="30" class="animate-spin text-primary opacity-70" />
        <span class="text-xs font-medium">Cargando productos...</span>
      </div>

      <!-- Error State (Regla 3: fallo explícito con reintento) -->
      <div
        v-else-if="productsPageError && displayedProducts.length === 0"
        class="flex flex-col items-center justify-center h-40 px-4 text-center gap-2 text-red-600 dark:text-red-400"
      >
        <AlertTriangle :size="28" />
        <p class="text-xs font-semibold">{{ productsPageError }}</p>
        <button
          type="button"
          data-testid="retry-products-btn"
          @click="retryLoadProducts"
          class="px-3 py-1.5 rounded-lg bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-800 text-xs font-bold hover:bg-red-100 transition-colors cursor-pointer"
        >
          Reintentar
        </button>
      </div>

      <!-- Empty State -->
      <div
        v-else-if="displayedProducts.length === 0"
        class="flex flex-col items-center justify-center h-40 text-gray-400"
      >
        <SearchX :size="44" class="mb-2 opacity-50" />
        <p class="text-sm">
          {{
            searchQuery.trim()
              ? 'No se encontraron productos que inicien con esa búsqueda'
              : 'No hay productos disponibles con stock'
          }}
        </p>
      </div>

      <!-- Product List -->
      <div v-else class="space-y-2">
        <button
          v-for="product in displayedProducts"
          :key="product.id"
          type="button"
          data-testid="pos-product-card"
          class="w-full flex items-center justify-between gap-3 p-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-100 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 active:scale-[0.98] transition-all text-left cursor-pointer"
          @click="selectProduct(product)"
        >
          <div class="flex items-center gap-3 flex-1 min-w-0">
            <!-- PLU Badge -->
            <div
              class="flex items-center justify-center bg-gray-100 dark:bg-gray-700 rounded-md h-10 w-12 shrink-0"
            >
              <span class="text-xs font-bold text-gray-600 dark:text-gray-300">{{
                product.plu || '---'
              }}</span>
            </div>

            <!-- Product Info -->
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-gray-900 dark:text-white truncate">
                {{ product.name }}
              </p>
              <p class="text-xs text-gray-500 truncate">
                {{ product.brand || 'Sin marca' }} · {{ product.category || 'General' }}
              </p>
            </div>
          </div>

          <!-- Price & Stock -->
          <div class="flex flex-col items-end shrink-0">
            <span class="text-sm font-bold text-primary">{{
              formatCurrency(product.price)
            }}</span>
            <span
              class="text-[10px] font-medium px-1.5 py-0.5 rounded-full"
              :class="
                product.stock.lte(product.minStock)
                  ? 'bg-red-100 text-red-600 dark:bg-red-900/30 dark:text-red-400'
                  : 'bg-emerald-100 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-400'
              "
            >
              Stock: {{ product.stock.toString() }} {{ product.measurementUnit }}
            </span>
          </div>
        </button>

        <!-- Error incremental al cargar página siguiente -->
        <div
          v-if="productsPageError"
          class="flex items-center justify-between gap-2 p-2.5 rounded-lg bg-red-50 dark:bg-red-950/40 border border-red-200 dark:border-red-800 text-xs text-red-600 dark:text-red-400"
        >
          <span class="font-medium truncate">{{ productsPageError }}</span>
          <button
            type="button"
            data-testid="retry-products-btn"
            @click="retryLoadProducts"
            class="px-2.5 py-1 rounded bg-white dark:bg-red-900/40 border border-red-200 dark:border-red-700 font-bold shrink-0 cursor-pointer"
          >
            Reintentar
          </button>
        </div>

        <!-- Carga Progresiva de 7 en 7 -->
        <button
          v-if="remainingProductsCount > 0"
          type="button"
          data-testid="load-more-products-btn"
          :disabled="isLoadingMoreProducts"
          @click="loadMoreProducts"
          class="w-full py-2 text-xs font-bold text-primary hover:bg-primary/10 rounded-lg flex items-center justify-center gap-1.5 transition-colors cursor-pointer disabled:opacity-60"
        >
          <Loader2 v-if="isLoadingMoreProducts" :size="15" class="animate-spin" />
          <ChevronDown v-else :size="15" />
          <span>
            {{
              isLoadingMoreProducts
                ? 'Cargando 7 más...'
                : `Cargar más productos (${remainingProductsCount} restantes)`
            }}
          </span>
        </button>
      </div>
    </div>
  </BaseModal>
</template>

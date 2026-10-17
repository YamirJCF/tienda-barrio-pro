<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useInventoryStore } from '../stores/inventory';
import { useAuthStore } from '../stores/auth';
import { getSupabaseClient } from '../data/supabaseClient';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import type { Product } from '../types';
import Decimal from 'decimal.js';
import BaseModal from './ui/BaseModal.vue';
import BaseInput from './ui/BaseInput.vue';
import { Search, SearchX, Loader2 } from 'lucide-vue-next';

// Props
interface Props {
  modelValue: boolean;
}

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
const isSearching = ref(false);
const serverResults = ref<Product[] | null>(null);

let debounceTimeout: any = null;

const performSearch = async (term: string) => {
  const clean = term.trim();
  if (!clean) {
    serverResults.value = null;
    isSearching.value = false;
    return;
  }

  isSearching.value = true;
  try {
    const storeId = authStore.currentStore?.id || inventoryStore.products[0]?.storeId;
    const supabase = getSupabaseClient();
    if (storeId && supabase) {
      const { data, error } = await supabase.rpc('buscar_producto_pos', {
        p_store_id: storeId,
        p_term: clean,
        p_limit: 30,
        p_offset: 0
      });

      if (!error && data) {
        const res = data as any;
        if (Array.isArray(res.data)) {
          serverResults.value = res.data.map((item: any) => ({
            id: item.id,
            name: item.name,
            plu: item.plu,
            price: new Decimal(item.price),
            cost: undefined,
            stock: new Decimal(item.current_stock ?? 0),
            minStock: 5,
            brand: '',
            category: 'General',
            isWeighable: Boolean(item.is_weighable),
            measurementUnit: item.measurement_unit || 'un',
            storeId: storeId
          }));
          return;
        }
      }
    }
    // Fallback to local store
    serverResults.value = inventoryStore.searchProducts(clean);
  } catch (e) {
    serverResults.value = inventoryStore.searchProducts(clean);
  } finally {
    isSearching.value = false;
  }
};

watch(searchQuery, (newVal) => {
  clearTimeout(debounceTimeout);
  if (!newVal.trim()) {
    serverResults.value = null;
    isSearching.value = false;
    return;
  }
  debounceTimeout = setTimeout(() => {
    performSearch(newVal);
  }, 250);
});

// Computed
const filteredProducts = computed(() => {
  if (serverResults.value !== null) {
    return serverResults.value;
  }
  return inventoryStore.products.slice(0, 20); // Show first 20 if no search
});

// Methods
const close = () => {
  emit('update:modelValue', false);
  searchQuery.value = '';
  serverResults.value = null;
};

const selectProduct = (product: Product) => {
  emit('select', product);
  close();
};

// Focus input when modal opens
watch(
  () => props.modelValue,
  (isOpen) => {
    if (isOpen) {
      setTimeout(() => {
        searchInput.value?.focus();
      }, 100);
    }
  },
);
</script>

<template>
  <BaseModal
    :model-value="modelValue"
    @update:model-value="close"
    max-height="85vh"
    content-class="flex flex-col"
  >
    <template #header>
        <div class="flex-none px-4 pb-2 w-full">
               <BaseInput
                  ref="searchInput"
                  v-model="searchQuery"
                  placeholder="Buscar por nombre, marca o PLU..."
                  :icon="Search"
                />
         </div>
    </template>

    <!-- Content (Results List) -->
    <div class="flex-1 overflow-y-auto p-3">
            <!-- Loading Indicator -->
            <div v-if="isSearching" class="flex items-center justify-center h-32 text-gray-400">
              <Loader2 :size="32" class="animate-spin text-primary opacity-60" />
            </div>

            <!-- Empty State -->
            <div
              v-else-if="filteredProducts.length === 0"
              class="flex flex-col items-center justify-center h-40 text-gray-400"
            >
              <SearchX :size="48" class="mb-2 opacity-50" />
              <p class="text-sm">No se encontraron productos</p>
            </div>

            <!-- Product List -->
            <div v-else class="space-y-2">
              <button
                v-for="product in filteredProducts"
                :key="product.id"
                class="w-full flex items-center justify-between gap-3 p-3 rounded-lg bg-white dark:bg-gray-800 border border-gray-100 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 active:scale-[0.98] transition-all text-left"
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
            </div>
    </div>
  </BaseModal>
</template>

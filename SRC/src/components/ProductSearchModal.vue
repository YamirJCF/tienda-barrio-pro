<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useInventoryStore } from '../stores/inventory';
import type { Product } from '../types';
import BaseModal from './ui/BaseModal.vue';
import BaseInput from './ui/BaseInput.vue';

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

// State
const searchQuery = ref('');
const searchInput = ref<any>(null);

// Computed
const filteredProducts = computed(() => {
  if (!searchQuery.value.trim()) {
    return inventoryStore.products.slice(0, 20); // Show first 20 if no search
  }
  return inventoryStore.searchProducts(searchQuery.value);
});

// Methods
const close = () => {
  emit('update:modelValue', false);
  searchQuery.value = '';
};

const selectProduct = (product: Product) => {
  emit('select', product);
  close();
};

import { Decimal } from 'decimal.js';

const formatCurrency = (price: Decimal | number | string) => {
  let value: number;
  if (typeof price === 'object' && 'toNumber' in price) {
    value = price.toNumber();
  } else {
    value = typeof price === 'string' ? parseFloat(price) : price;
  }
  
  return `$ ${Math.round(value)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`;
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
                  icon="search"
                />
         </div>
    </template>

    <!-- Content (Results List) -->
    <div class="flex-1 overflow-y-auto p-3">
            <!-- Empty State -->
            <div
              v-if="filteredProducts.length === 0"
              class="flex flex-col items-center justify-center h-40 text-gray-400"
            >
              <span class="material-symbols-outlined text-4xl mb-2 opacity-50">search_off</span>
              <p class="text-sm">No se encontraron productos</p>
            </div>

            <!-- Product List -->
            <div class="space-y-2">
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
                        : 'bg-green-100 text-green-600 dark:bg-green-900/30 dark:text-green-400'
                    "
                  >
                    {{ product.stock }} {{ product.measurementUnit }}
                  </span>
                </div>
              </button>
            </div>
            </div>
  </BaseModal>
</template>

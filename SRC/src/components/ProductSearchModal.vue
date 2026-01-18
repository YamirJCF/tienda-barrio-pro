<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useInventoryStore, type Product } from '../stores/inventory';

// Props
interface Props {
  modelValue: boolean;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'select': [product: Product];
}>();

const inventoryStore = useInventoryStore();

// State
const searchQuery = ref('');
const searchInput = ref<HTMLInputElement | null>(null);

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

const formatCurrency = (price: any) => {
  const value = typeof price === 'object' && price.toNumber ? price.toNumber() : parseFloat(price);
  return `$ ${Math.round(value).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".")}`;
};

// Focus input when modal opens
watch(() => props.modelValue, (isOpen) => {
  if (isOpen) {
    setTimeout(() => {
      searchInput.value?.focus();
    }, 100);
  }
});
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div
        v-if="modelValue"
        class="fixed inset-0 z-50 flex items-end justify-center"
        @click.self="close"
      >
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-slate-900/60 backdrop-blur-[2px]" @click="close"></div>
        
        <!-- Modal -->
        <div class="relative w-full max-w-md h-[85vh] bg-white dark:bg-background-dark rounded-t-2xl shadow-2xl flex flex-col animate-slide-up">
          <!-- Header -->
          <div class="flex-none border-b border-gray-200 dark:border-gray-700 rounded-t-2xl">
            <!-- Drag Handle -->
            <div class="flex justify-center pt-3 pb-2 cursor-pointer" @click="close">
              <div class="h-1.5 w-12 rounded-full bg-gray-300 dark:bg-gray-600"></div>
            </div>
            
            <!-- Search Input -->
            <div class="px-4 pb-4">
              <div class="relative">
                <span class="material-symbols-outlined absolute left-3 top-2.5 text-gray-400 text-xl">search</span>
                <input
                  ref="searchInput"
                  v-model="searchQuery"
                  type="text"
                  placeholder="Buscar por nombre, marca o PLU..."
                  class="w-full h-10 pl-10 pr-4 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white placeholder:text-gray-400 focus:border-primary focus:ring-1 focus:ring-primary outline-none text-sm"
                />
              </div>
            </div>
          </div>

          <!-- Results List -->
          <div class="flex-1 overflow-y-auto p-3">
            <!-- Empty State -->
            <div v-if="filteredProducts.length === 0" class="flex flex-col items-center justify-center h-40 text-gray-400">
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
                  <div class="flex items-center justify-center bg-gray-100 dark:bg-gray-700 rounded-md h-10 w-12 shrink-0">
                    <span class="text-xs font-bold text-gray-600 dark:text-gray-300">{{ product.plu || '---' }}</span>
                  </div>
                  
                  <!-- Product Info -->
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-gray-900 dark:text-white truncate">{{ product.name }}</p>
                    <p class="text-xs text-gray-500 truncate">{{ product.brand || 'Sin marca' }} · {{ product.category || 'General' }}</p>
                  </div>
                </div>

                <!-- Price & Stock -->
                <div class="flex flex-col items-end shrink-0">
                  <span class="text-sm font-bold text-primary">{{ formatCurrency(product.price) }}</span>
                  <span 
                    class="text-[10px] font-medium px-1.5 py-0.5 rounded-full"
                    :class="product.stock <= product.minStock 
                      ? 'bg-red-100 text-red-600 dark:bg-red-900/30 dark:text-red-400' 
                      : 'bg-green-100 text-green-600 dark:bg-green-900/30 dark:text-green-400'"
                  >
                    {{ product.stock }} {{ product.unit }}
                  </span>
                </div>
              </button>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.3s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

@keyframes slideUp {
  from { transform: translateY(100%); }
  to { transform: translateY(0); }
}

.animate-slide-up {
  animation: slideUp 0.3s ease-out;
}
</style>

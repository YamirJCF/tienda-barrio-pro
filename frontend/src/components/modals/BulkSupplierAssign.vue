<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { X, Package, Check, Search } from 'lucide-vue-next';
import { useSuppliersStore } from '@/stores/suppliers';
import { useInventoryStore } from '@/stores/inventory';

const props = defineProps<{
  modelValue: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'assigned': [];
}>();

const suppliersStore = useSuppliersStore();
const inventoryStore = useInventoryStore();

const searchQuery = ref('');
const selectedCategory = ref<string | null>(null);
const selectedProducts = ref<Set<string>>(new Set());
const selectedSupplierId = ref<string | null>(null);
const isLoading = ref(false);

// Computed
const filteredProducts = computed(() => {
  let products = inventoryStore.products.filter(p => !p.supplierId);
  
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    products = products.filter(p => p.name.toLowerCase().includes(q));
  }
  
  if (selectedCategory.value) {
    products = products.filter(p => p.category === selectedCategory.value);
  }
  
  return products;
});

const categories = computed(() => {
  const cats = new Set(inventoryStore.products.map(p => p.category).filter(Boolean));
  return Array.from(cats);
});

const unassignedCount = computed(() => 
  inventoryStore.products.filter(p => !p.supplierId).length
);

// Methods
const toggleProduct = (productId: string) => {
  if (selectedProducts.value.has(productId)) {
    selectedProducts.value.delete(productId);
  } else {
    selectedProducts.value.add(productId);
  }
};

const selectAll = () => {
  filteredProducts.value.forEach(p => selectedProducts.value.add(p.id));
};

const clearSelection = () => {
  selectedProducts.value.clear();
};

const close = () => {
  emit('update:modelValue', false);
};

const handleAssign = async () => {
  if (!selectedSupplierId.value || selectedProducts.value.size === 0) return;
  
  isLoading.value = true;
  
  const result = await suppliersStore.bulkAssignSupplier(
    Array.from(selectedProducts.value),
    selectedSupplierId.value
  );
  
  isLoading.value = false;
  
  if (result.success) {
    emit('assigned');
    close();
  } else {
    alert(result.error || 'Error al asignar proveedor');
  }
};

onMounted(async () => {
  // Ensure suppliers are loaded
  if (suppliersStore.suppliers.length === 0) {
    const storeId = inventoryStore.products[0]?.storeId;
    if (storeId) {
      await suppliersStore.fetchSuppliers(storeId);
    }
  }
});
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div 
        v-if="modelValue"
        class="fixed inset-0 z-50 flex items-end justify-center sm:items-center"
      >
        <!-- Backdrop -->
        <div 
          class="absolute inset-0 bg-black/50 backdrop-blur-sm"
          @click="close"
        />
        
        <!-- Modal Content -->
        <div class="relative w-full max-w-lg bg-white dark:bg-slate-900 rounded-t-3xl sm:rounded-2xl shadow-2xl max-h-[90vh] flex flex-col">
          
          <!-- Header -->
          <div class="flex items-center justify-between p-4 border-b border-slate-200 dark:border-slate-800">
            <div class="flex items-center gap-3">
              <div class="p-2 bg-indigo-100 dark:bg-indigo-900/30 rounded-xl">
                <Package :size="20" class="text-indigo-600 dark:text-indigo-400" />
              </div>
              <div>
                <h3 class="text-lg font-bold text-slate-900 dark:text-white">
                  Asignar Proveedor
                </h3>
                <p class="text-xs text-slate-500">
                  {{ unassignedCount }} productos sin proveedor
                </p>
              </div>
            </div>
            <button 
              @click="close"
              class="p-2 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800"
            >
              <X :size="20" class="text-slate-500" />
            </button>
          </div>
          
          <!-- Search & Filter -->
          <div class="p-4 space-y-3 border-b border-slate-200 dark:border-slate-800">
            <div class="relative">
              <Search :size="18" class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
              <input
                v-model="searchQuery"
                type="text"
                placeholder="Buscar productos..."
                class="w-full pl-10 pr-4 py-2 bg-slate-100 dark:bg-slate-800 rounded-xl text-sm"
              />
            </div>
            
            <div class="flex gap-2 overflow-x-auto pb-1">
              <button
                @click="selectedCategory = null"
                :class="[
                  'px-3 py-1 rounded-full text-xs font-medium whitespace-nowrap',
                  !selectedCategory 
                    ? 'bg-indigo-500 text-white' 
                    : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300'
                ]"
              >
                Todos
              </button>
              <button
                v-for="cat in categories"
                :key="cat"
                @click="selectedCategory = cat"
                :class="[
                  'px-3 py-1 rounded-full text-xs font-medium whitespace-nowrap',
                  selectedCategory === cat 
                    ? 'bg-indigo-500 text-white' 
                    : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300'
                ]"
              >
                {{ cat }}
              </button>
            </div>
          </div>
          
          <!-- Product List -->
          <div class="flex-1 overflow-y-auto p-4">
            <div class="flex justify-between mb-3">
              <span class="text-xs text-slate-500">
                {{ selectedProducts.size }} seleccionados
              </span>
              <div class="flex gap-2">
                <button @click="selectAll" class="text-xs text-indigo-500 font-medium">
                  Seleccionar todo
                </button>
                <button @click="clearSelection" class="text-xs text-slate-400 font-medium">
                  Limpiar
                </button>
              </div>
            </div>
            
            <div class="space-y-2">
              <button
                v-for="product in filteredProducts"
                :key="product.id"
                @click="toggleProduct(product.id)"
                :class="[
                  'w-full flex items-center gap-3 p-3 rounded-xl text-left transition-colors',
                  selectedProducts.has(product.id)
                    ? 'bg-indigo-50 dark:bg-indigo-900/20 border-2 border-indigo-500'
                    : 'bg-slate-50 dark:bg-slate-800 border-2 border-transparent'
                ]"
              >
                <div 
                  :class="[
                    'w-5 h-5 rounded-md flex items-center justify-center shrink-0',
                    selectedProducts.has(product.id)
                      ? 'bg-indigo-500'
                      : 'bg-slate-200 dark:bg-slate-700'
                  ]"
                >
                  <Check v-if="selectedProducts.has(product.id)" :size="14" class="text-white" />
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-medium text-slate-900 dark:text-white truncate">
                    {{ product.name }}
                  </p>
                  <p class="text-xs text-slate-500">
                    {{ product.category || 'Sin categoría' }}
                  </p>
                </div>
              </button>
            </div>
            
            <p v-if="filteredProducts.length === 0" class="text-center text-sm text-slate-500 py-8">
              No hay productos sin proveedor
            </p>
          </div>
          
          <!-- Footer -->
          <div class="p-4 border-t border-slate-200 dark:border-slate-800 space-y-3">
            <label class="block">
              <span class="text-xs font-medium text-slate-600 dark:text-slate-400 mb-1 block">
                ¿Quién te trae esto?
              </span>
              <select
                v-model="selectedSupplierId"
                class="w-full p-3 bg-slate-100 dark:bg-slate-800 rounded-xl text-sm"
              >
                <option :value="null" disabled>Selecciona proveedor...</option>
                <option 
                  v-for="supplier in suppliersStore.suppliers" 
                  :key="supplier.id" 
                  :value="supplier.id"
                >
                  {{ supplier.name }}
                </option>
              </select>
            </label>
            
            <button
              @click="handleAssign"
              :disabled="!selectedSupplierId || selectedProducts.size === 0 || isLoading"
              class="w-full py-3 bg-indigo-500 text-white rounded-xl font-bold text-sm disabled:opacity-50 active:scale-95 transition-transform"
            >
              {{ isLoading ? 'Guardando...' : 'Guardar Asociación' }}
            </button>
          </div>
          
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.modal-enter-active,
.modal-leave-active {
  transition: all 0.3s ease;
}
.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}
.modal-enter-from > div:last-child,
.modal-leave-to > div:last-child {
  transform: translateY(100%);
}
</style>

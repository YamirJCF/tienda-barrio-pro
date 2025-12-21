<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useInventoryStore, type Product } from '../stores/inventory';
import { Decimal } from 'decimal.js';

// Props
interface Props {
  modelValue: boolean;
  productId?: number; // For editing existing product
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'saved': [product: Product];
}>();

const inventoryStore = useInventoryStore();

// Form State
const formData = ref({
  name: '',
  brand: '',
  category: '',
  plu: '',
  saleMode: 'unit' as 'unit' | 'weight',
  cost: '',
  price: '',
  stock: '',
  minStock: '5',
});

// Computed
const margin = computed(() => {
  if (!formData.value.cost || !formData.value.price) return 0;
  const cost = parseFloat(formData.value.cost);
  const price = parseFloat(formData.value.price);
  if (cost === 0) return 0;
  return (price - cost) / cost * 100;
});

const isValid = computed(() => {
  return formData.value.name.trim() !== '' &&
         formData.value.price.trim() !== '' &&
         parseFloat(formData.value.price) > 0;
});



// Methods
const close = () => {
  emit('update:modelValue', false);
  setTimeout(resetForm, 300); // Reset after animation
};

const resetForm = () => {
  formData.value = {
    name: '',
    brand: '',
    category: '',
    plu: '',
    saleMode: 'unit',
    cost: '',
    price: '',
    stock: '',
    minStock: '5',
  };
};

const save = () => {
  if (!isValid.value) return;

  const productData = {
    name: formData.value.name.trim(),
    brand: formData.value.brand.trim() || undefined,
    category: formData.value.category.trim() || undefined,
    plu: formData.value.plu.trim() || undefined,
    saleMode: formData.value.saleMode,
    price: new Decimal(formData.value.price),
    cost: formData.value.cost ? new Decimal(formData.value.cost) : undefined,
    stock: parseInt(formData.value.stock) || 0,
    minStock: parseInt(formData.value.minStock) || 5,
    unit: 'un', // Default unit
  };

  let savedProduct: Product;
  
  if (props.productId) {
    // Update existing
    savedProduct = inventoryStore.updateProduct(props.productId, productData)!;
  } else {
    // Create new
    savedProduct = inventoryStore.addProduct(productData);
  }

  emit('saved', savedProduct);
  close();
};

const toggleSaleMode = (mode: 'unit' | 'weight') => {
  formData.value.saleMode = mode;
};

// Watch for product editing
watch(() => props.productId, (id) => {
  if (id) {
    const product = inventoryStore.getProductById(id);
    if (product) {
      formData.value = {
        name: product.name,
        brand: product.brand || '',
        category: product.category || '',
        plu: product.plu || '',
        saleMode: product.saleMode,
        cost: product.cost?.toString() || '',
        price: product.price.toString(),
        stock: product.stock.toString(),
        minStock: product.minStock.toString(),
      };
    }
  } else {
    resetForm();
  }
}, { immediate: true });
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div
        v-if="modelValue"
        class="fixed inset-0 z-50 flex items-end justify-center bg-gray-800/80"
        @click.self="close"
      >
        <!-- Modal Container -->
        <div class="w-full h-[90vh] bg-white dark:bg-background-dark rounded-t-xl shadow-2xl flex flex-col relative max-w-[480px] mx-auto animate-slide-up">
          <!-- Header -->
          <div class="flex-none bg-white dark:bg-background-dark border-b border-gray-100 dark:border-gray-800 z-20 sticky top-0 rounded-t-xl">
            <!-- Drag Handle -->
            <div class="flex justify-center pt-3 pb-1 cursor-grab" @click="close">
              <div class="h-1.5 w-12 rounded-full bg-gray-200 dark:bg-gray-700"></div>
            </div>
            <!-- Title Bar -->
            <div class="flex items-center justify-between px-4 pb-3">
              <h2 class="text-slate-900 dark:text-white text-lg font-bold leading-tight tracking-tight pl-1">
                {{ productId ? 'Editar Producto' : 'Nuevo Producto' }}
              </h2>
              <button
                class="flex h-10 w-10 items-center justify-center rounded-full bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 text-slate-900 dark:text-white transition-colors"
                @click="close"
              >
                <span class="material-symbols-outlined text-[24px]">close</span>
              </button>
            </div>
          </div>

          <!-- Scrollable Form Body -->
          <div class="flex-1 overflow-y-auto bg-white dark:bg-background-dark p-4 pb-24 no-scrollbar">
            <form class="grid grid-cols-12 gap-3" @submit.prevent="save">
              <!-- Nombre del Producto -->
              <div class="col-span-12">
                <label class="block text-[10px] uppercase font-bold text-gray-500 dark:text-gray-400 tracking-wider mb-1">
                  Nombre del Producto
                </label>
                <input
                  v-model="formData.name"
                  class="w-full h-10 rounded-lg border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-800 px-3 text-sm text-slate-900 dark:text-white placeholder:text-gray-400 focus:border-primary focus:ring-1 focus:ring-primary outline-none transition-all shadow-sm"
                  placeholder="Ej. Coca Cola 3L Original"
                  type="text"
                  required
                />
              </div>

              <!-- Marca y PLU -->
              <div class="col-span-8 relative">
                <label class="block text-[10px] uppercase font-bold text-gray-500 dark:text-gray-400 tracking-wider mb-1">
                  Marca
                </label>
                <div class="relative">
                  <input
                    v-model="formData.brand"
                    class="w-full h-10 rounded-lg border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-800 pl-3 pr-9 text-sm text-slate-900 dark:text-white placeholder:text-gray-400 focus:border-primary focus:ring-1 focus:ring-primary outline-none transition-all shadow-sm"
                    placeholder="Buscar..."
                    type="text"
                  />
                  <span class="material-symbols-outlined absolute right-2.5 top-2 text-gray-400 text-[20px] pointer-events-none">search</span>
                </div>
              </div>
              <div class="col-span-4">
                <label class="block text-[10px] uppercase font-bold text-gray-500 dark:text-gray-400 tracking-wider mb-1">
                  Cód. Rápido
                </label>
                <input
                  v-model="formData.plu"
                  class="w-full h-10 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 px-3 text-sm text-slate-900 dark:text-white placeholder:text-gray-400 focus:border-primary focus:ring-1 focus:ring-primary outline-none transition-all text-center font-medium"
                  placeholder="PLU"
                  type="tel"
                  maxlength="4"
                />
              </div>

              <!-- Categoría -->
              <div class="col-span-12 relative">
                <label class="block text-[10px] uppercase font-bold text-gray-500 dark:text-gray-400 tracking-wider mb-1">
                  Categoría
                </label>
                <div class="relative">
                  <input
                    v-model="formData.category"
                    class="w-full h-10 rounded-lg border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-800 pl-3 pr-10 text-sm text-slate-900 dark:text-white focus:border-primary focus:ring-1 focus:ring-primary outline-none transition-all shadow-sm"
                    placeholder="Ej. Bebidas, Despensa, Lácteos..."
                    type="text"
                    list="categories"
                  />
                  <datalist id="categories">
                    <option value="Bebidas y Licores" />
                    <option value="Despensa" />
                    <option value="Lácteos y Huevos" />
                    <option value="Aseo del Hogar" />
                    <option value="Panadería" />
                    <option value="Snacks" />
                  </datalist>
                  <span class="material-symbols-outlined absolute right-3 top-2.5 text-gray-500 pointer-events-none text-[20px]">arrow_drop_down</span>
                </div>
              </div>

              <!-- Modo de Venta (Segmented Control) -->
              <div class="col-span-12 pt-1">
                <div class="bg-gray-100 dark:bg-gray-800 p-1 rounded-lg flex h-10 shadow-inner">
                  <button
                    type="button"
                    class="flex-1 flex items-center justify-center gap-2 rounded-md text-xs font-bold transition-all"
                    :class="formData.saleMode === 'unit' 
                      ? 'bg-white dark:bg-gray-700 text-primary dark:text-primary-400 shadow-sm border border-gray-200 dark:border-gray-600' 
                      : 'text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700/50'"
                    @click="toggleSaleMode('unit')"
                  >
                    <span class="material-symbols-outlined text-[16px]" :class="formData.saleMode === 'unit' ? 'fill-1' : ''">package_2</span>
                    Unidad
                  </button>
                  <button
                    type="button"
                    class="flex-1 flex items-center justify-center gap-2 rounded-md text-xs font-medium transition-all"
                    :class="formData.saleMode === 'weight' 
                      ? 'bg-white dark:bg-gray-700 text-primary dark:text-primary-400 shadow-sm border border-gray-200 dark:border-gray-600' 
                      : 'text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700/50'"
                    @click="toggleSaleMode('weight')"
                  >
                    <span class="material-symbols-outlined text-[16px]" :class="formData.saleMode === 'weight' ? 'fill-1' : ''">scale</span>
                    Valor/Peso
                  </button>
                </div>
              </div>

              <!-- Costo y Precio -->
              <div class="col-span-6 pt-2">
                <label class="block text-[10px] uppercase font-bold text-gray-500 dark:text-gray-400 tracking-wider mb-1">
                  Costo ($)
                </label>
                <div class="relative">
                  <span class="absolute left-3 top-2.5 text-gray-400 text-sm font-medium">$</span>
                  <input
                    v-model="formData.cost"
                    class="w-full h-10 rounded-lg border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-800 pl-7 pr-3 text-sm text-slate-900 dark:text-white placeholder:text-gray-400 focus:border-primary focus:ring-1 focus:ring-primary outline-none shadow-sm font-medium"
                    placeholder="0"
                    type="number"
                    step="0.01"
                  />
                </div>
              </div>
              <div class="col-span-6 pt-2">
                <label class="block text-[10px] uppercase font-bold text-primary dark:text-primary-400 tracking-wider mb-1">
                  Precio Venta ($)
                </label>
                <div class="relative">
                  <span class="absolute left-3 top-2.5 text-primary/70 text-sm font-bold">$</span>
                  <input
                    v-model="formData.price"
                    class="w-full h-10 rounded-lg border border-primary/30 bg-primary/5 dark:bg-primary/10 pl-7 pr-3 text-sm text-primary dark:text-primary-400 placeholder:text-primary/40 focus:border-primary focus:ring-1 focus:ring-primary outline-none shadow-sm font-bold"
                    placeholder="0"
                    type="number"
                    step="0.01"
                    required
                  />
                </div>
              </div>
              <div class="col-span-12 flex justify-end -mt-1">
                <span v-if="margin > 0" class="text-[11px] font-medium text-emerald-600 dark:text-emerald-400 flex items-center gap-1">
                  <span class="material-symbols-outlined text-[12px]">trending_up</span>
                  Margen estimado: {{ margin.toFixed(1) }}%
                </span>
              </div>

              <!-- Inventario -->
              <div class="col-span-12 border-t border-gray-100 dark:border-gray-800 my-2"></div>
              <div class="col-span-6">
                <label class="block text-[10px] uppercase font-bold text-gray-500 dark:text-gray-400 tracking-wider mb-1">
                  Stock Actual
                </label>
                <input
                  v-model="formData.stock"
                  class="w-full h-10 rounded-lg border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-800 px-3 text-sm text-slate-900 dark:text-white placeholder:text-gray-400 focus:border-primary focus:ring-1 focus:ring-primary outline-none transition-all shadow-sm"
                  placeholder="0"
                  type="number"
                  min="0"
                />
              </div>
              <div class="col-span-6">
                <label class="block text-[10px] uppercase font-bold text-gray-500 dark:text-gray-400 tracking-wider mb-1">
                  Stock Mínimo
                </label>
                <input
                  v-model="formData.minStock"
                  class="w-full h-10 rounded-lg border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-800 px-3 text-sm text-slate-900 dark:text-white placeholder:text-gray-400 focus:border-primary focus:ring-1 focus:ring-primary outline-none transition-all shadow-sm"
                  placeholder="5"
                  type="number"
                  min="0"
                />
              </div>

              <!-- Spacer for scroll -->
              <div class="col-span-12 h-4"></div>
            </form>
          </div>

          <!-- Sticky Footer -->
          <div class="flex-none absolute bottom-0 left-0 w-full bg-white dark:bg-background-dark border-t border-gray-200 dark:border-gray-700 p-4 z-30 pb-8">
            <div class="grid grid-cols-2 gap-3">
              <button
                type="button"
                class="h-11 rounded-xl bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-200 font-bold text-sm tracking-wide hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors"
                @click="close"
              >
                Cancelar
              </button>
              <button
                type="button"
                class="h-11 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-sm tracking-wide shadow-lg shadow-primary/20 transition-colors flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                :disabled="!isValid"
                @click="save"
              >
                <span class="material-symbols-outlined text-[18px]">save</span>
                Guardar
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

.modal-enter-active .animate-slide-up {
  animation: slideUp 0.3s ease-out;
}

.modal-leave-active .animate-slide-up {
  animation: slideDown 0.3s ease-in;
}

@keyframes slideDown {
  from {
    transform: translateY(0);
  }
  to {
    transform: translateY(100%);
  }
}

/* Hide scrollbar */
.no-scrollbar::-webkit-scrollbar {
  display: none;
}
.no-scrollbar {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
</style>

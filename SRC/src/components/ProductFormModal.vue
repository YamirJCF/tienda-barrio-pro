<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useInventoryStore } from '../stores/inventory';
import type { Product } from '../types';
import { Decimal } from 'decimal.js';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { logger } from '../utils/logger';
import { getMarginLoss } from '../utils/currency';

// Props
// WO-001: Changed productId from number to string for UUID
interface Props {
  modelValue: boolean;
  productId?: string; // UUID for editing existing product
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  saved: [product: Product];
}>();

const inventoryStore = useInventoryStore();
// const { roundHybrid50 } = useCurrencyFormat(); // No longer needed for saving

// WO-003: Preservar stock original para evitar pérdida de precisión
const originalStock = ref<Decimal | null>(null);
const stockWasModified = ref(false);

// WO-004: Formatear cantidad a máximo 2 decimales para visualización
const formatQuantity = (qty: number | Decimal): string => {
  const num = qty instanceof Decimal ? qty.toNumber() : Number(qty);
  return Number.isInteger(num) ? num.toString() : num.toFixed(2);
};

// UX-FIX: Conversión automática entre unidades de peso
// Factores: 1 kg = 2.20462 lb, 1 kg = 1000 g, 1 lb = 453.592 g
const convertStock = (
  value: number,
  fromUnit: 'kg' | 'lb' | 'g',
  toUnit: 'kg' | 'lb' | 'g',
): number => {
  if (fromUnit === toUnit) return value;

  // Primero convertir a gramos (unidad base)
  let grams: number;
  switch (fromUnit) {
    case 'kg':
      grams = value * 1000;
      break;
    case 'lb':
      grams = value * 453.592;
      break;
    case 'g':
      grams = value;
      break;
  }

  // Luego convertir de gramos a la unidad destino
  switch (toUnit) {
    case 'kg':
      return grams / 1000;
    case 'lb':
      return grams / 453.592;
    case 'g':
      return grams;
  }
};

// Form State
const formData = ref({
  name: '',
  brand: '',
  category: '',
  plu: '',
  saleMode: 'unit' as 'unit' | 'weight',
  measurementUnit: 'lb' as 'kg' | 'lb' | 'g',
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
  return ((price - cost) / cost) * 100;
});

// BR-02: Alerta de Ineficiencia Financiera
const marginLoss = computed(() => {
  if (!formData.value.price) return 0;
  const price = parseFloat(formData.value.price);
  if (isNaN(price) || price <= 0) return 0;

  // Calculate loss per unit if paid in cash
  return getMarginLoss(price).toNumber();
});

// T-007: Validación de precio vs costo
const isPriceBelowCost = computed(() => {
  if (!formData.value.cost || !formData.value.price) return false;
  const cost = parseFloat(formData.value.cost);
  const price = parseFloat(formData.value.price);
  return price > 0 && cost > 0 && price < cost;
});

const isValid = computed(() => {
  const name = String(formData.value.name || '').trim();
  const price = formData.value.price;
  const priceNum = parseFloat(String(price));

  return name !== '' && price !== '' && price !== null && !isNaN(priceNum) && priceNum > 0;
});

// UX-FIX: Categorías dinámicas basadas en productos existentes
const existingCategories = computed(() => {
  const cats = new Set(
    inventoryStore.products.map((p) => p.category).filter((c): c is string => Boolean(c)),
  );
  return Array.from(cats).sort();
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
    measurementUnit: 'lb',
    cost: '',
    price: '',
    stock: '',
    minStock: '5',
  };
  // WO-003: Reset stock tracking
  originalStock.value = null;
  stockWasModified.value = false;
};

const save = () => {
  logger.log('[ProductForm] Save called');
  logger.log('[ProductForm] isValid:', isValid.value);
  logger.log('[ProductForm] formData:', formData.value);

  if (!isValid.value) {
    logger.log('[ProductForm] Form not valid, aborting');
    return;
  }

  // WO-003: Usar originalStock si no fue modificado por el usuario
  const stockToSave =
    props.productId && originalStock.value && !stockWasModified.value
      ? originalStock.value
      : new Decimal(formData.value.stock || 0);

  // BR-01: Libertad de Precios. No se fuerza el redondeo aquí.
  const productData = {
    name: formData.value.name.trim(),
    brand: formData.value.brand.trim() || undefined,
    category: formData.value.category.trim() || undefined,
    plu: formData.value.plu.trim() || undefined,
    isWeighable: formData.value.saleMode === 'weight',
    measurementUnit:
      formData.value.saleMode === 'weight' ? formData.value.measurementUnit : ('un' as const),
    price: new Decimal(formData.value.price), // Exact price
    cost: formData.value.cost ? new Decimal(formData.value.cost) : undefined,
    stock: stockToSave,
    minStock: parseInt(formData.value.minStock) || 5,
  };

  logger.log('[ProductForm] productData:', productData);

  let savedProduct: Product;

  if (props.productId) {
    // Update existing
    logger.log('[ProductForm] Updating product:', props.productId);
    savedProduct = inventoryStore.updateProduct(props.productId, productData)!;
  } else {
    // Create new
    logger.log('[ProductForm] Creating new product');
    savedProduct = inventoryStore.addProduct(productData);
  }

  logger.log('[ProductForm] Saved product:', savedProduct);
  emit('saved', savedProduct);
  close();
};

const toggleSaleMode = (mode: 'unit' | 'weight') => {
  formData.value.saleMode = mode;
};

// Watch for product editing
watch(
  () => props.productId,
  (id) => {
    if (id) {
      const product = inventoryStore.getProductById(id);
      if (product) {
        // WO-003: Guardar stock original para preservar precisión
        originalStock.value = product.stock;
        stockWasModified.value = false;

        // WO-004: Derivar saleMode de isWeighable y cargar measurementUnit
        formData.value = {
          name: product.name,
          brand: product.brand || '',
          category: product.category || '',
          plu: product.plu || '',
          saleMode: product.isWeighable ? 'weight' : 'unit',
          measurementUnit:
            product.measurementUnit !== 'un'
              ? (product.measurementUnit as 'kg' | 'lb' | 'g')
              : 'lb',
          cost: product.cost?.toString() || '',
          price: product.price.toString(),
          stock: formatQuantity(product.stock), // WO-004: Mostrar formateado
          minStock: product.minStock.toString(),
        };
      }
    } else {
      resetForm();
    }
  },
  { immediate: true },
);

// WO-003: Detectar modificación del stock por el usuario
watch(
  () => formData.value.stock,
  (newVal, oldVal) => {
    if (oldVal !== undefined && newVal !== oldVal) {
      stockWasModified.value = true;
    }
  },
);

// UX-FIX: Conversión automática de stock al cambiar unidad de medida
watch(
  () => formData.value.measurementUnit,
  (newUnit, oldUnit) => {
    // Solo convertir si estamos en modo peso y hay un valor de stock
    if (formData.value.saleMode !== 'weight') return;
    if (!formData.value.stock || formData.value.stock === '0') return;
    if (oldUnit === newUnit) return;

    const currentValue = parseFloat(formData.value.stock.replace(',', '.'));
    if (isNaN(currentValue)) return;

    const convertedValue = convertStock(currentValue, oldUnit, newUnit);
    formData.value.stock = formatQuantity(convertedValue);

    logger.log(
      `[ProductForm] Stock convertido: ${currentValue} ${oldUnit} → ${formatQuantity(convertedValue)} ${newUnit}`,
    );
  },
);
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
        <div
          class="w-full h-[90vh] bg-white dark:bg-background-dark rounded-t-xl shadow-2xl flex flex-col relative max-w-[480px] mx-auto animate-slide-up"
        >
          <!-- Header -->
          <div
            class="flex-none bg-white dark:bg-background-dark border-b border-gray-100 dark:border-gray-800 z-20 sticky top-0 rounded-t-xl"
          >
            <!-- Drag Handle -->
            <div class="flex justify-center pt-3 pb-1 cursor-grab" @click="close">
              <div class="h-1.5 w-12 rounded-full bg-gray-200 dark:bg-gray-700"></div>
            </div>
            <!-- Title Bar -->
            <div class="flex items-center justify-between px-4 pb-3">
              <div class="flex items-center gap-2">
                <h2
                  class="text-slate-900 dark:text-white text-lg font-bold leading-tight tracking-tight"
                >
                  {{ productId ? 'Editar Producto' : 'Nuevo Producto' }}
                </h2>
                <!-- WO-004: Badge tipo producto (solo al editar) -->
                <span
                  v-if="productId"
                  class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold"
                  :class="
                    formData.saleMode === 'weight'
                      ? 'bg-amber-100 dark:bg-amber-900/50 text-amber-700 dark:text-amber-300'
                      : 'bg-blue-100 dark:bg-blue-900/50 text-blue-700 dark:text-blue-300'
                  "
                >
                  <span class="material-symbols-outlined text-[12px]">
                    {{ formData.saleMode === 'weight' ? 'scale' : 'package_2' }}
                  </span>
                  {{ formData.saleMode === 'weight' ? 'Peso' : 'Unidad' }}
                </span>
              </div>
              <button
                class="flex h-10 w-10 items-center justify-center rounded-full bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 text-slate-900 dark:text-white transition-colors"
                @click="close"
              >
                <span class="material-symbols-outlined text-[24px]">close</span>
              </button>
            </div>
          </div>

          <!-- Scrollable Form Body -->
          <div
            class="flex-1 overflow-y-auto bg-white dark:bg-background-dark p-4 pb-24 no-scrollbar"
          >
            <form class="grid grid-cols-12 gap-3" @submit.prevent="save">
              <!-- Nombre del Producto -->
              <div class="col-span-12">
                <label
                  class="block text-[10px] uppercase font-bold text-gray-500 dark:text-gray-400 tracking-wider mb-1"
                >
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
                <label
                  class="block text-[10px] uppercase font-bold text-gray-500 dark:text-gray-400 tracking-wider mb-1"
                >
                  Marca
                </label>
                <div class="relative">
                  <input
                    v-model="formData.brand"
                    class="w-full h-10 rounded-lg border border-gray-300 dark:border-gray-700 bg-white dark:bg-gray-800 pl-3 pr-9 text-sm text-slate-900 dark:text-white placeholder:text-gray-400 focus:border-primary focus:ring-1 focus:ring-primary outline-none transition-all shadow-sm"
                    placeholder="Buscar..."
                    type="text"
                  />
                  <span
                    class="material-symbols-outlined absolute right-2.5 top-2 text-gray-400 text-[20px] pointer-events-none"
                    >search</span
                  >
                </div>
              </div>
              <div class="col-span-4">
                <label
                  class="block text-[10px] uppercase font-bold text-gray-500 dark:text-gray-400 tracking-wider mb-1"
                >
                  Cód. Rápido
                </label>
                <input
                  v-model="formData.plu"
                  @input="formData.plu = formData.plu.replace(/[^0-9]/g, '')"
                  class="w-full h-10 rounded-lg border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 px-3 text-sm text-slate-900 dark:text-white placeholder:text-gray-400 focus:border-primary focus:ring-1 focus:ring-primary outline-none transition-all text-center font-medium"
                  placeholder="PLU"
                  type="tel"
                  maxlength="4"
                />
              </div>

              <!-- Categoría -->
              <div class="col-span-12 relative">
                <label
                  class="block text-[10px] uppercase font-bold text-gray-500 dark:text-gray-400 tracking-wider mb-1"
                >
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
                    <option v-for="cat in existingCategories" :key="cat" :value="cat" />
                  </datalist>
                  <span
                    class="material-symbols-outlined absolute right-3 top-2.5 text-gray-500 pointer-events-none text-[20px]"
                    >arrow_drop_down</span
                  >
                </div>
              </div>

              <!-- Modo de Venta (Segmented Control) -->
              <div class="col-span-12 pt-1">
                <div class="bg-gray-100 dark:bg-gray-800 p-1 rounded-lg flex h-10 shadow-inner">
                  <button
                    type="button"
                    class="flex-1 flex items-center justify-center gap-2 rounded-md text-xs font-bold transition-all"
                    :class="
                      formData.saleMode === 'unit'
                        ? 'bg-white dark:bg-gray-700 text-primary dark:text-primary-400 shadow-sm border border-gray-200 dark:border-gray-600'
                        : 'text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700/50'
                    "
                    @click="toggleSaleMode('unit')"
                  >
                    <span
                      class="material-symbols-outlined text-[16px]"
                      :class="formData.saleMode === 'unit' ? 'fill-1' : ''"
                      >package_2</span
                    >
                    Unidad
                  </button>
                  <button
                    type="button"
                    class="flex-1 flex items-center justify-center gap-2 rounded-md text-xs font-medium transition-all"
                    :class="
                      formData.saleMode === 'weight'
                        ? 'bg-white dark:bg-gray-700 text-primary dark:text-primary-400 shadow-sm border border-gray-200 dark:border-gray-600'
                        : 'text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700/50'
                    "
                    @click="toggleSaleMode('weight')"
                  >
                    <span
                      class="material-symbols-outlined text-[16px]"
                      :class="formData.saleMode === 'weight' ? 'fill-1' : ''"
                      >scale</span
                    >
                    Valor/Peso
                  </button>
                </div>
              </div>

              <!-- Selector de Unidad (solo si es por peso) -->
              <div v-if="formData.saleMode === 'weight'" class="col-span-12">
                <label
                  class="block text-[10px] uppercase font-bold text-primary dark:text-primary-400 tracking-wider mb-1"
                >
                  Unidad de Medida
                </label>
                <div class="flex gap-2">
                  <button
                    type="button"
                    class="flex-1 h-10 rounded-lg flex items-center justify-center gap-1 text-xs font-bold transition-all border"
                    :class="
                      formData.measurementUnit === 'kg'
                        ? 'bg-primary text-white border-primary'
                        : 'bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-300 border-gray-200 dark:border-gray-700 hover:bg-gray-100'
                    "
                    @click="formData.measurementUnit = 'kg'"
                  >
                    kg
                  </button>
                  <button
                    type="button"
                    class="flex-1 h-10 rounded-lg flex items-center justify-center gap-1 text-xs font-bold transition-all border"
                    :class="
                      formData.measurementUnit === 'lb'
                        ? 'bg-primary text-white border-primary'
                        : 'bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-300 border-gray-200 dark:border-gray-700 hover:bg-gray-100'
                    "
                    @click="formData.measurementUnit = 'lb'"
                  >
                    Libras
                  </button>
                  <button
                    type="button"
                    class="flex-1 h-10 rounded-lg flex items-center justify-center gap-1 text-xs font-bold transition-all border"
                    :class="
                      formData.measurementUnit === 'g'
                        ? 'bg-primary text-white border-primary'
                        : 'bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-300 border-gray-200 dark:border-gray-700 hover:bg-gray-100'
                    "
                    @click="formData.measurementUnit = 'g'"
                  >
                    Gramos
                  </button>
                </div>
                <p class="text-[10px] text-gray-500 mt-1">
                  El precio y stock se manejarán en la unidad seleccionada
                </p>
              </div>

              <!-- Costo y Precio -->
              <div class="col-span-6 pt-2">
                <label
                  class="block text-[10px] uppercase font-bold text-gray-500 dark:text-gray-400 tracking-wider mb-1"
                >
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
                <label
                  class="block text-[10px] uppercase font-bold text-primary dark:text-primary-400 tracking-wider mb-1"
                >
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

              <!-- BR-02: Warning Fuga de Margen (Efectivo) -->
              <div v-if="marginLoss > 0" class="col-span-12 -mt-1">
                <div
                  class="flex items-center gap-2 p-2.5 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-700/50 rounded-lg"
                >
                  <span
                    class="material-symbols-outlined text-yellow-600 dark:text-yellow-400 text-lg"
                    >paid</span
                  >
                  <div class="flex flex-col">
                    <span class="text-xs font-bold text-yellow-700 dark:text-yellow-300">
                      ⚠️ Alerta de Eficiencia
                    </span>
                    <span
                      class="text-[10px] font-medium text-yellow-700 dark:text-yellow-300 leading-tight"
                    >
                      Perderás <b>${{ marginLoss }}</b> por unidad en ventas en efectivo debido al
                      redondeo obligatorio.
                    </span>
                  </div>
                </div>
              </div>

              <!-- T-007: Warning precio menor que costo -->
              <div v-if="isPriceBelowCost" class="col-span-12 -mt-1">
                <div
                  class="flex items-center gap-2 p-2.5 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700/50 rounded-lg"
                >
                  <span class="material-symbols-outlined text-amber-600 dark:text-amber-400 text-lg"
                    >warning</span
                  >
                  <span class="text-xs font-medium text-amber-700 dark:text-amber-300"
                    >El precio de venta es menor al costo</span
                  >
                </div>
              </div>

              <div class="col-span-12 flex justify-end -mt-1">
                <span
                  v-if="margin > 0"
                  class="text-[11px] font-medium text-emerald-600 dark:text-emerald-400 flex items-center gap-1"
                >
                  <span class="material-symbols-outlined text-[12px]">trending_up</span>
                  Margen estimado: {{ margin.toFixed(1) }}%
                </span>
              </div>

              <!-- Inventario -->
              <div class="col-span-12 border-t border-gray-100 dark:border-gray-800 my-2"></div>
              <div class="col-span-6">
                <label
                  class="block text-[10px] uppercase font-bold text-gray-500 dark:text-gray-400 tracking-wider mb-1"
                >
                  Stock Actual
                  <!-- WO-004: Mostrar unidad de medida -->
                  <span
                    v-if="formData.saleMode === 'weight'"
                    class="text-primary dark:text-primary-400"
                  >
                    ({{ formData.measurementUnit }})
                  </span>
                  <span v-else class="text-gray-400">(un)</span>
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
                <label
                  class="block text-[10px] uppercase font-bold text-gray-500 dark:text-gray-400 tracking-wider mb-1"
                >
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
              <div class="col-span-12 h-20"></div>

              <!-- Sticky Footer (inside form) -->
              <div
                class="col-span-12 fixed bottom-0 left-0 right-0 max-w-[480px] mx-auto bg-white dark:bg-background-dark border-t border-gray-200 dark:border-gray-700 p-4 z-30 pb-8"
              >
                <div class="grid grid-cols-2 gap-3">
                  <button
                    type="button"
                    class="h-11 rounded-xl bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-200 font-bold text-sm tracking-wide hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors"
                    @click="close"
                  >
                    Cancelar
                  </button>
                  <button
                    type="submit"
                    class="h-11 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-sm tracking-wide shadow-lg shadow-primary/20 transition-colors flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                    :disabled="!isValid"
                  >
                    <span class="material-symbols-outlined text-[18px]">save</span>
                    Guardar
                  </button>
                </div>
              </div>
            </form>
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

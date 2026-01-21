<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useInventoryStore, type Product } from '../stores/inventory';
import { Decimal } from 'decimal.js';
import { useQuantityFormat } from '../composables/useQuantityFormat';

const router = useRouter();
const inventoryStore = useInventoryStore();
const { formatStock } = useQuantityFormat();

// Form state
const supplierName = ref('');
const invoiceRef = ref('');
const paymentType = ref<'contado' | 'credito'>('contado');

// Product entry state
interface EntryItem {
  productId: number;
  productName: string;
  quantity: string;
  unitCost: string;
  measurementUnit: string; // Unidad del producto (destino)
  entryUnit: string; // Unidad elegida por usuario (entrada)
  isWeighable: boolean; // Para mostrar selector de unidad
}

const entryItems = ref<EntryItem[]>([]);
const searchQuery = ref('');
const showSearchResults = ref(false);

// UX-FIX: Toast notification state
const toastMessage = ref('');
const toastType = ref<'success' | 'error'>('success');
const showToast = ref(false);

const showToastNotification = (message: string, type: 'success' | 'error' = 'success') => {
  toastMessage.value = message;
  toastType.value = type;
  showToast.value = true;
  setTimeout(() => {
    showToast.value = false;
  }, 3000);
};

// Computed
const filteredProducts = computed(() => {
  if (!searchQuery.value.trim()) {
    return [];
  }
  return inventoryStore.searchProducts(searchQuery.value);
});

const productNotFound = computed(() => {
  return searchQuery.value.trim() && filteredProducts.value.length === 0;
});

const totalItems = computed(() => entryItems.value.length);

const totalInvoice = computed(() => {
  return entryItems.value.reduce((sum, item) => {
    const qty = parseFloat(item.quantity) || 0;
    const cost = parseFloat(item.unitCost) || 0;
    return sum + qty * cost;
  }, 0);
});

// Watch search query to show/hide results
watch(searchQuery, (val) => {
  showSearchResults.value = val.trim().length > 0;
});

// UX-FIX: Persistir borrador en sessionStorage
const DRAFT_KEY = 'stock-entry-draft';

watch(
  entryItems,
  (items) => {
    if (items.length > 0) {
      sessionStorage.setItem(DRAFT_KEY, JSON.stringify(items));
    } else {
      sessionStorage.removeItem(DRAFT_KEY);
    }
  },
  { deep: true },
);

// Restaurar borrador al montar
onMounted(() => {
  const saved = sessionStorage.getItem(DRAFT_KEY);
  if (saved) {
    try {
      entryItems.value = JSON.parse(saved);
    } catch {
      sessionStorage.removeItem(DRAFT_KEY);
    }
  }
});

// Methods
const goBack = () => {
  router.push('/inventory');
};

const formatCurrency = (val: number) => {
  return val.toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
};

const getSubtotal = (item: EntryItem) => {
  let qty = parseFloat(item.quantity) || 0;
  const cost = parseFloat(item.unitCost) || 0;

  // CRITICAL FIX: Convertir cantidad a unidad del producto para cálculo correcto
  // El costo está en measurementUnit, la cantidad en entryUnit
  if (item.isWeighable && item.entryUnit !== item.measurementUnit) {
    qty = convertWeight(qty, item.entryUnit, item.measurementUnit);
  }

  return qty * cost;
};

// WO-002: Conversión de peso con redondeo UX
const convertWeight = (value: number, from: string, to: string): number => {
  if (from === to) return value;

  // Paso 1: Convertir a gramos (unidad base)
  let grams: number;
  switch (from) {
    case 'kg':
      grams = value * 1000;
      break;
    case 'lb':
      grams = value * 453.592;
      break;
    case 'g':
      grams = value;
      break;
    default:
      return value;
  }

  // Paso 2: Convertir de gramos a unidad destino
  let result: number;
  switch (to) {
    case 'kg':
      result = grams / 1000;
      break;
    case 'lb':
      result = grams / 453.592;
      break;
    case 'g':
      result = grams;
      break;
    default:
      return value;
  }

  // Redondeo UX: gramos enteros, kg/lb 2 decimales
  return to === 'g' ? Math.round(result) : Math.round(result * 100) / 100;
};

const selectProduct = (product: Product) => {
  // Check if product already in list
  const exists = entryItems.value.find((item) => item.productId === product.id);
  if (exists) {
    searchQuery.value = '';
    showSearchResults.value = false;
    return;
  }

  // UX-FIX: Agregar al principio (unshift) para acceso rápido
  entryItems.value.unshift({
    productId: product.id,
    productName: product.name,
    quantity: '1',
    unitCost: product.cost?.toString() || product.price.toString(),
    measurementUnit: product.measurementUnit || 'un',
    entryUnit: product.measurementUnit || 'un', // Iniciar con unidad del producto
    isWeighable: product.isWeighable,
  });

  searchQuery.value = '';
  showSearchResults.value = false;
};

const createNewProduct = () => {
  // Navigate to inventory with the product name as a param or open modal
  // For now, just clear search
  alert(`Funcionalidad para crear "${searchQuery.value}" próximamente`);
  searchQuery.value = '';
  showSearchResults.value = false;
};

const removeItem = (index: number) => {
  entryItems.value.splice(index, 1);
};

const clearDraft = () => {
  if (entryItems.value.length > 0) {
    if (!confirm('¿Limpiar todos los productos?')) return;
  }
  entryItems.value = [];
  supplierName.value = '';
  invoiceRef.value = '';
};

const saveEntry = () => {
  if (entryItems.value.length === 0) {
    showToastNotification('Agrega al menos un producto', 'error');
    return;
  }

  // Update stock for each item with unit conversion
  entryItems.value.forEach((item) => {
    let qty = parseFloat(item.quantity);

    // WO-005: Convertir si es pesable y unidades diferentes
    if (item.isWeighable && item.entryUnit !== item.measurementUnit) {
      qty = convertWeight(qty, item.entryUnit, item.measurementUnit);
    }

    if (qty > 0) {
      inventoryStore.updateStock(item.productId, new Decimal(qty));
    }
  });

  // Success feedback and navigate back
  sessionStorage.removeItem(DRAFT_KEY); // Limpiar borrador
  showToastNotification(
    `Entrada guardada: ${totalItems.value} productos, $${formatCurrency(totalInvoice.value)} total`,
    'success',
  );
  setTimeout(() => router.push('/inventory'), 1500);
};

const clearSearch = () => {
  searchQuery.value = '';
  showSearchResults.value = false;
};
</script>

<template>
  <div class="flex flex-col h-screen bg-gray-50 dark:bg-slate-900">
    <!-- Header -->
    <header
      class="sticky top-0 z-30 bg-white dark:bg-slate-800 border-b border-gray-200 dark:border-slate-700 px-4 py-4"
    >
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <button
            @click="goBack"
            aria-label="Volver"
            class="p-1 -ml-1 text-slate-700 dark:text-slate-200"
          >
            <span class="material-symbols-outlined text-2xl">arrow_back</span>
          </button>
          <h1 class="text-lg font-bold text-slate-900 dark:text-white">Nueva Entrada</h1>
        </div>
        <button class="text-orange-500 font-semibold text-sm">Ayuda</button>
      </div>
    </header>

    <!-- Main Content -->
    <main class="flex-1 overflow-y-auto pb-44">
      <!-- Supplier & Invoice Section -->
      <section
        class="bg-white dark:bg-slate-800 mx-4 mt-4 rounded-xl p-4 shadow-sm border border-gray-100 dark:border-slate-700"
      >
        <!-- Proveedor -->
        <div class="mb-4">
          <label
            class="block text-[11px] font-semibold text-slate-500 uppercase tracking-wider mb-1.5"
            >Proveedor</label
          >
          <div class="relative">
            <input
              v-model="supplierName"
              type="text"
              placeholder="Distribuidora Central"
              class="w-full px-4 py-3 bg-white dark:bg-slate-700 rounded-lg border border-gray-200 dark:border-slate-600 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-orange-500 focus:border-transparent text-sm"
            />
            <span
              class="material-symbols-outlined absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 text-xl"
              >content_paste</span
            >
          </div>
        </div>

        <!-- Ref. Factura -->
        <div class="mb-4">
          <label
            class="block text-[11px] font-semibold text-slate-500 uppercase tracking-wider mb-1.5"
            >Ref. Factura</label
          >
          <input
            v-model="invoiceRef"
            type="text"
            placeholder="FAC-2023-891"
            class="w-full px-4 py-3 bg-white dark:bg-slate-700 rounded-lg border border-gray-200 dark:border-slate-600 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-orange-500 focus:border-transparent text-sm"
          />
        </div>

        <!-- Payment Type Toggle -->
        <div class="flex rounded-lg border border-gray-200 dark:border-slate-600 overflow-hidden">
          <button
            @click="paymentType = 'contado'"
            :class="[
              'flex-1 py-2.5 text-sm font-medium transition-colors',
              paymentType === 'contado'
                ? 'bg-gray-100 dark:bg-slate-700 text-slate-900 dark:text-white'
                : 'bg-white dark:bg-slate-800 text-slate-500',
            ]"
          >
            Contado
          </button>
          <button
            @click="paymentType = 'credito'"
            :class="[
              'flex-1 py-2.5 text-sm font-medium transition-colors border-l border-gray-200 dark:border-slate-600',
              paymentType === 'credito'
                ? 'bg-orange-50 dark:bg-orange-900/20 text-orange-500'
                : 'bg-white dark:bg-slate-800 text-slate-500',
            ]"
          >
            Crédito
          </button>
        </div>
      </section>

      <!-- Products Section -->
      <section class="mx-4 mt-6">
        <div class="flex items-center justify-between mb-3">
          <h2 class="text-base font-bold text-slate-900 dark:text-white">
            Productos ({{ totalItems }})
          </h2>
          <button
            v-if="totalItems > 0"
            @click="clearDraft"
            class="text-xs font-medium text-slate-500 bg-gray-100 dark:bg-slate-700 px-3 py-1.5 rounded-md hover:bg-gray-200 dark:hover:bg-slate-600 transition-colors"
          >
            Borrador
          </button>
        </div>

        <!-- Empty State -->
        <div
          v-if="entryItems.length === 0"
          class="bg-white dark:bg-slate-800 rounded-xl p-8 text-center border border-gray-100 dark:border-slate-700"
        >
          <span class="material-symbols-outlined text-5xl text-slate-300 mb-2">inventory_2</span>
          <p class="text-sm text-slate-400">Busca productos abajo para agregarlos</p>
        </div>

        <!-- Product Cards -->
        <div v-else class="space-y-3">
          <article
            v-for="(item, index) in entryItems"
            :key="item.productId"
            class="bg-white dark:bg-slate-800 rounded-xl p-4 shadow-sm border border-gray-100 dark:border-slate-700"
          >
            <!-- Product Header -->
            <div class="flex items-start justify-between mb-3">
              <h3 class="text-sm font-bold text-slate-900 dark:text-white">
                {{ item.productName }}
              </h3>
              <button
                @click="removeItem(index)"
                class="text-orange-400 hover:text-orange-500 p-1 -mr-1 -mt-1"
              >
                <span class="material-symbols-outlined text-xl">delete</span>
              </button>
            </div>

            <!-- Quantity and Cost Inputs -->
            <div class="flex items-end gap-3 mb-3">
              <div class="flex-1">
                <label
                  class="block text-[10px] font-semibold text-slate-500 uppercase tracking-wider mb-1"
                  >Cant. ({{ item.entryUnit }})</label
                >
                <!-- Selector de unidad para pesables -->
                <div v-if="item.isWeighable" class="flex gap-1 mb-1.5">
                  <button
                    v-for="unit in ['kg', 'lb', 'g']"
                    :key="unit"
                    @click="item.entryUnit = unit"
                    type="button"
                    :class="
                      item.entryUnit === unit
                        ? 'bg-orange-500 text-white'
                        : 'bg-gray-200 dark:bg-slate-600 text-slate-600 dark:text-slate-300'
                    "
                    class="px-2 py-1 text-xs font-bold rounded transition-colors"
                  >
                    {{ unit }}
                  </button>
                </div>
                <input
                  v-model="item.quantity"
                  type="number"
                  :step="item.entryUnit === 'un' ? '1' : '0.01'"
                  min="0"
                  class="w-full px-3 py-2.5 bg-gray-50 dark:bg-slate-700 rounded-lg border border-gray-200 dark:border-slate-600 text-slate-900 dark:text-white text-sm font-medium focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                />
              </div>
              <div class="flex-[2]">
                <label
                  class="block text-[10px] font-semibold text-slate-500 uppercase tracking-wider mb-1"
                  >Costo Unit.</label
                >
                <div class="flex items-center gap-1">
                  <span class="text-slate-400 font-medium">$</span>
                  <input
                    v-model="item.unitCost"
                    type="number"
                    step="100"
                    min="0"
                    class="flex-1 px-3 py-2.5 bg-gray-50 dark:bg-slate-700 rounded-lg border border-gray-200 dark:border-slate-600 text-slate-900 dark:text-white text-sm font-medium focus:ring-2 focus:ring-orange-500 focus:border-transparent"
                  />
                </div>
              </div>
            </div>

            <!-- Subtotal -->
            <div
              class="flex items-center justify-between pt-2 border-t border-gray-100 dark:border-slate-700"
            >
              <span class="text-[10px] font-semibold text-slate-500 uppercase tracking-wider"
                >Subtotal</span
              >
              <span class="text-sm font-bold text-slate-900 dark:text-white"
                >${{ formatCurrency(getSubtotal(item)) }}</span
              >
            </div>
          </article>
        </div>
      </section>
    </main>

    <!-- Bottom Search Bar -->
    <div
      class="fixed bottom-[76px] left-0 right-0 bg-slate-100 dark:bg-slate-800 border-t border-gray-200 dark:border-slate-700 px-4 py-3 z-20"
    >
      <!-- Search Results Dropdown -->
      <Transition name="slide-up">
        <div
          v-if="showSearchResults && (filteredProducts.length > 0 || productNotFound)"
          class="absolute bottom-full left-0 right-0 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-700 rounded-t-xl shadow-lg max-h-64 overflow-y-auto"
        >
          <!-- Product not found - Create option -->
          <div v-if="productNotFound" class="p-4">
            <div class="flex items-center gap-2 text-slate-500 mb-3">
              <span class="material-symbols-outlined text-xl">person_search</span>
              <span class="text-sm"
                >No existe un producto llamado "<strong class="text-slate-700 dark:text-white">{{
                  searchQuery
                }}</strong
                >"</span
              >
            </div>
            <button
              @click="createNewProduct"
              class="w-full flex items-center justify-center gap-2 py-3 bg-orange-50 dark:bg-orange-900/20 text-orange-500 font-semibold rounded-xl border border-orange-200 dark:border-orange-800 hover:bg-orange-100 dark:hover:bg-orange-900/30 transition-colors"
            >
              <span class="material-symbols-outlined text-xl">add_circle</span>
              Crear "{{ searchQuery }}" (Nuevo)
            </button>
          </div>

          <!-- Product results list -->
          <div v-else class="divide-y divide-gray-100 dark:divide-slate-700">
            <button
              v-for="product in filteredProducts"
              :key="product.id"
              @click="selectProduct(product)"
              class="w-full p-3 text-left hover:bg-gray-50 dark:hover:bg-slate-700 transition-colors flex items-center justify-between"
            >
              <div>
                <p class="font-semibold text-slate-900 dark:text-white text-sm">
                  {{ product.name }}
                </p>
                <p class="text-xs text-slate-500">
                  Stock: {{ formatStock(product.stock, product.measurementUnit) }}
                  {{ product.measurementUnit }}
                </p>
              </div>
              <span class="material-symbols-outlined text-orange-500">add_circle</span>
            </button>
          </div>
        </div>
      </Transition>

      <!-- Search Input -->
      <div class="relative">
        <span
          class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-xl"
          >search</span
        >
        <input
          v-model="searchQuery"
          type="text"
          placeholder="Buscar producto..."
          class="w-full pl-10 pr-10 py-3 bg-white dark:bg-slate-700 rounded-full border border-gray-200 dark:border-slate-600 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-orange-500 focus:border-transparent text-sm"
        />
        <button
          v-if="searchQuery"
          @click="clearSearch"
          class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
        >
          <span class="material-symbols-outlined text-xl">close</span>
        </button>
      </div>
    </div>

    <!-- Bottom Total Bar -->
    <footer
      class="fixed bottom-0 left-0 right-0 bg-slate-800 dark:bg-slate-900 px-4 py-3 z-30 flex items-center justify-between"
    >
      <div>
        <p class="text-[10px] font-semibold text-slate-400 uppercase tracking-wider">
          Total Factura
        </p>
        <p class="text-2xl font-bold text-white">${{ formatCurrency(totalInvoice) }}</p>
      </div>
      <button
        @click="saveEntry"
        :disabled="entryItems.length === 0"
        class="flex items-center gap-2 px-6 py-3 bg-orange-500 text-white font-bold rounded-xl hover:bg-orange-600 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-lg"
      >
        <span class="material-symbols-outlined text-xl">save</span>
        GUARDAR
      </button>
    </footer>

    <!-- Toast Notification -->
    <Transition name="toast">
      <div
        v-if="showToast"
        class="fixed top-20 left-1/2 -translate-x-1/2 z-50 px-6 py-3 rounded-xl shadow-lg font-medium"
        :class="toastType === 'success' ? 'bg-green-600 text-white' : 'bg-red-500 text-white'"
      >
        {{ toastMessage }}
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.slide-up-enter-active,
.slide-up-leave-active {
  transition: all 0.2s ease;
}

.slide-up-enter-from,
.slide-up-leave-to {
  opacity: 0;
  transform: translateY(10px);
}

/* Toast animations */
.toast-enter-active,
.toast-leave-active {
  transition: all 0.3s ease;
}

.toast-enter-from,
.toast-leave-to {
  opacity: 0;
  transform: translate(-50%, -20px);
}
</style>

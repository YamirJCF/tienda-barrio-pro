<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useInventoryStore, type Product } from '../stores/inventory';
import { Decimal } from 'decimal.js';

const router = useRouter();
const inventoryStore = useInventoryStore();

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
  measurementUnit: string;
}

const entryItems = ref<EntryItem[]>([]);
const searchQuery = ref('');
const showSearchResults = ref(false);

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
    return sum + (qty * cost);
  }, 0);
});

// Watch search query to show/hide results
watch(searchQuery, (val) => {
  showSearchResults.value = val.trim().length > 0;
});

// Methods
const goBack = () => {
  router.push('/inventory');
};

const formatCurrency = (val: number) => {
  return val.toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
};

const getSubtotal = (item: EntryItem) => {
  const qty = parseFloat(item.quantity) || 0;
  const cost = parseFloat(item.unitCost) || 0;
  return qty * cost;
};

const selectProduct = (product: Product) => {
  // Check if product already in list
  const exists = entryItems.value.find(item => item.productId === product.id);
  if (exists) {
    searchQuery.value = '';
    showSearchResults.value = false;
    return;
  }

  entryItems.value.push({
    productId: product.id,
    productName: product.name,
    quantity: '1',
    unitCost: product.cost?.toString() || product.price.toString(),
    measurementUnit: product.measurementUnit || 'un',
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
    alert('Agrega al menos un producto');
    return;
  }

  // Update stock for each item
  entryItems.value.forEach(item => {
    const qty = parseFloat(item.quantity);
    if (qty > 0) {
      inventoryStore.updateStock(item.productId, new Decimal(qty));
    }
  });

  // Success feedback and navigate back
  alert(`✅ Entrada guardada: ${totalItems.value} productos, $${formatCurrency(totalInvoice.value)} total`);
  router.push('/inventory');
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
      class="sticky top-0 z-30 bg-white dark:bg-slate-800 border-b border-gray-200 dark:border-slate-700 px-4 py-4">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <button @click="goBack" aria-label="Volver" class="p-1 -ml-1 text-slate-700 dark:text-slate-200">
            <span class="material-symbols-outlined text-2xl">arrow_back</span>
          </button>
          <h1 class="text-lg font-bold text-slate-900 dark:text-white">Nueva Entrada</h1>
        </div>
        <button class="text-orange-500 font-semibold text-sm">
          Ayuda
        </button>
      </div>
    </header>

    <!-- Main Content -->
    <main class="flex-1 overflow-y-auto pb-32">
      <!-- Supplier & Invoice Section -->
      <section
        class="bg-white dark:bg-slate-800 mx-4 mt-4 rounded-xl p-4 shadow-sm border border-gray-100 dark:border-slate-700">
        <!-- Proveedor -->
        <div class="mb-4">
          <label
            class="block text-[11px] font-semibold text-slate-500 uppercase tracking-wider mb-1.5">Proveedor</label>
          <div class="relative">
            <input v-model="supplierName" type="text" placeholder="Distribuidora Central"
              class="w-full px-4 py-3 bg-white dark:bg-slate-700 rounded-lg border border-gray-200 dark:border-slate-600 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-orange-500 focus:border-transparent text-sm" />
            <span
              class="material-symbols-outlined absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 text-xl">content_paste</span>
          </div>
        </div>

        <!-- Ref. Factura -->
        <div class="mb-4">
          <label class="block text-[11px] font-semibold text-slate-500 uppercase tracking-wider mb-1.5">Ref.
            Factura</label>
          <input v-model="invoiceRef" type="text" placeholder="FAC-2023-891"
            class="w-full px-4 py-3 bg-white dark:bg-slate-700 rounded-lg border border-gray-200 dark:border-slate-600 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-orange-500 focus:border-transparent text-sm" />
        </div>

        <!-- Payment Type Toggle -->
        <div class="flex rounded-lg border border-gray-200 dark:border-slate-600 overflow-hidden">
          <button @click="paymentType = 'contado'" :class="[
            'flex-1 py-2.5 text-sm font-medium transition-colors',
            paymentType === 'contado'
              ? 'bg-gray-100 dark:bg-slate-700 text-slate-900 dark:text-white'
              : 'bg-white dark:bg-slate-800 text-slate-500'
          ]">
            Contado
          </button>
          <button @click="paymentType = 'credito'" :class="[
            'flex-1 py-2.5 text-sm font-medium transition-colors border-l border-gray-200 dark:border-slate-600',
            paymentType === 'credito'
              ? 'bg-orange-50 dark:bg-orange-900/20 text-orange-500'
              : 'bg-white dark:bg-slate-800 text-slate-500'
          ]">
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
          <button v-if="totalItems > 0" @click="clearDraft"
            class="text-xs font-medium text-slate-500 bg-gray-100 dark:bg-slate-700 px-3 py-1.5 rounded-md hover:bg-gray-200 dark:hover:bg-slate-600 transition-colors">
            Borrador
          </button>
        </div>

        <!-- Empty State -->
        <div v-if="entryItems.length === 0"
          class="bg-white dark:bg-slate-800 rounded-xl p-8 text-center border border-gray-100 dark:border-slate-700">
          <span class="material-symbols-outlined text-5xl text-slate-300 mb-2">inventory_2</span>
          <p class="text-sm text-slate-400">Busca productos abajo para agregarlos</p>
        </div>

        <!-- Product Cards -->
        <div v-else class="space-y-3">
          <article v-for="(item, index) in entryItems" :key="item.productId"
            class="bg-white dark:bg-slate-800 rounded-xl p-4 shadow-sm border border-gray-100 dark:border-slate-700">
            <!-- Product Header -->
            <div class="flex items-start justify-between mb-3">
              <h3 class="text-sm font-bold text-slate-900 dark:text-white">{{ item.productName }}</h3>
              <button @click="removeItem(index)" class="text-orange-400 hover:text-orange-500 p-1 -mr-1 -mt-1">
                <span class="material-symbols-outlined text-xl">delete</span>
              </button>
            </div>

            <!-- Quantity and Cost Inputs -->
            <div class="flex items-end gap-3 mb-3">
              <div class="flex-1">
                <label
                  class="block text-[10px] font-semibold text-slate-500 uppercase tracking-wider mb-1">Cant.</label>
                <input v-model="item.quantity" type="number" step="1" min="0"
                  class="w-full px-3 py-2.5 bg-gray-50 dark:bg-slate-700 rounded-lg border border-gray-200 dark:border-slate-600 text-slate-900 dark:text-white text-sm font-medium focus:ring-2 focus:ring-orange-500 focus:border-transparent" />
              </div>
              <div class="flex-[2]">
                <label class="block text-[10px] font-semibold text-slate-500 uppercase tracking-wider mb-1">Costo
                  Unit.</label>
                <div class="flex items-center gap-1">
                  <span class="text-slate-400 font-medium">$</span>
                  <input v-model="item.unitCost" type="number" step="100" min="0"
                    class="flex-1 px-3 py-2.5 bg-gray-50 dark:bg-slate-700 rounded-lg border border-gray-200 dark:border-slate-600 text-slate-900 dark:text-white text-sm font-medium focus:ring-2 focus:ring-orange-500 focus:border-transparent" />
                </div>
              </div>
            </div>

            <!-- Subtotal -->
            <div class="flex items-center justify-between pt-2 border-t border-gray-100 dark:border-slate-700">
              <span class="text-[10px] font-semibold text-slate-500 uppercase tracking-wider">Subtotal</span>
              <span class="text-sm font-bold text-slate-900 dark:text-white">${{ formatCurrency(getSubtotal(item))
                }}</span>
            </div>
          </article>
        </div>
      </section>
    </main>

    <!-- Bottom Search Bar -->
    <div
      class="fixed bottom-[76px] left-0 right-0 bg-slate-100 dark:bg-slate-800 border-t border-gray-200 dark:border-slate-700 px-4 py-3 z-20">
      <!-- Search Results Dropdown -->
      <Transition name="slide-up">
        <div v-if="showSearchResults && (filteredProducts.length > 0 || productNotFound)"
          class="absolute bottom-full left-0 right-0 bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-700 rounded-t-xl shadow-lg max-h-64 overflow-y-auto">
          <!-- Product not found - Create option -->
          <div v-if="productNotFound" class="p-4">
            <div class="flex items-center gap-2 text-slate-500 mb-3">
              <span class="material-symbols-outlined text-xl">person_search</span>
              <span class="text-sm">No existe un producto llamado "<strong class="text-slate-700 dark:text-white">{{
                  searchQuery }}</strong>"</span>
            </div>
            <button @click="createNewProduct"
              class="w-full flex items-center justify-center gap-2 py-3 bg-orange-50 dark:bg-orange-900/20 text-orange-500 font-semibold rounded-xl border border-orange-200 dark:border-orange-800 hover:bg-orange-100 dark:hover:bg-orange-900/30 transition-colors">
              <span class="material-symbols-outlined text-xl">add_circle</span>
              Crear "{{ searchQuery }}" (Nuevo)
            </button>
          </div>

          <!-- Product results list -->
          <div v-else class="divide-y divide-gray-100 dark:divide-slate-700">
            <button v-for="product in filteredProducts" :key="product.id" @click="selectProduct(product)"
              class="w-full p-3 text-left hover:bg-gray-50 dark:hover:bg-slate-700 transition-colors flex items-center justify-between">
              <div>
                <p class="font-semibold text-slate-900 dark:text-white text-sm">{{ product.name }}</p>
                <p class="text-xs text-slate-500">Stock: {{ product.stock.toFixed(1) }} {{ product.measurementUnit }}
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
          class="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 text-xl">search</span>
        <input v-model="searchQuery" type="text" placeholder="Buscar producto..."
          class="w-full pl-10 pr-10 py-3 bg-white dark:bg-slate-700 rounded-full border border-gray-200 dark:border-slate-600 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-orange-500 focus:border-transparent text-sm" />
        <button v-if="searchQuery" @click="clearSearch"
          class="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600">
          <span class="material-symbols-outlined text-xl">close</span>
        </button>
      </div>
    </div>

    <!-- Bottom Total Bar -->
    <footer
      class="fixed bottom-0 left-0 right-0 bg-slate-800 dark:bg-slate-900 px-4 py-3 z-30 flex items-center justify-between">
      <div>
        <p class="text-[10px] font-semibold text-slate-400 uppercase tracking-wider">Total Factura</p>
        <p class="text-2xl font-bold text-white">${{ formatCurrency(totalInvoice) }}</p>
      </div>
      <button @click="saveEntry" :disabled="entryItems.length === 0"
        class="flex items-center gap-2 px-6 py-3 bg-orange-500 text-white font-bold rounded-xl hover:bg-orange-600 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-lg">
        <span class="material-symbols-outlined text-xl">save</span>
        GUARDAR
      </button>
    </footer>
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
</style>

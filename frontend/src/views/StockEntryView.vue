<template>
  <div class="h-screen flex flex-col overflow-hidden bg-gray-900 text-gray-100">
    <!-- Header -->
    <header class="z-30 bg-gray-900/95 backdrop-blur border-b border-gray-800 px-4 py-4 flex items-center justify-between shrink-0">
      <div class="flex items-center gap-3">
        <button @click="router.back()" class="p-2 hover:bg-gray-800 rounded-lg transition-colors">
          <ArrowLeft class="text-gray-400" :size="24" />
        </button>
        <h1 class="text-xl font-bold text-white">Nueva Entrada</h1>
      </div>
      <div class="flex items-center gap-2">
        <span class="text-sm text-gray-400">{{ currentDate }}</span>
      </div>
    </header>

    <main class="flex-1 overflow-y-auto w-full p-4 space-y-6">
      <div class="max-w-3xl mx-auto space-y-6">
      <!-- Movement Reason & Link to Salidas -->
      <section class="bg-gray-800 rounded-xl p-4 shadow-lg border border-gray-700/50 flex flex-col md:flex-row gap-4 items-start md:items-end">
        <div class="flex-1 space-y-1 w-full">
           <label class="text-xs text-gray-400">Motivo de Entrada (Compra / Reposición)</label>
           <select
             v-model="reason"
             class="w-full bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-white outline-none focus:ring-2 focus:ring-emerald-500"
           >
             <option v-for="r in availableReasons" :key="r" :value="r">{{ r }}</option>
           </select>
        </div>

        <button
          type="button"
          @click="router.push('/stock-outputs')"
          class="px-3.5 py-2 rounded-lg text-xs font-semibold bg-gray-900 text-amber-300 border border-amber-500/30 hover:bg-gray-700 transition-colors shrink-0 cursor-pointer"
        >
          ¿Mermas, consumos o conteo? Ir a Salidas ($0) →
        </button>
      </section>

      <!-- Supplier Section (Strictly informational, decoupled from CxP per CHK-502/CHK-505) -->
      <section class="bg-gray-800 rounded-xl p-4 shadow-lg border border-gray-700/50">
        <div class="flex items-center justify-between mb-3 gap-2 flex-wrap">
          <h2 class="text-sm font-semibold text-gray-400 uppercase tracking-wider">Datos del Proveedor (Opcional)</h2>
          <span class="text-[11px] text-gray-400">Registro logístico independiente de Cuentas por Pagar</span>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="space-y-1">
            <label class="text-xs text-gray-400 block mb-1">Proveedor</label>
            <select
              v-model="selectedSupplierId"
              class="w-full bg-gray-900 border border-gray-700 rounded-lg px-3 py-2.5 text-white outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">-- Sin asignar --</option>
              <option
                v-for="supplier in suppliers"
                :key="supplier.id"
                :value="supplier.id"
              >
                {{ supplier.name }}
              </option>
            </select>
          </div>
          <div class="space-y-1">
            <BaseInput
              v-model="invoiceRef"
              label="Ref. Remisión / Factura (Informativo)"
              placeholder="Ej: REM-2026-001"
            />
          </div>
        </div>
      </section>

      <!-- Items List -->
      <section class="space-y-3">
         <div v-if="entryItems.length === 0" class="text-center py-10 opacity-50">
           <ListPlus class="mx-auto mb-2" :size="36" />
           <p>Busca productos abajo para agregarlos</p>
         </div>

         <div 
           v-for="(item, index) in entryItems" 
           :key="item.productId"
           class="bg-gray-800 rounded-xl p-3 shadow-sm border border-gray-700 flex flex-col gap-3 relative overflow-hidden group"
         >
            <div class="flex justify-between items-start">
              <div>
                <h3 class="font-medium text-white">{{ item.productName }}</h3>
                <p class="text-xs text-gray-400">{{ item.measurementUnit }}</p>
              </div>
              <button @click="removeItem(index)" class="text-gray-500 hover:text-red-400 p-1">
                <X :size="16" />
              </button>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-3 items-end">
              <div class="space-y-1">
                <label class="text-[10px] text-gray-400 uppercase">Cantidad</label>
                <div class="relative">
                  <input 
                    v-model.number="item.quantity"
                    type="number" 
                    min="0"
                    step="0.01"
                    class="w-full bg-gray-900 border border-gray-700 rounded-lg px-2 py-1.5 text-right text-white font-mono focus:ring-1 focus:ring-blue-500 outline-none"
                  />
                </div>
              </div>
              
              <div class="space-y-1">
                 <label class="text-[10px] text-gray-400 uppercase">Vencimiento</label>
                 <input 
                   v-model="item.expirationDate"
                   type="date"
                   class="w-full bg-gray-900 border border-gray-700 rounded-lg px-2 py-1.5 text-white text-sm focus:ring-1 focus:ring-blue-500 outline-none"
                 />
              </div>

              <!-- Cost -->
              <div class="space-y-1">
                <label class="text-[10px] text-gray-400 uppercase">Costo Unit.</label>
                <div class="relative">
                  <span class="absolute left-2 top-1.5 text-gray-500 text-xs">$</span>
                  <input
                    v-model.number="item.unitCost"
                    type="number"
                    min="0"
                    step="50"
                    class="w-full bg-gray-900 border border-gray-700 rounded-lg pl-5 pr-2 py-1.5 text-right text-white font-mono focus:ring-1 focus:ring-blue-500 outline-none"
                  />
                </div>
              </div>

              <!-- Sale Price -->
              <div class="space-y-1">
                <label class="text-[10px] text-gray-400 uppercase">Precio Venta</label>
                <div class="relative">
                  <span class="absolute left-2 top-1.5 text-gray-500 text-xs">$</span>
                  <input
                    v-model.number="item.salePrice"
                    type="number"
                    min="0"
                    step="50"
                    class="w-full bg-gray-900 border border-gray-700 rounded-lg pl-5 pr-2 py-1.5 text-right text-white font-mono focus:ring-1 focus:ring-emerald-500 outline-none"
                  />
                </div>
              </div>
            </div>

            
            <div class="text-right text-xs font-mono text-emerald-400 pt-2 border-t border-gray-700/50">
              Subtotal: {{ formatCurrency(item.quantity * item.unitCost) }}
            </div>
         </div>
      </section>
      </div> <!-- End of max-w-3xl wrapper -->
    </main>

    <!-- Footer Search & Actions -->
    <div class="bg-gray-900/95 backdrop-blur border-t border-gray-800 p-3 pb-6 z-40 shrink-0">
       <div class="max-w-3xl mx-auto space-y-3">
          <!-- Total -->
          <div class="flex justify-between items-end px-2">
            <div class="text-xs text-gray-400">
              {{ entryItems.length }} items
            </div>
            <div class="text-right">
              <div class="text-xs text-gray-400 mb-0.5">Total Entrada</div>
              <div class="text-2xl font-bold text-white font-mono leading-none">
                {{ formatCurrency(totalInvoice) }}
              </div>
            </div>
          </div>

          <!-- Search Input -->
          <div class="relative">
             <BaseInput
               v-model="searchQuery"
               placeholder="Buscar producto..."
             >
                <template #prefix>
                    <Search :size="18" class="text-gray-400" />
                </template>
             </BaseInput>
             
             <!-- Dropdown Results -->
             <div 
               v-if="searchResults.length > 0 && searchQuery"
               class="absolute bottom-full left-0 right-0 mb-2 bg-gray-800 rounded-xl border border-gray-700 shadow-2xl max-h-60 overflow-y-auto"
             >
               <div 
                 v-for="product in searchResults" 
                 :key="product.id"
                 @click="addItem(product)"
                 class="p-3 border-b border-gray-700 last:border-0 hover:bg-gray-700 cursor-pointer flex justify-between items-center"
               >
                 <div>
                   <div class="font-medium text-white">{{ product.name }}</div>
                   <div class="text-xs text-gray-400">{{ product.plu }} • {{ product.brand }}</div>
                 </div>
                 <div class="text-xs bg-gray-900 px-2 py-1 rounded text-gray-300">
                   Stock: {{ product.stock }}
                 </div>
               </div>
             </div>
          </div>

          <!-- Main Actions -->
          <BaseButton
            @click="saveEntry"
            :disabled="entryItems.length === 0 || isSaving"
            :loading="isSaving"
            variant="primary"
            class="w-full h-12"
          >
            <div class="flex items-center justify-center gap-2">
                <Save :size="20" />
                GUARDAR ENTRADA
            </div>
          </BaseButton>
       </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useInventoryStore } from '../stores/inventory';
import { useAuthStore } from '../stores/auth';
import { Decimal } from 'decimal.js';
import type { Product } from '../types';
import { useSuppliersStore } from '../stores/suppliers';
import BaseInput from '@/components/ui/BaseInput.vue';
import BaseButton from '@/components/ui/BaseButton.vue';
import { ArrowLeft, Search, ListPlus, X, Save } from 'lucide-vue-next';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useAsyncAction } from '../composables/useAsyncAction';
import { useNotifications } from '../composables/useNotifications';

const router = useRouter();
const inventoryStore = useInventoryStore();
const authStore = useAuthStore();
const suppliersStore = useSuppliersStore();
const { formatCurrency } = useCurrencyFormat();
const { execute: executeSave, isLoading: isSaving } = useAsyncAction();
const { showSuccess, showWarning, showError } = useNotifications();

const loadSuppliers = async () => {
  const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
  if (storeId) {
    await suppliersStore.fetchSuppliers(storeId);
  }
};

// Fetch suppliers on mount
onMounted(async () => {
  await loadSuppliers();
});

watch(() => authStore.currentUser?.storeId || authStore.currentStore?.id, async (newStoreId) => {
  if (newStoreId) {
    await loadSuppliers();
  }
});

// Computed
const suppliers = computed(() => suppliersStore.suppliers);

// State
const selectedSupplierId = ref('');
const invoiceRef = ref('');
const movementType = ref<'entrada'>('entrada');
const reason = ref('Compra');
const searchQuery = ref('');
const searchResults = ref<Product[]>([]);
// isSaving handled by useAsyncAction

interface EntryItem {
    productId: string;
    productName: string;
    quantity: number;
    unitCost: number;
    salePrice: number;
    measurementUnit: string;
    expirationDate?: string;
}

const entryItems = ref<EntryItem[]>([]);

// Computed
const currentDate = computed(() => new Date().toLocaleDateString('es-CO', { 
  weekday: 'long', 
  year: 'numeric', 
  month: 'long', 
  day: 'numeric' 
}));

const totalInvoice = computed(() => {
  return entryItems.value.reduce((sum, item) => sum + (item.quantity * item.unitCost), 0);
});

const availableReasons = computed(() => ['Compra', 'Reposición de Proveedor']);

// FIX: Búsqueda reactiva inmediata (001)
watch(searchQuery, () => {
  handleSearch();
});

const handleSearch = () => {
  if (!searchQuery.value) {
    searchResults.value = [];
    return;
  }
  searchResults.value = inventoryStore.searchProducts(searchQuery.value);
};

const addItem = (product: Product) => {
  const existing = entryItems.value.find(i => i.productId === product.id);
  if (existing) {
    searchQuery.value = '';
    searchResults.value = [];
    return;
  }

  // Cost default: if entry, use cost. if exit, use average cost (logic to be refined, but for now cost)
  // FIX: Agregar al principio (unshift) para mejor UX
  entryItems.value.unshift({
    productId: product.id,
    productName: product.name,
    quantity: 1,
    unitCost: product.cost ? new Decimal(product.cost).toNumber() : 0,
    salePrice: product.price ? new Decimal(product.price).toNumber() : 0,
    measurementUnit: product.measurementUnit,
    expirationDate: ''
  });

  // Reset search
  searchQuery.value = '';
  searchResults.value = [];
};

const removeItem = (index: number) => {
  entryItems.value.splice(index, 1);
};

const saveEntry = async () => {
  if (entryItems.value.length === 0) return;

  for (const item of entryItems.value) {
    const qty = Number(item.quantity);
    const cost = Number(item.unitCost);
    const salePrice = Number(item.salePrice);

    if (!Number.isFinite(qty) || qty <= 0) {
      showWarning(`La cantidad de "${item.productName}" debe ser mayor a 0.`);
      return;
    }
    if (!Number.isFinite(cost) || cost < 0) {
      showWarning(`El costo unitario de "${item.productName}" no puede ser negativo.`);
      return;
    }
    if (!Number.isFinite(salePrice) || salePrice <= 0) {
      showWarning(`El precio de venta de "${item.productName}" debe ser mayor a 0.`);
      return;
    }
  }

  await executeSave(async () => {
    let successCount = 0;
    const failedItems: string[] = [];

    for (const item of entryItems.value) {
      const qty = new Decimal(item.quantity);
      const result = await inventoryStore.registerStockMovement({
        productId: item.productId,
        type: 'entrada',
        quantity: qty,
        reason: reason.value,
        expirationDate: item.expirationDate,
        unitCost: item.unitCost,
        salePrice: item.salePrice,
        supplierId: selectedSupplierId.value || undefined,
        invoiceRef: invoiceRef.value || undefined
      });
      
      if (result.success) {
        successCount++;
      } else {
        console.error(`Error saving item ${item.productName}:`, result.error);
        failedItems.push(`${item.productName}: ${result.error || 'Error desconocido'}`);
      }
    }

    if (failedItems.length > 0 && successCount === 0) {
      throw new Error(`Falló el registro de todos los productos: ${failedItems.join('; ')}`);
    }

    return { successCount, failedItems };

  }, {
    checkConnectivity: true,
    showSuccessToast: false
  }).then((res) => {
    if (res) {
      if (res.failedItems.length > 0) {
        showWarning(`Se registraron ${res.successCount} productos, pero fallaron ${res.failedItems.length}: ${res.failedItems.join('; ')}`);
        router.push('/inventory');
      } else if (res.successCount > 0) {
        showSuccess(`Entrada registrada exitosamente (${res.successCount} productos). Lotes actualizados correctamente.`);
        router.push('/inventory');
      }
    }
  });
};
</script>

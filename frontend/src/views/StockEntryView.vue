<template>
  <div class="h-screen flex flex-col overflow-hidden bg-background-light dark:bg-background-dark text-slate-900 dark:text-white">
    <!-- Header -->
    <header class="z-30 bg-surface-light/95 dark:bg-surface-dark/95 backdrop-blur border-b border-slate-200 dark:border-slate-800 px-4 py-4 flex items-center justify-between shrink-0">
      <div class="flex items-center gap-3">
        <button
          @click="router.back()"
          aria-label="Volver"
          class="p-2 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors text-slate-600 dark:text-slate-300"
        >
          <ArrowLeft :size="22" />
        </button>
        <div>
          <h1 class="text-lg font-bold text-slate-900 dark:text-white leading-tight">Nueva Entrada Atómica</h1>
          <p class="text-xs text-slate-500 dark:text-slate-400 capitalize">{{ currentDate }}</p>
        </div>
      </div>
    </header>

    <main class="flex-1 overflow-y-auto w-full p-4 space-y-5">
      <div class="max-w-3xl mx-auto space-y-5">
        <!-- Resumen de confirmación autoritativa del servidor -->
        <section
          v-if="confirmedReceipt"
          data-testid="bulk-entry-confirmed-banner"
          class="bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800/70 rounded-xl p-4 space-y-2"
        >
          <div class="flex items-center justify-between gap-2 flex-wrap">
            <div class="flex items-center gap-2 text-emerald-700 dark:text-emerald-300 font-bold text-sm">
              <CheckCircle2 :size="18" />
              <span>Entrada Atómica Confirmada</span>
            </div>
            <span class="font-mono tabular-nums text-base font-bold text-emerald-700 dark:text-emerald-300">
              Total factura (SQL): {{ formatWithSign(confirmedReceipt.totalEntryCost) }}
            </span>
          </div>
          <p class="text-xs text-emerald-800 dark:text-emerald-200 font-mono tabular-nums">
            {{ confirmedReceipt.itemsProcessed }} producto(s) · {{ confirmedReceipt.totalUnits }} unidad(es) ingresadas a inventario FIFO.
          </p>
          <div class="pt-1 flex gap-2">
            <BaseButton type="button" size="sm" variant="primary" @click="router.push('/inventory')">
              Ver Inventario
            </BaseButton>
            <BaseButton type="button" size="sm" variant="secondary" @click="confirmedReceipt = null">
              Nueva Captura
            </BaseButton>
          </div>
        </section>

        <!-- Error N3 persistente si falla el RPC atómico (preserva ítems capturados) -->
        <section
          v-if="submitError"
          data-testid="bulk-entry-error-banner"
          class="bg-red-50 dark:bg-red-950/40 border border-red-200 dark:border-red-800 rounded-xl p-4 flex items-start gap-3"
        >
          <AlertCircle :size="18" class="text-red-600 dark:text-red-400 shrink-0 mt-0.5" />
          <div class="flex-1 min-w-0">
            <p class="text-xs font-bold text-red-700 dark:text-red-300">No se pudo registrar la entrada</p>
            <p class="text-xs text-red-600 dark:text-red-200 mt-0.5">{{ submitError }}</p>
            <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">
              Tus productos siguen en la lista (operación todo-o-nada: no se guardaron registros parciales).
            </p>
          </div>
        </section>

        <!-- Movement Reason & Link to Salidas -->
        <section class="bg-surface-light dark:bg-surface-dark rounded-xl p-4 shadow-sm border border-slate-200 dark:border-slate-800 flex flex-col md:flex-row gap-4 items-start md:items-end">
          <div class="flex-1 space-y-1 w-full">
            <label class="text-xs font-semibold text-slate-600 dark:text-slate-300">
              Motivo de Entrada (Compra / Reposición)
            </label>
            <select
              v-model="reason"
              class="w-full h-10 bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 rounded-lg px-3 text-sm text-slate-900 dark:text-white outline-none focus:border-primary"
            >
              <option v-for="r in availableReasons" :key="r" :value="r">{{ r }}</option>
            </select>
          </div>

          <button
            type="button"
            @click="router.push('/stock-outputs')"
            class="px-3.5 py-2 rounded-lg text-xs font-semibold bg-background-light dark:bg-background-dark text-amber-700 dark:text-amber-300 border border-amber-300 dark:border-amber-700/50 hover:bg-amber-50 dark:hover:bg-amber-950/30 transition-colors shrink-0 cursor-pointer"
          >
            ¿Mermas, consumos o conteo? Ir a Salidas ($0) →
          </button>
        </section>

        <!-- Supplier Section (Informativo, desacoplado de CxP) -->
        <section class="bg-surface-light dark:bg-surface-dark rounded-xl p-4 shadow-sm border border-slate-200 dark:border-slate-800">
          <div class="flex items-center justify-between mb-3 gap-2 flex-wrap">
            <h2 class="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              Datos del Proveedor (Opcional)
            </h2>
            <span class="text-[11px] text-slate-400">
              Registro logístico independiente de Cuentas por Pagar
            </span>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="space-y-1">
              <label class="text-xs font-semibold text-slate-600 dark:text-slate-300 block mb-1">
                Proveedor
              </label>
              <select
                v-model="selectedSupplierId"
                class="w-full h-10 bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 rounded-lg px-3 text-sm text-slate-900 dark:text-white outline-none focus:border-primary"
              >
                <option value="">-- Sin asignar --</option>
                <option v-for="supplier in suppliers" :key="supplier.id" :value="supplier.id">
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
          <div
            v-if="entryItems.length === 0"
            class="text-center py-10 text-slate-400 bg-surface-light dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800"
          >
            <ListPlus class="mx-auto mb-2" :size="36" />
            <p class="text-sm font-medium">Busca productos abajo para agregarlos a la factura</p>
          </div>

          <div
            v-for="(item, index) in entryItems"
            :key="item.productId"
            class="bg-surface-light dark:bg-surface-dark rounded-xl p-3.5 shadow-sm border flex flex-col gap-3 relative overflow-hidden"
            :class="getRowErrors(item).length > 0 ? 'border-red-300 dark:border-red-700' : 'border-slate-200 dark:border-slate-800'"
          >
            <div class="flex justify-between items-start gap-2">
              <div>
                <h3 class="font-bold text-slate-900 dark:text-white text-sm">{{ item.productName }}</h3>
                <p class="text-xs text-slate-400 uppercase">{{ item.measurementUnit }}</p>
              </div>
              <button
                type="button"
                @click="removeItem(index)"
                aria-label="Quitar producto"
                class="text-slate-400 hover:text-red-500 p-1 rounded-lg transition-colors"
              >
                <X :size="16" />
              </button>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-4 gap-3 items-end">
              <div class="space-y-1">
                <label class="text-[10px] font-bold text-slate-500 uppercase">Cantidad</label>
                <input
                  v-model.number="item.quantity"
                  type="number"
                  min="0.01"
                  step="0.01"
                  class="w-full h-9 bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 rounded-lg px-2.5 text-right text-slate-900 dark:text-white font-mono tabular-nums text-sm focus:border-primary outline-none"
                />
              </div>

              <div class="space-y-1">
                <label class="text-[10px] font-bold text-slate-500 uppercase">Vencimiento</label>
                <input
                  v-model="item.expirationDate"
                  type="date"
                  class="w-full h-9 bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 rounded-lg px-2.5 text-slate-900 dark:text-white font-mono tabular-nums text-xs focus:border-primary outline-none"
                />
              </div>

              <div class="space-y-1">
                <label class="text-[10px] font-bold text-slate-500 uppercase">Costo Unit.</label>
                <div class="relative">
                  <span class="absolute left-2.5 top-2 text-slate-400 text-xs">$</span>
                  <input
                    v-model.number="item.unitCost"
                    type="number"
                    min="0"
                    step="50"
                    class="w-full h-9 bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 rounded-lg pl-6 pr-2.5 text-right text-slate-900 dark:text-white font-mono tabular-nums text-sm focus:border-primary outline-none"
                  />
                </div>
              </div>

              <div class="space-y-1">
                <label class="text-[10px] font-bold text-slate-500 uppercase">Precio Venta</label>
                <div class="relative">
                  <span class="absolute left-2.5 top-2 text-slate-400 text-xs">$</span>
                  <input
                    v-model.number="item.salePrice"
                    type="number"
                    min="1"
                    step="50"
                    class="w-full h-9 bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 rounded-lg pl-6 pr-2.5 text-right text-emerald-600 dark:text-emerald-400 font-mono tabular-nums font-bold text-sm focus:border-emerald-500 outline-none"
                  />
                </div>
              </div>
            </div>

            <!-- Validación N1 inline por fila -->
            <div v-if="getRowErrors(item).length > 0" class="text-xs text-red-600 dark:text-red-400 space-y-0.5">
              <p v-for="err in getRowErrors(item)" :key="err">{{ err }}</p>
            </div>
          </div>
        </section>
      </div>
    </main>

    <!-- Footer Search & Actions -->
    <div class="bg-surface-light/95 dark:bg-surface-dark/95 backdrop-blur border-t border-slate-200 dark:border-slate-800 p-3 pb-6 z-40 shrink-0">
      <div class="max-w-3xl mx-auto space-y-3">
        <!-- Resumen operativo (SIN cálculos monetarios en cliente — autoridad servidor) -->
        <div class="flex justify-between items-center px-2">
          <div class="text-xs font-semibold text-slate-600 dark:text-slate-300 font-mono tabular-nums">
            {{ entryItems.length }} producto(s) · {{ totalUnitsFormatted }} unidad(es)
          </div>
          <div class="text-[11px] text-slate-400">
            Total monetario validado por servidor al confirmar
          </div>
        </div>

        <!-- Search Input -->
        <div class="relative">
          <BaseInput v-model="searchQuery" placeholder="Buscar producto...">
            <template #prefix>
              <Search :size="18" class="text-slate-400" />
            </template>
          </BaseInput>

          <div
            v-if="searchResults.length > 0 && searchQuery"
            class="absolute bottom-full left-0 right-0 mb-2 bg-surface-light dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-700 shadow-2xl max-h-60 overflow-y-auto"
          >
            <div
              v-for="product in searchResults"
              :key="product.id"
              :data-testid="`stock-entry-search-result-${product.id}`"
              @click="addItem(product)"
              class="p-3 border-b border-slate-100 dark:border-slate-800 last:border-0 hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer flex justify-between items-center"
            >
              <div>
                <div class="font-semibold text-slate-900 dark:text-white text-sm">{{ product.name }}</div>
                <div class="text-xs text-slate-400 font-mono tabular-nums">{{ product.plu }} • {{ product.brand }}</div>
              </div>
              <div class="text-xs font-mono tabular-nums bg-background-light dark:bg-background-dark px-2 py-1 rounded border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300">
                Stock: {{ product.stock }}
              </div>
            </div>
          </div>
        </div>

        <BaseButton
          @click="saveEntry"
          :disabled="entryItems.length === 0 || hasAnyRowError || isSaving"
          :loading="isSaving"
          variant="primary"
          class="w-full h-12"
        >
          <div class="flex items-center justify-center gap-2">
            <Save :size="20" />
            GUARDAR ENTRADA ATÓMICA
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
import type { BulkStockEntryResult } from '../data/repositories/productRepository';
import BaseInput from '@/components/ui/BaseInput.vue';
import BaseButton from '@/components/ui/BaseButton.vue';
import { ArrowLeft, Search, ListPlus, X, Save, AlertCircle, CheckCircle2 } from 'lucide-vue-next';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useAsyncAction } from '../composables/useAsyncAction';
import { useNotifications } from '../composables/useNotifications';

const router = useRouter();
const inventoryStore = useInventoryStore();
const authStore = useAuthStore();
const suppliersStore = useSuppliersStore();
const { formatWithSign } = useCurrencyFormat();
const { execute: executeSave, isLoading: isSaving } = useAsyncAction();
const { showSuccess } = useNotifications();

const loadSuppliers = async () => {
  const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
  if (storeId) {
    await suppliersStore.fetchSuppliers(storeId);
  }
};

onMounted(async () => {
  await loadSuppliers();
});

watch(
  () => authStore.currentUser?.storeId || authStore.currentStore?.id,
  async (newStoreId) => {
    if (newStoreId) {
      await loadSuppliers();
    }
  }
);

const suppliers = computed(() => suppliersStore.suppliers);

const selectedSupplierId = ref('');
const invoiceRef = ref('');
const reason = ref('Compra');
const searchQuery = ref('');
const searchResults = ref<Product[]>([]);
const submitError = ref<string | null>(null);
const confirmedReceipt = ref<BulkStockEntryResult | null>(null);

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

const currentDate = computed(() =>
  new Date().toLocaleDateString('es-CO', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
);

const totalUnitsFormatted = computed(() => {
  const sum = entryItems.value.reduce((acc, item) => {
    const q = Number(item.quantity);
    return acc + (Number.isFinite(q) && q > 0 ? q : 0);
  }, 0);
  return Number.isInteger(sum) ? String(sum) : sum.toFixed(2);
});

const availableReasons = computed(() => ['Compra', 'Reposición de Proveedor']);

const getRowErrors = (item: EntryItem): string[] => {
  const errors: string[] = [];
  const qty = Number(item.quantity);
  const cost = Number(item.unitCost);
  const sale = Number(item.salePrice);
  if (!Number.isFinite(qty) || qty <= 0) errors.push('La cantidad debe ser mayor a 0.');
  if (!Number.isFinite(cost) || cost < 0) errors.push('El costo unitario no puede ser negativo.');
  if (!Number.isFinite(sale) || sale <= 0) errors.push('El precio de venta debe ser mayor a 0.');
  return errors;
};

const hasAnyRowError = computed(() =>
  entryItems.value.some((item) => getRowErrors(item).length > 0)
);

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
  submitError.value = null;
  confirmedReceipt.value = null;
  const existing = entryItems.value.find((i) => i.productId === product.id);
  if (existing) {
    searchQuery.value = '';
    searchResults.value = [];
    return;
  }

  entryItems.value.unshift({
    productId: product.id,
    productName: product.name,
    quantity: 1,
    unitCost: product.cost ? new Decimal(product.cost).toNumber() : 0,
    salePrice: product.price ? new Decimal(product.price).toNumber() : 0,
    measurementUnit: product.measurementUnit,
    expirationDate: '',
  });

  searchQuery.value = '';
  searchResults.value = [];
};

const removeItem = (index: number) => {
  entryItems.value.splice(index, 1);
};

const saveEntry = async () => {
  if (entryItems.value.length === 0 || hasAnyRowError.value) return;
  submitError.value = null;

  if (!navigator.onLine) {
    submitError.value =
      'Sin conexión a internet. La entrada masiva requiere conexión activa con el servidor.';
    return;
  }

  const result = await executeSave(
    async () => {
      try {
        return await inventoryStore.registerBulkStockEntry({
          items: entryItems.value.map((item) => ({
            productId: item.productId,
            quantity: Number(item.quantity),
            unitCost: Number(item.unitCost),
            salePrice: Number(item.salePrice),
            expirationDate: item.expirationDate || null,
          })),
          reason: reason.value,
          supplierId: selectedSupplierId.value || null,
          invoiceRef: invoiceRef.value.trim() || null,
        });
      } catch (err: any) {
        const msg = err?.message || 'Error al registrar la entrada masiva';
        submitError.value = msg.includes('OFFLINE_NOT_ALLOWED')
          ? 'Sin conexión a internet. La entrada masiva requiere conexión activa con el servidor.'
          : msg;
        return null;
      }
    },
    {
      checkConnectivity: true,
      showSuccessToast: false,
    }
  );

  if (result) {
    confirmedReceipt.value = result;
    entryItems.value = [];
    invoiceRef.value = '';
    selectedSupplierId.value = '';
    showSuccess(
      `Entrada registrada (${result.itemsProcessed} productos · Total: ${formatWithSign(result.totalEntryCost)})`
    );
  }
};
</script>

<template>
  <div class="space-y-4">
    <!-- Summary Header + CTA Merma / Salida -->
    <div class="bg-background-light dark:bg-background-dark p-3.5 rounded-xl border border-slate-200 dark:border-slate-800 flex flex-wrap justify-between items-center gap-3">
      <div>
        <p class="text-[10px] font-bold uppercase tracking-wider text-slate-400">Stock Total</p>
        <p class="font-mono tabular-nums text-lg font-bold text-slate-900 dark:text-white">
          {{ formatQuantity(totalStock) }} {{ product.measurementUnit || 'un' }}
        </p>
      </div>

      <BaseButton
        v-if="hasActiveStock && canManageInventory"
        type="button"
        variant="warning"
        size="sm"
        @click="openExitModal"
        data-testid="open-batch-exit-btn"
      >
        <span class="flex items-center gap-1.5">
          <PackageMinus :size="15" />
          Registrar Salida
        </span>
      </BaseButton>
    </div>

    <!-- Loading State -->
    <BaseListSkeleton v-if="batchStore.isLoading && !editingBatchId" :count="3" type="simple" />

    <!-- Error State (N3 persistente, nunca fallo silencioso) -->
    <div
      v-else-if="batchStore.error"
      class="bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800/60 rounded-xl p-4 text-center space-y-2"
    >
      <p class="text-xs font-bold text-red-700 dark:text-red-300">Error al cargar los lotes FIFO</p>
      <p class="text-xs text-slate-600 dark:text-slate-300">{{ batchStore.error }}</p>
      <BaseButton type="button" variant="danger" size="sm" @click="loadBatches">
        Reintentar
      </BaseButton>
    </div>

    <!-- Empty State -->
    <div
      v-else-if="batchStore.batches.length === 0"
      class="py-8 text-center text-slate-500 dark:text-slate-400 bg-background-light dark:bg-background-dark rounded-xl border border-slate-200 dark:border-slate-800"
    >
      <Layers class="mx-auto mb-2 text-slate-400" :size="28" :stroke-width="1.5" />
      <p class="text-sm font-medium">Sin lotes registrados para este producto</p>
    </div>

    <!-- Batches List / Table -->
    <div v-else class="overflow-x-auto border border-slate-200 dark:border-slate-800 rounded-xl bg-surface-light dark:bg-surface-dark">
      <table class="w-full text-sm text-left">
        <thead class="text-[10px] uppercase tracking-wider bg-background-light dark:bg-background-dark text-slate-500 border-b border-slate-200 dark:border-slate-800">
          <tr>
            <th class="px-3 py-2.5">Ingreso / Vence</th>
            <th class="px-3 py-2.5 text-right">Costo Unit.</th>
            <th class="px-3 py-2.5 text-right">Precio Venta</th>
            <th class="px-3 py-2.5 text-right">Saldo</th>
            <th class="px-3 py-2.5 text-center">Estado</th>
            <th class="px-3 py-2.5 text-center">Editar</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100 dark:divide-slate-800">
          <tr
            v-for="batch in batchStore.batches"
            :key="batch.id"
            class="transition-colors"
            :class="Number(batch.quantity_remaining) > 0 ? 'bg-emerald-50/20 dark:bg-emerald-950/10' : 'opacity-70'"
          >
            <td class="px-3 py-2.5 text-xs text-slate-700 dark:text-slate-300">
              <div class="font-medium">{{ formatDate(batch.created_at) }}</div>
              <div v-if="batch.expiration_date" class="text-[11px] text-amber-700 dark:text-amber-300 font-mono tabular-nums">
                Vence: {{ batch.expiration_date }}
              </div>
            </td>

            <!-- Cost Unit -->
            <td class="px-3 py-2.5 text-right font-mono tabular-nums">
              <template v-if="editingBatchId === batch.id">
                <input
                  v-model.number="editForm.cost_unit"
                  type="number"
                  min="0"
                  step="50"
                  class="w-24 px-2 py-1 text-right text-xs font-mono tabular-nums border rounded-lg bg-background-light dark:bg-background-dark border-slate-300 dark:border-slate-700 text-slate-900 dark:text-white outline-none focus:border-primary"
                />
              </template>
              <template v-else>
                {{ formatWithSign(batch.cost_unit) }}
              </template>
            </td>

            <!-- Sale Price -->
            <td class="px-3 py-2.5 text-right font-mono tabular-nums font-semibold text-slate-900 dark:text-white">
              <template v-if="editingBatchId === batch.id">
                <input
                  v-model.number="editForm.sale_price"
                  type="number"
                  min="1"
                  step="50"
                  class="w-24 px-2 py-1 text-right text-xs font-mono tabular-nums border rounded-lg bg-background-light dark:bg-background-dark border-slate-300 dark:border-slate-700 text-slate-900 dark:text-white outline-none focus:border-primary"
                />
              </template>
              <template v-else>
                {{ formatWithSign(batch.sale_price) }}
              </template>
            </td>

            <!-- Remaining / Initial -->
            <td class="px-3 py-2.5 text-right font-mono tabular-nums">
              <span class="font-bold" :class="Number(batch.quantity_remaining) > 0 ? 'text-emerald-600 dark:text-emerald-400' : 'text-slate-400'">
                {{ formatQuantity(batch.quantity_remaining) }}
              </span>
              <span class="text-slate-400 text-xs"> / {{ formatQuantity(batch.quantity_initial) }}</span>
            </td>

            <!-- Status -->
            <td class="px-3 py-2.5 text-center">
              <span
                class="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wide"
                :class="Number(batch.quantity_remaining) > 0
                  ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300'
                  : 'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400'"
              >
                {{ Number(batch.quantity_remaining) > 0 ? 'Activo' : 'Agotado' }}
              </span>
            </td>

            <!-- Actions -->
            <td class="px-3 py-2.5 text-center">
              <div v-if="Number(batch.quantity_remaining) > 0 && canManageInventory" class="flex justify-center gap-1.5">
                <template v-if="editingBatchId === batch.id">
                  <button
                    type="button"
                    @click="saveEdit"
                    :disabled="batchStore.isLoading"
                    title="Guardar precios de lote"
                    class="p-1.5 rounded-lg text-emerald-600 hover:bg-emerald-50 dark:hover:bg-emerald-900/30 disabled:opacity-50"
                  >
                    <Check :size="16" />
                  </button>
                  <button
                    type="button"
                    @click="cancelEdit"
                    :disabled="batchStore.isLoading"
                    title="Cancelar edición"
                    class="p-1.5 rounded-lg text-red-500 hover:bg-red-50 dark:hover:bg-red-900/30 disabled:opacity-50"
                  >
                    <X :size="16" />
                  </button>
                </template>
                <template v-else>
                  <button
                    type="button"
                    @click="startEdit(batch)"
                    title="Editar costo y precio de venta del lote"
                    class="p-1.5 rounded-lg text-slate-400 hover:text-primary hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
                  >
                    <Pencil :size="15" />
                  </button>
                </template>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="editInlineError" class="px-3 py-2 text-xs text-red-600 dark:text-red-400 border-t border-red-200 dark:border-red-900/40 bg-red-50/70 dark:bg-red-950/30">
        {{ editInlineError }}
      </p>
    </div>

    <!-- Hoja Transaccional Arquetipo D: Salida por Lote -->
    <BaseModal
      v-model="showExitModal"
      :title="`Salida: ${product.name}`"
    >
      <div class="p-4 space-y-4">
        <!-- Selector de Lote en Estantería (oculto si <= 1 lote, visible si >= 2) -->
        <BatchShelfSelector
          v-model="exitForm.batchId"
          :batches="batchStore.activeBatches"
          :unit="product.measurementUnit"
        />

        <!-- Tipo de Salida -->
        <div class="space-y-1.5">
          <label class="text-xs font-bold uppercase tracking-wider text-slate-600 dark:text-slate-300 block">
            Motivo de Salida
          </label>
          <select
            v-model="exitForm.movementType"
            class="w-full h-10 px-3 rounded-xl text-sm bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 text-slate-900 dark:text-white outline-none focus:border-primary"
          >
            <option value="merma">Merma / Daño</option>
            <option value="consumo_negocio">Consumo del Negocio</option>
            <option value="devolucion_proveedor">Devolución a Proveedor</option>
          </select>
        </div>

        <!-- Proveedor (solo devolucion_proveedor) -->
        <div v-if="exitForm.movementType === 'devolucion_proveedor'" class="space-y-1.5">
          <label class="text-xs font-bold uppercase tracking-wider text-slate-600 dark:text-slate-300 block">
            Proveedor (Opcional)
          </label>
          <select
            v-model="exitForm.supplierId"
            class="w-full h-10 px-3 rounded-xl text-sm bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 text-slate-900 dark:text-white outline-none focus:border-primary"
          >
            <option value="">-- Sin proveedor específico --</option>
            <option v-for="sup in suppliersStore.suppliers" :key="sup.id" :value="sup.id">
              {{ sup.name }}
            </option>
          </select>
        </div>

        <!-- Cantidad + N1 inline -->
        <div class="space-y-1.5">
          <div class="flex justify-between items-center">
            <label class="text-xs font-bold uppercase tracking-wider text-slate-600 dark:text-slate-300">
              Cantidad a Retirar ({{ product.measurementUnit || 'un' }})
            </label>
            <span class="text-xs text-slate-400 font-mono tabular-nums">
              Máx. lote: {{ formatQuantity(selectedBatchRemaining) }}
            </span>
          </div>
          <input
            v-model.number="exitForm.quantity"
            type="number"
            min="0.01"
            :max="selectedBatchRemaining"
            step="any"
            class="w-full h-10 px-3 rounded-xl text-sm font-mono tabular-nums bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 text-slate-900 dark:text-white outline-none focus:border-primary"
          />
          <p v-if="quantityInlineError" class="text-xs text-red-600 dark:text-red-400">
            {{ quantityInlineError }}
          </p>
        </div>

        <!-- Motivo obligatorio >= 3 chars + N1 inline -->
        <div class="space-y-1.5">
          <label class="text-xs font-bold uppercase tracking-wider text-slate-600 dark:text-slate-300 block">
            Motivo Obligatorio (mín. 3 caracteres)
          </label>
          <textarea
            v-model="exitForm.reason"
            rows="2"
            placeholder="Ej. Empaque averiado, producto vencido..."
            class="w-full p-2.5 rounded-xl text-sm bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 text-slate-900 dark:text-white outline-none focus:border-primary resize-none"
          />
          <p v-if="reasonInlineError" class="text-xs text-red-600 dark:text-red-400">
            {{ reasonInlineError }}
          </p>
        </div>

        <!-- Preview Antes -> Después -->
        <div class="rounded-xl p-3 bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-800 flex items-center justify-between text-xs">
          <span class="font-semibold text-slate-500">Stock lote:</span>
          <div class="font-mono tabular-nums font-bold text-slate-900 dark:text-white flex items-center gap-2">
            <span>{{ formatQuantity(selectedBatchRemaining) }} {{ product.measurementUnit || 'un' }}</span>
            <ArrowRight :size="14" class="text-slate-400" />
            <span :class="projectedAfterBatch < 0 ? 'text-red-600 dark:text-red-400' : 'text-emerald-600 dark:text-emerald-400'">
              {{ formatQuantity(projectedAfterBatch) }} {{ product.measurementUnit || 'un' }}
            </span>
          </div>
        </div>

        <!-- Error N3 explícito del servidor (no se cierra modal ni se oculta error) -->
        <div
          v-if="exitSubmitError"
          data-testid="batch-exit-error-banner"
          class="rounded-xl p-3 bg-red-50 dark:bg-red-950/40 border border-red-200 dark:border-red-800 text-xs text-red-700 dark:text-red-300"
        >
          {{ exitSubmitError }}
        </div>
      </div>

      <template #footer>
        <div class="p-4 pt-0 flex gap-3">
          <BaseButton
            type="button"
            variant="secondary"
            class="flex-1"
            :disabled="isSubmittingExit"
            @click="showExitModal = false"
          >
            Cancelar
          </BaseButton>
          <BaseButton
            type="button"
            variant="danger"
            class="flex-1"
            :disabled="!canConfirmExit || isSubmittingExit"
            :loading="isSubmittingExit"
            @click="confirmLogisticExit"
            data-testid="confirm-batch-exit-btn"
          >
            Confirmar Salida
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { Pencil, Check, X, Layers, PackageMinus, ArrowRight } from 'lucide-vue-next';
import { useBatchStore, type InventoryBatch } from '../../stores/batches';
import { useInventoryStore } from '../../stores/inventory';
import { useAuthStore } from '../../stores/auth';
import { useSuppliersStore } from '../../stores/suppliers';
import type { Product } from '../../types';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import { useNotifications } from '../../composables/useNotifications';
import { useAsyncAction } from '../../composables/useAsyncAction';
import BaseButton from '../ui/BaseButton.vue';
import BaseModal from '../ui/BaseModal.vue';
import BaseListSkeleton from '../ui/BaseListSkeleton.vue';
import BatchShelfSelector from './BatchShelfSelector.vue';

const props = defineProps<{
  product: Product;
}>();

const emit = defineEmits<{
  'stock-updated': [];
  'price-updated': [];
}>();

const batchStore = useBatchStore();
const inventoryStore = useInventoryStore();
const authStore = useAuthStore();
const suppliersStore = useSuppliersStore();
const { formatWithSign } = useCurrencyFormat();
const { showSuccess, showError } = useNotifications();
const { execute: executeExit, isLoading: isSubmittingExit } = useAsyncAction();

const canManageInventory = computed(() => authStore.canManageInventory || authStore.isAdmin);

const totalStock = computed(() => {
  if (batchStore.batches.length > 0) {
    return batchStore.batches.reduce((sum, b) => sum + Number(b.quantity_remaining), 0);
  }
  return props.product.stock?.toNumber?.() ?? Number(props.product.stock || 0);
});

const hasActiveStock = computed(() => batchStore.activeBatches.length > 0);

const loadBatches = async () => {
  if (props.product?.id) {
    await batchStore.fetchBatchesByProduct(props.product.id);
  }
};

onMounted(() => {
  loadBatches();
});

watch(
  () => props.product?.id,
  () => {
    editingBatchId.value = null;
    editInlineError.value = null;
    loadBatches();
  }
);

// Inline batch price/cost editing
const editingBatchId = ref<string | null>(null);
const editForm = ref({ cost_unit: 0, sale_price: 0 });
const editInlineError = ref<string | null>(null);

const startEdit = (batch: InventoryBatch) => {
  editInlineError.value = null;
  editingBatchId.value = batch.id;
  editForm.value = {
    cost_unit: Number(batch.cost_unit) || 0,
    sale_price: Number(batch.sale_price) || 0,
  };
};

const cancelEdit = () => {
  editingBatchId.value = null;
  editInlineError.value = null;
};

const saveEdit = async () => {
  if (!editingBatchId.value) return;
  if (!Number.isFinite(editForm.value.cost_unit) || editForm.value.cost_unit < 0) {
    editInlineError.value = 'El costo unitario no puede ser negativo.';
    return;
  }
  if (!Number.isFinite(editForm.value.sale_price) || editForm.value.sale_price <= 0) {
    editInlineError.value = 'El precio de venta debe ser mayor a $0.';
    return;
  }
  editInlineError.value = null;
  const res = await batchStore.updateBatchPrice(
    editingBatchId.value,
    editForm.value.cost_unit,
    editForm.value.sale_price
  );
  if (res.success) {
    editingBatchId.value = null;
    showSuccess('Lote actualizado correctamente');
    emit('price-updated');
  } else {
    showError(res.error || 'No se pudo actualizar el lote');
  }
};

// Merma / Salida ($0) Archetype D modal state
const showExitModal = ref(false);
const exitSubmitError = ref<string | null>(null);
const exitTouched = ref(false);
const exitForm = ref({
  batchId: null as string | null,
  movementType: 'merma' as 'merma' | 'consumo_negocio' | 'devolucion_proveedor',
  quantity: 1,
  reason: '',
  supplierId: '',
});

const openExitModal = async () => {
  exitSubmitError.value = null;
  exitTouched.value = false;
  exitForm.value = {
    batchId: batchStore.activeBatches[0]?.id ?? null,
    movementType: 'merma',
    quantity: 1,
    reason: '',
    supplierId: '',
  };
  showExitModal.value = true;
  const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
  if (storeId && suppliersStore.suppliers.length === 0) {
    await suppliersStore.fetchSuppliers(storeId);
  }
};

const selectedBatch = computed(() =>
  batchStore.activeBatches.find((b) => b.id === exitForm.value.batchId) || batchStore.activeBatches[0] || null
);

const selectedBatchRemaining = computed(() =>
  selectedBatch.value ? Number(selectedBatch.value.quantity_remaining) : totalStock.value
);

const projectedAfterBatch = computed(() => {
  const qty = Number(exitForm.value.quantity || 0);
  if (!Number.isFinite(qty) || qty <= 0) return selectedBatchRemaining.value;
  return selectedBatchRemaining.value - qty;
});

const quantityInlineError = computed(() => {
  const qty = Number(exitForm.value.quantity);
  if (!Number.isFinite(qty) || qty <= 0) return 'Ingresa una cantidad mayor a cero.';
  if (qty > selectedBatchRemaining.value) {
    return `Excede el saldo del lote (${formatQuantity(selectedBatchRemaining.value)}).`;
  }
  return null;
});

const reasonInlineError = computed(() => {
  if (!exitTouched.value && exitForm.value.reason.length === 0) return null;
  if (exitForm.value.reason.trim().length < 3) {
    return 'El motivo debe tener al menos 3 caracteres.';
  }
  return null;
});

const canConfirmExit = computed(() => {
  return !quantityInlineError.value && exitForm.value.reason.trim().length >= 3 && hasActiveStock.value;
});

const translateExitError = (rawMessage: string): string => {
  if (rawMessage.includes('OFFLINE_NOT_ALLOWED')) {
    return 'Sin conexión a internet. Las salidas de inventario requieren conexión activa.';
  }
  if (rawMessage.includes('BATCH_STOCK_INSUFFICIENT')) {
    return 'El saldo actual del lote en servidor es menor al solicitado. Recarga los lotes e intenta de nuevo.';
  }
  if (rawMessage.includes('PERMISSION_DENIED')) {
    return 'No cuentas con permiso vigente de inventario para registrar esta salida.';
  }
  return rawMessage || 'No se pudo registrar la salida del lote.';
};

const confirmLogisticExit = async () => {
  exitTouched.value = true;
  exitSubmitError.value = null;
  if (!canConfirmExit.value) return;

  if (!navigator.onLine) {
    exitSubmitError.value =
      'Sin conexión a internet. Las salidas de inventario requieren conexión activa.';
    return;
  }

  const res = await executeExit(
    async () => {
      try {
        return await inventoryStore.registerLogisticExit({
          productId: props.product.id,
          movementType: exitForm.value.movementType,
          quantity: Number(exitForm.value.quantity),
          reason: exitForm.value.reason.trim(),
          direction: 'negative',
          supplierId:
            exitForm.value.movementType === 'devolucion_proveedor' && exitForm.value.supplierId
              ? exitForm.value.supplierId
              : undefined,
          batchId: exitForm.value.batchId ?? selectedBatch.value?.id ?? null,
        });
      } catch (err: any) {
        exitSubmitError.value = translateExitError(err?.message || '');
        return null;
      }
    },
    { checkConnectivity: true, showSuccessToast: false }
  );

  if (res) {
    await loadBatches();
    emit('stock-updated');
    showExitModal.value = false;
    showSuccess('Salida registrada y lote actualizado correctamente.');
  }
};

const formatQuantity = (qty: number): string => {
  const num = Number(qty);
  return Number.isInteger(num) ? String(num) : num.toFixed(2);
};

const formatDate = (dateString: string): string => {
  if (!dateString) return '-';
  return new Date(dateString).toLocaleDateString('es-CO', {
    day: '2-digit',
    month: 'short',
    year: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
};
</script>

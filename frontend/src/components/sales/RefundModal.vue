<template>
  <BaseModal
    v-model="isOpen"
    title="Reembolsos"
    max-height="90vh"
    :show-close-button="true"
  >
    <div class="p-4 space-y-4">
      <!-- Bloqueos N1 por conectividad / turno cerrado -->
      <div
        v-if="!isOnline"
        role="alert"
        data-testid="refund-offline-alert"
        class="p-3 rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800 flex items-center gap-2 text-rose-700 dark:text-rose-300 text-xs font-semibold"
      >
        <WifiOff :size="16" class="shrink-0" />
        <span>Sin conexión. Conéctate para procesar reembolsos.</span>
      </div>

      <div
        v-else-if="!isCashUsable"
        role="alert"
        data-testid="refund-cash-closed-alert"
        class="p-3 rounded-xl bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-800 flex items-center gap-2 text-amber-800 dark:text-amber-300 text-xs font-semibold"
      >
        <AlertTriangle :size="16" class="shrink-0" />
        <span>
          {{ isCashStale
            ? 'El turno de caja superó las 24 horas y debe cerrarse primero.'
            : 'Abre la caja antes de procesar reembolsos.' }}
        </span>
      </div>

      <!-- Búsqueda de Venta o Producto (incluye stock = 0 por CHK-509) -->
      <div class="flex gap-2">
        <div class="relative flex-1">
          <Search class="absolute left-3 top-2.5 text-slate-400" :size="16" />
          <input
            v-model="searchQuery"
            type="text"
            aria-label="Buscar ticket, producto o código"
            placeholder="Ticket #, producto o código..."
            @keyup.enter="searchTickets"
            class="w-full h-10 pl-9 pr-3 rounded-xl border border-gray-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-primary outline-none"
          />
        </div>
        <BaseButton variant="primary" @click="searchTickets" :loading="isSearching" :disabled="!isOnline">
          Buscar
        </BaseButton>
      </div>

      <!-- Listado de Tickets Candidatos -->
      <div v-if="!selectedItem" class="space-y-2.5 max-h-[55vh] overflow-y-auto">
        <div v-if="isSearching" class="py-8 text-center text-xs text-slate-400">
          Consultando historial de ventas...
        </div>

        <!-- Regla 3: Error real N3 de búsqueda con Reintentar (oculta falso vacío) -->
        <div
          v-else-if="searchError"
          role="alert"
          data-testid="refund-search-error"
          class="p-4 rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800 flex flex-col items-center text-center gap-2 text-rose-700 dark:text-rose-300 text-xs"
        >
          <AlertTriangle :size="20" />
          <span class="font-semibold">{{ searchError }}</span>
          <button
            type="button"
            data-testid="refund-search-retry-btn"
            @click="searchTickets"
            class="px-3 py-1.5 rounded-lg bg-rose-600 hover:bg-rose-700 text-white font-bold cursor-pointer transition-colors"
          >
            Reintentar
          </button>
        </div>

        <div v-else-if="candidates.length === 0" class="py-8 text-center text-xs text-slate-400">
          No se encontraron ventas activas para reembolsar.
        </div>

        <div
          v-for="sale in candidates"
          :key="sale.sale_id"
          class="bg-gray-50 dark:bg-slate-800/80 rounded-xl p-3 border border-gray-200 dark:border-slate-700 space-y-2"
        >
          <div class="flex items-center justify-between text-xs">
            <span class="font-bold text-slate-900 dark:text-white">
              Ticket #{{ sale.ticket_number }} · {{ translateOriginalChannel(sale.payment_method) }}
            </span>
            <span class="font-mono tabular-nums font-bold text-emerald-600 dark:text-emerald-400">
              {{ formatWithSign(sale.total) }}
            </span>
          </div>

          <div class="divide-y divide-gray-200 dark:divide-slate-700/70">
            <div
              v-for="item in sale.items"
              :key="item.sale_item_id"
              class="py-2 flex items-center justify-between gap-2"
            >
              <div class="min-w-0">
                <p class="text-sm font-semibold text-slate-800 dark:text-slate-100 truncate">
                  {{ item.product_name }}
                </p>
                <p class="text-[11px] text-slate-500 dark:text-slate-400">
                  Vendido: {{ item.quantity }} · Disponible reembolso:
                  <strong class="font-mono tabular-nums">{{ item.remaining_quantity }}</strong> · Stock actual: {{ item.current_stock }}
                </p>
              </div>
              <button
                type="button"
                :disabled="item.remaining_quantity <= 0"
                @click="selectItemForRefund(sale, item)"
                class="px-3 py-1.5 rounded-lg text-xs font-bold shrink-0 transition-colors cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed"
                :class="item.remaining_quantity > 0
                  ? 'bg-rose-600 text-white hover:bg-rose-700'
                  : 'bg-gray-300 dark:bg-slate-700 text-gray-500'"
              >
                {{ item.remaining_quantity > 0 ? 'Reembolsar' : 'Reembolsado' }}
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Formulario de Reembolso de Ítem Seleccionado -->
      <div v-else class="space-y-4">
        <div
          data-testid="refund-server-authority-card"
          class="bg-slate-100 dark:bg-slate-800 rounded-xl p-3 space-y-1.5"
        >
          <div class="flex items-start justify-between gap-2">
            <div>
              <p class="text-xs font-bold text-slate-500 uppercase">Ticket #{{ selectedSale?.ticket_number }}</p>
              <p class="text-sm font-bold text-slate-900 dark:text-white">{{ selectedItem.product_name }}</p>
            </div>
            <button
              type="button"
              @click="clearSelectedItem"
              class="text-xs font-semibold text-primary hover:underline cursor-pointer shrink-0"
            >
              Cambiar
            </button>
          </div>
          <p class="text-[11px] text-slate-600 dark:text-slate-300 font-mono tabular-nums">
            Disponible: <strong>{{ selectedItem.remaining_quantity }}</strong> · Unit.: {{ formatWithSign(selectedItem.unit_price) }} · Subtotal: {{ formatWithSign(selectedItem.subtotal) }}
          </p>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label class="text-xs font-bold text-slate-500 block mb-1">Cantidad</label>
            <input
              v-model.number="refundQty"
              type="number"
              :min="selectedItem.is_weighable ? 0.01 : 1"
              :max="selectedItem.remaining_quantity"
              :step="selectedItem.is_weighable ? 0.01 : 1"
              class="w-full h-10 px-3 rounded-xl border border-gray-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-sm font-mono tabular-nums font-bold text-slate-900 dark:text-white"
            />
          </div>

          <div>
            <label class="text-xs font-bold text-slate-500 block mb-1">Pago original</label>
            <select
              v-model="originalChannel"
              class="w-full h-10 px-3 rounded-xl border border-gray-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-sm text-slate-900 dark:text-white"
            >
              <option value="efectivo">Efectivo</option>
              <option value="nequi">Nequi</option>
              <option value="llave_bre">Llave Bre-B</option>
              <option value="fiado">Fiado</option>
              <option value="transferencia">Transferencia</option>
            </select>
          </div>

          <div class="sm:col-span-2">
            <label class="text-xs font-bold text-slate-500 block mb-1">Devolver por</label>
            <div class="grid grid-cols-3 gap-2">
              <button
                v-for="ch in refundChannels"
                :key="ch.value"
                type="button"
                @click="refundChannel = ch.value"
                class="h-10 rounded-xl border text-xs font-bold transition-all cursor-pointer"
                :class="refundChannel === ch.value
                  ? 'bg-primary text-white border-primary shadow-sm'
                  : 'bg-gray-50 dark:bg-slate-800 text-slate-700 dark:text-slate-300 border-gray-200 dark:border-slate-700'"
              >
                {{ ch.label }}
              </button>
            </div>
          </div>
        </div>

        <!-- Destino de Stock + Switch "merma" unificado (Read Model C1-H4 + CHK-508/509) -->
        <div
          data-testid="refund-fifo-read-model"
          class="p-3 rounded-xl border transition-colors space-y-2"
          :class="isMerma
            ? 'bg-orange-50 dark:bg-orange-950/30 border-orange-300 dark:border-orange-700'
            : 'bg-emerald-50 dark:bg-emerald-950/30 border-emerald-200 dark:border-emerald-800'"
        >
          <label class="flex items-center justify-between gap-3 cursor-pointer">
            <span class="flex items-center gap-2.5">
              <input
                v-model="isMerma"
                type="checkbox"
                class="h-4 w-4 rounded accent-orange-600 cursor-pointer"
              />
              <span class="text-sm font-bold" :class="isMerma ? 'text-orange-700 dark:text-orange-300' : 'text-emerald-800 dark:text-emerald-200'">
                Producto dañado (Merma)
              </span>
            </span>
            <span
              class="text-[11px] font-bold px-2 py-0.5 rounded-full shrink-0"
              :class="isMerma
                ? 'bg-orange-100 dark:bg-orange-900/50 text-orange-800 dark:text-orange-200'
                : 'bg-emerald-100 dark:bg-emerald-900/50 text-emerald-800 dark:text-emerald-200'"
            >
              {{ isMerma ? 'No vuelve al estante' : 'Vuelve al estante' }}
            </span>
          </label>

          <div v-if="selectedItemFifoBatches.length > 0" class="space-y-1 pt-1 border-t border-black/5 dark:border-white/10">
            <div
              v-for="batch in selectedItemFifoBatches"
              :key="batch.batch_id"
              class="flex items-center justify-between gap-2 text-xs px-2.5 py-1 rounded-lg bg-white/80 dark:bg-slate-900/70"
            >
              <span class="inline-flex items-center gap-1 font-mono tabular-nums font-semibold text-slate-700 dark:text-slate-200">
                <Layers :size="12" class="text-indigo-500" />
                Lote #{{ shortBatchId(batch.batch_id) }}
              </span>
              <span class="text-slate-500 dark:text-slate-400 font-mono tabular-nums">
                {{ batch.quantity }} un · {{ formatWithSign(batch.unit_cost) }}
              </span>
            </div>
          </div>
        </div>

        <div>
          <label class="text-xs font-bold text-slate-500 block mb-1">Motivo (mín. 5 car.)</label>
          <textarea
            v-model="refundReason"
            rows="2"
            placeholder="Ej: Empaque abierto, cambio de referencia..."
            class="w-full p-2.5 rounded-xl border border-gray-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-primary"
          />
        </div>

        <!-- Error Inline N1 de envío -->
        <div
          v-if="submitError"
          role="alert"
          data-testid="refund-submit-error"
          class="p-3 rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800 flex items-start gap-2 text-rose-700 dark:text-rose-300 text-xs font-semibold"
        >
          <AlertTriangle :size="15" class="shrink-0 mt-0.5" />
          <span>{{ submitError }}</span>
        </div>

        <BaseButton
          variant="danger"
          data-testid="refund-confirm-btn"
          class="w-full h-11 font-bold"
          :loading="isSubmitting"
          :disabled="!canSubmitRefund || isSubmitting"
          @click="submitRefund"
        >
          Confirmar Reembolso
        </BaseButton>
      </div>
    </div>
  </BaseModal>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import BaseModal from '../ui/BaseModal.vue';
import BaseButton from '../ui/BaseButton.vue';
import { useAuthStore } from '../../stores/auth';
import { useCashRegisterStore } from '../../stores/cashRegister';
import {
  saleRepository,
  type RefundCandidateSale,
  type RefundCandidateItem
} from '../../data/repositories/saleRepository';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import { useNotifications } from '../../composables/useNotifications';
import { Search, AlertTriangle, WifiOff, Layers } from 'lucide-vue-next';

const props = defineProps<{ modelValue: boolean }>();
const emit = defineEmits<{ 'update:modelValue': [value: boolean] }>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (v) => emit('update:modelValue', v)
});

const authStore = useAuthStore();
const cashRegisterStore = useCashRegisterStore();
const { formatWithSign } = useCurrencyFormat();
const { showSuccess } = useNotifications();

const searchQuery = ref('');
const isSearching = ref(false);
const searchError = ref<string | null>(null);
const submitError = ref<string | null>(null);
const candidates = ref<RefundCandidateSale[]>([]);
const selectedSale = ref<RefundCandidateSale | null>(null);
const selectedItem = ref<RefundCandidateItem | null>(null);
const isOnline = ref<boolean>(typeof navigator !== 'undefined' ? navigator.onLine : true);

const syncOnlineStatus = () => {
  isOnline.value = typeof navigator !== 'undefined' ? navigator.onLine : true;
};

onMounted(() => {
  syncOnlineStatus();
  window.addEventListener('online', syncOnlineStatus);
  window.addEventListener('offline', syncOnlineStatus);
});

onUnmounted(() => {
  window.removeEventListener('online', syncOnlineStatus);
  window.removeEventListener('offline', syncOnlineStatus);
});

const isCashStale = computed(() => Boolean(cashRegisterStore.isStaleSession));
const isCashUsable = computed(() => cashRegisterStore.isOpen && !isCashStale.value);

const refundQty = ref(1);
const originalChannel = ref<'efectivo' | 'nequi' | 'llave_bre' | 'fiado' | 'transferencia'>('efectivo');
const refundChannel = ref<'efectivo' | 'nequi' | 'llave_bre'>('efectivo');
const isMerma = ref(false);
const refundReason = ref('');
const isSubmitting = ref(false);

const refundChannels = [
  { value: 'efectivo', label: 'Efectivo' },
  { value: 'nequi', label: 'Nequi' },
  { value: 'llave_bre', label: 'Llave Bre-B' }
] as const;

const selectedItemFifoBatches = computed(() => {
  return Array.isArray(selectedItem.value?.fifo_batches) ? selectedItem.value!.fifo_batches! : [];
});

const shortBatchId = (id: string) => {
  return String(id || '').slice(0, 8);
};

const canSubmitRefund = computed(() => {
  if (!isOnline.value || !isCashUsable.value || !selectedItem.value) return false;
  const qty = Number(refundQty.value);
  return (
    qty > 0 &&
    qty <= selectedItem.value.remaining_quantity &&
    refundReason.value.trim().length >= 5
  );
});

const searchTickets = async () => {
  syncOnlineStatus();
  searchError.value = null;

  if (!isOnline.value) {
    candidates.value = [];
    searchError.value = 'Sin conexión en línea. Conéctate para consultar ventas reembolsables.';
    return;
  }

  const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
  if (!storeId) {
    candidates.value = [];
    searchError.value = 'No se identificó la tienda activa para consultar ventas.';
    return;
  }

  isSearching.value = true;
  try {
    candidates.value = await saleRepository.searchRefundCandidates(storeId, searchQuery.value);
  } catch (err: any) {
    candidates.value = [];
    searchError.value = err?.message || 'Error al buscar ventas para reembolso';
  } finally {
    isSearching.value = false;
  }
};

watch(() => props.modelValue, (open) => {
  if (open) {
    syncOnlineStatus();
    selectedSale.value = null;
    selectedItem.value = null;
    searchQuery.value = '';
    searchError.value = null;
    submitError.value = null;
    searchTickets();
  }
}, { immediate: true });

watch([refundQty, refundChannel, originalChannel, isMerma, refundReason], () => {
  if (submitError.value) {
    submitError.value = null;
  }
});

const clearSelectedItem = () => {
  selectedItem.value = null;
  submitError.value = null;
};

const selectItemForRefund = (sale: RefundCandidateSale, item: RefundCandidateItem) => {
  selectedSale.value = sale;
  selectedItem.value = item;
  submitError.value = null;
  refundQty.value = item.remaining_quantity > 1 ? 1 : item.remaining_quantity;
  const orig = ['efectivo', 'nequi', 'llave_bre', 'fiado', 'transferencia'].includes(sale.payment_method)
    ? (sale.payment_method as any)
    : 'efectivo';
  originalChannel.value = orig;
  refundChannel.value = (['efectivo', 'nequi', 'llave_bre'].includes(orig) ? orig : 'efectivo') as any;
  isMerma.value = false;
  refundReason.value = '';
};

const translateOriginalChannel = (ch: string) => {
  const map: Record<string, string> = {
    efectivo: 'Efectivo',
    nequi: 'Nequi',
    llave_bre: 'Llave Bre-B',
    fiado: 'Fiado',
    transferencia: 'Transferencia'
  };
  return map[ch] || ch;
};

const submitRefund = async () => {
  syncOnlineStatus();
  submitError.value = null;

  if (!isOnline.value) {
    submitError.value = 'Los reembolsos requieren conexión en línea activa.';
    return;
  }
  if (!isCashUsable.value) {
    submitError.value = isCashStale.value
      ? 'El turno de caja superó las 24 horas y debe cerrarse antes de procesar reembolsos.'
      : 'Debes tener un turno de caja abierto para procesar reembolsos.';
    return;
  }
  if (!selectedItem.value || !canSubmitRefund.value || isSubmitting.value) return;

  isSubmitting.value = true;
  try {
    const res = await saleRepository.processItemRefund({
      saleItemId: selectedItem.value.sale_item_id,
      quantity: Number(refundQty.value),
      refundChannel: refundChannel.value,
      originalChannel: originalChannel.value,
      reason: refundReason.value.trim(),
      isMerma: isMerma.value
    });

    const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
    if (storeId && typeof cashRegisterStore.syncFromBackend === 'function') {
      await cashRegisterStore.syncFromBackend(storeId);
    }
    showSuccess(
      `Reembolso aprobado por ${formatWithSign(res.amountRefunded)} (${res.isMerma ? 'Asentado como merma' : 'Devuelto a stock vendible'})`
    );
    isOpen.value = false;
  } catch (err: any) {
    submitError.value = err?.message || 'No se pudo procesar el reembolso';
  } finally {
    isSubmitting.value = false;
  }
};
</script>

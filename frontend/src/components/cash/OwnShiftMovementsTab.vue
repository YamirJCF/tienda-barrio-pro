<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { ClipboardList, Lock, RefreshCw, AlertTriangle, User } from 'lucide-vue-next';
import { useAuthStore } from '../../stores/auth';
import cashRepository, {
  type OwnShiftMovement,
  type OwnShiftPaymentMethodFilter,
} from '../../data/repositories/cashRepository';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import BaseButton from '../ui/BaseButton.vue';
import BaseListSkeleton from '../ui/BaseListSkeleton.vue';

const authStore = useAuthStore();
const { formatCurrency } = useCurrencyFormat();

const movements = ref<OwnShiftMovement[]>([]);
const totalCount = ref(0);
const hasOpenShift = ref(false);
const shiftOpenedAt = ref<string | null>(null);
const selectedMethod = ref<OwnShiftPaymentMethodFilter>('all');
const isLoading = ref(false);
const error = ref<string | null>(null);

const paymentFilters: Array<{ value: OwnShiftPaymentMethodFilter; label: string }> = [
  { value: 'all', label: 'Todos' },
  { value: 'efectivo', label: 'Efectivo' },
  { value: 'nequi', label: 'Nequi' },
  { value: 'llave_bre', label: 'Llave Bre-B' },
  { value: 'fiado', label: 'Fiado' },
  { value: 'consumo_personal', label: 'Retiro Personal' },
];

const sourceLabelMap: Record<OwnShiftMovement['source'], string> = {
  sale: 'Venta',
  expense: 'Gasto',
  payment: 'Abono / Pago',
  refund: 'Devolución / Anulación',
  personal_withdrawal: 'Retiro Personal ($0)',
};

const channelLabelMap: Record<OwnShiftMovement['payment_method'], string> = {
  efectivo: 'Efectivo',
  nequi: 'Nequi',
  llave_bre: 'Llave Bre-B',
  fiado: 'Fiado',
  consumo_personal: 'Consumo Personal',
};

const loadMovements = async () => {
  const storeId = authStore.currentStore?.id || authStore.currentUser?.storeId;
  if (!storeId) {
    error.value = 'No hay una tienda activa seleccionada.';
    return;
  }

  isLoading.value = true;
  error.value = null;

  try {
    const res = await cashRepository.getOwnShiftMovements(storeId, selectedMethod.value, 100, 0);
    movements.value = res.data;
    totalCount.value = res.count;
    hasOpenShift.value = res.has_open_shift;
    shiftOpenedAt.value = res.shift_opened_at;
  } catch (e: any) {
    error.value = e?.message || 'Error al cargar tus movimientos del turno actual';
    movements.value = [];
  } finally {
    isLoading.value = false;
  }
};

const selectFilter = async (method: OwnShiftPaymentMethodFilter) => {
  selectedMethod.value = method;
  await loadMovements();
};

const openedAtFormatted = computed(() => {
  if (!shiftOpenedAt.value) return '';
  return new Date(shiftOpenedAt.value).toLocaleString('es-CO', {
    dateStyle: 'short',
    timeStyle: 'short',
  });
});

onMounted(() => {
  loadMovements();
});
</script>

<template>
  <section class="space-y-4">
    <!-- Filtros por Canal + Refresh -->
    <div class="bg-surface-light dark:bg-surface-dark border border-slate-200 dark:border-slate-700 rounded-2xl p-2.5 flex items-center gap-2">
      <div class="flex-1 flex gap-2 overflow-x-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
        <button
          v-for="f in paymentFilters"
          :key="f.value"
          type="button"
          @click="selectFilter(f.value)"
          class="px-3 py-1.5 rounded-full text-xs font-semibold whitespace-nowrap transition-colors"
          :class="
            selectedMethod === f.value
              ? 'bg-primary text-white shadow-sm'
              : 'bg-background-light dark:bg-background-dark text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700'
          "
        >
          {{ f.label }}
        </button>
      </div>
      <button
        type="button"
        @click="loadMovements"
        class="p-2 rounded-xl text-slate-500 hover:bg-background-light dark:hover:bg-background-dark shrink-0"
        title="Actualizar movimientos"
      >
        <RefreshCw :size="16" :class="{ 'animate-spin': isLoading }" />
      </button>
    </div>

    <p v-if="hasOpenShift && openedAtFormatted" class="px-1 text-[11px] text-emerald-700 dark:text-emerald-400 font-semibold">
      Turno desde {{ openedAtFormatted }}
    </p>

    <!-- Loading (BaseListSkeleton — sin spinner genérico) -->
    <BaseListSkeleton v-if="isLoading" :count="5" type="simple" />

    <!-- Error Persistente N3 + Reintentar -->
    <div
      v-else-if="error"
      data-test="own-movements-error"
      class="rounded-2xl border border-rose-300 bg-rose-50 dark:bg-rose-950/30 dark:border-rose-800 p-5 text-center space-y-3"
    >
      <AlertTriangle :size="28" class="text-rose-500 mx-auto" />
      <p class="text-sm font-semibold text-rose-700 dark:text-rose-300">{{ error }}</p>
      <BaseButton size="sm" variant="outline" @click="loadMovements">Reintentar</BaseButton>
    </div>

    <!-- Sin turno abierto -->
    <div
      v-else-if="!hasOpenShift"
      class="rounded-2xl border border-amber-200 dark:border-amber-800 bg-amber-50 dark:bg-amber-950/20 p-6 text-center space-y-2"
    >
      <Lock :size="30" class="text-amber-500 mx-auto" />
      <h2 class="text-sm font-bold text-slate-900 dark:text-white">Sin turno abierto</h2>
    </div>

    <!-- Lista vacía -->
    <div
      v-else-if="movements.length === 0"
      class="rounded-2xl border border-slate-200 dark:border-slate-700 bg-surface-light dark:bg-surface-dark p-8 text-center space-y-2"
    >
      <ClipboardList :size="30" class="text-slate-400 mx-auto" />
      <h2 class="text-sm font-bold text-slate-800 dark:text-slate-100">Sin movimientos</h2>
    </div>

    <!-- Lista de Movimientos Propios -->
    <div v-else class="space-y-2.5">
      <div
        v-for="item in movements"
        :key="item.id"
        class="bg-surface-light dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-700 p-3.5 shadow-sm flex items-start justify-between gap-3"
      >
        <div class="min-w-0 space-y-1">
          <div class="flex items-center gap-2 flex-wrap">
            <span class="text-[10px] font-bold uppercase px-2 py-0.5 rounded-full bg-background-light dark:bg-background-dark text-slate-700 dark:text-slate-300">
              {{ sourceLabelMap[item.source] || item.source }}
            </span>
            <span class="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300">
              {{ channelLabelMap[item.payment_method] || item.payment_method }}
            </span>
          </div>
          <p class="text-sm font-semibold text-slate-900 dark:text-white break-words">{{ item.description }}</p>
          <p class="text-[11px] text-slate-400 flex items-center gap-1.5">
            <User :size="12" /> {{ item.actor_name }} ·
            {{ new Date(item.created_at).toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit' }) }}
          </p>
        </div>
        <div class="text-right shrink-0">
          <p
            class="text-sm font-bold font-mono tabular-nums"
            :class="item.source === 'expense' || item.source === 'refund' ? 'text-rose-600' : 'text-emerald-600'"
          >
            {{ item.source === 'expense' || item.source === 'refund' ? '-' : '' }}$ {{ formatCurrency(item.amount) }}
          </p>
          <p v-if="item.category" class="text-[10px] text-slate-400 mt-0.5">{{ item.category }}</p>
        </div>
      </div>

      <p class="text-center text-xs text-slate-400 pt-2">
        Total de movimientos propios: <span class="font-mono tabular-nums font-semibold">{{ totalCount }}</span>
      </p>
    </div>
  </section>
</template>

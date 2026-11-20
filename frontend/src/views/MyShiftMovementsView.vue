<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import cashRepository, {
  type OwnShiftMovement,
  type OwnShiftPaymentMethodFilter,
} from '../data/repositories/cashRepository';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import BaseButton from '../components/ui/BaseButton.vue';
import { ArrowLeft, ClipboardList, Lock, RefreshCw, AlertTriangle, User } from 'lucide-vue-next';

const router = useRouter();
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
  <div class="min-h-screen bg-slate-50 dark:bg-background-dark flex flex-col pb-12">
    <header class="sticky top-0 z-30 bg-white dark:bg-surface-dark border-b border-slate-200 dark:border-slate-800 px-4 h-[64px] flex items-center justify-between">
      <button
        type="button"
        @click="router.push('/')"
        class="p-2 -ml-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800"
      >
        <ArrowLeft :size="22" />
      </button>
      <div class="text-center">
        <h1 class="text-base font-bold text-slate-900 dark:text-white">Mis Movimientos del Turno</h1>
        <p v-if="hasOpenShift && openedAtFormatted" class="text-[11px] text-emerald-600 dark:text-emerald-400 font-medium">
          Turno abierto desde {{ openedAtFormatted }}
        </p>
      </div>
      <button
        type="button"
        @click="loadMovements"
        class="p-2 rounded-xl text-slate-500 hover:bg-slate-100 dark:hover:bg-slate-800"
        title="Actualizar"
      >
        <RefreshCw :size="18" :class="{ 'animate-spin': isLoading }" />
      </button>
    </header>

    <!-- Filtros por Canal -->
    <div class="bg-white dark:bg-surface-dark border-b border-slate-200 dark:border-slate-800 px-4 py-2.5 flex gap-2 overflow-x-auto">
      <button
        v-for="f in paymentFilters"
        :key="f.value"
        type="button"
        @click="selectFilter(f.value)"
        class="px-3 py-1.5 rounded-full text-xs font-semibold whitespace-nowrap transition-colors"
        :class="
          selectedMethod === f.value
            ? 'bg-primary text-white shadow-sm'
            : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200'
        "
      >
        {{ f.label }}
      </button>
    </div>

    <main class="flex-1 p-4 max-w-lg w-full mx-auto space-y-4">
      <!-- Nota de Privacidad / Ceguera de Caja -->
      <div class="rounded-xl border border-blue-200 dark:border-blue-800/50 bg-blue-50 dark:bg-blue-950/30 p-3 text-xs text-blue-800 dark:text-blue-200">
        Visualizas únicamente tus propias operaciones registradas durante el turno abierto actual. Los arqueos esperados de gaveta están protegidos.
      </div>

      <!-- Loading -->
      <div v-if="isLoading" class="py-16 text-center space-y-2">
        <div class="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto"></div>
        <p class="text-xs text-slate-500">Cargando movimientos propios...</p>
      </div>

      <!-- Error -->
      <div v-else-if="error" class="rounded-2xl border border-rose-200 bg-rose-50 dark:bg-rose-950/30 dark:border-rose-800 p-5 text-center space-y-3">
        <AlertTriangle :size="30" class="text-rose-500 mx-auto" />
        <p class="text-sm font-semibold text-rose-700 dark:text-rose-300">{{ error }}</p>
        <BaseButton size="sm" variant="outline" @click="loadMovements">Reintentar</BaseButton>
      </div>

      <!-- Sin turno abierto -->
      <div v-else-if="!hasOpenShift" class="rounded-2xl border border-amber-200 dark:border-amber-800 bg-amber-50 dark:bg-amber-950/20 p-6 text-center space-y-2">
        <Lock :size="32" class="text-amber-500 mx-auto" />
        <h2 class="text-sm font-bold text-slate-900 dark:text-white">No hay un turno abierto</h2>
        <p class="text-xs text-slate-500 dark:text-slate-400">
          Cuando exista un turno de caja abierto en la tienda, aquí verás tus movimientos propios.
        </p>
      </div>

      <!-- Lista vacía -->
      <div v-else-if="movements.length === 0" class="rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-surface-dark p-8 text-center space-y-2">
        <ClipboardList :size="32" class="text-slate-400 mx-auto" />
        <h2 class="text-sm font-bold text-slate-800 dark:text-slate-100">Sin movimientos registrados</h2>
        <p class="text-xs text-slate-500">Aún no registras operaciones con este filtro en el turno actual.</p>
      </div>

      <!-- Lista de Movimientos Propios -->
      <div v-else class="space-y-2.5">
        <div
          v-for="item in movements"
          :key="item.id"
          class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200/80 dark:border-slate-800 p-3.5 shadow-sm flex items-start justify-between gap-3"
        >
          <div class="min-w-0 space-y-1">
            <div class="flex items-center gap-2 flex-wrap">
              <span class="text-[10px] font-bold uppercase px-2 py-0.5 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300">
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
              class="text-sm font-bold"
              :class="item.source === 'expense' || item.source === 'refund' ? 'text-rose-600' : 'text-emerald-600'"
            >
              {{ item.source === 'expense' || item.source === 'refund' ? '-' : '' }}$ {{ formatCurrency(item.amount) }}
            </p>
            <p v-if="item.category" class="text-[10px] text-slate-400 mt-0.5">{{ item.category }}</p>
          </div>
        </div>

        <p class="text-center text-xs text-slate-400 pt-2">
          Total de movimientos propios: {{ totalCount }}
        </p>
      </div>
    </main>
  </div>
</template>

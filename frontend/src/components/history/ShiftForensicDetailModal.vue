<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import cashRepository, {
  type MultichannelCashHistoryItem,
  type ShiftForensicReport,
} from '../../data/repositories/cashRepository';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import BaseButton from '../ui/BaseButton.vue';
import BaseModal from '../ui/BaseModal.vue';
import { AlertTriangle, CheckCircle2, ShieldAlert, Vault, RefreshCw } from 'lucide-vue-next';

type ChannelFilter = 'all' | 'efectivo' | 'digitales' | 'nequi' | 'llave_bre';

const props = defineProps<{
  modelValue: boolean;
  sessionId: string | null;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
}>();

const { formatWithSign } = useCurrencyFormat();
const isLoading = ref(false);
const isLoadingMovements = ref(false);
const error = ref<string | null>(null);
const movementsError = ref<string | null>(null);
const report = ref<ShiftForensicReport | null>(null);
const selectedChannel = ref<ChannelFilter>('all');
const filteredMovements = ref<MultichannelCashHistoryItem[] | null>(null);
const filteredMovementsCount = ref<number | null>(null);

const channelFilters: Array<{ value: ChannelFilter; label: string }> = [
  { value: 'all', label: 'Todos' },
  { value: 'efectivo', label: 'Efectivo' },
  { value: 'digitales', label: 'Digitales' },
  { value: 'nequi', label: 'Nequi' },
  { value: 'llave_bre', label: 'Llave Bre-B' },
];

const loadReport = async (sessionId: string) => {
  isLoading.value = true;
  error.value = null;
  movementsError.value = null;
  report.value = null;
  selectedChannel.value = 'all';
  filteredMovements.value = null;
  filteredMovementsCount.value = null;
  try {
    report.value = await cashRepository.getShiftForensicReport(sessionId);
  } catch (e: any) {
    error.value = e?.message || 'Error al cargar el expediente forense del turno';
  } finally {
    isLoading.value = false;
  }
};

const filterByChannel = async (channel: ChannelFilter) => {
  if (!report.value) return;
  selectedChannel.value = channel;
  movementsError.value = null;

  if (channel === 'all') {
    filteredMovements.value = null;
    filteredMovementsCount.value = null;
    return;
  }

  isLoadingMovements.value = true;
  try {
    const res = await cashRepository.getMultichannelCashHistory({
      storeId: report.value.session.store_id,
      sessionId: report.value.session.id,
      paymentMethod: channel,
      limit: 100,
      offset: 0,
    });
    filteredMovements.value = res.data;
    filteredMovementsCount.value = res.count;
  } catch (e: any) {
    movementsError.value = e?.message || 'Error al filtrar movimientos multicanal';
    filteredMovements.value = [];
  } finally {
    isLoadingMovements.value = false;
  }
};

const displayedMovements = computed(() => {
  if (filteredMovements.value !== null) return filteredMovements.value;
  return report.value?.movements || [];
});

watch(
  () => [props.modelValue, props.sessionId] as const,
  ([open, id]) => {
    if (open && id) {
      loadReport(id);
    } else if (!open) {
      report.value = null;
      error.value = null;
      movementsError.value = null;
      filteredMovements.value = null;
      filteredMovementsCount.value = null;
    }
  },
  { immediate: true }
);

const close = () => emit('update:modelValue', false);

const channelLabel = (channel: string) => {
  if (channel === 'nequi') return 'Nequi';
  if (channel === 'llave_bre') return 'Llave Bre-B';
  return 'Efectivo';
};
</script>

<template>
  <BaseModal
    :modelValue="modelValue"
    @update:modelValue="emit('update:modelValue', $event)"
    maxHeight="90vh"
    showCloseButton
    :showDragHandle="false"
    data-test="shift-forensic-modal"
  >
    <template #header>
      <div class="flex items-center gap-2.5">
        <div class="p-2 rounded-xl bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300">
          <Vault :size="20" />
        </div>
        <div>
          <h2 class="text-base font-bold text-slate-900 dark:text-white">Expediente Forense de Turno</h2>
          <p class="text-xs text-slate-500 dark:text-slate-400">
            Instantánea inmutable (Efectivo / Nequi / Llave Bre-B)
          </p>
        </div>
      </div>
    </template>

    <!-- Body -->
    <div class="p-5 space-y-5">
      <div v-if="isLoading" class="py-12 text-center space-y-2">
        <div class="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin mx-auto"></div>
        <p class="text-xs text-slate-500">Consultando reporte forense en servidor...</p>
      </div>

      <div v-else-if="error" class="rounded-xl border border-rose-200 bg-rose-50 dark:bg-rose-950/30 dark:border-rose-800 p-4 text-center space-y-3">
        <AlertTriangle :size="28" class="text-rose-500 mx-auto" />
        <p class="text-sm font-semibold text-rose-700 dark:text-rose-300">{{ error }}</p>
        <BaseButton v-if="sessionId" size="sm" variant="outline" @click="loadReport(sessionId)">
          <RefreshCw :size="14" class="mr-1" /> Reintentar
        </BaseButton>
      </div>

      <template v-else-if="report">
        <!-- Sesión y Firmas -->
        <div class="rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-800/50 p-4 space-y-3">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <span class="text-xs font-semibold text-slate-500">
              Apertura: <strong class="text-slate-800 dark:text-slate-200">{{ report.session.opened_by_name }}</strong>
              ({{ report.session.opened_by_role }})
            </span>
            <span class="text-xs font-semibold text-slate-500">
              Cierre: <strong class="text-slate-800 dark:text-slate-200">{{ report.session.closed_by_name || (report.session.forced_close ? 'Sistema (24h)' : 'Turno abierto') }}</strong>
            </span>
          </div>

          <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 pt-1">
            <div class="bg-white dark:bg-slate-900 rounded-lg p-2.5 border border-slate-200/70 dark:border-slate-700">
              <p class="text-[10px] uppercase font-bold text-slate-400">Base Inicial</p>
              <p class="text-sm font-bold font-mono tabular-nums text-slate-900 dark:text-white">{{ formatWithSign(report.session.opening_balance) }}</p>
            </div>
            <div class="bg-white dark:bg-slate-900 rounded-lg p-2.5 border border-slate-200/70 dark:border-slate-700">
              <p class="text-[10px] uppercase font-bold text-slate-400">Esperado</p>
              <p class="text-sm font-bold font-mono tabular-nums text-slate-900 dark:text-white">
                {{ report.session.expected_balance !== null ? formatWithSign(report.session.expected_balance) : '—' }}
              </p>
            </div>
            <div class="bg-white dark:bg-slate-900 rounded-lg p-2.5 border border-slate-200/70 dark:border-slate-700">
              <p class="text-[10px] uppercase font-bold text-slate-400">Contado Real</p>
              <p class="text-sm font-bold font-mono tabular-nums text-slate-900 dark:text-white">
                {{ report.session.actual_balance !== null ? formatWithSign(report.session.actual_balance) : 'Sin conteo' }}
              </p>
            </div>
            <div class="bg-white dark:bg-slate-900 rounded-lg p-2.5 border border-slate-200/70 dark:border-slate-700">
              <p class="text-[10px] uppercase font-bold text-slate-400">Descuadre / Intentos</p>
              <p
                class="text-sm font-bold font-mono tabular-nums"
                :class="report.session.difference === 0 ? 'text-emerald-600' : 'text-rose-600'"
              >
                {{ report.session.difference !== null ? formatWithSign(report.session.difference) : 'Pendiente' }}
                <span class="text-[10px] font-medium text-slate-400">({{ report.session.closing_attempts }}/3)</span>
              </p>
            </div>
          </div>
        </div>

        <!-- Desglose Multicanal y Egresos (100% Read Model, sin aritmética en cliente) -->
        <div class="space-y-2">
          <h3 class="text-xs font-bold uppercase tracking-wider text-slate-500">Resumen Financiero del Turno</h3>
          <div class="grid grid-cols-2 sm:grid-cols-3 gap-2.5 text-xs">
            <div class="p-3 rounded-xl border border-slate-200 dark:border-slate-800">
              <p class="text-slate-400">Ventas Efectivo</p>
              <p class="font-bold font-mono tabular-nums text-slate-900 dark:text-white text-sm mt-0.5">{{ formatWithSign(report.financial_summary.total_sales_cash) }}</p>
            </div>
            <div class="p-3 rounded-xl border border-slate-200 dark:border-slate-800">
              <p class="text-slate-400">Ventas Nequi</p>
              <p class="font-bold font-mono tabular-nums text-slate-900 dark:text-white text-sm mt-0.5">{{ formatWithSign(report.financial_summary.total_sales_nequi) }}</p>
            </div>
            <div class="p-3 rounded-xl border border-slate-200 dark:border-slate-800">
              <p class="text-slate-400">Llave Bre-B</p>
              <p class="font-bold font-mono tabular-nums text-slate-900 dark:text-white text-sm mt-0.5">{{ formatWithSign(report.financial_summary.total_sales_llave_bre) }}</p>
            </div>
            <div class="p-3 rounded-xl border border-slate-200 dark:border-slate-800">
              <p class="text-slate-400">Abonos Clientes</p>
              <p class="font-bold font-mono tabular-nums text-emerald-600 text-sm mt-0.5">{{ formatWithSign(report.financial_summary.total_client_abonos) }}</p>
            </div>
            <div class="p-3 rounded-xl border border-slate-200 dark:border-slate-800" data-testid="shift-forensic-opex">
              <p class="text-slate-400">Gastos OPEX</p>
              <p class="font-bold font-mono tabular-nums text-rose-600 text-sm mt-0.5">
                -{{ formatWithSign(report.financial_summary.total_opex_expenses) }}
              </p>
            </div>
            <div class="p-3 rounded-xl border border-slate-200 dark:border-slate-800" data-testid="shift-forensic-refunds">
              <p class="text-slate-400">Reembolsos</p>
              <p class="font-bold font-mono tabular-nums text-rose-600 text-sm mt-0.5">
                -{{ formatWithSign(report.financial_summary.total_refunds) }}
              </p>
            </div>
            <div class="p-3 rounded-xl border border-slate-200 dark:border-slate-800 sm:col-span-3">
              <p class="text-slate-400">Pagos a Proveedores</p>
              <p class="font-bold font-mono tabular-nums text-amber-600 text-sm mt-0.5">-{{ formatWithSign(report.financial_summary.total_supplier_payments) }}</p>
            </div>
          </div>
        </div>

        <!-- Ruido Operativo -->
        <div
          v-if="report.operational_noise.voided_sales.length > 0 || report.operational_noise.security_alerts.length > 0"
          class="rounded-xl border border-amber-200 dark:border-amber-800/50 bg-amber-50/70 dark:bg-amber-950/20 p-4 space-y-2"
        >
          <h3 class="text-xs font-bold uppercase tracking-wider text-amber-800 dark:text-amber-300 flex items-center gap-1.5">
            <ShieldAlert :size="15" /> Ruido Operativo y Alertas ({{ report.operational_noise.voided_sales.length + report.operational_noise.security_alerts.length }})
          </h3>
          <ul class="space-y-1.5 text-xs text-slate-700 dark:text-slate-300">
            <li v-for="v in report.operational_noise.voided_sales" :key="v.sale_id" class="flex justify-between">
              <span>Anulación Ticket #{{ v.ticket_number }} · {{ v.void_reason }} ({{ v.voided_by_name }})</span>
              <span class="font-bold font-mono tabular-nums text-rose-600">{{ formatWithSign(v.total) }}</span>
            </li>
            <li v-for="a in report.operational_noise.security_alerts" :key="a.id" class="flex justify-between">
              <span>{{ a.event_type }} · {{ a.actor_name }}</span>
              <span class="uppercase font-bold text-[10px] px-1.5 py-0.5 rounded bg-amber-200/70 text-amber-900">{{ a.severity }}</span>
            </li>
          </ul>
        </div>

        <!-- Movimientos con filtro Multicanal RPC (SDD-021 CHK-305) -->
        <div class="space-y-2.5">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <h3 class="text-xs font-bold uppercase tracking-wider text-slate-500">
              Movimientos del Turno ({{ filteredMovementsCount ?? report.movements.length }})
            </h3>
            <div class="flex flex-wrap gap-1.5" data-test="shift-channel-filters">
              <button
                v-for="cf in channelFilters"
                :key="cf.value"
                type="button"
                :data-channel="cf.value"
                @click="filterByChannel(cf.value)"
                class="px-2.5 py-1 rounded-full text-[11px] font-semibold transition-colors"
                :class="
                  selectedChannel === cf.value
                    ? 'bg-primary text-white'
                    : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200'
                "
              >
                {{ cf.label }}
              </button>
            </div>
          </div>

          <div v-if="isLoadingMovements" class="py-4 text-center text-xs text-slate-400">
            Consultando movimientos multicanal...
          </div>
          <div v-else-if="movementsError" class="rounded-xl border border-rose-200 bg-rose-50 dark:bg-rose-950/30 p-3 text-xs text-rose-700 dark:text-rose-300">
            {{ movementsError }}
          </div>
          <div v-else-if="displayedMovements.length === 0" class="text-xs text-slate-400 py-4 text-center flex items-center justify-center gap-1.5">
            <CheckCircle2 :size="15" /> Sin movimientos registrados para este canal.
          </div>
          <div v-else class="divide-y divide-slate-100 dark:divide-slate-800 border border-slate-200 dark:border-slate-800 rounded-xl overflow-hidden">
            <div
              v-for="m in displayedMovements"
              :key="m.id"
              class="p-3 flex items-center justify-between gap-3 text-xs bg-white dark:bg-slate-900"
            >
              <div class="min-w-0">
                <p class="font-semibold text-slate-800 dark:text-slate-100 truncate">{{ m.description }}</p>
                <p class="text-[11px] text-slate-400">
                  {{ channelLabel(m.payment_method) }} · {{ m.actor_name }} ({{ m.actor_role }})
                </p>
              </div>
              <span
                class="font-bold font-mono tabular-nums shrink-0"
                :class="m.movement_type === 'ingreso' ? 'text-emerald-600' : 'text-rose-600'"
              >
                {{ m.movement_type === 'ingreso' ? '+' : '-' }}{{ formatWithSign(m.amount) }}
              </span>
            </div>
          </div>
        </div>
      </template>
    </div>

    <template #footer>
      <div class="px-5 py-3 border-t border-slate-200 dark:border-slate-800 flex justify-end">
        <BaseButton variant="outline" size="sm" @click="close">Cerrar</BaseButton>
      </div>
    </template>
  </BaseModal>
</template>

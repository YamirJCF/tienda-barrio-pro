<script setup lang="ts">
import { onMounted, onUnmounted, ref, computed, watch } from 'vue';
import { useHistory, type HistoryType, type DatePreset } from '../../composables/useHistory';
import { useAuthStore } from '../../stores/auth';
import { useEmployeesStore } from '../../stores/employees';
import HistoryItemCard from '../history/HistoryItemCard.vue';
import SaleDetailModal from '../history/SaleDetailModal.vue';
import ShiftForensicDetailModal from '../history/ShiftForensicDetailModal.vue';
import type { AuditSeverity, EvidenceHubDomain } from '../../data/repositories/auditRepository';
import BaseButton from '../ui/BaseButton.vue';
import BaseDropdown, { type DropdownOption } from '../ui/BaseDropdown.vue';
import {
  SearchX,
  Search,
  X,
  RotateCcw,
  WifiOff,
  AlertTriangle,
} from 'lucide-vue-next';

const props = defineProps<{
  initialDomain?: string;
  initialSaleId?: string | null;
  initialSessionId?: string | null;
}>();

const VALID_DOMAINS: HistoryType[] = [
  'sales',
  'cash',
  'inventory',
  'expenses',
  'credits',
  'prices',
  'audit',
];

const authStore = useAuthStore();
const employeesStore = useEmployeesStore();
const {
  items,
  filteredItems,
  isLoading,
  error,
  currentType,
  dateFilter,
  employeeFilter,
  eventTypeFilter,
  paymentMethodFilter,
  auditDomainFilter,
  auditSeverityFilter,
  searchQuery,
  activeDateLabel,
  hasActiveFilters,
  fetchHistory,
  setCustomDateRange,
  resetFilters,
  applyShortcutQuery,
} = useHistory();

const isOnline = ref(typeof navigator !== 'undefined' ? navigator.onLine : true);

const handleOnline = () => {
  isOnline.value = true;
};

const handleOffline = () => {
  isOnline.value = false;
};

// Employees state
const employees = ref<{ id: string; name: string }[]>([]);

const loadEmployees = async () => {
  if (employees.value.length > 0 || !authStore.currentStore) return;
  try {
    await employeesStore.initialize(authStore.currentStore.id);
    employees.value = employeesStore.activeOperationalEmployees.map((e) => ({
      id: e.id,
      name: e.name,
    }));
  } catch (e) {
    console.error('[AuditHistoryTab] Failed to load employees', e);
  }
};

// 1. Opciones de Dominio (7 dominios)
const domainOptions: DropdownOption[] = [
  { value: 'sales', label: 'Ventas' },
  { value: 'cash', label: 'Caja' },
  { value: 'inventory', label: 'Compras' },
  { value: 'expenses', label: 'Gastos' },
  { value: 'credits', label: 'Créditos' },
  { value: 'prices', label: 'Precios' },
  { value: 'audit', label: 'Auditoría' },
];

const handleDomainChange = (val: string) => {
  localSearch.value = '';
  searchQuery.value = '';
  fetchHistory(val as HistoryType);
};

// 2. Opciones de Período (FRD-005 Regla 6: default Últimos 7 días)
const datePresetOptions: DropdownOption[] = [
  { value: 'week', label: 'Últimos 7 días' },
  { value: 'today', label: 'Hoy' },
  { value: 'yesterday', label: 'Ayer' },
  { value: 'month', label: 'Últimos 30 días' },
  { value: 'custom', label: 'Rango personalizado...' },
];

const tempStartDate = ref('');
const tempEndDate = ref('');

const toBogotaDateStr = (d: Date): string =>
  new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Bogota',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(d);

const shiftBogotaDays = (dateStr: string, deltaDays: number): string => {
  const [y, m, d] = dateStr.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d + deltaDays)).toISOString().slice(0, 10);
};

const handleDateChange = (val: string) => {
  if (val === 'custom') {
    dateFilter.value = 'custom';
    if (!tempStartDate.value) {
      const todayBogota = toBogotaDateStr(new Date());
      tempEndDate.value = todayBogota;
      tempStartDate.value = shiftBogotaDays(todayBogota, -7);
    }
  } else {
    fetchHistory(undefined, val as DatePreset);
  }
};

const applyCustomRange = () => {
  if (!tempStartDate.value || !tempEndDate.value) return;
  if (tempStartDate.value > tempEndDate.value) return;
  setCustomDateRange(tempStartDate.value, tempEndDate.value);
};

const expandDateRange = () => {
  fetchHistory(undefined, 'month');
};

// 3. Opciones de Método de Pago (FRD-021 Multichannel)
const isPaymentMethodApplicable = computed(() => {
  return ['sales', 'expenses', 'credits'].includes(currentType.value);
});

const paymentOptions = computed<DropdownOption[]>(() => {
  const base: DropdownOption[] = [
    { value: 'all', label: 'Pago: Todos' },
    { value: 'efectivo', label: 'Efectivo' },
    { value: 'digital', label: 'Digitales (Todos)' },
    { value: 'nequi', label: 'Nequi' },
    { value: 'llave_bre', label: 'Llave Bre-B' },
  ];
  if (currentType.value === 'credits') {
    base.push({ value: 'fiado', label: 'Fiado' });
  }
  return base;
});

// 4. Opciones de Tipo de Evento (Contextual por dominio)
const eventTypeOptions = computed<DropdownOption[]>(() => {
  switch (currentType.value) {
    case 'sales':
      return [
        { value: 'all', label: 'Tipo: Todas' },
        { value: 'creations', label: 'Creaciones' },
        { value: 'cancellations', label: 'Anulaciones' },
      ];
    case 'inventory':
      return [
        { value: 'all', label: 'Tipo: Todas' },
        { value: 'entries', label: 'Entradas' },
        { value: 'adjustments', label: 'Ajustes' },
      ];
    case 'cash':
      return [
        { value: 'all', label: 'Tipo: Todos' },
        { value: 'APERTURA', label: 'Aperturas' },
        { value: 'CIERRE', label: 'Cierres' },
      ];
    case 'audit':
      return [
        { value: 'all', label: 'Tipo: Todos' },
        { value: 'LOGIN_SUCCESS', label: 'Login OK' },
        { value: 'LOGIN_FAILED', label: 'Login Fallido' },
        { value: 'PIN_CHANGE', label: 'Cambio PIN' },
        { value: 'CASH_DISCREPANCY_ALERT', label: 'Descuadre Crítico' },
        { value: 'CASH_DISCREPANCY', label: 'Diferencia Arqueo' },
        { value: 'UNAUTHORIZED_SHIFT_CLOSE', label: 'Cierre Ajeno Bloqueado' },
        { value: 'INVENTORY_COUNT_ADJUSTMENT', label: 'Ajuste Conteo Físico' },
        { value: 'BUSINESS_CONSUMPTION', label: 'Consumo Negocio' },
        { value: 'PERSONAL_WITHDRAWAL', label: 'Retiro Personal ($0)' },
        { value: 'REFUND_MERMA', label: 'Merma por Devolución' },
        { value: 'SALE_VOIDED', label: 'Venta Anulada' },
      ];
    case 'credits':
      return [
        { value: 'all', label: 'Tipo: Todos' },
        { value: 'abono', label: 'Abonos' },
        { value: 'venta_fiado', label: 'Deudas Fiado' },
        { value: 'anulacion_fiado', label: 'Anulaciones Fiado' },
      ];
    default:
      return [];
  }
});

// 5. Opciones de Empleado (Admin supervisa a todos los empleados)
const employeeOptions = computed<DropdownOption[]>(() => {
  const list: DropdownOption[] = [
    { value: 'ALL', label: 'Todos los empleados' },
  ];
  for (const emp of employees.value) {
    list.push({ value: emp.id, label: emp.name });
  }
  return list;
});

const currentEmployeeValue = computed(() => {
  return employeeFilter.value || 'ALL';
});

const handleEmployeeChange = (val: string) => {
  employeeFilter.value = val === 'ALL' ? null : val;
};

// 6. Buscador y Atajos
const localSearch = ref('');
let searchTimeout: ReturnType<typeof setTimeout> | null = null;

const onSearchInput = (value: string) => {
  if (searchTimeout) clearTimeout(searchTimeout);
  searchTimeout = setTimeout(() => {
    searchQuery.value = value;
  }, 250);
};

const handleSearchCommit = async () => {
  if (!localSearch.value.trim()) return;
  const { freeText, matchedCount } = await applyShortcutQuery(localSearch.value, employees.value);
  if (matchedCount > 0) {
    localSearch.value = freeText;
  }
};

const clearSearch = () => {
  localSearch.value = '';
  searchQuery.value = '';
};

// Reset global de filtros
const handleResetFilters = async () => {
  localSearch.value = '';
  await resetFilters();
};

// Sale & Shift Forensic Detail Modals
const showSaleDetail = ref(false);
const selectedSaleId = ref<string | null>(null);
const showShiftDetail = ref(false);
const selectedSessionId = ref<string | null>(null);

const auditDomainOptions: DropdownOption[] = [
  { value: 'todos', label: 'Hub: Todos' },
  { value: 'caja', label: 'Hub: Caja' },
  { value: 'ventas', label: 'Hub: Ventas' },
  { value: 'inventario', label: 'Hub: Inventario' },
  { value: 'seguridad', label: 'Hub: Seguridad' },
  { value: 'precios', label: 'Hub: Precios' },
  { value: 'creditos', label: 'Hub: Créditos' },
];

const auditSeverityOptions: DropdownOption[] = [
  { value: 'all', label: 'Severidad: Todas' },
  { value: 'critical', label: 'Crítico' },
  { value: 'warning', label: 'Alerta' },
  { value: 'info', label: 'Info' },
];

const handleAuditDomainChange = (val: string) => {
  auditDomainFilter.value = val as EvidenceHubDomain;
  fetchHistory('audit');
};

const handleAuditSeverityChange = (val: string) => {
  auditSeverityFilter.value = val as 'all' | AuditSeverity;
  fetchHistory('audit');
};

const handleCardClick = (id: string) => {
  if (currentType.value === 'sales') {
    selectedSaleId.value = id;
    showSaleDetail.value = true;
  } else if (currentType.value === 'cash') {
    selectedSessionId.value = id;
    showShiftDetail.value = true;
  }
};

const applyDeepLinkModal = (saleId?: string | null, sessionId?: string | null) => {
  if (saleId) {
    selectedSaleId.value = saleId;
    showSaleDetail.value = true;
  } else if (sessionId) {
    selectedSessionId.value = sessionId;
    showShiftDetail.value = true;
  }
};

watch(
  () => [props.initialDomain, props.initialSaleId, props.initialSessionId],
  async ([domain, saleId, sessionId]) => {
    if (domain && VALID_DOMAINS.includes(domain as HistoryType) && domain !== currentType.value) {
      await fetchHistory(domain as HistoryType);
    }
    applyDeepLinkModal(saleId, sessionId);
  }
);

onMounted(async () => {
  if (typeof window !== 'undefined') {
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);
  }
  const initialDomain =
    props.initialDomain && VALID_DOMAINS.includes(props.initialDomain as HistoryType)
      ? (props.initialDomain as HistoryType)
      : undefined;
  await fetchHistory(initialDomain);
  loadEmployees();
  applyDeepLinkModal(props.initialSaleId, props.initialSessionId);
});

onUnmounted(() => {
  if (searchTimeout) clearTimeout(searchTimeout);
  if (typeof window !== 'undefined') {
    window.removeEventListener('online', handleOnline);
    window.removeEventListener('offline', handleOffline);
  }
});
</script>

<template>
  <div class="min-h-screen bg-background-light dark:bg-background-dark flex flex-col">
    <!-- Filter Header -->
    <div class="relative z-20 bg-white/95 dark:bg-surface-dark backdrop-blur-md border-b border-slate-200 dark:border-slate-800 shadow-sm pt-3">
      <!-- Fila 1: Buscador con soporte de atajos silenciosos -->
      <div class="px-4 pb-2.5">
        <div class="relative">
          <Search :size="16" class="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400 shrink-0 pointer-events-none" />
          <input
            v-model="localSearch"
            @input="onSearchInput(localSearch)"
            @keydown.enter="handleSearchCommit"
            type="text"
            placeholder="Buscar ticket, producto, cliente o atajo (ej. efectivo, hoy)..."
            class="w-full pl-10 pr-9 py-2 text-xs md:text-sm bg-slate-100 dark:bg-slate-800/90 border border-slate-200 dark:border-slate-700 rounded-xl text-slate-800 dark:text-slate-100 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent transition-all shadow-inner"
          />
          <button
            v-if="localSearch"
            type="button"
            @click="clearSearch"
            class="absolute right-2.5 top-1/2 -translate-y-1/2 p-1 rounded-full text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors"
            title="Limpiar búsqueda"
          >
            <X :size="14" />
          </button>
        </div>
      </div>

      <!-- Fila 2: Barra de Desplegables Compactos -->
      <div class="px-4 pb-3 flex items-center gap-2 flex-wrap py-0.5">
        <!-- 1. Dominio -->
        <BaseDropdown
          :model-value="currentType"
          :options="domainOptions"
          @update:model-value="handleDomainChange"
        />

        <!-- 2. Período -->
        <BaseDropdown
          :model-value="dateFilter"
          :options="datePresetOptions"
          prefix-label="Período"
          @update:model-value="handleDateChange"
        />

        <!-- 3. Medio de Pago (Contextual) -->
        <BaseDropdown
          v-if="isPaymentMethodApplicable"
          :model-value="paymentMethodFilter"
          :options="paymentOptions"
          @update:model-value="(val) => paymentMethodFilter = val"
        />

        <!-- 4. Tipo de Evento (Contextual) -->
        <BaseDropdown
          v-if="eventTypeOptions.length > 0"
          :model-value="eventTypeFilter"
          :options="eventTypeOptions"
          @update:model-value="(val) => eventTypeFilter = val"
        />

        <!-- 4b. Sub-filtros Evidence Hub (Dominio y Severidad) -->
        <BaseDropdown
          v-if="currentType === 'audit'"
          :model-value="auditDomainFilter"
          :options="auditDomainOptions"
          @update:model-value="handleAuditDomainChange"
        />
        <BaseDropdown
          v-if="currentType === 'audit'"
          :model-value="auditSeverityFilter"
          :options="auditSeverityOptions"
          @update:model-value="handleAuditSeverityChange"
        />

        <!-- 5. Empleado -->
        <BaseDropdown
          :model-value="currentEmployeeValue"
          :options="employeeOptions"
          prefix-label="Empleado"
          :searchable="true"
          :search-threshold="6"
          @update:model-value="handleEmployeeChange"
        />

        <!-- Botón Limpiar Filtros -->
        <button
          v-if="hasActiveFilters"
          type="button"
          @click="handleResetFilters"
          class="inline-flex items-center gap-1 px-3 py-1.5 rounded-full text-xs font-semibold text-rose-600 dark:text-rose-400 bg-rose-50 dark:bg-rose-950/40 hover:bg-rose-100 dark:hover:bg-rose-900/40 border border-rose-200 dark:border-rose-900/50 transition-colors shrink-0"
          title="Restablecer filtros"
        >
          <RotateCcw :size="12" />
          Limpiar
        </button>
      </div>

      <!-- Panel de Rango Personalizado (cuando Período = 'custom') -->
      <div v-if="dateFilter === 'custom'" class="px-4 pb-3">
        <div class="bg-slate-50 dark:bg-slate-800/60 rounded-xl p-3 border border-slate-200 dark:border-slate-700/80 space-y-2">
          <div class="flex items-center gap-3">
            <div class="flex-1">
              <label class="block text-[11px] font-semibold text-slate-500 dark:text-slate-400 mb-1">Desde</label>
              <input
                v-model="tempStartDate"
                type="date"
                max="9999-12-31"
                class="w-full px-2.5 py-1.5 text-xs bg-white dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-1 focus:ring-primary"
              />
            </div>
            <div class="flex-1">
              <label class="block text-[11px] font-semibold text-slate-500 dark:text-slate-400 mb-1">Hasta</label>
              <input
                v-model="tempEndDate"
                type="date"
                max="9999-12-31"
                class="w-full px-2.5 py-1.5 text-xs bg-white dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-800 dark:text-slate-100 focus:outline-none focus:ring-1 focus:ring-primary"
              />
            </div>
            <div class="self-end">
              <BaseButton
                @click="applyCustomRange"
                variant="primary"
                size="sm"
                :disabled="!tempStartDate || !tempEndDate || tempStartDate > tempEndDate"
              >
                Aplicar
              </BaseButton>
            </div>
          </div>
          <p v-if="tempStartDate && tempEndDate && tempStartDate > tempEndDate" class="text-xs text-rose-500 font-medium">
            La fecha inicial no puede ser posterior a la fecha final.
          </p>
        </div>
      </div>
    </div>

    <!-- Main Content -->
    <main class="flex-1 p-4 overflow-y-auto">
      <!-- Loading State -->
      <div v-if="isLoading" class="flex flex-col items-center justify-center py-20">
        <div class="w-9 h-9 border-3 border-primary border-t-transparent rounded-full animate-spin"></div>
        <p class="mt-3 text-xs font-semibold text-slate-500 dark:text-slate-400">Cargando registros...</p>
      </div>

      <!-- Offline / Error State (N3 Fail-Closed) -->
      <div
        v-else-if="!isOnline || error"
        role="alert"
        data-testid="history-error-banner"
        class="bg-rose-50 dark:bg-rose-950/20 p-5 rounded-2xl text-center border border-rose-200 dark:border-rose-900/40 max-w-md mx-auto my-6 flex flex-col items-center gap-3"
      >
        <WifiOff v-if="!isOnline" :size="32" class="text-rose-500" />
        <AlertTriangle v-else :size="32" class="text-rose-500" />
        <p class="text-rose-700 dark:text-rose-300 text-sm font-semibold">
          {{ error || 'Sin conexión a internet. Reconecta para consultar el historial.' }}
        </p>
        <BaseButton
          data-testid="history-retry-btn"
          @click="fetchHistory(currentType)"
          variant="outline"
          size="sm"
        >
          Reintentar
        </BaseButton>
      </div>

      <!-- Empty State (FRD-005 Regla 6: contextual con período y botón para ampliar) -->
      <div
        v-else-if="filteredItems.length === 0"
        class="flex flex-col items-center justify-center py-16 px-4 text-center max-w-sm mx-auto"
      >
        <div class="w-16 h-16 bg-slate-100 dark:bg-slate-800 rounded-full flex items-center justify-center mb-3">
          <SearchX :size="32" :stroke-width="1.5" class="text-slate-400" />
        </div>
        <h3 class="text-base font-bold text-slate-800 dark:text-slate-200">
          {{ searchQuery ? 'Sin resultados' : 'Sin registros' }}
        </h3>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1 leading-relaxed">
          {{ searchQuery
            ? `No se encontraron coincidencias para "${searchQuery}"`
            : `No se encontraron movimientos registrados en: ${activeDateLabel}.`
          }}
        </p>

        <!-- Botones de ampliación de rango y restablecimiento -->
        <div class="flex flex-wrap items-center justify-center gap-2 mt-5">
          <BaseButton
            v-if="dateFilter === 'today' || dateFilter === 'yesterday' || dateFilter === 'week'"
            @click="expandDateRange"
            variant="primary"
            size="sm"
          >
            Ver últimos 30 días
          </BaseButton>
          <BaseButton
            v-if="hasActiveFilters"
            @click="handleResetFilters"
            variant="outline"
            size="sm"
          >
            Restablecer filtros
          </BaseButton>
        </div>
      </div>

      <!-- List of Items -->
      <div v-else class="space-y-2.5 max-w-3xl mx-auto">
        <HistoryItemCard
          v-for="item in filteredItems"
          :key="item.id"
          :item="item"
          @click="handleCardClick"
        />

        <!-- Conteo sobrio al pie -->
        <div class="pt-4 pb-2 text-center">
          <p class="text-xs font-medium text-slate-400 dark:text-slate-500 font-mono tabular-nums">
            Mostrando {{ filteredItems.length }} registro{{ filteredItems.length !== 1 ? 's' : '' }}
            <span v-if="searchQuery && filteredItems.length !== items.length" class="text-primary dark:text-blue-400">
              (de {{ items.length }})
            </span>
          </p>
        </div>
      </div>
    </main>

    <!-- Sale Detail Modal -->
    <SaleDetailModal
      v-model="showSaleDetail"
      :saleId="selectedSaleId"
      @voided="fetchHistory(currentType)"
    />

    <!-- Forensic Shift Report Modal (SDD-027-01 CHK-306) -->
    <ShiftForensicDetailModal
      v-model="showShiftDetail"
      :sessionId="selectedSessionId"
    />
  </div>
</template>

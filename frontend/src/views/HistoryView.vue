<script setup lang="ts">
import { onMounted, onUnmounted, ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useHistory, type HistoryType, type DatePreset } from '../composables/useHistory';
import { useAuthStore } from '../stores/auth';
import HistoryItemCard from '../components/history/HistoryItemCard.vue';
import SaleDetailModal from '../components/history/SaleDetailModal.vue';
import BaseButton from '../components/ui/BaseButton.vue';
import BaseDropdown, { type DropdownOption } from '../components/ui/BaseDropdown.vue';
import { 
  ArrowLeft, 
  SearchX, 
  Search, 
  X,
  RotateCcw
} from 'lucide-vue-next';

const props = defineProps<{
  isEmbedded?: boolean;
}>();

const router = useRouter();
const authStore = useAuthStore();
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
  searchQuery,
  customStartDate,
  customEndDate,
  activeDateLabel,
  hasActiveFilters,
  fetchHistory,
  setCustomDateRange,
  resetFilters,
  applyShortcutQuery
} = useHistory();

// Employees state
const employees = ref<{ id: string; name: string }[]>([]);

const loadEmployees = async () => {
  if (employees.value.length > 0) return;
  try {
    const { getSupabaseClient } = await import('../data/supabaseClient');
    const supabase = getSupabaseClient();
    if (!supabase || !authStore.currentStore) return;
    
    const { data } = await supabase
      .from('employees')
      .select('id, name')
      .eq('store_id', authStore.currentStore.id)
      .eq('is_active', true)
      .order('name');

    if (data) employees.value = data;
  } catch (e) {
    console.error('[HistoryView] Failed to load employees', e);
  }
};

// 1. Opciones de Dominio (7 dominios)
const domainOptions: DropdownOption[] = [
  { value: 'sales', label: '🛒 Ventas' },
  { value: 'cash', label: '🏛️ Caja' },
  { value: 'inventory', label: '📦 Compras' },
  { value: 'expenses', label: '💵 Gastos' },
  { value: 'credits', label: '📒 Créditos' },
  { value: 'prices', label: '🏷️ Precios' },
  { value: 'audit', label: '🛡️ Auditoría' },
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

const handleDateChange = (val: string) => {
  if (val === 'custom') {
    dateFilter.value = 'custom';
    if (!tempStartDate.value) {
      const now = new Date();
      tempEndDate.value = now.toISOString().slice(0, 10);
      now.setDate(now.getDate() - 7);
      tempStartDate.value = now.toISOString().slice(0, 10);
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
    { value: 'efectivo', label: '💵 Efectivo' },
    { value: 'digital', label: '📱 Digitales (Todos)' },
    { value: 'nequi', label: '📱 Nequi' },
    { value: 'daviplata', label: '📱 Daviplata' },
  ];
  if (currentType.value === 'credits') {
    base.push({ value: 'fiado', label: '📋 Fiado' });
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
      ];
    case 'credits':
      return [
        { value: 'all', label: 'Tipo: Todos' },
        { value: 'payment', label: 'Abonos' },
        { value: 'charge', label: 'Deudas' },
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

// Sale Detail Modal
const showSaleDetail = ref(false);
const selectedSaleId = ref<string | null>(null);

const handleCardClick = (id: string) => {
  if (currentType.value === 'sales') {
    selectedSaleId.value = id;
    showSaleDetail.value = true;
  }
};

const goBack = () => router.back();

onMounted(async () => {
  await fetchHistory();
  loadEmployees();
});

onUnmounted(() => {
  if (searchTimeout) clearTimeout(searchTimeout);
});
</script>

<template>
  <div class="min-h-screen bg-slate-50 dark:bg-[#0f172a] flex flex-col">
    <!-- Header -->
    <header class="bg-white/95 dark:bg-[#1e293b]/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-800 shadow-sm transition-all" :class="isEmbedded ? 'relative z-20' : 'sticky top-0 z-30'">
      <div v-if="!isEmbedded" class="px-4 py-3 flex items-center gap-3">
        <BaseButton @click="goBack" variant="ghost" size="icon" class="-ml-2">
          <ArrowLeft :size="24" :stroke-width="1.5" />
        </BaseButton>
        <h1 class="text-lg font-bold text-slate-900 dark:text-white">
          Historial y Auditoría
        </h1>
      </div>

      <div v-else class="pt-3"></div>

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
            @click="clearSearch"
            class="absolute right-2.5 top-1/2 -translate-y-1/2 p-1 rounded-full text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors"
            title="Limpiar búsqueda"
          >
            <X :size="14" />
          </button>
        </div>
      </div>

      <!-- Fila 2: Barra de Desplegables Compactos (Opción A) -->
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
    </header>

    <!-- Main Content -->
    <main class="flex-1 p-4 overflow-y-auto">
      <!-- Loading State -->
      <div v-if="isLoading" class="flex flex-col items-center justify-center py-20">
        <div class="w-9 h-9 border-3 border-primary border-t-transparent rounded-full animate-spin"></div>
        <p class="mt-3 text-xs font-semibold text-slate-500 dark:text-slate-400">Cargando registros...</p>
      </div>

      <!-- Error State -->
      <div v-else-if="error" class="bg-rose-50 dark:bg-rose-950/20 p-5 rounded-2xl text-center border border-rose-200 dark:border-rose-900/40 max-w-md mx-auto my-6">
        <p class="text-rose-600 dark:text-rose-400 text-sm font-semibold pb-3">{{ error }}</p>
        <BaseButton
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
          <p class="text-xs font-medium text-slate-400 dark:text-slate-500">
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
    />
  </div>
</template>

<style scoped>
.no-scrollbar::-webkit-scrollbar {
  display: none;
}
.no-scrollbar {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
</style>

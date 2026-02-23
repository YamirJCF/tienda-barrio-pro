<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue';
import { useRouter } from 'vue-router';

const props = defineProps<{
  isEmbedded?: boolean;
}>();
import { useHistory, type HistoryType, type DatePreset } from '../composables/useHistory';
import { useAuthStore } from '../stores/auth';
import HistoryItemCard from '../components/history/HistoryItemCard.vue';
import SaleDetailModal from '../components/history/SaleDetailModal.vue';
import BaseButton from '../components/ui/BaseButton.vue';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { 
  ArrowLeft, 
  ShoppingCart, 
  Landmark, 
  ShieldCheck, 
  Package, 
  Banknote, 
  Tags,
  SearchX,
  Search,
  Calendar,
  CalendarRange,
  Users,
  X
} from 'lucide-vue-next';

const router = useRouter();
const authStore = useAuthStore();
const { formatCurrency } = useCurrencyFormat();
const {
  items, filteredItems, isLoading, error,
  currentType, dateFilter, employeeFilter,
  searchQuery, customStartDate, customEndDate,
  summary, fetchHistory, setCustomDateRange
} = useHistory();

// Tab definitions
const filters: { label: string; value: HistoryType; component: any }[] = [
  { label: 'Ventas', value: 'sales', component: ShoppingCart },
  { label: 'Caja', value: 'cash', component: Landmark },
  { label: 'Compras', value: 'inventory', component: Package },
  { label: 'Auditoría', value: 'audit', component: ShieldCheck },
  { label: 'Gastos', value: 'expenses', component: Banknote },
  { label: 'Precios', value: 'prices', component: Tags },
];

// Date presets
const datePresets: { label: string; value: DatePreset }[] = [
  { label: 'Hoy', value: 'today' },
  { label: 'Ayer', value: 'yesterday' },
  { label: 'Semana', value: 'week' },
  { label: 'Mes', value: 'month' },
];

// Custom date range panel (T3)
const showDateRangePanel = ref(false);
const tempStartDate = ref('');
const tempEndDate = ref('');

const applyCustomRange = () => {
  if (!tempStartDate.value || !tempEndDate.value) return;
  if (tempStartDate.value > tempEndDate.value) return;
  showDateRangePanel.value = false;
  setCustomDateRange(tempStartDate.value, tempEndDate.value);
};

const clearCustomRange = () => {
  showDateRangePanel.value = false;
  tempStartDate.value = '';
  tempEndDate.value = '';
  fetchHistory(undefined, 'today');
};

// Employee filter
const showEmployeeFilter = ref(false);
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

// Sale Detail Modal (T4)
const showSaleDetail = ref(false);
const selectedSaleId = ref<string | null>(null);

const handleCardClick = (id: string) => {
  if (currentType.value === 'sales') {
    selectedSaleId.value = id;
    showSaleDetail.value = true;
  }
};

// Search debounce (T2)
const localSearch = ref('');
let searchTimeout: ReturnType<typeof setTimeout> | null = null;

const onSearchInput = (value: string) => {
  if (searchTimeout) clearTimeout(searchTimeout);
  searchTimeout = setTimeout(() => {
    searchQuery.value = value;
  }, 300);
};

const goBack = () => router.back();

const selectFilter = (type: HistoryType) => {
  showDateRangePanel.value = false;
  localSearch.value = '';
  searchQuery.value = '';
  fetchHistory(type);
};

const selectDate = (preset: DatePreset) => {
  showDateRangePanel.value = false;
  fetchHistory(undefined, preset);
};

const selectEmployee = (id: string | null) => {
  employeeFilter.value = id;
  showEmployeeFilter.value = false;
  fetchHistory();
};

// Show employee filter only on sales tab
const isEmployeeFilterable = () => currentType.value === 'sales';

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
    <header class="sticky top-0 z-30 bg-white dark:bg-[#1e293b] border-b border-slate-100 dark:border-slate-800 shadow-sm">
      <div v-if="!isEmbedded" class="px-4 py-3 flex items-center gap-3">
        <BaseButton @click="goBack" variant="ghost" size="icon" class="-ml-2">
          <ArrowLeft :size="24" :stroke-width="1.5" />
        </BaseButton>
        <h1 class="text-lg font-bold text-slate-900 dark:text-white">
          Historial y Auditoría
        </h1>
      </div>

      <!-- Espaciador si está embebido para alinear padding -->
      <div v-else class="pt-4"></div>

      <!-- Search Bar (T2) -->
      <div class="px-4 pb-2">
        <div class="relative">
          <Search :size="16" class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
          <input
            v-model="localSearch"
            @input="onSearchInput(localSearch)"
            type="text"
            :placeholder="currentType === 'sales' ? 'Buscar ticket, producto o cliente...' : 'Buscar en historial...'"
            class="w-full pl-9 pr-8 py-2 text-sm bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl text-slate-800 dark:text-slate-200 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
          />
          <button
            v-if="localSearch"
            @click="localSearch = ''; searchQuery = ''"
            class="absolute right-2 top-1/2 -translate-y-1/2 p-1 rounded-full hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors"
          >
            <X :size="14" class="text-slate-400" />
          </button>
        </div>
      </div>

      <!-- Category Tabs -->
      <div class="px-4 pb-2 overflow-x-auto no-scrollbar">
        <div class="flex gap-2">
          <BaseButton
            v-for="filter in filters"
            :key="filter.value"
            @click="selectFilter(filter.value)"
            :variant="currentType === filter.value ? 'primary' : 'outline'"
            size="sm"
            class="!rounded-full whitespace-nowrap"
          >
            <component :is="filter.component" :size="18" :stroke-width="1.5" class="mr-1.5" />
            {{ filter.label }}
          </BaseButton>
        </div>
      </div>

      <!-- Date Filter Pills -->
      <div class="px-4 pb-2 flex items-center gap-2">
        <Calendar :size="16" class="text-slate-400 flex-shrink-0" />
        <div class="flex gap-1.5 overflow-x-auto no-scrollbar">
          <button
            v-for="preset in datePresets"
            :key="preset.value"
            @click="selectDate(preset.value)"
            class="px-3 py-1 text-xs font-semibold rounded-full whitespace-nowrap transition-colors"
            :class="dateFilter === preset.value 
              ? 'bg-blue-600 text-white' 
              : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700'"
          >
            {{ preset.label }}
          </button>

          <!-- Custom Range Button (T3) -->
          <button
            @click="showDateRangePanel = !showDateRangePanel"
            class="px-3 py-1 text-xs font-semibold rounded-full whitespace-nowrap transition-colors flex items-center gap-1"
            :class="dateFilter === 'custom'
              ? 'bg-blue-600 text-white'
              : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700'"
          >
            <CalendarRange :size="12" />
            Rango
          </button>
        </div>

        <!-- Employee Filter (only for sales) -->
        <button
          v-if="isEmployeeFilterable()"
          @click="showEmployeeFilter = !showEmployeeFilter"
          class="ml-auto flex items-center gap-1 px-3 py-1 text-xs font-semibold rounded-full transition-colors whitespace-nowrap"
          :class="employeeFilter 
            ? 'bg-violet-600 text-white' 
            : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700'"
        >
          <Users :size="14" />
          {{ employeeFilter ? 'Filtrando' : 'Empleado' }}
        </button>
      </div>

      <!-- Custom Date Range Panel (T3) -->
      <div v-if="showDateRangePanel" class="px-4 pb-3">
        <div class="bg-slate-50 dark:bg-slate-800/50 rounded-xl p-3 border border-slate-200 dark:border-slate-700 space-y-3">
          <div class="flex gap-3">
            <div class="flex-1">
              <label class="block text-xs font-medium text-slate-500 mb-1">Desde</label>
              <input
                v-model="tempStartDate"
                type="date"
                max="9999-12-31"
                class="w-full px-3 py-2 text-sm bg-white dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
            <div class="flex-1">
              <label class="block text-xs font-medium text-slate-500 mb-1">Hasta</label>
              <input
                v-model="tempEndDate"
                type="date"
                max="9999-12-31"
                class="w-full px-3 py-2 text-sm bg-white dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-lg text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>
          </div>
          <div class="flex gap-2">
            <BaseButton
              @click="applyCustomRange"
              variant="primary"
              size="sm"
              class="flex-1"
              :disabled="!tempStartDate || !tempEndDate || tempStartDate > tempEndDate"
            >
              Aplicar
            </BaseButton>
            <BaseButton
              v-if="dateFilter === 'custom'"
              @click="clearCustomRange"
              variant="outline"
              size="sm"
            >
              Limpiar
            </BaseButton>
          </div>
          <p v-if="tempStartDate && tempEndDate && tempStartDate > tempEndDate" class="text-xs text-red-500">
            La fecha "Desde" no puede ser mayor que "Hasta"
          </p>
        </div>
      </div>

      <!-- Employee Dropdown -->
      <div v-if="showEmployeeFilter && isEmployeeFilterable()" class="px-4 pb-3">
        <div class="bg-slate-50 dark:bg-slate-800/50 rounded-xl p-2 border border-slate-200 dark:border-slate-700 flex flex-wrap gap-1.5">
          <button
            @click="selectEmployee(null)"
            class="px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors"
            :class="!employeeFilter 
              ? 'bg-violet-600 text-white' 
              : 'bg-white dark:bg-slate-700 text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-600'"
          >
            Todos
          </button>
          <button
            v-for="emp in employees"
            :key="emp.id"
            @click="selectEmployee(emp.id)"
            class="px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors"
            :class="employeeFilter === emp.id 
              ? 'bg-violet-600 text-white' 
              : 'bg-white dark:bg-slate-700 text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-600'"
          >
            {{ emp.name }}
          </button>
        </div>
      </div>
    </header>

    <!-- Summary Bar (T5) -->
    <div v-if="!isLoading && filteredItems.length > 0" class="px-4 pt-3">
      <div class="bg-white dark:bg-slate-800 rounded-xl p-3 border border-slate-100 dark:border-slate-700 flex items-center justify-between">
        <div>
          <p class="text-xs text-slate-400 font-medium uppercase tracking-wider">{{ summary.label }}</p>
          <p class="text-sm text-slate-600 dark:text-slate-300">
            {{ filteredItems.length }} registro{{ filteredItems.length !== 1 ? 's' : '' }}
            <span v-if="searchQuery && filteredItems.length !== items.length" class="text-blue-500">
              (de {{ items.length }})
            </span>
          </p>
        </div>
        <div v-if="summary.totalAmount > 0" class="text-right">
          <p class="text-lg font-bold text-slate-900 dark:text-white">
            {{ formatCurrency(summary.totalAmount) }}
          </p>
        </div>
      </div>
    </div>

    <!-- Main Content -->
    <main class="flex-1 p-4 overflow-y-auto">
      <!-- Loading State -->
      <div v-if="isLoading" class="flex flex-col items-center justify-center py-20">
        <div class="w-10 h-10 border-4 border-primary border-t-transparent rounded-full animate-spin"></div>
        <p class="mt-4 text-sm font-medium text-slate-500">Cargando registros...</p>
      </div>

      <!-- Error State -->
      <div v-else-if="error" class="bg-red-50 dark:bg-red-900/10 p-4 rounded-xl text-center">
        <p class="text-red-600 dark:text-red-400 font-medium pb-2">{{ error }}</p>
        <BaseButton
          @click="fetchHistory(currentType)"
          variant="ghost"
          size="sm"
          class="underline font-bold text-primary"
        >
          Reintentar
        </BaseButton>
      </div>

      <!-- Empty State -->
      <div
        v-else-if="filteredItems.length === 0"
        class="flex flex-col items-center justify-center py-20 text-center opacity-60"
      >
        <div class="w-20 h-20 bg-slate-100 dark:bg-slate-800 rounded-full flex items-center justify-center mb-4">
          <SearchX :size="40" :stroke-width="1.5" class="text-slate-400" />
        </div>
        <h3 class="text-lg font-bold text-slate-700 dark:text-slate-300">
          {{ searchQuery ? 'Sin resultados' : 'Sin registros' }}
        </h3>
        <p class="text-sm text-slate-500">
          {{ searchQuery ? `No se encontraron resultados para "${searchQuery}"` : 'No hay movimientos en este período.' }}
        </p>
        <BaseButton
          v-if="searchQuery"
          @click="localSearch = ''; searchQuery = ''"
          variant="ghost"
          size="sm"
          class="mt-3 text-primary font-semibold"
        >
          Limpiar búsqueda
        </BaseButton>
      </div>

      <!-- List -->
      <div v-else class="space-y-3 max-w-3xl mx-auto">
        <HistoryItemCard
          v-for="item in filteredItems"
          :key="item.id"
          :item="item"
          @click="handleCardClick"
        />
        
        <!-- Pagination / Load More Hint -->
        <div class="pt-4 text-center">
          <p class="text-xs text-slate-400">
            Mostrando {{ filteredItems.length }} registros
          </p>
        </div>
      </div>
    </main>

    <!-- Sale Detail Modal (T4) -->
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

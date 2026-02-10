<script setup lang="ts">
import { onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useHistory, type HistoryType, type DatePreset } from '../composables/useHistory';
import { useAuthStore } from '../stores/auth';
import HistoryItemCard from '../components/history/HistoryItemCard.vue';
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
  Calendar,
  Users
} from 'lucide-vue-next';

const router = useRouter();
const authStore = useAuthStore();
const { formatCurrency } = useCurrencyFormat();
const { items, isLoading, error, currentType, dateFilter, employeeFilter, summary, fetchHistory } = useHistory();

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

const goBack = () => router.back();

const selectFilter = (type: HistoryType) => {
  fetchHistory(type);
};

const selectDate = (preset: DatePreset) => {
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
</script>

<template>
  <div class="min-h-screen bg-slate-50 dark:bg-[#0f172a] flex flex-col">
    <!-- Header -->
    <header class="sticky top-0 z-30 bg-white dark:bg-[#1e293b] border-b border-slate-100 dark:border-slate-800 shadow-sm">
      <div class="px-4 py-3 flex items-center gap-3">
        <BaseButton @click="goBack" variant="ghost" size="icon" class="-ml-2">
          <ArrowLeft :size="24" :stroke-width="1.5" />
        </BaseButton>
        <h1 class="text-lg font-bold text-slate-900 dark:text-white">
          Historial y Auditoría
        </h1>
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

    <!-- Summary Bar -->
    <div v-if="!isLoading && items.length > 0" class="px-4 pt-3">
      <div class="bg-white dark:bg-slate-800 rounded-xl p-3 border border-slate-100 dark:border-slate-700 flex items-center justify-between">
        <div>
          <p class="text-xs text-slate-400 font-medium uppercase tracking-wider">{{ summary.label }}</p>
          <p class="text-sm text-slate-600 dark:text-slate-300">
            {{ summary.count }} registro{{ summary.count !== 1 ? 's' : '' }}
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
        v-else-if="items.length === 0"
        class="flex flex-col items-center justify-center py-20 text-center opacity-60"
      >
        <div class="w-20 h-20 bg-slate-100 dark:bg-slate-800 rounded-full flex items-center justify-center mb-4">
          <SearchX :size="40" :stroke-width="1.5" class="text-slate-400" />
        </div>
        <h3 class="text-lg font-bold text-slate-700 dark:text-slate-300">
          Sin registros
        </h3>
        <p class="text-sm text-slate-500">
          No hay movimientos en este período.
        </p>
      </div>

      <!-- List -->
      <div v-else class="space-y-3 max-w-3xl mx-auto">
        <HistoryItemCard
          v-for="item in items"
          :key="item.id"
          :item="item"
        />
        
        <!-- Pagination / Load More Hint -->
        <div class="pt-4 text-center">
          <p class="text-xs text-slate-400">
            Mostrando {{ items.length }} registros
          </p>
        </div>
      </div>
    </main>
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

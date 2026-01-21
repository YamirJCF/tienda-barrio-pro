<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useSalesStore } from '../stores/sales';
import { useEmployeesStore } from '../stores/employees';
import BottomNav from '../components/BottomNav.vue';

const router = useRouter();
const salesStore = useSalesStore();
const employeesStore = useEmployeesStore();

// State
type HistoryType = 'ventas' | 'caja' | 'inventario' | 'gastos' | 'creditos' | 'auditoria' | 'precios';
const activeType = ref<HistoryType>('ventas');
const selectedPeriod = ref<'today' | 'week' | 'month'>('today');
const selectedEmployee = ref<string | null>(null);
const isLoading = ref(false);

// History types config
const historyTypes: { id: HistoryType; label: string; icon: string; color: string }[] = [
    { id: 'ventas', label: 'Ventas', icon: 'receipt_long', color: 'emerald' },
    { id: 'caja', label: 'Caja', icon: 'point_of_sale', color: 'blue' },
    { id: 'inventario', label: 'Inventario', icon: 'inventory_2', color: 'orange' },
    { id: 'gastos', label: 'Gastos', icon: 'payments', color: 'red' },
    { id: 'creditos', label: 'Créditos', icon: 'credit_card', color: 'purple' },
    { id: 'auditoria', label: 'Seguridad', icon: 'shield', color: 'slate' },
    { id: 'precios', label: 'Precios', icon: 'sell', color: 'cyan' },
];

// Computed: employees for filter
const employees = computed(() => employeesStore.employees || []);

// Computed: show employee filter for certain types
const showEmployeeFilter = computed(() =>
    ['ventas', 'caja', 'inventario', 'gastos'].includes(activeType.value)
);

// Computed: filtered history items (mock for now)
const historyItems = computed(() => {
    // TODO: Replace with actual data from useHistory composable
    return [];
});

// Methods
const goBack = () => {
    router.push({ path: '/admin', query: { tab: 'reportes' } });
};

const getTypeClass = (type: HistoryType) => {
    const config = historyTypes.find(t => t.id === type);
    if (!config) return '';

    if (activeType.value === type) {
        return `bg-${config.color}-50 dark:bg-${config.color}-900/30 text-${config.color}-700 dark:text-${config.color}-300 ring-1 ring-${config.color}-200 dark:ring-${config.color}-800`;
    }
    return 'text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-slate-700';
};

// Employees are loaded from persisted store automatically
</script>

<template>
    <div
        class="relative flex min-h-screen w-full flex-col overflow-x-hidden pb-20 bg-background-light dark:bg-background-dark">
        <!-- Header -->
        <header
            class="sticky top-0 z-40 bg-background-light/95 dark:bg-background-dark/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-800">
            <div class="flex items-center justify-between px-4 py-3 gap-3">
                <button @click="goBack" aria-label="Volver atrás"
                    class="flex items-center justify-center -ml-2 p-2 rounded-full text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors">
                    <span class="material-symbols-outlined">arrow_back</span>
                </button>
                <h2 class="text-xl font-bold leading-tight tracking-tight flex-1 dark:text-white">Historiales</h2>
            </div>
        </header>

        <!-- Type Filter Chips -->
        <div class="sticky top-[57px] z-30 bg-background-light dark:bg-background-dark px-4 pt-3 pb-2 overflow-x-auto">
            <div class="flex items-center gap-2 hide-scrollbar">
                <button v-for="type in historyTypes" :key="type.id" @click="activeType = type.id"
                    class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-all shrink-0 text-sm font-medium"
                    :class="getTypeClass(type.id)">
                    <span class="material-symbols-outlined text-[18px]">{{ type.icon }}</span>
                    {{ type.label }}
                </button>
            </div>
        </div>

        <!-- Filters Bar -->
        <div class="px-4 py-3 flex flex-wrap gap-3">
            <!-- Period Filter -->
            <div class="flex h-9 items-center rounded-lg bg-slate-100 dark:bg-slate-800 p-0.5">
                <button
                    v-for="period in [{ id: 'today', label: 'Hoy' }, { id: 'week', label: 'Semana' }, { id: 'month', label: 'Mes' }]"
                    :key="period.id" @click="selectedPeriod = period.id as 'today' | 'week' | 'month'"
                    class="px-3 py-1.5 rounded-md text-xs font-medium transition-all" :class="selectedPeriod === period.id
                        ? 'bg-white dark:bg-slate-700 shadow-sm text-primary'
                        : 'text-slate-500 dark:text-slate-400'">
                    {{ period.label }}
                </button>
            </div>

            <!-- Employee Filter -->
            <select v-if="showEmployeeFilter" v-model="selectedEmployee"
                class="h-9 px-3 rounded-lg bg-slate-100 dark:bg-slate-800 text-sm font-medium text-slate-700 dark:text-slate-300 border-0 focus:ring-2 focus:ring-primary">
                <option :value="null">Todos los empleados</option>
                <option v-for="emp in employees" :key="emp.id" :value="emp.id">
                    {{ emp.name }}
                </option>
            </select>
        </div>

        <!-- History List -->
        <main class="flex-1 px-4">
            <!-- Loading State -->
            <div v-if="isLoading" class="flex flex-col gap-3">
                <div v-for="i in 5" :key="i" class="h-20 rounded-xl bg-slate-100 dark:bg-slate-800 animate-pulse"></div>
            </div>

            <!-- Empty State -->
            <div v-else-if="historyItems.length === 0"
                class="flex flex-col items-center justify-center py-16 text-center">
                <div
                    class="h-20 w-20 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center mb-4">
                    <span class="material-symbols-outlined text-4xl text-slate-400">history</span>
                </div>
                <h3 class="text-lg font-semibold text-slate-700 dark:text-slate-300 mb-1">Sin registros</h3>
                <p class="text-sm text-slate-500 dark:text-slate-400 max-w-xs">
                    No hay eventos de {{historyTypes.find(t => t.id === activeType)?.label.toLowerCase()}} en el
                    período seleccionado.
                </p>
            </div>

            <!-- Items List -->
            <div v-else class="flex flex-col gap-3">
                <!-- TODO: Render HistoryItemCard components here -->
            </div>
        </main>

        <BottomNav />
    </div>
</template>

<style scoped>
.hide-scrollbar::-webkit-scrollbar {
    display: none;
}

.hide-scrollbar {
    -ms-overflow-style: none;
    scrollbar-width: none;
}

.material-symbols-outlined {
    font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;
}
</style>

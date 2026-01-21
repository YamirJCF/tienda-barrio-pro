<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useStoreStatusStore } from '../stores/storeStatus';
import { useExpensesStore } from '../stores/expenses';
import { useSalesStore } from '../stores/sales';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useNotifications } from '../composables/useNotifications';
import FormInputCurrency from '../components/ui/FormInputCurrency.vue';

const router = useRouter();
const storeStatus = useStoreStatusStore();
const expensesStore = useExpensesStore();
const salesStore = useSalesStore(); // Para obtener ventas de hoy si fuera necesario, aunque el backend lo hace
const { formatCurrency } = useCurrencyFormat();
const { showSuccess, showError } = useNotifications();

// Computed State
const isOpening = computed(() => !storeStatus.isOperational);
const title = computed(() => isOpening.value ? 'Apertura de Caja' : 'Cierre de Caja');
const buttonText = computed(() => isOpening.value ? 'ABRIR TURNO' : 'CERRAR TURNO');

// Form State
const amount = ref(0);
const pin = ref('');
const notes = ref('');
const isSubmitting = ref(false);

// Closing Data (Summary)
const summary = ref({
    base: 0,
    salesCash: 0,
    expenses: 0,
    expected: 0
});

// Lifecycle
onMounted(async () => {
    if (!isOpening.value) {
        // Prepare Closing Summary
        await expensesStore.fetchTodayExpenses();
        // Here we could fetch sales summary from backend or relying on SalesStore if perfectly synced
        // For robustness, let's rely on SalesStore local totals for responsive UI, 
        // knowing backend will validate on close.
        
        summary.value.base = storeStatus.openingAmount;
        summary.value.salesCash = salesStore.todayCash.toNumber();
        summary.value.expenses = expensesStore.todayTotal.toNumber();
        summary.value.expected = summary.value.base + summary.value.salesCash - summary.value.expenses;
    }
});

// Difference Calculation (Only for Closing)
const difference = computed(() => {
    if (isOpening.value) return 0;
    return amount.value - summary.value.expected;
});

const differenceStatus = computed(() => {
    const diff = difference.value;
    if (Math.abs(diff) < 50) return { color: 'text-emerald-500', icon: 'check_circle', text: 'Caja Cuadrada' };
    if (diff > 0) return { color: 'text-blue-500', icon: 'info', text: 'Sobrante (Excedente)' };
    return { color: 'text-red-500', icon: 'warning', text: 'Faltante (Pérdida)' };
});

const handleSubmit = async () => {
    isSubmitting.value = true;
    try {
        if (isOpening.value) {
            await storeStatus.openStore(amount.value, pin.value);
            showSuccess('Caja abierta correctamente');
            router.push('/'); // Go to POS
        } else {
            const result = await storeStatus.closeStore(amount.value);
            showSuccess('Turno cerrado. Reporte generado.');
            router.push('/'); // Go to Dashboard (which will be in Closed state)
        }
    } catch (e: any) {
        showError(e.message || 'Error en la operación');
    } finally {
        isSubmitting.value = false;
    }
};

const goBack = () => router.back();
</script>

<template>
    <div class="min-h-screen bg-gray-50 dark:bg-gray-900 flex flex-col">
        <!-- Header -->
        <div class="bg-white dark:bg-gray-800 p-4 shadow-sm border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
            <button @click="goBack" class="p-2 -ml-2 rounded-full text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700">
                <span class="material-symbols-outlined">arrow_back</span>
            </button>
            <h1 class="text-lg font-bold text-gray-800 dark:text-gray-100">{{ title }}</h1>
            <div class="w-10"></div> <!-- Spacer -->
        </div>

        <div class="flex-1 p-4 max-w-md mx-auto w-full flex flex-col gap-6">
            
            <!-- Opening State: Simple Form -->
            <div v-if="isOpening" class="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-6 border border-gray-100 dark:border-gray-700 animate-slide-up">
                <div class="text-center mb-6">
                    <div class="bg-emerald-100 dark:bg-emerald-900/30 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-3">
                        <span class="material-symbols-outlined text-3xl text-emerald-600 dark:text-emerald-400">lock_open</span>
                    </div>
                    <p class="text-gray-500 dark:text-gray-400 text-sm">Ingresa el dinero base en caja para iniciar operaciones.</p>
                </div>

                <div class="space-y-4">
                    <div>
                        <label class="block text-xs font-bold uppercase text-gray-400 mb-1">Base Inicial</label>
                        <FormInputCurrency v-model="amount" placeholder="0" class="text-2xl font-bold text-center" />
                    </div>
                </div>
            </div>

            <!-- Closing State: Detailed Summary -->
            <div v-else class="space-y-4 animate-slide-up">
                <!-- Mathematical Summary -->
                <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-4 border border-gray-100 dark:border-gray-700 space-y-3">
                    <h3 class="text-xs font-bold uppercase text-gray-400 tracking-wider mb-2">Resumen del Turno</h3>
                    
                    <div class="flex justify-between items-center text-sm">
                        <span class="text-gray-600 dark:text-gray-300">Base Inicial (+)</span>
                        <span class="font-medium text-gray-800 dark:text-white">{{ formatCurrency(summary.base) }}</span>
                    </div>
                    <div class="flex justify-between items-center text-sm">
                        <span class="text-gray-600 dark:text-gray-300">Ventas Efectivo (+)</span>
                        <span class="font-medium text-emerald-600">{{ formatCurrency(summary.salesCash) }}</span>
                    </div>
                    <div class="flex justify-between items-center text-sm">
                        <span class="text-gray-600 dark:text-gray-300">Gastos/Salidas (-)</span>
                        <span class="font-medium text-red-500">-{{ formatCurrency(summary.expenses) }}</span>
                    </div>
                    <div class="border-t border-gray-100 dark:border-gray-700 pt-2 flex justify-between items-center bg-gray-50 dark:bg-gray-700/30 -mx-4 px-4 py-2 mt-2">
                        <span class="font-bold text-gray-800 dark:text-gray-200">Debe haber en Caja</span>
                        <span class="font-bold text-lg text-gray-900 dark:text-white">{{ formatCurrency(summary.expected) }}</span>
                    </div>
                </div>

                <!-- Counting Input -->
                <div class="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-6 border border-gray-100 dark:border-gray-700">
                     <label class="block text-xs font-bold uppercase text-gray-400 mb-2 text-center">¿Cuánto contaste?</label>
                     <FormInputCurrency v-model="amount" placeholder="0" class="text-3xl font-black text-center text-blue-900 dark:text-blue-100 mb-4" />
                     
                     <!-- Discrepancy Indicator -->
                     <div class="flex items-center justify-center gap-2 p-2 rounded-lg bg-gray-50 dark:bg-gray-700/50 border border-gray-100 dark:border-gray-600">
                         <span class="material-symbols-outlined" :class="differenceStatus.color">{{ differenceStatus.icon }}</span>
                         <span class="font-bold text-sm" :class="differenceStatus.color">{{ differenceStatus.text }}</span>
                         <span v-if="Math.abs(difference) >= 50" class="font-mono text-sm" :class="differenceStatus.color">
                             ({{ formatCurrency(Math.abs(difference)) }})
                         </span>
                     </div>
                </div>
            </div>

            <!-- Action Button -->
            <button 
                @click="handleSubmit" 
                :disabled="isSubmitting"
                class="w-full py-4 rounded-xl font-bold text-white shadow-lg transition-all active:scale-[0.98] disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                :class="isOpening ? 'bg-emerald-600 hover:bg-emerald-700 shadow-emerald-500/30' : 'bg-slate-800 hover:bg-slate-900 shadow-slate-500/30'"
            >
                <span v-if="isSubmitting" class="material-symbols-outlined animate-spin">progress_activity</span>
                <span v-else class="material-symbols-outlined">{{ isOpening ? 'store' : 'lock' }}</span>
                {{ buttonText }}
            </button>

            <!-- Notes field optional -->
            <div v-if="!isOpening" class="text-center">
                 <button class="text-xs text-gray-400 font-medium underline">Agregar nota al reporte</button>
            </div>

        </div>
    </div>
</template>

<style scoped>
.animate-slide-up {
    animation: slideUp 0.4s ease-out;
}
@keyframes slideUp {
    from { opacity: 0; transform: translateY(20px); }
    to { opacity: 1; transform: translateY(0); }
}
</style>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useExpensesStore } from '../stores/expenses';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useNotifications } from '../composables/useNotifications';
import FormInputCurrency from '../components/ui/FormInputCurrency.vue';

const router = useRouter();
const expensesStore = useExpensesStore();
const { formatCurrency } = useCurrencyFormat();
const { showSuccess, showError } = useNotifications();

// State
const showAddModal = ref(false);
const newExpense = ref({
    amount: 0,
    description: '',
    category: 'General'
});

const isSubmitting = ref(false);

const categories = ['General', 'Proveedor', 'Servicios', 'Comida', 'Transporte', 'Mantenimiento'];

// Lifecycle
onMounted(() => {
    expensesStore.fetchTodayExpenses();
});

const sortedExpenses = computed(() => {
    return [...expensesStore.expenses].reverse(); // Newest first
});

const handleSubmit = async () => {
    if (newExpense.value.amount <= 0 || !newExpense.value.description) {
        showError('Completa todos los campos');
        return;
    }

    isSubmitting.value = true;
    try {
        await expensesStore.addExpense({
            amount: newExpense.value.amount,
            description: newExpense.value.description,
            category: newExpense.value.category
        });
        
        showSuccess('Gasto registrado');
        showAddModal.value = false;
        // Reset form
        newExpense.value = { amount: 0, description: '', category: 'General' };
    } catch (e: any) {
        showError(e.message || 'Error al registrar');
    } finally {
        isSubmitting.value = false;
    }
};

const goBack = () => router.push('/');

</script>

<template>
    <div class="bg-gray-50 dark:bg-gray-900 min-h-screen flex flex-col">
        <!-- Header -->
        <div class="bg-white dark:bg-gray-800 p-4 shadow-sm border-b border-gray-200 dark:border-gray-700 flex items-center justify-between sticky top-0 z-10">
            <button @click="goBack" class="p-2 -ml-2 rounded-full text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700">
                <span class="material-symbols-outlined">arrow_back</span>
            </button>
            <h1 class="text-lg font-bold text-gray-800 dark:text-gray-100">Gastos del Día</h1>
            <div class="w-10"></div>
        </div>

        <!-- Summary Card -->
        <div class="p-4 bg-white dark:bg-gray-800 mb-2 shadow-sm">
            <p class="text-xs font-bold uppercase text-gray-400 mb-1">Total Salidas</p>
            <p class="text-3xl font-black text-red-500">{{ formatCurrency(expensesStore.todayTotal) }}</p>
        </div>

        <!-- Expense List -->
        <div class="flex-1 overflow-y-auto p-4 space-y-3">
             <div v-if="expensesStore.isLoading && expensesStore.expenses.length === 0" class="flex justify-center p-8">
                 <span class="material-symbols-outlined animate-spin text-gray-400 text-3xl">progress_activity</span>
             </div>

             <div v-else-if="expensesStore.expenses.length === 0" class="flex flex-col items-center justify-center h-40 text-gray-400">
                 <span class="material-symbols-outlined text-4xl mb-2 opacity-30">receipt_long</span>
                 <p class="text-sm">No hay gastos registrados hoy</p>
             </div>

             <div v-for="expense in sortedExpenses" :key="expense.id" 
                  class="bg-white dark:bg-gray-800 p-4 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700 flex justify-between items-center animate-fade-in">
                 <div>
                     <p class="font-bold text-gray-800 dark:text-gray-200">{{ expense.description }}</p>
                     <span class="text-xs px-2 py-0.5 rounded-full bg-gray-100 dark:bg-gray-700 text-gray-500 font-medium">{{ expense.category }}</span>
                 </div>
                 <span class="font-bold text-red-500">-{{ formatCurrency(expense.amount) }}</span>
             </div>
        </div>

        <!-- FAB Add -->
        <button 
            @click="showAddModal = true"
            class="fixed bottom-6 right-6 w-14 h-14 bg-red-500 hover:bg-red-600 shadow-lg shadow-red-500/30 rounded-full flex items-center justify-center text-white transition-all active:scale-90"
        >
            <span class="material-symbols-outlined text-3xl">add</span>
        </button>

        <!-- Add Modal -->
        <div v-if="showAddModal" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm p-4" @click.self="showAddModal = false">
            <div class="bg-white dark:bg-gray-800 w-full max-w-sm rounded-2xl p-6 shadow-xl animate-slide-up">
                <h2 class="text-lg font-bold mb-4 text-gray-900 dark:text-white">Registrar Salida</h2>
                
                <div class="space-y-4">
                    <div>
                        <label class="block text-xs font-bold uppercase text-gray-400 mb-1">Monto</label>
                        <FormInputCurrency v-model="newExpense.amount" placeholder="0" class="text-2xl font-bold" :autofocus="true" />
                    </div>

                    <div>
                        <label class="block text-xs font-bold uppercase text-gray-400 mb-1">Concepto</label>
                        <input type="text" v-model="newExpense.description" placeholder="Ej. Pago Proveedor Pan" 
                               class="w-full bg-gray-50 dark:bg-gray-700 border-none rounded-lg p-3 text-gray-900 dark:text-white focus:ring-2 focus:ring-red-500" />
                    </div>

                    <div>
                        <label class="block text-xs font-bold uppercase text-gray-400 mb-1">Categoría</label>
                        <div class="flex flex-wrap gap-2">
                            <button v-for="cat in categories" :key="cat"
                                    @click="newExpense.category = cat"
                                    class="px-3 py-1 rounded-full text-xs font-bold border transition-colors"
                                    :class="newExpense.category === cat ? 'bg-red-500 border-red-500 text-white' : 'bg-transparent border-gray-200 dark:border-gray-600 text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-700'">
                                {{ cat }}
                            </button>
                        </div>
                    </div>

                    <button @click="handleSubmit" :disabled="isSubmitting" 
                            class="w-full bg-red-500 hover:bg-red-600 text-white font-bold py-3 rounded-xl mt-4 disabled:opacity-50 flex justify-center">
                        <span v-if="isSubmitting" class="material-symbols-outlined animate-spin">progress_activity</span>
                        <span v-else>GUARDAR SALIDA</span>
                    </button>
                </div>
            </div>
        </div>
    </div>
</template>

<style scoped>
.animate-fade-in { animation: fadeIn 0.3s ease-out; }
.animate-slide-up { animation: slideUp 0.3s ease-out; }
@keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
@keyframes slideUp { from { transform: translateY(100%); } to { transform: translateY(0); } }
</style>

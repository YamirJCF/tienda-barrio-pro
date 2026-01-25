<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useCashRegisterStore } from '../stores/cashRegister';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useNotifications } from '../composables/useNotifications';
import FormInputCurrency from '../components/ui/FormInputCurrency.vue';
import Decimal from 'decimal.js';
import BaseInput from '@/components/ui/BaseInput.vue';
import BaseButton from '@/components/ui/BaseButton.vue';
import { ArrowLeft, Lock, Receipt, Plus } from 'lucide-vue-next';

const router = useRouter();
const cashRegisterStore = useCashRegisterStore(); // Changed from expensesStore
const { formatCurrency } = useCurrencyFormat();
const { showSuccess, showError } = useNotifications();

// State
const showAddModal = ref(false);
const newExpense = ref({
    amount: 0,
    description: '',
    category: 'General'
});

// isSubmitting handled by useAsyncAction

const categories = ['General', 'Proveedor', 'Servicios', 'Comida', 'Transporte', 'Mantenimiento'];

// Computed
const currentExpenses = computed(() => {
    // Get from cash register session
    const transactions = cashRegisterStore.currentSession?.transactions || [];
    return transactions
        .filter(t => t.type === 'expense')
        .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());
});

const totalExpenses = computed(() => cashRegisterStore.totalExpenses);
const isSessionOpen = computed(() => cashRegisterStore.isOpen);

// Composable: Request Management
import { useAsyncAction } from '../composables/useAsyncAction';
const { execute: executeExpense, isLoading: isSubmitting } = useAsyncAction();

const handleSubmit = async () => {
    if (newExpense.value.amount <= 0 || !newExpense.value.description) {
        showError('Completa todos los campos');
        return;
    }

    await executeExpense(async () => {
        cashRegisterStore.registerExpense(
            new Decimal(newExpense.value.amount),
            newExpense.value.description,
            newExpense.value.category
        );
        
        // Success actions within the async flow to ensure they happen only on success
        showAddModal.value = false;
        // Reset form
        newExpense.value = { amount: 0, description: '', category: 'General' };
    }, {
        successMessage: 'Gasto registrado correcto',
        errorMessage: 'Error al registrar el gasto',
        checkConnectivity: false // Offline expenses allowed (sync later)
    });
};

const goBack = () => router.push('/');

</script>

<template>
    <div class="bg-gray-50 dark:bg-gray-900 min-h-screen flex flex-col">
        <!-- Header -->
        <div class="bg-white dark:bg-gray-800 p-4 shadow-sm border-b border-gray-200 dark:border-gray-700 flex items-center justify-between sticky top-0 z-10">
            <button @click="goBack" class="p-2 -ml-2 rounded-xl text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700">
                <ArrowLeft :size="24" :stroke-width="1.5" />
            </button>
            <h1 class="text-lg font-bold text-gray-800 dark:text-gray-100">Gastos del Día</h1>
            <div class="w-10"></div>
        </div>

        <!-- Session Status Warning -->
         <div v-if="!isSessionOpen" class="p-4">
             <div class="bg-amber-50 dark:bg-amber-900/20 text-amber-800 dark:text-amber-200 p-4 rounded-xl flex items-center gap-3">
                <Lock :size="24" />
                <div>
                   <p class="font-bold">Caja Cerrada</p>
                   <p class="text-sm opacity-80">Abre la caja para registrar gastos.</p>
                </div>
             </div>
         </div>

        <!-- Summary Card -->
        <div class="p-4 bg-white dark:bg-gray-800 mb-2 shadow-sm" v-if="isSessionOpen">
            <p class="text-xs font-bold uppercase text-gray-400 mb-1">Total Salidas (Sesión)</p>
            <p class="text-3xl font-black text-red-500">{{ formatCurrency(totalExpenses) }}</p>
        </div>

        <!-- Expense List -->
        <div class="flex-1 overflow-y-auto p-4 space-y-3">
             <div v-if="currentExpenses.length === 0" class="flex flex-col items-center justify-center h-40 text-gray-400">
                 <Receipt :size="48" :stroke-width="1" class="mb-2 opacity-30" />
                 <p class="text-sm">No hay gastos registrados en esta sesión</p>
             </div>

             <div v-for="expense in currentExpenses" :key="expense.id" 
                  class="bg-white dark:bg-gray-800 p-4 rounded-2xl shadow-sm border border-gray-100 dark:border-gray-700 flex justify-between items-center animate-fade-in">
                 <div>
                     <p class="font-bold text-gray-800 dark:text-gray-200">{{ expense.description }}</p>
                     <span class="text-xs px-2 py-0.5 rounded-lg bg-gray-100 dark:bg-gray-700 text-gray-500 font-bold uppercase tracking-wide">{{ expense.category }}</span>
                 </div>
                 <span class="font-bold text-red-500">-{{ formatCurrency(expense.amount) }}</span>
             </div>
        </div>

        <!-- FAB Add -->
        <button 
            v-if="isSessionOpen"
            @click="showAddModal = true"
            class="fixed bottom-6 right-6 w-14 h-14 bg-red-500 hover:bg-red-600 shadow-lg shadow-red-500/30 rounded-2xl flex items-center justify-center text-white transition-all active:scale-90"
        >
            <Plus :size="32" :stroke-width="1.5" />
        </button>

        <!-- Add Modal -->
        <div v-if="showAddModal" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm p-4" @click.self="showAddModal = false">
            <div class="bg-white dark:bg-gray-800 w-full max-w-sm rounded-3xl p-6 shadow-xl animate-slide-up">
                <h2 class="text-lg font-bold mb-4 text-gray-900 dark:text-white">Registrar Salida</h2>
                
                <div class="space-y-4">
                    <div>
                        <label class="block text-xs font-bold uppercase text-gray-400 mb-1">Monto</label>
                        <FormInputCurrency v-model="newExpense.amount" placeholder="0" class="text-2xl font-bold" :autofocus="true" />
                    </div>

                    <div>
                        <BaseInput
                            v-model="newExpense.description"
                            label="Concepto"
                            placeholder="Ej. Pago Proveedor Pan"
                        />
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

                    <BaseButton
                        @click="handleSubmit"
                        :disabled="isSubmitting"
                        :loading="isSubmitting"
                        variant="danger"
                        class="w-full mt-4 flex justify-center !rounded-xl"
                    >
                        GUARDAR SALIDA
                    </BaseButton>
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

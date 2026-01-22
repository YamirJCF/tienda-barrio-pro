<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useCashRegisterStore } from '../stores/cashRegister';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useNotifications } from '../composables/useNotifications';
import FormInputCurrency from '../components/ui/FormInputCurrency.vue';
import Decimal from 'decimal.js';

import { useAuthStore } from '../stores/auth'; // Import auth store
import BaseButton from '@/components/ui/BaseButton.vue';

const router = useRouter();
const cashRegisterStore = useCashRegisterStore(); // Replaced storeStatusStore
const authStore = useAuthStore(); // Initialize auth store
const { formatCurrency } = useCurrencyFormat();
const { showSuccess, showError } = useNotifications();

// Computed State
const isOpening = computed(() => !cashRegisterStore.isOpen);
const title = computed(() => isOpening.value ? 'Apertura de Caja' : 'Cierre de Caja');
const buttonText = computed(() => isOpening.value ? 'ABRIR TURNO' : 'CERRAR TURNO');

// Form State
const amount = ref(0);
const notes = ref('');
const isSubmitting = ref(false);

// Closing Data (Summary)
const summary = computed(() => {
    if (isOpening.value) return { base: 0, salesCash: 0, expenses: 0, expected: 0 };
    
    // We can get these directly from the store computed properties
    return {
        base: cashRegisterStore.currentSession?.openingBalance.toNumber() || 0,
        salesCash: cashRegisterStore.totalIncome.toNumber(),
        expenses: cashRegisterStore.totalExpenses.toNumber(),
        expected: cashRegisterStore.currentBalance.toNumber()
    };
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
            if (authStore.currentUser?.id) {
                cashRegisterStore.openRegister(authStore.currentUser.id, new Decimal(amount.value), notes.value);
            } else {
                 throw new Error('Usuario no autenticado');
            }
            showSuccess('Caja abierta correctamente');
            router.push('/'); // Go to POS
        } else {
            // Closing
            if (!confirm('¿Estás seguro de cerrar el turno?')) {
                isSubmitting.value = false;
                return;
            }
            cashRegisterStore.closeRegister(new Decimal(amount.value), notes.value);
            showSuccess('Turno cerrado. Reporte generado.');
            router.push('/'); // Go to Dashboard/Home
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
                        <FormInputCurrency v-model="amount" placeholder="0" class="text-2xl font-bold text-center" :autofocus="true" />
                    </div>
                    
                     <div>
                        <label class="block text-xs font-bold uppercase text-gray-400 mb-1">Notas (Opcional)</label>
                        <textarea v-model="notes" rows="2" class="w-full p-3 bg-gray-50 dark:bg-gray-700 border-none rounded-lg text-sm" placeholder="Observaciones..."></textarea>
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
                        <span class="text-gray-600 dark:text-gray-300">Ventas/Ingresos (+)</span>
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
                     
                      <div class="mt-4">
                        <label class="block text-xs font-bold uppercase text-gray-400 mb-1">Notas del Cierre</label>
                        <textarea v-model="notes" rows="2" class="w-full p-3 bg-gray-50 dark:bg-gray-700 border-none rounded-lg text-sm" placeholder="Observaciones sobre diferencias..."></textarea>
                    </div>
                </div>
            </div>

            <!-- Action Button -->
            <BaseButton 
                @click="handleSubmit" 
                :loading="isSubmitting"
                :disabled="isSubmitting"
                :variant="isOpening ? 'success' : 'dark'"
                class="w-full h-14 text-lg shadow-lg"
                :class="isOpening ? 'shadow-emerald-500/30' : 'shadow-slate-500/30'"
            >
                <div class="flex items-center gap-2">
                    <span class="material-symbols-outlined">{{ isOpening ? 'store' : 'lock' }}</span>
                    {{ buttonText }}
                </div>
            </BaseButton>

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

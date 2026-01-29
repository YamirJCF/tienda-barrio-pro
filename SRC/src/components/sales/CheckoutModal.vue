<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useAuthStore } from '../../stores/auth';
import type { Client } from '../../stores/clients';
import Decimal from 'decimal.js';
import BaseModal from '../ui/BaseModal.vue';
import {
  Banknote,
  CreditCard,
  User,
  Delete,
  X,
  CheckCircle2,
  Trash2
} from 'lucide-vue-next';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import { useNotifications } from '../../composables/useNotifications';
import type { PaymentTransaction } from '../../types';

interface Props {
  modelValue: boolean;
  total: Decimal;
  allowFiado?: boolean;
  selectedClient?: Client | null;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'complete': [payments: PaymentTransaction[], totalPaid: Decimal];
}>();

const { formatCurrency } = useCurrencyFormat();
const { showWarning } = useNotifications();

// State
const payments = ref<PaymentTransaction[]>([]);
const currentMethod = ref<'cash' | 'nequi' | 'fiado'>('cash');
const inputAmount = ref<string>(''); // String buffer for numpad
const reference = ref<string>('');

// Computed
const totalPaid = computed(() => {
  return payments.value.reduce((sum, p) => sum.plus(p.amount), new Decimal(0));
});

const currentTypedAmount = computed(() => {
    return inputAmount.value ? new Decimal(inputAmount.value) : new Decimal(0);
});

// Total "Put on table" = Previously Added Payments + Current Input
const totalMoneyOnTable = computed(() => {
    return totalPaid.value.plus(currentTypedAmount.value);
});

const remainingBalance = computed(() => {
  const diff = props.total.minus(totalPaid.value);
  return diff.isNegative() ? new Decimal(0) : diff;
});

const change = computed(() => {
  // Change is calculated based on (Registered Payments + Current Input) - Total
  const diff = totalMoneyOnTable.value.minus(props.total);
  return diff.isPositive() ? diff : new Decimal(0);
});

const canComplete = computed(() => {
    // Can complete if Money on Table >= Total
    return totalMoneyOnTable.value.gte(props.total);
});

// Numpad Logic
const handleNum = (char: string) => {
    if (inputAmount.value.length >= 9) return; // Max length limit
    inputAmount.value += char;
};

const handleBackspace = () => {
    inputAmount.value = inputAmount.value.slice(0, -1);
};

const clearInput = () => {
    inputAmount.value = '';
};

// Preset Amounts (e.g. Exact, Next 10k, etc - simplified to just "Exacto" from screenshot)
const setExactAmount = () => {
    // Set input to exactly what is missing
    inputAmount.value = remainingBalance.value.toString();
};

const addCurrentPayment = () => {
    if (!inputAmount.value) return;
    const amount = new Decimal(inputAmount.value);
    
    if (amount.lte(0)) return;

    // Add to payments list
    payments.value.push({
        method: currentMethod.value,
        amount: amount,
        reference: reference.value || undefined
    });

    clearInput();
};

const removePayment = (index: number) => {
    payments.value.splice(index, 1);
};

const confirmTransaction = () => {
    // Strategy: 
    // If we have input in the buffer, consider it as part of the payment (Smart Submit)
    // If buffer is empty, rely on `payments` list.
    
    if (inputAmount.value) {
        addCurrentPayment();
    }
    
    // Recalculate complete status after adding
    const finalTotalPaid = payments.value.reduce((sum, p) => sum.plus(p.amount), new Decimal(0));
    
    if (finalTotalPaid.gte(props.total)) {
        emit('complete', payments.value, finalTotalPaid);
    } else {
        showWarning('El monto es insuficiente');
    }
};

const close = () => {
  emit('update:modelValue', false);
};

// Watchers
watch(() => props.modelValue, (val) => {
  if (val) {
    payments.value = [];
    currentMethod.value = 'cash';
    inputAmount.value = ''; // Start empty, let user type or hit "Exacto"
    reference.value = '';
  }
});

watch(currentMethod, () => {
    reference.value = ''; // Clear reference when switching methods
});
</script>

<template>
  <BaseModal
    :modelValue="modelValue"
    :title="null"
    :max-width="'max-w-4xl'"
    @update:modelValue="close"
    class="checkout-modal"
  >
    <!-- CUSTOM HEADER IS HIDDEN via :title="null" for full control -->
    
    <div class="flex flex-col h-[85vh] md:h-auto overflow-hidden">
        
        <!-- HEADER / TOTAL -->
        <div class="bg-slate-50 dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 p-6 flex flex-col items-center justify-center shrink-0">
            <div class="w-12 h-1 bg-slate-200 rounded-full mb-4"></div> <!-- Handle visual -->
            <h2 class="text-slate-500 font-bold tracking-widest text-sm uppercase mb-1">Total a Pagar</h2>
            <div class="text-5xl font-black text-slate-900 dark:text-white tracking-tighter">
                {{ formatCurrency(total) }}
            </div>
        </div>

        <!-- TABS -->
        <div class="flex border-b border-slate-100 dark:border-slate-800 overflow-x-auto shrink-0">
            <button 
                v-for="method in ['cash', 'nequi', 'fiado']" 
                :key="method"
                @click="currentMethod = method as any"
                class="flex-1 py-4 flex flex-col items-center justify-center gap-1 relative transition-colors"
                :class="currentMethod === method ? 'text-emerald-600 bg-emerald-50 dark:bg-emerald-900/20' : 'text-slate-400 hover:bg-slate-50 dark:hover:bg-slate-800'"
            >
                <Banknote v-if="method === 'cash'" class="mb-1" />
                <CreditCard v-if="method === 'nequi'" class="mb-1" />
                <User v-if="method === 'fiado'" class="mb-1" />
                
                <span class="text-sm font-bold capitalize">{{ method === 'cash' ? 'Efectivo' : method }}</span>
                
                <!-- Active Indicator -->
                <div v-if="currentMethod === method" class="absolute bottom-0 left-0 right-0 h-1 bg-emerald-500 rounded-t-full mx-8"></div>
            </button>
        </div>

        <!-- MAIN LAYOUT: SPLIT INPUT / NUMPAD -->
        <div class="flex-1 flex flex-col md:flex-row bg-white dark:bg-slate-900 min-h-0">
            
            <!-- LEFT: INPUT & INFO -->
            <div class="flex-1 p-6 flex flex-col gap-4 border-r border-slate-100 dark:border-slate-800 overflow-y-auto">
                
                <!-- Dinero Recibido Display -->
                <div>
                   <label class="text-sm font-bold text-slate-500 mb-1 block">Dinero Recibido</label>
                   <div class="relative group cursor-default">
                       <div class="text-4xl font-bold text-slate-900 dark:text-white p-4 border-2 rounded-2xl border-blue-400 bg-blue-50/50 dark:bg-blue-900/10 flex items-center justify-center">
                           <span v-if="!inputAmount && payments.length === 0" class="text-slate-300">$ 0</span>
                           <span v-else>{{ formatCurrency(totalMoneyOnTable) }}</span>
                           <div class="w-1 h-8 bg-blue-500 animate-pulse ml-1"></div> <!-- Fake Cursor -->
                       </div>
                   </div>
                </div>

                <!-- Reference Input (Restored for FRD-007 Compliance) -->
                <div v-if="currentMethod !== 'cash'" class="animate-fade-in">
                    <label class="text-xs font-bold text-slate-400 uppercase mb-1 block">
                        {{ currentMethod === 'nequi' ? 'Referencia / # Celular' : 'Nota de Fiado' }}
                    </label>
                    <input 
                        v-model="reference"
                        type="text"
                        placeholder="Opcional..."
                        class="w-full p-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                    />
                </div>

                <!-- Vueltos Display -->
                <div class="bg-emerald-50 dark:bg-emerald-900/10 p-4 rounded-2xl border border-emerald-100 dark:border-emerald-900/30 flex flex-col items-center justify-center">
                    <span class="text-emerald-600 dark:text-emerald-400 font-bold text-xs uppercase tracking-widest">Vueltos a Dar</span>
                    <span class="text-3xl font-black text-emerald-600 dark:text-emerald-400">{{ formatCurrency(change) }}</span>
                </div>

                <!-- Payments List (If mixed) -->
                <div v-if="payments.length > 0" class="mt-2 space-y-2">
                    <p class="text-xs font-bold text-slate-400 uppercase">Pagos Parciales</p>
                    <div v-for="(p, i) in payments" :key="i" class="flex justify-between items-center text-sm p-2 bg-slate-50 dark:bg-slate-800 rounded-lg">
                        <span class="capitalize font-medium text-slate-700 dark:text-slate-300">{{ p.method }}</span>
                        <div class="flex items-center gap-2">
                            <span>{{ formatCurrency(p.amount) }}</span>
                            <button @click="removePayment(i)" class="text-red-400"><X :size="14" /></button>
                        </div>
                    </div>
                </div>

            </div>

            <!-- RIGHT: NUMPAD -->
            <div class="w-full md:w-[400px] bg-slate-50 dark:bg-slate-900 p-6 grid grid-cols-3 gap-3 shrink-0">
                <button v-for="n in [1,2,3,4,5,6,7,8,9]" :key="n" @click="handleNum(n.toString())"
                    class="h-16 rounded-2xl bg-white dark:bg-slate-800 shadow-sm border border-slate-200 dark:border-slate-700 text-2xl font-bold text-slate-700 dark:text-slate-200 hover:bg-slate-100 active:scale-95 transition-all">
                    {{ n }}
                </button>
                
                <button @click="handleNum('000')" class="h-16 rounded-2xl bg-slate-200 dark:bg-slate-700 text-xl font-bold text-slate-600 dark:text-slate-300 hover:bg-slate-300">000</button>
                <button @click="handleNum('0')" class="h-16 rounded-2xl bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-2xl font-bold text-slate-700 dark:text-slate-200">0</button>
                <button @click="handleBackspace" class="h-16 rounded-2xl bg-red-100 dark:bg-red-900/30 text-red-500 hover:bg-red-200 flex items-center justify-center">
                    <Delete :size="28" />
                </button>
            </div>
        </div>

        <!-- FOOTER ACTIONS -->
        <div class="p-6 pt-2 bg-white dark:bg-slate-900 flex flex-col gap-4 border-t border-slate-100 dark:border-slate-800">
            <!-- Shortcuts -->
            <div class="flex justify-center">
                <button @click="setExactAmount" class="px-6 py-2 rounded-full border border-dashed border-slate-300 text-slate-500 text-sm hover:bg-slate-50 hover:border-slate-400 active:scale-95 transition-all">
                    Usar monto exacto
                </button>
            </div>

            <!-- Big Main Button -->
            <button 
                @click="confirmTransaction"
                :disabled="!canComplete"
                class="w-full h-16 bg-emerald-600 hover:bg-emerald-500 disabled:bg-slate-200 disabled:text-slate-400 text-white rounded-2xl flex items-center justify-between px-8 shadow-xl shadow-emerald-500/20 active:scale-[0.98] transition-all"
            >
                <span class="text-lg font-medium">Completar Venta</span>
                
                <div class="flex items-center gap-3">
                    <div class="text-right">
                        <div class="text-xs uppercase opacity-80">Confirmar</div>
                        <div class="text-xl font-black leading-none" v-if="change.gt(0)">Vueltos: {{ formatCurrency(change) }}</div>
                        <div class="text-xl font-black leading-none" v-else>Exacto</div>
                    </div>
                    <div class="w-10 h-10 bg-white/20 rounded-full flex items-center justify-center">
                        <CheckCircle2 :size="24" />
                    </div>
                </div>
            </button>
        </div>

    </div>
  </BaseModal>
</template>

<style scoped>
/* Override BaseModal padding if needed via class */
.checkout-modal :deep(.relative) {
    /* Ensure modal content fits screen in mobile */
    max-height: 100dvh;
}
</style>

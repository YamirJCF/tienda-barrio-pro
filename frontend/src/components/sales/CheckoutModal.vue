<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useAuthStore } from '../../stores/auth';
import type { Client } from '../../types';
import Decimal from 'decimal.js';
import UIBaseModal from '@/components/ui/BaseModal.vue';
import {
  Banknote,
  CreditCard,
  User,
  Delete,
  X,
  CheckCircle2,
  Trash2,
  Search,
  UserPlus,
  QrCode,
  Smartphone
} from 'lucide-vue-next';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import { useNotifications } from '../../composables/useNotifications';
import { useClientsStore } from '../../stores/clients';
import { useConfigStore } from '../../stores/config'; // Import Config Store
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
  'complete': [payments: PaymentTransaction[], totalPaid: Decimal, clientId?: string];
}>();

const { formatCurrency } = useCurrencyFormat();
const { showWarning } = useNotifications();
const clientsStore = useClientsStore();
const configStore = useConfigStore(); // Use Config Store

// State
const payments = ref<PaymentTransaction[]>([]);
const currentMethod = ref<string>('cash'); // Default start, updated via watcher
const inputAmount = ref<string>('');
const reference = ref<string>('');
const clientSearch = ref('');
const selectedFiadoClient = ref<Client | null>(null);

// Computed: Dynamic Methods
const activeMethods = computed(() => configStore.activePaymentMethods);

const currentPaymentMethod = computed(() => {
    return activeMethods.value.find(m => m.code === currentMethod.value);
});

// Capabilities
const allowsChange = computed(() => currentPaymentMethod.value?.allowsChange ?? false);
const requiresReference = computed(() => currentPaymentMethod.value?.requiresReference ?? false);
const isFiado = computed(() => currentMethod.value === 'fiado'); // Special Business Logic
const isNequi = computed(() => currentMethod.value === 'nequi'); // Special UI Logic (QR)

// Total Calculations
const totalPaid = computed(() => {
  return payments.value.reduce((sum, p) => sum.plus(p.amount), new Decimal(0));
});

const currentTypedAmount = computed(() => {
    return inputAmount.value ? new Decimal(inputAmount.value) : new Decimal(0);
});

const totalMoneyOnTable = computed(() => {
    return totalPaid.value.plus(currentTypedAmount.value);
});

const remainingBalance = computed(() => {
  const diff = props.total.minus(totalPaid.value);
  return diff.isNegative() ? new Decimal(0) : diff;
});

const change = computed(() => {
  // Only calculate change if method allows it (Cash)
  if (!allowsChange.value) return new Decimal(0);
  
  const diff = totalMoneyOnTable.value.minus(props.total);
  return diff.isPositive() ? diff : new Decimal(0);
});

const canComplete = computed(() => {
    if (isFiado.value) {
        return !!selectedFiadoClient.value;
    }
    return totalMoneyOnTable.value.gte(props.total);
});

const filteredClients = computed(() => {
    return clientsStore.searchClients(clientSearch.value);
});

// Helpers
const getIconForMethod = (code: string) => {
    switch (code) {
        case 'cash': return Banknote;
        case 'nequi': return Smartphone;
        case 'fiado': return User;
        case 'card': return CreditCard;
        default: return Banknote;
    }
};

// Numpad Logic
const handleNum = (char: string) => {
    if (inputAmount.value.length >= 9) return; 
    inputAmount.value += char;
};

const handleBackspace = () => {
    inputAmount.value = inputAmount.value.slice(0, -1);
};

const clearInput = () => {
    inputAmount.value = '';
};

const setExactAmount = () => {
    inputAmount.value = remainingBalance.value.toString();
};

const addCurrentPayment = () => {
    if (!inputAmount.value) return;
    const amount = new Decimal(inputAmount.value);
    
    if (amount.lte(0)) return;

    // WO-CLEANUP: Enforce Single Payment Mode (Backend V2 limitation)
    payments.value = [{
        method: currentMethod.value,
        amount: amount,
        reference: reference.value || undefined
    }];

    clearInput();
};

const removePayment = (index: number) => {
    payments.value.splice(index, 1);
};

const confirmTransaction = () => {
    if (isFiado.value) {
        if (!selectedFiadoClient.value) {
            showWarning('Debes seleccionar un cliente para fiar.');
            return;
        }
        const amountToCredit = remainingBalance.value.gt(0) ? remainingBalance.value : props.total;
        
        // Single Payment for Fiado
        payments.value = [{
            method: 'fiado',
            amount: amountToCredit,
            reference: reference.value || undefined
        }];

        const finalTotalPaid = amountToCredit;
        emit('complete', payments.value, finalTotalPaid, selectedFiadoClient.value.id);
        return;
    }

    // Logic for Cash/Nequi/Card
    // If user typed an amount, use it as the SINGLE payment
    if (inputAmount.value) {
        // Validation: Must cover total?
        const amount = new Decimal(inputAmount.value);
        if (amount.lt(props.total) && !allowsChange.value) {
            showWarning('Pago parcial no soportado en este modo. Ingrese el monto completo.');
            return;
        }
        addCurrentPayment();
    } else if (payments.value.length === 0) {
        // Implicit Full Payment (e.g. Exact Amount button used or auto-set)
        // If nothing in payments list and no input, assume exact total?
        // Only if exact amount was pre-set.
        // Actually, if inputAmount is empty, check if we have a payment in list?
        // But we just enforced Single Payment overwrites list.
        showWarning('Ingrese el monto recibido.');
        return;
    }
    
    // Recalculate total from the (single) payment
    const finalTotalPaid = payments.value.reduce((sum, p) => sum.plus(p.amount), new Decimal(0));
    
    if (finalTotalPaid.gte(props.total)) {
        emit('complete', payments.value, finalTotalPaid, selectedFiadoClient.value?.id);
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
    currentMethod.value = activeMethods.value.length > 0 ? activeMethods.value[0].code : 'cash';
    inputAmount.value = '';
    reference.value = '';
    clientSearch.value = '';
    selectedFiadoClient.value = props.selectedClient || null;
  }
});

watch(currentMethod, (newMethod) => {
    reference.value = ''; 
    payments.value = []; 
    
    const methodObj = configStore.getMethodByCode(newMethod);
    
    // Auto-set exact amount for non-cash methods (Nequi, Cards)
    if (methodObj && !methodObj.allowsChange && newMethod !== 'fiado') {
        setExactAmount();
    } else if (methodObj && methodObj.allowsChange) {
        inputAmount.value = '';
    }
});
</script>


<template>
  <UIBaseModal
    :modelValue="modelValue"
    :title="null"
    @update:modelValue="close"
    class="checkout-modal"
  >
    <div class="flex flex-col h-[85vh] md:h-auto overflow-hidden">
        
        <!-- HEADER / TOTAL -->
        <div class="bg-slate-50 dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 p-6 flex flex-col items-center justify-center shrink-0">
             <div class="w-12 h-1 bg-slate-200 rounded-full mb-4"></div>
            <h2 class="text-slate-500 font-bold tracking-widest text-sm uppercase mb-1">Total a Pagar</h2>
            <div class="text-5xl font-black text-slate-900 dark:text-white tracking-tighter">
                {{ formatCurrency(total) }}
            </div>
        </div>

        <!-- DYNAMIC TABS -->
        <div class="flex border-b border-slate-100 dark:border-slate-800 overflow-x-auto shrink-0">
            <button 
                v-for="method in activeMethods" 
                :key="method.code"
                @click="currentMethod = method.code"
                class="flex-1 py-4 flex flex-col items-center justify-center gap-1 relative transition-colors min-w-[80px]"
                :class="currentMethod === method.code ? 'text-emerald-600 bg-emerald-50 dark:bg-emerald-900/20' : 'text-slate-400 hover:bg-slate-50 dark:hover:bg-slate-800'"
            >
                <component :is="getIconForMethod(method.code)" class="mb-1" />
                
                <span class="text-sm font-bold capitalize">{{ method.name }}</span>
                
                <div v-if="currentMethod === method.code" class="absolute bottom-0 left-0 right-0 h-1 bg-emerald-500 rounded-t-full mx-8"></div>
            </button>
        </div>

        <!-- MAIN LAYOUT -->
        <div class="flex-1 flex flex-col md:flex-row bg-white dark:bg-slate-900 min-h-0">
            
            <!-- LEFT: INPUT & INFO -->
            <div class="flex-1 p-6 flex flex-col gap-4 border-r border-slate-100 dark:border-slate-800 overflow-y-auto">
                
                <!-- SCENARIO A: Cash-Like (Allows Change) -->
                <div v-if="allowsChange">
                   <label class="text-sm font-bold text-slate-500 mb-1 block">Dinero Recibido</label>
                   <div class="relative group cursor-default">
                       <div class="text-4xl font-bold text-slate-900 dark:text-white p-4 border-2 rounded-2xl border-blue-400 bg-blue-50/50 dark:bg-blue-900/10 flex items-center justify-center">
                           <span v-if="!inputAmount && payments.length === 0" class="text-slate-300">$ 0</span>
                           <span v-else>{{ formatCurrency(totalMoneyOnTable) }}</span>
                           <div class="w-1 h-8 bg-blue-500 animate-pulse ml-1"></div>
                       </div>
                   </div>
                </div>

                <!-- SCENARIO B: Reference-Based (Nequi, Cards) -->
                <div v-else-if="!isFiado">
                   <label class="text-sm font-bold text-slate-500 mb-1 block">Monto a Transferir</label>
                   <div class="relative">
                       <div class="text-4xl font-bold text-pink-600 dark:text-pink-400 p-4 border-2 rounded-2xl border-pink-200 dark:border-pink-900 bg-pink-50 dark:bg-pink-900/10 flex items-center justify-center">
                           {{ formatCurrency(remainingBalance.gt(0) ? remainingBalance : totalMoneyOnTable) }}
                       </div>
                   </div>
                   <p class="text-xs text-center text-slate-400 mt-2">Pago exacto requerido.</p>
                </div>

                <!-- SCENARIO C: Fiado w/ Client -->
                <div v-else class="bg-indigo-50 dark:bg-indigo-900/20 p-4 rounded-xl border border-indigo-100 dark:border-indigo-800">
                    <label class="text-xs font-bold text-indigo-500 uppercase mb-2 block">Cliente Seleccionado</label>
                    <div v-if="selectedFiadoClient" class="flex items-center gap-3">
                        <div class="w-10 h-10 rounded-full bg-indigo-200 dark:bg-indigo-700 flex items-center justify-center text-indigo-700 dark:text-white font-bold">
                            {{ selectedFiadoClient.name.substring(0,2).toUpperCase() }}
                        </div>
                        <div>
                            <div class="font-bold text-slate-900 dark:text-white text-lg">{{ selectedFiadoClient.name }}</div>
                            <div class="text-xs text-slate-500">Cupo: {{ formatCurrency(selectedFiadoClient.creditLimit) }}</div>
                        </div>
                        <button @click="selectedFiadoClient = null" class="ml-auto text-slate-400 hover:text-red-500">
                            <X :size="20" />
                        </button>
                    </div>
                    <div v-else class="text-center py-4 text-slate-400 italic text-sm">
                        Selecciona un cliente de la lista
                    </div>
                </div>

                <!-- REFERENCE INPUT (Dynamic) -->
                <div v-if="requiresReference || isFiado" class="animate-fade-in mt-1">
                    <label class="text-xs font-bold text-slate-400 uppercase mb-1 block">
                        {{ isFiado ? 'Nota de Fiado' : 'Referencia / Comprobante (Opcional)' }}
                    </label>
                    <input 
                        v-model="reference"
                        :type="isNequi ? 'number' : 'text'"
                        :placeholder="isFiado ? 'Ej: Paga quincena...' : 'Últimos 4 dígitos'"
                        class="w-full p-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                    />
                </div>

                <!-- VUELTOS (Dynamic) -->
                <div v-if="allowsChange" class="bg-emerald-50 dark:bg-emerald-900/10 p-4 rounded-2xl border border-emerald-100 dark:border-emerald-900/30 flex flex-col items-center justify-center mt-2">
                    <span class="text-emerald-600 dark:text-emerald-400 font-bold text-xs uppercase tracking-widest">Vueltos a Dar</span>
                    <span class="text-3xl font-black text-emerald-600 dark:text-emerald-400">{{ formatCurrency(change) }}</span>
                </div>

                <!-- PAYMENTS LIST -->
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

            <!-- RIGHT PANELS -->
            <div class="w-full md:w-[400px] bg-slate-50 dark:bg-slate-900 p-6 shrink-0 flex flex-col">
                
                <!-- SCENARIO A: NUMPAD (If Method Allows Change or Input) -->
                <div v-if="allowsChange" class="grid grid-cols-3 gap-3 h-full">
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

                <!-- SCENARIO B: NEQUI/DIGITAL Specific UI -->
                <div v-else-if="isNequi" class="flex flex-col h-full items-center justify-center text-center p-4">
                    <div class="w-32 h-32 bg-pink-100 dark:bg-pink-900/20 rounded-3xl flex items-center justify-center mb-6 animate-bounce-in">
                        <QrCode :size="64" class="text-pink-600 dark:text-pink-400" />
                    </div>
                    <h3 class="text-xl font-bold text-slate-900 dark:text-white mb-2">Pago Digital</h3>
                    <p class="text-slate-500 dark:text-slate-400 text-sm leading-relaxed max-w-[240px]">
                        Nequi o Daviplata. Verifica el comprobante.
                    </p>
                    <div class="mt-6 p-3 bg-white dark:bg-slate-800 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm w-full">
                         <div class="text-xs uppercase text-slate-400 font-bold mb-1">Monto Exacto</div>
                         <div class="text-2xl font-black text-slate-900 dark:text-white">
                             {{ formatCurrency(remainingBalance.gt(0) ? remainingBalance : totalMoneyOnTable) }}
                         </div>
                    </div>
                </div>

                <!-- SCENARIO C: CLIENT SEARCH (Fiado) -->
                <div v-else-if="isFiado" class="flex flex-col h-full gap-3">
                    <div class="relative">
                        <Search :size="20" class="absolute left-3 top-3 text-slate-400" />
                        <input 
                            v-model="clientSearch"
                            type="text" 
                            placeholder="Buscar cliente..."
                            class="w-full pl-10 pr-4 py-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 outline-none focus:ring-2 focus:ring-indigo-500"
                        />
                    </div>
                    <div class="flex-1 overflow-y-auto min-h-0 space-y-2 pr-1">
                        <button 
                            v-for="client in filteredClients" 
                            :key="client.id"
                            @click="selectedFiadoClient = client"
                            class="w-full p-3 rounded-xl border flex items-center gap-3 transition-all text-left"
                            :class="selectedFiadoClient?.id === client.id ? 'bg-indigo-600 border-indigo-600 text-white' : 'bg-white dark:bg-slate-800 border-slate-100 hover:border-indigo-300'"
                        >
                            <div class="w-10 h-10 rounded-full flex items-center justify-center font-bold shrink-0 bg-slate-100 text-slate-600">
                                {{ client.name.substring(0,2).toUpperCase() }}
                            </div>
                            <div class="min-w-0">
                                <div class="font-bold truncate">{{ client.name }}</div>
                            </div>
                        </button>
                    </div>
                </div>
                
                 <!-- SCENARIO D: Generic Info (Card, etc) -->
                 <div v-else class="flex flex-col h-full items-center justify-center text-center p-4">
                    <CreditCard :size="64" class="text-slate-300 mb-4" />
                    <p class="text-slate-500">Procesar pago por {{ currentPaymentMethod?.name }}</p>
                    <div class="mt-6 p-3 bg-white dark:bg-slate-800 rounded-xl border shadow-sm w-full">
                         <div class="text-xs uppercase text-slate-400 font-bold mb-1">Monto Exacto</div>
                         <div class="text-2xl font-black text-slate-900 dark:text-white">
                             {{ formatCurrency(remainingBalance.gt(0) ? remainingBalance : totalMoneyOnTable) }}
                         </div>
                    </div>
                 </div>

            </div>
        </div>

        <!-- FOOTER -->
        <div class="p-6 pt-2 bg-white dark:bg-slate-900 flex flex-col gap-4 border-t border-slate-100 dark:border-slate-800">
            <div class="flex justify-center" v-if="allowsChange">
                <button @click="setExactAmount" class="px-6 py-2 rounded-full border border-dashed text-slate-500 text-sm hover:bg-slate-50">
                    Usar monto exacto
                </button>
            </div>

            <button 
                @click="confirmTransaction"
                :disabled="!canComplete && !isFiado"
                class="w-full h-16 bg-emerald-600 hover:bg-emerald-50 disabled:bg-slate-200 disabled:text-slate-400 text-white rounded-2xl flex items-center justify-between px-8 shadow-xl shadow-emerald-500/20 active:scale-[0.98] transition-all"
            >
                <span class="text-lg font-medium">Completar Venta</span>
                <div class="flex items-center gap-3">
                    <div class="text-right">
                        <div class="text-xs uppercase opacity-80">Confirmar</div>
                        <div class="text-xl font-black leading-none" v-if="isFiado">Fiado</div>
                        <div class="text-xl font-black leading-none" v-else-if="change.gt(0)">Vueltos: {{ formatCurrency(change) }}</div>
                        <div class="text-xl font-black leading-none" v-else>Exacto</div>
                    </div>
                    <CheckCircle2 :size="24" />
                </div>
            </button>
        </div>

    </div>
  </UIBaseModal>
</template>
<style scoped>
/* Override BaseModal padding if needed via class */
.checkout-modal :deep(.relative) {
    /* Ensure modal content fits screen in mobile */
    max-height: 100dvh;
}
</style>

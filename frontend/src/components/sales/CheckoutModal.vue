<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useAuthStore } from '../../stores/auth';
import type { Client } from '../../types';
import Decimal from 'decimal.js';
import UIBaseModal from '@/components/ui/BaseModal.vue';
import ClientSearchModal from './ClientSearchModal.vue';
import {
  Banknote,
  CreditCard,
  User,
  Delete,
  X,
  CheckCircle2,
  Search,
  QrCode,
  Smartphone,
  Users,
  UserPlus,
  AlertTriangle
} from 'lucide-vue-next';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import { useNotifications } from '../../composables/useNotifications';
import { useClientsStore } from '../../stores/clients';
import { useConfigStore } from '../../stores/config'; // Import Config Store
import type { PaymentTransaction } from '../../types';

interface Props {
  modelValue: boolean;
  total: Decimal;
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
const showClientSearchModal = ref(false);

const isCreditLimitExceeded = computed(() => {
  if (!selectedFiadoClient.value || !selectedFiadoClient.value.creditLimit) return false;
  const currentDebt = selectedFiadoClient.value.totalDebt || new Decimal(0);
  return currentDebt.plus(props.total).gt(selectedFiadoClient.value.creditLimit);
});

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
watch(() => props.modelValue, async (val) => {
  if (val) {
    payments.value = [];
    currentMethod.value = activeMethods.value.length > 0 ? activeMethods.value[0].code : 'cash';
    inputAmount.value = '';
    reference.value = '';
    clientSearch.value = '';
    selectedFiadoClient.value = props.selectedClient || null;

    // Carga bajo demanda no bloqueante de clientes para el flujo de Fiado/Crédito (SWR Nivel 2)
    const authStore = useAuthStore();
    const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
    if (storeId && clientsStore.clients.length === 0) {
      clientsStore.initialize(storeId);
    }
  }
});

watch(() => props.selectedClient, (client) => {
  if (client !== undefined) {
    selectedFiadoClient.value = client;
  }
}, { immediate: true });

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
    <div class="flex flex-col h-[85vh] md:h-[75vh] max-h-[800px] overflow-hidden">
        
        <!-- 1. HEADER (Total Summary) -->
        <header class="flex flex-col items-center justify-center py-4 bg-gray-50 dark:bg-background-dark border-b border-gray-100 dark:border-gray-800 shrink-0">
            <h3 class="text-gray-500 dark:text-gray-400 text-sm font-semibold tracking-wide uppercase mb-1">Total a Pagar</h3>
            <div class="flex items-baseline gap-1">
                <span class="text-3xl font-bold text-gray-800 dark:text-white">$</span>
                <span class="text-4xl font-black text-gray-900 dark:text-primary tracking-tight">{{ formatCurrency(total) }}</span>
            </div>
        </header>

        <!-- 2. Payment Method Tabs (Dynamic) -->
        <div class="grid w-full border-b border-gray-200 dark:border-gray-700 bg-white dark:bg-surface-dark shrink-0"
             :style="{ gridTemplateColumns: `repeat(${activeMethods.length}, 1fr)` }">
            <button 
                v-for="method in activeMethods" 
                :key="method.code"
                @click="currentMethod = method.code"
                class="relative flex flex-col items-center justify-center py-3 gap-1 group transition-opacity"
                :class="currentMethod === method.code 
                    ? '' 
                    : 'opacity-60 hover:opacity-100'"
            >
                <component 
                    :is="getIconForMethod(method.code)" 
                    :size="28"
                    :class="currentMethod === method.code 
                        ? 'text-emerald-600 dark:text-primary' 
                        : 'text-gray-400 dark:text-gray-500'" 
                />
                <span 
                    class="text-xs font-bold tracking-wide capitalize"
                    :class="currentMethod === method.code 
                        ? 'text-emerald-800 dark:text-emerald-100' 
                        : 'text-gray-500 dark:text-gray-400'"
                >{{ method.name }}</span>
                <!-- Active Indicator -->
                <div v-if="currentMethod === method.code" class="absolute bottom-0 w-full h-[4px] bg-emerald-500 dark:bg-primary rounded-t-full"></div>
                <div v-if="currentMethod === method.code" class="absolute inset-0 bg-emerald-50/50 dark:bg-primary/5"></div>
            </button>
        </div>

        <!-- 3. Dynamic Body Content -->
        <main class="flex-1 overflow-y-auto p-4 flex flex-col">
            
            <!-- Scenario A: Efectivo (Cash-Like) -->
            <div v-if="allowsChange" class="flex flex-1 flex-col gap-4 h-full">
                <div class="flex flex-col md:grid md:grid-cols-12 gap-4 flex-1 h-full">
                    
                    <!-- Left Column: Input & Feedback (Mobile: Row 1 Side-by-Side | Desktop: Col 1 Stacked) -->
                    <div class="w-full md:col-span-5 flex flex-row md:flex-col gap-3 md:justify-center items-start bg-white dark:bg-transparent rounded-xl md:rounded-none p-1 md:p-0">
                        <!-- Input Display Box -->
                        <div class="flex-1 w-full">
                            <span class="text-gray-500 dark:text-gray-400 text-[10px] md:text-sm font-bold mb-1.5 block ml-1 uppercase tracking-wide truncate">Dinero Recibido</span>
                            <div class="relative flex items-center w-full h-14 md:h-16 px-3 bg-white dark:bg-background-dark border-[3px] border-sky-500 rounded-xl shadow-sm ring-2 md:ring-4 ring-sky-100 dark:ring-sky-900/20 transition-all">
                                <span class="text-gray-400 text-lg md:text-xl font-bold mr-1">$</span>
                                <span v-if="!inputAmount && payments.length === 0" class="text-xl md:text-2xl font-bold text-gray-300 truncate">0</span>
                                <span v-else class="text-xl md:text-2xl font-bold text-gray-900 dark:text-white truncate">{{ formatCurrency(totalMoneyOnTable) }}</span>
                                <span class="absolute right-3 w-1.5 h-5 md:w-2 md:h-6 bg-sky-500 animate-pulse rounded-full"></span>
                            </div>
                        </div>

                        <!-- Feedback Box (Calculated Change) -->
                        <div class="flex-1 w-full flex flex-col">
                            <span class="text-emerald-600 dark:text-emerald-400 text-[10px] md:text-sm font-bold mb-1.5 block ml-1 uppercase tracking-wide truncate">Vueltos a dar</span>
                            <div class="h-14 md:h-16 w-full bg-emerald-100 dark:bg-emerald-900/30 border border-emerald-200 dark:border-emerald-800 rounded-xl px-3 flex items-center shadow-sm">
                                <span class="text-emerald-700/50 dark:text-emerald-500/50 text-lg md:text-xl font-bold mr-2">$</span>
                                <span class="text-xl md:text-2xl font-black text-emerald-800 dark:text-emerald-300 truncate">{{ formatCurrency(change) }}</span>
                            </div>
                        </div>

                        <!-- DESKTOP ONLY: Quick Action for exact cash -->
                        <button @click="setExactAmount" class="hidden md:block mt-auto py-3 px-4 rounded-xl border border-dashed border-gray-300 dark:border-gray-600 text-gray-500 dark:text-gray-400 text-sm font-medium hover:bg-gray-50 dark:hover:bg-gray-800 hover:text-gray-700 dark:hover:text-gray-200 hover:border-gray-400 transition-all text-center">
                            Usar monto exacto
                        </button>
                    </div>

                    <!-- Right Column: Numpad (Mobile: Row 2 Full Width | Desktop: Col 2) -->
                    <div class="w-full md:col-span-7 md:pl-2 flex flex-col justify-end md:justify-center">
                        <div class="grid grid-cols-3 gap-3 md:gap-2.5 h-auto md:h-full md:max-h-[320px]">
                            <!-- Row 1-3 -->
                            <button v-for="n in [1,2,3,4,5,6,7,8,9]" :key="n" @click="handleNum(n.toString())"
                                class="flex items-center justify-center rounded-xl md:rounded-lg bg-white md:bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white text-3xl md:text-xl font-black shadow-sm border border-gray-100 md:border-transparent active:translate-y-0.5 active:shadow-none transition-all touch-manipulation h-16 md:h-auto">
                                {{ n }}
                            </button>
                            <!-- Row 4 -->
                            <button @click="handleNum('000')" class="flex items-center justify-center rounded-xl md:rounded-lg bg-gray-50 md:bg-gray-200 dark:bg-gray-700 text-gray-900 dark:text-white text-xl md:text-lg font-black shadow-sm border border-gray-100 md:border-transparent active:translate-y-0.5 active:shadow-none transition-all touch-manipulation tracking-tighter h-16 md:h-auto">000</button>
                            <button @click="handleNum('0')" class="flex items-center justify-center rounded-xl md:rounded-lg bg-white md:bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white dark:text-gray-100 text-3xl md:text-xl font-black shadow-sm border border-gray-100 md:border-transparent active:translate-y-0.5 active:shadow-none transition-all touch-manipulation h-16 md:h-auto">0</button>
                            <button @click="handleBackspace" class="flex items-center justify-center rounded-xl md:rounded-lg bg-rose-100 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400 text-xl font-bold shadow-sm active:translate-y-0.5 active:shadow-none transition-all touch-manipulation h-16 md:h-auto">
                                <Delete :size="28" />
                            </button>
                        </div>
                    </div>

                    <!-- MOBILE ONLY: Quick Action for exact cash (Row 3) -->
                    <button @click="setExactAmount" class="md:hidden w-full py-3.5 rounded-full border-2 border-dashed border-gray-300 dark:border-gray-600 text-gray-500 dark:text-gray-400 text-sm font-bold uppercase tracking-wide active:bg-gray-50 dark:active:bg-gray-800 transition-colors">
                        Usar monto exacto
                    </button>

                </div>
            
                <!-- PAYMENTS LIST (inside cash view) -->
                <div v-if="payments.length > 0" class="mt-2 space-y-2">
                    <p class="text-xs font-bold text-gray-400 uppercase">Pagos Parciales</p>
                    <div v-for="(p, i) in payments" :key="i" class="flex justify-between items-center text-sm p-2 bg-gray-50 dark:bg-gray-800 rounded-lg">
                        <span class="capitalize font-medium text-gray-700 dark:text-gray-300">{{ p.method }}</span>
                        <div class="flex items-center gap-2">
                            <span>{{ formatCurrency(p.amount) }}</span>
                            <button @click="removePayment(i)" class="text-red-400"><X :size="14" /></button>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Scenario B: Nequi/Digital -->
            <div v-else-if="isNequi" class="flex flex-col items-center justify-center gap-6 h-full py-8 text-center">
                <div class="w-24 h-24 bg-pink-100 dark:bg-pink-900/20 rounded-full flex items-center justify-center mb-2">
                    <QrCode :size="48" class="text-pink-600 dark:text-pink-400" />
                </div>
                <div>
                    <h4 class="text-lg font-bold text-gray-900 dark:text-white mb-2">Pago con Nequi / Daviplata</h4>
                    <p class="text-gray-500 dark:text-gray-400 max-w-[260px] mx-auto text-sm leading-relaxed">
                        Solicita al cliente el pago exacto de <strong class="text-gray-900 dark:text-white">$ {{ formatCurrency(remainingBalance.gt(0) ? remainingBalance : total) }}</strong>.
                    </p>
                </div>
                <div class="w-full max-w-xs mt-4">
                    <label class="block text-left mb-1 text-xs font-semibold text-gray-500 uppercase">Referencia (Opcional)</label>
                    <input 
                        v-model="reference"
                        type="number"
                        class="w-full h-12 rounded-lg border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-center text-lg font-medium focus:ring-pink-500 focus:border-pink-500" 
                        placeholder="Últimos 4 dígitos"
                    />
                </div>
            </div>

            <!-- Scenario C: Fiado w/ Client Selection (Modal Dedicado) -->
            <div v-else-if="isFiado" class="flex flex-col gap-4">
                <!-- 1. Tarjeta de Cliente Seleccionado O Botón para Seleccionar -->
                <div v-if="selectedFiadoClient" class="bg-indigo-50 dark:bg-indigo-950/30 p-4 rounded-2xl border border-indigo-200 dark:border-indigo-800/60 shadow-sm space-y-3">
                    <div class="flex items-center justify-between">
                        <span class="text-xs font-bold text-indigo-600 dark:text-indigo-400 uppercase tracking-wide">
                            Cliente para Crédito
                        </span>
                        <div class="flex items-center gap-2">
                            <button 
                                @click="showClientSearchModal = true"
                                class="text-xs font-semibold text-indigo-600 hover:text-indigo-700 dark:text-indigo-400 hover:underline flex items-center gap-1"
                            >
                                <Users :size="14" />
                                Cambiar
                            </button>
                            <button 
                                @click="selectedFiadoClient = null"
                                class="text-gray-400 hover:text-red-500 p-1 rounded-lg transition-colors"
                                title="Quitar cliente"
                            >
                                <X :size="16" />
                            </button>
                        </div>
                    </div>

                    <div class="flex items-center gap-3.5">
                        <div class="w-12 h-12 rounded-full bg-indigo-600 text-white flex items-center justify-center font-bold text-base shadow-sm shrink-0">
                            {{ selectedFiadoClient.name.substring(0,2).toUpperCase() }}
                        </div>
                        <div class="min-w-0 flex-1">
                            <div class="font-black text-gray-900 dark:text-white text-lg truncate">
                                {{ selectedFiadoClient.name }}
                            </div>
                            <div class="text-xs text-gray-500 dark:text-gray-400 flex items-center gap-2">
                                <span v-if="selectedFiadoClient.cc">CC: {{ selectedFiadoClient.cc }}</span>
                                <span v-if="selectedFiadoClient.phone">• {{ selectedFiadoClient.phone }}</span>
                            </div>
                        </div>
                    </div>

                    <!-- Métricas Financieras del Cliente -->
                    <div class="grid grid-cols-2 gap-2 pt-2 border-t border-indigo-100 dark:border-indigo-900/50 text-xs">
                        <div>
                            <span class="text-[10px] font-bold text-gray-400 uppercase block">Cupo Límite</span>
                            <span class="font-bold text-emerald-600 dark:text-emerald-400 text-sm">
                                ${{ formatCurrency(selectedFiadoClient.creditLimit) }}
                            </span>
                        </div>
                        <div class="text-right">
                            <span class="text-[10px] font-bold text-gray-400 uppercase block">Deuda Actual</span>
                            <span class="font-bold text-sm" :class="selectedFiadoClient.totalDebt && selectedFiadoClient.totalDebt.gt(0) ? 'text-red-600 dark:text-red-400' : 'text-gray-500'">
                                ${{ formatCurrency(selectedFiadoClient.totalDebt || 0) }}
                            </span>
                        </div>
                    </div>

                    <!-- Advertencia si excede cupo disponible -->
                    <div 
                        v-if="isCreditLimitExceeded"
                        class="p-2.5 rounded-xl bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-800 flex items-center gap-2 text-amber-800 dark:text-amber-300 text-xs font-medium"
                    >
                        <AlertTriangle :size="16" class="shrink-0 text-amber-600" />
                        <span>Esta venta (${{ formatCurrency(total) }}) superará el cupo disponible del cliente.</span>
                    </div>
                </div>

                <!-- Botón Grande de Selección si no hay cliente -->
                <button
                    v-else
                    @click="showClientSearchModal = true"
                    class="w-full p-6 rounded-2xl border-2 border-dashed border-indigo-300 dark:border-indigo-700/80 hover:border-indigo-500 dark:hover:border-indigo-500 bg-indigo-50/50 dark:bg-indigo-950/20 hover:bg-indigo-50 dark:hover:bg-indigo-950/40 flex flex-col items-center justify-center gap-2.5 group transition-all"
                >
                    <div class="w-14 h-14 rounded-full bg-indigo-100 dark:bg-indigo-900/50 text-indigo-600 dark:text-indigo-400 flex items-center justify-center group-hover:scale-110 transition-transform shadow-sm">
                        <UserPlus :size="28" />
                    </div>
                    <div class="text-center">
                        <span class="text-base font-black text-indigo-900 dark:text-indigo-200 block">
                            Seleccionar Cliente de Cartera
                        </span>
                        <span class="text-xs text-gray-500 dark:text-gray-400 block mt-0.5">
                            Toca aquí para buscar por nombre, cédula o teléfono
                        </span>
                    </div>
                </button>

                <!-- 2. Nota de Fiado / Referencia -->
                <div class="space-y-1">
                    <label class="text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wide block">
                        Nota de Fiado (Opcional)
                    </label>
                    <input 
                        v-model="reference"
                        type="text" 
                        placeholder="Ej: Paga quincena, autorizado por dueño..."
                        class="w-full p-3.5 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-indigo-500 outline-none transition-all text-sm font-medium"
                    />
                </div>
            </div>

            <!-- Scenario D: Generic (Card, etc) -->
            <div v-else class="flex flex-col items-center justify-center gap-4 h-full py-8 text-center">
                <component :is="getIconForMethod(currentMethod)" :size="64" class="text-gray-300 dark:text-gray-600 mb-2" />
                <p class="text-gray-500 dark:text-gray-400">Procesar pago por {{ currentPaymentMethod?.name }}</p>
                <div class="w-full max-w-xs mt-4 p-4 bg-white dark:bg-gray-800 rounded-xl border border-gray-100 dark:border-gray-700 shadow-sm">
                    <div class="text-xs uppercase text-gray-400 font-bold mb-1">Monto Exacto</div>
                    <div class="text-2xl font-black text-gray-900 dark:text-white">
                        $ {{ formatCurrency(remainingBalance.gt(0) ? remainingBalance : totalMoneyOnTable) }}
                    </div>
                </div>
                <!-- Reference for cards -->
                <div v-if="requiresReference" class="w-full max-w-xs">
                    <label class="text-xs font-bold text-gray-400 uppercase mb-1 block text-left">Referencia (Opcional)</label>
                    <input 
                        v-model="reference"
                        type="text"
                        placeholder="Últimos 4 dígitos"
                        class="w-full p-3 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 outline-none transition-all"
                    />
                </div>
            </div>

        </main>

        <!-- 4. Footer (Action) -->
        <footer class="p-4 bg-white dark:bg-surface-dark border-t border-gray-100 dark:border-gray-800 shrink-0">
            <button 
                @click="confirmTransaction"
                :disabled="!canComplete && !isFiado"
                class="w-full h-14 bg-emerald-600 hover:bg-emerald-700 active:bg-emerald-800 disabled:bg-gray-100 disabled:text-gray-400 disabled:dark:bg-gray-800 disabled:dark:text-gray-600 rounded-xl shadow-lg shadow-emerald-200 dark:shadow-none flex flex-col items-center justify-center transition-all duration-200"
            >
                <div class="flex flex-col items-center leading-none">
                    <span class="text-emerald-100 text-[10px] font-bold uppercase tracking-wider mb-0.5">Completar Venta</span>
                    <div class="flex items-center gap-2">
                        <span class="text-white text-xl font-black tracking-wide">CONFIRMAR</span>
                        <span v-if="change.gt(0)" class="bg-emerald-800/40 text-emerald-50 text-[10px] px-1.5 py-0.5 rounded font-bold ml-1">
                            ${{ formatCurrency(change) }}
                        </span>
                    </div>
                </div>
            </button>
        </footer>

    </div>
  </UIBaseModal>

  <!-- Sub-modal de Búsqueda de Clientes para Fiado -->
  <ClientSearchModal
    v-model="showClientSearchModal"
    :selectedClientId="selectedFiadoClient?.id"
    :saleTotal="total"
    @select="(client) => selectedFiadoClient = client"
  />
</template>

<style scoped>
/* Override BaseModal content overflow for checkout layout */
.checkout-modal :deep(.relative) {
    max-height: 100dvh;
}
</style>

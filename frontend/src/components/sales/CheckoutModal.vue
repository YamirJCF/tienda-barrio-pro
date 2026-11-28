<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../../stores/auth';
import type { Client } from '../../types';
import Decimal from 'decimal.js';
import UIBaseModal from '@/components/ui/BaseModal.vue';
import {
  Banknote,
  User,
  Delete,
  X,
  Search,
  QrCode,
  Smartphone,
  Users,
  AlertTriangle,
  Loader2,
  UserX,
  ChevronDown,
  ExternalLink,
  WifiOff
} from 'lucide-vue-next';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import { useClientsStore } from '../../stores/clients';
import { useConfigStore } from '../../stores/config'; // Import Config Store
import type { PaymentTransaction } from '../../types';

interface Props {
  modelValue: boolean;
  total: Decimal;
  selectedClient?: Client | null;
  initialMethod?: string;
}

const CLIENTS_PAGE_SIZE = 5;

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'complete': [payments: PaymentTransaction[], totalPaid: Decimal, clientId?: string, beneficiaryEmployeeId?: string];
}>();

const router = useRouter();
const { formatCurrency } = useCurrencyFormat();
const authStore = useAuthStore();
const clientsStore = useClientsStore();
const configStore = useConfigStore(); // Use Config Store

// State
const payments = ref<PaymentTransaction[]>([]);
const currentMethod = ref<string>('cash'); // Default start, updated via watcher
const inputAmount = ref<string>('');
const reference = ref<string>('');
const clientSearch = ref('');
const pagedClients = ref<Client[]>([]);
const totalClientsCount = ref<number>(0);
const isLoadingClientsPage = ref<boolean>(false);
const isLoadingMoreClients = ref<boolean>(false);
const clientsPageError = ref<string | null>(null);
const selectedFiadoClient = ref<Client | null>(null);
const checkoutError = ref<string | null>(null);
const isOnline = ref<boolean>(typeof navigator !== 'undefined' ? navigator.onLine : true);
let activeFetchSeq = 0;
let inFlightQueryKey = '';

const syncOnlineStatus = () => {
  isOnline.value = typeof navigator !== 'undefined' ? navigator.onLine : true;
};

onMounted(() => {
  syncOnlineStatus();
  window.addEventListener('online', syncOnlineStatus);
  window.addEventListener('offline', syncOnlineStatus);
});

onUnmounted(() => {
  window.removeEventListener('online', syncOnlineStatus);
  window.removeEventListener('offline', syncOnlineStatus);
});

// Computed: Dynamic Commercial Methods (Fiado requiere canFiar || isAdmin; Retiro Personal vive en PersonalWithdrawalModal)
const activeMethods = computed(() => {
    const canUseFiado = authStore.canFiar || authStore.isAdmin;
    return configStore.activePaymentMethods
        .filter((m) => m.code !== 'fiado' || canUseFiado)
        .map((m) => ({
            code: m.code,
            name: m.name,
            allowsChange: Boolean(m.allowsChange),
        }));
});

const currentPaymentMethod = computed(() => {
    return activeMethods.value.find(m => m.code === currentMethod.value);
});

// Capabilities
const allowsChange = computed(() => currentPaymentMethod.value?.allowsChange ?? false);
const isFiado = computed(() => currentMethod.value === 'fiado'); // Special Business Logic
const isNequi = computed(() => currentMethod.value === 'nequi' || currentMethod.value === 'llave_bre'); // Canales digitales sin cambio

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

// C1-H1: Ecuación de cupo evaluada sobre el monto real a acreditar (no props.total ciego)
const amountToCredit = computed(() => {
  return remainingBalance.value.gt(0) ? remainingBalance.value : props.total;
});

const selectedClientCreditLimit = computed(() => {
  return selectedFiadoClient.value?.creditLimit || new Decimal(0);
});

const selectedClientCurrentDebt = computed(() => {
  return selectedFiadoClient.value?.totalDebt || new Decimal(0);
});

const projectedClientDebt = computed(() => {
  return selectedClientCurrentDebt.value.plus(amountToCredit.value);
});

const isCreditLimitExceeded = computed(() => {
  if (!selectedFiadoClient.value || !selectedFiadoClient.value.creditLimit) return false;
  return projectedClientDebt.value.gt(selectedFiadoClient.value.creditLimit);
});

const change = computed(() => {
  // Only calculate change if method allows it (Cash)
  if (!allowsChange.value) return new Decimal(0);
  
  const diff = totalMoneyOnTable.value.minus(props.total);
  return diff.isPositive() ? diff : new Decimal(0);
});

const canComplete = computed(() => {
    if (isFiado.value) {
        return (
            Boolean(selectedFiadoClient.value) &&
            !isCreditLimitExceeded.value &&
            isOnline.value &&
            (authStore.canFiar || authStore.isAdmin)
        );
    }
    return totalMoneyOnTable.value.gte(props.total);
});

const displayedClients = computed(() => {
    return pagedClients.value;
});

const remainingClientsCount = computed(() => {
    return Math.max(0, totalClientsCount.value - pagedClients.value.length);
});

const loadClientsPage = async (reset: boolean = false) => {
    const authStore = useAuthStore();
    const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
    if (!storeId) return;

    if (!reset && (isLoadingClientsPage.value || isLoadingMoreClients.value || remainingClientsCount.value <= 0)) {
        return;
    }

    const nextOffset = reset ? 0 : pagedClients.value.length;
    const queryKey = `${storeId}|${nextOffset}|${clientSearch.value}|${reset}`;
    if ((isLoadingClientsPage.value || isLoadingMoreClients.value) && inFlightQueryKey === queryKey) {
        return;
    }

    const seq = ++activeFetchSeq;
    inFlightQueryKey = queryKey;

    if (reset) {
        isLoadingClientsPage.value = true;
        clientsPageError.value = null;
    } else {
        isLoadingMoreClients.value = true;
    }

    try {
        const result = await clientsStore.fetchClientsPage({
            storeId,
            limit: CLIENTS_PAGE_SIZE,
            offset: nextOffset,
            search: clientSearch.value,
            debtFilter: 'all',
        });

        if (seq !== activeFetchSeq) return;

        if (reset) {
            pagedClients.value = result.data;
        } else {
            const existingIds = new Set(pagedClients.value.map((c) => c.id));
            const newItems = result.data.filter((c) => !existingIds.has(c.id));
            pagedClients.value = [...pagedClients.value, ...newItems];
        }
        totalClientsCount.value = result.count;
    } catch (e: any) {
        if (seq !== activeFetchSeq) return;
        clientsPageError.value = e?.message || 'Error al cargar clientes';
    } finally {
        if (seq === activeFetchSeq) {
            isLoadingClientsPage.value = false;
            isLoadingMoreClients.value = false;
            inFlightQueryKey = '';
        }
    }
};

const loadMoreClients = () => {
    loadClientsPage(false);
};

const handleClientListScroll = (event: Event) => {
    const target = event.target as HTMLElement | null;
    if (!target) return;
    if (
        target.scrollHeight > target.clientHeight &&
        target.scrollTop + target.clientHeight >= target.scrollHeight - 24
    ) {
        loadMoreClients();
    }
};

const retryLoadClients = () => {
    loadClientsPage(true);
};

const clearSelectedFiadoClient = () => {
    selectedFiadoClient.value = null;
    if (pagedClients.value.length === 0) {
        loadClientsPage(true);
    }
};

// Helpers
const getIconForMethod = (code: string) => {
    switch (code) {
        case 'cash':
        case 'efectivo':
            return Banknote;
        case 'nequi':
        case 'llave_bre':
            return Smartphone;
        case 'fiado':
            return User;
        default:
            return Banknote;
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
    syncOnlineStatus();
    checkoutError.value = null;

    if (isFiado.value) {
        if (!isOnline.value) {
            checkoutError.value = 'Las ventas fiadas requieren conexión en línea.';
            return;
        }
        if (!authStore.canFiar && !authStore.isAdmin) {
            checkoutError.value = 'No tienes permiso autorizado (canFiar) para registrar ventas fiadas.';
            return;
        }
        if (!selectedFiadoClient.value) {
            checkoutError.value = 'Debes seleccionar un cliente para fiar.';
            return;
        }
        if (isCreditLimitExceeded.value) {
            checkoutError.value = `El monto a fiar ($${formatCurrency(amountToCredit.value)}) supera el cupo disponible del cliente.`;
            return;
        }

        // Single Payment for Fiado
        payments.value = [{
            method: 'fiado',
            amount: amountToCredit.value,
        }];

        const finalTotalPaid = amountToCredit.value;
        emit('complete', payments.value, finalTotalPaid, selectedFiadoClient.value.id);
        return;
    }

    // Logic for Cash/Nequi/Card
    // If user typed an amount, use it as the SINGLE payment
    if (inputAmount.value) {
        // Validation: Must cover total?
        const amount = new Decimal(inputAmount.value);
        if (amount.lt(props.total) && !allowsChange.value) {
            checkoutError.value = 'Pago parcial no soportado en este modo. Ingrese el monto completo.';
            return;
        }
        addCurrentPayment();
    } else if (payments.value.length === 0) {
        checkoutError.value = 'Ingrese el monto recibido.';
        return;
    }
    
    // Recalculate total from the (single) payment
    const finalTotalPaid = payments.value.reduce((sum, p) => sum.plus(p.amount), new Decimal(0));
    
    if (finalTotalPaid.gte(props.total)) {
        // CHK-403 / RN-16: Ventas de contado / no fiadas nunca asocian client_id
        emit('complete', payments.value, finalTotalPaid, undefined);
    } else {
        checkoutError.value = 'El monto recibido es insuficiente para cubrir el total.';
    }
};

const close = () => {
  emit('update:modelValue', false);
};

const goToClientDetail = (clientId: string) => {
  if (!clientId) return;
  close();
  router?.push({ path: `/clients/${clientId}`, query: { from: 'pos' } });
};

// Watchers
watch(clientSearch, () => {
  if (props.modelValue && isFiado.value && !selectedFiadoClient.value) {
    loadClientsPage(true);
  }
});

watch(() => props.modelValue, (val) => {
  if (val) {
    syncOnlineStatus();
    payments.value = [];
    const defaultCode = activeMethods.value.length > 0 ? activeMethods.value[0].code : 'cash';
    const hasRequestedMethod = props.initialMethod && activeMethods.value.some((m) => m.code === props.initialMethod);
    currentMethod.value = hasRequestedMethod ? props.initialMethod! : defaultCode;
    inputAmount.value = '';
    reference.value = '';
    clientSearch.value = '';
    pagedClients.value = [];
    totalClientsCount.value = 0;
    clientsPageError.value = null;
    checkoutError.value = null;
    selectedFiadoClient.value = props.selectedClient || null;

    if (currentMethod.value === 'fiado' && !selectedFiadoClient.value) {
      loadClientsPage(true);
    }
  }
}, { immediate: true });

watch(() => props.selectedClient, (client) => {
  if (client !== undefined) {
    selectedFiadoClient.value = client;
  }
}, { immediate: true });

watch([inputAmount, selectedFiadoClient], () => {
  if (checkoutError.value) {
    checkoutError.value = null;
  }
});

watch(currentMethod, (newMethod) => {
    syncOnlineStatus();
    reference.value = ''; 
    payments.value = []; 
    checkoutError.value = null;

    if (newMethod !== 'fiado') {
        selectedFiadoClient.value = null;
    }
    
    const methodObj = configStore.getMethodByCode(newMethod);
    
    // Auto-set exact amount for non-cash methods (Nequi, Cards)
    if (methodObj && !methodObj.allowsChange && newMethod !== 'fiado') {
        setExactAmount();
    } else if (methodObj && methodObj.allowsChange) {
        inputAmount.value = '';
    }

    if (
        newMethod === 'fiado' &&
        props.modelValue &&
        !selectedFiadoClient.value &&
        pagedClients.value.length === 0
    ) {
        loadClientsPage(true);
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
        <header class="flex flex-col items-center justify-center py-2.5 bg-gray-50 dark:bg-background-dark border-b border-gray-100 dark:border-gray-800 shrink-0">
            <h3 class="text-gray-500 dark:text-gray-400 text-xs font-semibold tracking-wide uppercase mb-0.5">
                Total a Pagar
            </h3>
            <div class="flex items-baseline gap-1">
                <span class="text-2xl md:text-3xl font-bold text-gray-800 dark:text-white">$</span>
                <span class="text-3xl md:text-4xl font-black font-mono tabular-nums text-gray-900 dark:text-primary tracking-tight">
                    {{ formatCurrency(total) }}
                </span>
            </div>
        </header>

        <!-- 2. Payment Method Tabs (Dynamic) -->
        <div class="grid w-full border-b border-gray-200 dark:border-gray-700 bg-white dark:bg-surface-dark shrink-0"
             :style="{ gridTemplateColumns: `repeat(${activeMethods.length}, 1fr)` }">
            <button 
                v-for="method in activeMethods" 
                :key="method.code"
                @click="currentMethod = method.code"
                class="relative flex flex-col items-center justify-center py-2 gap-1 group transition-opacity"
                :class="currentMethod === method.code 
                    ? '' 
                    : 'opacity-60 hover:opacity-100'"
            >
                <component 
                    :is="getIconForMethod(method.code)" 
                    :size="22"
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
        <main class="flex-1 overflow-y-auto p-3 min-h-0 flex flex-col">
            
            <!-- Scenario A: Efectivo (Cash-Like) -->
            <div v-if="allowsChange" class="flex flex-1 flex-col gap-3 min-h-0">
                <div class="flex flex-col md:grid md:grid-cols-12 gap-3 flex-1 min-h-0">
                    
                    <!-- Left Column: Input & Feedback (Mobile: Row 1 Side-by-Side | Desktop: Col 1 Stacked) -->
                    <div class="w-full md:col-span-5 flex flex-row md:flex-col gap-2.5 md:justify-center items-start bg-white dark:bg-transparent rounded-xl md:rounded-none shrink-0">
                        <!-- Input Display Box -->
                        <div class="flex-1 w-full">
                            <span class="text-gray-500 dark:text-gray-400 text-[10px] md:text-sm font-bold mb-1 block ml-1 uppercase tracking-wide truncate">Dinero Recibido</span>
                            <div class="relative flex items-center w-full h-[52px] md:h-14 px-3 bg-white dark:bg-background-dark border-[3px] border-sky-500 rounded-xl shadow-sm ring-2 md:ring-4 ring-sky-100 dark:ring-sky-900/20 transition-all">
                                <span class="text-gray-400 text-lg md:text-xl font-bold mr-1">$</span>
                                <span v-if="!inputAmount && payments.length === 0" class="text-xl md:text-2xl font-bold text-gray-300 truncate">0</span>
                                <span v-else class="text-xl md:text-2xl font-bold text-gray-900 dark:text-white truncate">{{ formatCurrency(totalMoneyOnTable) }}</span>
                                <span class="absolute right-3 w-1.5 h-5 md:w-2 md:h-6 bg-sky-500 animate-pulse rounded-full"></span>
                            </div>
                        </div>

                        <!-- Feedback Box (Calculated Change) -->
                        <div class="flex-1 w-full flex flex-col">
                            <span class="text-emerald-600 dark:text-emerald-400 text-[10px] md:text-sm font-bold mb-1 block ml-1 uppercase tracking-wide truncate">Vueltos a dar</span>
                            <div class="h-[52px] md:h-14 w-full bg-emerald-100 dark:bg-emerald-900/30 border border-emerald-200 dark:border-emerald-800 rounded-xl px-3 flex items-center shadow-sm">
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
                    <div class="w-full md:col-span-7 md:pl-2 flex flex-col flex-1 min-h-0 md:justify-center">
                        <div class="grid grid-cols-3 grid-rows-4 gap-2.5 flex-1 min-h-0 md:max-h-[320px]">
                            <!-- Row 1-3 -->
                            <button v-for="n in [1,2,3,4,5,6,7,8,9]" :key="n" @click="handleNum(n.toString())"
                                class="flex items-center justify-center rounded-xl md:rounded-lg bg-white md:bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white text-2xl md:text-xl font-black shadow-sm border border-gray-100 md:border-transparent active:translate-y-0.5 active:shadow-none transition-all touch-manipulation h-full min-h-[42px]">
                                {{ n }}
                            </button>
                            <!-- Row 4 -->
                            <button @click="handleNum('000')" class="flex items-center justify-center rounded-xl md:rounded-lg bg-gray-50 md:bg-gray-200 dark:bg-gray-700 text-gray-900 dark:text-white text-xl font-black shadow-sm border border-gray-100 md:border-transparent active:translate-y-0.5 active:shadow-none transition-all touch-manipulation tracking-tighter h-full min-h-[42px]">000</button>
                            <button @click="handleNum('0')" class="flex items-center justify-center rounded-xl md:rounded-lg bg-white md:bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white dark:text-gray-100 text-2xl md:text-xl font-black shadow-sm border border-gray-100 md:border-transparent active:translate-y-0.5 active:shadow-none transition-all touch-manipulation h-full min-h-[42px]">0</button>
                            <button @click="handleBackspace" class="flex items-center justify-center rounded-xl md:rounded-lg bg-rose-100 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400 text-xl font-black shadow-sm active:translate-y-0.5 active:shadow-none transition-all touch-manipulation h-full min-h-[42px]">
                                <Delete :size="24" />
                            </button>
                        </div>
                    </div>

                    <!-- MOBILE ONLY: Quick Action for exact cash (Row 3) -->
                    <button @click="setExactAmount" class="md:hidden w-full py-2.5 shrink-0 rounded-full border-2 border-dashed border-gray-300 dark:border-gray-600 text-gray-500 dark:text-gray-400 text-xs font-bold uppercase tracking-wide active:bg-gray-50 dark:active:bg-gray-800 transition-colors">
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
            <div v-else-if="isNequi" class="flex flex-col items-center justify-center gap-4 h-full py-6 text-center">
                <div class="w-20 h-20 bg-pink-100 dark:bg-pink-900/20 rounded-full flex items-center justify-center">
                    <QrCode :size="40" class="text-pink-600 dark:text-pink-400" />
                </div>
                <div>
                    <h4 class="text-base font-bold text-gray-900 dark:text-white mb-1">
                      {{ currentMethod === 'llave_bre' ? 'Llave Bre-B' : 'Nequi' }}
                    </h4>
                    <p class="text-2xl font-black font-mono tabular-nums text-gray-900 dark:text-white">
                        $ {{ formatCurrency(remainingBalance.gt(0) ? remainingBalance : total) }}
                    </p>
                </div>
                <div class="w-full max-w-xs mt-2">
                    <label class="block text-left mb-1 text-xs font-semibold text-gray-500 uppercase">Referencia (Opcional)</label>
                    <input 
                        v-model="reference"
                        type="number"
                        class="w-full h-12 rounded-lg border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-center text-lg font-medium focus:ring-pink-500 focus:border-pink-500" 
                        placeholder="Últimos 4 dígitos"
                    />
                </div>
            </div>

            <!-- Scenario C: Fiado w/ Inline Compact Client Selection & Lazy Loading -->
            <div v-else-if="isFiado" class="flex flex-col gap-3 flex-1 min-h-0">
                <!-- Alerta Offline Bloqueante (N1) -->
                <div
                    v-if="!isOnline"
                    role="alert"
                    data-testid="fiado-offline-alert"
                    class="p-2.5 rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800 flex items-center gap-2 text-rose-700 dark:text-rose-300 text-xs font-semibold shrink-0"
                >
                    <WifiOff :size="15" class="shrink-0" />
                    <span>Las ventas fiadas requieren conexión en línea. Reconecta para acreditar este saldo.</span>
                </div>

                <!-- 1A. Tarjeta Compacta de Cliente Seleccionado -->
                <div v-if="selectedFiadoClient" class="bg-indigo-50 dark:bg-indigo-950/30 p-3 rounded-xl border border-indigo-200 dark:border-indigo-800/60 shadow-sm space-y-2.5 shrink-0">
                    <div class="flex items-center justify-between">
                        <span class="text-[11px] font-bold text-indigo-600 dark:text-indigo-400 uppercase tracking-wide">
                            Cliente Seleccionado
                        </span>
                        <div class="flex items-center gap-2">
                            <button
                                type="button"
                                @click="clearSelectedFiadoClient"
                                class="text-xs font-semibold text-indigo-600 hover:text-indigo-700 dark:text-indigo-400 hover:underline flex items-center gap-1 cursor-pointer"
                            >
                                <Users :size="14" />
                                Cambiar
                            </button>
                            <button
                                type="button"
                                @click="clearSelectedFiadoClient"
                                class="text-gray-400 hover:text-red-500 p-1 rounded-lg transition-colors cursor-pointer"
                                title="Quitar cliente"
                            >
                                <X :size="16" />
                            </button>
                        </div>
                    </div>

                    <div class="flex items-center justify-between gap-3">
                        <div class="flex items-center gap-2.5 min-w-0 flex-1">
                            <div class="w-9 h-9 rounded-full bg-indigo-600 text-white flex items-center justify-center font-bold text-xs shadow-sm shrink-0">
                                {{ selectedFiadoClient.name.substring(0, 2).toUpperCase() }}
                            </div>
                            <div class="min-w-0 flex-1">
                                <button
                                    type="button"
                                    data-testid="selected-client-name-link"
                                    @click="goToClientDetail(selectedFiadoClient.id)"
                                    title="Ver detalle y estado de cuenta del cliente"
                                    class="font-bold text-indigo-700 dark:text-indigo-300 hover:text-indigo-600 dark:hover:text-indigo-200 hover:underline text-sm truncate leading-tight flex items-center gap-1 max-w-full text-left cursor-pointer group/name transition-colors"
                                >
                                    <span class="truncate">{{ selectedFiadoClient.name }}</span>
                                    <ExternalLink :size="13" class="shrink-0 opacity-75 group-hover/name:opacity-100 group-hover/name:translate-x-0.5 transition-all" />
                                </button>
                                <div class="text-[11px] text-gray-500 dark:text-gray-400 truncate leading-tight mt-0.5">
                                    <span v-if="selectedFiadoClient.cc">CC: {{ selectedFiadoClient.cc }}</span>
                                    <span v-if="selectedFiadoClient.phone"> • Tel: {{ selectedFiadoClient.phone }}</span>
                                </div>
                            </div>
                        </div>

                        <div class="flex flex-col items-end shrink-0 text-right leading-tight gap-0.5">
                            <span class="text-[11px] font-semibold font-mono tabular-nums text-emerald-600 dark:text-emerald-400">
                                Cupo: ${{ formatCurrency(selectedClientCreditLimit) }}
                            </span>
                            <span
                                class="text-[11px] font-bold font-mono tabular-nums"
                                :class="selectedClientCurrentDebt.gt(0) ? 'text-red-600 dark:text-red-400' : 'text-gray-500 dark:text-gray-400'"
                            >
                                Deuda: ${{ formatCurrency(selectedClientCurrentDebt) }}
                            </span>
                        </div>
                    </div>

                    <!-- Read Model de Cupo y Saldo Previsto (Arquetipo D) -->
                    <div
                        data-testid="fiado-credit-read-model"
                        class="grid grid-cols-2 sm:grid-cols-4 gap-2 p-2.5 rounded-xl bg-white/90 dark:bg-slate-900/70 border border-indigo-200/80 dark:border-indigo-800/60 text-xs"
                    >
                        <div>
                            <span class="block text-[10px] uppercase tracking-wide text-slate-500 dark:text-slate-400">Cupo total</span>
                            <span class="font-bold font-mono tabular-nums text-slate-900 dark:text-white">${{ formatCurrency(selectedClientCreditLimit) }}</span>
                        </div>
                        <div>
                            <span class="block text-[10px] uppercase tracking-wide text-slate-500 dark:text-slate-400">Deuda actual</span>
                            <span class="font-bold font-mono tabular-nums text-slate-900 dark:text-white">${{ formatCurrency(selectedClientCurrentDebt) }}</span>
                        </div>
                        <div>
                            <span class="block text-[10px] uppercase tracking-wide text-slate-500 dark:text-slate-400">Monto a fiar</span>
                            <span class="font-bold font-mono tabular-nums text-indigo-700 dark:text-indigo-300">${{ formatCurrency(amountToCredit) }}</span>
                        </div>
                        <div>
                            <span class="block text-[10px] uppercase tracking-wide text-slate-500 dark:text-slate-400">Nuevo saldo previsto</span>
                            <span
                                class="font-black font-mono tabular-nums"
                                :class="isCreditLimitExceeded ? 'text-rose-600 dark:text-rose-400' : 'text-emerald-600 dark:text-emerald-400'"
                            >
                                ${{ formatCurrency(projectedClientDebt) }}
                            </span>
                        </div>
                    </div>

                    <!-- Bloqueo N1 si excede cupo disponible -->
                    <div
                        v-if="isCreditLimitExceeded"
                        role="alert"
                        data-testid="fiado-credit-exceeded-alert"
                        class="p-2.5 rounded-lg bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800 flex items-center gap-2 text-rose-700 dark:text-rose-300 text-xs font-semibold"
                    >
                        <AlertTriangle :size="15" class="shrink-0 text-rose-600 dark:text-rose-400" />
                        <span>
                            El monto a fiar (${{ formatCurrency(amountToCredit) }}) superará el cupo disponible (${{ formatCurrency(selectedClientCreditLimit) }}) del cliente.
                        </span>
                    </div>
                </div>

                <!-- 1B. Selector Inline Directo (Cero clics adicionales) -->
                <div v-else class="flex flex-col gap-2 bg-gray-50/70 dark:bg-gray-800/40 p-2.5 rounded-2xl border border-gray-200 dark:border-gray-700/80 flex-1 min-h-0">
                    <!-- Buscador Inline -->
                    <div class="relative shrink-0">
                        <Search :size="16" class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none" />
                        <input
                            v-model="clientSearch"
                            type="text"
                            aria-label="Buscar cliente por nombre, cédula o teléfono"
                            placeholder="Buscar por nombre, CC o teléfono..."
                            class="w-full h-10 pl-9 pr-8 rounded-xl border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900/80 text-gray-900 dark:text-white text-xs font-medium focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none transition-all"
                        />
                        <button
                            v-if="clientSearch"
                            type="button"
                            @click="clientSearch = ''"
                            aria-label="Limpiar búsqueda"
                            class="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 p-0.5 cursor-pointer"
                        >
                            <X :size="14" />
                        </button>
                    </div>

                    <!-- Contador visible -->
                    <div class="flex items-center justify-end shrink-0">
                        <span class="text-[11px] font-semibold text-gray-400 dark:text-gray-500 shrink-0">
                            {{ displayedClients.length }} de {{ totalClientsCount }}
                        </span>
                    </div>

                    <!-- Lista Scrollable con Carga Progresiva de 5 en 5 -->
                    <div
                        data-testid="fiado-client-list"
                        @scroll="handleClientListScroll"
                        class="flex-1 min-h-[140px] overflow-y-auto space-y-1.5 pr-1"
                    >
                        <!-- Estado Loading -->
                        <div
                            v-if="isLoadingClientsPage && displayedClients.length === 0"
                            class="flex flex-col items-center justify-center py-6 text-gray-500 dark:text-gray-400 gap-2"
                        >
                            <Loader2 :size="22" class="animate-spin text-indigo-500" />
                            <span class="text-xs font-medium">Cargando clientes...</span>
                        </div>

                        <!-- Estado Error explícito (Regla 3) -->
                        <div
                            v-else-if="clientsPageError && displayedClients.length === 0"
                            class="flex flex-col items-center justify-center py-5 px-3 text-center gap-2 text-red-600 dark:text-red-400"
                        >
                            <AlertTriangle :size="22" />
                            <span class="text-xs font-semibold">{{ clientsPageError }}</span>
                            <button
                                type="button"
                                @click="retryLoadClients"
                                class="px-3 py-1 rounded-lg bg-red-50 dark:bg-red-950/50 border border-red-200 dark:border-red-800 text-xs font-bold hover:bg-red-100 transition-colors cursor-pointer"
                            >
                                Reintentar
                            </button>
                        </div>

                        <!-- Estado Vacío -->
                        <div
                            v-else-if="displayedClients.length === 0"
                            class="flex flex-col items-center justify-center py-6 px-3 text-center text-gray-400 dark:text-gray-500 gap-1.5"
                        >
                            <UserX :size="22" />
                            <span class="text-xs font-semibold text-gray-600 dark:text-gray-300">
                                {{ clientSearch ? 'Sin coincidencias para tu búsqueda' : 'No hay clientes disponibles' }}
                            </span>
                        </div>

                        <!-- Tarjetas Ultra-Compactas de Cliente -->
                        <template v-else>
                            <button
                                v-for="client in displayedClients"
                                :key="client.id"
                                type="button"
                                data-testid="fiado-client-card"
                                @click="selectedFiadoClient = client"
                                class="w-full min-h-[48px] px-3 py-2 rounded-xl border border-gray-200/80 dark:border-gray-700/80 bg-white dark:bg-gray-800/90 hover:border-indigo-400 dark:hover:border-indigo-500 hover:bg-indigo-50/40 dark:hover:bg-indigo-950/30 flex items-center justify-between gap-2.5 text-left transition-all duration-150 cursor-pointer group"
                            >
                                <!-- Izquierda: Avatar + Nombre + CC + Teléfono -->
                                <div class="flex items-center gap-2.5 min-w-0 flex-1">
                                    <div class="w-8 h-8 rounded-full bg-indigo-100 dark:bg-indigo-900/60 text-indigo-700 dark:text-indigo-300 font-bold text-xs flex items-center justify-center shrink-0 group-hover:bg-indigo-600 group-hover:text-white transition-colors">
                                        {{ client.name.substring(0, 2).toUpperCase() }}
                                    </div>
                                    <div class="min-w-0 flex-1">
                                        <div class="font-bold text-gray-900 dark:text-white text-xs truncate leading-tight">
                                            {{ client.name }}
                                        </div>
                                        <div class="text-[11px] text-gray-500 dark:text-gray-400 truncate leading-tight mt-0.5">
                                            <span>CC: {{ client.cc }}</span>
                                            <span v-if="client.phone"> • Tel: {{ client.phone }}</span>
                                        </div>
                                    </div>
                                </div>

                                <!-- Derecha: Cupo Límite y Deuda Actual -->
                                <div class="flex flex-col items-end shrink-0 text-right leading-tight gap-0.5">
                                    <span class="text-[11px] font-semibold text-emerald-600 dark:text-emerald-400">
                                        Cupo: ${{ formatCurrency(client.creditLimit || 0) }}
                                    </span>
                                    <span
                                        class="text-[11px] font-bold"
                                        :class="client.totalDebt && client.totalDebt.gt(0) ? 'text-red-600 dark:text-red-400' : 'text-gray-400 dark:text-gray-500'"
                                    >
                                        Deuda: ${{ formatCurrency(client.totalDebt || 0) }}
                                    </span>
                                </div>
                            </button>

                            <!-- Carga Progresiva de Restantes (Petición de 5 en 5) -->
                            <button
                                v-if="remainingClientsCount > 0"
                                type="button"
                                data-testid="load-more-clients-btn"
                                :disabled="isLoadingMoreClients"
                                @click="loadMoreClients"
                                class="w-full py-1.5 text-[11px] font-bold text-indigo-600 dark:text-indigo-400 hover:bg-indigo-50 dark:hover:bg-indigo-950/40 rounded-lg flex items-center justify-center gap-1 transition-colors cursor-pointer disabled:opacity-60"
                            >
                                <Loader2 v-if="isLoadingMoreClients" :size="14" class="animate-spin" />
                                <ChevronDown v-else :size="14" />
                                <span>
                                    {{ isLoadingMoreClients ? 'Cargando 5 más...' : `Cargar más clientes (${remainingClientsCount} restantes)` }}
                                </span>
                            </button>
                        </template>
                    </div>
                </div>
            </div>

        </main>

        <!-- 4. Footer (Action) -->
        <footer class="px-4 py-3 bg-white dark:bg-surface-dark border-t border-gray-100 dark:border-gray-800 shrink-0 space-y-2">
            <div
                v-if="checkoutError"
                role="alert"
                data-testid="checkout-inline-error"
                class="p-2.5 rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800 flex items-center gap-2 text-rose-700 dark:text-rose-300 text-xs font-semibold"
            >
                <AlertTriangle :size="15" class="shrink-0" />
                <span>{{ checkoutError }}</span>
            </div>

            <button 
                type="button"
                data-testid="checkout-confirm-btn"
                @click="confirmTransaction"
                :disabled="!canComplete"
                class="w-full h-[52px] bg-emerald-600 hover:bg-emerald-700 active:bg-emerald-800 disabled:bg-gray-100 disabled:text-gray-400 disabled:dark:bg-gray-800 disabled:dark:text-gray-600 disabled:cursor-not-allowed rounded-xl shadow-lg shadow-emerald-200 dark:shadow-none flex flex-col items-center justify-center transition-all duration-200 cursor-pointer"
            >
                <div class="flex items-center gap-2">
                    <span class="text-white text-xl font-black tracking-wide">CONFIRMAR</span>
                    <span v-if="change.gt(0)" class="bg-emerald-800/40 text-emerald-50 text-xs px-2 py-0.5 rounded font-bold font-mono tabular-nums ml-1">
                        ${{ formatCurrency(change) }}
                    </span>
                </div>
            </button>
        </footer>

    </div>
  </UIBaseModal>
</template>

<style scoped>
/* Override BaseModal content overflow for checkout layout */
.checkout-modal :deep(.relative) {
    max-height: 100dvh;
}
</style>

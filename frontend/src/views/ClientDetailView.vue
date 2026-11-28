<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useClientsStore } from '../stores/clients';
import { useAuthStore } from '../stores/auth';
import { useCashRegisterStore } from '../stores/cashRegister';
import { type ClientTransaction } from '../types';
import type { ClientStatement, ClientStatementMovement } from '../data/repositories/clientRepository';
import { Decimal } from 'decimal.js';
import BaseModal from '../components/ui/BaseModal.vue';
import BaseInput from '../components/ui/BaseInput.vue';
import BaseButton from '../components/ui/BaseButton.vue';
import BaseListSkeleton from '../components/ui/BaseListSkeleton.vue';
import ClientFormModal from '../components/ClientFormModal.vue';
import {
  MoreVertical,
  Trash2,
  Receipt,
  Banknote,
  ShoppingCart,
  Plus,
  AlertTriangle,
  ChevronLeft,
  Pencil,
  Smartphone,
  CreditCard,
  Download,
  RefreshCw,
  Info
} from 'lucide-vue-next';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useNotifications } from '../composables/useNotifications';

const router = useRouter();
const route = useRoute();
const clientsStore = useClientsStore();
const authStore = useAuthStore();
const cashRegisterStore = useCashRegisterStore();
const isAdmin = computed(() => authStore.isAdmin);
const canOperateFiado = computed(() => authStore.canFiar || authStore.isAdmin);
const { formatCurrency: rawFormatCurrency } = useCurrencyFormat();
const { showSuccess } = useNotifications();

const PAYMENT_METHOD_LABELS: Record<string, string> = {
  efectivo: 'Abono Efectivo',
  nequi: 'Abono Nequi',
  llave_bre: 'Abono Llave Bre-B',
};

// State
const paymentAmount = ref('');
const paymentMethod = ref('efectivo');
const showPaymentModal = ref(false);
const isSubmittingPayment = ref(false);
const isSyncingCash = ref(false);
const cashSyncError = ref<string | null>(null);
const paymentSubmitError = ref<string | null>(null);
const showOptionsMenu = ref(false);
const showDeleteConfirm = ref(false);
const deleteError = ref<string | null>(null);
const showDebtAlert = ref(false);
const showEditModal = ref(false);
const isDeleting = ref(false);
const isLoadingStatement = ref(false);
const statementError = ref('');
const statementData = ref<ClientStatement | null>(null);
let statementSeq = 0;

// Get client ID from route
const clientId = computed(() => String(route.params.id));

const matchedStatementClient = computed(() =>
  statementData.value?.client?.id === clientId.value ? statementData.value.client : null
);

const client = computed(
  () => matchedStatementClient.value || clientsStore.getClientById(clientId.value) || null
);

const transactions = ref<(ClientTransaction | ClientStatementMovement)[]>([]);

const loadStatement = async (id: string) => {
  if (!id) return;
  const seq = ++statementSeq;
  if (statementData.value?.client?.id !== id) {
    statementData.value = null;
    transactions.value = [];
  }
  isLoadingStatement.value = true;
  statementError.value = '';
  try {
    if (typeof clientsStore.getClientStatement === 'function') {
      const stmt = await clientsStore.getClientStatement(id, 200, 0);
      if (seq !== statementSeq || id !== clientId.value) return;
      statementData.value = stmt;
      transactions.value = stmt.movements;
    } else {
      const txs = await clientsStore.getClientTransactions(id);
      if (seq !== statementSeq || id !== clientId.value) return;
      statementData.value = null;
      transactions.value = txs;
    }
  } catch (err: any) {
    if (seq !== statementSeq || id !== clientId.value) return;
    statementError.value =
      err?.message || 'No se pudo consultar el estado de cuenta en el servidor.';
  } finally {
    if (seq === statementSeq) {
      isLoadingStatement.value = false;
    }
  }
};

watch(clientId, async (newId) => {
  if (newId) {
    await loadStatement(newId);
  }
}, { immediate: true });

type ClientDatePreset = 'today' | 'week' | 'month' | 'all';
const dateFilter = ref<ClientDatePreset>('all');

const filteredTransactions = computed(() => {
  if (dateFilter.value === 'all') return transactions.value;

  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();

  return transactions.value.filter((tx) => {
    const txTime = new Date(tx.date).getTime();
    switch (dateFilter.value) {
      case 'today': return txTime >= todayStart;
      case 'week': return txTime >= todayStart - 7 * 24 * 60 * 60 * 1000;
      case 'month': return txTime >= todayStart - 30 * 24 * 60 * 60 * 1000;
      default: return true;
    }
  });
});

const availableCredit = computed(
  () => matchedStatementClient.value?.creditAvailable ?? clientsStore.getAvailableCredit(clientId.value)
);

const creditUsagePercent = computed(() => {
  if (!client.value || client.value.creditLimit.isZero()) return 0;
  return client.value.totalDebt.div(client.value.creditLimit).times(100).toNumber();
});

const creditBarColorClass = computed(() => {
  if (creditUsagePercent.value >= 100) return 'bg-red-500';
  if (creditUsagePercent.value >= 80) return 'bg-amber-500';
  return 'bg-emerald-500';
});

const parsedPaymentAmount = computed(() => {
  const num = Number(paymentAmount.value);
  if (!paymentAmount.value || !Number.isFinite(num)) return new Decimal(0);
  return new Decimal(num);
});

const isPositivePayment = computed(() => parsedPaymentAmount.value.gt(0));

const isOverpayment = computed(() => {
  if (!client.value || !isPositivePayment.value) return false;
  return parsedPaymentAmount.value.gt(client.value.totalDebt);
});

const canConfirmPayment = computed(() => {
  if (!client.value) return false;
  if (!isPositivePayment.value || isOverpayment.value) return false;
  if (isSubmittingPayment.value || isSyncingCash.value || Boolean(cashSyncError.value)) return false;
  if (!cashRegisterStore.isOpen || cashRegisterStore.isStaleSession) return false;
  return true;
});

// Methods
const formatCurrency = (val: Decimal | number) => {
  return rawFormatCurrency(val instanceof Decimal ? val.toNumber() : val);
};

const formatCedula = (cedula: string) => {
  return cedula.replace(/\B(?=(\d{3})+(?!\d))/g, '.');
};

const formatDate = (dateStr: string) => {
  const date = new Date(dateStr);
  const day = date.getDate();
  const months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];
  const month = months[date.getMonth()];
  const hours = date.getHours();
  const minutes = date.getMinutes().toString().padStart(2, '0');
  const ampm = hours >= 12 ? 'PM' : 'AM';
  const hour12 = hours % 12 || 12;
  return `${day} ${month}, ${hour12}:${minutes} ${ampm}`;
};

const goBack = () => {
  if (route.query?.from === 'pos') {
    router.push({ path: '/pos', query: { checkoutClientId: clientId.value } });
    return;
  }
  router.push('/clients');
};

const toggleOptionsMenu = () => {
  showOptionsMenu.value = !showOptionsMenu.value;
};

const closeOptionsMenu = () => {
  showOptionsMenu.value = false;
};

const confirmDelete = () => {
  showOptionsMenu.value = false;
  deleteError.value = null;

  if (client.value && client.value.totalDebt.gt(0)) {
    showDebtAlert.value = true;
    return;
  }

  showDeleteConfirm.value = true;
};

const deleteClient = async () => {
  if (isDeleting.value) return;
  isDeleting.value = true;
  deleteError.value = null;
  try {
    const result = await clientsStore.deleteClient(clientId.value);
    if (!result?.success) {
      if (result?.code === 'CLIENT_HAS_DEBT' || result?.code === 'DEBT_PENDING') {
        showDeleteConfirm.value = false;
        showDebtAlert.value = true;
      } else {
        deleteError.value = result?.error || 'No se pudo eliminar el cliente.';
      }
      return;
    }
    showDeleteConfirm.value = false;
    showSuccess('Cliente eliminado correctamente');
    router.push('/clients');
  } catch (err: any) {
    deleteError.value = err?.message || 'Error inesperado al eliminar el cliente.';
  } finally {
    isDeleting.value = false;
  }
};

const exportStatementCsv = () => {
  if (!client.value) return;
  const activeClient = statementData.value?.client || client.value;
  const rows = filteredTransactions.value;
  const escapeCsv = (val: string | number) => `"${String(val).replace(/"/g, '""')}"`;

  const lines: string[] = [
    ['Estado de Cuenta - Cliente Fiado', activeClient.name].map(escapeCsv).join(','),
    ['Documento / C.C.', activeClient.cc].map(escapeCsv).join(','),
    ['Saldo Pendiente', activeClient.totalDebt.toString()].map(escapeCsv).join(','),
    ['Cupo Autorizado', (activeClient.creditLimit || new Decimal(0)).toString()].map(escapeCsv).join(','),
    ['Generado (Servidor)', statementData.value?.generatedAt || new Date().toISOString()].map(escapeCsv).join(','),
    '',
    ['Fecha', 'Tipo', 'Detalle', 'Monto', 'Saldo Anterior', 'Saldo Nuevo'].map(escapeCsv).join(','),
  ];

  for (const tx of rows as any[]) {
    lines.push(
      [
        tx.date,
        tx.type === 'payment' ? 'Pago / Ajuste' : 'Compra Fiada',
        tx.description,
        tx.amount instanceof Decimal ? tx.amount.toString() : String(tx.amount),
        tx.previousBalance instanceof Decimal ? tx.previousBalance.toString() : '',
        tx.newBalance instanceof Decimal ? tx.newBalance.toString() : '',
      ]
        .map(escapeCsv)
        .join(',')
    );
  }

  const blob = new Blob(['\uFEFF' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `estado-cuenta-${activeClient.cc}-${new Date().toISOString().slice(0, 10)}.csv`;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
  showSuccess('Estado de cuenta exportado');
};

const syncCashForPayment = async () => {
  cashSyncError.value = null;
  const storeId = authStore.currentStore?.id || authStore.currentUser?.storeId;
  if (!storeId || typeof (cashRegisterStore as any).syncFromBackend !== 'function') {
    return;
  }
  isSyncingCash.value = true;
  try {
    await (cashRegisterStore as any).syncFromBackend(storeId, { throwOnError: true });
  } catch (err: any) {
    cashSyncError.value = err?.message || 'No se pudo verificar el estado real de caja en el servidor.';
  } finally {
    isSyncingCash.value = false;
  }
};

const openPaymentModal = async () => {
  paymentSubmitError.value = null;
  showPaymentModal.value = true;
  await syncCashForPayment();
};

const fillTotalBalance = () => {
  if (!client.value) return;
  paymentAmount.value = client.value.totalDebt.toString();
  paymentSubmitError.value = null;
};

const registerPayment = async () => {
  if (!canConfirmPayment.value || !client.value) return;

  isSubmittingPayment.value = true;
  paymentSubmitError.value = null;
  try {
    const paymentLabel = PAYMENT_METHOD_LABELS[paymentMethod.value] || 'Abono';
    await clientsStore.registerPayment(
      clientId.value,
      parsedPaymentAmount.value,
      paymentLabel,
      paymentMethod.value
    );
    showSuccess('Abono registrado exitosamente');
    paymentAmount.value = '';
    paymentMethod.value = 'efectivo';
    showPaymentModal.value = false;
    await loadStatement(clientId.value);
  } catch (err: any) {
    paymentSubmitError.value = err?.message || 'Error al registrar el abono';
  } finally {
    isSubmittingPayment.value = false;
  }
};

const handleClientEdited = async () => {
  showEditModal.value = false;
  await loadStatement(clientId.value);
};
</script>

<template>
  <div class="min-h-screen bg-background-light dark:bg-background-dark pb-24">
    <!-- Loading Inicial en Frío / Deep-Link sin caché previa -->
    <div v-if="isLoadingStatement && !client" data-testid="client-detail-loading" class="p-4 space-y-4">
      <div class="flex items-center gap-3">
        <button
          type="button"
          @click="goBack"
          aria-label="Volver"
          class="flex items-center justify-center size-10 text-slate-600 dark:text-slate-300 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800"
        >
          <ChevronLeft :size="24" :stroke-width="1.5" />
        </button>
        <div class="h-6 w-48 rounded-lg bg-slate-200 dark:bg-slate-800 animate-pulse"></div>
      </div>
      <BaseListSkeleton :count="4" type="detail" />
    </div>

    <!-- Error Fail-Closed en Carga en Frío -->
    <div
      v-else-if="statementError && !client"
      role="alert"
      data-testid="client-detail-error-card"
      class="m-4 p-5 rounded-2xl bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800 space-y-3"
    >
      <div class="flex items-start gap-2.5">
        <AlertTriangle :size="20" class="text-red-600 dark:text-red-400 shrink-0 mt-0.5" />
        <p class="text-sm font-semibold text-red-700 dark:text-red-200">{{ statementError }}</p>
      </div>
      <div class="flex gap-2">
        <BaseButton type="button" size="sm" variant="secondary" @click="goBack">
          Volver
        </BaseButton>
        <BaseButton type="button" size="sm" variant="danger" @click="loadStatement(clientId)">
          <RefreshCw :size="14" class="mr-1.5" />
          Reintentar
        </BaseButton>
      </div>
    </div>

    <!-- Hero Header Section (DESIGN.md tokens duales, sólido sin gradientes ni bg fijo) -->
    <div
      v-else-if="client"
      data-testid="client-detail-hero"
      class="relative bg-surface-light dark:bg-surface-dark border-b border-slate-200 dark:border-slate-800 shadow-sm z-10"
    >
      <div class="relative flex flex-col p-6 pb-8 max-w-3xl mx-auto">
        <!-- Navigation -->
        <div class="flex items-center justify-between mb-6">
          <button
            type="button"
            @click="goBack"
            aria-label="Volver"
            class="flex items-center justify-center size-11 -ml-2 text-slate-700 dark:text-slate-200 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer"
          >
            <ChevronLeft :size="26" :stroke-width="1.5" />
          </button>
          <div class="flex gap-2 relative">
            <button
              v-if="isAdmin"
              type="button"
              @click="toggleOptionsMenu"
              aria-label="Opciones"
              class="flex items-center justify-center size-10 text-slate-600 dark:text-slate-300 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer"
            >
              <MoreVertical :size="22" :stroke-width="1.5" />
            </button>

            <!-- Dropdown Menu -->
            <Transition name="dropdown">
              <div
                v-if="showOptionsMenu"
                class="absolute right-0 top-12 bg-surface-light dark:bg-surface-dark rounded-xl shadow-xl border border-slate-200 dark:border-slate-700 overflow-hidden min-w-[180px] z-50"
              >
                <button
                  v-if="isAdmin"
                  type="button"
                  @click="showEditModal = true; closeOptionsMenu()"
                  class="w-full px-4 py-3 flex items-center gap-3 text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors text-left cursor-pointer"
                >
                  <Pencil :size="20" :stroke-width="1.5" />
                  <span class="font-medium">Editar cliente</span>
                </button>
                <button
                  type="button"
                  @click="confirmDelete"
                  class="w-full px-4 py-3 flex items-center gap-3 text-red-600 hover:bg-red-50 dark:hover:bg-red-950/30 transition-colors text-left cursor-pointer"
                >
                  <Trash2 :size="20" :stroke-width="1.5" />
                  <span class="font-medium">Eliminar cliente</span>
                </button>
              </div>
            </Transition>
          </div>

          <div v-if="showOptionsMenu" class="fixed inset-0 z-40" @click="closeOptionsMenu"></div>
        </div>

        <!-- Client Info -->
        <div class="flex flex-col items-center text-center">
          <h2 class="text-slate-900 dark:text-white text-xl font-bold tracking-tight mb-1">{{ client.name }}</h2>
          <p class="text-slate-500 dark:text-slate-400 text-sm font-medium tracking-wide font-mono tabular-nums">
            C.C. {{ formatCedula(client.cc) }}
          </p>
        </div>

        <!-- Gigantic Balance -->
        <div class="flex flex-col items-center mt-6 mb-8">
          <span class="text-xs font-bold uppercase tracking-widest mb-2" :class="client.totalDebt.gt(0) ? 'text-red-600 dark:text-red-400' : 'text-emerald-600 dark:text-emerald-400'">
            Saldo Pendiente
          </span>
          <h1 class="text-slate-900 dark:text-white text-5xl leading-none font-black tracking-tight font-mono tabular-nums">
            {{ formatCurrency(client.totalDebt) }}
          </h1>
        </div>

        <!-- Credit Limit Progress Bar (Sólida DESIGN.md) -->
        <div class="bg-background-light dark:bg-background-dark rounded-xl p-4 border border-slate-200 dark:border-slate-800">
          <div class="flex justify-between items-end mb-2">
            <p class="text-slate-700 dark:text-slate-200 text-sm font-semibold">Cupo de Crédito</p>
            <p class="text-emerald-600 dark:text-emerald-400 text-xs font-bold font-mono tabular-nums">
              Disponibles: {{ formatCurrency(availableCredit) }}
            </p>
          </div>
          <div class="relative h-3 w-full bg-slate-200 dark:bg-slate-800 rounded-full overflow-hidden">
            <div
              class="absolute top-0 left-0 h-full rounded-full transition-all"
              :class="creditBarColorClass"
              :style="{ width: `${Math.min(creditUsagePercent, 100)}%` }"
            ></div>
          </div>
          <div class="flex justify-between mt-2 font-mono tabular-nums">
            <p class="text-slate-500 dark:text-slate-400 text-xs">Uso: {{ formatCurrency(client.totalDebt) }}</p>
            <p class="text-slate-500 dark:text-slate-400 text-xs">Total: {{ formatCurrency(client.creditLimit) }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Main Content: Transaction History -->
    <main v-if="client || !statementError" class="relative z-0 px-4 pt-6 pb-32 flex flex-col gap-4 max-w-3xl mx-auto">
      <div class="flex items-center justify-between px-1 gap-2">
        <h3 class="text-slate-800 dark:text-white text-lg font-bold">Movimientos</h3>
        <button
          v-if="client && canOperateFiado"
          type="button"
          data-testid="export-client-csv-btn"
          @click="exportStatementCsv"
          :disabled="isLoadingStatement"
          class="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl border border-slate-200 dark:border-slate-700 bg-surface-light dark:bg-surface-dark text-xs font-semibold text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 active:scale-95 transition-all cursor-pointer"
        >
          <Download :size="14" />
          Exportar
        </button>
      </div>

      <!-- Loading Skeleton -->
      <div v-if="isLoadingStatement" class="px-1">
        <BaseListSkeleton :count="3" type="simple" />
      </div>

      <!-- Statement Error (No Silent Fallback) -->
      <div
        v-else-if="statementError"
        role="alert"
        class="p-4 rounded-xl bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800 space-y-2.5"
      >
        <p class="text-xs sm:text-sm text-red-700 dark:text-red-200 font-medium">
          {{ statementError }}
        </p>
        <button
          type="button"
          @click="loadStatement(clientId)"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-red-600 text-white text-xs font-semibold hover:bg-red-700 active:scale-95 cursor-pointer"
        >
          <RefreshCw :size="13" />
          Reintentar
        </button>
      </div>

      <!-- Filters -->
      <div v-else class="flex gap-2 overflow-x-auto no-scrollbar">
        <button
          v-for="preset in [
            { label: 'Todos', value: 'all' },
            { label: 'Hoy', value: 'today' },
            { label: 'Semana', value: 'week' },
            { label: 'Mes', value: 'month' }
          ]"
          :key="preset.value"
          type="button"
          @click="dateFilter = preset.value as ClientDatePreset"
          class="px-3 py-1.5 text-xs font-semibold rounded-full whitespace-nowrap transition-colors cursor-pointer"
          :class="dateFilter === preset.value
            ? 'bg-primary text-white'
            : 'bg-surface-light dark:bg-surface-dark border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800'"
        >
          {{ preset.label }}
        </button>
      </div>

      <!-- Empty State -->
      <div v-if="!isLoadingStatement && !statementError && filteredTransactions.length === 0" class="flex flex-col items-center py-12 text-center">
        <div
          class="flex h-16 w-16 items-center justify-center rounded-2xl bg-slate-100 dark:bg-slate-800 text-slate-400 mb-4"
        >
          <Receipt :size="32" :stroke-width="1.5" />
        </div>
        <p class="text-slate-500 text-sm">Sin movimientos registrados</p>
      </div>

      <!-- Transaction List -->
      <div v-else-if="!isLoadingStatement && !statementError" class="flex flex-col gap-3">
        <article
          v-for="tx in filteredTransactions"
          :key="tx.id"
          class="group flex items-center gap-4 bg-surface-light dark:bg-surface-dark p-4 rounded-xl shadow-sm border border-slate-200 dark:border-slate-800 transition-colors"
        >
          <div
            class="shrink-0 flex items-center justify-center size-12 rounded-2xl"
            :class="
              tx.type === 'payment'
                ? 'bg-emerald-50 dark:bg-emerald-950/30 text-emerald-600 dark:text-emerald-400'
                : 'bg-red-50 dark:bg-red-950/30 text-red-600 dark:text-red-400'
            "
          >
            <component :is="tx.type === 'payment' ? Banknote : ShoppingCart" :size="24" :stroke-width="1.5" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-slate-900 dark:text-white text-base font-bold truncate">
              {{ tx.description }}
            </p>
            <p class="text-slate-500 dark:text-slate-400 text-xs font-medium mt-0.5">
              {{ formatDate(tx.date) }}
            </p>
          </div>
          <div class="shrink-0 text-right">
            <p
              class="text-lg font-bold font-mono tabular-nums"
              :class="
                tx.type === 'payment'
                  ? 'text-emerald-600 dark:text-emerald-400'
                  : 'text-red-600 dark:text-red-400'
              "
            >
              {{ tx.type === 'payment' ? '-' : '+' }}{{ formatCurrency(new Decimal(tx.amount)) }}
            </p>
            <p class="text-slate-400 text-[10px] uppercase font-bold tracking-wider">
              {{ tx.type === 'payment' ? 'Pago' : 'Deuda' }}
            </p>
          </div>
        </article>
      </div>
    </main>

    <!-- Sticky Footer Action -->
    <div
      v-if="client && canOperateFiado"
      class="fixed bottom-0 left-0 w-full bg-surface-light dark:bg-surface-dark border-t border-slate-200 dark:border-slate-800 p-4 z-50"
    >
      <div class="max-w-3xl mx-auto">
        <BaseButton
          @click="openPaymentModal"
          data-testid="register-payment-btn"
          variant="success"
          class="w-full h-14 text-lg font-bold"
        >
          <Plus :size="20" class="mr-2" />
          REGISTRAR ABONO
        </BaseButton>
      </div>
    </div>

    <!-- Payment Modal (Arquetipo D) -->
    <BaseModal
      v-model="showPaymentModal"
      title="Registrar Abono"
      :showCloseButton="true"
    >
      <div class="p-5 space-y-4">
        <!-- Read Model Saldo Pendiente -->
        <div
          v-if="client"
          class="p-3.5 rounded-xl bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-800 flex items-center justify-between"
        >
          <div>
            <p class="text-[11px] font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400">
              Saldo Pendiente
            </p>
            <p class="text-lg font-black text-slate-900 dark:text-white font-mono tabular-nums">
              {{ formatCurrency(client.totalDebt) }}
            </p>
          </div>
          <button
            v-if="client.totalDebt.gt(0)"
            type="button"
            data-testid="payment-full-balance-btn"
            @click="fillTotalBalance"
            class="px-2.5 py-1.5 rounded-lg bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800 text-xs font-bold text-emerald-700 dark:text-emerald-300 hover:bg-emerald-100 cursor-pointer"
          >
            SALDO TOTAL
          </button>
        </div>

        <!-- Banner N3 Error al sincronizar caja (Fail-Closed) -->
        <div
          v-if="cashSyncError"
          role="alert"
          data-testid="payment-cash-sync-error"
          class="p-3 rounded-xl bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800 space-y-2"
        >
          <p class="text-xs text-red-700 dark:text-red-300 font-medium">
            No se pudo verificar el estado de caja ({{ cashSyncError }}). Reintenta antes de registrar abonos.
          </p>
          <BaseButton
            type="button"
            size="sm"
            variant="danger"
            data-testid="payment-cash-sync-retry-btn"
            :loading="isSyncingCash"
            :disabled="isSyncingCash"
            @click="syncCashForPayment"
          >
            Reintentar
          </BaseButton>
        </div>

        <!-- Banner N3 Turno cerrado / +24h (oculto mientras sincroniza o hay error de red) -->
        <div
          v-else-if="!isSyncingCash && (!cashRegisterStore.isOpen || cashRegisterStore.isStaleSession)"
          data-testid="payment-cash-closed-banner"
          class="p-3 rounded-xl bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800/60 flex items-start gap-2"
        >
          <Info :size="16" class="text-amber-600 dark:text-amber-400 shrink-0 mt-0.5" />
          <p class="text-xs text-amber-800 dark:text-amber-300 font-medium">
            {{ cashRegisterStore.isStaleSession ? 'Cierra primero el turno vencido (+24h).' : 'Abre la caja antes de registrar abonos.' }}
          </p>
        </div>

        <div>
          <BaseInput
            v-model="paymentAmount"
            type="number"
            inputmode="numeric"
            label="Monto del abono"
            placeholder="0"
            class="font-mono tabular-nums"
            autofocus
          />
          <p
            v-if="isOverpayment"
            role="alert"
            data-testid="payment-overpayment-alert"
            class="mt-1.5 text-xs font-semibold text-red-600 dark:text-red-400"
          >
            El abono no puede superar la deuda actual ({{ client ? formatCurrency(client.totalDebt) : '$0' }}).
          </p>
        </div>

        <!-- Error RPC inline N1 (sin showWarning ni doble toast) -->
        <div
          v-if="paymentSubmitError"
          role="alert"
          data-testid="payment-modal-error"
          class="p-3 rounded-xl bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800 text-xs font-semibold text-red-700 dark:text-red-300"
        >
          {{ paymentSubmitError }}
        </div>

        <!-- Método de Pago Selector -->
        <div>
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">Método de Pago</label>
          <div class="grid grid-cols-3 gap-2">
            <button
              type="button"
              @click="paymentMethod = 'efectivo'"
              :class="paymentMethod === 'efectivo' ? 'bg-primary text-white border-primary shadow-sm' : 'bg-background-light dark:bg-background-dark text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800'"
              class="flex flex-col items-center justify-center p-3 rounded-xl border transition-all cursor-pointer"
            >
              <Banknote :size="24" :stroke-width="1.5" class="mb-1" />
              <span class="text-xs font-semibold">Efectivo</span>
            </button>
            <button
              type="button"
              @click="paymentMethod = 'nequi'"
              :class="paymentMethod === 'nequi' ? 'bg-[#4A148C] text-white border-[#4A148C] shadow-sm' : 'bg-background-light dark:bg-background-dark text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800'"
              class="flex flex-col items-center justify-center p-3 rounded-xl border transition-all cursor-pointer"
            >
              <Smartphone :size="24" :stroke-width="1.5" class="mb-1" />
              <span class="text-xs font-semibold">Nequi</span>
            </button>
            <button
              type="button"
              @click="paymentMethod = 'llave_bre'"
              :class="paymentMethod === 'llave_bre' ? 'bg-teal-600 text-white border-teal-600 shadow-sm' : 'bg-background-light dark:bg-background-dark text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800'"
              class="flex flex-col items-center justify-center p-3 rounded-xl border transition-all cursor-pointer"
            >
              <CreditCard :size="24" :stroke-width="1.5" class="mb-1" />
              <span class="text-xs font-semibold">Llave Bre-B</span>
            </button>
          </div>
        </div>
      </div>

      <template #footer>
        <div class="p-5 pt-2 border-t border-slate-100 dark:border-slate-800 flex gap-3">
          <BaseButton
            type="button"
            @click="showPaymentModal = false"
            variant="secondary"
            class="flex-1"
            :disabled="isSubmittingPayment"
          >
            Cancelar
          </BaseButton>
          <BaseButton
            type="button"
            data-testid="confirm-payment-btn"
            @click="registerPayment"
            :disabled="!canConfirmPayment"
            :loading="isSubmittingPayment"
            variant="success"
            class="flex-1"
          >
            Confirmar
          </BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Delete Confirmation Modal -->
    <BaseModal
      v-model="showDeleteConfirm"
      title="¿Eliminar cliente?"
    >
      <div class="p-6 text-center">
        <div class="flex items-center justify-center w-14 h-14 rounded-full bg-red-100 dark:bg-red-900/30 mx-auto mb-4">
          <AlertTriangle :size="28" class="text-red-600" />
        </div>
        <p class="text-slate-600 dark:text-slate-300 text-sm">
          Se retirará a <strong>{{ client?.name }}</strong>. No se puede deshacer.
        </p>
        <div
          v-if="deleteError"
          role="alert"
          data-testid="delete-client-error"
          class="mt-4 p-3 rounded-xl bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800 text-xs font-semibold text-red-700 dark:text-red-300 text-left"
        >
          {{ deleteError }}
        </div>
      </div>

      <template #footer>
        <div class="p-6 pt-0 flex gap-3">
          <BaseButton
            @click="showDeleteConfirm = false"
            variant="secondary"
            class="flex-1"
            :disabled="isDeleting"
          >
            Cancelar
          </BaseButton>
          <BaseButton
            @click="deleteClient"
            variant="danger"
            class="flex-1"
            :loading="isDeleting"
            :disabled="isDeleting"
          >
            <Trash2 :size="20" class="mr-2" />
            {{ isDeleting ? 'Eliminando...' : 'Eliminar' }}
          </BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Debt Blocking Alert Modal -->
    <BaseModal
      v-model="showDebtAlert"
      title="Tiene Saldo Pendiente"
    >
      <div class="p-6 text-center">
        <div class="flex items-center justify-center w-14 h-14 rounded-full bg-red-100 dark:bg-red-900/30 mx-auto mb-4">
          <AlertTriangle :size="28" class="text-red-600" />
        </div>
        <p class="text-slate-600 dark:text-slate-300 text-sm">
          <strong>{{ client?.name }}</strong> tiene una deuda activa:
        </p>
        <p class="text-2xl font-bold text-red-600 my-3 font-mono tabular-nums">
          {{ client ? formatCurrency(client.totalDebt) : '$0' }}
        </p>
        <p class="text-slate-400 text-xs">
          Registra el pago total antes de eliminarlo.
        </p>
      </div>

      <template #footer>
        <div class="p-6 pt-0">
          <BaseButton
            @click="showDebtAlert = false"
            variant="primary"
            class="w-full"
          >
            Entendido
          </BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Edit Client Modal -->
    <ClientFormModal v-model="showEditModal" :client-id="clientId" @saved="handleClientEdited" />
  </div>
</template>

<style scoped>
.dropdown-enter-active,
.dropdown-leave-active {
  transition: all 0.15s ease;
}

.dropdown-enter-from,
.dropdown-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}
</style>

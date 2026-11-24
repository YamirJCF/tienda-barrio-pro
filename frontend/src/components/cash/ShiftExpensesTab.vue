<script setup lang="ts">
import { ref, watch, onMounted } from 'vue';
import Decimal from 'decimal.js';
import { Receipt, Plus, Lock, AlertTriangle, RefreshCw, User } from 'lucide-vue-next';
import cashRepository, { type SessionOpexExpense } from '../../data/repositories/cashRepository';
import { useCashRegisterStore } from '../../stores/cashRegister';
import { useAuthStore } from '../../stores/auth';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import { useNotifications } from '../../composables/useNotifications';
import { useAsyncAction } from '../../composables/useAsyncAction';
import BaseButton from '../ui/BaseButton.vue';
import BaseInput from '../ui/BaseInput.vue';
import BaseModal from '../ui/BaseModal.vue';
import BaseListSkeleton from '../ui/BaseListSkeleton.vue';
import FormInputCurrency from '../ui/FormInputCurrency.vue';

const props = defineProps<{
  sessionId: string | null;
  isOpen: boolean;
}>();

const authStore = useAuthStore();
const cashRegisterStore = useCashRegisterStore();
const { formatCurrency } = useCurrencyFormat();
const { showSuccess } = useNotifications();
const { execute: executeExpense, isLoading: isSubmitting } = useAsyncAction();

const expenses = ref<SessionOpexExpense[]>([]);
const totalOpexExpenses = ref(0);
const expenseCount = ref(0);
const isLoading = ref(false);
const loadError = ref<string | null>(null);

const showAddModal = ref(false);
const submitError = ref<string | null>(null);
const fieldErrors = ref<{ amount: string | null; description: string | null }>({
  amount: null,
  description: null,
});

const newExpense = ref<{
  amount: number;
  description: string;
  category: 'Servicios' | 'Nomina' | 'Transporte' | 'Mantenimiento' | 'Insumos';
  paymentMethod: 'efectivo' | 'nequi' | 'llave_bre';
  voucherRef: string;
}>({
  amount: 0,
  description: '',
  category: 'Servicios',
  paymentMethod: 'efectivo',
  voucherRef: '',
});

// Catálogo OPEX cerrado de 5 categorías (POL-FIN-04 / SDD-026)
const categories: Array<'Servicios' | 'Nomina' | 'Transporte' | 'Mantenimiento' | 'Insumos'> = [
  'Servicios',
  'Nomina',
  'Transporte',
  'Mantenimiento',
  'Insumos',
];

const paymentMethods: Array<{ id: 'efectivo' | 'nequi' | 'llave_bre'; name: string }> = [
  { id: 'efectivo', name: 'Efectivo' },
  { id: 'nequi', name: 'Nequi' },
  { id: 'llave_bre', name: 'Llave Bre-B' },
];

const channelLabel = (method?: string) =>
  paymentMethods.find((pm) => pm.id === method)?.name || 'Efectivo';

const translateExpenseError = (err: any): string => {
  const rawMessage = String(err?.message || err || '');
  const code = String(err?.code || rawMessage.split(':')[0] || '').trim();

  if (code === 'ADMIN_ONLY_ACTION' || rawMessage.includes('ADMIN_ONLY_ACTION')) {
    return 'Solo el Administrador puede registrar o consultar gastos OPEX.';
  }
  if (code === 'INSUFFICIENT_CHANNEL_FUNDS' || code === 'INSUFFICIENT_FUNDS' || rawMessage.includes('INSUFFICIENT')) {
    return rawMessage.replace(/^INSUFFICIENT_(?:CHANNEL_)?FUNDS:\s*/i, '') || 'Fondos insuficientes en el canal seleccionado.';
  }
  if (code === 'SHIFT_EXPIRED_24H' || code === 'SESSION_EXPIRED' || rawMessage.includes('EXPIRED')) {
    return 'El turno superó las 24 horas y debe cerrarse antes de registrar gastos.';
  }
  if (code === 'NO_OPEN_SESSION' || rawMessage.includes('NO_OPEN_SESSION')) {
    return 'No existe un turno de caja abierto para registrar gastos.';
  }
  if (code === 'INVALID_OPEX_CATEGORY' || rawMessage.includes('INVALID_OPEX_CATEGORY')) {
    return 'Categoría OPEX no autorizada.';
  }
  return rawMessage || 'No se pudo registrar el gasto OPEX.';
};

const loadExpenses = async () => {
  if (!authStore.isAdmin) {
    loadError.value = 'Solo el Administrador puede consultar gastos OPEX.';
    expenses.value = [];
    totalOpexExpenses.value = 0;
    expenseCount.value = 0;
    return;
  }

  if (!props.isOpen || !props.sessionId) {
    expenses.value = [];
    totalOpexExpenses.value = 0;
    expenseCount.value = 0;
    loadError.value = null;
    return;
  }

  isLoading.value = true;
  loadError.value = null;

  try {
    const res = await cashRepository.getSessionOpexExpenses(props.sessionId);
    expenses.value = res.data;
    totalOpexExpenses.value = res.total_opex_expenses;
    expenseCount.value = res.count;
  } catch (e: any) {
    loadError.value = translateExpenseError(e);
    expenses.value = [];
    totalOpexExpenses.value = 0;
    expenseCount.value = 0;
  } finally {
    isLoading.value = false;
  }
};

const openModal = () => {
  submitError.value = null;
  fieldErrors.value = { amount: null, description: null };
  newExpense.value = {
    amount: 0,
    description: '',
    category: 'Servicios',
    paymentMethod: 'efectivo',
    voucherRef: '',
  };
  showAddModal.value = true;
};

const validateFields = (): boolean => {
  const amountVal = Number(newExpense.value.amount);
  const descVal = newExpense.value.description.trim();

  fieldErrors.value = {
    amount: !Number.isFinite(amountVal) || amountVal <= 0 ? 'Ingresa un monto positivo mayor a cero.' : null,
    description: descVal.length < 3 ? 'Ingresa un concepto de al menos 3 caracteres.' : null,
  };

  return !fieldErrors.value.amount && !fieldErrors.value.description;
};

const handleSubmit = async () => {
  submitError.value = null;
  if (!validateFields()) {
    return;
  }

  const res = await executeExpense(
    async () => {
      try {
        const opexRes = await cashRegisterStore.registerExpense(
          new Decimal(newExpense.value.amount),
          newExpense.value.description.trim(),
          newExpense.value.category,
          newExpense.value.paymentMethod,
          newExpense.value.paymentMethod !== 'efectivo'
            ? newExpense.value.voucherRef.trim() || undefined
            : undefined
        );

        if (opexRes && typeof opexRes.total_opex_expenses === 'number') {
          expenses.value = opexRes.data;
          totalOpexExpenses.value = opexRes.total_opex_expenses;
          expenseCount.value = opexRes.count;
        } else {
          await loadExpenses();
        }

        showAddModal.value = false;
        showSuccess('Gasto OPEX registrado correctamente');
        return true;
      } catch (err: any) {
        const translated = translateExpenseError(err);
        submitError.value = translated;
        throw new Error(translated);
      }
    },
    {
      checkConnectivity: true,
      showSuccessToast: false,
      errorMessage: 'Error al registrar el gasto OPEX',
    }
  );

  if (res === null && !navigator.onLine) {
    submitError.value = 'Se requiere conexión a internet para registrar gastos OPEX.';
  }
};

watch(
  () => [props.sessionId, props.isOpen] as const,
  () => {
    loadExpenses();
  }
);

onMounted(() => {
  loadExpenses();
});
</script>

<template>
  <section class="space-y-4">
    <!-- Caja Cerrada (N3) -->
    <div
      v-if="!isOpen || !sessionId"
      data-test="expenses-closed-banner"
      class="bg-amber-50 dark:bg-amber-900/20 border border-amber-300 dark:border-amber-700 rounded-2xl p-4 flex items-start gap-3"
    >
      <Lock :size="20" class="text-amber-600 dark:text-amber-400 shrink-0 mt-0.5" />
      <div>
        <h3 class="text-sm font-bold text-amber-900 dark:text-amber-200">Caja Cerrada</h3>
        <p class="text-xs text-amber-800 dark:text-amber-300 mt-1">
          Abre la caja en la pestaña Turno para registrar o consultar gastos OPEX.
        </p>
      </div>
    </div>

    <!-- Loading (Skeleton) -->
    <BaseListSkeleton v-else-if="isLoading" :count="4" type="simple" />

    <!-- Error Persistente N3 + Reintentar -->
    <div
      v-else-if="loadError"
      data-test="expenses-error-banner"
      class="bg-rose-50 dark:bg-rose-950/30 border border-rose-300 dark:border-rose-800 rounded-2xl p-4 flex items-center justify-between gap-3"
    >
      <div class="flex items-start gap-3">
        <AlertTriangle :size="20" class="text-rose-600 dark:text-rose-400 shrink-0 mt-0.5" />
        <p class="text-xs font-medium text-rose-800 dark:text-rose-200">{{ loadError }}</p>
      </div>
      <BaseButton size="sm" variant="outline" @click="loadExpenses">
        <span class="flex items-center gap-1.5">
          <RefreshCw :size="14" />
          Reintentar
        </span>
      </BaseButton>
    </div>

    <!-- Contenido Autoritativo OPEX -->
    <template v-else>
      <div class="bg-surface-light dark:bg-surface-dark rounded-2xl p-5 border border-slate-200 dark:border-slate-700 shadow-sm flex items-center justify-between gap-4">
        <div>
          <p class="text-xs font-bold uppercase tracking-wide text-slate-500 dark:text-slate-400">
            Total Gastos OPEX del Turno
          </p>
          <p
            data-test="total-opex-expenses"
            class="text-2xl font-black text-rose-600 dark:text-rose-400 font-mono tabular-nums mt-1"
          >
            {{ formatCurrency(totalOpexExpenses) }}
          </p>
          <p class="text-[11px] text-slate-400 mt-0.5">
            {{ expenseCount }} registro(s) OPEX verificados en servidor
          </p>
        </div>

        <BaseButton
          type="button"
          variant="danger"
          data-test="btn-register-expense"
          @click="openModal"
        >
          <span class="flex items-center gap-1.5 text-xs font-bold">
            <Plus :size="16" />
            + Registrar Gasto
          </span>
        </BaseButton>
      </div>

      <!-- Empty State -->
      <div
        v-if="expenses.length === 0"
        class="bg-surface-light dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-slate-700 p-8 text-center text-slate-400"
      >
        <Receipt :size="40" :stroke-width="1.25" class="mx-auto mb-2 opacity-40" />
        <p class="text-sm font-semibold text-slate-700 dark:text-slate-200">
          Sin gastos OPEX en este turno
        </p>
        <p class="text-xs text-slate-500 mt-1">
          Usa "+ Registrar Gasto" para asentar egresos operativos autorizados.
        </p>
      </div>

      <!-- Lista OPEX -->
      <div v-else class="space-y-2.5">
        <div
          v-for="expense in expenses"
          :key="expense.id"
          class="bg-surface-light dark:bg-surface-dark p-4 rounded-2xl border border-slate-200 dark:border-slate-700 shadow-sm flex justify-between items-start gap-3"
        >
          <div class="min-w-0 space-y-1">
            <p class="text-sm font-bold text-slate-900 dark:text-white break-words">
              {{ expense.description }}
            </p>
            <div class="flex flex-wrap items-center gap-1.5">
              <span class="text-[10px] px-2 py-0.5 rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 font-bold uppercase tracking-wide">
                {{ expense.category }}
              </span>
              <span class="text-[10px] px-2 py-0.5 rounded-lg bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 font-semibold">
                {{ channelLabel(expense.payment_method) }}
              </span>
              <span v-if="expense.voucher_ref" class="text-[10px] text-slate-500 dark:text-slate-400 font-mono">
                Ref: {{ expense.voucher_ref }}
              </span>
            </div>
            <p class="text-[11px] text-slate-400 flex items-center gap-1">
              <User :size="12" /> {{ expense.actor_name }} ·
              {{ new Date(expense.created_at).toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit' }) }}
            </p>
          </div>
          <span class="text-sm font-bold text-rose-600 dark:text-rose-400 font-mono tabular-nums shrink-0">
            -{{ formatCurrency(expense.amount) }}
          </span>
        </div>
      </div>
    </template>

    <!-- Hoja Transaccional Arquetipo D (BaseModal) -->
    <BaseModal
      v-model="showAddModal"
      title="Registrar Gasto OPEX"
      :show-close-button="true"
      data-test="expense-create-modal"
    >
      <div class="px-4 pb-6 space-y-4">
        <div
          v-if="submitError"
          data-test="expense-submit-error"
          class="rounded-xl border border-rose-300 dark:border-rose-700 bg-rose-50 dark:bg-rose-950/30 p-3 flex items-start gap-2.5 text-xs text-rose-800 dark:text-rose-200"
        >
          <AlertTriangle :size="16" class="text-rose-600 dark:text-rose-400 shrink-0 mt-0.5" />
          <span>{{ submitError }}</span>
        </div>

        <div>
          <label class="block text-xs font-bold uppercase text-slate-500 dark:text-slate-400 mb-1">
            Monto
          </label>
          <div class="rounded-xl border px-3 py-2 bg-background-light dark:bg-background-dark"
               :class="fieldErrors.amount ? 'border-rose-400' : 'border-slate-300 dark:border-slate-600'">
            <FormInputCurrency
              v-model="newExpense.amount"
              placeholder="0"
              class="text-2xl font-bold font-mono tabular-nums"
              :autofocus="true"
              @update:modelValue="fieldErrors.amount = null"
            />
          </div>
          <p v-if="fieldErrors.amount" data-test="error-expense-amount" class="mt-1 text-xs text-rose-600 dark:text-rose-400">
            {{ fieldErrors.amount }}
          </p>
        </div>

        <div>
          <BaseInput
            id="expense-description"
            v-model="newExpense.description"
            label="Concepto"
            placeholder="Ej. Pago recibo de energía eléctrica"
            :error="fieldErrors.description ?? undefined"
            @update:modelValue="fieldErrors.description = null"
          />
        </div>

        <div>
          <label class="block text-xs font-bold uppercase text-slate-500 dark:text-slate-400 mb-1.5">
            Medio de Pago
          </label>
          <div class="flex gap-2">
            <button
              v-for="pm in paymentMethods"
              :key="pm.id"
              type="button"
              @click="newExpense.paymentMethod = pm.id"
              class="flex-1 py-2 px-2 rounded-xl text-xs font-bold border transition-colors text-center"
              :class="
                newExpense.paymentMethod === pm.id
                  ? 'bg-rose-600 border-rose-600 text-white'
                  : 'bg-surface-light dark:bg-surface-dark border-slate-200 dark:border-slate-600 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800'
              "
            >
              {{ pm.name }}
            </button>
          </div>
        </div>

        <div v-if="newExpense.paymentMethod !== 'efectivo'">
          <BaseInput
            v-model="newExpense.voucherRef"
            label="Referencia / Comprobante (Opcional)"
            placeholder="Ej. Comprobante Nequi #4821"
          />
        </div>

        <div>
          <label class="block text-xs font-bold uppercase text-slate-500 dark:text-slate-400 mb-1.5">
            Categoría OPEX
          </label>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="cat in categories"
              :key="cat"
              type="button"
              @click="newExpense.category = cat"
              class="px-3 py-1.5 rounded-full text-xs font-bold border transition-colors"
              :class="
                newExpense.category === cat
                  ? 'bg-rose-600 border-rose-600 text-white'
                  : 'bg-surface-light dark:bg-surface-dark border-slate-200 dark:border-slate-600 text-slate-600 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800'
              "
            >
              {{ cat }}
            </button>
          </div>
        </div>

        <BaseButton
          type="button"
          variant="danger"
          class="w-full mt-2"
          data-test="btn-confirm-expense"
          :disabled="isSubmitting"
          :loading="isSubmitting"
          @click="handleSubmit"
        >
          CONFIRMAR GASTO OPEX
        </BaseButton>
      </div>
    </BaseModal>
  </section>
</template>

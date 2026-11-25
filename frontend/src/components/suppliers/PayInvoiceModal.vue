<template>
  <BaseModal
    :modelValue="show"
    @update:modelValue="(val) => { if (!val) close(); }"
    title="Registrar Abono a Proveedor"
    :showCloseButton="true"
    maxHeight="90vh"
  >
    <div class="p-4 space-y-4">
      <!-- Read Model Factura (Autoridad SQL) -->
      <div class="text-sm text-slate-600 dark:text-slate-300 bg-background-light dark:bg-background-dark p-3.5 rounded-xl border border-slate-200 dark:border-slate-800 space-y-1">
        <p class="font-semibold text-slate-800 dark:text-slate-100">
          Factura de: {{ invoice?.supplier?.name || 'Desconocido' }}
        </p>
        <p class="flex items-center justify-between text-xs">
          <span>Total de la factura</span>
          <span class="font-mono tabular-nums font-medium text-slate-700 dark:text-slate-200">
            {{ formatCurrency(invoice?.total_amount || 0) }}
          </span>
        </p>
        <p class="flex items-center justify-between pt-1.5 border-t border-slate-200 dark:border-slate-800">
          <span class="text-sm font-bold text-slate-700 dark:text-slate-200">Saldo Pendiente</span>
          <span class="font-mono tabular-nums text-base font-black text-slate-900 dark:text-white">
            {{ formatCurrency(pendingBalance) }}
          </span>
        </p>
      </div>

      <!-- Banner N3 Turno Cerrado / Expirado +24h -->
      <div
        v-if="(!cashRegisterStore.isOpen || cashRegisterStore.isStaleSession) && paymentMethod !== 'externo'"
        class="p-3 bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800/60 rounded-xl flex items-start gap-2.5"
      >
        <Info :size="16" class="text-amber-600 dark:text-amber-400 shrink-0 mt-0.5" />
        <p class="text-xs text-amber-800 dark:text-amber-300 font-medium">
          {{ cashRegisterStore.isStaleSession ? 'El turno de caja superó 24 horas.' : 'Turno de caja cerrado.' }} Puedes registrar el abono seleccionando <strong>Pago externo / fuera de caja</strong> ($0 en caja).
        </p>
      </div>

      <!-- Monto a abonar -->
      <div class="relative">
        <BaseInput
          v-model.number="amountToPay"
          label="¿Cuánto deseas abonar?"
          type="number"
          placeholder="0"
          class="pr-24 font-mono tabular-nums"
          :max="pendingBalance"
          min="0"
          step="1"
          :disabled="isSubmitting"
        />
        <button
          type="button"
          @click="payFullAmount"
          class="absolute right-2 top-[34px] text-xs font-bold text-primary hover:text-primary-dark transition-colors px-2 py-1.5 rounded-md hover:bg-primary-light/20 z-10 cursor-pointer"
          :disabled="isSubmitting"
        >
          TOTALIDAD
        </button>
      </div>

      <!-- Validación N1: supera saldo pendiente -->
      <div v-if="amountExceedsPending" class="text-xs text-red-600 dark:text-red-400 font-semibold">
        El abono no puede superar la deuda pendiente.
      </div>

      <!-- Validación N1 estricta: Saldo insuficiente del canal -->
      <div
        v-if="isInternalPayment && amountExceedsChannel && !amountExceedsPending"
        data-testid="insufficient-channel-balance-alert"
        class="bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800/60 p-3 rounded-xl flex items-start gap-2.5"
      >
        <Ban :size="16" class="text-red-600 dark:text-red-400 shrink-0 mt-0.5" />
        <p class="text-xs text-red-700 dark:text-red-300 font-medium">
          Saldo insuficiente en {{ selectedChannelLabel }} (<span class="font-mono tabular-nums">Disponible: {{ formatCurrency(selectedChannelBalance) }}</span>). No se permiten sobregiros.
        </p>
      </div>

      <!-- Error del servidor (N1/N3 persistente en modal) -->
      <div
        v-if="errorMessage"
        role="alert"
        class="text-xs font-medium text-red-700 dark:text-red-300 bg-red-50 dark:bg-red-950/30 p-3 rounded-xl border border-red-200 dark:border-red-800/60"
      >
        {{ errorMessage }}
      </div>

      <!-- Selector Método de Pago -->
      <div>
        <label class="block text-xs font-bold uppercase tracking-wider text-slate-600 dark:text-slate-300 mb-2">
          Método de Pago
        </label>
        <div class="grid grid-cols-4 gap-2">
          <button
            type="button"
            data-testid="pay-method-efectivo"
            @click="paymentMethod = 'efectivo'"
            :class="paymentMethod === 'efectivo' ? 'bg-primary text-white border-primary shadow-sm' : 'bg-background-light dark:bg-background-dark text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800'"
            class="flex flex-col items-center justify-center p-2.5 rounded-xl border transition-all cursor-pointer"
          >
            <Banknote :size="20" :stroke-width="1.5" class="mb-1" />
            <span class="text-[11px] font-semibold">Efectivo</span>
          </button>
          <button
            type="button"
            data-testid="pay-method-nequi"
            @click="paymentMethod = 'nequi'"
            :class="paymentMethod === 'nequi' ? 'bg-[#4A148C] text-white border-[#4A148C] shadow-sm' : 'bg-background-light dark:bg-background-dark text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800'"
            class="flex flex-col items-center justify-center p-2.5 rounded-xl border transition-all cursor-pointer"
          >
            <Smartphone :size="20" :stroke-width="1.5" class="mb-1" />
            <span class="text-[11px] font-semibold">Nequi</span>
          </button>
          <button
            type="button"
            data-testid="pay-method-llave_bre"
            @click="paymentMethod = 'llave_bre'"
            :class="paymentMethod === 'llave_bre' ? 'bg-teal-600 text-white border-teal-600 shadow-sm' : 'bg-background-light dark:bg-background-dark text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800'"
            class="flex flex-col items-center justify-center p-2.5 rounded-xl border transition-all cursor-pointer"
          >
            <CreditCard :size="20" :stroke-width="1.5" class="mb-1" />
            <span class="text-[11px] font-semibold">Llave Bre-B</span>
          </button>
          <button
            type="button"
            data-testid="pay-method-externo"
            @click="paymentMethod = 'externo'"
            :class="paymentMethod === 'externo' ? 'bg-emerald-600 text-white border-emerald-600 shadow-sm' : 'bg-background-light dark:bg-background-dark text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800'"
            class="flex flex-col items-center justify-center p-2.5 rounded-xl border transition-all cursor-pointer"
          >
            <Wallet :size="20" :stroke-width="1.5" class="mb-1" />
            <span class="text-[10px] font-semibold leading-tight text-center">Pago externo / fuera de caja</span>
          </button>
        </div>
      </div>

      <!-- Descripción / Nota -->
      <div>
        <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
          {{ isInternalPayment ? 'Descripción del egreso en caja (Obligatorio)' : 'Nota o comprobante externo (Opcional)' }}
        </label>
        <input
          v-model="description"
          data-testid="pay-invoice-description-input"
          type="text"
          :disabled="isSubmitting"
          :placeholder="isInternalPayment ? 'Ej. Abono parcial factura semanal' : 'Ej. Pagado con cuenta personal del dueño'"
          class="w-full h-11 px-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-background-light dark:bg-background-dark text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-primary outline-none"
        />
        <p v-if="isInternalPayment" class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">
          Disponible en {{ selectedChannelLabel }}:
          <strong class="font-mono tabular-nums">{{ formatCurrency(selectedChannelBalance) }}</strong>
        </p>
      </div>
    </div>

    <template #footer>
      <div class="p-4 pt-2 border-t border-slate-100 dark:border-slate-800 flex gap-3">
        <BaseButton
          variant="secondary"
          @click="close"
          class="flex-1"
          :disabled="isSubmitting"
        >
          Cancelar
        </BaseButton>
        <BaseButton
          @click="submitPayment"
          class="flex-1"
          :disabled="!canSubmit || isSubmitting"
          :loading="isSubmitting"
        >
          {{ isSubmitting ? 'Procesando...' : 'Confirmar Abono' }}
        </BaseButton>
      </div>
    </template>
  </BaseModal>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useCashRegisterStore } from '@/stores/cashRegister';
import { usePayablesStore, type SupplierInvoice } from '@/stores/payables';
import { useCurrencyFormat } from '@/composables/useCurrencyFormat';
import { useNotifications } from '@/composables/useNotifications';
import BaseModal from '@/components/ui/BaseModal.vue';
import BaseInput from '@/components/ui/BaseInput.vue';
import BaseButton from '@/components/ui/BaseButton.vue';
import { Banknote, Smartphone, CreditCard, Wallet, Info, Ban } from 'lucide-vue-next';

const props = defineProps<{
  show: boolean;
  invoice: SupplierInvoice | null;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'success'): void;
}>();

const { formatCurrency } = useCurrencyFormat();
const { showSuccess } = useNotifications();
const authStore = useAuthStore();
const cashRegisterStore = useCashRegisterStore();
const payablesStore = usePayablesStore();

const amountToPay = ref<number | ''>('');
const paymentMethod = ref(cashRegisterStore.isOpen && !cashRegisterStore.isStaleSession ? 'efectivo' : 'externo');
const description = ref('');
const isSubmitting = ref(false);
const errorMessage = ref<string | null>(null);

watch(
  () => props.show,
  async (isOpen) => {
    if (!isOpen) return;
    errorMessage.value = null;
    const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
    if (storeId && typeof (cashRegisterStore as any).syncFromBackend === 'function') {
      await (cashRegisterStore as any).syncFromBackend(storeId);
    }
    paymentMethod.value = cashRegisterStore.isOpen && !cashRegisterStore.isStaleSession ? 'efectivo' : 'externo';
  },
  { immediate: true }
);

const isInternalPayment = computed(() => paymentMethod.value !== 'externo');

const selectedChannelLabel = computed(() => {
  switch (paymentMethod.value) {
    case 'efectivo':
      return 'Efectivo';
    case 'nequi':
      return 'Nequi';
    case 'llave_bre':
      return 'Llave Bre-B';
    default:
      return 'Externo';
  }
});

const selectedChannelBalance = computed(() => {
  if (paymentMethod.value === 'externo') return Number.POSITIVE_INFINITY;
  const byMethod = (cashRegisterStore as any).balancesByMethod as Record<string, any> | undefined;
  if (byMethod && Object.keys(byMethod).length > 0) {
    const val = byMethod[paymentMethod.value];
    return val ? Number(val) : 0;
  }
  if (paymentMethod.value === 'efectivo') {
    return Number(cashRegisterStore.currentBalance ?? 0);
  }
  return 0;
});

const pendingBalance = computed(() => {
  if (!props.invoice) return 0;
  return Number(props.invoice.pending_balance ?? 0);
});

const amountExceedsPending = computed(() => {
  return Number(amountToPay.value) > pendingBalance.value;
});

const amountExceedsChannel = computed(() => {
  if (!isInternalPayment.value) return false;
  return Number(amountToPay.value) > selectedChannelBalance.value;
});

const canSubmit = computed(() => {
  if (!authStore.isAdmin) return false;
  const amount = Number(amountToPay.value);
  if (amount <= 0 || amountExceedsPending.value) return false;
  if (!isInternalPayment.value) return true;
  if (!cashRegisterStore.isOpen || cashRegisterStore.isStaleSession) return false;
  if (!description.value.trim()) return false;
  if (amountExceedsChannel.value) return false;
  return true;
});

const payFullAmount = () => {
  amountToPay.value = pendingBalance.value;
};

const resetForm = () => {
  amountToPay.value = '';
  description.value = '';
  paymentMethod.value = cashRegisterStore.isOpen && !cashRegisterStore.isStaleSession ? 'efectivo' : 'externo';
  errorMessage.value = null;
};

const close = () => {
  if (isSubmitting.value) return;
  resetForm();
  emit('close');
};

const submitPayment = async () => {
  if (!props.invoice || !canSubmit.value) return;

  isSubmitting.value = true;
  errorMessage.value = null;

  const cleanDescription = description.value.trim() || undefined;
  const { success, error } = await payablesStore.payInvoice(
    props.invoice.id,
    Number(amountToPay.value),
    paymentMethod.value,
    cleanDescription
  );

  isSubmitting.value = false;
  if (success) {
    showSuccess('Abono registrado correctamente');
    resetForm();
    emit('success');
    emit('close');
  } else {
    errorMessage.value = error || 'Error al registrar abono';
  }
};
</script>

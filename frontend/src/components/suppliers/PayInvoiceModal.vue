<template>
  <div v-if="show" class="fixed inset-0 z-50 flex items-end justify-center" aria-labelledby="modal-title" role="dialog" aria-modal="true">
    <!-- Backdrop -->
    <div class="fixed inset-0 transition-opacity bg-black/50" aria-hidden="true" @click="close"></div>
    
    <!-- Bottom Sheet -->
    <div class="bg-white dark:bg-slate-800 rounded-t-3xl w-full max-w-lg p-6 animate-slide-up relative z-10">
      <div class="mb-4">
        <h3 class="text-xl font-bold text-slate-900 dark:text-white" id="modal-title">
          Registrar Abono a Proveedor
        </h3>
        
        <div class="mt-3 text-sm text-slate-500 dark:text-slate-400 bg-slate-50 dark:bg-slate-900/50 p-3 rounded-xl border border-slate-100 dark:border-slate-800">
          <p class="font-medium text-slate-700 dark:text-slate-300 mb-1">Factura de: {{ invoice?.supplier?.name || 'Desconocido' }}</p>
          <p>Total de la factura: {{ formatCurrency(invoice?.total_amount || 0) }}</p>
          <p class="text-base font-bold mt-2 text-slate-900 dark:text-white">Saldo Pendiente: {{ formatCurrency(pendingBalance) }}</p>
        </div>
      </div>

      <div v-if="(!cashRegisterStore.isOpen || cashRegisterStore.isStaleSession) && paymentMethod !== 'externo'" class="mb-4 p-3 bg-amber-50 dark:bg-amber-900/20 border-l-4 border-amber-500 rounded-r-xl">
        <p class="text-xs text-amber-700 dark:text-amber-400 font-medium">
          ℹ️ {{ cashRegisterStore.isStaleSession ? 'El turno de caja superó 24 horas.' : 'Turno de caja cerrado.' }} Puedes registrar el abono seleccionando <strong>Pago externo / fuera de caja</strong> ($0 en caja).
        </p>
      </div>

      <div class="space-y-4">
        <div class="relative">
          <BaseInput
            v-model.number="amountToPay"
            label="¿Cuánto deseas abonar?"
            type="number"
            placeholder="0"
            class="pr-24"
            :max="pendingBalance"
            min="0"
            step="1"
            :disabled="isSubmitting"
          />
          <button
            type="button"
            @click="payFullAmount"
            class="absolute right-2 top-[34px] text-xs font-bold text-primary hover:text-primary-dark transition-colors px-2 py-1.5 rounded-md hover:bg-primary-light/20 z-10"
            :disabled="isSubmitting"
          >
            TOTALIDAD
          </button>
        </div>
        
        <!-- Error Exceeds Pending Balance -->
        <div v-if="amountExceedsPending" class="text-sm text-red-600 dark:text-red-400 font-medium animate-pulse">
          El abono no puede superar la deuda pendiente.
        </div>

        <!-- Strict Error on Insufficient Channel Balance (No Soft Overdraft) -->
        <div
          v-if="isInternalPayment && amountExceedsChannel && !amountExceedsPending"
          data-testid="insufficient-channel-balance-alert"
          class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800/50 p-3 rounded-xl flex items-start gap-2"
        >
          <span class="text-red-500 text-lg leading-none">🚫</span>
          <p class="text-xs text-red-700 dark:text-red-400 font-medium">
            Saldo insuficiente en {{ selectedChannelLabel }} (Disponible: {{ formatCurrency(selectedChannelBalance) }}). No se permiten sobregiros.
          </p>
        </div>

        <div v-if="errorMessage" class="text-sm text-red-600 dark:text-red-400 bg-red-50 dark:bg-red-900/20 p-3 rounded-xl border border-red-200 dark:border-red-800/50">
          {{ errorMessage }}
        </div>

        <!-- Método de Pago Selector -->
        <div class="mt-4">
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">Método de Pago</label>
            <div class="grid grid-cols-4 gap-2">
                <button
                    type="button"
                    data-testid="pay-method-efectivo"
                    @click="paymentMethod = 'efectivo'"
                    :class="paymentMethod === 'efectivo' ? 'bg-primary text-white border-primary shadow-sm' : 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-slate-100 dark:bg-slate-800 dark:text-slate-400 dark:border-slate-700'"
                    class="flex flex-col items-center justify-center p-2.5 rounded-xl border transition-all"
                >
                    <Banknote :size="20" :stroke-width="1.5" class="mb-1" />
                    <span class="text-[11px] font-semibold">Efectivo</span>
                </button>
                <button
                    type="button"
                    data-testid="pay-method-nequi"
                    @click="paymentMethod = 'nequi'"
                    :class="paymentMethod === 'nequi' ? 'bg-[#4A148C] text-white border-[#4A148C] shadow-sm' : 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-slate-100 dark:bg-slate-800 dark:text-slate-400 dark:border-slate-700'"
                    class="flex flex-col items-center justify-center p-2.5 rounded-xl border transition-all"
                >
                    <Smartphone :size="20" :stroke-width="1.5" class="mb-1" />
                    <span class="text-[11px] font-semibold">Nequi</span>
                </button>
                <button
                    type="button"
                    data-testid="pay-method-llave_bre"
                    @click="paymentMethod = 'llave_bre'"
                    :class="paymentMethod === 'llave_bre' ? 'bg-teal-600 text-white border-teal-600 shadow-sm' : 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-slate-100 dark:bg-slate-800 dark:text-slate-400 dark:border-slate-700'"
                    class="flex flex-col items-center justify-center p-2.5 rounded-xl border transition-all"
                >
                    <CreditCard :size="20" :stroke-width="1.5" class="mb-1" />
                    <span class="text-[11px] font-semibold">Llave Bre-B</span>
                </button>
                <button
                    type="button"
                    data-testid="pay-method-externo"
                    @click="paymentMethod = 'externo'"
                    :class="paymentMethod === 'externo' ? 'bg-emerald-600 text-white border-emerald-600 shadow-sm' : 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-slate-100 dark:bg-slate-800 dark:text-slate-400 dark:border-slate-700'"
                    class="flex flex-col items-center justify-center p-2.5 rounded-xl border transition-all"
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
            class="w-full h-11 px-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-primary outline-none"
          />
          <p v-if="isInternalPayment" class="text-[11px] text-slate-400 mt-1">
            Disponible en {{ selectedChannelLabel }}: <strong>{{ formatCurrency(selectedChannelBalance) }}</strong>
          </p>
        </div>
      </div>
      
      <div class="flex gap-3 mt-6">
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
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useCashRegisterStore } from '@/stores/cashRegister';
import { usePayablesStore, type SupplierInvoice } from '@/stores/payables';
import { useCurrencyFormat } from '@/composables/useCurrencyFormat';
import BaseInput from '@/components/ui/BaseInput.vue';
import BaseButton from '@/components/ui/BaseButton.vue';
import { useToast } from 'vue-toastification';
import { Banknote, Smartphone, CreditCard, Wallet } from 'lucide-vue-next';

const props = defineProps<{
  show: boolean;
  invoice: SupplierInvoice | null;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'success'): void;
}>();

const { formatCurrency } = useCurrencyFormat();
const toast = useToast();
const authStore = useAuthStore();
const cashRegisterStore = useCashRegisterStore();
const payablesStore = usePayablesStore();

const amountToPay = ref<number | ''>('');
const paymentMethod = ref(cashRegisterStore.isOpen && !cashRegisterStore.isStaleSession ? 'efectivo' : 'externo');
const description = ref('');
const isSubmitting = ref(false);
const errorMessage = ref<string | null>(null);

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
  return props.invoice.total_amount - props.invoice.amount_paid;
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

const close = () => {
  if (isSubmitting.value) return;
  amountToPay.value = '';
  description.value = '';
  paymentMethod.value = cashRegisterStore.isOpen && !cashRegisterStore.isStaleSession ? 'efectivo' : 'externo';
  errorMessage.value = null;
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
  
  if (success) {
    toast.success('Abono registrado correctamente');
    setTimeout(() => {
      isSubmitting.value = false;
      emit('success');
      close();
    }, 400);
  } else {
    errorMessage.value = error || 'Error al registrar abono';
    isSubmitting.value = false;
  }
};
</script>

<style scoped>
.animate-slide-up {
  animation: slideUp 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

@keyframes slideUp {
  from {
    transform: translateY(100%);
  }
  to {
    transform: translateY(0);
  }
}
</style>

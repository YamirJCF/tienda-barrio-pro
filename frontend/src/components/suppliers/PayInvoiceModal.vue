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

      <div v-if="!cashRegisterStore.isOpen" class="mb-6 p-4 bg-red-50 dark:bg-red-900/20 border-l-4 border-red-500 rounded-r-xl">
        <p class="text-sm text-red-700 dark:text-red-400 font-medium">
          ⛔ Debes tener un turno de caja abierto para registrar un pago.
        </p>
      </div>

      <div v-else class="space-y-4">
        <div class="relative">
          <BaseInput
            v-model.number="amountToPay"
            label="¿Cuánto deseas abonar de la caja actual?"
            type="number"
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

        <!-- Soft Warning Exceeds Cash -->
        <div v-if="amountExceedsCash && !amountExceedsPending" class="bg-orange-50 dark:bg-amber-900/20 border border-orange-200 dark:border-amber-800/50 p-3 rounded-xl flex items-start gap-2">
          <span class="text-orange-500 dark:text-amber-500 text-lg leading-none">⚠️</span>
          <p class="text-xs text-orange-700 dark:text-amber-400 font-medium">
            Este abono dejará el saldo de la caja en negativo. Deberás justificar el faltante en el cierre.
          </p>
        </div>

        <div v-if="errorMessage" class="text-sm text-red-600 dark:text-red-400 bg-red-50 dark:bg-red-900/20 p-3 rounded-xl border border-red-200 dark:border-red-800/50">
          {{ errorMessage }}
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
import { formatCurrency } from '@/utils/currency';
import BaseInput from '@/components/ui/BaseInput.vue';
import BaseButton from '@/components/ui/BaseButton.vue';

const props = defineProps<{
  show: boolean;
  invoice: SupplierInvoice | null;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'success'): void;
}>();

const authStore = useAuthStore();
const cashRegisterStore = useCashRegisterStore();
const payablesStore = usePayablesStore();

const amountToPay = ref<number | ''>('');
const isSubmitting = ref(false);
const errorMessage = ref<string | null>(null);

const pendingBalance = computed(() => {
  if (!props.invoice) return 0;
  return props.invoice.total_amount - props.invoice.amount_paid;
});

const amountExceedsPending = computed(() => {
  return Number(amountToPay.value) > pendingBalance.value;
});

const amountExceedsCash = computed(() => {
  return Number(amountToPay.value) > Number(cashRegisterStore.currentBalance);
});

const canSubmit = computed(() => {
  return (
    authStore.isAdmin &&
    cashRegisterStore.isOpen &&
    Number(amountToPay.value) > 0 &&
    !amountExceedsPending.value
  );
});

const payFullAmount = () => {
  amountToPay.value = pendingBalance.value;
};

const close = () => {
  if (isSubmitting.value) return;
  amountToPay.value = '';
  errorMessage.value = null;
  emit('close');
};

const submitPayment = async () => {
  if (!props.invoice || !canSubmit.value) return;
  
  isSubmitting.value = true;
  errorMessage.value = null;
  
  const { success, error } = await payablesStore.payInvoice(props.invoice.id, Number(amountToPay.value));
  
  if (success) {
    isSubmitting.value = false;
    emit('success');
    close();
  } else {
    errorMessage.value = error;
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

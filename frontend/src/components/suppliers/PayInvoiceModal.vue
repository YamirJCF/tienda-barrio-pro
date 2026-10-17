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

      <div v-if="!cashRegisterStore.isOpen && paymentMethod !== 'externo'" class="mb-4 p-3 bg-amber-50 dark:bg-amber-900/20 border-l-4 border-amber-500 rounded-r-xl">
        <p class="text-xs text-amber-700 dark:text-amber-400 font-medium">
          ℹ️ Turno de caja cerrado. Puedes registrar el abono seleccionando <strong>Fondos Propios (Externo)</strong>.
        </p>
      </div>

      <div class="space-y-4">
        <div class="relative">
          <BaseInput
            v-model.number="amountToPay"
            label="¿Cuánto deseas abonar?"
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

        <!-- Strict Error on Insufficient Cash (No Soft Overdraft) -->
        <div v-if="paymentMethod === 'efectivo' && amountExceedsCash && !amountExceedsPending" class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800/50 p-3 rounded-xl flex items-start gap-2">
          <span class="text-red-500 text-lg leading-none">🚫</span>
          <p class="text-xs text-red-700 dark:text-red-400 font-medium">
            Saldo insuficiente en caja de efectivo (Disponible: {{ formatCurrency(Number(cashRegisterStore.currentBalance)) }}). No se permiten sobregiros.
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
                    @click="paymentMethod = 'efectivo'"
                    :class="paymentMethod === 'efectivo' ? 'bg-primary text-white border-primary shadow-sm' : 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-slate-100 dark:bg-slate-800 dark:text-slate-400 dark:border-slate-700'"
                    class="flex flex-col items-center justify-center p-2.5 rounded-xl border transition-all"
                >
                    <Banknote :size="20" :stroke-width="1.5" class="mb-1" />
                    <span class="text-[11px] font-semibold">Efectivo</span>
                </button>
                <button
                    type="button"
                    @click="paymentMethod = 'nequi'"
                    :class="paymentMethod === 'nequi' ? 'bg-[#4A148C] text-white border-[#4A148C] shadow-sm' : 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-slate-100 dark:bg-slate-800 dark:text-slate-400 dark:border-slate-700'"
                    class="flex flex-col items-center justify-center p-2.5 rounded-xl border transition-all"
                >
                    <Smartphone :size="20" :stroke-width="1.5" class="mb-1" />
                    <span class="text-[11px] font-semibold">Nequi</span>
                </button>
                <button
                    type="button"
                    @click="paymentMethod = 'daviplata'"
                    :class="paymentMethod === 'daviplata' ? 'bg-[#E32119] text-white border-[#E32119] shadow-sm' : 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-slate-100 dark:bg-slate-800 dark:text-slate-400 dark:border-slate-700'"
                    class="flex flex-col items-center justify-center p-2.5 rounded-xl border transition-all"
                >
                    <CreditCard :size="20" :stroke-width="1.5" class="mb-1" />
                    <span class="text-[11px] font-semibold">Daviplata</span>
                </button>
                <button
                    type="button"
                    @click="paymentMethod = 'externo'"
                    :class="paymentMethod === 'externo' ? 'bg-emerald-600 text-white border-emerald-600 shadow-sm' : 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-slate-100 dark:bg-slate-800 dark:text-slate-400 dark:border-slate-700'"
                    class="flex flex-col items-center justify-center p-2.5 rounded-xl border transition-all"
                >
                    <Wallet :size="20" :stroke-width="1.5" class="mb-1" />
                    <span class="text-[11px] font-semibold">Externo</span>
                </button>
            </div>
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
const paymentMethod = ref(cashRegisterStore.isOpen ? 'efectivo' : 'externo');
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
  if (!authStore.isAdmin) return false;
  const amount = Number(amountToPay.value);
  if (amount <= 0 || amountExceedsPending.value) return false;
  if (paymentMethod.value === 'externo') return true;
  if (!cashRegisterStore.isOpen) return false;
  if (paymentMethod.value === 'efectivo' && amountExceedsCash.value) return false;
  return true;
});

const payFullAmount = () => {
  amountToPay.value = pendingBalance.value;
};

const close = () => {
  if (isSubmitting.value) return;
  amountToPay.value = '';
  paymentMethod.value = cashRegisterStore.isOpen ? 'efectivo' : 'externo';
  errorMessage.value = null;
  emit('close');
};

const submitPayment = async () => {
  if (!props.invoice || !canSubmit.value) return;
  
  isSubmitting.value = true;
  errorMessage.value = null;
  
  const { success, error } = await payablesStore.payInvoice(props.invoice.id, Number(amountToPay.value), paymentMethod.value);
  
  if (success) {
    toast.success('Abono registrado correctamente');
    setTimeout(() => {
      isSubmitting.value = false;
      emit('success');
      close();
    }, 400);
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

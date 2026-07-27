<template>
  <div v-if="show" class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
    <div class="flex items-end justify-center min-h-screen px-4 pt-4 pb-20 text-center sm:block sm:p-0">
      <div class="fixed inset-0 transition-opacity bg-gray-500 bg-opacity-75" aria-hidden="true" @click="close"></div>
      
      <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>
      
      <div class="inline-block px-4 pt-5 pb-4 overflow-hidden text-left align-bottom transition-all transform bg-white rounded-lg shadow-xl sm:my-8 sm:align-middle sm:max-w-lg sm:w-full sm:p-6">
        <div>
          <div class="mt-3 text-center sm:mt-5">
            <h3 class="text-lg font-medium leading-6 text-gray-900" id="modal-title">
              Pagar Factura: {{ invoice?.invoice_number }}
            </h3>
            
            <div class="mt-2 text-sm text-gray-500">
              <p>Total: {{ formatCurrency(invoice?.total_amount || 0) }}</p>
              <p>Abonado: {{ formatCurrency(invoice?.amount_paid || 0) }}</p>
              <p class="font-bold">Saldo Pendiente: {{ formatCurrency(pendingBalance) }}</p>
            </div>
            
            <div class="mt-4 text-left">
              <label for="amount" class="block text-sm font-medium text-gray-700">Monto a Abonar</label>
              <div class="flex mt-1">
                <input
                  type="number"
                  name="amount"
                  id="amount"
                  v-model.number="amountToPay"
                  class="block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
                  :max="pendingBalance"
                  min="0"
                  step="1"
                  :disabled="isSubmitting"
                />
                <button
                  type="button"
                  @click="payFullAmount"
                  class="ml-2 inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-indigo-700 bg-indigo-100 hover:bg-indigo-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  :disabled="isSubmitting"
                >
                  Pagar Totalidad
                </button>
              </div>
              
              <div v-if="amountExceedsCash" class="mt-2 text-sm text-red-600 font-medium">
                ⚠️ El abono supera el efectivo actual en caja ({{ formatCurrency(cashRegisterStore.currentBalance) }})
              </div>

              <div v-if="errorMessage" class="mt-2 text-sm text-red-600 bg-red-50 p-2 rounded border border-red-200">
                {{ errorMessage }}
              </div>
            </div>
          </div>
        </div>
        <div class="mt-5 sm:mt-6 sm:flex sm:flex-row-reverse">
          <button
            type="button"
            class="inline-flex justify-center w-full px-4 py-2 text-base font-medium text-white bg-indigo-600 border border-transparent rounded-md shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
            @click="submitPayment"
            :disabled="!canSubmit || isSubmitting"
            :title="submitTitle"
          >
            <span v-if="isSubmitting" class="mr-2">⏳</span>
            Confirmar Pago
          </button>
          <button
            type="button"
            class="inline-flex justify-center w-full px-4 py-2 mt-3 text-base font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50"
            @click="close"
            :disabled="isSubmitting"
          >
            Cancelar
          </button>
        </div>
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

const amountToPay = ref<number>(0);
const isSubmitting = ref(false);
const errorMessage = ref<string | null>(null);

const pendingBalance = computed(() => {
  if (!props.invoice) return 0;
  return props.invoice.total_amount - props.invoice.amount_paid;
});

const amountExceedsCash = computed(() => {
  return amountToPay.value > Number(cashRegisterStore.currentBalance);
});

const canSubmit = computed(() => {
  return (
    authStore.isAdmin &&
    cashRegisterStore.isOpen &&
    amountToPay.value > 0 &&
    amountToPay.value <= pendingBalance.value
  );
});

const submitTitle = computed(() => {
  if (!authStore.isAdmin) return 'Requiere permisos de administrador';
  if (!cashRegisterStore.isOpen) return 'La caja registradora debe estar abierta';
  if (amountToPay.value <= 0) return 'Ingrese un monto mayor a 0';
  if (amountToPay.value > pendingBalance.value) return 'El monto supera el saldo pendiente';
  return 'Confirmar pago';
});

const payFullAmount = () => {
  amountToPay.value = pendingBalance.value;
};

const close = () => {
  if (isSubmitting.value) return;
  amountToPay.value = 0;
  errorMessage.value = null;
  emit('close');
};

const submitPayment = async () => {
  if (!props.invoice || !canSubmit.value) return;
  
  isSubmitting.value = true;
  errorMessage.value = null;
  
  const { success, error } = await payablesStore.payInvoice(props.invoice.id, amountToPay.value);
  
  if (success) {
    emit('success');
    close();
  } else {
    errorMessage.value = error;
    isSubmitting.value = false;
  }
};
</script>

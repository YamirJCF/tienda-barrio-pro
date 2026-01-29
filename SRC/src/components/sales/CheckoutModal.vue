<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useAuthStore } from '../../stores/auth';
import type { Client } from '../../stores/clients';
import Decimal from 'decimal.js';
import BaseModal from '../ui/BaseModal.vue';
import BaseInput from '../ui/BaseInput.vue';
import BaseButton from '../ui/BaseButton.vue';
import {
  Banknote,
  CreditCard,
  User,
  Trash2,
  Plus,
  AlertTriangle,
  CheckCircle2
} from 'lucide-vue-next';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import { useNotifications } from '../../composables/useNotifications';
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
  'complete': [payments: PaymentTransaction[], totalPaid: Decimal];
}>();

const { formatCurrency } = useCurrencyFormat();
const { showWarning } = useNotifications();

// State
const payments = ref<PaymentTransaction[]>([]);
const tempAmount = ref<string>('');
const tempMethod = ref<'cash' | 'nequi' | 'fiado'>('cash');
const tempReference = ref<string>('');

// Computed
const totalPaid = computed(() => {
  return payments.value.reduce((sum, p) => sum.plus(p.amount), new Decimal(0));
});

const remainingBalance = computed(() => {
  const diff = props.total.minus(totalPaid.value);
  return diff.isNegative() ? new Decimal(0) : diff;
});

const change = computed(() => {
  const diff = totalPaid.value.minus(props.total);
  return diff.isPositive() ? diff : new Decimal(0);
});

const isComplete = computed(() => {
  // Complete if total covered OR (Cash overflow allowed for change)
  return totalPaid.value.gte(props.total);
});

// Methods
const autoFillAmount = () => {
    // Fill with remaining amount if positive
    if (remainingBalance.value.gt(0)) {
        tempAmount.value = remainingBalance.value.toString();
    }
};

const addPayment = () => {
  if (!tempAmount.value) return;
  const amount = new Decimal(tempAmount.value);

  if (amount.lte(0)) {
    showWarning('El monto debe ser mayor a 0');
    return;
  }

  // Validation: Non-cash methods cannot exceed remaining balance
  if (tempMethod.value !== 'cash' && amount.gt(remainingBalance.value)) {
    showWarning(`El pago con ${tempMethod.value} no puede exceder el saldo restante (${formatCurrency(remainingBalance.value)})`);
    return;
  }

  // Validation: Fiado requires client
  if (tempMethod.value === 'fiado' && !props.selectedClient) {
    showWarning('Debes seleccionar un cliente para fiar');
    return;
  }
  
  // Validation: Nequi requires reference (Logic decision: Make optional or warn? Let's make it optional for speed, but encouraged)
  
  payments.value.push({
    method: tempMethod.value,
    amount: amount,
    reference: tempReference.value || undefined
  });

  // Reset temp form
  tempAmount.value = '';
  tempReference.value = '';
  
  // Auto-switch back to cash or stay? Stay for now.
  // If complete, maybe focus button?
};

const removePayment = (index: number) => {
  payments.value.splice(index, 1);
};

const handleComplete = () => {
  if (!isComplete.value) return;
  emit('complete', payments.value, totalPaid.value);
};

const close = () => {
  emit('update:modelValue', false);
};

// Watchers
watch(() => props.modelValue, (val) => {
  if (val) {
    // Reset on open
    payments.value = [];
    tempMethod.value = 'cash';
    tempReference.value = '';
    // Auto-prefill full amount for quick cash sale
    tempAmount.value = props.total.toString();
  }
});
</script>

<template>
  <BaseModal
    :modelValue="modelValue"
    title="Finalizar Venta"
    :max-width="'max-w-xl'"
    @update:modelValue="close"
  >
    <div class="p-6 space-y-6">
      <!-- SUMMARY CARD -->
      <div class="bg-slate-50 dark:bg-slate-800 rounded-2xl p-4 flex flex-col gap-2 border border-slate-200 dark:border-slate-700">
        <div class="flex justify-between items-center text-sm">
            <span class="text-slate-500 font-bold uppercase tracking-wider">Total Venta</span>
            <span class="text-slate-900 dark:text-white font-bold text-lg">{{ formatCurrency(total) }}</span>
        </div>
        
        <div class="h-px bg-slate-200 dark:bg-slate-700 my-1"></div>
        
        <div class="flex justify-between items-center">
            <span class="text-slate-500 font-bold">Pagado</span>
            <span class="text-emerald-600 font-bold">{{ formatCurrency(totalPaid) }}</span>
        </div>
        
        <div class="flex justify-between items-center text-xl mt-1">
             <span v-if="remainingBalance.gt(0)" class="text-blue-600 font-black">Falta</span>
             <span v-else class="text-emerald-500 font-black">Cambio</span>
             
             <span v-if="remainingBalance.gt(0)" class="text-blue-600 font-black">{{ formatCurrency(remainingBalance) }}</span>
             <span v-else class="text-emerald-500 font-black">{{ formatCurrency(change) }}</span>
        </div>
      </div>

      <!-- PAYMENTS LIST -->
      <div class="space-y-3 min-h-[100px]">
         <h3 class="text-xs font-bold text-slate-400 uppercase tracking-widest">Pagos Agregados</h3>
         
         <div v-if="payments.length === 0" class="text-center py-4 text-slate-400 text-sm italic border-2 border-dashed border-slate-200 dark:border-slate-700 rounded-xl">
            No hay pagos registrados
         </div>
         
         <div v-for="(payment, index) in payments" :key="index" 
            class="flex items-center justify-between bg-white dark:bg-slate-700 p-3 rounded-xl border border-slate-100 dark:border-slate-600 shadow-sm animate-fade-in"
         >
            <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full flex items-center justify-center"
                     :class="{
                        'bg-emerald-100 text-emerald-600': payment.method === 'cash',
                        'bg-purple-100 text-purple-600': payment.method === 'nequi',
                        'bg-amber-100 text-amber-600': payment.method === 'fiado'
                     }">
                     <Banknote v-if="payment.method === 'cash'" :size="20" />
                     <CreditCard v-if="payment.method === 'nequi'" :size="20" />
                     <User v-if="payment.method === 'fiado'" :size="20" />
                </div>
                <div>
                    <p class="font-bold text-slate-800 dark:text-white capitalize">
                        {{ payment.method === 'cash' ? 'Efectivo' : payment.method }}
                    </p>
                    <p v-if="payment.reference" class="text-xs text-slate-500">Ref: {{ payment.reference }}</p>
                </div>
            </div>
            
            <div class="flex items-center gap-3">
                <span class="font-bold text-slate-700 dark:text-slate-200">{{ formatCurrency(payment.amount) }}</span>
                <button @click="removePayment(index)" class="text-slate-400 hover:text-red-500 transition-colors">
                    <Trash2 :size="18" />
                </button>
            </div>
         </div>
      </div>

      <!-- ADD PAYMENT FORM -->
      <div v-if="remainingBalance.gt(0)" class="bg-slate-50 dark:bg-slate-800/50 p-4 rounded-xl border border-blue-100 dark:border-slate-700 space-y-4">
          <div class="grid grid-cols-3 gap-2">
              <button 
                v-for="method in ['cash', 'nequi', 'fiado']" 
                :key="method"
                @click="tempMethod = method as any; autoFillAmount()"
                class="flex flex-col items-center justify-center p-2 rounded-lg border-2 transition-all"
                :class="tempMethod === method 
                    ? 'border-blue-500 bg-blue-50 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400' 
                    : 'border-transparent bg-white dark:bg-slate-700 text-slate-500 hover:bg-slate-100'"
              >
                  <span class="capitalize text-sm font-bold">{{ method === 'cash' ? 'Efectivo' : method }}</span>
              </button>
          </div>

          <div class="flex gap-3">
              <div class="flex-1">
                   <BaseInput 
                        v-model="tempAmount"
                        type="number" 
                        placeholder="0.00"
                        class="text-right font-mono font-bold text-lg"
                        :autofocus="true"
                        @keyup.enter="addPayment"
                    />
              </div>
              <div v-if="tempMethod === 'nequi'" class="flex-1">
                   <BaseInput 
                        v-model="tempReference"
                        placeholder="Ref # (Op)"
                        @keyup.enter="addPayment"
                    />
              </div>
              <button 
                 @click="addPayment"
                 class="bg-blue-600 hover:bg-blue-700 text-white w-12 rounded-xl flex items-center justify-center shadow-md active:scale-95 transition-transform"
              >
                 <Plus :size="24" />
              </button>
          </div>
      </div>
    </div>

    <template #footer>
      <div class="p-6 pt-0 flex gap-3">
         <BaseButton @click="close" variant="secondary" class="flex-1 h-12">
            Cancelar
         </BaseButton>
         <BaseButton 
            @click="handleComplete" 
            :disabled="!isComplete"
            variant="success" 
            class="flex-[2] h-12 text-lg font-bold shadow-lg shadow-emerald-500/20"
         >
            <div class="flex items-center gap-2">
                <CheckCircle2 :size="24" />
                CONFIRMAR PAGO
            </div>
         </BaseButton>
      </div>
    </template>
  </BaseModal>
</template>

<style scoped>
.animate-fade-in {
  animation: fadeIn 0.3s ease-out;
}
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(5px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>

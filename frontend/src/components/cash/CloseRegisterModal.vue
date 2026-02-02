<script setup lang="ts">
import { ref, computed } from 'vue';
import { useCashRegisterStore } from '../../stores/cashRegister';
import Decimal from 'decimal.js';
import { Store, CheckCircle, AlertTriangle, Loader2 } from 'lucide-vue-next';
import { useNotifications } from '@/composables/useNotifications';

// Props & Emits
interface Props {
  modelValue: boolean;
}
const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'closed': [];
}>();

// Store
const cashRegisterStore = useCashRegisterStore();

// State
const physicalCount = ref('');
const notes = ref('');
const isLoading = ref(false);
const { showError, showSuccess } = useNotifications(); // Hook

// Computed
const systemExpected = computed(() => cashRegisterStore.currentBalance);
const openingBalance = computed(() => cashRegisterStore.currentSession?.openingBalance || new Decimal(0));
const totalIncome = computed(() => cashRegisterStore.totalIncome);
const totalExpenses = computed(() => cashRegisterStore.totalExpenses);

const difference = computed(() => {
  const physical = new Decimal(physicalCount.value || 0);
  return physical.minus(systemExpected.value);
});

const isBalanced = computed(() => difference.value.equals(0));
const isValid = computed(() => physicalCount.value !== '' && !isNaN(parseFloat(physicalCount.value)));

const differenceColor = computed(() => {
  if (difference.value.greaterThan(0)) return 'text-emerald-600 bg-emerald-50 dark:bg-emerald-900/20';
  if (difference.value.lessThan(0)) return 'text-red-600 bg-red-50 dark:bg-red-900/20';
  return 'text-gray-600 bg-gray-50 dark:text-gray-300 dark:bg-slate-700';
});

const differenceLabel = computed(() => {
  if (difference.value.greaterThan(0)) return 'Sobrante';
  if (difference.value.lessThan(0)) return 'Faltante';
  return 'Cuadrado';
});

// Methods
const formatCurrency = (val: Decimal) => {
  return new Intl.NumberFormat('es-CO', {
    style: 'currency',
    currency: 'COP',
    minimumFractionDigits: 0
  }).format(val.toNumber());
};

const close = () => {
  emit('update:modelValue', false);
  physicalCount.value = '';
  notes.value = '';
};

const handleClose = () => {
  if (!isValid.value) return;
  if (!confirm('¿Estás seguro de cerrar la caja? Esta acción no se puede deshacer.')) return;

  try {
    isLoading.value = true;
    cashRegisterStore.closeRegister(
      new Decimal(physicalCount.value),
      notes.value
    );
    emit('closed');
    close();
  } catch (error) {
    console.error(error);
    showError('Error al cerrar la caja');
  } finally {
    isLoading.value = false;
  }
};
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div 
        v-if="modelValue" 
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4"
        @click.self="close"
      >
        <div class="bg-white dark:bg-slate-800 w-full max-w-lg rounded-2xl shadow-2xl overflow-hidden animate-scale-in flex flex-col max-h-[90vh]">
          <!-- Header -->
          <div class="p-6 border-b border-gray-100 dark:border-gray-700 bg-gray-50/50 dark:bg-slate-800/50 shrink-0">
            <div class="flex items-center gap-3">
              <div class="size-12 rounded-full bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 flex items-center justify-center">
                <Store :size="28" />
              </div>
              <div>
                <h2 class="text-xl font-bold text-gray-900 dark:text-white">Cierre de Caja</h2>
                <p class="text-sm text-gray-500 dark:text-gray-400">Arqueo y finalización de turno</p>
              </div>
            </div>
          </div>

          <!-- Body -->
          <div class="flex-1 overflow-y-auto p-6 space-y-6">
            <div class="bg-gray-50 dark:bg-slate-700/50 rounded-xl p-4 space-y-3">
              <h3 class="text-sm font-semibold text-gray-900 dark:text-white mb-2">Resumen del Sistema</h3>
              <div class="flex justify-between text-sm">
                <span class="text-gray-500 dark:text-gray-400">Base Inicial</span>
                <span class="font-medium text-gray-900 dark:text-white">{{ formatCurrency(openingBalance) }}</span>
              </div>
              <div class="flex justify-between text-sm">
                <span class="text-gray-500 dark:text-gray-400">(+) Ventas/Ingresos</span>
                <span class="font-medium text-emerald-600 dark:text-emerald-400">{{ formatCurrency(totalIncome) }}</span>
              </div>
              <div class="flex justify-between text-sm">
                <span class="text-gray-500 dark:text-gray-400">(-) Gastos/Salidas</span>
                <span class="font-medium text-red-600 dark:text-red-400">{{ formatCurrency(totalExpenses) }}</span>
              </div>
              <div class="border-t border-gray-200 dark:border-gray-600 pt-2 flex justify-between font-bold">
                <span class="text-gray-700 dark:text-gray-300">Total Esperado</span>
                <span class="text-gray-900 dark:text-white text-lg">{{ formatCurrency(systemExpected) }}</span>
              </div>
            </div>

            <div class="space-y-4">
              <div class="space-y-2">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Efectivo Real en Caja (Conteo)
                </label>
                <div class="relative">
                  <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 font-medium">$</span>
                  <input 
                    v-model="physicalCount"
                    type="number" 
                    min="0"
                    step="100"
                    placeholder="0"
                    class="w-full h-14 pl-10 pr-4 text-2xl font-bold text-gray-900 dark:text-white bg-white dark:bg-slate-700 border-2 border-gray-200 dark:border-gray-600 rounded-xl focus:border-blue-500 focus:ring-0 transition-colors"
                  />
                </div>
              </div>

              <div 
                v-if="isValid"
                class="flex items-center justify-between p-3 rounded-lg border border-transparent"
                :class="differenceColor"
              >
                <div class="flex items-center gap-2 font-medium">
                  <component :is="isBalanced ? CheckCircle : AlertTriangle" :size="20" />
                  <span>{{ differenceLabel }}</span>
                </div>
                <span class="font-bold text-lg">{{ formatCurrency(difference.abs()) }}</span>
              </div>

              <div class="space-y-2">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                  Notas del Cierre
                </label>
                <textarea 
                  v-model="notes"
                  rows="3"
                  class="w-full p-3 text-sm text-gray-900 dark:text-white bg-gray-50 dark:bg-slate-700 border border-gray-200 dark:border-gray-600 rounded-xl focus:border-blue-500 focus:ring-blue-500 transition-colors resize-none"
                  placeholder="Observaciones..."
                ></textarea>
              </div>
            </div>
          </div>

          <!-- Footer -->
          <div class="p-6 pt-2 shrink-0 flex gap-3">
            <button 
              @click="close"
              class="flex-1 h-12 rounded-xl text-gray-600 dark:text-gray-300 font-semibold hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
            >
              Cancelar
            </button>
            <button 
              @click="handleClose"
              :disabled="!isValid || isLoading"
              class="flex-1 h-12 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-bold shadow-lg shadow-blue-500/20 active:scale-95 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              <Loader2 v-if="isLoading" class="animate-spin" :size="24" />
              <span v-else>Cerrar Turno</span>
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.modal-enter-active, .modal-leave-active { transition: opacity 0.2s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.animate-scale-in { animation: scaleIn 0.2s ease-out; }
@keyframes scaleIn { from { transform: scale(0.95); opacity: 0; } to { transform: scale(1); opacity: 1; } }
</style>

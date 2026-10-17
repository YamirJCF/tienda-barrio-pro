<script setup lang="ts">
import { ref, computed } from 'vue';
import { useCashRegisterStore } from '../../stores/cashRegister';
import Decimal from 'decimal.js';
import { Store, CheckCircle, AlertTriangle, Loader2, ShieldCheck } from 'lucide-vue-next';
import { useNotifications } from '@/composables/useNotifications';
import { useNotificationsStore } from '../../stores/notificationsStore';

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
const physicalCounts = ref<Record<string, string>>({});
const notes = ref('');
const isLoading = ref(false);
const closedReport = ref<{
  expected: number;
  actual: number;
  difference: number;
} | null>(null);

const { showError, showSuccess } = useNotifications();

// Initialize counts
import { watch } from 'vue';
watch(() => props.modelValue, (isOpen) => {
  if (isOpen) {
    physicalCounts.value = {};
    closedReport.value = null;
    Object.keys(cashRegisterStore.balancesByMethod).forEach(method => {
      physicalCounts.value[method] = '';
    });
  }
});

const balancesByMethod = computed(() => cashRegisterStore.balancesByMethod);

const totalPhysical = computed(() => {
  return Object.values(physicalCounts.value).reduce((sum, count) => sum.plus(new Decimal(count || 0)), new Decimal(0));
});

const isValid = computed(() => {
  // All methods must have a valid number entered
  return Object.keys(balancesByMethod.value).every(method => {
    const val = physicalCounts.value[method];
    return val !== '' && !isNaN(parseFloat(val));
  });
});

// Methods
const formatCurrency = (val: Decimal | number) => {
  const num = typeof val === 'number' ? val : val.toNumber();
  return new Intl.NumberFormat('es-CO', {
    style: 'currency',
    currency: 'COP',
    minimumFractionDigits: 0
  }).format(num);
};

const close = () => {
  emit('update:modelValue', false);
  physicalCounts.value = {};
  notes.value = '';
  closedReport.value = null;
};

const handleClose = async () => {
  if (!isValid.value) return;
  if (!confirm('¿Estás seguro de registrar el arqueo y cerrar el turno?')) return;

  try {
    isLoading.value = true;
    const result = await cashRegisterStore.closeRegister(
      totalPhysical.value,
      notes.value
    ) as any;

    // NOTIFICATION INTEGRATION
    const notifStore = useNotificationsStore();
    notifStore.addNotification({
      type: 'finance',
      audience: 'all',
      title: 'Cierre de Caja',
      message: `Cierre exitoso. Total reportado: ${formatCurrency(totalPhysical.value)}`,
      icon: 'banknote',
      isRead: false,
      metadata: { amount: totalPhysical.value.toNumber() }
    });

    // Certificación post-cierre por backend
    closedReport.value = {
      expected: Number(result?.expected_balance ?? 0),
      actual: Number(result?.actual_balance ?? totalPhysical.value.toNumber()),
      difference: Number(result?.difference ?? 0)
    };

    showSuccess('Cierre registrado correctamente');
  } catch (error: any) {
    console.error(error);
    showError(error.message || 'Error al cerrar la caja');
  } finally {
    isLoading.value = false;
  }
};

const finish = () => {
  emit('closed');
  close();
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
                <p class="text-sm text-gray-500 dark:text-gray-400">Arqueo Ciego y finalización de turno</p>
              </div>
            </div>
          </div>

          <!-- Body: Formulario de Conteo (Arqueo Ciego) -->
          <div v-if="!closedReport" class="flex-1 overflow-y-auto p-6 space-y-6">
            <!-- Banner Arqueo Ciego -->
            <div class="flex items-start gap-3 p-4 rounded-xl bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800/40">
              <ShieldCheck :size="22" class="text-blue-600 dark:text-blue-400 shrink-0 mt-0.5" />
              <p class="text-xs text-blue-800 dark:text-blue-200 leading-relaxed">
                Por política de control estricto (<strong>Arqueo Ciego</strong>), digita el valor total físico contado por cada canal. Los cálculos de cuadre se validarán en el servidor.
              </p>
            </div>

            <!-- Inputs por Método de Pago -->
            <div class="space-y-4">
              <div v-for="(_, method) in balancesByMethod" :key="method" class="space-y-1.5">
                <label class="block text-xs font-bold uppercase text-gray-500 dark:text-gray-400 tracking-wider capitalize">
                  Monto Físico Contado en {{ method }}
                </label>
                <div class="relative">
                  <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 font-medium">$</span>
                  <input 
                    v-model="physicalCounts[method]"
                    type="number" 
                    min="0"
                    step="100"
                    placeholder="0"
                    class="w-full h-12 pl-10 pr-4 text-xl font-bold text-gray-900 dark:text-white bg-white dark:bg-slate-700 border border-gray-200 dark:border-gray-600 rounded-xl focus:border-blue-500 focus:ring-0 transition-colors"
                  />
                </div>
              </div>

              <div class="space-y-2 pt-2">
                <label class="block text-xs font-bold uppercase text-gray-500 dark:text-gray-400">
                  Notas u Observaciones del Cierre
                </label>
                <textarea 
                  v-model="notes"
                  rows="2"
                  class="w-full p-3 text-sm text-gray-900 dark:text-white bg-gray-50 dark:bg-slate-700 border border-gray-200 dark:border-gray-600 rounded-xl focus:border-blue-500 focus:ring-blue-500 transition-colors resize-none"
                  placeholder="Detalles sobre el turno..."
                ></textarea>
              </div>
            </div>
          </div>

          <!-- Body: Acta Post-Cierre (Certificación del Servidor) -->
          <div v-else class="flex-1 overflow-y-auto p-6 space-y-6">
            <div class="text-center">
              <div class="size-14 rounded-2xl mx-auto flex items-center justify-center mb-3"
                   :class="Math.abs(closedReport.difference) < 50 ? 'bg-emerald-100 text-emerald-600 dark:bg-emerald-900/30' : (closedReport.difference > 0 ? 'bg-blue-100 text-blue-600 dark:bg-blue-900/30' : 'bg-red-100 text-red-600 dark:bg-red-900/30')">
                <CheckCircle v-if="Math.abs(closedReport.difference) < 50" :size="32" />
                <AlertTriangle v-else :size="32" />
              </div>
              <h3 class="text-lg font-bold text-gray-900 dark:text-white">Acta Oficial de Cierre</h3>
              <p class="text-xs text-gray-500 dark:text-gray-400">Balance contable certificado por el servidor</p>
            </div>

            <div class="bg-slate-50 dark:bg-slate-900/50 rounded-2xl p-4 space-y-3 text-sm border border-slate-100 dark:border-slate-700">
              <div class="flex justify-between items-center">
                <span class="text-gray-500 dark:text-gray-400">Total Declarado:</span>
                <span class="font-bold text-gray-900 dark:text-white">{{ formatCurrency(closedReport.actual) }}</span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-gray-500 dark:text-gray-400">Esperado en Sistema:</span>
                <span class="font-medium text-gray-700 dark:text-gray-300">{{ formatCurrency(closedReport.expected) }}</span>
              </div>
              <div class="border-t border-gray-200 dark:border-gray-700 pt-2 flex justify-between items-center font-bold">
                <span>Diferencia:</span>
                <span :class="Math.abs(closedReport.difference) < 50 ? 'text-emerald-600' : (closedReport.difference > 0 ? 'text-blue-600' : 'text-red-600')">
                  {{ closedReport.difference > 0 ? '+' : '' }}{{ formatCurrency(closedReport.difference) }}
                  <span class="text-xs font-normal">
                    ({{ Math.abs(closedReport.difference) < 50 ? 'Cuadrada' : (closedReport.difference > 0 ? 'Sobrante' : 'Faltante') }})
                  </span>
                </span>
              </div>
            </div>
          </div>

          <!-- Footer -->
          <div class="p-6 pt-2 shrink-0 flex gap-3">
            <template v-if="!closedReport">
              <button 
                type="button"
                @click="close"
                class="flex-1 h-12 rounded-xl text-gray-600 dark:text-gray-300 font-semibold hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
                :disabled="isLoading"
              >
                Cancelar
              </button>
              <button 
                type="button"
                @click="handleClose"
                :disabled="!isValid || isLoading"
                class="flex-1 h-12 rounded-xl bg-blue-600 hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed text-white font-semibold flex items-center justify-center gap-2 shadow-lg shadow-blue-500/25 transition-all"
              >
                <Loader2 v-if="isLoading" class="animate-spin" :size="20" />
                <span>{{ isLoading ? 'Cerrando...' : 'Cerrar Turno' }}</span>
              </button>
            </template>
            <template v-else>
              <button 
                type="button"
                @click="finish"
                class="w-full h-12 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-semibold flex items-center justify-center gap-2 shadow-lg shadow-blue-500/25 transition-all"
              >
                Finalizar y Continuar
              </button>
            </template>
          </div>

        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.2s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}
</style>

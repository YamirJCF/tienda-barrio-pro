<script setup lang="ts">
import { ref, computed } from 'vue';
import { useCashRegisterStore } from '../../stores/cashRegister';
import { useEmployeesStore } from '../../stores/employees';
import Decimal from 'decimal.js';

// Props & Emits
interface Props {
  modelValue: boolean;
}
const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'opened': [];
}>();

// Stores
const cashRegisterStore = useCashRegisterStore();
const employeesStore = useEmployeesStore(); // Assuming we use this to get current employee ID if strict mode

// State
const amount = ref('');
const notes = ref('');
const isLoading = ref(false);

// Computed
const isValid = computed(() => {
  const val = parseFloat(amount.value);
  return !isNaN(val) && val >= 0;
});

// Methods
const close = () => {
  emit('update:modelValue', false);
  amount.value = '';
  notes.value = '';
};

const handleOpen = () => {
  if (!isValid.value) return;

  try {
    isLoading.value = true;
    // For now, using a dummy employee ID 1 if not authenticated fully
    // In strict mode, we should fetch from session
    const employeeId = 1; 
    
    cashRegisterStore.openRegister(
      employeeId, 
      new Decimal(amount.value), 
      notes.value
    );
    
    emit('opened');
    close();
  } catch (error) {
    console.error(error);
    alert('Error al abrir la caja');
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
        <div class="bg-white dark:bg-slate-800 w-full max-w-md rounded-2xl shadow-2xl overflow-hidden animate-scale-in">
          <!-- Header -->
          <div class="p-6 border-b border-gray-100 dark:border-gray-700 bg-gray-50/50 dark:bg-slate-800/50">
            <div class="flex items-center gap-3">
              <div class="size-12 rounded-full bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 flex items-center justify-center">
                <span class="material-symbols-outlined text-2xl">point_of_sale</span>
              </div>
              <div>
                <h2 class="text-xl font-bold text-gray-900 dark:text-white">Apertura de Caja</h2>
                <p class="text-sm text-gray-500 dark:text-gray-400">Inicia el turno ingresando la base</p>
              </div>
            </div>
          </div>

          <!-- Body -->
          <div class="p-6 space-y-6">
            <!-- Amount Input -->
            <div class="space-y-2">
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                Base Inicial (Efectivo)
              </label>
              <div class="relative">
                <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 font-medium">$</span>
                <input 
                  v-model="amount"
                  type="number" 
                  min="0"
                  step="100"
                  placeholder="0"
                  class="w-full h-14 pl-10 pr-4 text-2xl font-bold text-gray-900 dark:text-white bg-white dark:bg-slate-700 border-2 border-gray-200 dark:border-gray-600 rounded-xl focus:border-emerald-500 focus:ring-0 transition-colors"
                  @keydown.enter="isValid && handleOpen()"
                  autofocus
                />
              </div>
              <p class="text-xs text-gray-500">Dinero en efectivo disponible al inicio del turno.</p>
            </div>

            <!-- Notes -->
            <div class="space-y-2">
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
                Notas (Opcional)
              </label>
              <textarea 
                v-model="notes"
                rows="3"
                class="w-full p-3 text-sm text-gray-900 dark:text-white bg-gray-50 dark:bg-slate-700 border border-gray-200 dark:border-gray-600 rounded-xl focus:border-emerald-500 focus:ring-emerald-500 transition-colors resize-none"
                placeholder="Observaciones sobre la apertura..."
              ></textarea>
            </div>
          </div>

          <!-- Footer -->
          <div class="p-6 pt-2 flex gap-3">
            <button 
              @click="close"
              class="flex-1 h-12 rounded-xl text-gray-600 dark:text-gray-300 font-semibold hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
            >
              Cancelar
            </button>
            <button 
              @click="handleOpen"
              :disabled="!isValid || isLoading"
              class="flex-1 h-12 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold shadow-lg shadow-emerald-500/20 active:scale-95 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              <span v-if="isLoading" class="material-symbols-outlined animate-spin text-xl">progress_activity</span>
              <span v-else>Abrir Caja</span>
             </button>
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

.animate-scale-in {
  animation: scaleIn 0.2s ease-out;
}

@keyframes scaleIn {
  from {
    transform: scale(0.95);
    opacity: 0;
  }
  to {
    transform: scale(1);
    opacity: 1;
  }
}
</style>

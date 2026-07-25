<script setup lang="ts">
import { ref, computed } from 'vue';
import { AlertTriangle, CheckCircle, Info } from 'lucide-vue-next';
import BaseButton from './ui/BaseButton.vue';
import FormInputCurrency from './ui/FormInputCurrency.vue';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';

// =============================================
// TIPOS
// =============================================
export interface PendingForcedSession {
  id: string;
  openedAt: string;
  expectedBalance: number;
}

// =============================================
// PROPS & EMITS
// =============================================
const props = defineProps<{
  /** Lista de sesiones cerradas forzosamente pendientes de reconciliación, ordenada ASC */
  pendingSessions: PendingForcedSession[];
  isVisible: boolean;
}>();

const emit = defineEmits<{
  /** Emitido cuando el usuario confirma el conteo físico de la sesión actual */
  (e: 'confirm', sessionId: string, actualBalance: number): void;
  /** Emitido si el usuario cierra el modal (solo disponible cuando no hay pendientes bloqueantes) */
  (e: 'close'): void;
}>();

// =============================================
// STATE
// =============================================
const { formatCurrency } = useCurrencyFormat();
const actualBalance = ref(0);

// La sesión que se está conciliando ahora es siempre la primera de la lista (más antigua primero)
const currentSession = computed(() => props.pendingSessions[0] ?? null);

const remainingCount = computed(() => props.pendingSessions.length);

const difference = computed(() => {
  if (!currentSession.value) return 0;
  return actualBalance.value - currentSession.value.expectedBalance;
});

const differenceStatus = computed(() => {
  const diff = difference.value;
  if (Math.abs(diff) < 50) return { color: 'text-emerald-500', label: 'Cuadra' };
  if (diff > 0)             return { color: 'text-blue-500',    label: 'Sobrante' };
  return                           { color: 'text-red-500',     label: 'Faltante' };
});

const formattedOpenedAt = computed(() => {
  if (!currentSession.value) return '';
  return new Date(currentSession.value.openedAt).toLocaleString('es-CO', {
    weekday: 'long', year: 'numeric', month: 'long',
    day: 'numeric', hour: '2-digit', minute: '2-digit',
  });
});

// =============================================
// HANDLERS
// =============================================
const handleConfirm = () => {
  if (!currentSession.value) return;
  emit('confirm', currentSession.value.id, actualBalance.value);
  // Reset para la siguiente sesión de la cola
  actualBalance.value = 0;
};
</script>

<template>
  <Teleport to="body">
    <Transition name="audit-modal">
      <div
        v-if="isVisible && currentSession"
        class="fixed inset-0 z-[9999] flex items-end justify-center sm:items-center"
        role="dialog"
        aria-modal="true"
        aria-labelledby="audit-modal-title"
      >
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-slate-900/80 backdrop-blur-sm" />

        <!-- Panel -->
        <div class="relative z-10 w-full max-w-md bg-white dark:bg-gray-900 rounded-t-3xl sm:rounded-2xl shadow-2xl p-6 flex flex-col gap-5">

          <!-- Header -->
          <div class="flex items-start gap-4">
            <div class="w-12 h-12 bg-amber-100 dark:bg-amber-900/30 rounded-2xl flex items-center justify-center flex-shrink-0">
              <AlertTriangle :size="24" class="text-amber-600 dark:text-amber-400" />
            </div>
            <div>
              <h2 id="audit-modal-title" class="font-bold text-gray-900 dark:text-white text-lg leading-tight">
                Auditoría de Cierre Forzado
              </h2>
              <p class="text-xs text-amber-600 dark:text-amber-400 font-medium mt-0.5">
                {{ remainingCount > 1 ? `${remainingCount} turnos pendientes` : '1 turno pendiente' }}
              </p>
            </div>
          </div>

          <!-- Context info -->
          <div class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700/50 rounded-xl p-4 space-y-2">
            <p class="text-xs font-bold uppercase text-amber-700 dark:text-amber-400 tracking-wider">Turno cerrado automáticamente</p>
            <p class="text-xs text-amber-700 dark:text-amber-300 leading-relaxed">
              Apertura: <strong>{{ formattedOpenedAt }}</strong>
            </p>
            <p class="text-sm font-bold text-amber-800 dark:text-amber-200">
              Saldo esperado: {{ formatCurrency(currentSession.expectedBalance) }}
            </p>
          </div>

          <!-- Info note -->
          <div class="flex items-start gap-2 px-3 py-2 rounded-xl bg-blue-50 dark:bg-blue-900/20 border border-blue-100 dark:border-blue-800/40">
            <Info :size="14" class="text-blue-500 mt-0.5 flex-shrink-0" />
            <p class="text-xs text-blue-700 dark:text-blue-300 leading-relaxed">
              Debes ingresar el conteo físico real antes de abrir un nuevo turno.
              Esta acción queda registrada en el historial de auditoría.
            </p>
          </div>

          <!-- Physical count input -->
          <div>
            <label class="block text-xs font-bold uppercase text-gray-400 mb-2 text-center">
              ¿Cuánto hay físicamente en caja?
            </label>
            <FormInputCurrency
              v-model="actualBalance"
              placeholder="0"
              class="text-2xl font-bold text-center"
              :autofocus="true"
            />

            <!-- Difference indicator -->
            <div
              class="mt-3 flex items-center justify-center gap-2 p-2 rounded-lg bg-gray-50 dark:bg-gray-800/50 border border-gray-100 dark:border-gray-700"
            >
              <CheckCircle :size="16" :class="differenceStatus.color" />
              <span class="text-sm font-bold" :class="differenceStatus.color">
                {{ differenceStatus.label }}
              </span>
              <span v-if="Math.abs(difference) >= 50" class="font-mono text-sm" :class="differenceStatus.color">
                ({{ formatCurrency(Math.abs(difference)) }})
              </span>
            </div>
          </div>

          <!-- Action button -->
          <BaseButton
            id="btn-confirm-forced-close-audit"
            variant="dark"
            class="w-full h-12 font-bold"
            @click="handleConfirm"
          >
            Confirmar Conteo y Continuar
          </BaseButton>

        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.audit-modal-enter-active,
.audit-modal-leave-active {
  transition: opacity 0.25s ease;
}
.audit-modal-enter-active .relative,
.audit-modal-leave-active .relative {
  transition: transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
}
.audit-modal-enter-from,
.audit-modal-leave-to {
  opacity: 0;
}
.audit-modal-enter-from .relative {
  transform: translateY(40px);
}
</style>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { AlertTriangle, Info, ShieldCheck } from 'lucide-vue-next';
import BaseButton from './ui/BaseButton.vue';
import FormInputCurrency from './ui/FormInputCurrency.vue';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';

// =============================================
// TIPOS
// =============================================
export interface PendingForcedSession {
  id: string;
  openedAt: string;
  /** Canales a contar físicamente (hoy solo 'efectivo'). NO incluye saldos esperados (Arqueo Ciego). */
  channels: string[];
}

// =============================================
// PROPS & EMITS
// =============================================
const props = withDefaults(defineProps<{
  /** Lista de sesiones cerradas forzosamente pendientes de reconciliación, ordenada ASC */
  pendingSessions: PendingForcedSession[];
  isVisible: boolean;
  /** Admin-only (FRD-027-02 R5): permite omitir conteo físico con confirmación explícita */
  allowSkipCount?: boolean;
}>(), {
  allowSkipCount: true,
});

const emit = defineEmits<{
  /** Emitido cuando el usuario confirma el conteo físico (o null si omite conteo como Admin) */
  (e: 'confirm', sessionId: string, actualBalance: number | null): void;
  /** Emitido si el usuario cierra el modal (solo disponible cuando no hay pendientes bloqueantes) */
  (e: 'close'): void;
}>();

// =============================================
// STATE
// =============================================
const { formatCurrency } = useCurrencyFormat();
const physicalCounts = ref<Record<string, number>>({});
const skipPhysicalCount = ref(false);
const confirmSkipWithoutCount = ref(false);

// La sesión que se está conciliando ahora es siempre la primera de la lista (más antigua primero)
const currentSession = computed(() => props.pendingSessions[0] ?? null);

import { watch } from 'vue';
watch(() => currentSession.value, (session) => {
  skipPhysicalCount.value = false;
  confirmSkipWithoutCount.value = false;
  if (session) {
    physicalCounts.value = {};
    session.channels.forEach(method => {
      physicalCounts.value[method] = 0;
    });
  }
}, { immediate: true });

const remainingCount = computed(() => props.pendingSessions.length);

const totalPhysical = computed(() => {
  return Object.values(physicalCounts.value).reduce((sum, count) => sum + (Number(count) || 0), 0);
});

const isValid = computed(() => {
  if (!currentSession.value) return false;
  if (props.allowSkipCount && skipPhysicalCount.value) {
    return confirmSkipWithoutCount.value;
  }
  return currentSession.value.channels.every(method => {
    const val = physicalCounts.value[method];
    return typeof val === 'number' && !isNaN(val) && val >= 0;
  });
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
  if (!currentSession.value || !isValid.value) return;
  if (props.allowSkipCount && skipPhysicalCount.value) {
    emit('confirm', currentSession.value.id, null);
    return;
  }
  emit('confirm', currentSession.value.id, totalPhysical.value);
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

          <!-- Context info (Arqueo Ciego: Sin mostrar saldo esperado del sistema) -->
          <div class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700/50 rounded-xl p-4 space-y-1">
            <p class="text-xs font-bold uppercase text-amber-700 dark:text-amber-400 tracking-wider">Turno cerrado automáticamente (>24 Horas)</p>
            <p class="text-xs text-amber-700 dark:text-amber-300 leading-relaxed">
              Fecha de apertura: <strong>{{ formattedOpenedAt }}</strong>
            </p>
          </div>

          <!-- Protocolo de Arqueo Ciego -->
          <div class="flex items-start gap-2.5 px-3 py-2.5 rounded-xl bg-blue-50 dark:bg-blue-900/20 border border-blue-100 dark:border-blue-800/40">
            <ShieldCheck :size="18" class="text-blue-500 mt-0.5 flex-shrink-0" />
            <p class="text-xs text-blue-700 dark:text-blue-300 leading-relaxed">
              Por control de seguridad (<strong>Arqueo Ciego</strong>), ingresa el valor físico real recuperado. El servidor calculará el balance oficial al procesar.
            </p>
          </div>

          <!-- Physical count inputs -->
          <div v-if="!skipPhysicalCount" class="space-y-4 max-h-[40vh] overflow-y-auto px-1 no-scrollbar">
            <div v-for="method in currentSession.channels" :key="method" class="space-y-1.5">
              <label class="block text-xs font-bold uppercase text-gray-500 dark:text-gray-400 capitalize">
                ¿Cuánto dinero físico recuperaste en {{ method }}?
              </label>
              <FormInputCurrency
                v-model="physicalCounts[method]"
                placeholder="0"
                class="text-xl font-bold text-center"
              />
            </div>
          </div>

          <!-- FRD-027-02 R5: Conteo físico opcional para Cierre Forzoso Admin -->
          <div v-if="allowSkipCount" class="border border-slate-200 dark:border-slate-700 rounded-xl p-3 space-y-2.5 bg-slate-50 dark:bg-slate-800/60">
            <label class="flex items-start gap-2.5 cursor-pointer select-none">
              <input
                v-model="skipPhysicalCount"
                type="checkbox"
                data-test="skip-count-toggle"
                class="mt-0.5 rounded border-slate-300 text-amber-600 focus:ring-amber-500"
              />
              <span class="text-xs font-semibold text-slate-700 dark:text-slate-200">
                Cerrar sin conteo físico (el abridor no está disponible)
              </span>
            </label>

            <div v-if="skipPhysicalCount" class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800/50 rounded-lg p-2.5 space-y-2">
              <p class="text-[11px] text-red-700 dark:text-red-300 leading-relaxed">
                El servidor asumirá el saldo esperado en libros con diferencia $0, marcará <strong>cierre sin conteo</strong> y emitirá alerta crítica de auditoría.
              </p>
              <label class="flex items-start gap-2 cursor-pointer select-none">
                <input
                  v-model="confirmSkipWithoutCount"
                  type="checkbox"
                  data-test="confirm-skip-count"
                  class="mt-0.5 rounded border-red-300 text-red-600 focus:ring-red-500"
                />
                <span class="text-[11px] font-bold text-red-800 dark:text-red-200">
                  Confirmo cerrar este turno sin conteo físico
                </span>
              </label>
            </div>
          </div>

          <!-- Action button -->
          <BaseButton
            id="btn-confirm-forced-close-audit"
            variant="dark"
            class="w-full h-12 font-bold"
            :disabled="!isValid"
            @click="handleConfirm"
          >
            {{ skipPhysicalCount ? 'Cerrar Sin Conteo y Desbloquear' : 'Confirmar Conteo y Continuar' }}
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

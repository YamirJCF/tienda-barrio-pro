<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { AlertTriangle } from 'lucide-vue-next';
import BaseButton from './ui/BaseButton.vue';
import FormInputCurrency from './ui/FormInputCurrency.vue';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';

// =============================================
// TIPOS
// =============================================
export interface PendingForcedSession {
  id: string;
  openedAt: string;
  openedByName?: string;
  openedByRole?: string;
  openingBalance?: number;
  expectedEfectivo?: number;
  nequiSummary?: number;
  llaveBreSummary?: number;
  isOpenedByOther?: boolean;
  /** Canal físico a contar obligatoriamente ('efectivo'). */
  channels: string[];
}

// =============================================
// PROPS & EMITS
// =============================================
const props = withDefaults(defineProps<{
  /** Lista de sesiones vencidas (+24h) pendientes de cierre obligatorio, ordenada ASC */
  pendingSessions: PendingForcedSession[];
  isVisible: boolean;
  isSubmitting?: boolean;
  errorMessage?: string | null;
}>(), {
  isSubmitting: false,
  errorMessage: null,
});

const emit = defineEmits<{
  /** Emitido únicamente cuando el Administrador declara explícitamente el efectivo físico recuperado */
  (e: 'confirm', sessionId: string, actualBalance: number, notes?: string): void;
  (e: 'close'): void;
}>();

// =============================================
// STATE
// =============================================
const { formatWithSign } = useCurrencyFormat();
const physicalCounts = ref<Record<string, number | null>>({});
const observationNotes = ref('');

const currentSession = computed(() => props.pendingSessions[0] ?? null);

watch(() => currentSession.value, (session) => {
  observationNotes.value = '';
  if (session) {
    physicalCounts.value = {};
    session.channels.forEach(method => {
      // Nace vacío (null) para prohibir cierres sin digitar (POL-SEG-01 / FRD-027-02)
      physicalCounts.value[method] = null;
    });
  }
}, { immediate: true });

const remainingCount = computed(() => props.pendingSessions.length);

const requiresObservation = computed(() => Boolean(currentSession.value?.isOpenedByOther));

const totalPhysical = computed(() => {
  return Object.values(physicalCounts.value).reduce<number>((sum, count) => sum + (Number(count) || 0), 0);
});

const isValid = computed(() => {
  if (!currentSession.value) return false;
  const hasValidAmounts = currentSession.value.channels.every(method => {
    const val = physicalCounts.value[method];
    return val !== null && typeof val === 'number' && !isNaN(val) && val >= 0;
  });
  if (!hasValidAmounts) return false;
  if (requiresObservation.value && observationNotes.value.trim().length < 5) {
    return false;
  }
  return true;
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
  const cleanNotes = observationNotes.value.trim();
  emit('confirm', currentSession.value.id, totalPhysical.value, cleanNotes || undefined);
};
</script>

<template>
  <Teleport to="body">
    <Transition name="audit-modal">
      <div
        v-if="isVisible && currentSession"
        class="fixed inset-0 z-50 flex items-end justify-center sm:items-center"
        role="dialog"
        aria-modal="true"
        aria-labelledby="audit-modal-title"
      >
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-slate-900/80 backdrop-blur-sm" />

        <!-- Panel -->
        <div class="relative z-10 w-full max-w-md bg-white dark:bg-gray-900 rounded-t-3xl sm:rounded-2xl shadow-2xl p-6 flex flex-col gap-4 max-h-[92vh] overflow-y-auto">

          <!-- Header -->
          <div class="flex items-center gap-3">
            <div class="w-11 h-11 bg-amber-100 dark:bg-amber-900/30 rounded-2xl flex items-center justify-center flex-shrink-0">
              <AlertTriangle :size="22" class="text-amber-600 dark:text-amber-400" />
            </div>
            <div>
              <h2 id="audit-modal-title" class="font-bold text-gray-900 dark:text-white text-lg leading-tight">
                Turno Vencido (+24h)
              </h2>
              <p v-if="remainingCount > 1" class="text-xs text-amber-600 dark:text-amber-400 font-medium mt-0.5">
                {{ remainingCount }} turnos pendientes
              </p>
            </div>
          </div>

          <!-- Ficha Resumen del Turno Vencido (Exclusivo Admin — Autoridad del Servidor) -->
          <div
            data-test="forced-close-session-summary"
            class="bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800/50 rounded-xl p-4 space-y-2"
          >
            <div class="flex items-center justify-between text-xs">
              <span class="text-emerald-800 dark:text-emerald-300 font-semibold">Abierto por</span>
              <span class="font-bold text-slate-900 dark:text-white">{{ currentSession.openedByName || 'Usuario' }}</span>
            </div>
            <div class="flex items-center justify-between text-xs">
              <span class="text-emerald-800 dark:text-emerald-300 font-semibold">Apertura</span>
              <span class="text-slate-700 dark:text-slate-200 capitalize text-right">{{ formattedOpenedAt }}</span>
            </div>

            <div
              v-if="typeof currentSession.expectedEfectivo === 'number'"
              class="pt-2 border-t border-emerald-200/70 dark:border-emerald-800/50 space-y-2"
            >
              <div class="flex items-center justify-between text-xs">
                <span class="text-slate-600 dark:text-slate-300">Base inicial</span>
                <span class="font-mono tabular-nums font-semibold text-slate-800 dark:text-slate-200">
                  {{ formatWithSign(currentSession.openingBalance ?? 0) }}
                </span>
              </div>
              <div class="flex items-center justify-between">
                <span class="text-xs font-bold uppercase tracking-wide text-emerald-800 dark:text-emerald-300">
                  Efectivo esperado
                </span>
                <span class="text-lg font-black font-mono tabular-nums text-emerald-900 dark:text-emerald-200">
                  {{ formatWithSign(currentSession.expectedEfectivo) }}
                </span>
              </div>
              <div class="grid grid-cols-2 gap-2 pt-1 text-xs">
                <div class="rounded-lg bg-white/70 dark:bg-slate-900/40 px-2.5 py-1.5">
                  <p class="text-[10px] font-bold uppercase text-slate-500 dark:text-slate-400">Nequi</p>
                  <p class="font-mono tabular-nums font-bold text-slate-800 dark:text-slate-200">
                    {{ formatWithSign(currentSession.nequiSummary ?? 0) }}
                  </p>
                </div>
                <div class="rounded-lg bg-white/70 dark:bg-slate-900/40 px-2.5 py-1.5">
                  <p class="text-[10px] font-bold uppercase text-slate-500 dark:text-slate-400">Llave Bre-B</p>
                  <p class="font-mono tabular-nums font-bold text-slate-800 dark:text-slate-200">
                    {{ formatWithSign(currentSession.llaveBreSummary ?? 0) }}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <!-- Physical count input (solo efectivo físico, obligatorio digitar) -->
          <div class="space-y-3 px-1">
            <div v-for="method in currentSession.channels" :key="method" class="space-y-1.5">
              <label class="block text-xs font-bold uppercase text-gray-500 dark:text-gray-400">
                Efectivo en cajón
              </label>
              <FormInputCurrency
                v-model="physicalCounts[method]"
                :allow-null="true"
                placeholder="0"
                data-test="forced-close-amount-input"
                class="text-2xl font-black text-center font-mono tabular-nums"
              />
            </div>

            <!-- Observación obligatoria si el turno vencido lo abrió otro usuario -->
            <div class="space-y-1">
              <label class="block text-xs font-bold uppercase text-gray-500 dark:text-gray-400">
                {{ requiresObservation ? 'Motivo (Obligatorio)' : 'Nota (Opcional)' }}
              </label>
              <textarea
                v-model="observationNotes"
                data-test="forced-close-notes-input"
                rows="2"
                class="w-full p-2.5 bg-background-light dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl text-xs text-slate-800 dark:text-slate-100"
                :placeholder="requiresObservation ? 'Ej: Empleado ausente, conté cajón...' : 'Opcional...'"
              />
              <p
                v-if="requiresObservation && observationNotes.trim().length > 0 && observationNotes.trim().length < 5"
                class="text-[11px] text-amber-600 dark:text-amber-400"
              >
                Mínimo 5 caracteres.
              </p>
            </div>
          </div>

          <!-- Error visible en modal (Regla 3: Cero fallos silenciosos) -->
          <div v-if="errorMessage" class="p-3 rounded-xl bg-red-50 dark:bg-red-900/30 border border-red-300 dark:border-red-700 text-xs font-medium text-red-700 dark:text-red-200">
            {{ errorMessage }}
          </div>

          <!-- Action button -->
          <BaseButton
            id="btn-confirm-forced-close-audit"
            variant="dark"
            class="w-full h-12 font-bold"
            :loading="isSubmitting"
            :disabled="!isValid || isSubmitting"
            @click="handleConfirm"
          >
            Cerrar Turno
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
  transition: transform 0.25s cubic-bezier(0.16, 1, 0.3, 1);
}
.audit-modal-enter-from,
.audit-modal-leave-to {
  opacity: 0;
}
.audit-modal-enter-from .relative {
  transform: translateY(40px);
}
</style>

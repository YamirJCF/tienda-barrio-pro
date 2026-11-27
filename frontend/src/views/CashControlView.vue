<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useCashRegisterStore } from '../stores/cashRegister';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useNotifications } from '../composables/useNotifications';
import FormInputCurrency from '../components/ui/FormInputCurrency.vue';
import ForcedCloseAuditModal, { type PendingForcedSession } from '../components/ForcedCloseAuditModal.vue';
import BaseButton from '@/components/ui/BaseButton.vue';
import BaseModal from '../components/ui/BaseModal.vue';
import BaseListSkeleton from '../components/ui/BaseListSkeleton.vue';
import ShiftExpensesTab from '../components/cash/ShiftExpensesTab.vue';
import OwnShiftMovementsTab from '../components/cash/OwnShiftMovementsTab.vue';
import Decimal from 'decimal.js';
import { useAuthStore } from '../stores/auth';
import { useAsyncAction } from '../composables/useAsyncAction';
import { logger } from '../utils/logger';
import {
  ArrowLeft,
  LockOpen,
  Lock,
  Store,
  CheckCircle,
  AlertTriangle,
  ShieldCheck,
  RefreshCw
} from 'lucide-vue-next';

type CashTab = 'shift' | 'expenses' | 'movements';

const route = useRoute();
const router = useRouter();
const cashRegisterStore = useCashRegisterStore();
const authStore = useAuthStore();
const { formatWithSign } = useCurrencyFormat();
const { showSuccess, showError, showWarning } = useNotifications();
const { execute: executeAction, isLoading: isSubmitting } = useAsyncAction();

// =============================================
// PERMISOS Y PESTAÑAS DEL WORKSPACE (?tab=shift|expenses|movements)
// =============================================
const canOpenCloseCash = computed(() => authStore.canOpenCloseCash);

const availableTabs = computed<Array<{ id: CashTab; label: string }>>(() => {
  if (authStore.isAdmin) {
    return [
      { id: 'shift', label: 'Turno' },
      { id: 'expenses', label: 'Gastos' },
      { id: 'movements', label: 'Mis Movimientos' },
    ];
  }
  if (canOpenCloseCash.value) {
    return [
      { id: 'shift', label: 'Turno' },
      { id: 'movements', label: 'Mis Movimientos' },
    ];
  }
  return [];
});

// =============================================
// FORCED CLOSE AUDIT STATE (FRD-017 / FRD-027-02)
// =============================================
const pendingForcedSessions = ref<PendingForcedSession[]>([]);
const fetchForcedSessionsError = ref(false);
const isReconcilingForced = ref(false);
const forcedReconcileError = ref<string | null>(null);
const showAuditModal = computed(() => authStore.isAdmin && pendingForcedSessions.value.length > 0);

// Sync State (C2-H2: Fail-closed con skeleton desde frame 0 para no flashear ni montar tabs antes de sincronizar)
const isLoadingWorkspace = ref(Boolean(authStore.canOpenCloseCash));
const syncError = ref<string | null>(null);

const fetchPendingForcedSessions = async () => {
  if (!authStore.isAdmin) {
    pendingForcedSessions.value = [];
    return;
  }
  fetchForcedSessionsError.value = false;
  try {
    pendingForcedSessions.value = await cashRegisterStore.fetchPendingForcedSessions(authStore.currentStore?.id);
  } catch (e) {
    console.error('🚫 [CashControl] Failed to fetch pending forced sessions:', e);
    fetchForcedSessionsError.value = true;
  }
};

const translateReconciliationError = (message?: string): string => {
  const code = (message || '').split(':')[0].trim();
  const messages: Record<string, string> = {
    INVALID_BALANCE: 'El monto contado no es válido.',
    SESSION_NOT_FOUND: 'El turno ya no existe. Actualiza e intenta de nuevo.',
    SESSION_NOT_RECONCILABLE: 'Este turno ya fue reconciliado. Actualiza para continuar.',
    STORE_ACCESS_DENIED: 'No tienes acceso a esta tienda.',
    ADMIN_ONLY_ACTION: 'Solo el Administrador puede ejecutar cierres forzosos administrativos.',
    EMPLOYEE_NOT_FOUND: 'Tu usuario no está registrado como empleado de esta tienda.',
    INSUFFICIENT_PERMISSIONS: 'No tienes permiso para reconciliar cierres de caja. Consulta con el administrador.',
    AUDIT_ACTOR_UNRESOLVABLE: 'Tu usuario no puede firmar la auditoría. Pide a un administrador que reconcilie el turno.',
  };
  return messages[code] || 'No se pudo reconciliar el turno. Intenta de nuevo.';
};

// Post-Cierre Confirmation State (POL-SEG-01 v1.5: empleados NUNCA ven esperado/diferencia; Admin sí)
const closedSealSummary = ref<{
  sealedWithAlert: boolean;
  closedByName?: string;
  expectedEfectivo?: number;
  actualEfectivo?: number;
  difference?: number;
} | null>(null);

// Assisted Close Retry State (Cierre Asistido 3 intentos)
const assistedRetryNotice = ref<{
  attemptsUsed: number;
  attemptsRemaining: number;
  message: string;
} | null>(null);

// Computed State
const currentActorId = computed(() => authStore.currentUser?.employeeId || authStore.currentUser?.id || null);
const pendingOpenerExpiredSession = computed(() => {
  const forced = cashRegisterStore.pendingForcedSessionInfo;
  if (!forced || authStore.isAdmin || !currentActorId.value) return null;
  return forced.openedBy === currentActorId.value ? forced : null;
});
const isClosingMode = computed(() => cashRegisterStore.isOpen || Boolean(pendingOpenerExpiredSession.value));
const isOpening = computed(() => !isClosingMode.value);
const isStale = computed(() => cashRegisterStore.isStaleSession || Boolean(pendingOpenerExpiredSession.value));
const staleDate = computed(() => {
  if (cashRegisterStore.staleSessionDate) return cashRegisterStore.staleSessionDate;
  if (!pendingOpenerExpiredSession.value?.openedAt) return '';
  return new Date(pendingOpenerExpiredSession.value.openedAt).toLocaleDateString('es-CO', {
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
  });
});

// Prioridad Compuerta F (N5): bloquea navegación y cambio de pestaña si +24h o reconciliación forzada pendiente
const isForcedGateLocked = computed(
  () => showAuditModal.value || (isStale.value && canOpenCloseCash.value)
);

const resolveAuthorizedTab = (requested?: unknown): CashTab => {
  if (!canOpenCloseCash.value) return 'movements';
  if (isForcedGateLocked.value) return 'shift';
  if (requested === 'expenses' && authStore.isAdmin) return 'expenses';
  if (requested === 'movements') return 'movements';
  return 'shift';
};

const activeTab = ref<CashTab>(resolveAuthorizedTab(route?.query?.tab));

const normalizeRouteTabIfNeeded = (requested: unknown, resolved: CashTab) => {
  if (!route || typeof router.replace !== 'function') return;
  if (requested !== undefined && requested !== resolved) {
    router.replace({ query: { ...route.query, tab: resolved } });
  }
};

watch(
  () => [route?.query?.tab, authStore.isAdmin, canOpenCloseCash.value, isForcedGateLocked.value] as const,
  ([requested]) => {
    const resolved = resolveAuthorizedTab(requested);
    activeTab.value = resolved;
    normalizeRouteTabIfNeeded(requested, resolved);
  },
  { immediate: true }
);

const selectTab = (tab: CashTab) => {
  if (isForcedGateLocked.value && tab !== 'shift') return;
  const resolved = resolveAuthorizedTab(tab);
  activeTab.value = resolved;
  if (route && typeof router.replace === 'function') {
    router.replace({ query: { ...route.query, tab: resolved } });
  }
};

const syncWorkspace = async () => {
  if (!canOpenCloseCash.value) {
    syncError.value = null;
    isLoadingWorkspace.value = false;
    return;
  }

  const storeId = authStore.currentStore?.id || authStore.currentUser?.storeId;
  if (!storeId) {
    syncError.value = 'No hay una tienda activa cargada. Inicia sesión nuevamente.';
    isLoadingWorkspace.value = false;
    return;
  }

  isLoadingWorkspace.value = true;
  syncError.value = null;

  try {
    logger.log('🔍 [CashControl] Syncing Status for Store:', storeId);
    const result = await cashRegisterStore.syncFromBackend(storeId, { throwOnError: true });
    logger.log('✅ [CashControl] Sync Result:', {
      isOpen: cashRegisterStore.isOpen,
      result,
      session: cashRegisterStore.currentSession
    });

    const usedAttempts =
      cashRegisterStore.currentSession?.closingAttempts ||
      cashRegisterStore.pendingForcedSessionInfo?.closingAttempts ||
      0;
    if (usedAttempts > 0 && usedAttempts < 3) {
      assistedRetryNotice.value = {
        attemptsUsed: usedAttempts,
        attemptsRemaining: 3 - usedAttempts,
        message: 'Tienes un intento previo de conteo pendiente de completar.',
      };
    }

    await fetchPendingForcedSessions();
  } catch (e: any) {
    console.error('🚫 [CashControl] Mount Error:', e);
    syncError.value =
      e?.message ||
      cashRegisterStore.lastSyncError ||
      'No se pudo sincronizar el estado de la caja con el servidor.';
  } finally {
    isLoadingWorkspace.value = false;
  }
};

onMounted(() => {
  syncWorkspace();
});

const handleAuditConfirm = async (sessionId: string, actualBalance: number | null) => {
  const employeeId = authStore.currentUser?.employeeId || authStore.currentUser?.id;
  if (!employeeId) {
    forcedReconcileError.value = 'No se encontró el ID del usuario para la reconciliación.';
    showError(forcedReconcileError.value);
    return;
  }

  isReconcilingForced.value = true;
  forcedReconcileError.value = null;
  try {
    await cashRegisterStore.reconcileForcedClose(sessionId, employeeId, actualBalance);

    pendingForcedSessions.value = pendingForcedSessions.value.filter(s => s.id !== sessionId);
    if (pendingForcedSessions.value.length === 0 && authStore.currentStore?.id) {
      try {
        await cashRegisterStore.syncFromBackend(authStore.currentStore.id);
      } catch {
        // La reconciliación ya quedó confirmada en BD
      }
    }
    showSuccess(
      actualBalance === null
        ? 'Turno cerrado sin conteo físico. Se generó alerta crítica de auditoría.'
        : 'Turno reconciliado correctamente.'
    );
  } catch (e: any) {
    console.error('🚫 [CashControl] Reconciliation failed:', e);
    const translated = translateReconciliationError(e?.message);
    forcedReconcileError.value = translated;
    showError(translated);
  } finally {
    isReconcilingForced.value = false;
  }
};

const isShiftOwnedByOther = computed(() => {
  if (isOpening.value || authStore.isAdmin) return false;
  const openerId = cashRegisterStore.currentSession?.employeeId;
  return Boolean(openerId && openerId !== 'unknown' && currentActorId.value && openerId !== currentActorId.value);
});
const openerDisplayName = computed(() => cashRegisterStore.currentSession?.openedByName || 'otro usuario');

const title = computed(() => {
  if (!canOpenCloseCash.value) return 'Mis Movimientos del Turno';
  if (activeTab.value === 'expenses') return 'Gastos de Caja';
  if (activeTab.value === 'movements') return 'Mis Movimientos del Turno';
  if (isLoadingWorkspace.value || syncError.value) return 'Control de Caja';
  if (isStale.value) return 'Turno Expirado (+24h)';
  return isOpening.value ? 'Apertura de Caja' : 'Cierre de Caja';
});

const buttonText = computed(() => {
  if (isStale.value) return 'CERRAR TURNO EXPIRADO';
  return isOpening.value ? 'ABRIR TURNO' : 'CONFIRMAR CONTEO Y CERRAR';
});

// Form State (POL-SEG-01 v1.5: Nace vacío = null para prohibir envíos en blanco; solo Efectivo físico del cajón)
const amount = ref<number | null>(null);
const notes = ref('');
const amountValidationError = ref<string | null>(null);
const isAmountEmpty = computed(() => amount.value === null || !Number.isFinite(Number(amount.value)) || Number(amount.value) < 0);
const adminExpectedSummary = computed(() => (authStore.isAdmin ? cashRegisterStore.adminExpectedSummary : null));

// Ejecución online obligatoria (C2-H2: checkConnectivity: true)
const handleSubmit = async () => {
  amountValidationError.value = null;

  if (!canOpenCloseCash.value) {
    showError('No tienes permisos asignados para operar la caja.');
    return;
  }

  if (syncError.value) {
    showError('Sincroniza el estado de caja pulsando "Reintentar" antes de operar.');
    return;
  }

  if (isShiftOwnedByOther.value) {
    showError(`Solo ${openerDisplayName.value} o el Administrador pueden cerrar este turno.`);
    return;
  }

  if (amount.value === null || !Number.isFinite(Number(amount.value)) || Number(amount.value) < 0) {
    amountValidationError.value = isOpening.value
      ? 'Digita la base inicial en efectivo (si abres sin base, escribe 0).'
      : 'Digita el efectivo físico contado en el cajón (si está vacío, escribe 0).';
    return;
  }

  const parsedAmount = Number(amount.value);

  await executeAction(async () => {
    if (isOpening.value) {
      if (fetchForcedSessionsError.value) {
        showError('No se pudo verificar si hay turnos pendientes de reconciliar. Pulsa "Reintentar" antes de abrir la caja.');
        return;
      }

      if (pendingForcedSessions.value.length > 0) {
        showError('Debes reconciliar los turnos cerrados forzosamente antes de abrir una nueva caja.');
        return;
      }

      const storeId = authStore.currentStore?.id;
      if (!storeId) {
        showError('No hay tienda asociada. Cierra sesión e ingresa de nuevo.');
        return;
      }

      if (authStore.currentUser?.id) {
        const secureId = authStore.currentUser.employeeId || authStore.currentUser.id;
        await cashRegisterStore.openRegister(
          secureId,
          storeId,
          new Decimal(parsedAmount),
          notes.value
        );
      } else {
        throw new Error('Usuario no autenticado');
      }
      showSuccess('Caja abierta correctamente');
      router.push('/');
    } else {
      // Closing (POL-SEG-01 v1.5: Arqueo físico exclusivo sobre Efectivo del cajón)
      assistedRetryNotice.value = null;
      const closeResult = await cashRegisterStore.closeRegister(
        {
          efectivo: parsedAmount,
        },
        notes.value,
        authStore.currentStore?.id
      );

      if (!closeResult.success && closeResult.code === 'COUNT_MISMATCH_RETRY') {
        assistedRetryNotice.value = {
          attemptsUsed: closeResult.attemptsUsed ?? 1,
          attemptsRemaining: closeResult.attemptsRemaining ?? 2,
          message: closeResult.message || 'El conteo de efectivo no coincide con el registro del turno. Revisa y vuelve a intentar.',
        };
        showWarning(`${assistedRetryNotice.value.message} (Restan ${assistedRetryNotice.value.attemptsRemaining} intento(s))`);
        return;
      }

      if (closeResult.sealedWithAlert) {
        showWarning('Turno cerrado al 3.er intento. Se envió alerta al Administrador.');
      } else {
        showSuccess('Turno cerrado correctamente.');
      }
      closedSealSummary.value = {
        sealedWithAlert: Boolean(closeResult.sealedWithAlert),
        closedByName: closeResult.closedByName,
        expectedEfectivo: authStore.isAdmin ? closeResult.expectedEfectivo : undefined,
        actualEfectivo: authStore.isAdmin ? closeResult.actualEfectivo : undefined,
        difference: authStore.isAdmin ? closeResult.difference : undefined,
      };
    }
  }, {
    checkConnectivity: true,
    errorMessage: 'Error en la operación de caja'
  });
};

const finishClosing = () => {
  closedSealSummary.value = null;
  router.push('/');
};

const goBack = () => {
  if (isForcedGateLocked.value) return;
  if (typeof window !== 'undefined' && window.history.length > 1) {
    router.back();
  } else {
    router.push('/');
  }
};
</script>

<template>
  <div class="min-h-screen bg-background-light dark:bg-background-dark flex flex-col">
    <!-- Header -->
    <header class="bg-surface-light dark:bg-surface-dark p-4 shadow-sm border-b border-slate-200 dark:border-slate-700 flex items-center justify-between">
      <button
        type="button"
        @click="goBack"
        class="p-2 -ml-2 rounded-xl text-slate-500 hover:bg-slate-100 dark:hover:bg-slate-700"
        :class="{ 'opacity-30 cursor-not-allowed': isForcedGateLocked }"
        :disabled="isForcedGateLocked"
      >
        <ArrowLeft :size="24" :stroke-width="1.5" />
      </button>
      <div class="flex items-center gap-2">
        <AlertTriangle
          v-if="activeTab === 'shift' && isStale"
          :size="18"
          class="text-amber-600 dark:text-amber-400 shrink-0"
        />
        <h1 class="text-lg font-bold text-slate-900 dark:text-white">{{ title }}</h1>
      </div>
      <div class="w-10"></div>
    </header>

    <!-- Barra de Pestañas (Segregada por Rol; oculta si !canOpenCloseCash) -->
    <nav
      v-if="availableTabs.length > 1"
      data-test="cash-workspace-tabs"
      class="bg-surface-light dark:bg-surface-dark border-b border-slate-200 dark:border-slate-700 px-4"
    >
      <div class="max-w-md mx-auto flex gap-2">
        <button
          v-for="tab in availableTabs"
          :key="tab.id"
          type="button"
          :data-test="`tab-${tab.id}`"
          :disabled="isForcedGateLocked && tab.id !== 'shift'"
          @click="selectTab(tab.id)"
          class="flex-1 py-3 text-xs font-bold border-b-2 transition-colors"
          :class="[
            activeTab === tab.id
              ? 'border-primary text-primary'
              : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200',
            isForcedGateLocked && tab.id !== 'shift' ? 'opacity-40 cursor-not-allowed' : ''
          ]"
        >
          {{ tab.label }}
        </button>
      </div>
    </nav>

    <main class="flex-1 p-4 max-w-md mx-auto w-full flex flex-col gap-6">
      <!-- TAB 3: MIS MOVIMIENTOS DEL TURNO (Arquetipo E — Independiente de syncWorkspace de Apertura/Cierre) -->
      <OwnShiftMovementsTab v-if="activeTab === 'movements' || !canOpenCloseCash" />

      <!-- Skeleton durante carga inicial (C2-H2: protege tanto Turno como Gastos; nunca flashear Apertura/Caja Cerrada) -->
      <BaseListSkeleton v-else-if="isLoadingWorkspace" :count="3" type="card" data-test="workspace-loading-skeleton" />

      <!-- Banner N3 Persistente de Error de Sincronización Inicial (Fail-Closed para Turno y Gastos) -->
      <div
        v-else-if="syncError"
        data-test="sync-error-banner"
        class="bg-rose-50 dark:bg-rose-950/30 border border-rose-300 dark:border-rose-700 rounded-2xl p-4 space-y-3"
      >
        <div class="flex items-start gap-3">
          <AlertTriangle :size="20" class="text-rose-600 dark:text-rose-400 shrink-0 mt-0.5" />
          <div>
            <h3 class="text-sm font-bold text-rose-900 dark:text-rose-200">
              No se pudo verificar el estado de la caja
            </h3>
            <p class="text-xs text-rose-800 dark:text-rose-300 mt-1 leading-relaxed">
              {{ syncError }}
            </p>
          </div>
        </div>
        <BaseButton size="sm" variant="outline" data-test="btn-retry-sync" @click="syncWorkspace">
          <span class="flex items-center gap-1.5">
            <RefreshCw :size="14" />
            Reintentar
          </span>
        </BaseButton>
      </div>

      <!-- TAB 1: TURNO / ARQUEO -->
      <template v-else-if="activeTab === 'shift'">
          <!-- Error de Carga de Cierres Forzados (Anti-Fallo Silencioso) -->
          <div v-if="fetchForcedSessionsError" class="bg-rose-50 dark:bg-rose-900/30 border border-rose-400 dark:border-rose-600 rounded-2xl p-4 flex items-center justify-between">
            <div class="flex items-center gap-3">
              <AlertTriangle :size="20" class="text-rose-600" />
              <p class="text-xs text-rose-700 dark:text-rose-300 font-medium">Error al verificar turnos forzados pendientes.</p>
            </div>
            <button @click="fetchPendingForcedSessions" class="px-3 py-1.5 bg-rose-600 text-white rounded-lg text-xs font-bold flex items-center gap-1.5 hover:bg-rose-700">
              <RefreshCw :size="14" /> Reintentar
            </button>
          </div>

          <!-- FRD-015: Stale Shift Alert Banner -->
          <div v-if="isStale" class="bg-amber-50 dark:bg-amber-900/30 border border-amber-400 dark:border-amber-600 rounded-2xl p-4 animate-slide-up">
            <div class="flex items-start gap-3">
              <div class="bg-amber-100 dark:bg-amber-800/40 w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0">
                <AlertTriangle :size="22" class="text-amber-600 dark:text-amber-400" />
              </div>
              <div>
                <h3 class="font-bold text-amber-800 dark:text-amber-200 text-sm">Turno Sin Cerrar</h3>
                <p class="text-amber-700 dark:text-amber-300 text-xs mt-1 leading-relaxed">
                  Existe un turno abierto desde <strong>{{ staleDate }}</strong> que no fue cerrado.
                  Debes cerrarlo ahora para poder continuar operando.
                </p>
              </div>
            </div>
          </div>

          <!-- Opening State: Simple Form -->
          <div v-if="isOpening" class="bg-surface-light dark:bg-surface-dark rounded-2xl shadow-sm p-6 border border-slate-200 dark:border-slate-700 animate-slide-up">
            <div class="text-center mb-6">
              <div class="bg-emerald-100 dark:bg-emerald-900/30 w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-3">
                <LockOpen :size="32" class="text-emerald-600 dark:text-emerald-400" />
              </div>
              <p class="text-slate-500 dark:text-slate-400 text-sm">Ingresa el dinero base en caja para iniciar operaciones.</p>
            </div>

            <div class="space-y-4">
              <div>
                <label class="block text-xs font-bold uppercase text-slate-400 mb-1">Base Inicial en Efectivo</label>
                <FormInputCurrency
                  v-model="amount"
                  :allow-null="true"
                  placeholder="Digita el monto"
                  data-test="cash-amount-input"
                  class="text-2xl font-bold text-center font-mono tabular-nums"
                  :autofocus="true"
                  :disabled="!canOpenCloseCash"
                  @update:modelValue="amountValidationError = null"
                />
                <p
                  v-if="amountValidationError"
                  data-test="opening-amount-error"
                  class="mt-1.5 text-xs text-rose-600 dark:text-rose-400 text-center"
                >
                  {{ amountValidationError }}
                </p>
              </div>

              <div>
                <label class="block text-xs font-bold uppercase text-slate-400 mb-1">Notas (Opcional)</label>
                <textarea v-model="notes" rows="2" class="w-full p-3 bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 rounded-lg text-sm" placeholder="Observaciones..." :disabled="!canOpenCloseCash"></textarea>
              </div>
            </div>
          </div>

          <!-- Closing State: Arqueo Físico Exclusivo de Efectivo (Abierto para Admin / Ciego Asistido con Margen para Empleados) -->
          <div v-else class="space-y-4 animate-slide-up">
            <!-- Banner Propiedad Estricta del Turno (POL-SEG-03) -->
            <div v-if="isShiftOwnedByOther" class="bg-rose-50 dark:bg-rose-900/30 border border-rose-400 dark:border-rose-600 rounded-2xl p-4">
              <div class="flex items-start gap-3">
                <AlertTriangle :size="22" class="text-rose-600 dark:text-rose-400 flex-shrink-0 mt-0.5" />
                <div>
                  <h4 class="font-bold text-rose-800 dark:text-rose-200 text-sm">Turno Pertenece a Otro Usuario</h4>
                  <p class="text-rose-700 dark:text-rose-300 text-xs mt-1 leading-relaxed">
                    Este turno fue abierto por <strong>{{ openerDisplayName }}</strong>. Solo quien abrió el turno o el Administrador pueden cerrarlo.
                  </p>
                </div>
              </div>
            </div>

            <!-- Banner Cierre Asistido (Solo Empleados — Intentos 1 y 2 sin revelar esperado) -->
            <div v-if="!authStore.isAdmin && assistedRetryNotice" class="bg-amber-50 dark:bg-amber-900/30 border border-amber-400 dark:border-amber-600 rounded-2xl p-4" data-test="assisted-retry-banner">
              <div class="flex items-start justify-between gap-2">
                <div>
                  <h4 class="font-bold text-amber-800 dark:text-amber-200 text-sm">Revisa tu conteo</h4>
                  <p class="text-amber-700 dark:text-amber-300 text-xs mt-1 leading-relaxed">
                    {{ assistedRetryNotice.message }}
                  </p>
                </div>
                <span class="shrink-0 px-2.5 py-1 rounded-full bg-amber-200/80 dark:bg-amber-800/60 text-amber-900 dark:text-amber-100 text-[11px] font-bold">
                  Intento {{ assistedRetryNotice.attemptsUsed }} de 3
                </span>
              </div>
            </div>

            <!-- Resumen del Turno (EXCLUSIVO ADMINISTRADOR — Autoridad del Servidor) -->
            <div
              v-if="authStore.isAdmin && adminExpectedSummary"
              data-test="admin-expected-summary"
              class="rounded-2xl bg-emerald-50 dark:bg-emerald-950/30 border border-emerald-200 dark:border-emerald-800/50 p-4 space-y-3"
            >
              <div class="flex items-center justify-between">
                <span class="text-xs font-bold uppercase tracking-wide text-emerald-800 dark:text-emerald-300">
                  Efectivo esperado en cajón
                </span>
                <span class="text-xl font-black font-mono tabular-nums text-emerald-900 dark:text-emerald-200">
                  {{ formatWithSign(adminExpectedSummary.efectivo) }}
                </span>
              </div>
              <div class="pt-2 border-t border-emerald-200/70 dark:border-emerald-800/50 grid grid-cols-2 gap-2 text-xs">
                <div class="rounded-xl bg-white/70 dark:bg-slate-900/40 px-3 py-2">
                  <p class="text-[10px] font-bold uppercase text-slate-500 dark:text-slate-400">Movimientos Nequi</p>
                  <p class="font-mono tabular-nums font-bold text-slate-800 dark:text-slate-200 mt-0.5">
                    {{ formatWithSign(adminExpectedSummary.nequi) }}
                  </p>
                </div>
                <div class="rounded-xl bg-white/70 dark:bg-slate-900/40 px-3 py-2">
                  <p class="text-[10px] font-bold uppercase text-slate-500 dark:text-slate-400">Movimientos Llave Bre-B</p>
                  <p class="font-mono tabular-nums font-bold text-slate-800 dark:text-slate-200 mt-0.5">
                    {{ formatWithSign(adminExpectedSummary.llave_bre) }}
                  </p>
                </div>
              </div>
              <p class="text-[11px] text-emerald-700/90 dark:text-emerald-300/80">
                Nequi y Llave Bre-B son solo informativos; aquí solo cuentas los billetes y monedas del cajón.
              </p>
            </div>

            <!-- Protocolo de Arqueo Ciego (EXCLUSIVO EMPLEADOS) -->
            <div
              v-else-if="!authStore.isAdmin"
              data-test="employee-blind-protocol-banner"
              class="flex items-start gap-3 p-4 rounded-2xl bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800/40"
            >
              <ShieldCheck :size="24" class="text-blue-600 dark:text-blue-400 mt-0.5 flex-shrink-0" />
              <div>
                <h4 class="text-sm font-bold text-blue-900 dark:text-blue-100">Conteo de Efectivo en Cajón</h4>
                <p class="text-xs text-blue-700 dark:text-blue-300 mt-1 leading-relaxed">
                  Cuenta únicamente los billetes y monedas físicos del cajón. El servidor validará el cuadre sin mostrar el saldo esperado.
                </p>
              </div>
            </div>

            <!-- Counting Input (Solo Efectivo Físico del Cajón) -->
            <div class="bg-surface-light dark:bg-surface-dark rounded-2xl shadow-sm p-6 border border-slate-200 dark:border-slate-700 space-y-4">
              <div>
                <label class="block text-xs font-bold uppercase text-slate-400 mb-2 text-center">Efectivo Contado en Cajón</label>
                <FormInputCurrency
                  v-model="amount"
                  :allow-null="true"
                  placeholder="Digita el monto"
                  data-test="cash-amount-input"
                  class="text-3xl font-black text-center font-mono tabular-nums text-blue-900 dark:text-blue-100"
                  :disabled="!canOpenCloseCash || isShiftOwnedByOther"
                  @update:modelValue="amountValidationError = null"
                />
                <p
                  v-if="amountValidationError"
                  data-test="closing-amount-error"
                  class="mt-1.5 text-xs text-rose-600 dark:text-rose-400 text-center"
                >
                  {{ amountValidationError }}
                </p>
              </div>

              <div>
                <label class="block text-xs font-bold uppercase text-slate-400 mb-1">Notas del Cierre</label>
                <textarea v-model="notes" rows="2" class="w-full p-3 bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 rounded-lg text-sm" placeholder="Observaciones sobre el conteo..." :disabled="!canOpenCloseCash || isShiftOwnedByOther"></textarea>
              </div>
            </div>
          </div>

          <!-- Action Button -->
          <BaseButton
            @click="handleSubmit"
            :loading="isSubmitting"
            :disabled="isSubmitting || !canOpenCloseCash || isShiftOwnedByOther || Boolean(syncError) || isAmountEmpty"
            :variant="isOpening ? 'success' : 'dark'"
            class="w-full h-14 text-lg shadow-lg"
            :class="isOpening ? 'shadow-emerald-500/30' : 'shadow-slate-500/30'"
          >
            <div class="flex items-center gap-2">
              <component :is="isOpening ? Store : Lock" :size="20" />
              {{ buttonText }}
            </div>
          </BaseButton>
      </template>

      <!-- TAB 2: GASTOS OPEX DEL TURNO (Estrictamente Admin) -->
      <ShiftExpensesTab
        v-else-if="activeTab === 'expenses' && authStore.isAdmin"
        :session-id="cashRegisterStore.currentSession?.id ?? null"
        :is-open="cashRegisterStore.isOpen"
      />
    </main>

    <!-- FRD-017 / FRD-027-02: Forced Close Audit Modal (Admin-only con conteo opcional) -->
    <ForcedCloseAuditModal
      :isVisible="showAuditModal"
      :pendingSessions="pendingForcedSessions"
      :allowSkipCount="authStore.isAdmin"
      :isSubmitting="isReconcilingForced"
      :errorMessage="forcedReconcileError"
      @confirm="handleAuditConfirm"
    />

    <!-- Post-Cierre Blind Confirmation Modal en BaseModal (POL-SEG-01: Cero exposición de esperado/diferencia) -->
    <BaseModal
      :model-value="Boolean(closedSealSummary)"
      :show-drag-handle="false"
      :show-close-button="false"
      data-test="blind-close-modal"
      @update:model-value="(val) => !val && finishClosing()"
    >
      <div v-if="closedSealSummary" class="p-6 space-y-4">
        <div class="text-center">
          <div
            class="size-14 rounded-2xl mx-auto flex items-center justify-center mb-3"
            :class="closedSealSummary.sealedWithAlert ? 'bg-amber-100 text-amber-600 dark:bg-amber-900/30' : 'bg-emerald-100 text-emerald-600 dark:bg-emerald-900/30'"
          >
            <AlertTriangle v-if="closedSealSummary.sealedWithAlert" :size="32" />
            <CheckCircle v-else :size="32" />
          </div>
          <h3 class="text-lg font-bold text-slate-900 dark:text-white">
            {{ closedSealSummary.sealedWithAlert ? 'Turno Cerrado con Alerta' : 'Turno Cerrado' }}
          </h3>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-1 leading-relaxed">
            {{
              closedSealSummary.sealedWithAlert
                ? 'El turno fue sellado tras completar los 3 intentos y se envió una notificación al Administrador para revisión.'
                : 'Tu conteo de efectivo fue registrado correctamente y sellado en la bitácora del servidor.'
            }}
          </p>
          <div
            v-if="authStore.isAdmin && typeof closedSealSummary.difference === 'number'"
            data-test="admin-close-diff-summary"
            class="mt-3 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 p-3 text-xs space-y-1 font-mono tabular-nums"
          >
            <div class="flex justify-between">
              <span class="text-slate-500">Esperado en cajón:</span>
              <span class="font-bold text-slate-800 dark:text-white">{{ formatWithSign(closedSealSummary.expectedEfectivo ?? 0) }}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-slate-500">Contado en cajón:</span>
              <span class="font-bold text-slate-800 dark:text-white">{{ formatWithSign(closedSealSummary.actualEfectivo ?? 0) }}</span>
            </div>
            <div class="flex justify-between pt-1 border-t border-slate-200 dark:border-slate-700">
              <span class="text-slate-500">Diferencia exacta:</span>
              <span
                class="font-bold"
                :class="(closedSealSummary.difference ?? 0) === 0 ? 'text-emerald-600' : (closedSealSummary.difference ?? 0) > 0 ? 'text-blue-600' : 'text-rose-600'"
              >
                {{ formatWithSign(closedSealSummary.difference ?? 0) }}
              </span>
            </div>
          </div>
        </div>

        <BaseButton @click="finishClosing" class="w-full">
          Aceptar y Finalizar
        </BaseButton>
      </div>
    </BaseModal>
  </div>
</template>

<style scoped>
.animate-slide-up {
  animation: slideUp 0.4s ease-out;
}
@keyframes slideUp {
  from { opacity: 0; transform: translateY(20px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>

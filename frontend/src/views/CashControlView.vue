<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useCashRegisterStore } from '../stores/cashRegister';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useNotifications } from '../composables/useNotifications';
import FormInputCurrency from '../components/ui/FormInputCurrency.vue';
import ForcedCloseAuditModal, { type PendingForcedSession } from '../components/ForcedCloseAuditModal.vue';
import Decimal from 'decimal.js';

import { useAuthStore } from '../stores/auth';
import BaseButton from '@/components/ui/BaseButton.vue';
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

const router = useRouter();
const cashRegisterStore = useCashRegisterStore();
const authStore = useAuthStore();
const { formatCurrency: _formatCurrency } = useCurrencyFormat();
const { showSuccess, showError, showWarning } = useNotifications();
// Composable: Request Management
import { useAsyncAction } from '../composables/useAsyncAction';
const { execute: executeAction, isLoading: isSubmitting } = useAsyncAction();

// =============================================
// FORCED CLOSE AUDIT STATE (FRD-017 / FRD-027-02)
// =============================================
const pendingForcedSessions = ref<PendingForcedSession[]>([]);
const fetchForcedSessionsError = ref(false);
const showAuditModal = computed(() => authStore.isAdmin && pendingForcedSessions.value.length > 0);

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

const handleAuditConfirm = async (sessionId: string, actualBalance: number | null) => {
    const employeeId = authStore.currentUser?.employeeId || authStore.currentUser?.id;
    if (!employeeId) {
        showError('No se encontró el ID del usuario para la reconciliación.');
        return;
    }

    try {
        await cashRegisterStore.reconcileForcedClose(sessionId, employeeId, actualBalance);

        // Eliminar la sesión conciliada de la cola
        pendingForcedSessions.value = pendingForcedSessions.value.filter(s => s.id !== sessionId);
        showSuccess(
            actualBalance === null
                ? 'Turno cerrado sin conteo físico. Se generó alerta crítica de auditoría.'
                : 'Turno reconciliado correctamente.'
        );
    } catch (e: any) {
        console.error('🚫 [CashControl] Reconciliation failed:', e);
        showError(translateReconciliationError(e?.message));
    }
};

// Traduce el código técnico del backend a un mensaje accionable (el backend no conoce la UI)
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

// Post-Cierre Blind Confirmation State (POL-SEG-01: NUNCA expone expected_balance ni difference)
const closedSealSummary = ref<{
    sealedWithAlert: boolean;
    closedByName?: string;
} | null>(null);

// Assisted Close Retry State (Cierre Asistido 3 intentos)
const assistedRetryNotice = ref<{
    attemptsUsed: number;
    attemptsRemaining: number;
    message: string;
} | null>(null);

// Lifecycle
onMounted(async () => {
    try {
        if (!authStore.currentStore) {
            console.error('🚫 [CashControl] No store loaded in AuthStore!');
            return;
        }

        logger.log('🔍 [CashControl] Syncing Status for Store:', authStore.currentStore.id);
        const result = await cashRegisterStore.syncFromBackend(authStore.currentStore.id);
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
    } catch (e) {
        console.error('🚫 [CashControl] Mount Error:', e);
    }
});

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

const isShiftOwnedByOther = computed(() => {
    if (isOpening.value || authStore.isAdmin) return false;
    const openerId = cashRegisterStore.currentSession?.employeeId;
    return Boolean(openerId && openerId !== 'unknown' && currentActorId.value && openerId !== currentActorId.value);
});
const openerDisplayName = computed(() => cashRegisterStore.currentSession?.openedByName || 'otro usuario');

const title = computed(() => {
    if (isStale.value) return '⚠️ Turno Expirado (+24h)';
    return isOpening.value ? 'Apertura de Caja' : 'Cierre de Caja';
});
const buttonText = computed(() => {
    if (isStale.value) return 'CERRAR TURNO EXPIRADO';
    return isOpening.value ? 'ABRIR TURNO' : 'CONFIRMAR CONTEO Y CERRAR';
});

// Permiso preventivo canOpenCloseCash (Fail-Closed: delega a authStore.canOpenCloseCash)
const canOpenCloseCash = computed(() => authStore.canOpenCloseCash);

// Form State (Multicanal para cierre: Efectivo, Nequi, Llave Bre-B)
const amount = ref(0);
const nequiAmount = ref(0);
const llaveBreAmount = ref(0);
const notes = ref('');

// Ejecución directa sin PinChallengeModal (POL-SEG-03: 1 dispositivo por cuenta)
const handleSubmit = async () => {
    if (!canOpenCloseCash.value) {
        showError('No tienes permisos asignados para operar la caja.');
        return;
    }

    if (isShiftOwnedByOther.value) {
        showError(`Solo ${openerDisplayName.value} o el Administrador pueden cerrar este turno.`);
        return;
    }

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
                    new Decimal(amount.value),
                    notes.value
                );
            } else {
                throw new Error('Usuario no autenticado');
            }
            showSuccess('Caja abierta correctamente');
            router.push('/');
        } else {
            // Closing (Arqueo Ciego con Cierre Asistido 3 Intentos)
            assistedRetryNotice.value = null;
            const closeResult = await cashRegisterStore.closeRegister(
                {
                    efectivo: amount.value,
                    nequi: nequiAmount.value,
                    llave_bre: llaveBreAmount.value,
                },
                notes.value,
                authStore.currentStore?.id
            );

            if (!closeResult.success && closeResult.code === 'COUNT_MISMATCH_RETRY') {
                assistedRetryNotice.value = {
                    attemptsUsed: closeResult.attemptsUsed ?? 1,
                    attemptsRemaining: closeResult.attemptsRemaining ?? 2,
                    message: closeResult.message || 'El conteo no coincide con el registro del turno. Revisa y vuelve a intentar.',
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
            };
        }
    }, {
        checkConnectivity: false,
        errorMessage: 'Error en la operación de caja'
    });
};

const finishClosing = () => {
    closedSealSummary.value = null;
    router.push('/');
};

const goBack = () => {
    if (isStale.value) return;
    router.back();
};
</script>

<template>
    <div class="min-h-screen bg-gray-50 dark:bg-gray-900 flex flex-col">
        <!-- Header -->
        <div class="bg-white dark:bg-gray-800 p-4 shadow-sm border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
            <button @click="goBack" class="p-2 -ml-2 rounded-xl text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700" :class="{ 'opacity-30 cursor-not-allowed': isStale }">
                <ArrowLeft :size="24" :stroke-width="1.5" />
            </button>
            <h1 class="text-lg font-bold text-gray-800 dark:text-gray-100">{{ title }}</h1>
            <button
                type="button"
                @click="router.push('/my-shift-movements')"
                class="text-xs font-semibold text-primary hover:underline px-2 py-1 rounded-lg"
            >
                Mis movimientos
            </button>
        </div>

        <div class="flex-1 p-4 max-w-md mx-auto w-full flex flex-col gap-6">

            <!-- Banner Permiso Restringido -->
            <div v-if="!canOpenCloseCash" class="bg-red-50 dark:bg-red-900/30 border-2 border-red-400 dark:border-red-600 rounded-2xl p-4">
                <div class="flex items-start gap-3">
                    <AlertTriangle :size="22" class="text-red-600 dark:text-red-400 flex-shrink-0 mt-0.5" />
                    <div>
                        <h3 class="font-bold text-red-800 dark:text-red-200 text-sm">Acceso Restringido</h3>
                        <p class="text-red-700 dark:text-red-300 text-xs mt-1 leading-relaxed">
                            Tu usuario no tiene asignado el permiso para aperturar o cerrar turnos de caja. Consulta con el administrador.
                        </p>
                    </div>
                </div>
            </div>

            <!-- Error de Carga de Cierres Forzados (Anti-Fallo Silencioso) -->
            <div v-if="fetchForcedSessionsError" class="bg-red-50 dark:bg-red-900/30 border-2 border-red-400 dark:border-red-600 rounded-2xl p-4 flex items-center justify-between">
                <div class="flex items-center gap-3">
                    <AlertTriangle :size="20" class="text-red-600" />
                    <p class="text-xs text-red-700 dark:text-red-300 font-medium">Error al verificar turnos forzados pendientes.</p>
                </div>
                <button @click="fetchPendingForcedSessions" class="px-3 py-1.5 bg-red-600 text-white rounded-lg text-xs font-bold flex items-center gap-1.5 hover:bg-red-700">
                    <RefreshCw :size="14" /> Reintentar
                </button>
            </div>

            <!-- FRD-015: Stale Shift Alert Banner -->
            <div v-if="isStale" class="bg-amber-50 dark:bg-amber-900/30 border-2 border-amber-400 dark:border-amber-600 rounded-2xl p-4 animate-slide-up">
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
            <div v-if="isOpening" class="bg-white dark:bg-gray-800 rounded-2xl shadow-sm p-6 border border-gray-100 dark:border-gray-700 animate-slide-up">
                <div class="text-center mb-6">
                    <div class="bg-emerald-100 dark:bg-emerald-900/30 w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-3">
                        <LockOpen :size="32" class="text-emerald-600 dark:text-emerald-400" />
                    </div>
                    <p class="text-gray-500 dark:text-gray-400 text-sm">Ingresa el dinero base en caja para iniciar operaciones.</p>
                </div>

                <div class="space-y-4">
                    <div>
                        <label class="block text-xs font-bold uppercase text-gray-400 mb-1">Base Inicial</label>
                        <FormInputCurrency v-model="amount" placeholder="0" class="text-2xl font-bold text-center" :autofocus="true" :disabled="!canOpenCloseCash" />
                    </div>
                    
                     <div>
                        <label class="block text-xs font-bold uppercase text-gray-400 mb-1">Notas (Opcional)</label>
                        <textarea v-model="notes" rows="2" class="w-full p-3 bg-gray-50 dark:bg-gray-700 border-none rounded-lg text-sm" placeholder="Observaciones..." :disabled="!canOpenCloseCash"></textarea>
                    </div>
                </div>
            </div>

            <!-- Closing State: Arqueo Ciego + Cierre Asistido 3 Intentos + Propiedad Estricta -->
            <div v-else class="space-y-4 animate-slide-up">
                <!-- Banner Propiedad Estricta del Turno (POL-SEG-03) -->
                <div v-if="isShiftOwnedByOther" class="bg-red-50 dark:bg-red-900/30 border-2 border-red-400 dark:border-red-600 rounded-2xl p-4">
                    <div class="flex items-start gap-3">
                        <AlertTriangle :size="22" class="text-red-600 dark:text-red-400 flex-shrink-0 mt-0.5" />
                        <div>
                            <h4 class="font-bold text-red-800 dark:text-red-200 text-sm">Turno Pertenece a Otro Usuario</h4>
                            <p class="text-red-700 dark:text-red-300 text-xs mt-1 leading-relaxed">
                                Este turno fue abierto por <strong>{{ openerDisplayName }}</strong>. Solo quien abrió el turno o el Administrador pueden cerrarlo.
                            </p>
                        </div>
                    </div>
                </div>

                <!-- Banner Cierre Asistido (Intentos 1 y 2 sin revelar esperado) -->
                <div v-if="assistedRetryNotice" class="bg-amber-50 dark:bg-amber-900/30 border-2 border-amber-400 dark:border-amber-600 rounded-2xl p-4" data-test="assisted-retry-banner">
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

                <!-- Protocolo de Arqueo Ciego -->
                <div class="flex items-start gap-3 p-4 rounded-2xl bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800/40">
                    <ShieldCheck :size="24" class="text-blue-600 dark:text-blue-400 mt-0.5 flex-shrink-0" />
                    <div>
                        <h4 class="text-sm font-bold text-blue-900 dark:text-blue-100">Protocolo de Arqueo Ciego</h4>
                        <p class="text-xs text-blue-700 dark:text-blue-300 mt-1 leading-relaxed">
                            Cuenta el dinero físico en gaveta y valida los saldos en Nequi y Llave Bre-B. El servidor validará el cuadre por canal sin revelar saldos esperados.
                        </p>
                    </div>
                </div>

                <!-- Counting Inputs Multicanal -->
                <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-sm p-6 border border-gray-100 dark:border-gray-700 space-y-4">
                    <div>
                        <label class="block text-xs font-bold uppercase text-gray-400 mb-2 text-center">Efectivo Total Contado</label>
                        <FormInputCurrency v-model="amount" placeholder="0" class="text-3xl font-black text-center text-blue-900 dark:text-blue-100" :disabled="!canOpenCloseCash || isShiftOwnedByOther" />
                    </div>

                    <div class="grid grid-cols-2 gap-3">
                        <div>
                            <label class="block text-[11px] font-bold uppercase text-gray-400 mb-1 text-center">Nequi Contado</label>
                            <FormInputCurrency v-model="nequiAmount" placeholder="0" class="text-base font-bold text-center" :disabled="!canOpenCloseCash || isShiftOwnedByOther" />
                        </div>
                        <div>
                            <label class="block text-[11px] font-bold uppercase text-gray-400 mb-1 text-center">Llave Bre-B Contado</label>
                            <FormInputCurrency v-model="llaveBreAmount" placeholder="0" class="text-base font-bold text-center" :disabled="!canOpenCloseCash || isShiftOwnedByOther" />
                        </div>
                    </div>

                    <div>
                        <label class="block text-xs font-bold uppercase text-gray-400 mb-1">Notas del Cierre</label>
                        <textarea v-model="notes" rows="2" class="w-full p-3 bg-gray-50 dark:bg-gray-700 border-none rounded-lg text-sm" placeholder="Observaciones sobre el conteo..." :disabled="!canOpenCloseCash || isShiftOwnedByOther"></textarea>
                    </div>
                </div>
            </div>

            <!-- Action Button -->
            <BaseButton 
                @click="handleSubmit" 
                :loading="isSubmitting"
                :disabled="isSubmitting || !canOpenCloseCash || isShiftOwnedByOther"
                :variant="isOpening ? 'success' : 'dark'"
                class="w-full h-14 text-lg shadow-lg"
                :class="isOpening ? 'shadow-emerald-500/30' : 'shadow-slate-500/30'"
            >
                <div class="flex items-center gap-2">
                    <component :is="isOpening ? Store : Lock" :size="20" />
                    {{ buttonText }}
                </div>
            </BaseButton>

        </div>

        <!-- FRD-017 / FRD-027-02: Forced Close Audit Modal (Admin-only con conteo opcional) -->
        <ForcedCloseAuditModal
            :isVisible="showAuditModal"
            :pendingSessions="pendingForcedSessions"
            :allowSkipCount="authStore.isAdmin"
            @confirm="handleAuditConfirm"
        />

        <!-- Post-Cierre Blind Confirmation Modal (POL-SEG-01: Cero exposición de esperado/diferencia) -->
        <div v-if="closedSealSummary" class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4" data-test="blind-close-modal">
            <div class="bg-white dark:bg-slate-800 w-full max-w-sm rounded-3xl p-6 shadow-2xl space-y-4 animate-slide-up border border-slate-100 dark:border-slate-700">
                <div class="text-center">
                    <div class="size-14 rounded-2xl mx-auto flex items-center justify-center mb-3"
                         :class="closedSealSummary.sealedWithAlert ? 'bg-amber-100 text-amber-600 dark:bg-amber-900/30' : 'bg-emerald-100 text-emerald-600 dark:bg-emerald-900/30'">
                        <AlertTriangle v-if="closedSealSummary.sealedWithAlert" :size="32" />
                        <CheckCircle v-else :size="32" />
                    </div>
                    <h3 class="text-lg font-bold text-gray-900 dark:text-white">
                        {{ closedSealSummary.sealedWithAlert ? 'Turno Cerrado con Alerta' : 'Turno Cerrado' }}
                    </h3>
                    <p class="text-xs text-gray-500 dark:text-gray-400 mt-1 leading-relaxed">
                        {{
                            closedSealSummary.sealedWithAlert
                                ? 'El turno fue sellado tras completar los 3 intentos y se envió una notificación al Administrador para revisión.'
                                : 'Tu arqueo fue registrado correctamente y sellado en la bitácora del servidor.'
                        }}
                    </p>
                </div>

                <BaseButton @click="finishClosing" class="w-full">
                    Aceptar y Finalizar
                </BaseButton>
            </div>
        </div>

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

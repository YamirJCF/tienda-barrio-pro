<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useCashRegisterStore } from '../stores/cashRegister';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useNotifications } from '../composables/useNotifications';
import FormInputCurrency from '../components/ui/FormInputCurrency.vue';
import PinChallengeModal from '../components/PinChallengeModal.vue';
import ForcedCloseAuditModal, { type PendingForcedSession } from '../components/ForcedCloseAuditModal.vue';
import Decimal from 'decimal.js';

import { useAuthStore } from '../stores/auth';
import BaseButton from '@/components/ui/BaseButton.vue';
import { requireSupabase } from '../data/supabaseClient';
import {
  ArrowLeft,
  LockOpen,
  Lock,
  Store,
  CheckCircle,
  Info,
  AlertTriangle,
  ShieldCheck,
  RefreshCw
} from 'lucide-vue-next';

const router = useRouter();
const cashRegisterStore = useCashRegisterStore();
const authStore = useAuthStore();
const { formatCurrency } = useCurrencyFormat();
const { showSuccess, showError } = useNotifications();
// Composable: Request Management
import { useAsyncAction } from '../composables/useAsyncAction';
const { execute: executeAction, isLoading: isSubmitting } = useAsyncAction();

// =============================================
// FORCED CLOSE AUDIT STATE (FRD-017)
// =============================================
const pendingForcedSessions = ref<PendingForcedSession[]>([]);
const fetchForcedSessionsError = ref(false);
const showAuditModal = computed(() => pendingForcedSessions.value.length > 0);

const fetchPendingForcedSessions = async () => {
    fetchForcedSessionsError.value = false;
    try {
        const supabase = requireSupabase();
        
        // Arqueo Ciego (POL-SEG-01): el saldo esperado NO viaja al cliente.
        // Solo se piden id y fecha de apertura; el servidor calcula la diferencia al reconciliar.
        const { data: sessions, error } = await supabase
            .from('cash_sessions')
            .select('id, opened_at')
            .eq('status', 'closed')
            .eq('forced_close', true)
            .is('actual_balance', null)
            .order('opened_at', { ascending: true });

        if (error) throw error;

        // La reconciliación de cierre forzado es solo en efectivo: el backend vivo
        // (cerrar_caja / rpc_check_and_force_close_shifts / rpc_reconciliar_cierre_forzado)
        // calcula expected_balance únicamente con cash_movements.payment_method = 'efectivo'.
        // cash_session_balances no existe en producción (Ola 4 diferida, RVC L20).
        pendingForcedSessions.value = (sessions ?? []).map(s => ({
            id:       s.id,
            openedAt: s.opened_at,
            channels: ['efectivo']
        }));
    } catch (e) {
        console.error('🚫 [CashControl] Failed to fetch pending forced sessions:', e);
        fetchForcedSessionsError.value = true;
    }
};

const handleAuditConfirm = async (sessionId: string, actualBalance: number) => {
    const employeeId = authStore.currentUser?.employeeId || authStore.currentUser?.id;
    if (!employeeId) {
        showError('No se encontró el ID del usuario para la reconciliación.');
        return;
    }

    try {
        const supabase = requireSupabase();
        const { data, error } = await supabase.rpc('rpc_reconciliar_cierre_forzado', {
            p_session_id:     sessionId,
            p_employee_id:    employeeId,
            p_actual_balance: actualBalance,
        });

        if (error) throw error;
        if (!data?.success) throw new Error('RECONCILIATION_FAILED');

        // Eliminar la sesión conciliada de la cola
        pendingForcedSessions.value = pendingForcedSessions.value.filter(s => s.id !== sessionId);
        showSuccess('Turno reconciliado correctamente.');
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
        EMPLOYEE_NOT_FOUND: 'Tu usuario no está registrado como empleado de esta tienda.',
        INSUFFICIENT_PERMISSIONS: 'No tienes permiso para reconciliar cierres de caja. Consulta con el administrador.',
        AUDIT_ACTOR_UNRESOLVABLE: 'Tu usuario no puede firmar la auditoría. Pide a un administrador que reconcilie el turno.',
    };
    return messages[code] || 'No se pudo reconciliar el turno. Intenta de nuevo.';
};

// Post-Cierre Confirmation State (Arqueo Ciego)
const closedReport = ref<{
    expected: number;
    actual: number;
    difference: number;
} | null>(null);

// Lifecycle
onMounted(async () => {
    try {
        if (!authStore.currentStore) {
            console.error('🚫 [CashControl] No store loaded in AuthStore!');
            return;
        }

        console.log('🔍 [CashControl] Syncing Status for Store:', authStore.currentStore.id);
        const result = await cashRegisterStore.syncFromBackend(authStore.currentStore.id);
        console.log('✅ [CashControl] Sync Result:', {
            isOpen: cashRegisterStore.isOpen,
            result,
            session: cashRegisterStore.currentSession
        });

        // Verificar si hay cierres forzados sin reconciliar
        await fetchPendingForcedSessions();
    } catch (e) {
        console.error('🚫 [CashControl] Mount Error:', e);
    }
});

// PIN Challenge State
const showPinModal = ref(false);
const pendingAction = ref<'open' | 'close'>('open');

// Computed State
const isOpening = computed(() => !cashRegisterStore.isOpen);
const isStale = computed(() => cashRegisterStore.isStaleSession);
const staleDate = computed(() => cashRegisterStore.staleSessionDate);
const title = computed(() => {
    if (isStale.value) return '⚠️ Cierre Pendiente';
    return isOpening.value ? 'Apertura de Caja' : 'Cierre de Caja';
});
const buttonText = computed(() => {
    if (isStale.value) return 'CERRAR TURNO PENDIENTE';
    return isOpening.value ? 'ABRIR TURNO' : 'CERRAR TURNO';
});

// Permiso preventivo canOpenCloseCash
const canOpenCloseCash = computed(() => {
    if (authStore.isAdmin) return true;
    const permissions = authStore.currentUser?.permissions as Record<string, any> | undefined;
    if (!permissions) return true;
    return permissions.canOpenCloseCash !== false;
});

// Form State
const amount = ref(0);
const notes = ref('');

// STEP 1: User clicks button -> Show PIN modal (do NOT execute yet)
const handleSubmit = () => {
    if (!canOpenCloseCash.value) {
        showError('No tienes permisos asignados para operar la caja.');
        return;
    }

    // ADMIN BYPASS: Admins (Owners) are already strongly authenticated
    if (authStore.isAdmin) {
        pendingAction.value = isOpening.value ? 'open' : 'close';
        handlePinSuccess(); // Skip challenge
        return;
    }

    pendingAction.value = isOpening.value ? 'open' : 'close';
    showPinModal.value = true;
};

// STEP 2: PIN validated successfully -> Execute the actual operation
const handlePinSuccess = async () => {
    showPinModal.value = false;
    
    await executeAction(async () => {
        if (pendingAction.value === 'open') {
            // No se puede abrir sin verificar turnos forzados pendientes (RN-017-03):
            // si la verificación falló, se bloquea (Regla 3: no saltar un control obligatorio).
            if (fetchForcedSessionsError.value) {
                showError('No se pudo verificar si hay turnos pendientes de reconciliar. Pulsa "Reintentar" antes de abrir la caja.');
                return;
            }

            // Bloqueo de apertura si hay reconciliaciones pendientes
            if (pendingForcedSessions.value.length > 0) {
                showError('Debes reconciliar los turnos cerrados forzosamente antes de abrir una nueva caja.');
                return;
            }

            // ===== VALIDACIÓN STOREID =====
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
            // Closing (Arqueo Ciego)
            const closeResult = await cashRegisterStore.closeRegister(new Decimal(amount.value), notes.value) as any;
            showSuccess('Turno cerrado. Reporte generado.');
            closedReport.value = {
                expected: Number(closeResult?.expected_balance ?? 0),
                actual: Number(closeResult?.actual_balance ?? amount.value),
                difference: Number(closeResult?.difference ?? 0)
            };
        }
    }, {
        checkConnectivity: false,
        errorMessage: 'Error en la operación de caja'
    });
};

const finishClosing = () => {
    closedReport.value = null;
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
            <div class="w-10"></div> <!-- Spacer -->
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

            <!-- Closing State: Arqueo Ciego Estricto (POL-SEG-01) -->
            <div v-else class="space-y-4 animate-slide-up">
                <!-- Protocolo de Arqueo Ciego -->
                <div class="flex items-start gap-3 p-4 rounded-2xl bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800/40">
                    <ShieldCheck :size="24" class="text-blue-600 dark:text-blue-400 mt-0.5 flex-shrink-0" />
                    <div>
                        <h4 class="text-sm font-bold text-blue-900 dark:text-blue-100">Protocolo de Arqueo Ciego</h4>
                        <p class="text-xs text-blue-700 dark:text-blue-300 mt-1 leading-relaxed">
                            Cuenta el dinero en efectivo que tienes físicamente en caja y digítalo a continuación. El sistema validará el cuadre al confirmar.
                        </p>
                    </div>
                </div>

                <!-- Counting Input -->
                <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-sm p-6 border border-gray-100 dark:border-gray-700">
                     <label class="block text-xs font-bold uppercase text-gray-400 mb-2 text-center">Efectivo Total Contado</label>
                     <FormInputCurrency v-model="amount" placeholder="0" class="text-3xl font-black text-center text-blue-900 dark:text-blue-100 mb-4" :disabled="!canOpenCloseCash" />
                     
                      <div class="mt-4">
                        <label class="block text-xs font-bold uppercase text-gray-400 mb-1">Notas del Cierre</label>
                        <textarea v-model="notes" rows="2" class="w-full p-3 bg-gray-50 dark:bg-gray-700 border-none rounded-lg text-sm" placeholder="Observaciones sobre el conteo..." :disabled="!canOpenCloseCash"></textarea>
                    </div>
                </div>
            </div>

            <!-- Action Button -->
            <BaseButton 
                @click="handleSubmit" 
                :loading="isSubmitting"
                :disabled="isSubmitting || !canOpenCloseCash"
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

        <!-- PIN Challenge Modal -->
        <PinChallengeModal
            :isVisible="showPinModal"
            :action="pendingAction"
            @close="showPinModal = false"
            @success="handlePinSuccess"
        />

        <!-- FRD-017: Forced Close Audit Modal -->
        <ForcedCloseAuditModal
            :isVisible="showAuditModal"
            :pendingSessions="pendingForcedSessions"
            @confirm="handleAuditConfirm"
        />

        <!-- Post-Cierre Summary Modal (Arqueo Ciego Certificado por Backend) -->
        <div v-if="closedReport" class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
            <div class="bg-white dark:bg-slate-800 w-full max-w-sm rounded-3xl p-6 shadow-2xl space-y-4 animate-slide-up border border-slate-100 dark:border-slate-700">
                <div class="text-center">
                    <div class="size-14 rounded-2xl mx-auto flex items-center justify-center mb-3"
                         :class="Math.abs(closedReport.difference) < 50 ? 'bg-emerald-100 text-emerald-600 dark:bg-emerald-900/30' : (closedReport.difference > 0 ? 'bg-blue-100 text-blue-600 dark:bg-blue-900/30' : 'bg-red-100 text-red-600 dark:bg-red-900/30')">
                        <CheckCircle v-if="Math.abs(closedReport.difference) < 50" :size="32" />
                        <AlertTriangle v-else :size="32" />
                    </div>
                    <h3 class="text-lg font-bold text-gray-900 dark:text-white">Cierre Certificado</h3>
                    <p class="text-xs text-gray-500 dark:text-gray-400">Resultado oficial calculado por el servidor</p>
                </div>

                <div class="bg-slate-50 dark:bg-slate-900/50 rounded-2xl p-4 space-y-3 text-sm">
                    <div class="flex justify-between items-center">
                        <span class="text-gray-500 dark:text-gray-400">Contado (Declarado):</span>
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

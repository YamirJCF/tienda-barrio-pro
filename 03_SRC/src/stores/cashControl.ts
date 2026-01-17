import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { supabase } from '../lib/supabase';
import { useAuthStore } from './auth';

export interface CashControlEvent {
    id: string;
    storeId: string;
    eventType: 'open' | 'close';
    authorizedById: string | null;
    authorizedByType: 'admin' | 'employee';
    authorizedByName: string;
    amountDeclared: number;
    amountExpected: number | null;
    difference: number | null;
    pinVerified: boolean;
    createdAt: string;
}

interface ValidatePinResult {
    success: boolean;
    error_code?: 'PIN_LOCKED' | 'PIN_NOT_CONFIGURED' | 'INVALID_PIN' | 'STORE_NOT_FOUND';
    attempts_remaining?: number;
    locked_until?: string;
    message?: string;
}

interface SetupPinResult {
    success: boolean;
    error?: string;
    message?: string;
}

interface RegisterEventResult {
    success: boolean;
    error?: string;
    event_id?: string;
    amount_expected?: number;
    difference?: number;
}

export const useCashControlStore = defineStore('cashControl', () => {
    const authStore = useAuthStore();

    // State
    const isOpen = ref(false);
    const currentEvent = ref<CashControlEvent | null>(null);
    const pinAttempts = ref(0);
    const lockedUntil = ref<Date | null>(null);
    const loading = ref(false);
    const hasPinConfigured = ref(false);
    const expectedCash = ref<number>(0);

    // Computed
    const isLocked = computed(() =>
        lockedUntil.value !== null && lockedUntil.value > new Date()
    );

    const lockRemainingSeconds = computed(() => {
        if (!lockedUntil.value) return 0;
        return Math.max(0, Math.ceil((lockedUntil.value.getTime() - Date.now()) / 1000));
    });

    // Actions
    const checkPinConfigured = async (): Promise<boolean> => {
        const storeId = authStore.currentUser?.storeId;
        if (!storeId) return false;

        try {
            const { data, error } = await supabase
                .from('stores')
                .select('owner_pin_hash')
                .eq('id', storeId)
                .single();

            if (error) throw error;
            hasPinConfigured.value = data?.owner_pin_hash !== null;
            return hasPinConfigured.value;
        } catch (err) {
            console.error('Error checking PIN status:', err);
            return false;
        }
    };

    const validatePin = async (pin: string): Promise<{ success: boolean; error?: string; attemptsRemaining?: number }> => {
        const storeId = authStore.currentUser?.storeId;
        if (!storeId) {
            return { success: false, error: 'Sesión no válida' };
        }

        try {
            loading.value = true;

            const { data, error } = await supabase
                .rpc('validar_pin_admin', { p_store_id: storeId, p_pin: pin });

            if (error) throw error;

            const result = data as ValidatePinResult;

            if (result.success) {
                pinAttempts.value = 0;
                lockedUntil.value = null;
                return { success: true };
            }

            // Handle specific error codes
            if (result.error_code === 'PIN_LOCKED') {
                lockedUntil.value = result.locked_until ? new Date(result.locked_until) : null;
                return { success: false, error: 'Cuenta bloqueada temporalmente' };
            }

            if (result.error_code === 'PIN_NOT_CONFIGURED') {
                return { success: false, error: 'Debes configurar un PIN primero' };
            }

            pinAttempts.value = 5 - (result.attempts_remaining ?? 0);
            return {
                success: false,
                error: result.message ?? 'PIN incorrecto',
                attemptsRemaining: result.attempts_remaining
            };
        } catch (err) {
            // Network errors don't count as attempts
            console.error('Error validating PIN:', err);
            return { success: false, error: 'Error de conexión. Intenta de nuevo.' };
        } finally {
            loading.value = false;
        }
    };

    const setupPin = async (newPin: string, currentPin?: string): Promise<{ success: boolean; error?: string }> => {
        const storeId = authStore.currentUser?.storeId;
        if (!storeId) {
            return { success: false, error: 'Sesión no válida' };
        }

        try {
            loading.value = true;

            const { data, error } = await supabase
                .rpc('establecer_pin_admin', {
                    p_store_id: storeId,
                    p_new_pin: newPin,
                    p_current_pin: currentPin ?? null
                });

            if (error) throw error;

            const result = data as SetupPinResult;

            if (result.success) {
                hasPinConfigured.value = true;
            }

            return result;
        } catch (err) {
            console.error('Error setting up PIN:', err);
            return { success: false, error: 'Error de conexión' };
        } finally {
            loading.value = false;
        }
    };

    const openCash = async (amount: number, pin: string, authorizedByName: string): Promise<{ success: boolean; error?: string }> => {
        const storeId = authStore.currentUser?.storeId;
        if (!storeId) {
            return { success: false, error: 'Sesión no válida' };
        }

        // First validate PIN
        const pinResult = await validatePin(pin);
        if (!pinResult.success) {
            return pinResult;
        }

        try {
            loading.value = true;

            const { data, error } = await supabase
                .rpc('registrar_evento_caja', {
                    p_store_id: storeId,
                    p_event_type: 'open',
                    p_amount_declared: amount,
                    p_authorized_by_name: authorizedByName,
                    p_authorized_by_type: authStore.isAdmin ? 'admin' : 'employee',
                    p_authorized_by_id: authStore.currentUser?.employeeId ?? null
                });

            if (error) throw error;

            const result = data as RegisterEventResult;

            if (result.success) {
                isOpen.value = true;
                currentEvent.value = {
                    id: result.event_id!,
                    storeId,
                    eventType: 'open',
                    authorizedById: authStore.currentUser?.employeeId?.toString() ?? null,
                    authorizedByType: authStore.isAdmin ? 'admin' : 'employee',
                    authorizedByName,
                    amountDeclared: amount,
                    amountExpected: null,
                    difference: null,
                    pinVerified: true,
                    createdAt: new Date().toISOString()
                };
            }

            return result;
        } catch (err) {
            console.error('Error opening cash:', err);
            return { success: false, error: 'Error de conexión' };
        } finally {
            loading.value = false;
        }
    };

    const closeCash = async (amountDeclared: number, pin: string, authorizedByName: string): Promise<{ success: boolean; error?: string; difference?: number }> => {
        const storeId = authStore.currentUser?.storeId;
        if (!storeId) {
            return { success: false, error: 'Sesión no válida' };
        }

        // First validate PIN
        const pinResult = await validatePin(pin);
        if (!pinResult.success) {
            return pinResult;
        }

        try {
            loading.value = true;

            const { data, error } = await supabase
                .rpc('registrar_evento_caja', {
                    p_store_id: storeId,
                    p_event_type: 'close',
                    p_amount_declared: amountDeclared,
                    p_authorized_by_name: authorizedByName,
                    p_authorized_by_type: authStore.isAdmin ? 'admin' : 'employee',
                    p_authorized_by_id: authStore.currentUser?.employeeId ?? null
                });

            if (error) throw error;

            const result = data as RegisterEventResult;

            if (result.success) {
                isOpen.value = false;
                currentEvent.value = {
                    id: result.event_id!,
                    storeId,
                    eventType: 'close',
                    authorizedById: authStore.currentUser?.employeeId?.toString() ?? null,
                    authorizedByType: authStore.isAdmin ? 'admin' : 'employee',
                    authorizedByName,
                    amountDeclared,
                    amountExpected: result.amount_expected ?? null,
                    difference: result.difference ?? null,
                    pinVerified: true,
                    createdAt: new Date().toISOString()
                };
            }

            return {
                success: result.success,
                error: result.error,
                difference: result.difference
            };
        } catch (err) {
            console.error('Error closing cash:', err);
            return { success: false, error: 'Error de conexión' };
        } finally {
            loading.value = false;
        }
    };

    const checkCashStatus = async (): Promise<void> => {
        const storeId = authStore.currentUser?.storeId;
        if (!storeId) return;

        try {
            const { data, error } = await supabase
                .from('cash_control_events')
                .select('*')
                .eq('store_id', storeId)
                .eq('event_type', 'open')
                .gte('created_at', new Date().toISOString().split('T')[0])
                .order('created_at', { ascending: false })
                .limit(1);

            if (error) throw error;

            if (data && data.length > 0) {
                // Check if there's a closing event after
                const { data: closeData } = await supabase
                    .from('cash_control_events')
                    .select('id')
                    .eq('store_id', storeId)
                    .eq('event_type', 'close')
                    .gt('created_at', data[0].created_at)
                    .limit(1);

                isOpen.value = !closeData || closeData.length === 0;
            } else {
                isOpen.value = false;
            }
        } catch (err) {
            console.error('Error checking cash status:', err);
        }
    };

    const getExpectedCash = async (): Promise<number> => {
        const storeId = authStore.currentUser?.storeId;
        if (!storeId) return 0;

        try {
            const { data, error } = await supabase
                .rpc('get_cash_report', { p_store_id: storeId });

            if (error) throw error;
            expectedCash.value = data?.expected_cash ?? 0;
            return expectedCash.value;
        } catch (err) {
            console.error('Error getting expected cash:', err);
            return 0;
        }
    };

    return {
        // State
        isOpen,
        currentEvent,
        pinAttempts,
        lockedUntil,
        loading,
        hasPinConfigured,
        expectedCash,
        // Computed
        isLocked,
        lockRemainingSeconds,
        // Actions
        checkPinConfigured,
        validatePin,
        setupPin,
        openCash,
        closeCash,
        checkCashStatus,
        getExpectedCash
    };
});

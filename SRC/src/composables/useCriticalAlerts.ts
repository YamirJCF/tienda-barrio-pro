/**
 * SPEC-008: Composable para gestionar alertas críticas bloqueantes
 * Centraliza la lógica de mostrar alertas que requieren acción del usuario
 */
import { ref, readonly } from 'vue';

export interface CriticalAlert {
    id: string;
    type: 'error' | 'warning' | 'security' | 'info';
    title: string;
    message: string;
    primaryAction?: string;
    secondaryAction?: string;
    onPrimary?: () => void;
    onSecondary?: () => void;
}

// Estado global (singleton)
const currentAlert = ref<CriticalAlert | null>(null);
const isVisible = ref(false);

export function useCriticalAlerts() {
    /**
     * Muestra una alerta crítica bloqueante
     */
    const showAlert = (alert: Omit<CriticalAlert, 'id'>): string => {
        const id = `alert-${Date.now()}`;
        currentAlert.value = { ...alert, id };
        isVisible.value = true;
        return id;
    };

    /**
     * Cierra la alerta actual
     */
    const dismissAlert = () => {
        isVisible.value = false;
        setTimeout(() => {
            currentAlert.value = null;
        }, 300); // Wait for animation
    };

    /**
     * Ejecuta acción primaria y cierra
     */
    const handlePrimary = () => {
        if (currentAlert.value?.onPrimary) {
            currentAlert.value.onPrimary();
        }
        dismissAlert();
    };

    /**
     * Ejecuta acción secundaria y cierra
     */
    const handleSecondary = () => {
        if (currentAlert.value?.onSecondary) {
            currentAlert.value.onSecondary();
        }
        dismissAlert();
    };

    // --- Helpers para alertas comunes ---

    /**
     * Alerta de error de seguridad (PIN fallidos, etc.)
     */
    const showSecurityAlert = (title: string, message: string, onDismiss?: () => void) => {
        return showAlert({
            type: 'security',
            title,
            message,
            primaryAction: 'Entendido',
            onPrimary: onDismiss,
        });
    };

    /**
     * Alerta de stock crítico
     */
    const showStockCriticalAlert = (productName: string, currentStock: number) => {
        return showAlert({
            type: 'warning',
            title: 'Stock Crítico',
            message: `El producto "${productName}" tiene solo ${currentStock} unidades. Considera reabastecer pronto.`,
            primaryAction: 'Ir a Inventario',
            secondaryAction: 'Después',
        });
    };

    /**
     * Alerta de error de sincronización
     */
    const showSyncErrorAlert = (onRetry?: () => void) => {
        return showAlert({
            type: 'error',
            title: 'Error de Sincronización',
            message: 'No se pudieron guardar los cambios. Verifica tu conexión a internet.',
            primaryAction: 'Reintentar',
            secondaryAction: 'Cancelar',
            onPrimary: onRetry,
        });
    };

    /**
     * Alerta de bloqueo por PIN
     */
    const showPinBlockedAlert = (minutes: number) => {
        return showAlert({
            type: 'security',
            title: 'Acceso Bloqueado',
            message: `Demasiados intentos fallidos. El sistema estará bloqueado por ${minutes} minutos.`,
            primaryAction: 'Entendido',
        });
    };

    return {
        // State (readonly)
        currentAlert: readonly(currentAlert),
        isVisible: readonly(isVisible),
        // Actions
        showAlert,
        dismissAlert,
        handlePrimary,
        handleSecondary,
        // Helper shortcuts
        showSecurityAlert,
        showStockCriticalAlert,
        showSyncErrorAlert,
        showPinBlockedAlert,
    };
}

export default useCriticalAlerts;

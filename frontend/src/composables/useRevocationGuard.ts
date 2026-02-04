import { onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { logger } from '../utils/logger';

/**
 * Composable para vigilar si el pase diario ha sido revocado.
 * Polling suave + check al recuperar foco.
 */
export function useRevocationGuard() {
    const authStore = useAuthStore();
    const router = useRouter();
    let intervalId: NodeJS.Timeout | null = null;
    const POLLING_INTERVAL = 15000; // 15 segundos

    const checkStatus = async () => {
        // Solo chequear si hay un usuario empleado logueado
        if (!authStore.isAuthenticated || !authStore.isEmployee) return;

        try {
            const status = await authStore.checkDailyApproval();

            if (status === 'rejected' || status === 'expired') {
                logger.warn('[RevocationGuard] Access revoked/expired! Logging out...');
                await authStore.logout();
                router.push('/login');
                // Opcional: Mostrar Toast o Alerta
            }
        } catch (error) {
            // Silenciar errores de red para no spamear
        }
    };

    const onVisibilityChange = () => {
        if (document.visibilityState === 'visible') {
            checkStatus();
        }
    };

    onMounted(() => {
        // Check inicial
        checkStatus();

        // Polling
        intervalId = setInterval(checkStatus, POLLING_INTERVAL);

        // On Focus
        document.addEventListener('visibilitychange', onVisibilityChange);
    });

    onUnmounted(() => {
        if (intervalId) clearInterval(intervalId);
        document.removeEventListener('visibilitychange', onVisibilityChange);
    });
}

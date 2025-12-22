/**
 * useNetworkStatus - Composable for detecting online/offline status
 * Provides reactive network status with event listeners
 */

import { ref, onMounted, onUnmounted, readonly } from 'vue';
import { useNotifications } from './useNotifications';

export const useNetworkStatus = () => {
    const isOnline = ref(typeof navigator !== 'undefined' ? navigator.onLine : true);
    const wasOffline = ref(false);
    const { showInfo, showWarning } = useNotifications();

    const updateOnlineStatus = () => {
        const newStatus = navigator.onLine;

        // Detect transitions
        if (!newStatus && isOnline.value) {
            // Going offline
            wasOffline.value = true;
            showWarning('Sin conexión - Los datos se guardan localmente', 'wifi_off');
        } else if (newStatus && !isOnline.value && wasOffline.value) {
            // Coming back online
            showInfo('Conexión restaurada', 'wifi');
            wasOffline.value = false;
        }

        isOnline.value = newStatus;
    };

    onMounted(() => {
        window.addEventListener('online', updateOnlineStatus);
        window.addEventListener('offline', updateOnlineStatus);
    });

    onUnmounted(() => {
        window.removeEventListener('online', updateOnlineStatus);
        window.removeEventListener('offline', updateOnlineStatus);
    });

    return {
        isOnline: readonly(isOnline),
        wasOffline: readonly(wasOffline),
    };
};

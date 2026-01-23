import { onMounted, onUnmounted, ref } from 'vue';
import { usePresenceStore } from '../stores/presence';
import { useAuthStore } from '../stores/auth';
import HeartbeatWorker from '../workers/heartbeat.worker?worker'; // Vite worker import

export function useHeartbeat() {
    const presenceStore = usePresenceStore();
    const authStore = useAuthStore();

    let worker: Worker | null = null;

    // Persistence for Pause State
    const STORAGE_KEY_PAUSED = 'heartbeat_is_paused';
    const STORAGE_KEY_PAUSE_START = 'heartbeat_pause_start';

    // Initialize state from storage
    const getStoredPause = () => localStorage.getItem(STORAGE_KEY_PAUSED) === 'true';
    const isPaused = ref(getStoredPause());

    // Pause Timeout Confirmation (30 min)
    const MAX_PAUSE_DURATION = 30 * 60 * 1000;

    const checkPauseTimeout = (): boolean => {
        if (!isPaused.value) return false;

        const startStr = localStorage.getItem(STORAGE_KEY_PAUSE_START);
        if (startStr) {
            const startTime = parseInt(startStr, 10);
            const now = Date.now();
            if (now - startTime > MAX_PAUSE_DURATION) {
                // Timeout exceeded
                return true;
            }
        }
        return false;
    };

    const sendPulse = () => {
        if (!authStore.isAuthenticated) return;

        // Check if pause exceeded limit
        if (isPaused.value && checkPauseTimeout()) {
            // If timeout exceeded, we STOP sending pulses.
            // This will cause the backend logic (or presence store) to mark as 'offline' eventually.
            console.log('[Heartbeat] Pause limit exceeded. Stopping pulse.');
            return;
        }

        const status = isPaused.value ? 'paused' : 'online';
        presenceStore.reportHeartbeat(status);

        // Also sync storage in case it changed in another tab (though component state is local)
        localStorage.setItem(STORAGE_KEY_PAUSED, isPaused.value.toString());
    };

    const startHeartbeat = () => {
        if (!worker) {
            worker = new HeartbeatWorker();
            worker.onmessage = (e) => {
                if (e.data.type === 'tick') {
                    sendPulse();
                }
            };
            worker.postMessage({ cmd: 'start' });
        }

        // Event listeners for OS-level activity
        document.addEventListener('visibilitychange', handleVisibilityChange);
        window.addEventListener('beforeunload', handleUnload);
    };

    const stopHeartbeat = () => {
        if (worker) {
            worker.postMessage({ cmd: 'stop' });
            worker.terminate();
            worker = null;
        }
        document.removeEventListener('visibilitychange', handleVisibilityChange);
        window.removeEventListener('beforeunload', handleUnload);
    };

    const handleVisibilityChange = () => {
        if (document.visibilityState === 'visible') {
            sendPulse(); // Immediate pulse on wake
        }
    };

    const handleUnload = () => {
        // Optional: Send beacon
    };

    const setPause = (value: boolean) => {
        isPaused.value = value;
        localStorage.setItem(STORAGE_KEY_PAUSED, value.toString());

        if (value) {
            localStorage.setItem(STORAGE_KEY_PAUSE_START, Date.now().toString());
        } else {
            localStorage.removeItem(STORAGE_KEY_PAUSE_START);
        }

        sendPulse(); // Immediate update
    };

    onMounted(() => {
        if (authStore.isAuthenticated) {
            startHeartbeat();
        }
    });

    onUnmounted(() => {
        stopHeartbeat();
    });

    return {
        isPaused,
        setPause
    };
}

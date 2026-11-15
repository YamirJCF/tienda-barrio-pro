import { getCurrentInstance, onMounted, onUnmounted, ref } from 'vue';
import { usePresenceStore } from '../stores/presence';
import { useAuthStore } from '../stores/auth';
import HeartbeatWorker from '../workers/heartbeat.worker?worker'; // Vite worker import

const STORAGE_KEY_PAUSED = 'heartbeat_is_paused';
const STORAGE_KEY_PAUSE_START = 'heartbeat_pause_start';
const MAX_PAUSE_DURATION = 30 * 60 * 1000;

let worker: Worker | null = null;
let activeMounts = 0;
let listenersAttached = false;

const getStoredPause = () =>
    typeof localStorage !== 'undefined' && localStorage.getItem(STORAGE_KEY_PAUSED) === 'true';

const isPaused = ref(getStoredPause());

export function useHeartbeat() {
    const presenceStore = usePresenceStore();
    const authStore = useAuthStore();

    const checkPauseTimeout = (): boolean => {
        if (!isPaused.value) return false;

        const startStr = localStorage.getItem(STORAGE_KEY_PAUSE_START);
        if (startStr) {
            const startTime = parseInt(startStr, 10);
            const now = Date.now();
            if (now - startTime > MAX_PAUSE_DURATION) {
                return true;
            }
        }
        return false;
    };

    const sendPulse = () => {
        if (!authStore.isAuthenticated) return;

        if (isPaused.value && checkPauseTimeout()) {
            return;
        }

        const status = isPaused.value ? 'paused' : 'online';
        presenceStore.reportHeartbeat(status);

        localStorage.setItem(STORAGE_KEY_PAUSED, isPaused.value.toString());
    };

    const handleVisibilityChange = () => {
        if (document.visibilityState === 'visible') {
            sendPulse();
        }
    };

    const handleUnload = () => {
        // Optional: Send beacon
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

        if (!listenersAttached) {
            document.addEventListener('visibilitychange', handleVisibilityChange);
            window.addEventListener('beforeunload', handleUnload);
            listenersAttached = true;
        }
    };

    const stopHeartbeat = () => {
        if (worker) {
            worker.postMessage({ cmd: 'stop' });
            worker.terminate();
            worker = null;
        }
        if (listenersAttached) {
            document.removeEventListener('visibilitychange', handleVisibilityChange);
            window.removeEventListener('beforeunload', handleUnload);
            listenersAttached = false;
        }
    };

    const setPause = (value: boolean) => {
        isPaused.value = value;
        localStorage.setItem(STORAGE_KEY_PAUSED, value.toString());

        if (value) {
            localStorage.setItem(STORAGE_KEY_PAUSE_START, Date.now().toString());
        } else {
            localStorage.removeItem(STORAGE_KEY_PAUSE_START);
        }

        sendPulse();
    };

    if (getCurrentInstance()) {
        onMounted(() => {
            activeMounts++;
            if (authStore.isAuthenticated && authStore.currentUser?.storeId) {
                presenceStore.initPresence(authStore.currentUser.storeId);
                startHeartbeat();
            }
        });

        onUnmounted(() => {
            activeMounts = Math.max(0, activeMounts - 1);
            if (activeMounts === 0) {
                stopHeartbeat();
            }
        });
    }

    return {
        isPaused,
        setPause
    };
}

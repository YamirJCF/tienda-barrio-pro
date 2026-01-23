import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { useAuthStore } from './auth';

export type PresenceStatus = 'online' | 'paused' | 'offline' | 'ghost';

export interface EmployeePresence {
    employeeId: number;
    name: string;
    storeId: string;
    lastSeen: string; // ISO String
    status: PresenceStatus;
    isRegisterOpen: boolean;
    deviceInfo?: string;
    currentIp?: string;
}

export const usePresenceStore = defineStore('presence', () => {
    const activeSessions = ref<Map<number, EmployeePresence>>(new Map());
    const authStore = useAuthStore();

    // Thresholds (ms)
    const THRESHOLD_OFFLINE = 5 * 60 * 1000; // 5 min sin señal -> Offline
    const THRESHOLD_GHOST = 10 * 60 * 1000;  // 10 min sin señal + caja abierta -> Ghost

    // Actions
    const reportHeartbeat = (status: 'online' | 'paused' = 'online') => {
        if (!authStore.isEmployee || !authStore.currentUser?.employeeId) return;

        const empId = authStore.currentUser.employeeId;

        // Update local state (simulating server Update)
        const session: EmployeePresence = {
            employeeId: empId,
            name: authStore.currentUser.name,
            storeId: authStore.currentUser.storeId,
            lastSeen: new Date().toISOString(),
            status: status,
            isRegisterOpen: true, // TODO: Link to real register status
        };

        // In a real backend, this would be a Supabase RPC call
        // For now, we mock it in local state (which syncs if using realtime broadcast)
        activeSessions.value.set(empId, session);
    };

    const getPresence = (employeeId: number): EmployeePresence | undefined => {
        return activeSessions.value.get(employeeId);
    };

    // Computeds for Admin Dashboard
    const getEmployeeStatus = (employeeId: number): PresenceStatus => {
        const session = activeSessions.value.get(employeeId);
        if (!session) return 'offline';

        const now = new Date().getTime();
        const lastSeen = new Date(session.lastSeen).getTime();
        const diff = now - lastSeen;

        if (session.status === 'paused') return 'paused';

        if (diff > THRESHOLD_GHOST && session.isRegisterOpen) {
            return 'ghost'; // ALERTA
        }

        if (diff > THRESHOLD_OFFLINE) {
            return 'offline'; // Neutral
        }

        return 'online';
    };

    return {
        activeSessions,
        reportHeartbeat,
        getPresence,
        getEmployeeStatus
    };
});

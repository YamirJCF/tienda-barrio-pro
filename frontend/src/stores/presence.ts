import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { useAuthStore } from './auth';
import { supabase } from '../lib/supabase';

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

    // Realtime Channel
    let channel: any = null;

    // Thresholds (ms)
    const THRESHOLD_OFFLINE = 5 * 60 * 1000; // 5 min sin señal -> Offline
    const THRESHOLD_GHOST = 10 * 60 * 1000;  // 10 min sin señal + caja abierta -> Ghost

    // Actions
    const initPresence = (storeId: string) => {
        if (channel) return; // Ya conectado

        const roomName = `room:store_${storeId}`;

        channel = supabase.channel(roomName, {
            config: {
                presence: {
                    key: authStore.currentUser?.employeeId?.toString() || 'unknown',
                },
            },
        });

        channel
            .on('presence', { event: 'sync' }, () => {
                const newState = channel.presenceState();

                // Reconstruir mapa local desde el estado del servidor (Source of Truth)
                const newMap = new Map<number, EmployeePresence>();

                for (const key in newState) {
                    const presences = newState[key];
                    // Tomamos el más reciente si hubiera duplicados por refresh
                    const latest = presences[0] as EmployeePresence;
                    if (latest && latest.employeeId) {
                        newMap.set(Number(latest.employeeId), latest);
                    }
                }

                activeSessions.value = newMap;
            })
            .subscribe(async (status: string) => {
                if (status === 'SUBSCRIBED') {
                    // Enviar estado inicial
                    await reportHeartbeat('online');
                }
            });
    };

    const cleanupPresence = () => {
        if (channel) {
            supabase.removeChannel(channel);
            channel = null;
        }
        activeSessions.value.clear();
    };

    const reportHeartbeat = async (status: 'online' | 'paused' = 'online') => {
        if (!authStore.isEmployee || !authStore.currentUser?.employeeId || !channel) return;

        const session: EmployeePresence = {
            employeeId: Number(authStore.currentUser.employeeId),
            name: authStore.currentUser.name,
            storeId: authStore.currentUser.storeId,
            lastSeen: new Date().toISOString(),
            status: status,
            isRegisterOpen: true, // Idealmente esto vendría del cashRegisterStore
        };

        await channel.track(session);
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
        initPresence,
        cleanupPresence,
        reportHeartbeat,
        getPresence,
        getEmployeeStatus
    };
});

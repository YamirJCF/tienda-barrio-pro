import { defineStore } from 'pinia';
import { ref } from 'vue';
import { authRepository } from '../data/repositories/authRepository';
import { logger } from '../utils/logger';
import { useNotificationsStore } from './notificationsStore';
import { useAuthStore } from './auth';
import { supabase } from '../lib/supabase';
import type { RealtimeChannel } from '@supabase/supabase-js';

// Module-level variable: NOT a ref() to avoid unnecessary reactivity overhead
// OT-4: Supabase Realtime channel for daily_passes push notifications
let realtimeChannel: RealtimeChannel | null = null;

export interface DeviceRequest {
    id: string;
    employeeId: string;
    employeeName: string;
    deviceFingerprint: string;
    userAgent: string;
    status: 'pending' | 'approved' | 'rejected' | 'revoked';
    requestedAt: string;
}

export const useDevicesStore = defineStore('devices', () => {
    // State
    const pendingRequests = ref<DeviceRequest[]>([]);
    const connectedDevices = ref<DeviceRequest[]>([]);
    const isLoading = ref(false);
    // OT-4: Controls whether the blocking modal is minimized to the widget
    const isModalMinimized = ref(false);

    // Actions
    const fetchPendingRequests = async () => {
        const authStore = useAuthStore();
        if (!authStore.currentStore?.id) return;

        try {
            isLoading.value = true;
            const requests = await authRepository.getPendingAccessRequests(authStore.currentStore.id);
            pendingRequests.value = requests.map((r: any) => ({
                ...r,
                status: 'pending' // Ensure status is explicitly pending
            }));

            // Sync with Notification Center
            const notifStore = useNotificationsStore();
            pendingRequests.value.forEach(req => {
                const exists = notifStore.notifications.some(n => n.metadata?.requestId === req.id);
                if (!exists) {
                    const employeeName = req.employeeName || 'Empleado';
                    notifStore.addNotification({
                        type: 'security',
                        audience: 'admin',
                        title: 'Solicitud de Acceso',
                        message: `${employeeName} solicita acceso al sistema`,
                        icon: 'shield-check',
                        isRead: false,
                        actionable: true,
                        // Actions are now handled by the Widget UI, but we keep metadata for linking
                        metadata: { requestId: req.id, employeeName, status: 'pending', deviceInfo: req.userAgent }
                    });
                }
            });

        } catch (error) {
            logger.error('[DevicesStore] Error fetching pending requests:', error);
        } finally {
            isLoading.value = false;
        }
    };

    const fetchConnectedDevices = async () => {
        const authStore = useAuthStore();
        if (!authStore.currentStore?.id) return;

        try {
            isLoading.value = true;
            const devices = await authRepository.getAuthorizedDevices(authStore.currentStore.id);
            connectedDevices.value = devices as DeviceRequest[];
        } catch (error) {
            logger.error('[DevicesStore] Error fetching connected devices:', error);
        } finally {
            isLoading.value = false;
        }
    };

    const approveDevice = async (requestId: string) => {
        const authStore = useAuthStore();
        if (!authStore.currentUser?.id) return false;

        try {
            isLoading.value = true;
            await authRepository.updateAccessRequestStatus(
                requestId,
                'approved',
                authStore.currentUser.id
            );

            // Update local state
            const req = pendingRequests.value.find(r => r.id === requestId);
            if (req) {
                // Move from pending to connected
                pendingRequests.value = pendingRequests.value.filter(r => r.id !== requestId);
                connectedDevices.value.push({ ...req, status: 'approved' });

                // Refresh connected list to get full server data if needed
                // await fetchConnectedDevices(); 
            }

            // Update Notification to 'approved' state (persisted for history/clearing)
            const notifStore = useNotificationsStore();
            const notif = notifStore.notifications.find(n => n.metadata?.requestId === requestId);
            if (notif) {
                notifStore.updateNotification(notif.id, {
                    title: 'Acceso Aprobado',
                    message: `${notif.metadata?.employeeName} ahora tiene acceso`,
                    icon: 'check-circle',
                    actionable: false, // Actions moved to widget
                    metadata: { ...notif.metadata, status: 'approved' }
                });
            }

            logger.log('[DevicesStore] Device approved:', requestId);
            return true;
        } catch (error) {
            logger.error('[DevicesStore] Error approving device:', error);
            return false;
        } finally {
            isLoading.value = false;
        }
    };

    const revokeDevice = async (deviceId: string) => {
        const authStore = useAuthStore();
        if (!authStore.currentUser?.id) return false;

        try {
            isLoading.value = true;
            await authRepository.updateAccessRequestStatus(
                deviceId,
                'rejected', // 'rejected' status effectively revokes access in backend
                authStore.currentUser.id
            );

            // Update local state
            connectedDevices.value = connectedDevices.value.filter(d => d.id !== deviceId);

            // Remove Notification entirely
            const notifStore = useNotificationsStore();
            const notif = notifStore.notifications.find(n => n.metadata?.requestId === deviceId);
            if (notif) {
                notifStore.removeNotification(notif.id);
            }

            logger.log('[DevicesStore] Device revoked:', deviceId);
            return true;
        } catch (error) {
            logger.error('[DevicesStore] Error revoking device:', error);
            return false;
        } finally {
            isLoading.value = false;
        }
    };

    const rejectRequest = async (requestId: string) => {
        // Same logic as revoke, but for pending requests
        const result = await revokeDevice(requestId);
        if (result) {
            pendingRequests.value = pendingRequests.value.filter(r => r.id !== requestId);
        }
        return result;
    };

    // ================================================================
    // OT-4: Realtime Subscription
    // Listens to daily_passes changes pushed by the server (Zero Polling)
    // ================================================================
    const subscribeToDailyPasses = (storeId: string) => {
        // Guard: prevent duplicate channels
        if (realtimeChannel) {
            logger.log('[DevicesStore] Realtime already subscribed, skipping.');
            return;
        }

        logger.log('[DevicesStore] Subscribing to daily_passes Realtime channel...');

        realtimeChannel = supabase
            .channel(`admin_devices_${storeId}`)
            .on(
                'postgres_changes',
                {
                    event: '*',
                    schema: 'public',
                    table: 'daily_passes',
                    filter: `store_id=eq.${storeId}`,
                },
                async (payload) => {
                    const newRecord = payload.new as any;
                    const oldRecord = payload.old as any;

                    logger.log('[DevicesStore] Realtime event:', payload.eventType, newRecord?.status);

                    if (payload.eventType === 'INSERT' && newRecord?.status === 'pending') {
                        // New access request → refresh list and show modal
                        await fetchPendingRequests();
                        isModalMinimized.value = false;

                    } else if (payload.eventType === 'UPDATE') {
                        const newStatus = newRecord?.status;
                        const oldRetryCount = oldRecord?.retry_count ?? 0;
                        const newRetryCount = newRecord?.retry_count ?? 0;

                        if (newStatus === 'approved') {
                            // Pass approved → move to connected, hide modal if no more pending
                            pendingRequests.value = pendingRequests.value.filter(r => r.id !== newRecord.id);
                            await fetchConnectedDevices();
                            if (pendingRequests.value.length === 0) {
                                isModalMinimized.value = false; // reset for next time
                            }

                        } else if (newStatus === 'expired' || newStatus === 'rejected') {
                            // Server-driven expiry or rejection → clean up UI
                            pendingRequests.value = pendingRequests.value.filter(r => r.id !== newRecord.id);
                            connectedDevices.value = connectedDevices.value.filter(d => d.id !== newRecord.id);

                            // Remove linked notification from bell center
                            const notifStore = useNotificationsStore();
                            const notif = notifStore.notifications.find(n => n.metadata?.requestId === newRecord.id);
                            if (notif) notifStore.removeNotification(notif.id);

                            if (pendingRequests.value.length === 0) {
                                isModalMinimized.value = false; // reset for next time
                            }

                        } else if (newStatus === 'pending' && newRetryCount > oldRetryCount) {
                            // Employee sent a retry → refresh list and re-interrupt admin screen
                            await fetchPendingRequests();
                            isModalMinimized.value = false;
                        }
                    }
                }
            )
            .subscribe((status) => {
                if (status === 'SUBSCRIBED') {
                    logger.log('[DevicesStore] Realtime SUBSCRIBED to daily_passes ✅');
                } else if (status === 'CHANNEL_ERROR') {
                    logger.error('[DevicesStore] Realtime CHANNEL_ERROR — will retry automatically.');
                }
            });
    };

    const unsubscribeFromDailyPasses = async () => {
        if (!realtimeChannel) return;
        logger.log('[DevicesStore] Unsubscribing from daily_passes Realtime channel.');
        await supabase.removeChannel(realtimeChannel);
        realtimeChannel = null;
    };


    return {
        // State
        pendingRequests,
        connectedDevices,
        isLoading,
        isModalMinimized,
        // Actions
        fetchPendingRequests,
        fetchConnectedDevices,
        approveDevice,
        revokeDevice,
        rejectRequest,
        // OT-4: Realtime
        subscribeToDailyPasses,
        unsubscribeFromDailyPasses,
    };
});

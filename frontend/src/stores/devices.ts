import { defineStore } from 'pinia';
import { ref } from 'vue';
import { authRepository } from '../data/repositories/authRepository';
import { logger } from '../utils/logger';
import { useNotificationsStore } from './notificationsStore';
import { useAuthStore } from './auth';

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


    return {
        pendingRequests,
        connectedDevices,
        isLoading,
        fetchPendingRequests,
        fetchConnectedDevices,
        approveDevice,
        revokeDevice,
        rejectRequest
    };
});

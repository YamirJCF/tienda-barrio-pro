/**
 * useNotifications - Composable for toast notifications
 * Handles success, error, info, and warning messages
 */

import { ref, readonly } from 'vue';

export type NotificationType = 'success' | 'error' | 'info' | 'warning';

export interface Notification {
    id: number;
    type: NotificationType;
    message: string;
    icon?: string;
    duration: number;
}

const notifications = ref<Notification[]>([]);
let nextId = 1;

const show = (type: NotificationType, message: string, icon?: string, duration = 3000) => {
    const notification: Notification = {
        id: nextId++,
        type,
        message,
        icon,
        duration,
    };

    notifications.value.push(notification);

    // Auto dismiss
    if (duration > 0) {
        setTimeout(() => {
            dismiss(notification.id);
        }, duration);
    }

    return notification.id;
};

const dismiss = (id: number) => {
    const index = notifications.value.findIndex(n => n.id === id);
    if (index !== -1) {
        notifications.value.splice(index, 1);
    }
};

const dismissAll = () => {
    notifications.value = [];
};

export const useNotifications = () => {
    const showSuccess = (message: string, icon = 'check_circle') => {
        return show('success', message, icon);
    };

    const showError = (message: string, icon = 'error') => {
        return show('error', message, icon, 5000); // Longer for errors
    };

    const showInfo = (message: string, icon = 'info') => {
        return show('info', message, icon);
    };

    const showWarning = (message: string, icon = 'warning') => {
        return show('warning', message, icon, 4000);
    };

    // Sale-specific helpers
    const showSaleSuccess = (ticketNumber: string) => {
        return showSuccess(`¡Venta ${ticketNumber} guardada!`);
    };

    const showSaleOffline = (ticketNumber: string) => {
        return showWarning(`Venta ${ticketNumber} guardada localmente`, 'cloud_off');
    };

    return {
        notifications: readonly(notifications),
        showSuccess,
        showError,
        showInfo,
        showWarning,
        showSaleSuccess,
        showSaleOffline,
        dismiss,
        dismissAll,
    };
};

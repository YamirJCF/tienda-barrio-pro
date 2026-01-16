/**
 * Notifications Store - Sistema de Notificaciones Persistentes
 * FRD: 01_REQUIREMENTS/notifications.md v1.1
 */

import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

// Types
export type NotificationType = 'security' | 'inventory' | 'finance' | 'general';

export interface SystemNotification {
    id: string;
    type: NotificationType;
    icon: string;
    title: string;
    message: string;
    createdAt: string;
    isRead: boolean;
    actionable?: boolean;
    metadata?: {
        productId?: string;
        clientId?: string;
        saleId?: string;
        amount?: number;
    };
}

// Constants
const STORAGE_KEY = 'app_notifications';
const MAX_NOTIFICATIONS = 50;
const TTL_DAYS = 30;
const RATE_LIMIT_PER_MINUTE = 5;

// Rate limiting tracker
const rateLimitTracker: Record<NotificationType, number[]> = {
    security: [],
    inventory: [],
    finance: [],
    general: []
};

// Helpers
const generateUUID = (): string => {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
};

const isValidUUID = (str: string): boolean => {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    return uuidRegex.test(str);
};

const isValidNotification = (n: Partial<SystemNotification>): boolean => {
    if (!n.title || n.title.length > 100) return false;
    if (!n.message || n.message.length > 500) return false;
    if (!['security', 'inventory', 'finance', 'general'].includes(n.type!)) return false;
    if (n.metadata?.productId && !isValidUUID(n.metadata.productId)) return false;
    if (n.metadata?.clientId && !isValidUUID(n.metadata.clientId)) return false;
    return true;
};

const isRateLimited = (type: NotificationType): boolean => {
    const now = Date.now();
    const oneMinuteAgo = now - 60000;

    // Clean old entries
    rateLimitTracker[type] = rateLimitTracker[type].filter(t => t > oneMinuteAgo);

    return rateLimitTracker[type].length >= RATE_LIMIT_PER_MINUTE;
};

const loadFromStorage = (): SystemNotification[] => {
    try {
        const data = localStorage.getItem(STORAGE_KEY);
        if (!data) return [];

        const parsed = JSON.parse(data);
        if (!Array.isArray(parsed)) return [];

        const now = Date.now();
        const ttlMs = TTL_DAYS * 24 * 60 * 60 * 1000;

        // Filter valid and non-expired notifications
        return parsed.filter((n: SystemNotification) => {
            const createdTime = new Date(n.createdAt).getTime();
            const isExpired = now - createdTime > ttlMs;
            return !isExpired && isValidNotification(n);
        });
    } catch (e) {
        console.warn('[Notifications] Datos corruptos, reseteando...', e);
        localStorage.removeItem(STORAGE_KEY);
        return [];
    }
};

const saveToStorage = (notifications: SystemNotification[]): void => {
    try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(notifications));
    } catch (e) {
        // localStorage full - remove oldest notifications
        console.warn('[Notifications] localStorage lleno, limpiando...', e);
        const reduced = notifications.slice(-Math.floor(MAX_NOTIFICATIONS / 2));
        localStorage.setItem(STORAGE_KEY, JSON.stringify(reduced));
    }
};

// Store
export const useNotificationsStore = defineStore('notifications', () => {
    const notifications = ref<SystemNotification[]>(loadFromStorage());

    // Getters
    const unreadCount = computed(() =>
        notifications.value.filter(n => !n.isRead).length
    );

    const hasUnread = computed(() => unreadCount.value > 0);

    const sortedByDate = computed(() =>
        [...notifications.value].sort((a, b) =>
            new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
        )
    );

    // Actions
    const addNotification = (data: Omit<SystemNotification, 'id' | 'createdAt'>): SystemNotification | null => {
        // Validate
        if (!isValidNotification(data as Partial<SystemNotification>)) {
            console.warn('[Notifications] Notificación inválida:', data);
            return null;
        }

        // Rate limit check
        if (isRateLimited(data.type)) {
            console.warn('[Notifications] Rate limit excedido para tipo:', data.type);
            return null;
        }

        const notification: SystemNotification = {
            ...data,
            id: generateUUID(),
            createdAt: new Date().toISOString(),
        };

        // Add to rate tracker
        rateLimitTracker[data.type].push(Date.now());

        // Add notification
        notifications.value.push(notification);

        // Enforce limit
        if (notifications.value.length > MAX_NOTIFICATIONS) {
            notifications.value = notifications.value.slice(-MAX_NOTIFICATIONS);
        }

        saveToStorage(notifications.value);
        return notification;
    };

    const markAsRead = (id: string): void => {
        const notification = notifications.value.find(n => n.id === id);
        if (notification) {
            notification.isRead = true;
            saveToStorage(notifications.value);
        }
    };

    const markAllAsRead = (): void => {
        notifications.value.forEach(n => {
            n.isRead = true;
        });
        saveToStorage(notifications.value);
    };

    const removeNotification = (id: string): void => {
        const index = notifications.value.findIndex(n => n.id === id);
        if (index > -1) {
            notifications.value.splice(index, 1);
            saveToStorage(notifications.value);
        }
    };

    const clearAll = (): void => {
        notifications.value = [];
        saveToStorage(notifications.value);
    };

    return {
        notifications,
        unreadCount,
        hasUnread,
        sortedByDate,
        addNotification,
        markAsRead,
        markAllAsRead,
        removeNotification,
        clearAll,
    };
});

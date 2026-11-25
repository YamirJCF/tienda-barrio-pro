/**
 * Notifications Store - Sistema de Notificaciones Persistentes
 * FRD: 01_REQUIREMENTS/notifications.md v1.1
 */

import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { getSupabaseClient, isSupabaseConfigured } from '../data/supabaseClient';
import { logger } from '../utils/logger';

// Types
export type NotificationType = 'security' | 'inventory' | 'finance' | 'general';
export type NotificationAudience = 'all' | 'admin' | 'employee';
export type NotificationActionType = 'approve' | 'reject' | 'view';

export interface NotificationAction {
  label: string;
  action: NotificationActionType;
  primary?: boolean;
  payload?: any;
}

export interface SystemNotification {
  id: string;
  type: NotificationType;
  audience: NotificationAudience;
  icon: string;
  title: string;
  message: string;
  createdAt: string;
  isRead: boolean;
  actionable?: boolean;
  actions?: NotificationAction[];
  metadata?: {
    productId?: string;
    clientId?: string;
    saleId?: string;
    sessionId?: string;
    supplierId?: string;
    invoiceId?: string;
    amount?: number;
    requestId?: string;
    employeeName?: string;
    actorName?: string;
    deviceInfo?: string;
    status?: 'pending' | 'approved' | 'rejected';
    eventType?: string;
    fromDatabase?: boolean;
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
  general: [],
};

// Helpers
const generateUUID = (): string => {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
};

const isValidUUID = (str: string): boolean => {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(str);
};

// Validate ID: accepts UUID or numeric string (for backwards compatibility with inventory)
const isValidId = (str: string): boolean => {
  if (!str || str.trim() === '') return false;
  // Accept UUID format
  if (isValidUUID(str)) return true;
  // Accept numeric IDs (current inventory format)
  if (/^\d+$/.test(str)) return true;
  return false;
};

const isValidNotification = (n: Partial<SystemNotification>): boolean => {
  if (!n.title || n.title.length > 100) return false;
  if (!n.message || n.message.length > 500) return false;
  if (!['security', 'inventory', 'finance', 'general'].includes(n.type!)) return false;
  if (n.metadata?.productId && !isValidId(n.metadata.productId)) return false;
  if (n.metadata?.clientId && !isValidId(n.metadata.clientId)) return false;
  return true;
};

const isRateLimited = (type: NotificationType): boolean => {
  const now = Date.now();
  const oneMinuteAgo = now - 60000;

  // Clean old entries
  rateLimitTracker[type] = rateLimitTracker[type].filter((t) => t > oneMinuteAgo);

  return rateLimitTracker[type].length >= RATE_LIMIT_PER_MINUTE;
};

const getStorageKeyForStore = (storeId?: string | null): string =>
  storeId ? `${STORAGE_KEY}:${storeId}` : STORAGE_KEY;

const loadFromStorage = (storeId?: string | null): SystemNotification[] => {
  try {
    const data = localStorage.getItem(getStorageKeyForStore(storeId));
    if (!data) return [];

    const parsed = JSON.parse(data);
    if (!Array.isArray(parsed)) return [];

    const now = Date.now();
    const ttlMs = TTL_DAYS * 24 * 60 * 60 * 1000;
    const PASS_TTL_MS = 5 * 60 * 1000; // 5 minutes (OT-3)

    // Filter valid and non-expired notifications, then convert stale access requests
    return parsed
      .filter((n: SystemNotification) => {
        try {
          const createdTime = new Date(n.createdAt).getTime();
          const isExpired = now - createdTime > ttlMs;
          return !isExpired && isValidNotification(n);
        } catch {
          return false; // discard corrupted timestamps
        }
      })
      .map((n: SystemNotification) => {
        // OT-3: Convert pending access requests older than 5 minutes into
        // archived informational notifications (remove requestId so they
        // leave the Security Widget and appear in the regular bell history)
        if (
          n.metadata?.requestId &&
          n.metadata?.status === 'pending'
        ) {
          try {
            const createdTime = new Date(n.createdAt).getTime();
            if (now - createdTime > PASS_TTL_MS) {
              const { requestId: _removed, ...cleanMeta } = n.metadata as any;
              return {
                ...n,
                title: 'Pase Vencido',
                message: `${n.metadata.employeeName || 'Empleado'}: Solicitud expirada (5m)`,
                actionable: false,
                actions: [],
                metadata: { ...cleanMeta, status: 'expired' },
              } as SystemNotification;
            }
          } catch {
            // If date is corrupt, leave notification unchanged
          }
        }
        return n;
      });
  } catch (e) {
    console.warn('[Notifications] Datos corruptos, reseteando...', e);
    localStorage.removeItem(STORAGE_KEY);
    return [];
  }
};

const saveToStorage = (notifications: SystemNotification[], storeId?: string | null): void => {
  const key = getStorageKeyForStore(storeId);
  try {
    localStorage.setItem(key, JSON.stringify(notifications));
  } catch (e) {
    // localStorage full - remove oldest notifications
    console.warn('[Notifications] localStorage lleno, limpiando...', e);
    const reduced = notifications.slice(-Math.floor(MAX_NOTIFICATIONS / 2));
    localStorage.setItem(key, JSON.stringify(reduced));
  }
};

// Store
export const useNotificationsStore = defineStore('notifications', () => {
  const activeStoreId = ref<string | null>(null);
  const notifications = ref<SystemNotification[]>(loadFromStorage(null));
  const fetchError = ref<string | null>(null);

  // Getters
  const unreadCount = computed(() => notifications.value.filter((n) => !n.isRead).length);

  const hasUnread = computed(() => unreadCount.value > 0);

  const sortedByDate = computed(() =>
    [...notifications.value].sort((a, b) => {
      // Access request notifications always on top
      const aIsAccess = a.metadata?.requestId ? 1 : 0;
      const bIsAccess = b.metadata?.requestId ? 1 : 0;
      if (aIsAccess !== bIsAccess) return bIsAccess - aIsAccess;
      // Within same priority, sort by date (newest first)
      return new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime();
    }),
  );

  // Role-based filtered getters
  const getVisibleNotifications = (userType: 'admin' | 'employee') => {
    const sorted = sortedByDate.value;
    if (userType === 'admin') return sorted;
    return sorted.filter(n => (n.audience ?? 'all') !== 'admin');
  };

  const getVisibleUnreadCount = (userType: 'admin' | 'employee') => {
    if (userType === 'admin') return unreadCount.value;
    return notifications.value.filter(n => !n.isRead && (n.audience ?? 'all') !== 'admin').length;
  };

  // Actions
  const addNotification = (
    data: Omit<SystemNotification, 'id' | 'createdAt'>,
  ): SystemNotification | null => {
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
      audience: data.audience ?? 'all',
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

    saveToStorage(notifications.value, activeStoreId.value);
    return notification;
  };

  const isLoading = ref(false);

  const mapRowToNotification = (row: any): SystemNotification => {
    const rawMeta = (row.metadata && typeof row.metadata === 'object') ? row.metadata : {};
    const validTypes: NotificationType[] = ['security', 'inventory', 'finance', 'general'];
    const normalizedType: NotificationType = validTypes.includes(row.type) ? row.type : 'general';
    const normalizedAudience: NotificationAudience =
      row.audience === 'admin' ? 'admin' : row.audience === 'employee' ? 'employee' : 'all';

    return {
      id: row.id,
      type: normalizedType,
      audience: normalizedAudience,
      icon: normalizedType === 'security' ? 'ShieldAlert' : normalizedType === 'finance' ? 'payments' : normalizedType === 'inventory' ? 'Package' : 'Store',
      title: row.title,
      message: row.message,
      createdAt: row.created_at,
      isRead: Boolean(row.is_read),
      metadata: {
        ...rawMeta,
        productId: rawMeta.product_id || rawMeta.productId,
        clientId: rawMeta.client_id || rawMeta.clientId,
        saleId: rawMeta.sale_id || rawMeta.saleId,
        sessionId: rawMeta.session_id || rawMeta.sessionId,
        supplierId: rawMeta.supplier_id || rawMeta.supplierId,
        invoiceId: rawMeta.invoice_id || rawMeta.invoiceId,
        actorName: rawMeta.actor_name || rawMeta.actorName,
        eventType: rawMeta.event_type || rawMeta.eventType,
        fromDatabase: true,
      },
    };
  };

  const fetchNotifications = async (storeId: string): Promise<void> => {
    if (!storeId) return;

    // Aislamiento estricto por tienda: al cambiar storeId recarga memoria desde la partición aislada de esa tienda
    if (activeStoreId.value !== storeId) {
      activeStoreId.value = storeId;
      notifications.value = loadFromStorage(storeId);
    }

    if (!navigator.onLine || !isSupabaseConfigured()) return;

    fetchError.value = null;
    isLoading.value = true;
    try {
      const supabase = getSupabaseClient();
      if (!supabase) return;

      const { data, error } = await supabase
        .from('notifications')
        .select('*')
        .eq('store_id', storeId)
        .order('created_at', { ascending: false })
        .limit(MAX_NOTIFICATIONS);

      if (error) {
        logger.error('[Notifications] Error fetching notifications from Supabase:', error);
        fetchError.value = error.message || 'No se pudieron cargar las notificaciones del servidor.';
        throw error;
      }

      const dbItems = (data || []).map(mapRowToNotification);
      const dbIds = new Set(dbItems.map((item) => item.id));

      // Preservar avisos locales vigentes de ESTA tienda
      const localOnly = notifications.value.filter(
        (n) => !n.metadata?.fromDatabase && !dbIds.has(n.id)
      );

      notifications.value = [...dbItems, ...localOnly].slice(0, MAX_NOTIFICATIONS);
      saveToStorage(notifications.value, storeId);
    } catch (e: any) {
      if (!fetchError.value) {
        fetchError.value = e?.message || 'No se pudieron cargar las notificaciones del servidor.';
      }
      throw e;
    } finally {
      isLoading.value = false;
    }
  };

  const markAsRead = async (id: string): Promise<void> => {
    const notification = notifications.value.find((n) => n.id === id);
    if (notification) {
      notification.isRead = true;
      saveToStorage(notifications.value, activeStoreId.value);

      if (notification.metadata?.fromDatabase && navigator.onLine && isSupabaseConfigured()) {
        try {
          const supabase = getSupabaseClient();
          await supabase?.from('notifications').update({ is_read: true }).eq('id', id);
        } catch (e) {
          logger.error('[Notifications] Failed syncing markAsRead to DB:', e);
        }
      }
    }
  };

  const markAllAsRead = async (storeId?: string): Promise<void> => {
    const unreadDbIds = notifications.value
      .filter((n) => !n.isRead && n.metadata?.fromDatabase)
      .map((n) => n.id);

    notifications.value.forEach((n) => {
      n.isRead = true;
    });
    saveToStorage(notifications.value, storeId || activeStoreId.value);

    if (unreadDbIds.length > 0 && navigator.onLine && isSupabaseConfigured()) {
      try {
        const supabase = getSupabaseClient();
        if (supabase) {
          const query = supabase.from('notifications').update({ is_read: true }).in('id', unreadDbIds);
          await (storeId ? query.eq('store_id', storeId) : query);
        }
      } catch (e) {
        logger.error('[Notifications] Failed syncing markAllAsRead to DB:', e);
      }
    }
  };

  const removeNotification = async (id: string): Promise<void> => {
    const index = notifications.value.findIndex((n) => n.id === id);
    if (index === -1) return;

    const target = notifications.value[index];
    if (target.metadata?.fromDatabase && navigator.onLine && isSupabaseConfigured()) {
      const supabase = getSupabaseClient();
      if (supabase) {
        const { error } = await supabase.from('notifications').delete().eq('id', id);
        if (error) {
          logger.error('[Notifications] Failed deleting DB notification:', error);
          throw new Error(error.message || 'No se pudo eliminar la notificación');
        }
      }
    }

    notifications.value.splice(index, 1);
    saveToStorage(notifications.value, activeStoreId.value);
  };

  const updateNotification = (id: string, updates: Partial<Omit<SystemNotification, 'id' | 'createdAt'>>): void => {
    const notification = notifications.value.find((n) => n.id === id);
    if (notification) {
      Object.assign(notification, updates);
      saveToStorage(notifications.value, activeStoreId.value);
    }
  };

  const clearAll = (): void => {
    notifications.value = notifications.value.filter(n => !!n.metadata?.requestId);
    saveToStorage(notifications.value, activeStoreId.value);
  };

  return {
    notifications,
    activeStoreId,
    isLoading,
    fetchError,
    unreadCount,
    hasUnread,
    sortedByDate,
    getVisibleNotifications,
    getVisibleUnreadCount,
    fetchNotifications,
    addNotification,
    markAsRead,
    markAllAsRead,
    removeNotification,
    updateNotification,
    clearAll,
  };
});

<script setup lang="ts">
/**
 * NotificationCenterView - Centro de Notificaciones
 * FRD: 01_REQUIREMENTS/notifications.md v1.1
 */
import { computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useNotificationsStore, type SystemNotification } from '../stores/notificationsStore';
import { useAuthStore } from '../stores/auth';

import { formatRelativeTime } from '../composables/useRelativeTime';
import { useNotifications } from '../composables/useNotifications';
import NotificationSecurityWidget from '../components/NotificationSecurityWidget.vue';
import { 
  ArrowLeft, 
  ChevronLeft, 
  BellOff, 
  ShieldCheck, 
  Package, 
  Banknote, 
  Store, 
  X,
  AlertTriangle,
  RefreshCw
} from 'lucide-vue-next';

const router = useRouter();
const notificationsStore = useNotificationsStore();
const authStore = useAuthStore();
const { showError } = useNotifications();

const isAdmin = computed(() => authStore.isAdmin);
const userType = computed<'admin' | 'employee'>(() => authStore.isAdmin ? 'admin' : 'employee');
const activeStoreId = computed(() => authStore.currentStore?.id || authStore.currentUser?.storeId || '');

const reloadNotifications = async () => {
  if (!activeStoreId.value) return;
  try {
    await notificationsStore.fetchNotifications(activeStoreId.value);
  } catch (e: any) {
    showError(e?.message || 'No se pudieron sincronizar las notificaciones');
  }
};

onMounted(reloadNotifications);

const handleRemoveNotification = async (id: string) => {
  try {
    await notificationsStore.removeNotification(id);
  } catch (e: any) {
    showError(e?.message || 'No se pudo eliminar la notificación');
  }
};

// Computed
const notifications = computed(() => {
  // Filter by role audience, then exclude access requests shown in SecurityWidget
  return notificationsStore.getVisibleNotifications(userType.value)
    .filter(n => !n.metadata?.requestId);
});

const hasUnreadNotifications = computed(() => notificationsStore.getVisibleUnreadCount(userType.value) > 0);
const isEmpty = computed(() => notifications.value.length === 0);

// Methods
const goBack = () => {
  if (typeof window !== 'undefined' && window.history.length > 1) {
    router.back();
    return;
  }
  router.push('/');
};

const markAllAsRead = () => {
  notificationsStore.markAllAsRead(activeStoreId.value || undefined);
};

const isForcedSessionEvent = (notification: SystemNotification): boolean => {
  const eventType = String(notification.metadata?.eventType || '').toUpperCase();
  const title = (notification.title || '').toLowerCase();
  return (
    eventType.includes('FORCE') ||
    eventType.includes('24H') ||
    title.includes('forzad') ||
    title.includes('24h')
  );
};

const resolveNotificationTarget = (notification: SystemNotification): string | null => {
  const meta = notification.metadata;
  if (!meta) return null;

  if (meta.productId && authStore.canManageInventory) {
    return `/inventory?productId=${encodeURIComponent(String(meta.productId))}&tab=batches`;
  }
  if (meta.clientId && authStore.canFiar) {
    return `/clients/${encodeURIComponent(String(meta.clientId))}`;
  }
  if (meta.saleId && authStore.isAdmin) {
    return `/reports?tab=history&domain=sales&saleId=${encodeURIComponent(String(meta.saleId))}`;
  }
  if (meta.sessionId) {
    if (isForcedSessionEvent(notification) || !authStore.isAdmin) {
      return '/cash-control';
    }
    return `/reports?tab=history&domain=cash&sessionId=${encodeURIComponent(String(meta.sessionId))}`;
  }
  if ((meta.supplierId || meta.invoiceId) && authStore.isAdmin) {
    return '/suppliers?tab=payables';
  }
  return null;
};

const handleNotificationClick = (notification: SystemNotification) => {
  if (!notification.isRead) {
    notificationsStore.markAsRead(notification.id);
  }
  const target = resolveNotificationTarget(notification);
  if (target) {
    router.push(target);
  }
};



const getIconConfig = (notification: SystemNotification) => {
  const bgColorMap: Record<string, string> = {
    security: 'bg-red-100 dark:bg-red-900/40',
    inventory: 'bg-orange-100 dark:bg-orange-900/40',
    finance: 'bg-green-100 dark:bg-green-900/40',
    general: 'bg-blue-100 dark:bg-blue-900/40',
  };
  
  const textColorMap: Record<string, string> = {
    security: 'text-red-600 dark:text-red-400',
    inventory: 'text-orange-600 dark:text-orange-400',
    finance: 'text-green-600 dark:text-green-400',
    general: 'text-blue-600 dark:text-blue-400',
  };

  const IconComponent = (() => {
      switch(notification.type) {
        case 'security': 
          return ShieldCheck;
        case 'inventory': 
          return Package;
        case 'finance':
          return Banknote;
        case 'general':
        default:
          return Store;
      }
  })();

  // Use values based on type, defaulting to general if not found
  const bgColor = bgColorMap[notification.type] || bgColorMap.general;
  const textColor = textColorMap[notification.type] || textColorMap.general;
  
  return {
    component: IconComponent,
    bgColor,
    textColor
  };
};

const getRelativeTime = (createdAt: string) => {
  return formatRelativeTime(createdAt);
};
</script>

<template>
  <div
    class="bg-gray-50 dark:bg-background-dark text-slate-900 dark:text-white min-h-screen flex flex-col"
  >
    <!-- Header -->
    <header
      class="sticky top-0 z-30 flex items-center justify-between px-4 py-3 bg-white dark:bg-background-dark border-b border-slate-100 dark:border-slate-800 shadow-sm shrink-0"
    >
      <button
        @click="goBack"
        aria-label="Volver"
        class="flex items-center justify-center p-2 -ml-2 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors text-slate-800 dark:text-white"
      >
        <ChevronLeft :size="24" :stroke-width="1.5" />
      </button>
      <h1 class="text-lg font-bold text-center text-slate-900 dark:text-white flex-1 truncate px-2">
        Notificaciones
      </h1>
      <button
        v-if="hasUnreadNotifications"
        @click="markAllAsRead"
        class="text-primary text-sm font-bold p-2 -mr-2 rounded-lg active:bg-blue-50 dark:active:bg-blue-900/20 transition-colors shrink-0"
      >
        Marcar todo leído
      </button>
      <div v-else class="w-[90px]"></div>
    </header>

    <!-- Notification List Container -->
    <main class="flex-1 overflow-y-auto p-4 space-y-3 scroll-smooth">
      
      <!-- Security Widget (Admin Only) -->
      <NotificationSecurityWidget v-if="isAdmin" />

      <!-- Server Load Error Banner (Regla 3: Cero Fallos Silenciosos) -->
      <div
        v-if="notificationsStore.fetchError"
        data-test="notifications-error"
        class="bg-red-50 dark:bg-red-900/20 border border-red-300 dark:border-red-700 rounded-xl p-3 flex items-center justify-between gap-3"
      >
        <div class="flex items-center gap-2 text-xs text-red-700 dark:text-red-300 font-medium">
          <AlertTriangle :size="16" class="shrink-0" />
          <span>{{ notificationsStore.fetchError }}</span>
        </div>
        <button
          @click="reloadNotifications"
          class="px-2.5 py-1 rounded-lg bg-red-600 text-white text-xs font-bold flex items-center gap-1 shrink-0"
        >
          <RefreshCw :size="12" /> Reintentar
        </button>
      </div>

      <!-- Empty State -->
      <div
        v-if="isEmpty"
        class="flex flex-col items-center justify-center h-full text-center py-10 opacity-60"
      >
        <BellOff :size="64" :stroke-width="1" class="text-slate-300 mb-4" />
        <p class="text-lg font-bold text-slate-600 dark:text-slate-400">Estás al día</p>
        <p class="text-sm text-slate-400">No tienes nuevas notificaciones</p>
      </div>

      <!-- Notification Items -->
      <template v-else>
        <article
          v-for="notification in notifications"
          :key="notification.id"
          data-testid="notification-card"
          @click="handleNotificationClick(notification)"
          class="group relative flex flex-col gap-3 p-4 rounded-xl shadow-sm overflow-hidden transition-all duration-300 border"
          :class="[
            notification.isRead
              ? 'bg-white dark:bg-surface-dark border-slate-200 dark:border-slate-700 opacity-90 hover:opacity-100'
              : 'bg-blue-50/70 dark:bg-primary/10 border-primary/30 dark:border-primary/40',
            resolveNotificationTarget(notification) ? 'cursor-pointer active:scale-[0.99]' : '',
          ]"
        >
          <div class="flex gap-4 items-start">
            <!-- Icon -->
            <div class="shrink-0 relative z-10">
              <div
                class="flex items-center justify-center size-12 rounded-full shadow-sm"
                :class="[
                  getIconConfig(notification).bgColor,
                  getIconConfig(notification).textColor,
                ]"
              >
                <component :is="getIconConfig(notification).component" :size="24" :stroke-width="1.5" />
              </div>
            </div>

            <!-- Content -->
            <div class="flex-1 min-w-0 relative z-10">
              <div class="flex justify-between items-start mb-1 gap-2">
                <h3
                  class="text-base leading-tight text-slate-900 dark:text-white"
                  :class="notification.isRead ? 'font-semibold' : 'font-bold'"
                >
                  {{ notification.title }}
                </h3>
                <div class="flex items-center gap-2">
                  <span
                    class="text-xs font-medium whitespace-nowrap pt-0.5"
                    :class="
                      notification.isRead ? 'text-slate-400' : 'text-slate-500 dark:text-slate-400'
                    "
                  >
                    {{ getRelativeTime(notification.createdAt) }}
                  </span>
                  <!-- T-013: Botón eliminar notificación (hidden for access requests) -->
                  <button
                    v-if="!notification.metadata?.requestId && (!notification.metadata?.fromDatabase || isAdmin)"
                    @click.stop="handleRemoveNotification(notification.id)"
                    class="p-1 rounded-full text-slate-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
                    title="Eliminar"
                  >
                    <X :size="16" />
                  </button>
                </div>
              </div>
              <p
                class="text-sm leading-relaxed"
                :class="[
                  notification.isRead
                    ? 'text-slate-500 dark:text-slate-400 truncate'
                    : 'text-slate-600 dark:text-slate-300',
                  notification.actionable ? 'mb-3' : '',
                ]"
              >
                {{ notification.message }}
              </p>
            </div>
          </div>

          <!-- Unread Indicator Dot -->
          <div
            v-if="!notification.isRead && !notification.actionable"
            class="absolute top-4 right-4 size-2 rounded-full bg-primary/40 dark:bg-primary/60"
          ></div>
        </article>
      </template>

      <!-- Bottom Spacer for Safe Area -->
      <div class="h-6"></div>
    </main>
  </div>
</template>

<style scoped>
.size-12 {
  width: 3rem;
  height: 3rem;
}

.size-2 {
  width: 0.5rem;
  height: 0.5rem;
}
</style>

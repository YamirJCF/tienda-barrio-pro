<script setup lang="ts">
/**
 * NotificationCenterView - Centro de Notificaciones
 * FRD: 01_REQUIREMENTS/notifications.md v1.1
 */
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useNotificationsStore, type SystemNotification } from '../stores/notificationsStore';
import { formatRelativeTime } from '../composables/useRelativeTime';

const router = useRouter();
const notificationsStore = useNotificationsStore();

// Computed
const notifications = computed(() => notificationsStore.sortedByDate);
const hasUnreadNotifications = computed(() => notificationsStore.hasUnread);
const isEmpty = computed(() => notifications.value.length === 0);

// Methods
const goBack = () => {
    router.back();
};

const markAllAsRead = () => {
    notificationsStore.markAllAsRead();
};

const handleApprove = (notificationId: string) => {
    console.log('Approved:', notificationId);
    notificationsStore.removeNotification(notificationId);
};

const handleReject = (notificationId: string) => {
    console.log('Rejected:', notificationId);
    notificationsStore.removeNotification(notificationId);
};

const getIconConfig = (notification: SystemNotification) => {
    // Use icon from notification if available, otherwise default by type
    const iconMap: Record<string, { icon: string; bgColor: string; textColor: string }> = {
        security: { icon: notification.icon || 'shield', bgColor: 'bg-red-100 dark:bg-red-900/40', textColor: 'text-red-600 dark:text-red-400' },
        inventory: { icon: notification.icon || 'inventory_2', bgColor: 'bg-orange-100 dark:bg-orange-900/40', textColor: 'text-orange-600 dark:text-orange-400' },
        finance: { icon: notification.icon || 'payments', bgColor: 'bg-green-100 dark:bg-green-900/40', textColor: 'text-green-600 dark:text-green-400' },
        general: { icon: notification.icon || 'store', bgColor: 'bg-blue-100 dark:bg-blue-900/40', textColor: 'text-blue-600 dark:text-blue-400' },
    };
    return iconMap[notification.type] || iconMap.general;
};

const getRelativeTime = (createdAt: string) => {
    return formatRelativeTime(createdAt);
};
</script>

<template>
    <div class="bg-gray-50 dark:bg-background-dark text-slate-900 dark:text-white min-h-screen flex flex-col">
        <!-- Header -->
        <header
            class="sticky top-0 z-30 flex items-center justify-between px-4 py-3 bg-white dark:bg-background-dark border-b border-slate-100 dark:border-slate-800 shadow-sm shrink-0">
            <button @click="goBack" aria-label="Volver"
                class="flex items-center justify-center p-2 -ml-2 rounded-full hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors text-slate-800 dark:text-white">
                <span class="material-symbols-outlined">arrow_back_ios_new</span>
            </button>
            <h1 class="text-lg font-bold text-center text-slate-900 dark:text-white flex-1 truncate px-2">Notificaciones
            </h1>
            <button v-if="hasUnreadNotifications" @click="markAllAsRead"
                class="text-primary text-sm font-bold p-2 -mr-2 rounded-lg active:bg-blue-50 dark:active:bg-blue-900/20 transition-colors shrink-0">
                Marcar todo leído
            </button>
            <div v-else class="w-[90px]"></div>
        </header>

        <!-- Notification List Container -->
        <main class="flex-1 overflow-y-auto p-4 space-y-3 scroll-smooth">

            <!-- Empty State -->
            <div v-if="isEmpty" class="flex flex-col items-center justify-center h-full text-center py-10 opacity-60">
                <span class="material-symbols-outlined text-6xl text-slate-300 mb-4">notifications_off</span>
                <p class="text-lg font-bold text-slate-600 dark:text-slate-400">Estás al día</p>
                <p class="text-sm text-slate-400">No tienes nuevas notificaciones</p>
            </div>

            <!-- Notification Items -->
            <template v-else>
                <article v-for="notification in notifications" :key="notification.id"
                    class="group relative flex flex-col gap-3 p-4 rounded-xl shadow-sm ring-1 ring-black/5 dark:ring-white/5 overflow-hidden transition-all duration-300"
                    :class="[
                        notification.isRead
                            ? 'bg-white dark:bg-[#1e293b] border-l-4 border-transparent opacity-90 hover:opacity-100 cursor-pointer active:scale-[0.99]'
                            : 'bg-blue-50 dark:bg-primary/10 border-l-4 border-primary'
                    ]">
                    <div class="flex gap-4 items-start">
                        <!-- Icon -->
                        <div class="shrink-0 relative z-10">
                            <div class="flex items-center justify-center size-12 rounded-full shadow-sm"
                                :class="[getIconConfig(notification).bgColor, getIconConfig(notification).textColor]">
                                <span class="material-symbols-outlined">{{ getIconConfig(notification).icon }}</span>
                            </div>
                        </div>

                        <!-- Content -->
                        <div class="flex-1 min-w-0 relative z-10">
                            <div class="flex justify-between items-start mb-1 gap-2">
                                <h3 class="text-base leading-tight text-slate-900 dark:text-white"
                                    :class="notification.isRead ? 'font-semibold' : 'font-bold'">
                                    {{ notification.title }}
                                </h3>
                                <span class="text-xs font-medium whitespace-nowrap pt-0.5"
                                    :class="notification.isRead ? 'text-slate-400' : 'text-slate-500 dark:text-slate-400'">
                                    {{ getRelativeTime(notification.createdAt) }}
                                </span>
                            </div>
                            <p class="text-sm leading-relaxed" :class="[
                                notification.isRead ? 'text-slate-500 dark:text-slate-400 truncate' : 'text-slate-600 dark:text-slate-300',
                                notification.actionable ? 'mb-3' : ''
                            ]">
                                {{ notification.message }}
                            </p>

                            <!-- Integrated Actions (for actionable notifications) -->
                            <div v-if="notification.actionable && !notification.isRead" class="flex gap-3">
                                <button @click="handleReject(notification.id)"
                                    class="flex-1 h-10 px-3 rounded-lg border border-slate-200 bg-white dark:bg-slate-800 dark:border-slate-700 text-slate-700 dark:text-slate-200 text-sm font-bold shadow-sm active:bg-slate-50 dark:active:bg-slate-700 transition-colors flex items-center justify-center">
                                    Rechazar
                                </button>
                                <button @click="handleApprove(notification.id)"
                                    class="flex-1 h-10 px-3 rounded-lg bg-primary text-white text-sm font-bold shadow-sm active:bg-blue-600 transition-colors flex items-center justify-center">
                                    Aprobar
                                </button>
                            </div>
                        </div>
                    </div>

                    <!-- Unread Indicator Dot -->
                    <div v-if="!notification.isRead && !notification.actionable"
                        class="absolute top-4 right-4 size-2 rounded-full bg-primary/40 dark:bg-primary/60"></div>
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

<script setup lang="ts">
import { useNotifications, type Notification } from '../composables/useNotifications';

const { notifications, dismiss } = useNotifications();

const getTypeClasses = (type: Notification['type']) => {
  const classes = {
    success: 'bg-emerald-500 text-white',
    error: 'bg-red-500 text-white',
    info: 'bg-blue-500 text-white',
    warning: 'bg-amber-500 text-black',
  };
  return classes[type];
};

const getIcon = (notification: Notification) => {
  if (notification.icon) return notification.icon;
  const icons = {
    success: 'check_circle',
    error: 'error',
    info: 'info',
    warning: 'warning',
  };
  return icons[notification.type];
};
</script>

<template>
  <Teleport to="body">
    <!-- T-012: Movido de bottom-20 a top-20 para no bloquear botones del POS -->
    <div
      class="fixed top-20 left-0 right-0 z-[100] flex flex-col items-center gap-2 pointer-events-none px-4"
    >
      <TransitionGroup name="toast">
        <div
          v-for="notification in notifications"
          :key="notification.id"
          class="pointer-events-auto flex items-center gap-3 px-4 py-3 rounded-xl shadow-lg max-w-sm w-full animate-slide-up"
          :class="getTypeClasses(notification.type)"
          @click="dismiss(notification.id)"
        >
          <!-- Icon -->
          <span class="material-symbols-outlined text-xl shrink-0">
            {{ getIcon(notification) }}
          </span>

          <!-- Message -->
          <p class="flex-1 text-sm font-medium">
            {{ notification.message }}
          </p>

          <!-- Close button -->
          <button
            class="shrink-0 opacity-70 hover:opacity-100 transition-opacity"
            @click.stop="dismiss(notification.id)"
          >
            <span class="material-symbols-outlined text-lg">close</span>
          </button>
        </div>
      </TransitionGroup>
    </div>
  </Teleport>
</template>

<style scoped>
/* Toast animations */
.toast-enter-active {
  animation: slideUp 0.3s ease-out;
}

.toast-leave-active {
  animation: slideDown 0.2s ease-in;
}

.toast-move {
  transition: transform 0.3s ease;
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateY(20px) scale(0.95);
  }

  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

@keyframes slideDown {
  from {
    opacity: 1;
    transform: translateY(0) scale(1);
  }

  to {
    opacity: 0;
    transform: translateY(20px) scale(0.95);
  }
}

.animate-slide-up {
  animation: slideUp 0.3s ease-out;
}
</style>

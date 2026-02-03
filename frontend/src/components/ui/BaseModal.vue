<script setup lang="ts">
/**
 * BaseModal - Reusable modal wrapper component.
 * Encapsulates: Teleport, Transition, overlay, drag handle, and animations.
 */
import { X } from 'lucide-vue-next';

defineOptions({
  inheritAttrs: false
});

interface Props {
  modelValue: boolean;
  title?: string;
  maxHeight?: string;
  showDragHandle?: boolean;
  showCloseButton?: boolean;
  contentClass?: string;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
}>();

const close = () => {
  emit('update:modelValue', false);
};
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div
        v-bind="$attrs"
        v-if="modelValue"
        class="fixed inset-0 z-50 flex flex-col justify-end bg-gray-900/40"
        @click.self="close"
      >
        <!-- Modal Container -->
        <div
          class="relative w-full bg-surface-light dark:bg-surface-dark rounded-t-2xl shadow-2xl flex flex-col overflow-hidden animate-slide-up"
          :style="{ maxHeight: maxHeight || '85vh' }"
        >
          <!-- Drag Handle -->
          <div
            v-if="showDragHandle !== false"
            class="flex justify-center pt-3 pb-2 cursor-pointer shrink-0"
            @click="close"
          >
            <div class="h-1 w-10 rounded-full bg-gray-300 dark:bg-gray-600"></div>
          </div>

          <!-- Header (optional) -->
          <header
            v-if="title || showCloseButton || $slots.header"
            class="flex items-center justify-between px-4 pb-3 shrink-0"
          >
            <slot name="header">
              <h2 v-if="title" class="text-lg font-bold text-slate-900 dark:text-white">
                {{ title }}
              </h2>
            </slot>
            <button
              v-if="showCloseButton"
              class="p-2 -mr-2 rounded-full text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
              @click="close"
            >
              <X :size="24" />
            </button>
          </header>

          <!-- Content Slot -->
          <div class="flex-1" :class="contentClass ?? 'overflow-y-auto'">
            <slot></slot>
          </div>

          <!-- Footer Slot -->
          <div v-if="$slots.footer" class="shrink-0">
            <slot name="footer"></slot>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.3s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.modal-enter-active .animate-slide-up {
  animation: slideUp 0.3s ease-out;
}

.modal-leave-active .animate-slide-up {
  animation: slideDown 0.3s ease-in;
}

@keyframes slideUp {
  from {
    transform: translateY(100%);
  }
  to {
    transform: translateY(0);
  }
}

@keyframes slideDown {
  from {
    transform: translateY(0);
  }
  to {
    transform: translateY(100%);
  }
}
</style>

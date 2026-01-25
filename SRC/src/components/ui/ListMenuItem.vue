<script setup lang="ts">
/**
 * ListMenuItem - Reusable menu item component for sidebars and lists.
 */
import { ChevronRight } from 'lucide-vue-next';

defineProps<{
  icon: any; // Changed from string to any to support Component
  iconBgColor?: string;
  iconTextColor?: string;
  label: string;
  showChevron?: boolean;
  disabled?: boolean;
}>();

const emit = defineEmits<{
  click: [];
}>();
</script>

<template>
  <button
    class="flex w-full items-center justify-between p-4 hover:bg-gray-50 dark:hover:bg-slate-800/50 text-left transition-colors"
    :class="{ 'opacity-50 cursor-not-allowed': disabled }"
    :disabled="disabled"
    @click="!disabled && emit('click')"
  >
    <div class="flex items-center gap-3">
      <!-- Icon Container -->
      <div
        class="flex h-10 w-10 items-center justify-center rounded-full"
        :class="iconBgColor || 'bg-slate-100 dark:bg-slate-700'"
      >
        <component
          :is="icon"
          :class="iconTextColor || 'text-slate-600 dark:text-slate-300'"
          :size="24"
        />
      </div>

      <!-- Label -->
      <span class="text-sm font-medium text-slate-700 dark:text-slate-200">
        {{ label }}
      </span>
    </div>

    <!-- Chevron -->
    <ChevronRight
      v-if="showChevron !== false"
      class="text-slate-400"
      :size="24"
    />
  </button>
</template>

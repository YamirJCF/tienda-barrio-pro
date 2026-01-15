<script setup lang="ts">
/**
 * StatCard - Reusable statistics card component.
 * Used in Dashboard to display KPIs with consistent styling.
 */

type IconColor = 'green' | 'blue' | 'orange' | 'purple' | 'red' | 'slate';

defineProps<{
  icon: string;
  iconColor?: IconColor;
  title: string;
  value: string;
  subtitle?: string;
  subtitleColor?: 'red' | 'slate';
}>();

const colorClasses: Record<IconColor, { bg: string; text: string }> = {
  green: {
    bg: 'bg-green-50 dark:bg-green-900/20',
    text: 'text-green-600 dark:text-green-400',
  },
  blue: {
    bg: 'bg-blue-50 dark:bg-blue-900/20',
    text: 'text-blue-600 dark:text-blue-400',
  },
  orange: {
    bg: 'bg-orange-50 dark:bg-orange-900/20',
    text: 'text-orange-600 dark:text-orange-400',
  },
  purple: {
    bg: 'bg-purple-50 dark:bg-purple-900/20',
    text: 'text-purple-600 dark:text-purple-400',
  },
  red: {
    bg: 'bg-red-50 dark:bg-red-900/20',
    text: 'text-red-600 dark:text-red-400',
  },
  slate: {
    bg: 'bg-slate-100 dark:bg-slate-700',
    text: 'text-slate-600 dark:text-slate-300',
  },
};
</script>

<template>
  <div
    class="flex flex-col justify-between gap-3 rounded-xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-surface-dark p-4 shadow-sm"
  >
    <!-- Icon -->
    <div
      class="rounded-lg p-2 w-fit"
      :class="[colorClasses[iconColor || 'blue'].bg, colorClasses[iconColor || 'blue'].text]"
    >
      <span class="material-symbols-outlined text-[28px]">{{ icon }}</span>
    </div>

    <!-- Content -->
    <div>
      <p class="text-slate-500 dark:text-slate-400 text-[10px] font-semibold uppercase tracking-wide">
        {{ title }}
      </p>
      <h3 class="text-xl font-bold text-slate-900 dark:text-white">{{ value }}</h3>
      <p
        v-if="subtitle"
        class="text-xs mt-0.5"
        :class="subtitleColor === 'red' ? 'text-red-500' : 'text-slate-400'"
      >
        {{ subtitle }}
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { PropType } from 'vue';
import type { HistoryItem } from '../../composables/useHistory';
import { formatRelativeTime } from '../../composables/useRelativeTime';

defineProps({
  item: {
    type: Object as PropType<HistoryItem>,
    required: true,
  },
});
</script>

<template>
  <article
    class="relative flex items-center gap-4 p-4 bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-slate-100 dark:border-slate-700 hover:border-blue-200 dark:hover:border-blue-800 transition-colors cursor-pointer group"
  >
    <!-- Icon Box -->
    <div
      class="shrink-0 flex items-center justify-center w-12 h-12 rounded-full transition-transform group-hover:scale-110"
      :class="item.colorClass"
    >
      <span class="material-symbols-outlined text-2xl">{{ item.icon }}</span>
    </div>

    <!-- Content -->
    <div class="flex-1 min-w-0">
      <div class="flex justify-between items-start mb-0.5">
        <h3 class="font-bold text-slate-900 dark:text-white truncate pr-2">
          {{ item.title }}
        </h3>
        <!-- Amount (if exists) -->
        <span
          v-if="item.amountFormatted"
          class="shrink-0 font-bold text-slate-900 dark:text-emerald-400"
          :class="{ 'text-red-600 dark:text-red-400': item.type === 'expenses' }"
        >
          {{ item.type === 'expenses' ? '-' : '' }}{{ item.amountFormatted }}
        </span>
      </div>

      <p class="text-sm text-slate-600 dark:text-slate-300 truncate">
        {{ item.subtitle }}
      </p>

      <div class="flex items-center gap-2 mt-1.5 text-xs text-slate-400">
        <span class="flex items-center gap-1">
          <span class="material-symbols-outlined text-[14px]">person</span>
          {{ item.user }}
        </span>
        <span>•</span>
        <span>{{ formatRelativeTime(item.date) }}</span>
      </div>
    </div>

    <!-- Chevron -->
    <div class="hidden sm:block text-slate-300 dark:text-slate-600">
      <span class="material-symbols-outlined">chevron_right</span>
    </div>
  </article>
</template>

<script setup lang="ts">
import { PropType, computed } from 'vue';
import type { HistoryItem } from '../../composables/useHistory';
import { formatRelativeTime } from '../../composables/useRelativeTime';
import { 
  Tag, ShoppingCart, Banknote, LogIn, Lock, Shield, 
  ChevronRight, User, HelpCircle, Vault, Package
} from 'lucide-vue-next';

const props = defineProps({
  item: {
    type: Object as PropType<HistoryItem>,
    required: true,
  },
});

const emit = defineEmits<{
  'click': [id: string];
}>();

const iconComponent = computed(() => {
  const map: Record<string, any> = {
    'price_change': Tag,
    'shopping_cart': ShoppingCart,
    'payments': Banknote,
    'login': LogIn,
    'lock': Lock,
    'shield': Shield,
    'vault': Vault,
    'package': Package,
  };
  return map[props.item.icon] || HelpCircle;
});
</script>

<template>
  <article
    class="relative flex items-center gap-4 p-4 bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-slate-100 dark:border-slate-700 hover:border-blue-200 dark:hover:border-blue-800 transition-colors cursor-pointer group"
    @click="emit('click', item.id)"
  >
    <!-- Icon Box -->
    <div
      class="shrink-0 flex items-center justify-center w-12 h-12 rounded-full transition-transform group-hover:scale-110"
      :class="item.colorClass"
    >
      <component :is="iconComponent" :size="24" />
    </div>

    <!-- Content -->
    <div class="flex-1 min-w-0">
      <div class="flex justify-between items-start mb-0.5">
        <div class="flex items-center gap-2 min-w-0">
          <h3 class="font-bold text-slate-900 dark:text-white truncate">
            {{ item.title }}
          </h3>
          <!-- Badge -->
          <span
            v-if="item.badge"
            class="shrink-0 px-2 py-0.5 text-[10px] font-bold uppercase rounded-full"
            :class="item.badge.color"
          >
            {{ item.badge.text }}
          </span>
        </div>
        <!-- Amount (if exists) -->
        <span
          v-if="item.amountFormatted"
          class="shrink-0 font-bold text-slate-900 dark:text-emerald-400 ml-2"
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
          <User :size="14" />
          {{ item.user }}
        </span>
        <span>•</span>
        <span>{{ formatRelativeTime(item.date) }}</span>
      </div>
    </div>

    <!-- Chevron -->
    <div class="hidden sm:block text-slate-300 dark:text-slate-600">
      <ChevronRight :size="24" />
    </div>
  </article>
</template>

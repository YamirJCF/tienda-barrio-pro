<script setup lang="ts">
import { 
  Banknote, 
  TrendingUp, 
  Users, 
  Package, 
  Store, 
  Wallet,
  CreditCard,
  AlertCircle
} from 'lucide-vue-next';
import { computed } from 'vue';

/**
 * StatCard - Reusable statistics card component.
 * Updated to use Lucide icons and Nu-Style aesthetics.
 */

type IconColor = 'green' | 'blue' | 'orange' | 'purple' | 'red' | 'slate';

const props = defineProps<{
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

// Map legacy material icon names to Lucide components
const iconComponent = computed(() => {
  switch (props.icon) {
    case 'payments': return Banknote;
    case 'show_chart': return TrendingUp;
    case 'person': return Users;
    case 'group': return Users;
    case 'inventory_2': return Package;
    case 'point_of_sale': return Store;
    case 'account_balance_wallet': return Wallet;
    case 'credit_card': return CreditCard;
    default: return AlertCircle;
  }
});
</script>

<template>
  <div
    class="flex flex-col justify-between gap-3 rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-surface-dark p-4 shadow-sm"
  >
    <!-- Icon (Squircle) -->
    <div
      class="rounded-xl p-2.5 w-fit"
      :class="[colorClasses[iconColor || 'blue'].bg, colorClasses[iconColor || 'blue'].text]"
    >
      <component :is="iconComponent" :size="24" :stroke-width="1.5" />
    </div>

    <!-- Content -->
    <div>
      <p
        class="text-slate-500 dark:text-slate-400 text-[10px] font-bold uppercase tracking-widest"
      >
        {{ title }}
      </p>
      <h3 class="text-xl font-bold text-slate-900 dark:text-white mt-1">{{ value }}</h3>
      <p
        v-if="subtitle"
        class="text-xs mt-1 font-medium"
        :class="subtitleColor === 'red' ? 'text-red-500' : 'text-slate-400'"
      >
        {{ subtitle }}
      </p>
    </div>
  </div>
</template>

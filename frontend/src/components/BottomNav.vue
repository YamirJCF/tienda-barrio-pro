<script setup lang="ts">
import { useRouter, useRoute } from 'vue-router';
import { 
  Calculator, 
  Package, 
  Users, 
  LayoutDashboard, 
  BarChart3 
} from 'lucide-vue-next';
import { useAuthStore } from '../stores/auth';
import { computed } from 'vue';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();

const isActive = (name: string) => route.name === name;

const canViewReports = computed(() => authStore.canViewReports);
const isAdmin = computed(() => authStore.isAdmin);

// Tab visibility logic
const showInventory = true;
const showClients = true;
</script>

<template>
  <nav
    class="fixed bottom-0 left-0 w-full bg-white dark:bg-surface-dark border-t border-gray-200 dark:border-gray-800 z-40 pb-safe"
  >
    <div
      class="grid h-16 max-w-lg mx-auto"
      :class="isAdmin ? 'grid-cols-5' : canViewReports ? 'grid-cols-4' : 'grid-cols-3'"
    >
      <!-- Item: Vender -->
      <button
        @click="router.push('/pos')"
        class="flex flex-col items-center justify-center gap-1 transition-colors"
        :class="isActive('pos') ? 'text-primary' : 'text-slate-400 dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-300'"
      >
        <Calculator :size="24" :stroke-width="isActive('pos') ? 2 : 1.5" />
        <span class="text-[10px] font-medium tracking-wide">Vender</span>
      </button>

      <!-- Item: Productos -->
      <button
        v-if="showInventory"
        @click="router.push('/inventory')"
        class="flex flex-col items-center justify-center gap-1 transition-colors"
        :class="isActive('inventory') ? 'text-primary' : 'text-slate-400 dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-300'"
      >
        <Package :size="24" :stroke-width="isActive('inventory') ? 2 : 1.5" />
        <span class="text-[10px] font-medium tracking-wide">Productos</span>
      </button>

      <!-- Item: Reportes -->
      <button
        v-if="canViewReports"
        @click="router.push('/reports')"
        class="flex flex-col items-center justify-center gap-1 transition-colors"
        :class="isActive('reports') || isActive('financial-dashboard') || isActive('history') ? 'text-emerald-600 dark:text-emerald-400' : 'text-slate-400 dark:text-slate-500 hover:text-emerald-600 dark:hover:text-emerald-400'"
      >
        <BarChart3 :size="24" :stroke-width="isActive('reports') ? 2 : 1.5" />
        <span class="text-[10px] font-medium tracking-wide">Reportes</span>
      </button>

      <!-- Item: Clientes -->
      <button
        v-if="showClients"
        @click="router.push('/clients')"
        class="flex flex-col items-center justify-center gap-1 transition-colors"
        :class="isActive('clients') ? 'text-primary' : 'text-slate-400 dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-300'"
      >
        <Users :size="24" :stroke-width="isActive('clients') ? 2 : 1.5" />
        <span class="text-[10px] font-medium tracking-wide">Clientes</span>
      </button>

      <!-- Item: Admin -->
      <button
        v-if="isAdmin"
        @click="router.push('/admin')"
        class="flex flex-col items-center justify-center gap-1 transition-colors"
        :class="isActive('admin') ? 'text-primary' : 'text-slate-400 dark:text-slate-500 hover:text-slate-600 dark:hover:text-slate-300'"
      >
        <LayoutDashboard :size="24" :stroke-width="isActive('admin') ? 2 : 1.5" />
        <span class="text-[10px] font-medium tracking-wide">Admin</span>
      </button>
    </div>
  </nav>
</template>

<style scoped>
.pb-safe {
  padding-bottom: env(safe-area-inset-bottom, 20px);
}
</style>

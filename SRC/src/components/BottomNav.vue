<script setup lang="ts">
import { useRouter, useRoute } from 'vue-router';
import { Calculator, Package, Users, LayoutDashboard, BarChart3 } from 'lucide-vue-next';

const router = useRouter();
const route = useRoute();

const isActive = (name: string) => route.name === name;
</script>

<template>
  <nav
    class="fixed bottom-0 left-0 w-full bg-white dark:bg-surface-dark border-t border-gray-200 dark:border-gray-800 z-40 pb-safe">
    <!-- WO-008: Reorganizado con 5 tabs, Reportes prominente -->
    <div class="grid grid-cols-5 h-16 max-w-lg mx-auto">
      <button @click="router.push('/pos')"
        class="group flex flex-col items-center justify-center gap-1 transition-colors"
        :class="isActive('pos') ? 'text-primary' : 'text-slate-400 dark:text-slate-500 hover:text-primary'">
        <Calculator :size="22" :stroke-width="isActive('pos') ? 2.5 : 2" />
        <span class="text-[10px] font-medium">Vender</span>
      </button>

      <button @click="router.push('/inventory')"
        class="group flex flex-col items-center justify-center gap-1 transition-colors"
        :class="isActive('inventory') ? 'text-primary' : 'text-slate-400 dark:text-slate-500 hover:text-primary'">
        <Package :size="22" :stroke-width="isActive('inventory') ? 2.5 : 2" />
        <span class="text-[10px] font-medium">Productos</span>
      </button>

      <!-- REPORTES - Core Value Prominente -->
      <button @click="router.push('/admin')"
        class="group flex flex-col items-center justify-center gap-1 transition-colors"
        :class="isActive('admin') && route.query.tab === 'reportes' ? 'text-emerald-500' : 'text-slate-400 dark:text-slate-500 hover:text-emerald-500'">
        <BarChart3 :size="22" :stroke-width="2" />
        <span class="text-[10px] font-medium text-emerald-600 dark:text-emerald-400 font-bold">Reportes</span>
      </button>

      <button @click="router.push('/clients')"
        class="group flex flex-col items-center justify-center gap-1 transition-colors"
        :class="isActive('clients') ? 'text-primary' : 'text-slate-400 dark:text-slate-500 hover:text-primary'">
        <Users :size="22" :stroke-width="isActive('clients') ? 2.5 : 2" />
        <span class="text-[10px] font-medium">Clientes</span>
      </button>

      <button @click="router.push('/admin')"
        class="group flex flex-col items-center justify-center gap-1 transition-colors"
        :class="isActive('admin') ? 'text-primary' : 'text-slate-400 dark:text-slate-500 hover:text-primary'">
        <LayoutDashboard :size="22" :stroke-width="isActive('admin') ? 2.5 : 2" />
        <span class="text-[10px] font-medium">Admin</span>
      </button>
    </div>
  </nav>
</template>

<style scoped>
.pb-safe {
  padding-bottom: env(safe-area-inset-bottom, 20px);
}
</style>
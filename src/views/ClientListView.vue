<script setup lang="ts">
import { Search, Plus, AlertTriangle, QrCode } from 'lucide-vue-next';
import BottomNav from '../components/BottomNav.vue';

const clients = [
  { id: 1, name: 'Maria Perez', cc: '1.020.304', debt: 120000, initials: 'MP', color: 'bg-blue-100 text-blue-600' },
  { id: 2, name: 'Jorge Villamizar', cc: '98.765.432', debt: 45000, initials: 'JV', color: 'bg-purple-100 text-purple-600' },
  { id: 3, name: 'Luisa Mendoza', cc: '52.190.876', debt: 0, initials: 'LM', color: 'bg-emerald-100 text-emerald-600' },
  { id: 4, name: 'Carlos Rodriguez', cc: '79.444.111', debt: 15500, initials: 'CR', color: 'bg-orange-100 text-orange-600' },
];
</script>

<template>
  <div class="flex flex-col h-screen bg-background-light dark:bg-background-dark pb-24">
    <header class="sticky top-0 z-30 bg-background-light/95 dark:bg-background-dark/95 backdrop-blur-sm border-b border-gray-200 dark:border-gray-800 pb-2">
      <div class="flex items-center px-4 pt-4 pb-2 justify-between">
        <h2 class="text-slate-900 dark:text-white text-xl font-bold">Cartera de Clientes</h2>
        <div class="bg-red-100 dark:bg-red-900/30 px-3 py-1.5 rounded-full flex items-center gap-1.5">
          <AlertTriangle :size="16" class="text-red-600 dark:text-red-400" />
          <span class="text-red-700 dark:text-red-300 text-xs font-bold whitespace-nowrap">Total: $180.500</span>
        </div>
      </div>
      <div class="px-4 py-2">
        <div class="relative">
          <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <Search class="text-gray-400" :size="20" />
          </div>
          <input type="text" class="block w-full rounded-xl border-none bg-white dark:bg-slate-800 py-3 pl-10 pr-4 text-sm text-slate-900 dark:text-white shadow-sm placeholder-slate-400 focus:ring-2 focus:ring-primary" placeholder="Buscar por nombre o cédula..." />
        </div>
      </div>
    </header>

    <main class="flex-1 overflow-y-auto px-4 py-4 flex flex-col gap-3">
      <div v-for="client in clients" :key="client.id" class="relative flex items-center gap-3 bg-white dark:bg-slate-800 rounded-lg shadow-sm p-3 border-l-[6px] overflow-hidden" :class="client.debt > 0 ? 'border-red-500' : 'border-emerald-500'">
        <div class="h-12 w-12 shrink-0 rounded-full flex items-center justify-center font-bold text-lg" :class="client.color">
          {{ client.initials }}
        </div>
        <div class="flex flex-1 flex-col justify-center min-w-0">
          <p class="text-slate-900 dark:text-white text-base font-bold truncate">{{ client.name }}</p>
          <p class="text-gray-500 text-xs font-medium truncate">CC: {{ client.cc }}</p>
        </div>
        <div class="flex flex-col items-end gap-1">
          <p class="text-base font-bold leading-tight" :class="client.debt > 0 ? 'text-red-600' : 'text-emerald-600'">
            ${{ client.debt }}
          </p>
          <button class="flex h-8 w-8 items-center justify-center rounded-lg bg-gray-100 dark:bg-slate-700 text-slate-800 dark:text-white hover:bg-gray-200 transition-colors">
            <QrCode :size="18" />
          </button>
        </div>
      </div>
    </main>

    <div class="absolute bottom-24 right-4 z-40">
      <button class="flex h-14 w-14 items-center justify-center rounded-full bg-primary text-white shadow-lg hover:bg-blue-600 transition-all active:scale-90">
        <Plus :size="32" />
      </button>
    </div>

    <BottomNav />
  </div>
</template>
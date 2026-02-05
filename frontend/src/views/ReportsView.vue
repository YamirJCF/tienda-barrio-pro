<script setup lang="ts">
import { useRouter } from 'vue-router';
import { ArrowLeft } from 'lucide-vue-next';
import SmartDailySummary from '../components/SmartDailySummary.vue';
import BottomNav from '../components/BottomNav.vue';

const router = useRouter();

const goBack = () => {
  router.push('/');
};
</script>

<template>
  <div class="relative flex min-h-screen w-full flex-col overflow-x-hidden pb-20 bg-background-light dark:bg-background-dark">
    <!-- Header -->
    <header class="sticky top-0 z-40 bg-background-light/95 dark:bg-background-dark/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-800">
      <div class="flex items-center justify-between px-4 py-3 gap-3">
        <button
          @click="goBack"
          class="flex items-center justify-center -ml-2 p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <ArrowLeft :size="24" :stroke-width="1.5" />
        </button>
        <h2 class="text-xl font-bold leading-tight tracking-tight flex-1 dark:text-white">
          Reportes y Análisis
        </h2>
      </div>
    </header>

    <main class="flex-1 pt-4">
      <SmartDailySummary />
    </main>

    <BottomNav />
  </div>
</template>

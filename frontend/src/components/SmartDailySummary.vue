<script setup lang="ts">
import { onMounted, computed } from 'vue';
import { useReportsStore } from '../stores/reports';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import {
  Banknote,
  Smartphone,
  BookOpen,
  AlertTriangle,
  CheckCircle,
  TrendingUp,
  TrendingDown,
  Minus
} from 'lucide-vue-next';

const reportsStore = useReportsStore();
const { formatCurrency } = useCurrencyFormat();

onMounted(() => {
  reportsStore.fetchDailySummary();
});

const summary = computed(() => reportsStore.summary);
const isLoading = computed(() => reportsStore.isLoading);
const error = computed(() => reportsStore.error);

// Helper for Traffic Light Styles
const trafficLightClasses = computed(() => {
  const status = summary.value?.traffic_light.status;
  switch (status) {
    case 'green':
      return 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-400 border-emerald-100 dark:border-emerald-800';
    case 'red':
      return 'bg-rose-50 dark:bg-rose-900/20 text-rose-700 dark:text-rose-400 border-rose-100 dark:border-rose-800';
    default:
      return 'bg-slate-50 dark:bg-slate-800 text-slate-700 dark:text-slate-400 border-slate-100 dark:border-slate-700';
  }
});
</script>

<template>
  <div class="flex flex-col gap-6 w-full max-w-md mx-auto pb-24">
    
    <!-- Loading State -->
    <div v-if="isLoading" class="flex flex-col gap-6 px-4 pt-4 animate-pulse">
      <div class="h-24 w-full bg-slate-200 dark:bg-slate-800 rounded-2xl"></div>
      <div class="h-16 w-3/4 mx-auto bg-slate-200 dark:bg-slate-800 rounded-xl"></div>
      <div class="grid grid-cols-3 gap-3">
        <div class="h-24 bg-slate-200 dark:bg-slate-800 rounded-xl"></div>
        <div class="h-24 bg-slate-200 dark:bg-slate-800 rounded-xl"></div>
        <div class="h-24 bg-slate-200 dark:bg-slate-800 rounded-xl"></div>
      </div>
      <div class="h-40 bg-slate-200 dark:bg-slate-800 rounded-xl"></div>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="p-8 text-center">
      <div class="inline-flex p-4 bg-red-50 text-red-500 rounded-full mb-4">
        <AlertTriangle :size="32" />
      </div>
      <h3 class="text-lg font-bold text-slate-800 dark:text-white mb-2">No pudimos cargar el resumen</h3>
      <p class="text-sm text-slate-500 mb-6">{{ error }}</p>
      <button 
        @click="reportsStore.fetchDailySummary()" 
        class="px-6 py-2 bg-primary text-white rounded-xl font-medium shadow-lg shadow-primary/30 active:scale-95 transition-transform"
      >
        Reintentar
      </button>
    </div>

    <!-- Content -->
    <div v-else-if="summary" class="flex flex-col animate-fade-in-up">
      
      <!-- 1. Header Contextual (Semáforo) -->
      <header 
        class="mx-4 p-5 rounded-2xl border flex items-center gap-4 shadow-sm"
        :class="trafficLightClasses"
      >
        <div class="p-2 bg-white/50 dark:bg-black/20 rounded-xl shrink-0 backdrop-blur-sm">
          <TrendingUp v-if="summary.traffic_light.status === 'green'" :size="24" />
          <TrendingDown v-else-if="summary.traffic_light.status === 'red'" :size="24" />
          <Minus v-else :size="24" />
        </div>
        <div>
          <p class="text-xs uppercase font-bold opacity-70 tracking-wider mb-0.5">Resumen de Hoy</p>
          <p class="text-lg font-bold leading-tight">
            {{ summary.traffic_light.message }}
          </p>
        </div>
      </header>

      <!-- 2. Hero Section (La Verdad) -->
      <div class="text-center py-8">
        <p class="text-sm font-medium text-slate-400 uppercase tracking-widest mb-2">Ventas Totales</p>
        <h1 class="text-5xl font-black text-slate-900 dark:text-white tracking-tight">
          {{ formatCurrency(summary.hero_number).replace(',00', '') }}
        </h1>
      </div>

      <!-- 3. Money Breakdown (Desglose) -->
      <div class="grid grid-cols-3 gap-3 px-4">
        <!-- Cash -->
        <div class="bg-white dark:bg-slate-800 p-4 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm flex flex-col items-center text-center gap-2">
          <div class="p-2 bg-emerald-50 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 rounded-lg">
            <Banknote :size="20" />
          </div>
          <div>
            <span class="text-[10px] uppercase font-bold text-slate-400 block mb-0.5">Efectivo</span>
            <span class="font-bold text-slate-800 dark:text-white block">
              {{ formatCurrency(summary.money_breakdown.cash).replace(',00', '').replace('$', '') }}
            </span>
          </div>
        </div>

        <!-- Digital -->
        <div class="bg-white dark:bg-slate-800 p-4 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm flex flex-col items-center text-center gap-2">
          <div class="p-2 bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 rounded-lg">
            <Smartphone :size="20" />
          </div>
          <div>
            <span class="text-[10px] uppercase font-bold text-slate-400 block mb-0.5">Digital</span>
            <span class="font-bold text-slate-800 dark:text-white block">
              {{ formatCurrency(summary.money_breakdown.transfer).replace(',00', '').replace('$', '') }}
            </span>
          </div>
        </div>

        <!-- Fiado -->
        <div class="bg-white dark:bg-slate-800 p-4 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm flex flex-col items-center text-center gap-2">
          <div class="p-2 bg-orange-50 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400 rounded-lg">
            <BookOpen :size="20" />
          </div>
          <div>
            <span class="text-[10px] uppercase font-bold text-slate-400 block mb-0.5">Fiado</span>
            <span class="font-bold text-slate-800 dark:text-white block">
              {{ formatCurrency(summary.money_breakdown.credit).replace(',00', '').replace('$', '') }}
            </span>
          </div>
        </div>
      </div>

      <!-- 4. Feed de Alertas -->
      <div class="mt-8 px-4">
        <h3 class="text-sm font-bold text-slate-400 uppercase tracking-wider mb-4 pl-2">
          Atención Requerida
        </h3>

        <!-- Empty State Alertas -->
        <div 
          v-if="summary.alerts.length === 0" 
          class="bg-white dark:bg-slate-800 p-6 rounded-2xl border border-slate-100 dark:border-slate-700 text-center"
        >
          <CheckCircle :size="32" class="text-emerald-400 mx-auto mb-2" />
          <p class="text-sm font-medium text-slate-600 dark:text-slate-300">¡Todo en orden! No hay alertas urgentes.</p>
        </div>

        <!-- Lista de Alertas -->
        <div v-else class="flex flex-col gap-3">
          <div 
            v-for="(alert, index) in summary.alerts" 
            :key="index"
            class="flex items-start gap-4 p-4 bg-white dark:bg-slate-800 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm"
          >
            <div class="p-2 shrink-0 bg-rose-50 dark:bg-rose-900/20 text-rose-500 rounded-lg mt-0.5">
              <AlertTriangle :size="20" />
            </div>
            <div class="flex-1">
               <p class="text-sm font-medium text-slate-800 dark:text-slate-200 leading-snug">
                 {{ alert.message }}
               </p>
               <p class="text-xs text-rose-500 font-medium mt-1">Requiere atención inmediata</p>
            </div>
          </div>
        </div>
      </div>

      <!-- 5. Recordatorio Footer -->
      <div class="mt-8 mx-4 p-4 bg-violet-50 dark:bg-violet-900/20 border border-violet-100 dark:border-violet-800/30 rounded-xl text-center">
        <p class="text-sm font-medium text-violet-700 dark:text-violet-300 animate-pulse">
           💡 {{ summary.reminder.message }}
        </p>
      </div>

    </div>
  </div>
</template>

<style scoped>
.animate-fade-in-up {
  animation: fadeInUp 0.5s ease-out;
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>

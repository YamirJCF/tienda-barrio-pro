<script setup lang="ts">
import { ref, watch, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { ArrowLeft, BarChart3, Search } from 'lucide-vue-next';
import BottomNav from '../components/BottomNav.vue';

// Vistas Integradas
import FinancialDashboardView from './FinancialDashboardView.vue';
import HistoryView from './HistoryView.vue';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();

// Determinación dinámica de la Pestaña Activa
type ReportTab = 'dashboard' | 'history';
const activeTab = ref<ReportTab>((route.query.tab as ReportTab) || 'dashboard');

const goBack = () => {
  router.push('/');
};

// Sincronizar cambios de pestaña con la URL
watch(activeTab, (newTab) => {
  router.replace({ query: { ...route.query, tab: newTab } });
});

onMounted(() => {
  if (route.query.tab && ['dashboard', 'history'].includes(route.query.tab as string)) {
    activeTab.value = route.query.tab as ReportTab;
  }
});
</script>

<template>
  <div class="relative flex min-h-screen w-full flex-col overflow-x-hidden pb-20 bg-background-light dark:bg-background-dark">
    <!-- Header Global del Hub -->
    <header class="sticky top-0 z-40 bg-background-light/95 dark:bg-background-dark/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-800">
      <div class="flex items-center justify-between px-4 py-3 gap-3">
        <button
          @click="goBack"
          aria-label="Volver atrás"
          class="flex items-center justify-center -ml-2 p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <ArrowLeft :size="24" :stroke-width="1.5" />
        </button>
        <h2 class="text-xl font-bold leading-tight tracking-tight flex-1 dark:text-white">
          Centro de Inteligencia
        </h2>
      </div>

      <!-- Pestañas Paritarias Lado-a-Lado -->
      <div class="px-4 pb-3">
        <div class="flex h-12 w-full items-center justify-center rounded-2xl bg-slate-200/80 dark:bg-slate-800/80 p-1">
          <label
            class="flex cursor-pointer h-full flex-1 items-center justify-center overflow-hidden rounded-xl px-2 transition-all"
            :class="
              activeTab === 'dashboard'
                ? 'bg-white dark:bg-slate-700 shadow-sm text-primary dark:text-primary font-bold ring-1 ring-black/5 dark:ring-white/10'
                : 'text-slate-500 dark:text-slate-400 font-semibold hover:bg-white/50 dark:hover:bg-slate-700/50'
            "
            @click="activeTab = 'dashboard'"
          >
            <span class="flex items-center gap-2 truncate text-sm">
              <BarChart3 :size="18" :stroke-width="1.5" />
              Dashboard
            </span>
          </label>
          <label
            class="flex cursor-pointer h-full flex-1 items-center justify-center overflow-hidden rounded-xl px-2 transition-all"
            :class="
              activeTab === 'history'
                ? 'bg-white dark:bg-slate-700 shadow-sm text-primary dark:text-primary font-bold ring-1 ring-black/5 dark:ring-white/10'
                : 'text-slate-500 dark:text-slate-400 font-semibold hover:bg-white/50 dark:hover:bg-slate-700/50'
            "
            @click="activeTab = 'history'"
          >
            <span class="flex items-center gap-2 truncate text-sm">
              <Search :size="18" :stroke-width="1.5" />
              Historial y Auditoría
            </span>
          </label>
        </div>
      </div>
    </header>

    <!-- Contenido Dinámico (Renderizado Completo para mantener estado) -->
    <main class="flex-1">
      <div v-show="activeTab === 'dashboard'">
        <FinancialDashboardView :is-embedded="true" />
      </div>
      <div v-show="activeTab === 'history'">
        <HistoryView :is-embedded="true" />
      </div>
    </main>

    <BottomNav />
  </div>
</template>

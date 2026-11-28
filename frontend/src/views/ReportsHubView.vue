<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { ArrowLeft, BarChart3, History } from 'lucide-vue-next';
import FinancialDashboardTab from '../components/reports/FinancialDashboardTab.vue';
import AuditHistoryTab from '../components/reports/AuditHistoryTab.vue';
import BottomNav from '../components/BottomNav.vue';

type ReportTab = 'dashboard' | 'history';

const route = useRoute();
const router = useRouter();

const resolveTabFromRoute = (): ReportTab => {
  if (route.path === '/history') {
    return 'history';
  }
  if (route.path === '/admin/financial-dashboard') {
    return 'dashboard';
  }
  if (route.query.tab === 'history') {
    return 'history';
  }
  if (route.query.tab === 'dashboard') {
    return 'dashboard';
  }
  if (route.query.saleId || route.query.sessionId || route.query.domain) {
    return 'history';
  }
  return 'dashboard';
};

const activeTab = ref<ReportTab>(resolveTabFromRoute());

const initialHistoryDomain = computed(() =>
  typeof route.query.domain === 'string' ? route.query.domain : undefined
);
const initialSaleId = computed(() =>
  typeof route.query.saleId === 'string' ? route.query.saleId : null
);
const initialSessionId = computed(() =>
  typeof route.query.sessionId === 'string' ? route.query.sessionId : null
);

const normalizeAliasIfNeeded = () => {
  if (route.path === '/admin/financial-dashboard') {
    activeTab.value = 'dashboard';
    router.replace({ path: '/reports', query: { ...route.query, tab: 'dashboard' } });
    return true;
  }
  if (route.path === '/history') {
    activeTab.value = 'history';
    router.replace({ path: '/reports', query: { ...route.query, tab: 'history' } });
    return true;
  }
  return false;
};

const switchTab = (tab: ReportTab) => {
  activeTab.value = tab;
  router.replace({ path: '/reports', query: { ...route.query, tab } });
};

const goBack = () => {
  if (route.query.from === 'admin') {
    router.push('/admin');
    return;
  }
  router.push('/');
};

watch(
  () => [route.path, route.query.tab, route.query.saleId, route.query.sessionId, route.query.domain],
  () => {
    if (!normalizeAliasIfNeeded()) {
      activeTab.value = resolveTabFromRoute();
    }
  }
);

onMounted(() => {
  normalizeAliasIfNeeded();
});
</script>

<template>
  <div class="min-h-screen bg-background-light dark:bg-background-dark flex flex-col pb-16">
    <!-- Header Global del Hub -->
    <header class="sticky top-0 z-40 bg-background-light/95 dark:bg-background-dark/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-800">
      <div class="flex items-center justify-between px-4 h-[56px] max-w-3xl mx-auto w-full">
        <button
          type="button"
          data-testid="reports-back-btn"
          @click="goBack"
          class="flex items-center gap-1.5 text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white transition-colors"
        >
          <ArrowLeft :size="20" :stroke-width="1.5" />
          <span class="text-sm font-medium">Volver</span>
        </button>
        <h1 class="text-base font-bold text-slate-900 dark:text-white tracking-tight">
          Reportes
        </h1>
        <div class="w-16"></div>
      </div>

      <!-- Segmented Switcher Accessible -->
      <div class="px-4 pb-3 pt-1 max-w-3xl mx-auto w-full">
        <div
          role="tablist"
          aria-label="Secciones de reportes"
          class="flex h-10 w-full items-center justify-center rounded-xl bg-slate-200 dark:bg-slate-800 p-1"
        >
          <button
            type="button"
            role="tab"
            :aria-selected="activeTab === 'dashboard'"
            data-testid="reports-tab-dashboard"
            class="flex h-full flex-1 items-center justify-center gap-1.5 rounded-lg px-2 transition-all text-xs font-semibold"
            :class="activeTab === 'dashboard'
              ? 'bg-white dark:bg-slate-700 text-primary dark:text-white shadow-sm'
              : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'"
            @click="switchTab('dashboard')"
          >
            <BarChart3 :size="15" />
            <span>Resumen</span>
          </button>

          <button
            type="button"
            role="tab"
            :aria-selected="activeTab === 'history'"
            data-testid="reports-tab-history"
            class="flex h-full flex-1 items-center justify-center gap-1.5 rounded-lg px-2 transition-all text-xs font-semibold"
            :class="activeTab === 'history'
              ? 'bg-white dark:bg-slate-700 text-primary dark:text-white shadow-sm'
              : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'"
            @click="switchTab('history')"
          >
            <History :size="15" />
            <span>Historial</span>
          </button>
        </div>
      </div>
    </header>

    <!-- Lazy Tab Mounting (v-if / v-else prevents background RPC fan-out) -->
    <main class="flex-1">
      <FinancialDashboardTab v-if="activeTab === 'dashboard'" />
      <AuditHistoryTab
        v-else
        :initial-domain="initialHistoryDomain"
        :initial-sale-id="initialSaleId"
        :initial-session-id="initialSessionId"
      />
    </main>

    <BottomNav />
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue';
import { useRouter } from 'vue-router';

const props = defineProps<{
  isEmbedded?: boolean;
}>();
import { useFinancialStore, type PeriodType } from '../stores/financial';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import InventoryHealthWidget from '../components/reports/InventoryHealthWidget.vue';
import ClientLedgerWidget from '../components/reports/ClientLedgerWidget.vue';
import {
  ArrowLeft,
  TrendingUp,
  TrendingDown,
  Banknote,
  Smartphone,
  BookOpen,
  AlertTriangle,
  Package,
  RefreshCcw,
} from 'lucide-vue-next';

const router = useRouter();
const store = useFinancialStore();
const { formatCurrency } = useCurrencyFormat();

// Period tabs
const periods: { key: PeriodType; label: string }[] = [
  { key: 'today', label: 'Hoy' },
  { key: 'week', label: 'Semana' },
  { key: 'month', label: 'Mes' },
];

function changePeriod(period: PeriodType) {
  store.setPeriod(period);
}

function goBack() {
  router.push('/admin');
}

function retry() {
  store.loadSnapshots();
  store.setPeriod(store.activePeriod);
}

function stockStatusColor(status: string): string {
  switch (status) {
    case 'out': return 'text-red-500';
    case 'critical': return 'text-orange-500';
    case 'low': return 'text-yellow-500';
    default: return 'text-green-500';
  }
}

function stockStatusLabel(status: string): string {
  switch (status) {
    case 'out': return 'Agotado';
    case 'critical': return 'Crítico';
    case 'low': return 'Bajo';
    default: return 'OK';
  }
}

function intensityWidth(index: number, total: number): string {
  if (total <= 1) return '100%';
  const pct = Math.max(20, 100 - ((index / (total - 1)) * 80));
  return `${pct}%`;
}

function intensityColor(index: number): string {
  if (index < 3) return 'bg-rose-500';
  if (index < 6) return 'bg-amber-400';
  return 'bg-slate-300 dark:bg-slate-600';
}

onMounted(() => {
  store.loadSnapshots();
  store.setPeriod('today');
});
</script>

<template>
  <div class="relative flex min-h-screen w-full flex-col overflow-x-hidden pb-20 bg-background-light dark:bg-background-dark">

    <!-- Header -->
    <header v-if="!isEmbedded" class="sticky top-0 z-40 bg-background-light/95 dark:bg-background-dark/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-800">
      <div class="flex items-center justify-between px-4 h-[65px]">
        <button @click="goBack" class="flex items-center gap-2 text-slate-600 dark:text-slate-400 active:scale-95 transition-transform">
          <ArrowLeft :size="20" :stroke-width="1.5" />
          <span class="text-sm font-medium">Admin</span>
        </button>
        <h1 class="text-lg font-bold text-slate-900 dark:text-white">📊 Dashboard Financiero</h1>
        <div class="w-10"></div>
      </div>
    </header>

    <!-- Period Tabs -->
    <div 
      class="sticky z-30 w-full bg-background-light dark:bg-background-dark px-4 pb-4 pt-2 shadow-[0_4px_10px_-10px_rgba(0,0,0,0.1)]"
      :class="isEmbedded ? 'top-0' : 'top-[65px]'"
    >
      <div class="flex h-12 w-full items-center justify-center rounded-2xl bg-slate-200 dark:bg-slate-800 p-1">
        <button
          v-for="p in periods"
          :key="p.key"
          class="flex h-full flex-1 items-center justify-center rounded-xl px-2 transition-all text-sm font-semibold"
          :class="store.activePeriod === p.key
            ? 'bg-white dark:bg-slate-700 text-primary shadow-sm'
            : 'text-slate-500 dark:text-slate-400'"
          @click="changePeriod(p.key)"
        >
          {{ p.label }}
        </button>
      </div>
    </div>

    <!-- Main Content -->
    <main class="flex flex-col gap-6 px-4 pt-4 max-w-lg mx-auto w-full">

      <!-- Loading Skeletons for Time Series -->
      <div v-if="store.isLoadingTimeSeries" class="flex flex-col gap-6 animate-pulse">
        <div class="h-24 w-full bg-slate-200 dark:bg-slate-800 rounded-2xl"></div>
        <div class="grid grid-cols-3 gap-3">
          <div class="h-20 bg-slate-200 dark:bg-slate-800 rounded-xl"></div>
          <div class="h-20 bg-slate-200 dark:bg-slate-800 rounded-xl"></div>
          <div class="h-20 bg-slate-200 dark:bg-slate-800 rounded-xl"></div>
        </div>
        <div class="h-16 w-full bg-slate-200 dark:bg-slate-800 rounded-2xl"></div>
        <div class="h-40 w-full bg-slate-200 dark:bg-slate-800 rounded-2xl"></div>
      </div>

      <!-- Error State -->
      <div
        v-else-if="store.error"
        class="flex flex-col items-center gap-4 py-12 text-center"
      >
        <AlertTriangle :size="48" class="text-red-400" />
        <p class="text-slate-600 dark:text-slate-400 text-sm">{{ store.error }}</p>
        <button
          @click="retry"
          class="flex items-center gap-2 px-6 py-2 bg-primary text-white rounded-xl font-medium shadow-lg shadow-primary/30 active:scale-95 transition-transform"
        >
          <RefreshCcw :size="16" />
          Reintentar
        </button>
      </div>

      <!-- Dashboard Content -->
      <div v-else-if="store.summary" class="flex flex-col gap-6 animate-fade-in-up">

        <!-- 1. Traffic Light Header -->
        <header
          class="p-5 rounded-2xl border flex items-center gap-4 shadow-sm"
          :class="{
            'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800/40': store.summary.traffic_light.status === 'green',
            'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800/40': store.summary.traffic_light.status === 'red',
            'bg-slate-50 dark:bg-slate-800 border-slate-200 dark:border-slate-700': store.summary.traffic_light.status === 'gray',
          }"
        >
          <div
            class="flex h-12 w-12 shrink-0 items-center justify-center rounded-full"
            :class="{
              'bg-green-100 dark:bg-green-900/40': store.summary.traffic_light.status === 'green',
              'bg-red-100 dark:bg-red-900/40': store.summary.traffic_light.status === 'red',
              'bg-slate-200 dark:bg-slate-700': store.summary.traffic_light.status === 'gray',
            }"
          >
            <TrendingUp v-if="store.summary.traffic_light.status === 'green'" :size="24" class="text-green-600 dark:text-green-400" />
            <TrendingDown v-else-if="store.summary.traffic_light.status === 'red'" :size="24" class="text-red-500 dark:text-red-400" />
            <span v-else class="text-lg">📊</span>
          </div>
          <p class="text-sm font-medium text-slate-700 dark:text-slate-300">
            {{ store.summary.traffic_light.message }}
          </p>
        </header>

        <!-- 2. KPI Hero Cards -->
        <section class="flex flex-col gap-3">
          <!-- Ventas Totales (Hero) -->
          <div class="bg-white dark:bg-slate-800 p-6 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm text-center">
            <p class="text-xs font-bold text-slate-400 uppercase tracking-wider mb-1">Ventas Totales</p>
            <h2 class="text-4xl font-black text-slate-900 dark:text-white tracking-tight">
              $ {{ formatCurrency(store.summary.total_sales) }}
            </h2>
          </div>

          <!-- Sub-KPIs: Costo & Ganancia -->
          <div class="grid grid-cols-2 gap-3">
            <div class="bg-white dark:bg-slate-800 p-4 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm text-center">
              <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1">Costo Mercancía</p>
              <p class="text-lg font-bold text-slate-700 dark:text-slate-300">
                $ {{ formatCurrency(store.summary.total_cost) }}
              </p>
            </div>
            <div
              class="p-4 rounded-xl border shadow-sm text-center"
              :class="store.summary.net_profit >= 0
                ? 'bg-emerald-50 dark:bg-emerald-900/20 border-emerald-200 dark:border-emerald-800/40'
                : 'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800/40'"
            >
              <p class="text-[10px] font-bold uppercase tracking-wider mb-1"
                :class="store.summary.net_profit >= 0 ? 'text-emerald-500' : 'text-red-500'">
                {{ store.summary.net_profit >= 0 ? '📈 Ganancia Neta' : '⚠️ Pérdida Neta' }}
              </p>
              <p class="text-lg font-bold"
                :class="store.summary.net_profit >= 0 ? 'text-emerald-600 dark:text-emerald-400' : 'text-red-600 dark:text-red-400'">
                $ {{ formatCurrency(Math.abs(store.summary.net_profit)) }}
              </p>
              <p class="text-[10px] text-slate-400 mt-1">Margen: {{ store.summary.profit_margin }}%</p>
            </div>
          </div>
        </section>

        <!-- 3. Money Breakdown: "¿Dónde Está el Dinero?" -->
        <section>
          <h3 class="text-sm font-bold text-slate-400 uppercase tracking-wider mb-3 pl-1">
            💰 ¿Dónde Está el Dinero?
          </h3>
          <div class="grid grid-cols-3 gap-3">
            <!-- Efectivo -->
            <div class="bg-white dark:bg-slate-800 p-4 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm flex flex-col items-center text-center gap-2">
              <div class="flex h-10 w-10 items-center justify-center rounded-full bg-green-100 dark:bg-green-900/30">
                <Banknote :size="20" class="text-green-600 dark:text-green-400" />
              </div>
              <div>
                <span class="text-[10px] text-slate-400 block">Efectivo</span>
                <span class="font-bold text-slate-800 dark:text-white block">
                  {{ formatCurrency(store.summary.money_breakdown.cash) }}
                </span>
              </div>
            </div>

            <!-- Transferencias -->
            <div class="bg-white dark:bg-slate-800 p-4 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm flex flex-col items-center text-center gap-2">
              <div class="flex h-10 w-10 items-center justify-center rounded-full bg-blue-100 dark:bg-blue-900/30">
                <Smartphone :size="20" class="text-blue-600 dark:text-blue-400" />
              </div>
              <div>
                <span class="text-[10px] text-slate-400 block">Transferencias</span>
                <span class="font-bold text-slate-800 dark:text-white block">
                  {{ formatCurrency(store.summary.money_breakdown.transfer) }}
                </span>
              </div>
            </div>

            <!-- Fiado -->
            <div class="bg-white dark:bg-slate-800 p-4 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm flex flex-col items-center text-center gap-2">
              <div class="flex h-10 w-10 items-center justify-center rounded-full bg-amber-100 dark:bg-amber-900/30">
                <BookOpen :size="20" class="text-amber-600 dark:text-amber-400" />
              </div>
              <div>
                <span class="text-[10px] text-slate-400 block">Fiado</span>
                <span class="font-bold text-slate-800 dark:text-white block">
                  {{ formatCurrency(store.summary.money_breakdown.credit) }}
                </span>
              </div>
            </div>

            <!-- Client Ledger Widget (Snapshot) injected into Liquidity Section -->
            <div class="col-span-3 mt-2">
              <ClientLedgerWidget :ledger="store.clientLedger" :isLoading="store.isLoadingSnapshots" />
            </div>
          </div>
        </section>

        <!-- 4. Centro de Acción Orgánico -->
        <section>
          <h3 class="text-sm font-bold text-slate-400 uppercase tracking-wider mb-3 pl-1">
            ⚡ Centro de Mando
          </h3>

          <div class="flex flex-col gap-4">
            <!-- Inventory Health Widget (Snapshot) -->
            <InventoryHealthWidget :health="store.inventoryHealth" :isLoading="store.isLoadingSnapshots" />
          
            <!-- Top Ventas List (Time-Series) -->
            <div class="bg-white dark:bg-slate-800 p-5 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm flex flex-col gap-3">
              <h4 class="font-bold text-slate-900 dark:text-white mb-2 flex items-center gap-2">
                🔥 Top Ventas del Período
              </h4>
              
              <div v-if="store.topProductsByUnits.length === 0" class="text-center py-6">
                <Package :size="32" class="mx-auto text-slate-300 dark:text-slate-600 mb-2" />
                <p class="text-sm text-slate-400">No hay ventas registradas</p>
              </div>

              <div
                v-for="(product, index) in store.topProductsByUnits.slice(0, 5)"
                :key="product.product_id"
                class="flex items-center gap-3 py-2 border-b border-slate-50 border-white/5 dark:border-slate-800 last:border-0"
              >
                <!-- Ranking -->
                <span class="flex h-6 w-6 shrink-0 items-center justify-center rounded-md text-xs font-black"
                  :class="index < 3 ? 'bg-rose-100 dark:bg-rose-900/40 text-rose-600 dark:text-rose-400' : 'bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-400'">
                  #{{ index + 1 }}
                </span>

                <!-- Product Info -->
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-bold text-slate-800 dark:text-slate-200 truncate">{{ product.product_name }}</p>
                  <p class="text-xs text-slate-500 dark:text-slate-400">
                    Rota c/ {{ product.dias_rotacion }} d.
                  </p>
                </div>

                <!-- Stats -->
                <div class="text-right shrink-0">
                  <p class="text-sm font-bold text-slate-800 dark:text-slate-200">{{ product.units_sold }}</p>
                  <p class="text-[10px] text-slate-400 uppercase tracking-wider">uds</p>
                </div>
              </div>
            </div>
          </div>
        </section>

        <!-- 5. Info Footer -->
        <div class="p-4 bg-violet-50 dark:bg-violet-900/20 border border-violet-100 dark:border-violet-800/30 rounded-xl text-center">
          <p class="text-xs font-medium text-violet-600 dark:text-violet-400">
            💡 Los costos estimados se basan en el precio de compra registrado. Actualiza los costos de tus productos para mayor precisión.
          </p>
        </div>
      </div>

      <!-- Empty State (no summary at all) -->
      <div v-else class="text-center py-16">
        <Package :size="48" class="mx-auto text-slate-300 dark:text-slate-600 mb-3" />
        <p class="text-slate-500 dark:text-slate-400 text-sm">Selecciona un período para ver tu resumen financiero</p>
      </div>
    </main>
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

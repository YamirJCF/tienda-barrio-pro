<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useFinancialStore, type PeriodType } from '../stores/financial';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import {
  ArrowLeft,
  TrendingUp,
  TrendingDown,
  Banknote,
  Smartphone,
  BookOpen,
  AlertTriangle,
  Snowflake,
  Package,
  RefreshCcw,
} from 'lucide-vue-next';

const router = useRouter();
const store = useFinancialStore();
const { formatCurrency } = useCurrencyFormat();

// Sub-tab state for "Decisiones de Compra"
const activeProductTab = ref<'top' | 'stagnant'>('top');

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
  store.setPeriod('today');
});
</script>

<template>
  <div class="relative flex min-h-screen w-full flex-col overflow-x-hidden pb-20 bg-background-light dark:bg-background-dark">

    <!-- Header -->
    <header class="sticky top-0 z-40 bg-background-light/95 dark:bg-background-dark/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-800">
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
    <div class="sticky top-[65px] z-30 w-full bg-background-light dark:bg-background-dark px-4 pb-4 pt-2 shadow-[0_4px_10px_-10px_rgba(0,0,0,0.1)]">
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

      <!-- Loading Skeletons -->
      <div v-if="store.isLoading" class="flex flex-col gap-6 animate-pulse">
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
          </div>

          <!-- Fiado Pendiente Banner -->
          <div
            v-if="store.summary.fiado_pendiente > 0"
            class="mt-3 p-3 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800/40 rounded-xl flex items-center gap-3"
          >
            <span class="text-lg">📋</span>
            <div class="flex-1">
              <p class="text-xs font-bold text-amber-700 dark:text-amber-400">Fiado Pendiente Total</p>
              <p class="text-sm font-bold text-amber-800 dark:text-amber-300">
                $ {{ formatCurrency(store.summary.fiado_pendiente) }}
              </p>
            </div>
            <span class="text-[10px] px-2 py-0.5 bg-amber-200 dark:bg-amber-800 text-amber-800 dark:text-amber-200 rounded-full font-bold">
              Por cobrar
            </span>
          </div>
        </section>

        <!-- 4. Decisiones de Compra -->
        <section>
          <h3 class="text-sm font-bold text-slate-400 uppercase tracking-wider mb-3 pl-1">
            📦 Decisiones de Compra
          </h3>

          <!-- Sub-tabs -->
          <div class="flex gap-2 mb-4">
            <button
              @click="activeProductTab = 'top'"
              class="flex-1 py-2 px-3 rounded-xl text-sm font-semibold transition-all"
              :class="activeProductTab === 'top'
                ? 'bg-rose-100 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400'
                : 'bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400'"
            >
              🔥 Top Ventas
            </button>
            <button
              @click="activeProductTab = 'stagnant'"
              class="flex-1 py-2 px-3 rounded-xl text-sm font-semibold transition-all"
              :class="activeProductTab === 'stagnant'
                ? 'bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400'
                : 'bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400'"
            >
              ❄️ Estancados
            </button>
          </div>

          <!-- Top Ventas List -->
          <div v-if="activeProductTab === 'top'" class="flex flex-col gap-2">
            <div v-if="store.topProducts.length === 0" class="text-center py-8">
              <Package :size="40" class="mx-auto text-slate-300 dark:text-slate-600 mb-2" />
              <p class="text-sm text-slate-400">No hay ventas en este período</p>
            </div>

            <div
              v-for="(product, index) in store.topProducts"
              :key="product.product_id"
              class="bg-white dark:bg-slate-800 p-4 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm flex items-center gap-3"
            >
              <!-- Ranking -->
              <span class="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-sm font-black"
                :class="index < 3 ? 'bg-rose-100 dark:bg-rose-900/30 text-rose-600' : 'bg-slate-100 dark:bg-slate-700 text-slate-500'">
                #{{ index + 1 }}
              </span>

              <!-- Product Info -->
              <div class="flex-1 min-w-0">
                <p class="text-sm font-bold text-slate-800 dark:text-white truncate">{{ product.product_name }}</p>
                <div class="flex items-center gap-2 mt-1">
                  <!-- Intensity Bar -->
                  <div class="h-1.5 rounded-full bg-slate-100 dark:bg-slate-700 flex-1 overflow-hidden">
                    <div class="h-full rounded-full transition-all" :class="intensityColor(index)" :style="{ width: intensityWidth(index, store.topProducts.length) }"></div>
                  </div>
                  <span class="text-[10px] font-bold shrink-0" :class="stockStatusColor(product.stock_status)">
                    {{ stockStatusLabel(product.stock_status) }}
                  </span>
                </div>
              </div>

              <!-- Stats -->
              <div class="text-right shrink-0">
                <p class="text-sm font-bold text-slate-800 dark:text-white">{{ product.units_sold }}</p>
                <p class="text-[10px] text-slate-400">uds</p>
              </div>
            </div>
          </div>

          <!-- Stagnant Products List -->
          <div v-if="activeProductTab === 'stagnant'" class="flex flex-col gap-2">
            <div v-if="store.stagnantProducts.length === 0" class="text-center py-8">
              <Package :size="40" class="mx-auto text-slate-300 dark:text-slate-600 mb-2" />
              <p class="text-sm text-slate-400">¡Sin productos estancados! 🎉</p>
            </div>

            <!-- Stagnant Summary -->
            <div
              v-if="store.stagnantProducts.length > 0"
              class="p-3 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800/40 rounded-xl text-center mb-2"
            >
              <p class="text-xs text-blue-500">Capital inmovilizado total</p>
              <p class="text-lg font-black text-blue-700 dark:text-blue-300">
                $ {{ formatCurrency(store.totalStagnantValue) }}
              </p>
            </div>

            <div
              v-for="product in store.stagnantProducts"
              :key="product.product_id"
              class="bg-white dark:bg-slate-800 p-4 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm flex items-center gap-3"
            >
              <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-blue-100 dark:bg-blue-900/30">
                <Snowflake :size="20" class="text-blue-500" />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-bold text-slate-800 dark:text-white truncate">{{ product.product_name }}</p>
                <p class="text-[10px] text-slate-400">
                  {{ product.days_stagnant }} días sin venta
                  <span v-if="product.last_sale_date"> · Última: {{ product.last_sale_date }}</span>
                  <span v-else> · Nunca vendido</span>
                </p>
              </div>
              <div class="text-right shrink-0">
                <p class="text-sm font-bold text-blue-600 dark:text-blue-400">$ {{ formatCurrency(product.stock_value) }}</p>
                <p class="text-[10px] text-slate-400">inmovilizado</p>
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

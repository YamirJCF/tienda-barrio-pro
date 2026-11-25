<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useFinancialStore, type PeriodType } from '../../stores/financial';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import InventoryHealthWidget from './InventoryHealthWidget.vue';
import ClientLedgerWidget from './ClientLedgerWidget.vue';
import {
  TrendingUp,
  TrendingDown,
  Banknote,
  Smartphone,
  BookOpen,
  AlertTriangle,
  Package,
  RefreshCcw,
  BarChart3,
  Wallet,
  Activity,
  Flame,
  Lightbulb,
  ChevronRight,
  WifiOff,
} from 'lucide-vue-next';

const router = useRouter();
const store = useFinancialStore();
const { formatWithSign } = useCurrencyFormat();

const isOnline = ref(typeof navigator !== 'undefined' ? navigator.onLine : true);

const sanitizedTrafficMessage = computed(() =>
  (store.summary?.traffic_light?.message || '').replace(/^[\p{Extended_Pictographic}\uFE0F\s]+/u, '')
);

const handleOnline = () => {
  isOnline.value = true;
};

const handleOffline = () => {
  isOnline.value = false;
};

// Period tabs
const periods: { key: PeriodType; label: string }[] = [
  { key: 'today', label: 'Hoy' },
  { key: 'week', label: 'Semana' },
  { key: 'month', label: 'Mes' },
];

function changePeriod(period: PeriodType) {
  store.setPeriod(period);
}

function goToProduct(productId: string) {
  if (!productId) return;
  router.push({ path: '/inventory', query: { productId } });
}

function retry() {
  store.loadSnapshots();
  store.setPeriod(store.activePeriod);
}

onMounted(() => {
  if (typeof window !== 'undefined') {
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);
  }
  store.loadSnapshots();
  store.setPeriod('today');
});

onUnmounted(() => {
  if (typeof window !== 'undefined') {
    window.removeEventListener('online', handleOnline);
    window.removeEventListener('offline', handleOffline);
  }
});
</script>

<template>
  <div class="relative flex w-full flex-col overflow-x-hidden pb-20 bg-background-light dark:bg-background-dark">

    <!-- Period Tabs -->
    <div class="relative z-20 w-full bg-background-light dark:bg-background-dark px-4 pb-4 pt-3 shadow-[0_4px_10px_-10px_rgba(0,0,0,0.1)]">
      <div class="flex h-12 w-full items-center justify-center rounded-2xl bg-slate-200 dark:bg-slate-800 p-1 max-w-lg mx-auto">
        <button
          v-for="p in periods"
          :key="p.key"
          type="button"
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
    <main class="flex flex-col gap-6 px-4 pt-2 max-w-lg mx-auto w-full">

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

      <!-- Offline / Error State (N3 Fail-Closed) -->
      <div
        v-else-if="!isOnline || store.error"
        role="alert"
        data-testid="financial-error-banner"
        class="flex flex-col items-center gap-4 py-10 px-5 text-center rounded-2xl border border-rose-200 dark:border-rose-900/40 bg-rose-50 dark:bg-rose-950/20"
      >
        <WifiOff v-if="!isOnline" :size="40" class="text-rose-500" />
        <AlertTriangle v-else :size="40" class="text-rose-500" />
        <p class="text-rose-700 dark:text-rose-300 text-sm font-medium">
          {{ store.error || 'Sin conexión a internet. Reconecta para consultar el balance financiero.' }}
        </p>
        <button
          type="button"
          data-testid="financial-retry-btn"
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
            <BarChart3 v-else :size="24" class="text-slate-600 dark:text-slate-300" />
          </div>
          <p class="text-sm font-medium text-slate-700 dark:text-slate-300">
            {{ sanitizedTrafficMessage }}
          </p>
        </header>

        <!-- 2. KPI Hero Cards -->
        <section class="flex flex-col gap-3">
          <!-- Ventas Totales (Hero) -->
          <div class="bg-white dark:bg-surface-dark p-6 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm text-center">
            <p class="text-xs font-bold text-slate-400 uppercase tracking-wider mb-1">Ingresos Netos del Período</p>
            <h2 class="text-4xl font-black font-mono tabular-nums text-slate-900 dark:text-white tracking-tight">
              {{ formatWithSign(store.summary.revenue) }}
            </h2>
            <p v-if="(store.summary.refunds_total || 0) > 0" class="text-xs font-mono tabular-nums text-slate-500 dark:text-slate-400 mt-1.5">
              Bruto: {{ formatWithSign(store.summary.gross_sales || store.summary.revenue) }} − Reembolsos: {{ formatWithSign(store.summary.refunds_total || 0) }}
            </p>
          </div>
          <!-- Sub-KPIs: Flujo Financiero -->
          <div class="grid grid-cols-2 gap-3">
            <div class="bg-white dark:bg-surface-dark p-4 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm text-center">
              <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1">Costo de Ventas (FIFO)</p>
              <p class="text-lg font-bold font-mono tabular-nums text-slate-700 dark:text-slate-300">
                {{ formatWithSign(store.summary.cogs) }}
              </p>
            </div>
            <div class="bg-white dark:bg-surface-dark p-4 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm text-center">
              <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1">Utilidad Bruta</p>
              <p class="text-lg font-bold font-mono tabular-nums text-emerald-600 dark:text-emerald-400">
                {{ formatWithSign(store.summary.gross_profit) }}
              </p>
              <p class="text-[10px] font-mono tabular-nums text-slate-400 mt-1">Margen: {{ store.summary.gross_margin }}%</p>
            </div>
            
            <div class="bg-white dark:bg-surface-dark p-4 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm text-center">
              <p class="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1">Gastos Operativos (OPEX)</p>
              <p class="text-lg font-bold font-mono tabular-nums text-red-500 dark:text-red-400">
                {{ formatWithSign(store.summary.operational_expenses) }}
              </p>
            </div>
            <div
              class="p-4 rounded-xl border shadow-sm text-center flex flex-col justify-center"
              :class="store.summary.net_profit >= 0
                ? 'bg-emerald-50 dark:bg-emerald-900/20 border-emerald-200 dark:border-emerald-800/40'
                : 'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800/40'"
            >
              <p
                class="text-[10px] font-bold uppercase tracking-wider mb-1 inline-flex items-center justify-center gap-1"
                :class="store.summary.net_profit >= 0 ? 'text-emerald-600 dark:text-emerald-400' : 'text-red-600 dark:text-red-400'"
              >
                <TrendingUp v-if="store.summary.net_profit >= 0" :size="12" />
                <AlertTriangle v-else :size="12" />
                <span>{{ store.summary.net_profit >= 0 ? 'Ganancia Neta' : 'Pérdida Neta' }}</span>
              </p>
              <p
                class="text-lg font-bold font-mono tabular-nums"
                :class="store.summary.net_profit >= 0 ? 'text-emerald-600 dark:text-emerald-400' : 'text-red-600 dark:text-red-400'"
              >
                {{ formatWithSign(Math.abs(store.summary.net_profit)) }}
              </p>
            </div>
          </div>

          <!-- Valor de Inventario -->
          <div class="bg-blue-50 dark:bg-blue-900/20 p-4 rounded-2xl border border-blue-100 dark:border-blue-800/40 shadow-sm text-center flex items-center justify-between">
            <div class="flex items-center gap-2">
              <Package :size="20" class="text-blue-600 dark:text-blue-400" />
              <p class="text-xs font-bold text-blue-600 dark:text-blue-400 uppercase tracking-wider">Capital en Stock</p>
            </div>
            <p class="text-xl font-black font-mono tabular-nums text-blue-700 dark:text-blue-300 tracking-tight">
              {{ formatWithSign(store.summary.inventory_value) }}
            </p>
          </div>
        </section>

        <!-- 3. Money Breakdown: "¿Dónde Está el Dinero?" -->
        <section>
          <h3 class="text-sm font-bold text-slate-400 uppercase tracking-wider mb-3 pl-1 flex items-center gap-1.5">
            <Wallet :size="15" class="text-slate-400" />
            <span>¿Dónde Está el Dinero?</span>
          </h3>
          <div class="grid grid-cols-3 gap-3">
            <!-- Efectivo -->
            <div class="bg-white dark:bg-surface-dark p-4 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm flex flex-col items-center text-center gap-2">
              <div class="flex h-10 w-10 items-center justify-center rounded-full bg-green-100 dark:bg-green-900/30">
                <Banknote :size="20" class="text-green-600 dark:text-green-400" />
              </div>
              <div>
                <span class="text-[10px] text-slate-400 block">Efectivo</span>
                <span class="font-bold font-mono tabular-nums text-slate-800 dark:text-white block">
                  {{ formatWithSign(store.summary.payment_breakdown.cash) }}
                </span>
              </div>
            </div>

            <!-- Transferencias -->
            <div class="bg-white dark:bg-surface-dark p-4 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm flex flex-col items-center text-center gap-2">
              <div class="flex h-10 w-10 items-center justify-center rounded-full bg-blue-100 dark:bg-blue-900/30">
                <Smartphone :size="20" class="text-blue-600 dark:text-blue-400" />
              </div>
              <div>
                <span class="text-[10px] text-slate-400 block">Transferencias</span>
                <span class="font-bold font-mono tabular-nums text-slate-800 dark:text-white block">
                  {{ formatWithSign(store.summary.payment_breakdown.transfer) }}
                </span>
              </div>
            </div>

            <!-- Fiado -->
            <div class="bg-white dark:bg-surface-dark p-4 rounded-xl border border-slate-100 dark:border-slate-700 shadow-sm flex flex-col items-center text-center gap-2">
              <div class="flex h-10 w-10 items-center justify-center rounded-full bg-amber-100 dark:bg-amber-900/30">
                <BookOpen :size="20" class="text-amber-600 dark:text-amber-400" />
              </div>
              <div>
                <span class="text-[10px] text-slate-400 block">Fiado</span>
                <span class="font-bold font-mono tabular-nums text-slate-800 dark:text-white block">
                  {{ formatWithSign(store.summary.payment_breakdown.credit) }}
                </span>
              </div>
            </div>

            <!-- Client Ledger Widget (Snapshot) injected into Liquidity Section -->
            <div class="col-span-3 mt-2">
              <ClientLedgerWidget :ledger="store.clientLedger" :isLoading="store.isLoadingSnapshots" />
            </div>
          </div>

          <!-- Desglose OPEX P&L al Costo (CHK-512) -->
          <div v-if="store.summary.opex_breakdown" class="mt-4 bg-white dark:bg-surface-dark p-4 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm space-y-2.5">
            <div class="flex items-center justify-between">
              <h4 class="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                Desglose OPEX del Período (Cero Doble Conteo)
              </h4>
              <span class="text-xs font-bold font-mono tabular-nums text-rose-600 dark:text-rose-400">
                {{ formatWithSign(store.summary.opex_breakdown.total) }}
              </span>
            </div>
            <div class="grid grid-cols-2 sm:grid-cols-4 gap-2 text-xs">
              <div class="p-2.5 rounded-xl bg-slate-50 dark:bg-slate-900/60">
                <span class="text-[10px] text-slate-400 block">Gastos en Caja</span>
                <strong class="font-mono tabular-nums text-slate-800 dark:text-white">{{ formatWithSign(store.summary.opex_breakdown.cash_expenses) }}</strong>
              </div>
              <div class="p-2.5 rounded-xl bg-orange-50 dark:bg-orange-950/30">
                <span class="text-[10px] text-orange-600 dark:text-orange-400 block">Mermas (Costo)</span>
                <strong class="font-mono tabular-nums text-orange-700 dark:text-orange-300">{{ formatWithSign(store.summary.opex_breakdown.merma_cost) }}</strong>
              </div>
              <div class="p-2.5 rounded-xl bg-sky-50 dark:bg-sky-950/30">
                <span class="text-[10px] text-sky-600 dark:text-sky-400 block">Consumo Negocio</span>
                <strong class="font-mono tabular-nums text-sky-700 dark:text-sky-300">{{ formatWithSign(store.summary.opex_breakdown.consumo_negocio_cost) }}</strong>
              </div>
              <div class="p-2.5 rounded-xl bg-indigo-50 dark:bg-indigo-950/30">
                <span class="text-[10px] text-indigo-600 dark:text-indigo-400 block">Consumo Personal</span>
                <strong class="font-mono tabular-nums text-indigo-700 dark:text-indigo-300">{{ formatWithSign(store.summary.opex_breakdown.consumo_personal_cost) }}</strong>
              </div>
            </div>
          </div>

          <!-- Módulo Exclusivo Admin: Consumos / Retiros Personales (CHK-512) -->
          <div v-if="store.summary.personal_consumptions_summary" class="mt-4 bg-white dark:bg-surface-dark p-4 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm space-y-3">
            <div class="flex flex-wrap items-center justify-between gap-2">
              <h4 class="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
                Consumos / Retiros Personales (Consolidado & Perfil)
              </h4>
              <div class="flex items-center gap-3 text-xs">
                <span class="text-slate-500">
                  Costo P&L: <strong class="font-mono tabular-nums text-indigo-600 dark:text-indigo-400">{{ formatWithSign(store.summary.personal_consumptions_summary.total_cost) }}</strong>
                </span>
                <span class="text-slate-500">
                  Val. Ref. Venta: <strong class="font-mono tabular-nums text-slate-800 dark:text-slate-200">{{ formatWithSign(store.summary.personal_consumptions_summary.total_reference_sale_price) }}</strong>
                </span>
              </div>
            </div>

            <div v-if="store.summary.personal_consumptions_summary.by_profile.length === 0" class="text-xs text-slate-400 italic py-2">
              No se registran consumos personales en el período.
            </div>
            <div v-else class="divide-y divide-slate-100 dark:divide-slate-700/70">
              <div
                v-for="prof in store.summary.personal_consumptions_summary.by_profile"
                :key="prof.profile_key"
                class="py-2 flex items-center justify-between text-xs gap-2"
              >
                <div>
                  <span class="font-bold text-slate-800 dark:text-slate-100">{{ prof.profile_name }}</span>
                  <span class="ml-1.5 text-[10px] uppercase px-1.5 py-0.5 rounded bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-300">
                    {{ prof.profile_role === 'owner' || prof.profile_role === 'manager' ? 'Admin' : 'Empleado' }}
                  </span>
                  <span class="text-[11px] text-slate-400 ml-2">{{ prof.movements_count }} retiros</span>
                </div>
                <div class="text-right font-mono tabular-nums">
                  <span class="font-bold text-indigo-600 dark:text-indigo-400">{{ formatWithSign(prof.total_cost) }}</span>
                  <span class="text-[10px] text-slate-400 block">Ref: {{ formatWithSign(prof.total_reference_sale_price) }}</span>
                </div>
              </div>
            </div>
          </div>
        </section>

        <!-- 4. Centro de Acción Orgánico -->
        <section>
          <h3 class="text-sm font-bold text-slate-400 uppercase tracking-wider mb-3 pl-1 flex items-center gap-1.5">
            <Activity :size="15" class="text-slate-400" />
            <span>Centro de Mando</span>
          </h3>

          <div class="flex flex-col gap-4">
            <!-- Inventory Health Widget (Snapshot) -->
            <InventoryHealthWidget :health="store.inventoryHealth" :isLoading="store.isLoadingSnapshots" />

            <!-- Top Ventas List (Time-Series, Enlace Heterárquico -> /inventory?productId=) -->
            <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm flex flex-col gap-2">
              <h4 class="font-bold text-slate-900 dark:text-white mb-2 flex items-center gap-2">
                <Flame :size="18" class="text-rose-500" />
                <span>Top Ventas del Período</span>
              </h4>

              <div v-if="store.topProductsByUnits.length === 0" class="text-center py-6">
                <Package :size="32" class="mx-auto text-slate-300 dark:text-slate-600 mb-2" />
                <p class="text-sm text-slate-400">No hay ventas registradas</p>
              </div>

              <button
                v-for="(product, index) in store.topProductsByUnits.slice(0, 5)"
                :key="product.product_id"
                type="button"
                data-testid="top-product-link"
                @click="goToProduct(product.product_id)"
                class="w-full text-left flex items-center gap-3 py-2.5 px-2 -mx-2 rounded-xl border-b border-slate-50 dark:border-slate-800 last:border-0 hover:bg-slate-50 dark:hover:bg-slate-800/60 active:scale-[0.99] transition-all cursor-pointer"
              >
                <!-- Ranking -->
                <span
                  class="flex h-6 w-6 shrink-0 items-center justify-center rounded-md text-xs font-black font-mono tabular-nums"
                  :class="index < 3 ? 'bg-rose-100 dark:bg-rose-900/40 text-rose-600 dark:text-rose-400' : 'bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-400'"
                >
                  #{{ index + 1 }}
                </span>

                <!-- Product Info -->
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-bold text-slate-800 dark:text-slate-200 truncate">{{ product.product_name }}</p>
                  <p class="text-xs font-mono tabular-nums text-slate-500 dark:text-slate-400">
                    Rota c/ {{ product.dias_rotacion }} d.
                  </p>
                </div>

                <!-- Stats + Chevron -->
                <div class="text-right shrink-0 flex items-center gap-1.5">
                  <div>
                    <p class="text-sm font-bold font-mono tabular-nums text-slate-800 dark:text-slate-200">{{ product.units_sold }}</p>
                    <p class="text-[10px] text-slate-400 uppercase tracking-wider">uds</p>
                  </div>
                  <ChevronRight :size="16" class="text-slate-400" />
                </div>
              </button>
            </div>
          </div>
        </section>

        <!-- 5. Info Footer -->
        <div class="p-4 bg-violet-50 dark:bg-violet-900/20 border border-violet-100 dark:border-violet-800/30 rounded-xl text-center">
          <p class="text-xs font-medium text-violet-600 dark:text-violet-400 inline-flex items-center justify-center gap-1.5">
            <Lightbulb :size="15" class="shrink-0" />
            <span>Los costos se calculan de manera exacta por el método FIFO basándose en el inventario despachado y los gastos de operación.</span>
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

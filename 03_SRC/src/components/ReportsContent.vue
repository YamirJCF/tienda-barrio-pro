<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useSalesStore } from '../stores/sales';
import { useInventoryStore } from '../stores/inventory';
import { Decimal } from 'decimal.js';

const router = useRouter();
const salesStore = useSalesStore();
const inventoryStore = useInventoryStore();

// State
const selectedPeriod = ref<'today' | 'week' | 'month'>('today');
const selectedTab = ref<'top' | 'low' | 'stale'>('top');

// Period filtering
const getStartDate = (period: 'today' | 'week' | 'month') => {
  const now = new Date();
  switch (period) {
    case 'today':
      return new Date(now.getFullYear(), now.getMonth(), now.getDate());
    case 'week':
      const weekStart = new Date(now);
      weekStart.setDate(now.getDate() - now.getDay());
      weekStart.setHours(0, 0, 0, 0);
      return weekStart;
    case 'month':
      return new Date(now.getFullYear(), now.getMonth(), 1);
    default:
      return new Date(now.getFullYear(), now.getMonth(), now.getDate());
  }
};

// Filtered sales for selected period
const filteredSales = computed(() => {
  const startDate = getStartDate(selectedPeriod.value);
  return salesStore.sales.filter(sale => new Date(sale.date) >= startDate);
});

// Metrics
const totalSales = computed(() => {
  return filteredSales.value.reduce((sum, sale) => sum.plus(sale.total), new Decimal(0));
});

const totalCost = computed(() => {
  // Approximate cost as 70% of sales (simplified)
  return totalSales.value.times(0.7);
});

const netProfit = computed(() => {
  return totalSales.value.minus(totalCost.value);
});

// Payment breakdown
const cashTotal = computed(() => {
  return filteredSales.value
    .filter(s => s.paymentMethod === 'cash')
    .reduce((sum, sale) => sum.plus(sale.total), new Decimal(0));
});

const nequiTotal = computed(() => {
  return filteredSales.value
    .filter(s => s.paymentMethod === 'nequi')
    .reduce((sum, sale) => sum.plus(sale.total), new Decimal(0));
});

const fiadoTotal = computed(() => {
  return filteredSales.value
    .filter(s => s.paymentMethod === 'fiado')
    .reduce((sum, sale) => sum.plus(sale.total), new Decimal(0));
});

// Top selling products
const topProducts = computed(() => {
  const productSales: Record<number, { name: string; quantity: number }> = {};

  filteredSales.value.forEach(sale => {
    sale.items.forEach(item => {
      if (productSales[item.productId]) {
        productSales[item.productId].quantity += item.quantity;
      } else {
        productSales[item.productId] = {
          name: item.productName,
          quantity: item.quantity
        };
      }
    });
  });

  return Object.entries(productSales)
    .map(([id, data]) => ({ id: Number(id), ...data }))
    .sort((a, b) => b.quantity - a.quantity)
    .slice(0, 5);
});

const maxQuantity = computed(() => {
  if (topProducts.value.length === 0) return 1;
  return topProducts.value[0]?.quantity || 1;
});

// Low stock products
const lowStockProducts = computed(() => {
  return inventoryStore.lowStockProducts.slice(0, 5);
});

// Methods
const formatCurrency = (val: Decimal) => {
  return `$${val.toDecimalPlaces(0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".")}`;
};

const goBack = () => {
  router.push('/');
};

// WO: initializeSampleData eliminada - SPEC-007
</script>

<template>
  <div class="flex flex-col">
    <!-- Period Selector -->
    <div class="px-4 pb-4">
      <div class="flex h-10 w-full items-center justify-center rounded-xl bg-slate-100 dark:bg-slate-800 p-1">
        <label
          class="flex cursor-pointer h-full grow items-center justify-center overflow-hidden rounded-[10px] px-2 transition-all duration-200"
          :class="selectedPeriod === 'today' ? 'bg-white dark:bg-slate-700 shadow-sm text-primary font-medium' : 'text-slate-500 dark:text-slate-400'">
          <span class="truncate text-sm">Hoy</span>
          <input v-model="selectedPeriod" class="invisible w-0 h-0 absolute" name="period-selector" type="radio"
            value="today" />
        </label>
        <label
          class="flex cursor-pointer h-full grow items-center justify-center overflow-hidden rounded-[10px] px-2 transition-all duration-200"
          :class="selectedPeriod === 'week' ? 'bg-white dark:bg-slate-700 shadow-sm text-primary font-medium' : 'text-slate-500 dark:text-slate-400'">
          <span class="truncate text-sm">Semana</span>
          <input v-model="selectedPeriod" class="invisible w-0 h-0 absolute" name="period-selector" type="radio"
            value="week" />
        </label>
        <label
          class="flex cursor-pointer h-full grow items-center justify-center overflow-hidden rounded-[10px] px-2 transition-all duration-200"
          :class="selectedPeriod === 'month' ? 'bg-white dark:bg-slate-700 shadow-sm text-primary font-medium' : 'text-slate-500 dark:text-slate-400'">
          <span class="truncate text-sm">Mes</span>
          <input v-model="selectedPeriod" class="invisible w-0 h-0 absolute" name="period-selector" type="radio"
            value="month" />
        </label>
      </div>
    </div>

    <!-- Hero Card - Sales Summary -->
    <div class="mx-4 mt-6">
      <div
        class="relative w-full overflow-hidden rounded-2xl bg-slate-900 shadow-xl shadow-slate-900/10 text-white p-6">
        <div class="absolute top-0 right-0 -mr-16 -mt-16 h-64 w-64 rounded-full bg-blue-500 opacity-10 blur-3xl"></div>
        <div class="flex flex-col gap-1 relative z-10 mb-6">
          <span class="text-slate-400 text-sm font-medium tracking-wide">Ventas Totales</span>
          <h2 class="text-4xl font-bold tracking-tight">{{ formatCurrency(totalSales) }}</h2>
        </div>
        <div class="h-px w-full bg-white/10 mb-5 relative z-10"></div>
        <div class="flex justify-between items-end relative z-10">
          <div class="flex flex-col gap-1">
            <span class="text-slate-400 text-xs font-medium uppercase tracking-wider">Costo Mercancía</span>
            <p class="text-xl font-medium text-slate-300 tracking-tight">{{ formatCurrency(totalCost) }}</p>
          </div>
          <div class="flex flex-col gap-1 text-right items-end">
            <span class="text-slate-400 text-xs font-medium uppercase tracking-wider">Ganancia Neta</span>
            <div class="flex items-center gap-1">
              <span class="material-symbols-outlined text-green-400 text-xl">trending_up</span>
              <p class="text-2xl font-bold text-green-400 tracking-tight">+{{ formatCurrency(netProfit) }}</p>
            </div>
          </div>
        </div>
        <div class="mt-4 pt-4 border-t border-white/5 relative z-10">
          <p class="text-xs text-slate-400 flex items-center gap-2">
            <span class="material-symbols-outlined text-sm">info</span>
            Esto es lo que te queda libre teóricamente
          </p>
        </div>
      </div>
    </div>

    <!-- Payment Breakdown -->
    <div class="mt-8">
      <h3 class="px-6 mb-3 text-sm font-bold text-gray-500 uppercase tracking-wide ml-4 mt-6">¿Dónde está el dinero?
      </h3>
      <div class="grid grid-cols-2 gap-3 px-4">
        <!-- Cash -->
        <div
          class="col-span-1 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-4 shadow-sm flex flex-col justify-between min-h-[140px]">
          <div class="flex justify-between items-start">
            <div class="p-2 bg-green-50 dark:bg-green-900/20 rounded-lg text-green-600 dark:text-green-400">
              <span class="material-symbols-outlined">payments</span>
            </div>
          </div>
          <div>
            <p class="text-slate-500 dark:text-slate-400 text-xs font-medium mb-0.5">Efectivo</p>
            <h4 class="text-lg font-bold text-slate-900 dark:text-white tracking-tight">{{ formatCurrency(cashTotal) }}
            </h4>
            <span
              class="inline-flex mt-2 items-center rounded-md bg-slate-100 dark:bg-slate-700 px-2 py-1 text-[10px] font-medium text-slate-600 dark:text-slate-300 ring-1 ring-inset ring-slate-500/10">
              Debe estar en cajón
            </span>
          </div>
        </div>

        <!-- Nequi -->
        <div
          class="col-span-1 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-4 shadow-sm flex flex-col justify-between min-h-[140px]">
          <div class="flex justify-between items-start">
            <div class="p-2 bg-blue-50 dark:bg-blue-900/20 rounded-lg text-primary">
              <span class="material-symbols-outlined">smartphone</span>
            </div>
          </div>
          <div>
            <p class="text-slate-500 dark:text-slate-400 text-xs font-medium mb-0.5">Nequi / Dav</p>
            <h4 class="text-lg font-bold text-slate-900 dark:text-white tracking-tight">{{ formatCurrency(nequiTotal) }}
            </h4>
            <span
              class="inline-flex mt-2 items-center rounded-md bg-blue-50 dark:bg-blue-900/30 px-2 py-1 text-[10px] font-medium text-blue-700 dark:text-blue-300 ring-1 ring-inset ring-blue-700/10">
              En bancos
            </span>
          </div>
        </div>

        <!-- Fiado -->
        <div
          class="col-span-2 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-4 shadow-sm flex items-center gap-4">
          <div
            class="p-3 bg-orange-50 dark:bg-orange-900/20 rounded-lg text-orange-600 dark:text-orange-400 h-12 w-12 flex items-center justify-center shrink-0">
            <span class="material-symbols-outlined">menu_book</span>
          </div>
          <div class="flex-1">
            <div class="flex justify-between items-baseline">
              <p class="text-slate-500 dark:text-slate-400 text-xs font-medium">Fiado Hoy</p>
              <span
                class="inline-flex items-center rounded-md bg-orange-50 dark:bg-orange-900/30 px-2 py-0.5 text-[10px] font-medium text-orange-700 dark:text-orange-300 ring-1 ring-inset ring-orange-600/20">
                Por cobrar
              </span>
            </div>
            <h4 class="text-lg font-bold text-slate-900 dark:text-white tracking-tight">{{ formatCurrency(fiadoTotal) }}
            </h4>
          </div>
        </div>
      </div>
    </div>

    <!-- Product Rankings -->
    <div class="mt-8 mx-4">
      <h3 class="mb-3 text-sm font-bold text-gray-500 uppercase tracking-wide ml-2">Decisiones de Compra</h3>
      <div
        class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm overflow-hidden">
        <!-- Tabs -->
        <div
          class="flex items-center gap-2 p-3 border-b border-gray-100 dark:border-slate-700 overflow-x-auto hide-scrollbar">
          <button @click="selectedTab = 'top'"
            class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-all shrink-0" :class="selectedTab === 'top'
              ? 'bg-orange-50 dark:bg-orange-900/30 text-orange-700 dark:text-orange-300 ring-1 ring-orange-200 dark:ring-orange-800'
              : 'text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-slate-700'">
            <span class="material-symbols-outlined text-[18px]">local_fire_department</span>
            <span class="text-xs font-bold">Top Ventas</span>
          </button>
          <button @click="selectedTab = 'low'"
            class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-all shrink-0 relative" :class="selectedTab === 'low'
              ? 'bg-red-50 dark:bg-red-900/30 text-red-700 dark:text-red-300 ring-1 ring-red-200 dark:ring-red-800'
              : 'text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-slate-700'">
            <span class="material-symbols-outlined text-[18px]">warning</span>
            <span class="text-xs font-medium">Stock Bajo</span>
            <span v-if="lowStockProducts.length > 0"
              class="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-red-500 text-[9px] font-bold text-white ring-2 ring-white dark:ring-slate-800">
              {{ lowStockProducts.length }}
            </span>
          </button>
          <button @click="selectedTab = 'stale'"
            class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg transition-all shrink-0" :class="selectedTab === 'stale'
              ? 'bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 ring-1 ring-blue-200 dark:ring-blue-800'
              : 'text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-slate-700'">
            <span class="material-symbols-outlined text-[18px]">ac_unit</span>
            <span class="text-xs font-medium">Estancados</span>
          </button>
        </div>

        <!-- Top Products List -->
        <div v-if="selectedTab === 'top'" class="flex flex-col">
          <div v-if="topProducts.length === 0" class="p-8 text-center text-gray-400">
            <span class="material-symbols-outlined text-4xl mb-2">shopping_cart</span>
            <p class="text-sm">No hay ventas en este período</p>
          </div>
          <div v-for="(product, index) in topProducts" :key="product.id"
            class="p-4 border-b border-gray-100 dark:border-slate-700/50 last:border-0 hover:bg-gray-50 dark:hover:bg-slate-700/50 transition-colors">
            <div class="flex items-center gap-3">
              <span class="text-xs font-bold text-gray-400 w-4">#{{ index + 1 }}</span>
              <div class="flex-1 min-w-0">
                <div class="flex justify-between items-end mb-1">
                  <h4 class="text-sm font-semibold text-slate-900 dark:text-white truncate">{{ product.name }}</h4>
                  <span class="text-sm font-mono font-bold text-slate-900 dark:text-white">
                    {{ product.quantity }} <span
                      class="text-[10px] text-gray-500 font-sans font-normal uppercase">unds</span>
                  </span>
                </div>
                <div class="w-full bg-gray-100 dark:bg-slate-700 rounded-full h-1.5 overflow-hidden">
                  <div class="bg-gradient-to-r from-orange-500 to-red-500 h-1.5 rounded-full transition-all"
                    :style="{ width: `${(product.quantity / maxQuantity) * 100}%` }"></div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Low Stock List -->
        <div v-if="selectedTab === 'low'" class="flex flex-col">
          <div v-if="lowStockProducts.length === 0" class="p-8 text-center text-gray-400">
            <span class="material-symbols-outlined text-4xl mb-2">check_circle</span>
            <p class="text-sm">Todo el stock está bien</p>
          </div>
          <div v-for="product in lowStockProducts" :key="product.id"
            class="p-4 border-b border-gray-100 dark:border-slate-700/50 last:border-0 hover:bg-gray-50 dark:hover:bg-slate-700/50 transition-colors">
            <div class="flex items-center gap-3">
              <div class="p-2 bg-red-50 dark:bg-red-900/20 rounded-lg text-red-600">
                <span class="material-symbols-outlined text-[18px]">warning</span>
              </div>
              <div class="flex-1 min-w-0">
                <h4 class="text-sm font-semibold text-slate-900 dark:text-white truncate">{{ product.name }}</h4>
                <p class="text-xs text-gray-500">
                  Stock: <span class="font-bold text-red-500">{{ product.stock.toFixed ? product.stock.toFixed(0) :
                    product.stock }}</span> / Min: {{ product.minStock }}
                </p>
              </div>
            </div>
          </div>
        </div>

        <!-- Stale Products -->
        <div v-if="selectedTab === 'stale'" class="p-8 text-center text-gray-400">
          <span class="material-symbols-outlined text-4xl mb-2">ac_unit</span>
          <p class="text-sm">Función próximamente</p>
          <p class="text-xs mt-1 opacity-60">Productos sin movimiento en 30+ días</p>
        </div>

        <!-- Footer -->
        <div
          class="px-4 py-3 bg-gray-50 dark:bg-slate-800/50 border-t border-gray-100 dark:border-slate-700 flex justify-center">
          <button
            class="text-xs font-medium text-primary flex items-center gap-1 hover:text-blue-700 transition-colors">
            Ver todo el reporte
            <span class="material-symbols-outlined text-sm">arrow_forward</span>
          </button>
        </div>
      </div>
    </div>

    <div class="h-10"></div>
  </div>
</template>

<style scoped>
.hide-scrollbar::-webkit-scrollbar {
  display: none;
}

.hide-scrollbar {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
</style>

<script setup lang="ts">
import { onMounted, computed } from 'vue';
import { useFinancialStore } from '../../stores/financial';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import { Package } from 'lucide-vue-next';

const financialStore = useFinancialStore();
const { formatCurrency } = useCurrencyFormat();

onMounted(async () => {
  if (!financialStore.summary) {
    const today = new Date().toISOString().split('T')[0];
    await financialStore.fetchFinancialReport(today, today).catch(() => {});
  }
});

const totalCost = computed(() => financialStore.summary?.inventory_value ?? 0);
const revenue = computed(() => financialStore.summary?.revenue ?? 0);
const grossProfit = computed(() => financialStore.summary?.gross_profit ?? 0);
const grossMargin = computed(() => financialStore.summary?.gross_margin ?? 0);
</script>

<template>
  <div class="relative w-full overflow-hidden rounded-2xl bg-slate-900 border border-slate-700/50 shadow-xl p-6 text-white animate-fade-in">
    <!-- Decorator -->
     <div class="absolute top-0 right-0 -mr-16 -mt-16 h-64 w-64 rounded-full bg-purple-500 opacity-10 blur-3xl"></div>

    <div class="flex items-center gap-2 mb-4 relative z-10">
      <div class="h-8 w-8 rounded-lg bg-white/10 flex items-center justify-center">
         <Package class="text-purple-300" :size="24" />
      </div>
      <h3 class="font-bold text-lg tracking-tight">Valoración de Inventario</h3>
    </div>

    <!-- Metrics Grid -->
    <div class="grid grid-cols-2 gap-6 relative z-10">
      
      <!-- Cost -->
      <div class="flex flex-col gap-1">
        <span class="text-xs font-bold uppercase text-slate-400 tracking-wider">Costo Total (FIFO)</span>
        <span class="text-2xl font-bold text-white">{{ formatCurrency(totalCost) }}</span>
      </div>

       <!-- Retail / Revenue -->
      <div class="flex flex-col gap-1">
        <span class="text-xs font-bold uppercase text-slate-400 tracking-wider">Ingresos Período</span>
        <span class="text-2xl font-bold text-emerald-400">{{ formatCurrency(revenue) }}</span>
      </div>

       <!-- Profit -->
      <div class="col-span-2 pt-4 border-t border-white/10 flex justify-between items-center">
        <div class="flex flex-col">
            <span class="text-xs font-bold uppercase text-slate-400 tracking-wider">Margen Bruto</span>
             <div class="flex items-baseline gap-2">
                <span class="text-xl font-bold text-white">{{ formatCurrency(grossProfit) }}</span>
                <span class="text-sm font-medium text-emerald-400">({{ grossMargin.toFixed(1) }}%)</span>
             </div>
        </div>
        <div class="text-right max-w-[120px]">
             <p class="text-[10px] leading-tight text-slate-500">
                Valoración oficial calculada por motor financiero backend (FIFO).
             </p>
        </div>
      </div>

    </div>
  </div>
</template>

<style scoped>
.animate-fade-in {
  animation: fadeIn 0.5s ease-out;
}
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>

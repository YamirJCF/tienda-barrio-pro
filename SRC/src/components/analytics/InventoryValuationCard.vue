<script setup lang="ts">
import { computed } from 'vue';
import { useInventoryStore } from '../../stores/inventory';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';

const inventoryStore = useInventoryStore();
const { formatCurrency } = useCurrencyFormat();

const valuation = computed(() => {
  let totalCost = 0;
  let totalRetail = 0;

  inventoryStore.products.forEach(p => {
    const stock = p.stock.toNumber();
    const cost = p.cost ? p.cost.toNumber() : (p.price.toNumber() * 0.7); // Fallback assumption
    const price = p.price.toNumber();

    totalCost += stock * cost;
    totalRetail += stock * price;
  });

  const potentialProfit = totalRetail - totalCost;
  const margin = totalRetail > 0 ? (potentialProfit / totalRetail) * 100 : 0;

  return {
    cost: totalCost,
    retail: totalRetail,
    profit: potentialProfit,
    margin: margin
  };
});
</script>

<template>
  <div class="relative w-full overflow-hidden rounded-2xl bg-slate-900 border border-slate-700/50 shadow-xl p-6 text-white animate-fade-in">
    <!-- Decorator -->
     <div class="absolute top-0 right-0 -mr-16 -mt-16 h-64 w-64 rounded-full bg-purple-500 opacity-10 blur-3xl"></div>

    <div class="flex items-center gap-2 mb-4 relative z-10">
      <div class="h-8 w-8 rounded-lg bg-white/10 flex items-center justify-center">
         <span class="material-symbols-outlined text-purple-300">inventory_2</span>
      </div>
      <h3 class="font-bold text-lg tracking-tight">Valoración de Inventario</h3>
    </div>

    <!-- Metrics Grid -->
    <div class="grid grid-cols-2 gap-6 relative z-10">
      
      <!-- Cost -->
      <div class="flex flex-col gap-1">
        <span class="text-xs font-bold uppercase text-slate-400 tracking-wider">Costo Total</span>
        <span class="text-2xl font-bold text-white">{{ formatCurrency(valuation.cost) }}</span>
      </div>

       <!-- Retail -->
      <div class="flex flex-col gap-1">
        <span class="text-xs font-bold uppercase text-slate-400 tracking-wider">Valor Venta</span>
        <span class="text-2xl font-bold text-emerald-400">{{ formatCurrency(valuation.retail) }}</span>
      </div>

       <!-- Profit -->
      <div class="col-span-2 pt-4 border-t border-white/10 flex justify-between items-center">
        <div class="flex flex-col">
            <span class="text-xs font-bold uppercase text-slate-400 tracking-wider">Margen Potencial</span>
             <div class="flex items-baseline gap-2">
                <span class="text-xl font-bold text-white">{{ formatCurrency(valuation.profit) }}</span>
                <span class="text-sm font-medium text-emerald-400">({{ valuation.margin.toFixed(1) }}%)</span>
             </div>
        </div>
        <div class="text-right max-w-[120px]">
             <p class="text-[10px] leading-tight text-slate-500">
                Calculado sobre todo el stock actual y sus costos registrados. 
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

<script setup lang="ts">
import { onMounted, ref, computed } from 'vue';
import { supabase } from '@/lib/supabase';
import { useAuthStore } from '@/stores/auth';
import { useCurrencyFormat } from '@/composables/useCurrencyFormat';
import {
  AlertTriangle,
  Package,
  Flame,
  TrendingDown,
  Clock,
  Sparkles,
  AlertCircle
} from 'lucide-vue-next';

interface SupplyItem {
  product_id: string;
  product_name: string;
  current_stock: number;
  velocity: number;
  doi: number;
  revenue_at_risk: number;
  status: 'OK' | 'WARNING' | 'CRITICAL' | 'REPRESSED' | 'UNKNOWN';
  suggestion: string;
}

const authStore = useAuthStore();
const { formatCurrency } = useCurrencyFormat();

const items = ref<SupplyItem[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);
const streak = ref(1);

// Fetch Smart Supply Report
const fetchReport = async () => {
  const storeId = authStore.currentStore?.id;
  if (!storeId) return;
  
  isLoading.value = true;
  error.value = null;
  
  try {
    const { data, error: rpcError } = await supabase.rpc('get_smart_supply_report', {
      p_store_id: storeId
    });
    
    if (rpcError) throw rpcError;
    items.value = (data || []) as SupplyItem[];
  } catch (e: any) {
    console.error('[SmartSupply] Fetch failed', e);
    error.value = 'Error al cargar sugerencias';
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  fetchReport();
});

// Computed States
const criticalItems = computed(() => items.value.filter(i => i.status === 'CRITICAL'));
const warningItems = computed(() => items.value.filter(i => i.status === 'WARNING'));
const unknownItems = computed(() => items.value.filter(i => i.status === 'UNKNOWN'));
const alertCount = computed(() => criticalItems.value.length + warningItems.value.length);
const isAllOK = computed(() => 
  items.value.length > 0 && 
  criticalItems.value.length === 0 && 
  warningItems.value.length === 0
);
const isLearning = computed(() => 
  items.value.length > 0 && 
  unknownItems.value.length === items.value.length
);
const totalRisk = computed(() => 
  items.value.reduce((sum, i) => sum + (i.revenue_at_risk || 0), 0)
);
</script>

<template>
  <div class="flex flex-col gap-5 py-6">
    
    <!-- Header with Badge -->
    <div class="flex items-center justify-between px-4">
      <div class="flex items-center gap-3">
        <div class="p-2.5 bg-gradient-to-br from-violet-500 to-indigo-600 rounded-xl shadow-lg shadow-indigo-500/20">
          <Package :size="20" class="text-white" />
        </div>
        <div>
          <h2 class="text-lg font-bold text-slate-800 dark:text-white">
            Sugerencias de Compra
          </h2>
          <p class="text-xs text-slate-500 dark:text-slate-400">
            Solo lectura · Decide tú qué hacer
          </p>
        </div>
      </div>
      
      <!-- Alert Badge -->
      <div 
        v-if="alertCount > 0 && !isLoading"
        class="flex items-center gap-1.5 px-3 py-1.5 bg-rose-500 text-white rounded-full text-xs font-bold shadow-lg shadow-rose-500/30"
      >
        <AlertCircle :size="12" />
        {{ alertCount }}
      </div>
    </div>
    
    <!-- Loading State -->
    <div v-if="isLoading" class="flex flex-col gap-3 px-4">
      <div class="h-20 bg-gradient-to-r from-slate-200 via-slate-100 to-slate-200 dark:from-slate-800 dark:via-slate-700 dark:to-slate-800 rounded-2xl skeleton-shimmer"></div>
      <div class="h-16 bg-gradient-to-r from-slate-200 via-slate-100 to-slate-200 dark:from-slate-800 dark:via-slate-700 dark:to-slate-800 rounded-2xl skeleton-shimmer" style="animation-delay: 0.15s"></div>
    </div>
    
    <!-- Error State -->
    <div v-else-if="error" class="mx-4 p-6 bg-red-50 dark:bg-red-900/20 rounded-2xl text-center border border-red-100 dark:border-red-800">
      <div class="w-14 h-14 mx-auto mb-4 bg-red-100 dark:bg-red-800/50 rounded-full flex items-center justify-center">
        <AlertTriangle :size="28" class="text-red-500" />
      </div>
      <p class="text-sm text-red-600 dark:text-red-400 font-medium">{{ error }}</p>
      <button 
        @click="fetchReport" 
        class="mt-4 px-5 py-2.5 bg-red-500 hover:bg-red-600 text-white rounded-xl text-sm font-bold transition-colors"
      >
        Reintentar
      </button>
    </div>
    
    <!-- Learning State -->
    <div v-else-if="isLearning" class="mx-4 p-8 bg-gradient-to-br from-slate-100 to-slate-50 dark:from-slate-800 dark:to-slate-900 rounded-2xl text-center border border-slate-200 dark:border-slate-700">
      <div class="w-16 h-16 mx-auto mb-4 bg-gradient-to-br from-indigo-100 to-violet-100 dark:from-indigo-900/50 dark:to-violet-900/50 rounded-2xl flex items-center justify-center">
        <Sparkles :size="32" class="text-indigo-500" />
      </div>
      <h3 class="text-lg font-bold text-slate-700 dark:text-slate-200 mb-2">
        Aprendiendo tus patrones
      </h3>
      <p class="text-sm text-slate-500 dark:text-slate-400 max-w-xs mx-auto">
        Dame unos días para analizar tus ventas y predecir qué necesitas pedir.
      </p>
    </div>
    
    <!-- All OK State (Streak Card) -->
    <div 
      v-else-if="isAllOK" 
      class="mx-4 p-6 rounded-2xl text-center relative overflow-hidden"
      style="background: linear-gradient(135deg, #10B981 0%, #059669 100%)"
    >
      <!-- Decorative circles -->
      <div class="absolute -top-10 -right-10 w-32 h-32 bg-white/10 rounded-full"></div>
      <div class="absolute -bottom-8 -left-8 w-24 h-24 bg-white/10 rounded-full"></div>
      
      <Flame :size="44" class="mx-auto text-white mb-3 drop-shadow-lg" />
      <h3 class="text-xl font-black text-white mb-1">
        ¡Inventario Blindado!
      </h3>
      <p class="text-sm text-emerald-100">
        Llevas <span class="font-bold bg-white/20 px-2 py-0.5 rounded-full">{{ streak }} día{{ streak > 1 ? 's' : '' }}</span> sin riesgo de desabastecimiento
      </p>
    </div>
    
    <!-- Alerts State (INFORMATIONAL ONLY) -->
    <div v-else class="flex flex-col gap-4 px-4">
      
      <!-- Total Risk Summary -->
      <div 
        v-if="totalRisk > 0"
        class="p-5 rounded-2xl relative overflow-hidden"
        style="background: linear-gradient(135deg, #F43F5E 0%, #E11D48 100%)"
      >
        <div class="absolute top-0 right-0 w-40 h-40 bg-white/10 rounded-full -translate-y-1/2 translate-x-1/2"></div>
        
        <div class="relative flex items-center gap-4">
          <div class="p-3 bg-white/20 rounded-xl backdrop-blur-sm">
            <TrendingDown :size="28" class="text-white" />
          </div>
          <div>
            <p class="text-xs font-bold text-rose-200 uppercase tracking-wider mb-1">
              Riesgo de Ventas Perdidas
            </p>
            <p class="text-3xl font-black text-white tracking-tight">
              {{ formatCurrency(totalRisk) }}
            </p>
          </div>
        </div>
      </div>
      
      <!-- Info Banner -->
      <p class="text-xs text-slate-400 dark:text-slate-500 text-center italic">
        📋 Esta información es para tu referencia. Anótalo en tu lista de compras.
      </p>
      
      <!-- Critical Items (READ-ONLY) -->
      <div 
        v-for="item in criticalItems" 
        :key="item.product_id"
        class="p-4 bg-rose-50 dark:bg-rose-900/20 border-l-4 border-rose-500 rounded-r-2xl"
      >
        <div class="flex items-start gap-3">
          <div class="p-2 bg-rose-100 dark:bg-rose-800/50 rounded-lg shrink-0">
            <AlertTriangle :size="18" class="text-rose-500" />
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center justify-between gap-2 mb-1">
              <span class="text-xs font-bold text-rose-500 uppercase tracking-wider">🔴 Pedir Urgente</span>
              <span class="text-sm font-black text-rose-600 dark:text-rose-400">
                {{ formatCurrency(item.revenue_at_risk) }}
              </span>
            </div>
            <p class="text-base font-bold text-slate-800 dark:text-white">
              {{ item.product_name }}
            </p>
            <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
              Se agotará antes de que llegue el proveedor
            </p>
          </div>
        </div>
      </div>
      
      <!-- Warning Items (READ-ONLY) -->
      <div 
        v-for="item in warningItems" 
        :key="item.product_id"
        class="p-4 bg-amber-50 dark:bg-amber-900/20 border-l-4 border-amber-400 rounded-r-2xl"
      >
        <div class="flex items-start gap-3">
          <div class="p-2 bg-amber-100 dark:bg-amber-800/50 rounded-lg shrink-0">
            <Clock :size="18" class="text-amber-500" />
          </div>
          <div class="flex-1 min-w-0">
            <span class="text-xs font-bold text-amber-500 uppercase tracking-wider mb-1 block">🟡 Próximo Pedido</span>
            <p class="text-base font-bold text-slate-800 dark:text-white">
              {{ item.product_name }}
            </p>
            <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
              Incluirlo en el próximo pedido al proveedor
            </p>
          </div>
        </div>
      </div>
      
    </div>
    
  </div>
</template>

<style scoped>
@keyframes shimmer {
  0% { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}
.skeleton-shimmer {
  background-size: 200% 100%;
  animation: shimmer 1.5s ease-in-out infinite;
}
</style>

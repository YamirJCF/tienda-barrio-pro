<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import { PackageSearch, AlertTriangle, ArrowRight, Activity, TrendingUp, Clock } from 'lucide-vue-next';
import type { InventoryHealth } from '../../stores/financial';

const props = defineProps<{
    health: InventoryHealth | null;
    isLoading: boolean;
}>();

const router = useRouter();
const { formatCurrency } = useCurrencyFormat();

function goToInventory() {
    router.push('/inventory');
}

const statusColor = computed(() => {
    if (!props.health) return 'slate';
    switch (props.health.estado) {
        case 'riesgo': return 'red';
        case 'optimo': return 'green';
        case 'saludable': return 'emerald';
        case 'sobre_inventario': return 'amber';
        default: return 'slate';
    }
});

const statusLabel = computed(() => {
    if (!props.health) return 'Desconocido';
    switch (props.health.estado) {
        case 'riesgo': return 'Riesgo Agotamiento (< 7 días)';
        case 'optimo': return 'Rotación Óptima (7-15 días)';
        case 'saludable': return 'Saludable (15-30 días)';
        case 'sobre_inventario': return 'Capital Estancado (> 30 días)';
        default: return 'Sin suficientes datos';
    }
});

const hasCriticalItems = computed(() => {
    return props.health && props.health.distribucion_rotacion.lenta.count > 0;
});
</script>

<template>
    <!-- Skeleton Loading -->
    <div v-if="isLoading" class="bg-white dark:bg-slate-800 p-5 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm animate-pulse">
        <div class="flex items-center gap-3 mb-4">
            <div class="h-10 w-10 bg-slate-200 dark:bg-slate-700 rounded-xl"></div>
            <div>
                <div class="h-4 w-32 bg-slate-200 dark:bg-slate-700 rounded mb-1"></div>
                <div class="h-3 w-20 bg-slate-200 dark:bg-slate-700 rounded"></div>
            </div>
        </div>
        <div class="h-8 w-2/3 bg-slate-200 dark:bg-slate-700 rounded mb-6"></div>
        <div class="h-2 w-full bg-slate-200 dark:bg-slate-700 rounded mb-2"></div>
        <div class="h-2 w-3/4 bg-slate-200 dark:bg-slate-700 rounded"></div>
    </div>

    <!-- Empty/No Data State -->
    <div v-else-if="!health" class="bg-slate-50 dark:bg-slate-800/50 p-5 rounded-2xl border border-slate-200 dark:border-slate-700 flex flex-col items-center justify-center text-center gap-3">
        <PackageSearch :size="32" class="text-slate-400" />
        <p class="text-sm text-slate-500 dark:text-slate-400">Datos de inventario no disponibles</p>
    </div>

    <!-- Active Widget -->
    <button
        v-else
        @click="goToInventory"
        class="w-full text-left bg-white dark:bg-slate-800 p-5 rounded-2xl border transition-all active:scale-[0.98] shadow-sm hover:border-slate-300 dark:hover:border-slate-600 group"
        :class="{
            'border-red-200 dark:border-red-900/40': statusColor === 'red',
            'border-green-200 dark:border-green-900/40': statusColor === 'green' || statusColor === 'emerald',
            'border-amber-200 dark:border-amber-900/40': statusColor === 'amber',
            'border-slate-100 dark:border-slate-700': statusColor === 'slate'
        }"
    >
        <div class="flex items-start justify-between mb-4">
            <div class="flex items-center gap-3">
                <div class="p-2.5 rounded-xl"
                    :class="{
                        'bg-red-100 text-red-600 dark:bg-red-900/30 dark:text-red-400': statusColor === 'red',
                        'bg-green-100 text-green-600 dark:bg-green-900/30 dark:text-green-400': statusColor === 'green',
                        'bg-emerald-100 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-400': statusColor === 'emerald',
                        'bg-amber-100 text-amber-600 dark:bg-amber-900/30 dark:text-amber-400': statusColor === 'amber',
                        'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-400': statusColor === 'slate'
                    }">
                    <Activity v-if="statusColor === 'red'" :size="24" />
                    <TrendingUp v-else-if="statusColor === 'green' || statusColor === 'emerald'" :size="24" />
                    <Clock v-else-if="statusColor === 'amber'" :size="24" />
                    <PackageSearch v-else :size="24" />
                </div>
                <div>
                    <h3 class="font-bold text-slate-900 dark:text-white leading-tight">Salud de Inventario</h3>
                    <p class="text-[10px] font-semibold uppercase tracking-wider mt-0.5"
                        :class="`text-${statusColor}-600 dark:text-${statusColor}-400`">
                        {{ statusLabel }}
                    </p>
                </div>
            </div>
            <ArrowRight :size="20" class="text-slate-400 opacity-50 group-hover:opacity-100 transition-opacity" />
        </div>

        <div class="mb-5">
            <p class="text-3xl font-black tracking-tight" :class="`text-${statusColor}-700 dark:text-${statusColor}-300`">
                {{ health.dias_inventario }} <span class="text-lg font-medium text-slate-500 dark:text-slate-400 tracking-normal ml-1">días restan</span>
            </p>
            <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">
                Stock valorado en <span class="font-bold text-slate-700 dark:text-slate-300">${{ formatCurrency(health.valor_total) }}</span>
            </p>
        </div>

        <!-- Distribution bar -->
        <div class="space-y-2">
            <div class="flex justify-between text-[10px] font-semibold text-slate-400 uppercase tracking-wide">
                <span>Rápida: {{ health.distribucion_rotacion.rapida.porcentaje }}%</span>
                <span>Normal: {{ health.distribucion_rotacion.normal.porcentaje }}%</span>
                <span>Lenta: {{ health.distribucion_rotacion.lenta.porcentaje }}%</span>
            </div>
            
            <div class="flex h-2.5 w-full rounded-full overflow-hidden bg-slate-100 dark:bg-slate-800/50">
                <div class="bg-emerald-500 transition-all duration-500" :style="{ width: `${health.distribucion_rotacion.rapida.porcentaje}%` }"></div>
                <div class="bg-blue-400 transition-all duration-500" :style="{ width: `${health.distribucion_rotacion.normal.porcentaje}%` }"></div>
                <div class="bg-amber-500 transition-all duration-500" :style="{ width: `${health.distribucion_rotacion.lenta.porcentaje}%` }"></div>
            </div>
            
            <div class="flex justify-between text-xs text-slate-500 dark:text-slate-400 mt-1">
                <span>{{ health.distribucion_rotacion.rapida.count }} prods</span>
                <span v-if="hasCriticalItems" class="flex items-center gap-1 text-amber-600 dark:text-amber-400 font-medium whitespace-nowrap">
                    <AlertTriangle :size="12" />
                    {{ health.distribucion_rotacion.lenta.count }} estancados
                </span>
                <span v-else>{{ health.distribucion_rotacion.lenta.count }} prods</span>
            </div>
        </div>
    </button>
</template>

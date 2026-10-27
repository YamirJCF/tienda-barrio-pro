<template>
  <BaseModal 
    v-model="isOpen" 
    :title="productName ? `Kardex: ${productName}` : 'Historial de Movimientos'"
    max-height="90vh"
    :show-close-button="true"
  >
    <div class="p-4 space-y-4">
      <!-- Stitch Mobile Controls Bar (FRD-006 / SDD-006 / SDD-028) -->
      <div class="space-y-3 pb-1 border-b border-gray-100 dark:border-slate-800">
        <!-- Row 1: Segmented Time Window Pills & Cache Pill -->
        <div class="flex items-center justify-between gap-2">
          <div class="inline-flex p-1 bg-gray-100 dark:bg-slate-900 rounded-full border border-gray-200 dark:border-slate-800">
            <button
              v-for="preset in datePresets"
              :key="preset.value"
              type="button"
              @click="datePreset = preset.value"
              class="px-3 py-1 rounded-full text-xs font-semibold transition-all cursor-pointer active:scale-95"
              :class="datePreset === preset.value
                ? 'bg-primary text-white shadow-sm shadow-primary/25 font-bold'
                : 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white'"
            >
              {{ preset.label }}
            </button>
          </div>

          <span class="px-2 py-0.5 rounded-full bg-slate-100 dark:bg-slate-800 text-[10px] font-mono font-medium text-slate-500 dark:text-slate-400 border border-gray-200 dark:border-slate-700/60">
            LRU Nivel 5
          </span>
        </div>

        <!-- Row 2: Scrollable Movement Type Ribbon -->
        <div class="flex gap-1.5 overflow-x-auto py-1 [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]">
          <button
            v-for="type in movementTypes"
            :key="type.value"
            type="button"
            @click="selectedMovementType = type.value"
            class="px-3 py-1 rounded-full text-xs font-semibold whitespace-nowrap transition-all shrink-0 cursor-pointer active:scale-95"
            :class="selectedMovementType === type.value
              ? 'bg-slate-900 dark:bg-white text-white dark:text-slate-900 shadow-sm font-bold'
              : 'bg-gray-100 dark:bg-slate-800/80 text-slate-600 dark:text-slate-300 border border-gray-200 dark:border-slate-700/60 hover:border-slate-400'"
          >
            {{ type.label }}
          </button>
        </div>
      </div>

      <!-- Loading State -->
      <div v-if="loading" class="flex flex-col items-center justify-center py-10 text-gray-400 space-y-2">
        <div class="w-8 h-8 rounded-full border-2 border-primary border-t-transparent animate-spin"></div>
        <span class="text-xs text-slate-400 font-medium">Consultando movimientos bajo Nivel 5 LRU...</span>
      </div>

      <!-- Error State -->
      <div v-else-if="errorMessage" class="bg-red-50 dark:bg-red-950/40 border border-red-200 dark:border-red-800/60 rounded-2xl p-4 text-center">
        <p class="text-xs font-semibold text-red-600 dark:text-red-400 mb-1">Error al cargar historial</p>
        <p class="text-[11px] text-slate-600 dark:text-slate-300 mb-3">{{ errorMessage }}</p>
        <button 
          @click="loadHistory" 
          class="text-xs px-4 py-1.5 bg-red-600 hover:bg-red-700 text-white rounded-full font-semibold transition-colors active:scale-95 shadow-sm"
        >
          Reintentar
        </button>
      </div>

      <!-- Empty State -->
      <div v-else-if="movements.length === 0" class="text-center py-10">
        <div class="w-12 h-12 rounded-2xl bg-gray-100 dark:bg-slate-800/80 text-slate-400 flex items-center justify-center mx-auto mb-3">
          <History :size="24" :stroke-width="1.5" />
        </div>
        <p class="text-sm font-semibold text-slate-800 dark:text-white">No hay movimientos registrados</p>
        <p class="text-xs text-slate-400 mt-1">Prueba seleccionando una ventana temporal más amplia.</p>
      </div>

      <!-- History List -->
      <div v-else class="space-y-2.5">
        <div class="flex justify-between items-center text-xs text-slate-400 px-1">
          <span class="font-medium">Mostrando {{ movements.length }} movimientos</span>
        </div>
        <div 
          v-for="move in movements" 
          :key="move.id"
          class="bg-white dark:bg-slate-800/80 rounded-2xl p-3.5 border border-gray-100 dark:border-slate-700/60 shadow-soft items-start gap-3 flex transition-all"
        >
          <!-- Icon based on type -->
          <div 
            class="w-9 h-9 rounded-xl shrink-0 flex items-center justify-center"
            :class="getTypeBgColor(move.type)"
          >
            <component :is="getTypeLucideIcon(move.type)" :size="16" :stroke-width="2.2" :class="getTypeIconColor(move.type)" />
          </div>
          
          <div class="flex-1 min-w-0">
            <div class="flex justify-between items-start gap-2">
              <div>
                <p class="text-sm font-bold text-slate-900 dark:text-white capitalize">{{ move.type }}</p>
                <p class="text-xs text-slate-400">{{ formatDate(move.date) }}</p>
              </div>
              <div class="text-right shrink-0">
                <span 
                  class="font-mono font-bold text-sm block"
                  :class="getQuantityColor(move.type)"
                >
                  {{ formatQuantity(move.type, move.quantity) }}
                </span>
                <p class="text-[10px] text-slate-400 dark:text-slate-500 font-mono uppercase tracking-wide">{{ move.user }}</p>
              </div>
            </div>
            
            <!-- Reason / Details -->
            <p v-if="move.reason" class="mt-2 text-xs text-slate-600 dark:text-slate-300 bg-gray-50 dark:bg-slate-900/60 px-2.5 py-1.5 rounded-xl border border-gray-100 dark:border-slate-800/80 italic">
              "{{ move.reason }}"
            </p>
          </div>
        </div>
      </div>
    </div>
  </BaseModal>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import BaseModal from '../ui/BaseModal.vue';
import { productRepository, MovementHistoryFilters } from '../../data/repositories/productRepository';
import {
  ArrowDownLeft,
  ArrowUpRight,
  ShoppingCart,
  RotateCcw,
  Trash2,
  Sliders,
  Wrench,
  HelpCircle,
  History
} from 'lucide-vue-next';

const props = defineProps<{
  modelValue: boolean;
  productId: string | null;
  productName: string | null;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
}>();

const isOpen = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
});

const loading = ref(false);
const errorMessage = ref<string | null>(null);
const movements = ref<any[]>([]);

// Filter states
const selectedMovementType = ref('all');
const datePreset = ref<'7d' | '30d' | 'all'>('7d');

const datePresets = [
  { value: '7d', label: '7 días' },
  { value: '30d', label: '30 días' },
  { value: 'all', label: 'Histórico' }
] as const;

const movementTypes = [
  { value: 'all', label: 'Todos' },
  { value: 'entrada', label: 'Entradas' },
  { value: 'salida', label: 'Salidas' },
  { value: 'venta', label: 'Ventas' },
  { value: 'merma', label: 'Mermas' },
  { value: 'ajuste', label: 'Ajustes' },
  { value: 'devolucion', label: 'Devoluciones' },
  { value: 'CORRECCION_SISTEMA', label: 'Correcciones' }
];

const calculateStartDate = (preset: '7d' | '30d' | 'all'): string | undefined => {
  const now = Date.now();
  if (preset === '7d') {
    return new Date(now - 7 * 24 * 60 * 60 * 1000).toISOString();
  }
  if (preset === '30d') {
    return new Date(now - 30 * 24 * 60 * 60 * 1000).toISOString();
  }
  return undefined;
};

const loadHistory = async () => {
  if (!props.productId) return;
  
  loading.value = true;
  errorMessage.value = null;
  movements.value = [];
  
  try {
    const filters: MovementHistoryFilters = {
      movementType: selectedMovementType.value !== 'all' ? selectedMovementType.value : undefined,
      startDate: calculateStartDate(datePreset.value),
      limit: 50
    };

    const history = await productRepository.getMovementHistory(props.productId, filters);
    movements.value = history;
  } catch (e: any) {
    errorMessage.value = e?.message || 'Error al recuperar movimientos de Kardex';
    console.error('Error loading history', e);
  } finally {
    loading.value = false;
  }
};

// Re-fetch when modal opens or filters change
watch(() => props.modelValue, (val) => {
  if (val && props.productId) {
    loadHistory();
  }
});

watch([selectedMovementType, datePreset], () => {
  if (props.modelValue && props.productId) {
    loadHistory();
  }
});

// Helpers
const formatDate = (dateStr: string) => {
  return new Date(dateStr).toLocaleString('es-CO', {
    day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit'
  });
};

const getTypeLucideIcon = (type: string) => {
  switch (type) {
    case 'entrada': return ArrowDownLeft;
    case 'salida': return ArrowUpRight;
    case 'venta': return ShoppingCart;
    case 'devolucion': return RotateCcw;
    case 'merma': return Trash2;
    case 'ajuste': return Sliders;
    case 'CORRECCION_SISTEMA': return Wrench;
    default: return HelpCircle;
  }
};

const getTypeBgColor = (type: string) => {
  switch (type) {
    case 'entrada': return 'bg-emerald-500/15';
    case 'salida': return 'bg-rose-500/15';
    case 'venta': return 'bg-blue-500/15';
    case 'devolucion': return 'bg-purple-500/15';
    case 'merma': return 'bg-orange-500/15';
    case 'ajuste': return 'bg-amber-500/15';
    case 'CORRECCION_SISTEMA': return 'bg-cyan-500/15';
    default: return 'bg-gray-500/15';
  }
};

const getTypeIconColor = (type: string) => {
  switch (type) {
    case 'entrada': return 'text-emerald-500';
    case 'salida': return 'text-rose-500';
    case 'venta': return 'text-blue-500';
    case 'devolucion': return 'text-purple-500';
    case 'merma': return 'text-orange-500';
    case 'ajuste': return 'text-amber-500';
    case 'CORRECCION_SISTEMA': return 'text-cyan-500';
    default: return 'text-gray-500';
  }
};

const getQuantityColor = (type: string) => {
  if (type === 'entrada' || type === 'devolucion') return 'text-emerald-600 dark:text-emerald-400';
  if (type === 'salida' || type === 'venta' || type === 'merma') return 'text-rose-600 dark:text-rose-400';
  return 'text-amber-600 dark:text-amber-400';
};

const formatQuantity = (type: string, qty: number) => {
  const sign = (type === 'entrada' || type === 'devolucion') ? '+' : '-';
  if (type === 'ajuste' || type === 'CORRECCION_SISTEMA') return qty > 0 ? `+${qty}` : `${qty}`;
  return `${sign}${qty}`;
};
</script>

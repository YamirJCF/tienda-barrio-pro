<template>
  <BaseModal 
    v-model="isOpen" 
    :title="productName ? `Kardex: ${productName}` : 'Historial de Movimientos'"
    max-height="90vh"
    :show-close-button="true"
  >
    <div class="p-4 space-y-4">
      <!-- Filter Controls (FRD-006 / SDD-006 / SDD-028) -->
      <div class="bg-gray-100 dark:bg-gray-800/60 p-3 rounded-xl space-y-2 border border-gray-200 dark:border-gray-700">
        <div class="flex items-center justify-between text-xs font-semibold text-slate-500 uppercase tracking-wider">
          <span>Filtros de Auditoría</span>
          <span class="text-[11px] text-slate-400 font-normal">Caché LRU Nivel 5</span>
        </div>

        <div class="grid grid-cols-2 gap-2">
          <!-- Movement Type Filter -->
          <div>
            <label class="block text-[11px] text-slate-600 dark:text-slate-300 mb-1 font-medium">Tipo</label>
            <select 
              v-model="selectedMovementType"
              class="w-full text-xs rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-slate-800 dark:text-white px-2 py-1.5 focus:ring-2 focus:ring-primary focus:outline-none"
            >
              <option value="all">Todos los movimientos</option>
              <option value="entrada">Entradas (+)</option>
              <option value="salida">Salidas (-)</option>
              <option value="venta">Ventas (-)</option>
              <option value="merma">Mermas (-)</option>
              <option value="ajuste">Ajustes</option>
              <option value="devolucion">Devoluciones (+)</option>
              <option value="CORRECCION_SISTEMA">Corrección de Sistema</option>
            </select>
          </div>

          <!-- Date Range Preset -->
          <div>
            <label class="block text-[11px] text-slate-600 dark:text-slate-300 mb-1 font-medium">Ventana Temporal</label>
            <select 
              v-model="datePreset"
              class="w-full text-xs rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-slate-800 dark:text-white px-2 py-1.5 focus:ring-2 focus:ring-primary focus:outline-none"
            >
              <option value="7d">Últimos 7 días (Default)</option>
              <option value="30d">Últimos 30 días</option>
              <option value="all">Todo el historial</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Loading State -->
      <div v-if="loading" class="flex flex-col items-center justify-center py-8 text-gray-400">
        <span class="material-icons animate-spin text-3xl mb-2">refresh</span>
        <span class="text-sm">Consultando movimientos bajo Nivel 5 LRU...</span>
      </div>

      <!-- Error State -->
      <div v-else-if="errorMessage" class="bg-red-50 dark:bg-red-950/40 border border-red-200 dark:border-red-800 rounded-xl p-4 text-center">
        <p class="text-xs font-semibold text-red-600 dark:text-red-400 mb-1">Error al cargar historial</p>
        <p class="text-[11px] text-slate-600 dark:text-slate-300 mb-3">{{ errorMessage }}</p>
        <button 
          @click="loadHistory" 
          class="text-xs px-3 py-1 bg-red-600 hover:bg-red-700 text-white rounded-lg font-medium transition-colors"
        >
          Reintentar
        </button>
      </div>

      <!-- Empty State -->
      <div v-else-if="movements.length === 0" class="text-center py-8 text-gray-400">
        <span class="material-icons text-3xl mb-2">history_edu</span>
        <p class="text-sm font-medium">No hay movimientos registrados.</p>
        <p class="text-xs text-gray-500 mt-1">Prueba seleccionando una ventana temporal más amplia.</p>
      </div>

      <!-- History List -->
      <div v-else class="space-y-3">
        <div class="flex justify-between items-center text-xs text-slate-400 px-1">
          <span>Mostrando {{ movements.length }} movimientos</span>
        </div>
        <div 
          v-for="move in movements" 
          :key="move.id"
          class="bg-gray-800/50 rounded-lg p-3 border border-gray-700 items-start gap-3 flex"
        >
          <!-- Icon based on type -->
          <div 
            class="p-2 rounded-full shrink-0"
            :class="getTypeColor(move.type)"
          >
            <span class="material-icons text-sm text-white">{{ getTypeIcon(move.type) }}</span>
          </div>
          
          <div class="flex-1 min-w-0">
            <div class="flex justify-between items-start">
              <div>
                <p class="text-sm font-medium text-white capitalize">{{ move.type }}</p>
                <p class="text-xs text-gray-400">{{ formatDate(move.date) }}</p>
              </div>
              <div class="text-right">
                <span 
                  class="font-mono font-bold text-sm"
                  :class="getQuantityColor(move.type)"
                >
                  {{ formatQuantity(move.type, move.quantity) }}
                </span>
                <p class="text-[10px] text-gray-500 uppercase">{{ move.user }}</p>
              </div>
            </div>
            
            <!-- Reason / Details -->
            <p v-if="move.reason" class="mt-1 text-xs text-gray-300 italic">
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

const getTypeColor = (type: string) => {
  switch (type) {
    case 'entrada': return 'bg-emerald-600';
    case 'salida': return 'bg-rose-600';
    case 'venta': return 'bg-blue-600';
    case 'devolucion': return 'bg-purple-600';
    case 'merma': return 'bg-orange-600';
    case 'ajuste': return 'bg-amber-600';
    case 'CORRECCION_SISTEMA': return 'bg-cyan-600';
    default: return 'bg-gray-600';
  }
};

const getTypeIcon = (type: string) => {
  switch (type) {
    case 'entrada': return 'arrow_downward';
    case 'salida': return 'arrow_upward';
    case 'venta': return 'shopping_cart';
    case 'devolucion': return 'keyboard_return';
    case 'merma': return 'delete_sweep';
    case 'ajuste': return 'tune';
    case 'CORRECCION_SISTEMA': return 'build';
    default: return 'swap_horiz';
  }
};

const getQuantityColor = (type: string) => {
  if (type === 'entrada' || type === 'devolucion') return 'text-emerald-400';
  if (type === 'salida' || type === 'venta' || type === 'merma') return 'text-rose-400';
  return 'text-amber-400';
};

const formatQuantity = (type: string, qty: number) => {
  const sign = (type === 'entrada' || type === 'devolucion') ? '+' : '-';
  if (type === 'ajuste' || type === 'CORRECCION_SISTEMA') return qty > 0 ? `+${qty}` : `${qty}`;
  return `${sign}${qty}`;
};
</script>

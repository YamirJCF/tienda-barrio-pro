<template>
  <BaseModal 
    v-model="isOpen" 
    :title="productName ? `Kardex: ${productName}` : 'Historial de Movimientos'"
    max-height="90vh"
    :show-close-button="true"
  >
    <div class="p-4 space-y-4">
      <!-- Loading State -->
      <div v-if="loading" class="flex flex-col items-center justify-center py-8 text-gray-400">
        <span class="material-icons animate-spin text-3xl mb-2">refresh</span>
        <span class="text-sm">Cargando movimientos...</span>
      </div>

      <!-- Empty State -->
      <div v-else-if="movements.length === 0" class="text-center py-8 text-gray-400">
        <span class="material-icons text-3xl mb-2">history_edu</span>
        <p class="text-sm">No hay movimientos registrados.</p>
      </div>

      <!-- History List -->
      <div v-else class="space-y-3">
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
import { productRepository } from '../../data/repositories/productRepository';

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
const movements = ref<any[]>([]);

const loadHistory = async () => {
  if (!props.productId) return;
  
  loading.value = true;
  movements.value = [];
  
  try {
    const history = await productRepository.getMovementHistory(props.productId);
    movements.value = history;
  } catch (e) {
    console.error('Error loading history', e);
  } finally {
    loading.value = false;
  }
};

watch(() => props.modelValue, (val) => {
  if (val && props.productId) {
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
    case 'ajuste': return 'bg-amber-600';
    default: return 'bg-gray-600';
  }
};

const getTypeIcon = (type: string) => {
    switch (type) {
    case 'entrada': return 'arrow_downward';
    case 'salida': return 'arrow_upward';
    case 'venta': return 'shopping_cart';
    case 'devolucion': return 'keyboard_return';
    case 'ajuste': return 'tune';
    default: return 'swap_horiz';
  }
};

const getQuantityColor = (type: string) => {
  if (type === 'entrada' || type === 'devolucion') return 'text-emerald-400';
  if (type === 'salida' || type === 'venta') return 'text-rose-400';
  return 'text-amber-400';
};

const formatQuantity = (type: string, qty: number) => {
    const sign = (type === 'entrada' || type === 'devolucion') ? '+' : '-';
    // If 'ajuste', it depends? For now assume + if not negative logic
    if (type === 'ajuste') return qty > 0 ? `+${qty}` : `${qty}`;
    return `${sign}${qty}`;
};
</script>

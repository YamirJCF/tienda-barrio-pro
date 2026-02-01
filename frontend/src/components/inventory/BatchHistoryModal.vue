<template>
  <BaseModal
    v-model="modelValue"
    :title="`Historial de Lotes: ${productName}`"
  >
    <div class="space-y-4">
      <!-- Summary Header -->
      <div class="bg-gray-50 dark:bg-gray-800 p-4 rounded-xl flex justify-between items-center">
        <div>
          <p class="text-xs text-gray-500 uppercase">Producto</p>
          <p class="font-bold text-gray-900 dark:text-gray-100">{{ productName }}</p>
        </div>
        <div class="text-right">
          <p class="text-xs text-gray-500 uppercase">Stock Total</p>
          <p class="font-mono text-xl font-bold text-primary">{{ stockTotal }} un</p>
        </div>
      </div>

      <!-- Loading State -->
      <div v-if="batchStore.isLoading" class="py-8 text-center space-y-2">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary mx-auto"></div>
        <p class="text-sm text-gray-500">Cargando lotes...</p>
      </div>

      <!-- Error State -->
      <div v-else-if="batchStore.error" class="bg-red-50 text-red-600 p-4 rounded-xl text-sm">
        {{ batchStore.error }}
      </div>

      <!-- Empty State -->
      <div v-else-if="batchStore.batches.length === 0" class="py-8 text-center text-gray-500">
        No hay registros de lotes para este producto.
      </div>

      <!-- Batches Table -->
      <div v-else class="overflow-x-auto border border-gray-100 dark:border-gray-700 rounded-xl">
        <table class="w-full text-sm text-left">
          <thead class="text-xs uppercase bg-gray-50 dark:bg-gray-800 text-gray-500">
            <tr>
              <th class="px-4 py-3">Fecha</th>
              <th class="px-4 py-3 text-right">Costo Unit.</th>
              <th class="px-4 py-3 text-right">Inicial</th>
              <th class="px-4 py-3 text-right">Restante</th>
              <th class="px-4 py-3 text-center">Estado</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100 dark:divide-gray-700">
            <tr 
              v-for="batch in batchStore.batches" 
              :key="batch.id"
              class="hover:bg-gray-50 dark:hover:bg-gray-800/50 transition-colors"
              :class="{'bg-emerald-50/30': batch.quantity_remaining > 0}"
            >
              <td class="px-4 py-3 text-gray-600 dark:text-gray-300">
                {{ formatDate(batch.created_at) }}
              </td>
              <td class="px-4 py-3 text-right font-mono">
                {{ formatCurrency(batch.cost_unit) }}
              </td>
              <td class="px-4 py-3 text-right text-gray-500">
                {{ batch.quantity_initial }}
              </td>
              <td class="px-4 py-3 text-right font-bold" :class="batch.quantity_remaining > 0 ? 'text-emerald-600' : 'text-gray-400'">
                {{ batch.quantity_remaining }}
              </td>
              <td class="px-4 py-3 text-center">
                 <span 
                   class="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wide"
                   :class="batch.quantity_remaining > 0 
                     ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400' 
                     : 'bg-gray-100 text-gray-500 dark:bg-gray-800 dark:text-gray-400'"
                 >
                   {{ batch.quantity_remaining > 0 ? 'Activo' : 'Agotado' }}
                 </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Explanation Footer -->
      <div class="text-xs text-gray-400 italic text-center pt-2">
        * El sistema FIFO consume primero los lotes más antiguos (Fecha ASC).
      </div>

    </div>

    <template #footer>
      <div class="flex justify-end p-4 pt-0">
        <BaseButton variant="secondary" @click="close">Cerrar</BaseButton>
      </div>
    </template>
  </BaseModal>
</template>

<script setup lang="ts">
import { computed, onMounted, watch } from 'vue';
import { useBatchStore } from '../../stores/batches';
import BaseModal from '../ui/BaseModal.vue';
import BaseButton from '../ui/BaseButton.vue';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';

const props = defineProps<{
  modelValue: boolean;
  productId: string | null;
  productName: string | null;
}>();

const emit = defineEmits(['update:modelValue']);

const batchStore = useBatchStore();
const { formatCurrency } = useCurrencyFormat();

const modelValue = computed({
  get: () => props.modelValue,
  set: (val) => emit('update:modelValue', val)
});

const stockTotal = computed(() => {
  return batchStore.batches.reduce((sum, b) => sum + Number(b.quantity_remaining), 0);
});

// Load batches when modal opens
watch(() => props.modelValue, async (isOpen) => {
  if (isOpen && props.productId) {
    await batchStore.fetchBatchesByProduct(props.productId);
  }
});

const close = () => {
  modelValue.value = false;
};

const formatDate = (dateString: string) => {
  if (!dateString) return '-';
  return new Date(dateString).toLocaleDateString('es-CO', {
    day: '2-digit',
    month: 'short',
    year: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  });
};
</script>

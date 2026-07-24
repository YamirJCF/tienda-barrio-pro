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
      <div v-if="batchStore.isLoading && !editingBatchId" class="py-8 text-center space-y-2">
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
              <th class="px-4 py-3 text-right">Precio Venta</th>
              <th class="px-4 py-3 text-right">Restante/Inic.</th>
              <th class="px-4 py-3 text-center">Estado</th>
              <th class="px-4 py-3 text-center">Acciones</th>
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
              
              <!-- Cost Column -->
              <td class="px-4 py-3 text-right font-mono">
                <template v-if="editingBatchId === batch.id">
                  <input type="number" v-model="editForm.cost_unit" class="w-24 px-2 py-1 text-right text-sm border rounded bg-white dark:bg-gray-900 dark:border-gray-600 focus:ring-primary focus:border-primary" />
                </template>
                <template v-else>
                  {{ formatCurrency(batch.cost_unit) }}
                </template>
              </td>

              <!-- Sale Price Column -->
              <td class="px-4 py-3 text-right font-mono font-medium text-gray-900 dark:text-gray-100">
                <template v-if="editingBatchId === batch.id">
                  <input type="number" v-model="editForm.sale_price" class="w-24 px-2 py-1 text-right text-sm border rounded bg-white dark:bg-gray-900 dark:border-gray-600 focus:ring-primary focus:border-primary" />
                </template>
                <template v-else>
                  {{ formatCurrency(batch.sale_price) }}
                </template>
              </td>

              <!-- Quantity Column -->
              <td class="px-4 py-3 text-right">
                <span class="font-bold" :class="batch.quantity_remaining > 0 ? 'text-emerald-600' : 'text-gray-400'">
                  {{ batch.quantity_remaining }}
                </span>
                <span class="text-gray-400 text-xs ml-1">/ {{ batch.quantity_initial }}</span>
              </td>
              
              <!-- Status Column -->
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

              <!-- Actions Column -->
              <td class="px-4 py-3 text-center">
                <div v-if="batch.quantity_remaining > 0" class="flex justify-center gap-2">
                  <template v-if="editingBatchId === batch.id">
                    <button @click="saveEdit" :disabled="batchStore.isLoading" class="text-emerald-600 hover:text-emerald-800 disabled:opacity-50">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-5 h-5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                      </svg>
                    </button>
                    <button @click="cancelEdit" :disabled="batchStore.isLoading" class="text-red-500 hover:text-red-700 disabled:opacity-50">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" class="w-5 h-5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </template>
                  <template v-else>
                    <button @click="startEdit(batch)" class="text-gray-400 hover:text-primary transition-colors">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L6.832 19.82a4.5 4.5 0 01-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 011.13-1.897L16.863 4.487zm0 0L19.5 7.125" />
                      </svg>
                    </button>
                  </template>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Explanation Footer -->
      <div class="text-xs text-gray-400 italic text-center pt-2">
        * El sistema FIFO consume primero los lotes más antiguos (Fecha ASC). Solo se pueden editar lotes activos.
      </div>

    </div>

    <template #footer>
      <div class="flex justify-end p-4 pt-0">
        <BaseButton variant="secondary" @click="close" :disabled="batchStore.isLoading">Cerrar</BaseButton>
      </div>
    </template>
  </BaseModal>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue';
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

const editingBatchId = ref<string | null>(null);
const editForm = ref({ cost_unit: 0, sale_price: 0 });

const modelValue = computed({
  get: () => props.modelValue,
  set: (val) => {
    if (!batchStore.isLoading) {
      emit('update:modelValue', val);
    }
  }
});

const stockTotal = computed(() => {
  return batchStore.batches.reduce((sum, b) => sum + Number(b.quantity_remaining), 0);
});

// Load batches when modal opens
watch(() => props.modelValue, async (isOpen) => {
  if (isOpen && props.productId) {
    editingBatchId.value = null;
    await batchStore.fetchBatchesByProduct(props.productId);
  }
});

const startEdit = (batch: any) => {
  editingBatchId.value = batch.id;
  editForm.value = {
    cost_unit: Number(batch.cost_unit) || 0,
    sale_price: Number(batch.sale_price) || 0
  };
};

const cancelEdit = () => {
  editingBatchId.value = null;
};

const saveEdit = async () => {
  if (!editingBatchId.value) return;
  const res = await batchStore.updateBatchPrice(editingBatchId.value, editForm.value.cost_unit, editForm.value.sale_price);
  if (res.success) {
    editingBatchId.value = null;
  } else {
    alert(res.error || 'No se pudo actualizar el lote');
  }
};

const close = () => {
  if (!batchStore.isLoading) {
    modelValue.value = false;
  }
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

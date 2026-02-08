<template>
  <div v-if="isOpen" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
    <div class="bg-white rounded-xl shadow-2xl w-full max-w-2xl overflow-hidden flex flex-col max-h-[90vh]">
      
      <!-- Header -->
      <div class="bg-red-50 p-4 border-b border-red-100 flex justify-between items-center">
        <div class="flex items-center gap-3">
          <div class="p-2 bg-red-100 rounded-lg">
            <i class="material-icons text-red-600">error_outline</i>
          </div>
          <div>
            <h3 class="text-lg font-bold text-red-900">Conflictos de Sincronización</h3>
            <p class="text-xs text-red-700">Estas operaciones fallaron y requieren tu atención</p>
          </div>
        </div>
        <button @click="close" class="p-2 hover:bg-red-100 rounded-full text-red-700 transition-colors">
          <i class="material-icons">close</i>
        </button>
      </div>

      <!-- List -->
      <div class="flex-1 overflow-y-auto p-4 space-y-3 bg-gray-50">
        <div v-if="loading" class="text-center py-8 text-gray-400">
          <i class="material-icons animate-spin text-3xl">sync</i>
          <p class="mt-2 text-sm">Cargando conflictos...</p>
        </div>

        <div v-else-if="items.length === 0" class="text-center py-12 flex flex-col items-center">
          <div class="p-4 bg-green-100 rounded-full mb-3">
            <i class="material-icons text-green-600 text-3xl">check_circle</i>
          </div>
          <h4 class="text-gray-900 font-medium">Todo en orden</h4>
          <p class="text-gray-500 text-sm mt-1">No hay conflictos pendientes de resolución.</p>
        </div>

        <div v-else v-for="item in items" :key="item.id" 
             class="bg-white rounded-lg border border-gray-200 shadow-sm p-4 hover:shadow-md transition-shadow">
          
          <!-- Item Header -->
          <div class="flex justify-between items-start mb-3">
            <div class="flex items-center gap-2">
              <span class="px-2 py-1 rounded text-xs font-bold bg-gray-100 text-gray-600">
                {{ formatType(item.type) }}
              </span>
              <span class="text-xs text-gray-400">
                {{ formatDate(item.timestamp) }}
              </span>
            </div>
            <!-- ID for debug -->
            <span class="text-[10px] text-gray-300 font-mono">{{ item.id.slice(0, 8) }}...</span>
          </div>

          <!-- Error Content -->
          <div class="bg-red-50 border border-red-100 rounded p-3 mb-4">
            <p class="text-sm text-red-800 font-medium flex items-start gap-2">
              <i class="material-icons text-base mt-0.5">warning</i>
              {{ item.error || 'Error desconocido' }}
            </p>
          </div>

          <!-- Actions -->
          <div class="flex gap-2 justify-end pt-2 border-t border-gray-50">
            <button @click="deleteItem(item.id)" 
                    class="px-3 py-1.5 text-sm rounded-lg flex items-center gap-1 transition-all duration-200"
                    :class="confirmDeleteId === item.id 
                      ? 'bg-red-600 text-white hover:bg-red-700 font-bold' 
                      : 'text-red-600 hover:bg-red-50'">
              <i class="material-icons text-base">{{ confirmDeleteId === item.id ? 'check' : 'delete' }}</i>
              {{ confirmDeleteId === item.id ? '¿Confirmar?' : 'Eliminar' }}
            </button>
            <button @click="retryItem(item.id)" 
                    class="px-4 py-1.5 text-sm bg-blue-600 text-white hover:bg-blue-700 rounded-lg shadow-sm flex items-center gap-1 transition-colors">
              <i class="material-icons text-base">refresh</i>
              Reintentar
            </button>
            <!-- Force Sale Button (Admin Only, Stock Errors) - FRD-014 -->
            <button v-if="isStockError(item) && isAdmin" 
                    @click="handleForceSale(item)" 
                    class="px-4 py-1.5 text-sm bg-amber-600 text-white hover:bg-amber-700 rounded-lg shadow-sm flex items-center gap-1 transition-colors">
              <i class="material-icons text-base">shield_alert</i>
              Forzar Venta
            </button>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div v-if="items.length > 0" class="p-4 bg-white border-t border-gray-100 text-xs text-gray-500 flex justify-between items-center">
        <span>{{ items.length }} conflicto(s) pendiente(s)</span>
        <div class="flex gap-2">
           <span class="flex items-center gap-1">
             <i class="material-icons text-sm">info</i>
             Reintentar mueve el item a la cola de sincronización
           </span>
        </div>
      </div>

    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch, computed } from 'vue';
import { useDataSource } from '../../composables/useDataSource';
import syncQueue, { QueueItem } from '../../data/syncQueue';
import ForceSaleModal from '../ForceSaleModal.vue';
import { useAuthStore } from '../../stores/auth';

const props = defineProps<{
  isOpen: boolean;
}>();

const emit = defineEmits(['close', 'resolved']);

const authStore = useAuthStore();
const isAdmin = computed(() => authStore.isAdmin);

const items = ref<any[]>([]);
const loading = ref(false);

// Force Sale State (FRD-014)
const showForceSaleModal = ref(false);
const forceSaleItems = ref<any[]>([]);
const pendingDLQItem = ref<any | null>(null);

const loadItems = async () => {
    if (!props.isOpen) return;
    loading.value = true;
    try {
        items.value = await syncQueue.getDLQItems();
    } catch (e) {
        console.error('Failed to load DLQ items', e);
    } finally {
        loading.value = false;
    }
};

const formatType = (type: string) => {
    const map: Record<string, string> = {
        'CREATE_SALE': 'Venta',
        'CREATE_CLIENT': 'Cliente',
        'CREATE_MOVEMENT': 'Inventario'
    };
    return map[type] || type;
};

const formatDate = (ts: number) => {
    return new Date(ts).toLocaleString();
};

const confirmDeleteId = ref<string | null>(null);

const deleteItem = async (id: string) => {
    if (confirmDeleteId.value === id) {
        // Confirmed
        try {
            await syncQueue.deleteDLQItem(id);
            await loadItems();
            emit('resolved');
            confirmDeleteId.value = null;
        } catch (e) {
            console.error('Failed to delete item', e);
            alert('Error al eliminar el item');
        }
    } else {
        // First click
        confirmDeleteId.value = id;
        // Auto-reset after 3 seconds
        setTimeout(() => {
            if (confirmDeleteId.value === id) confirmDeleteId.value = null;
        }, 3000);
    }
};

const retryItem = async (id: string) => {
    try {
        await syncQueue.retryDLQItem(id);
        await loadItems();
        
        // Trigger generic sync attempt if online
        const { processSyncQueue } = await import('../../data/syncQueue');
        processSyncQueue(); 
        
        emit('resolved');
        emit('close'); // Close on retry to let user see sync happening
    } catch (e) {
        console.error('Failed to retry item', e);
        alert('Error al reintentar el item');
    }
};

const close = () => {
    emit('close');
};

// Force Sale Handlers (FRD-014)
const isStockError = (item: any): boolean => {
  if (!item.error) return false;
  const errorMsg = item.error.toLowerCase();
  return errorMsg.includes('stock insuficiente') || errorMsg.includes('insufficient');
};

const handleForceSale = (item: any) => {
  // Parse the sale payload from DLQ item
  const salePayload = item.payload;
  
  // Calculate deficit from sale items
  if (salePayload && salePayload.items) {
    forceSaleItems.value = salePayload.items.map((saleItem: any) => {
      // Assume stock deficit exists since it's in DLQ with stock error
      return {
        product_id: saleItem.productId,
        name: saleItem.productName,
        quantity: saleItem.quantity,
        deficit: saleItem.quantity // Simplified - assuming full deficit for DLQ items
      };
    });
    
    pendingDLQItem.value = item;
    showForceSaleModal.value = true;
  }
};

const handleForceSaleConfirm = async (justification: string) => {
  if (!pendingDLQItem.value) return;

  try {
    const { useSalesStore } = await import('../../stores/sales');
    const salesStore = useSalesStore();
    
    const salePayload = pendingDLQItem.value.payload;
    
    // Call Force Sale with justification
    const result = await salesStore.forceSale({
      items: salePayload.items.map((item: any) => ({
        productId: item.productId,
        productName: item.productName,
        quantity: Number(item.quantity),
        price: item.price,
        subtotal: item.subtotal
      })),
      total: salePayload.total,
      paymentMethod: salePayload.paymentMethod || 'efectivo',
      clientId: salePayload.clientId,
    }, salePayload.storeId, justification);

    if (result.success) {
      // Remove from DLQ
      await syncQueue.deleteDLQItem(pendingDLQItem.value.id);
      await loadItems();
      emit('resolved');
      
      // Close modal
      showForceSaleModal.value = false;
      pendingDLQItem.value = null;
      forceSaleItems.value = [];
    } else {
      alert(`Error al forzar venta: ${result.error}`);
    }
  } catch (e: any) {
    console.error('Force sale failed', e);
    alert(`Error: ${e.message}`);
  }
};

const handleForceSaleCancel = () => {
  showForceSaleModal.value = false;
  pendingDLQItem.value = null;
  forceSaleItems.value = [];
};

// Watch for open prop to reload data
watch(() => props.isOpen, (newVal) => {
    if (newVal) {
        loadItems();
    }
});
</script>

<!-- Force Sale Modal (FRD-014) -->
<ForceSaleModal 
  :is-open="showForceSaleModal"
  :items="forceSaleItems"
  @confirm="handleForceSaleConfirm"
  @cancel="handleForceSaleCancel"
/>

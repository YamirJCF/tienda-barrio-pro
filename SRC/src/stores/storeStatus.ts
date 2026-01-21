import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

/**
 * Store para el estado OPERATIVO de la tienda.
 * Diferente del estado de la CAJA (salesStore.isStoreOpen).
 *
 * - isOperational: La tienda está disponible para operar (ventas, etc.)
 * - Cerrar Tienda: Bloquea ventas nuevas, marca tienda como "fuera de servicio"
 */
export const useStoreStatusStore = defineStore(
  'storeStatus',
  () => {
    // Estado operativo de la tienda (diferente de la caja)
    const isOperational = ref(true);
    const closedReason = ref('');
    const closedAt = ref<string | null>(null);

    // Computed
    const isClosed = computed(() => !isOperational.value);

    // Methods
    const closeStore = (reason: string = 'Cierre temporal') => {
      isOperational.value = false;
      closedReason.value = reason;
      closedAt.value = new Date().toISOString();
    };

    const openStore = () => {
      isOperational.value = true;
      closedReason.value = '';
      closedAt.value = null;
    };

    const toggleStatus = () => {
      if (isOperational.value) {
        closeStore();
      } else {
        openStore();
      }
    };

    return {
      isOperational,
      closedReason,
      closedAt,
      isClosed,
      closeStore,
      openStore,
      toggleStatus,
    };
  },
  {
    persist: {
      key: 'tienda-store-status',
      storage: localStorage,
    },
  },
);

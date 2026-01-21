import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { cashRepository } from '../data/repositories/cashRepository';
import { useAuthStore } from './auth';
import { logger } from '../utils/logger';

/**
 * Store para el estado OPERATIVO de la tienda (Caja).
 * Conectado con bases de datos reales vía cashRepository.
 */
export const useStoreStatusStore = defineStore(
  'storeStatus',
  () => {
    // Estado
    const isOperational = ref(false); // Default closed until checked
    const openingAmount = ref(0);
    const lastEvent = ref<any>(null);
    const isLoading = ref(false);

    // Computed
    const isClosed = computed(() => !isOperational.value);

    // Init: Check status from DB/Local
    const initialize = async () => {
      const authStore = useAuthStore();
      if (!authStore.currentUser?.storeId) return;

      isLoading.value = true;
      try {
        const status = await cashRepository.getStoreStatus(authStore.currentUser.storeId);
        isOperational.value = status.isOpen;
        openingAmount.value = status.openingAmount;
        lastEvent.value = status.lastEvent;
      } catch (e) {
        logger.error('[StoreStatus] Init failed', e);
      } finally {
        isLoading.value = false;
      }
    };

    // Actions
    const openStore = async (amount: number, pin: string) => {
      const authStore = useAuthStore();
      if (!authStore.currentUser) throw new Error('No user logged in');

      // Verify PIN locally or via AuthStore helper if needed?
      // For now, allow open if authenticated as admin/employee with permission
      // The repository RPC will validate further if logical constraints exist

      const result = await cashRepository.registerEvent({
        store_id: authStore.currentUser.storeId,
        type: 'open',
        amount_declared: amount,
        authorized_by_id: authStore.currentUser.id,
        authorized_by_name: authStore.currentUser.name,
        authorized_by_type: authStore.currentUser.type as 'admin' | 'employee'
      });

      if (result.success) {
        isOperational.value = true;
        openingAmount.value = amount;
        return true;
      } else {
        throw new Error(result.error);
      }
    };

    const closeStore = async (countedAmount: number) => {
      const authStore = useAuthStore();
      if (!authStore.currentUser) throw new Error('No user logged in');

      const result = await cashRepository.registerEvent({
        store_id: authStore.currentUser.storeId,
        type: 'close',
        amount_declared: countedAmount,
        authorized_by_id: authStore.currentUser.id,
        authorized_by_name: authStore.currentUser.name,
        authorized_by_type: authStore.currentUser.type as 'admin' | 'employee'
      });

      if (result.success) {
        isOperational.value = false;
        openingAmount.value = 0;
        return result.data; // May return difference/expected info
      } else {
        throw new Error(result.error);
      }
    };

    return {
      isOperational,
      isClosed,
      openingAmount,
      isLoading,
      initialize,
      openStore,
      closeStore
    };
  },
  {
    // Persist basic status to avoid flicker on reload before async check
    persist: {
      key: 'tienda-store-status-v2',
      storage: localStorage,
    },
  },
);

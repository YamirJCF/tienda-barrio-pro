import { ref, onUnmounted } from 'vue';
import { useNotifications } from './useNotifications';

interface AsyncActionOptions {
  successMessage?: string;
  errorMessage?: string;
  showSuccessToast?: boolean;
  timeoutMs?: number;
  /**
   * If true, blocks execution if device is offline.
   * Set to false for Offline-First actions that handle their own sync.
   * @default true
   */
  checkConnectivity?: boolean;
}

export function useAsyncAction() {
  const isLoading = ref(false);
  const { showSuccess, showError, showWarning } = useNotifications();

  // Guard to prevent state updates on unmounted component
  let isMounted = true;
  onUnmounted(() => {
    isMounted = false;
  });

  const execute = async <T>(
    action: () => Promise<T>,
    options: AsyncActionOptions = {}
  ): Promise<T | null> => {
    const {
      successMessage,
      errorMessage = 'Ocurrió un error inesperado',
      showSuccessToast = true,
      timeoutMs = 15000,
      checkConnectivity = true,
    } = options;

    // 1. Resilience: Offline Check
    if (checkConnectivity && !navigator.onLine) {
      showWarning('Sin conexión a internet', 'wifi_off');
      return null;
    }

    // 2. Race Condition / Interaction Blocking
    if (isLoading.value) return null;

    isLoading.value = true;

    try {
      // 3. Resilience: Timeout Race
      const timeoutPromise = new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error('TIMEOUT_ERROR')), timeoutMs)
      );

      const result = await Promise.race([action(), timeoutPromise]);

      if (isMounted) {
        if (showSuccessToast && successMessage) {
          showSuccess(successMessage);
        }
      }
      return result;
    } catch (error: any) {
      if (!isMounted) return null;

      console.error('[AsyncAction Error]', error);

      // 4. Semantic Error Handling
      if (error.message === 'TIMEOUT_ERROR') {
        showError('El servidor tarda demasiado en responder', 'timer_off');
      } else if (
        error.message?.includes('fetch') ||
        error.message?.includes('network') ||
        error.code === 'PGRST301'
      ) {
        // Only show connectivity error if we were checking for it OR if it actually failed network-wise
        // But if checkConnectivity=false, maybe we swallow this? 
        // No, if the action *tried* to fetch and failed, we should still report it unless the action itself catches it.
        // For Offline-first, the action should ideally NOT throw network errors but queue locally.
        showError('Error de conexión con el servidor', 'wifi_off');
      } else {
        // Business logic or validation error
        showError(error.message || errorMessage || 'Error desconocido');
      }
      return null;
    } finally {
      if (isMounted) {
        isLoading.value = false;
      }
    }
  };

  return {
    isLoading,
    execute,
  };
}

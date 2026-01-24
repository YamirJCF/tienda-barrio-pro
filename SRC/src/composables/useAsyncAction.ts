import { ref, onUnmounted } from 'vue';
import { useNotifications } from './useNotifications';

interface AsyncActionOptions {
  successMessage?: string;
  errorMessage?: string;
  showSuccessToast?: boolean;
  timeoutMs?: number;
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
    // 1. Resilience: Offline Check
    if (!navigator.onLine) {
      showWarning('Sin conexión a internet', 'wifi_off');
      return null;
    }

    // 2. Race Condition / Interaction Blocking
    if (isLoading.value) return null;

    isLoading.value = true;
    const {
      successMessage,
      errorMessage = 'Ocurrió un error inesperado',
      showSuccessToast = true,
      timeoutMs = 15000,
    } = options;

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
        showError('Error de conexión con el servidor', 'wifi_off');
      } else {
        // Business logic or validation error
        showError(errorMessage || error.message || 'Error desconocido');
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

<script setup lang="ts">
import { ref, computed, onErrorCaptured } from 'vue';
import { RouterView } from 'vue-router';
import ToastNotification from './components/ToastNotification.vue';
import { useNetworkStatus } from './composables/useNetworkStatus';
import { checkDataIntegrity } from './composables/useDataIntegrity';
// T-009: Import para banner de tienda cerrada
import { useStoreStatusStore } from './stores/storeStatus';
// SPEC-008: Alertas críticas bloqueantes
import CriticalAlertModal from './components/CriticalAlertModal.vue';
import { useCriticalAlerts } from './composables/useCriticalAlerts';

// ============================================
// DATA INTEGRITY CHECK (FIRST THING!)
// ============================================
// Ejecutar ANTES de cualquier store o componente
const integrityResult = checkDataIntegrity();
if (integrityResult.wasCorrupted) {
  console.warn('⚠️ Se detectaron y repararon datos corruptos:', integrityResult.repairedKeys);
}

useNetworkStatus();

// SPEC-008: Inicializar sistema de alertas críticas
const { currentAlert, isVisible, handlePrimary, handleSecondary, dismissAlert } =
  useCriticalAlerts();

// T-009: Estado de tienda para banner global
const storeStatusStore = useStoreStatusStore();
const isStoreClosed = computed(() => storeStatusStore.isClosed);

const errorDetected = ref(false);

// CAPTURA DE ERRORES GLOBAL
onErrorCaptured((err, instance, info) => {
  console.error('🔥 Error Crítico Capturado:', err);
  errorDetected.value = true;
  return false; // Evita que el error rompa la app completa
});

const resetApp = () => {
  localStorage.clear();
  window.location.reload();
};
</script>

<template>
  <div
    class="min-h-screen w-full mx-auto max-w-md bg-background-light dark:bg-background-dark shadow-2xl overflow-hidden relative"
    :class="{ 'pt-8': isStoreClosed }"
  >
    <!-- T-009: Banner Global de Tienda Cerrada -->
    <div
      v-if="isStoreClosed"
      class="fixed top-0 left-0 right-0 z-[200] bg-red-500 text-white text-center py-2 px-4 text-xs font-semibold flex items-center justify-center gap-2 shadow-lg"
    >
      <span class="material-symbols-outlined text-sm">lock</span>
      <span>🔒 Tienda Cerrada - Solo Administración</span>
    </div>

    <div
      v-if="errorDetected"
      class="absolute inset-0 z-50 flex flex-col items-center justify-center bg-white dark:bg-gray-900 p-6 text-center"
    >
      <div class="text-red-500 mb-4">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-16 w-16 mx-auto"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
          />
        </svg>
      </div>
      <h2 class="text-xl font-bold text-gray-800 dark:text-white mb-2">Algo salió mal</h2>
      <p class="text-gray-600 dark:text-gray-300 mb-6">
        Detectamos una inconsistencia en los datos locales.
      </p>
      <button
        @click="resetApp"
        class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors shadow-lg"
      >
        Reiniciar y Limpiar Datos
      </button>
    </div>

    <RouterView v-else v-slot="{ Component }">
      <transition name="fade" mode="out-in">
        <component :is="Component" />
      </transition>
    </RouterView>

    <ToastNotification />
  </div>
</template>

<style>
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>

<script setup lang="ts">
import { ref, computed, onErrorCaptured } from 'vue';
import { RouterView } from 'vue-router';
import ToastNotification from './components/ToastNotification.vue';
import { useNetworkStatus } from './composables/useNetworkStatus';
import { checkDataIntegrity } from './composables/useDataIntegrity';
// SPEC-008: Alertas críticas bloqueantes
import CriticalAlertModal from './components/CriticalAlertModal.vue';
import { useCriticalAlerts } from './composables/useCriticalAlerts';
import OfflineBanner from './components/common/OfflineBanner.vue';
import AdminInterruptionModal from './components/security/AdminInterruptionModal.vue';

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

// Presence Monitoring (Silent Witness)
import { useHeartbeat } from './composables/useHeartbeat';
useHeartbeat();

// Security: Revocation Guard (Checks for ban/revocation)
import { useRevocationGuard } from './composables/useRevocationGuard';
useRevocationGuard();

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
  >
    <!-- T-009: Banner Global de Tienda Cerrada - ELIMINADO -->

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

    <OfflineBanner />
    <AdminInterruptionModal />
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

<script setup lang="ts">
import { ref, computed, onErrorCaptured, onMounted, onUnmounted } from 'vue';
import { RouterView, useRouter } from 'vue-router';
import { useAuthStore } from './stores/auth'; // Import Auth Store
import ToastNotification from './components/ToastNotification.vue';
import { useNetworkStatus } from './composables/useNetworkStatus';
import { checkDataIntegrity } from './composables/useDataIntegrity';
// SPEC-008: Alertas críticas bloqueantes
import CriticalAlertModal from './components/CriticalAlertModal.vue';
import { useCriticalAlerts } from './composables/useCriticalAlerts';
import OfflineBanner from './components/common/OfflineBanner.vue';
import GlobalNetworkHandler from './components/common/GlobalNetworkHandler.vue';
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
const router = useRouter();
const authStore = useAuthStore(); // Initialize Auth Store

// ============================================
// FRD-012-R: Sync Auth Required Handler (RN-R05)
// ============================================
const handleSyncAuthRequired = () => {
  // If user is already on login page, silently ignore - this is expected
  const currentPath = router.currentRoute.value.path;
  if (currentPath === '/login' || currentPath === '/' || currentPath.includes('login')) {
    console.log('[App] sync:auth_required ignored - user already on login page');
    return;
  }
  
  console.warn('[App] sync:auth_required event received - session expired during sync');
  // Redirect to login with message
  alert('Tu sesión expiró. Por favor, inicia sesión nuevamente para sincronizar las ventas pendientes.');
  router.push('/login');
};

onMounted(() => {
  window.addEventListener('sync:auth_required', handleSyncAuthRequired);
});

onUnmounted(() => {
  window.removeEventListener('sync:auth_required', handleSyncAuthRequired);
});

// CAPTURA DE ERRORES GLOBAL (MEJORADO PARA OFFLINE)
onErrorCaptured((err, instance, info) => {
  // Ignorar errores de red que ya están siendo manejados por los repositorios
  if (err instanceof TypeError && (
    err.message.includes('Failed to fetch') ||
    err.message.includes('NetworkError') ||
    err.message.includes('fetch failed')
  )) {
    console.warn('⚠️ Error de red capturado (ignorado - modo offline activo):', err.message);
    return false; // Prevent propagation but don't show error overlay
  }

  // Ignorar errores de Supabase que ya están siendo manejados
  if (err.message && (
    err.message.includes('ERR_INTERNET_DISCONNECTED') ||
    err.message.includes('dynamically imported module') ||
    err.message.includes('websocket')
  )) {
    console.warn('⚠️ Error de Supabase capturado (ignorado):', err.message);
    return false;
  }

  // Solo mostrar overlay para errores críticos no manejados
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

    <!-- Global Network Handler - Always active -->
    <GlobalNetworkHandler />
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

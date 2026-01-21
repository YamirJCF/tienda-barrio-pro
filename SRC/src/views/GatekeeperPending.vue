<script setup lang="ts">
/**
 * GatekeeperPending Component
 * WO-004 T4.3: Shows "Device pending approval" screen for employees
 * 
 * Features:
 * - Message: "Dispositivo en espera de aprobación"
 * - Polling every 30s to check status
 * - Logout option
 * 
 * @component GatekeeperPending
 * @see SPEC-005: auth-unificada-iam.md
 */

import { ref, onMounted, onUnmounted, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { useDeviceFingerprint } from '../composables/useDeviceFingerprint';

const router = useRouter();
const authStore = useAuthStore();
const { getShortFingerprint } = useDeviceFingerprint();

const deviceId = ref('');
const isPolling = ref(false);
const lastChecked = ref<Date | null>(null);
const pollCount = ref(0);

let pollingInterval: ReturnType<typeof setInterval> | null = null;
const POLL_INTERVAL_MS = 30 * 1000; // 30 seconds

// Status message based on device status
const statusMessage = computed(() => {
  switch (authStore.deviceApproved) {
    case 'pending':
      return 'Tu dispositivo está esperando aprobación del Administrador.';
    case 'rejected':
      return 'Acceso denegado. Este dispositivo no está autorizado.';
    default:
      return 'Verificando estado del dispositivo...';
  }
});

const statusIcon = computed(() => {
  switch (authStore.deviceApproved) {
    case 'pending':
      return 'hourglass_top';
    case 'rejected':
      return 'block';
    default:
      return 'sync';
  }
});

const statusColor = computed(() => {
  switch (authStore.deviceApproved) {
    case 'pending':
      return 'text-amber-500';
    case 'rejected':
      return 'text-red-500';
    default:
      return 'text-gray-400';
  }
});

/**
 * Check device status with server
 * In production: calls RPC to verify approval status
 */
const checkDeviceStatus = async (): Promise<void> => {
  isPolling.value = true;
  pollCount.value++;
  
  try {
    // TODO: Replace with actual RPC call to check device status
    // const status = await supabase.rpc('check_device_status', { fingerprint: deviceId.value });
    
    // Simulated: Keep as pending (in real app, would update based on server response)
    lastChecked.value = new Date();
    
    // If approved, redirect to dashboard
    if (authStore.deviceApproved === 'approved') {
      stopPolling();
      router.push('/');
    }
  } catch (error) {
    console.error('[GatekeeperPending] Error checking status:', error);
  } finally {
    isPolling.value = false;
  }
};

/**
 * Start polling for status
 */
const startPolling = (): void => {
  if (pollingInterval) return;
  
  // Initial check
  checkDeviceStatus();
  
  // Start interval
  pollingInterval = setInterval(checkDeviceStatus, POLL_INTERVAL_MS);
};

/**
 * Stop polling
 */
const stopPolling = (): void => {
  if (pollingInterval) {
    clearInterval(pollingInterval);
    pollingInterval = null;
  }
};

/**
 * Handle logout
 */
const handleLogout = (): void => {
  stopPolling();
  authStore.logout();
  router.push('/login');
};

/**
 * Manual refresh
 */
const manualRefresh = async (): Promise<void> => {
  await checkDeviceStatus();
};

// Lifecycle
onMounted(async () => {
  deviceId.value = await getShortFingerprint();
  startPolling();
});

onUnmounted(() => {
  stopPolling();
});
</script>

<template>
  <div class="flex flex-col items-center justify-center min-h-screen p-6 bg-background-light dark:bg-background-dark">
    <div class="w-full max-w-md flex flex-col items-center text-center gap-6">
      <!-- Status Icon -->
      <div
        class="w-24 h-24 rounded-full flex items-center justify-center bg-gray-100 dark:bg-gray-800"
        :class="[authStore.deviceApproved === 'rejected' ? 'bg-red-100 dark:bg-red-900/20' : 'bg-amber-100 dark:bg-amber-900/20']"
      >
        <span
          class="material-symbols-outlined text-[48px]"
          :class="statusColor"
        >
          {{ statusIcon }}
        </span>
      </div>

      <!-- Status Message -->
      <div class="space-y-2">
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
          {{ authStore.deviceApproved === 'rejected' ? 'Acceso Denegado' : 'Aprobación Pendiente' }}
        </h1>
        <p class="text-gray-600 dark:text-gray-400 text-base leading-relaxed">
          {{ statusMessage }}
        </p>
      </div>

      <!-- Device Info Card -->
      <div class="w-full bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm border border-gray-200 dark:border-gray-700">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <span class="material-symbols-outlined text-gray-400">smartphone</span>
            <div class="text-left">
              <p class="text-sm font-medium text-gray-900 dark:text-white">ID del Dispositivo</p>
              <p class="text-xs text-gray-500 font-mono">{{ deviceId || '...' }}</p>
            </div>
          </div>
          <div
            class="px-2 py-1 rounded-full text-xs font-bold"
            :class="[
              authStore.deviceApproved === 'rejected'
                ? 'bg-red-100 text-red-600 dark:bg-red-900/30 dark:text-red-400'
                : 'bg-amber-100 text-amber-600 dark:bg-amber-900/30 dark:text-amber-400'
            ]"
          >
            {{ authStore.deviceApproved === 'rejected' ? 'Rechazado' : 'Pendiente' }}
          </div>
        </div>
      </div>

      <!-- Polling Info -->
      <div v-if="authStore.deviceApproved === 'pending'" class="text-xs text-gray-500 space-y-1">
        <p v-if="lastChecked">
          Última verificación: {{ lastChecked.toLocaleTimeString() }}
        </p>
        <p>
          Verificando automáticamente cada 30 segundos...
          <span v-if="isPolling" class="inline-flex items-center gap-1 text-primary">
            <span class="material-symbols-outlined text-sm animate-spin">sync</span>
          </span>
        </p>
      </div>

      <!-- Actions -->
      <div class="flex flex-col gap-3 w-full mt-4">
        <button
          v-if="authStore.deviceApproved === 'pending'"
          @click="manualRefresh"
          :disabled="isPolling"
          class="w-full py-3 px-4 rounded-xl bg-primary text-white font-semibold flex items-center justify-center gap-2 hover:bg-primary-dark transition-colors disabled:opacity-50"
        >
          <span class="material-symbols-outlined" :class="{ 'animate-spin': isPolling }">refresh</span>
          Verificar Ahora
        </button>
        
        <button
          @click="handleLogout"
          class="w-full py-3 px-4 rounded-xl border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 font-semibold hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
        >
          Cerrar Sesión
        </button>
      </div>

      <!-- Help Text -->
      <p class="text-xs text-gray-400 max-w-sm">
        Contacta a tu administrador para que apruebe este dispositivo desde el panel de control.
      </p>
    </div>
  </div>
</template>

<script setup lang="ts">
/**
 * AdminInterruptionModal
 * WO-005: Modal intrusivo para aprobación de pases diarios.
 * Se muestra globalmente en App.vue si el usuario es Admin.
 */
import { ref, onMounted, onUnmounted } from 'vue';
import { useAuthStore } from '../../stores/auth';
import BaseButton from '@/components/ui/BaseButton.vue';
import { User, Bell, PhoneCall, CheckCircle } from 'lucide-vue-next';

const authStore = useAuthStore();
const isVisible = ref(false);

// Datos del solicitante (Mock)
const requester = ref({
    name: 'Juan Pérez',
    photo: '',
    time: 'Hace 30 seg',
    pings: 1
});

// Polling para simular eventos entrantes (Stubs)
let pollInterval: ReturnType<typeof setInterval> | null = null;

const checkForRequests = () => {
    // En producción: Escuchar WebSocket o polling real
    // Simulación: Random pop-up para demo
    // if (Math.random() > 0.95) isVisible.value = true;
};

const handleApprove = () => {
    // authStore.approveDailyPass(requester.id);
    isVisible.value = false;
    alert(`Acceso concedido a ${requester.value.name}`);
};

const handleIgnore = () => {
    isVisible.value = false;
};

onMounted(() => {
    if (authStore.isAdmin) {
        pollInterval = setInterval(checkForRequests, 10000);
    }
});

onUnmounted(() => {
    if (pollInterval) clearInterval(pollInterval);
});

// Exponemos método para activar manualmente (demo)
defineExpose({ isVisible });
</script>

<template>
  <Teleport to="body">
      <div v-if="isVisible && authStore.isAdmin" class="fixed inset-0 z-[9999] flex items-center justify-center bg-gray-900/80 backdrop-blur-sm p-4 animate-[fadeIn_0.2s_ease-out]">
          <div class="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl max-w-md w-full overflow-hidden border border-red-500/30 ring-4 ring-red-500/10">
              
              <!-- Header -->
              <div class="bg-red-50 dark:bg-red-900/20 p-4 flex items-center gap-3 border-b border-red-100 dark:border-red-900/50">
                  <div class="animate-pulse bg-red-500 rounded-full w-3 h-3"></div>
                  <h3 class="font-bold text-red-700 dark:text-red-300 uppercase tracking-wider text-sm">
                      Solicitud de Ingreso Urgente
                  </h3>
              </div>

              <!-- Content -->
              <div class="p-6 flex flex-col items-center text-center gap-4">
                  <div class="relative">
                      <div class="w-20 h-20 bg-gray-200 rounded-full overflow-hidden flex items-center justify-center">
                          <User class="text-gray-400" :size="48" />
                      </div>
                      <div class="absolute -bottom-1 -right-1 bg-white dark:bg-gray-800 rounded-full p-1">
                          <Bell class="text-amber-500" :size="24" />
                      </div>
                  </div>
                  
                  <div>
                      <h2 class="text-2xl font-bold text-gray-900 dark:text-white">
                          {{ requester.name }}
                      </h2>
                      <p class="text-gray-500 dark:text-gray-400 text-sm">
                          Solicitó acceso {{ requester.time }}
                      </p>
                      <div v-if="requester.pings > 0" class="mt-2 inline-flex items-center gap-1 px-2 py-1 bg-red-100 text-red-700 rounded text-xs font-bold">
                          <PhoneCall :size="12" />
                          Insistencia: {{ requester.pings }}/3
                      </div>
                  </div>
              </div>

              <!-- Actions -->
              <div class="grid grid-cols-2 gap-0 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900/50">
                  <button 
                      @click="handleIgnore"
                      class="p-4 text-gray-600 dark:text-gray-400 font-bold hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
                  >
                      IGNORAR
                  </button>
                  <button 
                      @click="handleApprove"
                      class="p-4 text-white bg-emerald-600 font-bold hover:bg-emerald-700 transition-colors flex items-center justify-center gap-2"
                  >
                      <CheckCircle :size="20" />
                      APROBAR
                  </button>
              </div>
          </div>
      </div>
  </Teleport>
</template>

<script setup lang="ts">
/**
 * AdminInterruptionModal
 * WO-005: Modal intrusivo para aprobación de pases diarios.
 * Se muestra globalmente en App.vue si el usuario es Admin.
 */
import { ref, onMounted, watch, computed, onUnmounted } from 'vue';
import { useAuthStore } from '../../stores/auth';
import BaseButton from '@/components/ui/BaseButton.vue';
import { User, Bell, PhoneCall, CheckCircle, XCircle } from 'lucide-vue-next';

const authStore = useAuthStore();
const isVisible = ref(false);

// Datos reactivos del store
const pendingRequestTime = computed(() => authStore.pendingRequestTime);

// Manual TimeAgo
const now = ref(Date.now());
let timeInterval: ReturnType<typeof setInterval>;

const timeAgo = computed(() => {
    if (!pendingRequestTime.value) return '';
    const diff = now.value - new Date(pendingRequestTime.value).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return 'menos de un minuto';
    return `${mins} minutos`;
});

// Watcher: Si hay una solicitud pendiente y soy admin, mostrar modal
watch(
    () => authStore.dailyAccessStatus,
    (newStatus) => {
        if (newStatus === 'pending' && authStore.isAdmin) {
            isVisible.value = true;
            // Play sound?
        }
    }
);

const handleApprove = async () => {
    await authStore.approveRequest();
    isVisible.value = false;
};

const handleReject = async () => {
    await authStore.rejectRequest();
    isVisible.value = false;
};

onMounted(() => {
    timeInterval = setInterval(() => { now.value = Date.now() }, 60000);
});

onUnmounted(() => {
    clearInterval(timeInterval);
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
                          Empleado Solicitando
                      </h2>
                      <p class="text-gray-500 dark:text-gray-400 text-sm">
                          Solicitó acceso hace {{ timeAgo }}
                      </p>
                  </div>
              </div>

              <!-- Actions -->
              <div class="grid grid-cols-2 gap-0 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900/50">
                  <button 
                      @click="handleReject"
                      class="p-4 text-red-600 dark:text-red-400 font-bold hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors flex items-center justify-center gap-2"
                  >
                      <XCircle :size="20" />
                      RECHAZAR
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

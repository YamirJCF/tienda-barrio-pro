<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { useDevicesStore } from '../stores/devices';
import { 
  ShieldCheck, 
  Check, 
  X, 
  Smartphone, 
  CheckCircle, 
  UserX,
  Clock
} from 'lucide-vue-next';

const devicesStore = useDevicesStore();

// Initial fetch
onMounted(() => {
  devicesStore.fetchPendingRequests();
  devicesStore.fetchConnectedDevices();
});

// Computed
const hasPending = computed(() => devicesStore.pendingRequests.length > 0);
const hasConnected = computed(() => devicesStore.connectedDevices.length > 0);
const requestCount = computed(() => devicesStore.pendingRequests.length);
const connectedCount = computed(() => devicesStore.connectedDevices.length);

const isVisible = computed(() => hasPending.value || hasConnected.value);

// Methods
const parseDevice = (ua: string): string => {
  if (!ua) return '📱 Dispositivo';
  if (ua.includes('iPhone')) return '📱 iPhone';
  if (ua.includes('Android')) return '📱 Android';
  if (ua.includes('Windows')) return '💻 Windows';
  if (ua.includes('Mac')) return '💻 Mac';
  return '📱 Dispositivo';
};

const formatDate = (isoDate: string): string => {
  if (!isoDate) return '';
  const date = new Date(isoDate);
  return date.toLocaleDateString('es-CO', {
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
};
</script>

<template>
  <div v-if="isVisible" class="mb-4 space-y-4 animate-fade-in-down">
    
    <!-- Security Header -->
    <div class="flex items-center gap-2 px-1">
      <ShieldCheck class="text-primary dark:text-primary-light" :size="20" />
      <h3 class="text-sm font-bold text-slate-700 dark:text-slate-200 uppercase tracking-wider">
        Control de Accesos
      </h3>
    </div>

    <!-- Container -->
    <div class="bg-white dark:bg-surface-dark rounded-2xl shadow-sm border border-orange-100 dark:border-slate-700 overflow-hidden divide-y divide-slate-100 dark:divide-slate-700">
      
      <!-- Loading Overlay -->
      <div v-if="devicesStore.isLoading" class="absolute inset-0 bg-white/50 dark:bg-slate-900/50 z-10 flex items-center justify-center">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
      </div>

      <!-- Section: Pending Requests -->
      <div v-if="hasPending" class="p-4 bg-orange-50/50 dark:bg-orange-900/10">
        <div class="flex items-center justify-between mb-3">
          <h4 class="text-sm font-bold text-orange-800 dark:text-orange-400 flex items-center gap-2">
            <Clock :size="16" />
            Solicitudes Pendientes ({{ requestCount }})
          </h4>
        </div>
        
        <div class="space-y-3">
          <div 
            v-for="req in devicesStore.pendingRequests" 
            :key="req.id"
            class="bg-white dark:bg-slate-800 p-3 rounded-xl border border-orange-100 dark:border-slate-700 shadow-sm"
          >
            <div class="flex justify-between items-start mb-3">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-orange-100 dark:bg-orange-900/30 flex items-center justify-center text-orange-600 dark:text-orange-400">
                  <Smartphone :size="20" />
                </div>
                <div>
                  <p class="font-bold text-slate-800 dark:text-slate-200 text-sm">{{ req.employeeName }}</p>
                  <p class="text-xs text-slate-500 dark:text-slate-400">{{ parseDevice(req.userAgent) }}</p>
                </div>
              </div>
              <span class="text-[10px] bg-white dark:bg-slate-700 px-2 py-1 rounded-full border border-slate-100 dark:border-slate-600 text-slate-500">
                {{ formatDate(req.requestedAt) }}
              </span>
            </div>
            
            <div class="flex gap-2">
              <button 
                @click="devicesStore.approveDevice(req.id)"
                class="flex-1 py-1.5 rounded-lg bg-green-600 hover:bg-green-700 text-white text-xs font-bold flex items-center justify-center gap-1 transition-colors"
              >
                <Check :size="14" /> Aprobar
              </button>
              <button 
                @click="devicesStore.rejectRequest(req.id)"
                class="flex-1 py-1.5 rounded-lg bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-600 hover:bg-slate-50 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 text-xs font-bold flex items-center justify-center gap-1 transition-colors"
              >
                <X :size="14" /> Rechazar
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Section: Connected Devices -->
      <div v-if="hasConnected" class="p-4">
        <div class="flex items-center justify-between mb-3">
          <h4 class="text-sm font-bold text-slate-700 dark:text-slate-300 flex items-center gap-2">
            <CheckCircle :size="16" class="text-green-600 dark:text-green-400" />
            Dispositivos Conectados ({{ connectedCount }})
          </h4>
        </div>

        <div class="space-y-2">
          <div 
            v-for="device in devicesStore.connectedDevices" 
            :key="device.id"
            class="flex items-center justify-between p-2 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors group"
          >
            <div class="flex items-center gap-3">
               <div class="relative">
                 <div class="w-8 h-8 rounded-lg bg-slate-100 dark:bg-slate-700 flex items-center justify-center text-slate-500">
                    <Smartphone :size="16" />
                 </div>
                 <div class="absolute -bottom-1 -right-1 bg-green-500 rounded-full p-0.5 border-2 border-white dark:border-slate-800">
                    <Check :size="8" class="text-white" stroke-width="4" />
                 </div>
               </div>
               <div>
                  <p class="text-sm font-medium text-slate-800 dark:text-slate-200">{{ device.employeeName }}</p>
                  <p class="text-[10px] text-slate-400">{{ parseDevice(device.userAgent) }}</p>
               </div>
            </div>

            <button 
              @click="devicesStore.revokeDevice(device.id)"
              class="p-2 rounded-lg text-slate-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 transition-all opacity-100 sm:opacity-0 sm:group-hover:opacity-100"
              title="Revocar Acceso"
            >
              <UserX :size="16" />
            </button>
          </div>
        </div>
      </div>
    
    </div>
  </div>
</template>

<style scoped>
.animate-fade-in-down {
  animation: fadeInDown 0.3s ease-out;
}

@keyframes fadeInDown {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>

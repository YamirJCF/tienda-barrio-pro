<template>
  <div v-if="pendingRequests.length > 0" class="bg-white rounded-2xl shadow-sm border border-orange-100 overflow-hidden mb-6">
    <div class="px-6 py-4 bg-orange-50 border-b border-orange-100 flex justify-between items-center">
      <div class="flex items-center gap-3">
        <div class="p-2 bg-orange-100 rounded-lg">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-orange-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
          </svg>
        </div>
        <div>
          <h3 class="font-bold text-gray-900">Solicitudes de Acceso</h3>
          <p class="text-xs text-gray-500">{{ pendingRequests.length }} empleados esperando</p>
        </div>
      </div>
      <span class="animate-pulse relative flex h-3 w-3">
        <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-orange-400 opacity-75"></span>
        <span class="relative inline-flex rounded-full h-3 w-3 bg-orange-500"></span>
      </span>
    </div>
    
    <div class="divide-y divide-gray-100">
      <div v-for="req in pendingRequests" :key="req.id" class="p-4 flex items-center justify-between hover:bg-gray-50 transition-colors">
        <div class="flex items-center gap-4">
           <div class="h-10 w-10 rounded-full bg-gray-100 flex items-center justify-center text-gray-600 font-bold">
             {{ getInitials(req.employees?.name) }}
           </div>
           <div>
             <p class="font-medium text-gray-900">{{ req.employees?.name || 'Desconocido' }}</p>
             <p class="text-xs text-gray-500">
               {{ formatFromNow(req.requested_at) }} • Intento #{{ req.retry_count }}
             </p>
           </div>
        </div>
        
        <div class="flex items-center gap-2">
           <button 
             @click="reject(req.id)"
             :disabled="processing === req.id"
             class="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-colors"
             title="Rechazar">
             <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
               <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
             </svg>
           </button>
           
           <button 
             @click="approve(req.id)"
             :disabled="processing === req.id"
             class="px-4 py-2 bg-gray-900 text-white text-sm font-medium rounded-xl hover:bg-black transition-colors shadow-sm flex items-center gap-2">
             <span v-if="processing === req.id">...</span>
             <span v-else>Aprobar</span>
           </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue';
import { useAuthStore } from '../../stores/auth';
import { formatDistanceToNow } from 'date-fns';
import { es } from 'date-fns/locale';

const authStore = useAuthStore();
const processing = ref<string | null>(null);
let pollInterval: any = null;

const pendingRequests = computed(() => authStore.pendingRequests);

onMounted(() => {
  refresh();
  pollInterval = setInterval(refresh, 15000); // Poll every 15s
});

onUnmounted(() => {
  if (pollInterval) clearInterval(pollInterval);
});

const refresh = async () => {
  await authStore.fetchPendingRequests();
};

const approve = async (id: string) => {
  processing.value = id;
  await authStore.approveRequest(id);
  processing.value = null;
};

const reject = async (id: string) => {
  if (!confirm('¿Rechazar acceso a este empleado?')) return;
  processing.value = id;
  await authStore.rejectRequest(id);
  processing.value = null;
};

const getInitials = (name?: string) => {
    if (!name) return '?';
    return name.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase();
};

const formatFromNow = (dateStr: string) => {
    try {
        return formatDistanceToNow(new Date(dateStr), { addSuffix: true, locale: es });
    } catch (e) {
        return 'Hace un momento';
    }
}
</script>

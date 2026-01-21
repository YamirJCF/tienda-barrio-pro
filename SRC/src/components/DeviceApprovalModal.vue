<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { logger } from '../utils/logger';

// Props y Emits
const props = defineProps<{
  modelValue: boolean;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
}>();

// Tipo para solicitud de acceso
interface AccessRequest {
  id: string;
  employeeId: string;
  employeeName: string;
  deviceFingerprint: string;
  userAgent: string;
  status: 'pending' | 'approved' | 'rejected';
  requestedAt: string;
}

// Estado local (simulado - en producción vendría de Supabase)
const requests = ref<AccessRequest[]>([]);
const isLoading = ref(false);

// Computed
const pendingRequests = computed(() => requests.value.filter((r) => r.status === 'pending'));

const approvedDevices = computed(() => requests.value.filter((r) => r.status === 'approved'));

// Simular carga de datos (en producción: Supabase query)
onMounted(() => {
  // Datos de ejemplo para demostración
  requests.value = [
    {
      id: '1',
      employeeId: 'emp1',
      employeeName: 'Juan Pérez',
      deviceFingerprint: 'abc123def456',
      userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0)',
      status: 'pending',
      requestedAt: new Date().toISOString(),
    },
    {
      id: '2',
      employeeId: 'emp2',
      employeeName: 'María García',
      deviceFingerprint: 'xyz789ghi012',
      userAgent: 'Mozilla/5.0 (Android 13; SM-G998B)',
      status: 'approved',
      requestedAt: new Date(Date.now() - 86400000).toISOString(),
    },
  ];
});

// Métodos
const close = () => {
  emit('update:modelValue', false);
};

const approveDevice = (request: AccessRequest) => {
  const idx = requests.value.findIndex((r) => r.id === request.id);
  if (idx !== -1) {
    requests.value[idx].status = 'approved';
    logger.log('[DeviceApproval] Aprobado:', request.employeeName);
  }
};

const rejectDevice = (request: AccessRequest) => {
  const idx = requests.value.findIndex((r) => r.id === request.id);
  if (idx !== -1) {
    requests.value[idx].status = 'rejected';
    logger.log('[DeviceApproval] Rechazado:', request.employeeName);
  }
};

// Parsear User Agent para mostrar dispositivo resumido
const parseDevice = (ua: string): string => {
  if (ua.includes('iPhone')) return '📱 iPhone';
  if (ua.includes('Android')) return '📱 Android';
  if (ua.includes('Windows')) return '💻 Windows';
  if (ua.includes('Mac')) return '💻 Mac';
  return '📱 Dispositivo';
};

const formatDate = (isoDate: string): string => {
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
  <Teleport to="body">
    <Transition name="modal">
      <div v-if="modelValue" class="fixed inset-0 z-50 flex items-end justify-center">
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-slate-900/60 backdrop-blur-[2px]" @click="close"></div>

        <!-- Modal Panel -->
        <div
          class="relative w-full max-w-md max-h-[80vh] bg-white dark:bg-surface-dark rounded-t-3xl shadow-2xl animate-slide-up flex flex-col"
        >
          <!-- Handle -->
          <div
            class="mx-auto mt-3 mb-2 h-1.5 w-12 rounded-full bg-slate-200 dark:bg-slate-700 cursor-pointer"
            @click="close"
          ></div>

          <!-- Header -->
          <div class="px-6 pb-4 border-b border-slate-100 dark:border-slate-700">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-3">
                <div
                  class="flex h-10 w-10 items-center justify-center rounded-full bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400"
                >
                  <span class="material-symbols-outlined">smartphone</span>
                </div>
                <div>
                  <h3 class="text-lg font-bold text-slate-900 dark:text-white">Dispositivos</h3>
                  <p class="text-xs text-slate-500 dark:text-slate-400">
                    {{ pendingRequests.length }} pendientes
                  </p>
                </div>
              </div>
              <button
                @click="close"
                class="p-2 rounded-full hover:bg-slate-100 dark:hover:bg-slate-700 text-slate-400"
              >
                <span class="material-symbols-outlined">close</span>
              </button>
            </div>
          </div>

          <!-- Content -->
          <div class="flex-1 overflow-y-auto p-4 space-y-4">
            <!-- Solicitudes Pendientes -->
            <section v-if="pendingRequests.length > 0">
              <h4
                class="text-sm font-bold text-amber-700 dark:text-amber-400 mb-2 flex items-center gap-2"
              >
                <span class="material-symbols-outlined text-lg">pending</span>
                Pendientes de Aprobación
              </h4>
              <div class="space-y-2">
                <div
                  v-for="request in pendingRequests"
                  :key="request.id"
                  class="p-4 rounded-xl bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800"
                >
                  <div class="flex items-start justify-between mb-3">
                    <div>
                      <p class="font-bold text-slate-900 dark:text-white">
                        {{ request.employeeName }}
                      </p>
                      <p class="text-xs text-slate-500 dark:text-slate-400">
                        {{ parseDevice(request.userAgent) }} • {{ formatDate(request.requestedAt) }}
                      </p>
                    </div>
                  </div>
                  <div class="flex gap-2">
                    <button
                      @click="approveDevice(request)"
                      class="flex-1 py-2 px-3 rounded-lg bg-green-600 hover:bg-green-700 text-white text-sm font-bold flex items-center justify-center gap-1 transition-colors"
                    >
                      <span class="material-symbols-outlined text-lg">check</span>
                      Aprobar
                    </button>
                    <button
                      @click="rejectDevice(request)"
                      class="flex-1 py-2 px-3 rounded-lg bg-red-600 hover:bg-red-700 text-white text-sm font-bold flex items-center justify-center gap-1 transition-colors"
                    >
                      <span class="material-symbols-outlined text-lg">close</span>
                      Rechazar
                    </button>
                  </div>
                </div>
              </div>
            </section>

            <!-- Empty State Pendientes -->
            <div v-else class="text-center py-6">
              <div
                class="mx-auto w-16 h-16 rounded-full bg-green-100 dark:bg-green-900/20 flex items-center justify-center mb-3"
              >
                <span class="material-symbols-outlined text-3xl text-green-600 dark:text-green-400"
                  >verified_user</span
                >
              </div>
              <p class="text-sm font-medium text-slate-600 dark:text-slate-400">
                No hay solicitudes pendientes
              </p>
            </div>

            <!-- Dispositivos Aprobados -->
            <section v-if="approvedDevices.length > 0">
              <h4
                class="text-sm font-bold text-slate-600 dark:text-slate-400 mb-2 flex items-center gap-2"
              >
                <span class="material-symbols-outlined text-lg">check_circle</span>
                Dispositivos Autorizados
              </h4>
              <div class="space-y-2">
                <div
                  v-for="device in approvedDevices"
                  :key="device.id"
                  class="p-3 rounded-lg bg-slate-50 dark:bg-slate-800 border border-slate-100 dark:border-slate-700 flex items-center justify-between"
                >
                  <div>
                    <p class="font-medium text-slate-800 dark:text-slate-200 text-sm">
                      {{ device.employeeName }}
                    </p>
                    <p class="text-xs text-slate-500 dark:text-slate-400">
                      {{ parseDevice(device.userAgent) }}
                    </p>
                  </div>
                  <span class="text-green-600 dark:text-green-400">
                    <span class="material-symbols-outlined">verified</span>
                  </span>
                </div>
              </div>
            </section>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.3s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.modal-enter-active .animate-slide-up {
  animation: slideUp 0.3s ease-out;
}

.modal-leave-active .animate-slide-up {
  animation: slideDown 0.3s ease-in;
}

@keyframes slideUp {
  from {
    transform: translateY(100%);
  }

  to {
    transform: translateY(0);
  }
}

@keyframes slideDown {
  from {
    transform: translateY(0);
  }

  to {
    transform: translateY(100%);
  }
}
</style>

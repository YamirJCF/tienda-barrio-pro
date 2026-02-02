<script setup lang="ts">
/**
 * DailyWaitingRoom Component
 * WO-005: Sala de espera para aprobación diaria (Zero Trust)
 */

import { ref, onMounted, onUnmounted, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { useNotifications } from '@/composables/useNotifications';
import BaseButton from '@/components/ui/BaseButton.vue';
import { Hourglass, AlertCircle, BellRing } from 'lucide-vue-next';

const router = useRouter();
const authStore = useAuthStore();
const { showInfo, showSuccess, showError } = useNotifications();

// State
const isPolling = ref(false);
const pingCount = ref(0);
const isPingDisabled = ref(true);
const pingCooldown = ref(120); // 2 minutos iniciales
const maxPings = 3;
const isLocked = ref(false);

let pollingInterval: ReturnType<typeof setInterval> | null = null;
let cooldownInterval: ReturnType<typeof setInterval> | null = null;

// Messages
const title = computed(() => {
    if (authStore.dailyAccessStatus === 'rejected') return 'Acceso Denegado';
    return isLocked.value ? 'Atención Requerida' : 'Esperando Autorización';
});

const subtitle = computed(() => {
    if (authStore.dailyAccessStatus === 'rejected') return 'Tu solicitud ha sido rechazada por el administrador.';
    return isLocked.value 
    ? 'No hemos recibido respuesta del administrador.' 
    : 'Tu supervisor ha sido notificado. Por favor espera.';
});

// Methods
const startPolling = () => {
    pollingInterval = setInterval(async () => {
        // Consultar estado real al store
        const status = await authStore.checkDailyApproval();
        console.log('[WaitingRoom] Polling Status:', status);
        
        if (status === 'approved') {
            console.log('[WaitingRoom] Approved! Redirecting...');
            router.push('/');
        } else if (status === 'rejected') {
            isLocked.value = true;
            if (pollingInterval) clearInterval(pollingInterval);
        }
    }, 5000); // 5s polling (más rápido para demo local)
};

const startCooldown = (seconds: number) => {
    pingCooldown.value = seconds;
    isPingDisabled.value = true;
    
    if (cooldownInterval) clearInterval(cooldownInterval);
    
    cooldownInterval = setInterval(() => {
        if (pingCooldown.value > 0) {
            pingCooldown.value--;
        } else {
            isPingDisabled.value = false;
            clearInterval(cooldownInterval!);
        }
    }, 1000);
};

const handlePing = async () => {
    if (pingCount.value >= maxPings) return;

    pingCount.value++;
    // START: Connection to Real Store Logic
    await authStore.requestDailyPass(); 
    // END
    
    if (pingCount.value >= maxPings) {
        isLocked.value = true;
        // No paramos polling, quizas el admin apruebe justo despues
    } else {
        startCooldown(60); // 1 min cooldown para demo (antes 5 min)
    }
};

const handleLogout = () => {
    authStore.logout();
    router.push('/login');
};

onMounted(async () => {
    // Si no hay solicitud pendiente, pedirla automáticamente
    if (authStore.dailyAccessStatus === 'none' || authStore.dailyAccessStatus === 'expired') {
        showInfo('Contactando al Supervisor...');
        const result = await authStore.requestDailyPass();
        if (result.success) {
            showSuccess('Solicitud Enviada Correctamente');
        } else {
            showError(`Error: ${result.error}`);
        }
    }
    
    startPolling();
    
    // Si ya enviamos solicitud (auto o previa), iniciar cooldown visual
    if (authStore.dailyAccessStatus === 'pending') {
        startCooldown(60); 
    } else {
        startCooldown(0); // Permitir botón si falló
    }
});

onUnmounted(() => {
    if (pollingInterval) clearInterval(pollingInterval);
    if (cooldownInterval) clearInterval(cooldownInterval);
});

const formatTime = (seconds: number) => {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m}:${s.toString().padStart(2, '0')}`;
};
</script>

<template>
  <div class="flex flex-col items-center justify-center min-h-screen p-6 bg-gray-50 dark:bg-gray-900">
    <div class="w-full max-w-md flex flex-col items-center text-center gap-8">
      
      <!-- Icon Animation -->
      <div class="relative">
        <div class="w-24 h-24 rounded-full flex items-center justify-center"
             :class="isLocked ? 'bg-red-100 text-red-600' : 'bg-amber-100 text-amber-600'">
             <component :is="isLocked ? AlertCircle : Hourglass" :size="48" :stroke-width="1.5" />
        </div>
        <div v-if="!isLocked" class="absolute -top-1 -right-1 w-6 h-6 bg-blue-500 rounded-full animate-ping opacity-75"></div>
      </div>

      <!-- Text Content -->
      <div class="space-y-3">
        <h1 class="text-2xl font-bold text-gray-900 dark:text-white">{{ title }}</h1>
        <p class="text-gray-500 dark:text-gray-400 max-w-xs mx-auto">
            {{ subtitle }}
        </p>
        <div v-if="isLocked" class="p-4 bg-red-50 dark:bg-red-900/20 rounded-lg border border-red-200 dark:border-red-800 mt-4">
            <p class="font-bold text-red-700 dark:text-red-300">Contacte a su supervisor por teléfono</p>
        </div>
      </div>

      <!-- Actions -->
      <div class="w-full space-y-4">
          <div v-if="!isLocked">
            <BaseButton 
                @click="handlePing"
                :disabled="isPingDisabled"
                variant="secondary"
                class="w-full relative overflow-hidden"
            >
                <span v-if="isPingDisabled" class="absolute inset-0 bg-gray-200/50 dark:bg-gray-700/50 z-10 transition-all" 
                      :style="{ width: `${(pingCooldown / (pingCount === 0 ? 120 : 300)) * 100}%` }"></span>
                <span class="relative z-20 flex items-center gap-2 justify-center">
                    <BellRing :size="20" :stroke-width="1.5" />
                    {{ isPingDisabled ? `Espere ${formatTime(pingCooldown)}` : '¡Sigo aquí! (Reenviar)' }}
                </span>
            </BaseButton>
            <p class="text-xs text-gray-400 mt-2">
                Intentos de llamada: {{ pingCount }}/{{ maxPings }}
            </p>
          </div>

          <button 
            @click="handleLogout"
            class="text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-white underline text-sm"
          >
              Cancelar y Cerrar Sesión
          </button>
      </div>

       <div class="mt-8 p-4 bg-gray-900 rounded-lg text-xs text-green-400 font-mono text-left opacity-90">
          <p><strong>DEBUG INFO:</strong></p>
          <p>User ID: {{ authStore.currentUser?.id }}</p>
          <p>Access Status: {{ authStore.dailyAccessStatus }}</p>
          <p>Fingerprint: {{ authStore.dailyAccessState?.fingerprint?.substring(0, 15) }}...</p>
          <p>Last Poll: {{ new Date().toLocaleTimeString() }}</p>
      </div>

    </div>
  </div>
</template>

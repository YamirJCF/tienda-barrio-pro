<script setup lang="ts">
/**
 * DailyWaitingRoom Component
 * WO-005: Sala de espera para aprobación diaria (Zero Trust)
 */

import { ref, onMounted, onUnmounted, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import BaseButton from '@/components/ui/BaseButton.vue';

const router = useRouter();
const authStore = useAuthStore();

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
const title = computed(() => isLocked.value ? 'Atención Requerida' : 'Esperando Autorización');
const subtitle = computed(() => isLocked.value 
    ? 'No hemos recibido respuesta del administrador.' 
    : 'Tu supervisor ha sido notificado. Por favor espera.');

// Methods
const startPolling = () => {
    pollingInterval = setInterval(async () => {
        const status = await authStore.checkDailyApproval();
        if (status === 'approved') {
            router.push('/');
        }
    }, 15000); // 15s polling
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
    await authStore.requestDailyPass(); // Send ping
    
    // Feedback visual (toast simulado)
    // alert("Notificación reenviada"); 

    if (pingCount.value >= maxPings) {
        isLocked.value = true;
        if (pollingInterval) clearInterval(pollingInterval); // Stop checking if locked? Validar regla.
        // Regla: Abandono de sistema. Bloquea solicitud.
    } else {
        startCooldown(300); // 5 min cooldown
    }
};

const handleLogout = () => {
    authStore.logout();
    router.push('/login');
};

onMounted(() => {
    startPolling();
    startCooldown(120); // Start with 2 min cooldown
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
             <span class="material-symbols-outlined text-5xl">
                 {{ isLocked ? 'fmd_bad' : 'hourglass_top' }}
             </span>
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
                    <span class="material-symbols-outlined">notifications_active</span>
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

    </div>
  </div>
</template>

<script setup lang="ts">
/**
 * DailyWaitingRoom Component
 * WO-005: Sala de espera para aprobación diaria (Zero Trust)
 *
 * OT-6: Replaced setInterval polling with:
 *   1. Supabase Realtime subscription on the employee's specific pass row
 *   2. Local 5-minute setTimeout that expires the request if admin doesn't respond
 *      Timer resets on every "Reenviar Alerta" (handlePing) call.
 */

import { ref, onMounted, onUnmounted, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { useNotifications } from '@/composables/useNotifications';
import BaseButton from '@/components/ui/BaseButton.vue';
import { Hourglass, AlertCircle, BellRing } from 'lucide-vue-next';
import { supabase } from '@/lib/supabase';
import type { RealtimeChannel } from '@supabase/supabase-js';

const router = useRouter();
const authStore = useAuthStore();
const { showInfo, showSuccess, showError } = useNotifications();

// State
const pingCount = ref(0);
const isPingDisabled = ref(true);
const pingCooldown = ref(120); // 2 min initial cooldown display
const maxPings = 3;
const isLocked = ref(false);

// Realtime channel for this employee's specific pass row
let passChannel: RealtimeChannel | null = null;
// 5-minute expiry timer — reset on every retry
let expiryTimer: ReturnType<typeof setTimeout> | null = null;
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

// ─── Realtime ──────────────────────────────────────────────────────────────

const subscribeToPass = (passId: string) => {
    if (passChannel) return; // guard: already subscribed

    passChannel = supabase
        .channel(`employee_pass_${passId}`)
        .on(
            'postgres_changes',
            { event: 'UPDATE', schema: 'public', table: 'daily_passes', filter: `id=eq.${passId}` },
            (payload) => {
                const status = (payload.new as any)?.status;
                if (status === 'approved') {
                    clearExpiryTimer();
                    router.push('/');
                } else if (status === 'rejected' || status === 'expired') {
                    clearExpiryTimer();
                    isLocked.value = true;
                    cleanupChannel();
                }
            }
        )
        .subscribe();
};

const cleanupChannel = () => {
    if (passChannel) {
        supabase.removeChannel(passChannel);
        passChannel = null;
    }
};

// ─── 5-minute expiry timer ──────────────────────────────────────────────────

const EXPIRY_MS = 5 * 60 * 1000; // 5 minutes

const startExpiryTimer = () => {
    clearExpiryTimer();
    expiryTimer = setTimeout(() => {
        // Admin didn't respond within 5 minutes → logout employee
        cleanupChannel();
        authStore.logout();
        router.push({ path: '/login', query: { reason: 'timeout' } });
    }, EXPIRY_MS);
};

const clearExpiryTimer = () => {
    if (expiryTimer) {
        clearTimeout(expiryTimer);
        expiryTimer = null;
    }
};

// ─── Cooldown display ───────────────────────────────────────────────────────

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

// ─── Actions ────────────────────────────────────────────────────────────────

const handlePing = async () => {
    if (pingCount.value >= maxPings) return;

    pingCount.value++;
    await authStore.requestDailyPass();

    // Reset the 5-minute expiry window — employee is actively waiting
    startExpiryTimer();

    if (pingCount.value >= maxPings) {
        isLocked.value = true;
    } else {
        startCooldown(60); // 1 min UI cooldown between retries
    }
};

const handleLogout = () => {
    clearExpiryTimer();
    cleanupChannel();
    authStore.logout();
    router.push('/login');
};

// ─── Lifecycle ──────────────────────────────────────────────────────────────

onMounted(async () => {
    // If no pending request yet, fire the initial one
    if (authStore.dailyAccessStatus === 'none' || authStore.dailyAccessStatus === 'expired') {
        showInfo('Contactando al Supervisor...');
        const result = await authStore.requestDailyPass();
        if (result.success) {
            showSuccess('Solicitud Enviada Correctamente');
        } else {
            showError(`Error: ${result.error}`);
        }
    }

    // Subscribe to the server-pushed pass status updates
    const passId = authStore.dailyAccessState?.passId;
    if (passId) {
        subscribeToPass(passId);
    }

    // Start 5-minute expiry timer
    if (authStore.dailyAccessStatus === 'pending') {
        startExpiryTimer();
        startCooldown(60);
    } else {
        startCooldown(0); // Allow button immediately if status is not pending
    }
});

onUnmounted(() => {
    clearExpiryTimer();
    cleanupChannel();
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



    </div>
  </div>
</template>

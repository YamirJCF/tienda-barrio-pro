<script setup lang="ts">
/**
 * CheckEmailView Component
 * WO-005: Pausa obligatoria tras registro para validar email (Verificación).
 */
import { ref, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
// import { useAuthStore } from '../stores/auth'; // Si necesitamos verificar estado
// import BaseButton from '@/components/ui/BaseButton.vue';

const router = useRouter();

// State
const email = ref('tu@email.com'); // Idealmente vendría del Store o query param
const cooldown = ref(60);
const canResend = ref(false);

let timer: ReturnType<typeof setInterval> | null = null;

const startTimer = () => {
    canResend.value = false;
    cooldown.value = 60;
    
    timer = setInterval(() => {
        if (cooldown.value > 0) {
            cooldown.value--;
        } else {
            canResend.value = true;
            if (timer) clearInterval(timer);
        }
    }, 1000);
};

const handleResend = async () => {
    if (!canResend.value) return;
    
    // TODO: Call Store action resendVerificationEmail()
    console.log("Resending email...");
    startTimer();
};

const goBack = () => {
    router.push('/login');
};

onMounted(() => {
    // Si pasamos el email por query param
    // const route = useRoute();
    // if (route.query.email) email.value = route.query.email as string;
    
    startTimer();
});

onUnmounted(() => {
    if (timer) clearInterval(timer);
});

</script>

<template>
  <div class="flex flex-col items-center justify-center min-h-screen p-6 bg-white dark:bg-gray-900 font-display">
    <div class="w-full max-w-sm flex flex-col items-center text-center gap-6">
      
      <!-- Icon -->
      <div class="w-20 h-20 rounded-full bg-emerald-50 text-emerald-600 flex items-center justify-center animate-[popIn_0.5s_ease-out]">
          <span class="material-symbols-outlined text-4xl">mark_email_unread</span>
      </div>

      <!-- Text -->
      <div class="space-y-2 animate-[fadeIn_0.5s_ease-out_0.2s_both]">
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white">Revisa tu correo</h1>
          <p class="text-gray-500 dark:text-gray-400">
              Hemos enviado un enlace de confirmación a <br>
              <strong class="text-gray-900 dark:text-gray-200">{{ email }}</strong>
          </p>
          <p class="text-sm text-gray-400 mt-2">
              Haz clic en el enlace para activar tu cuenta y empezar a usar Tienda de Barrio.
          </p>
      </div>

      <!-- Actions -->
      <div class="w-full space-y-4 mt-4 animate-[fadeIn_0.5s_ease-out_0.4s_both]">
          <button 
              @click="handleResend"
              :disabled="!canResend"
              class="w-full py-3 rounded-xl border border-gray-200 dark:border-gray-700 text-sm font-medium transition-all"
              :class="canResend ? 'hover:bg-gray-50 dark:hover:bg-gray-800 text-gray-700 dark:text-gray-300' : 'opacity-50 cursor-not-allowed text-gray-400'"
          >
              {{ canResend ? '¿No te llegó? Reenviar correo' : `Reenviar en (${cooldown}s)` }}
          </button>

          <button 
              @click="goBack"
              class="text-emerald-600 font-medium hover:underline text-sm"
          >
              Volver al inicio de sesión
          </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
@keyframes popIn {
    0% { transform: scale(0); opacity: 0; }
    80% { transform: scale(1.1); }
    100% { transform: scale(1); opacity: 1; }
}
@keyframes fadeIn {
    from { opacity: 0; transform: translateY(10px); }
    to { opacity: 1; transform: translateY(0); }
}
</style>

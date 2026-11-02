<template>
  <div class="bg-[#f8fcfb] dark:bg-[#0f231d] min-h-screen text-[#0d1c17] dark:text-white font-display flex flex-col justify-between selection:bg-emerald-100 selection:text-emerald-700">
    <!-- Header -->
    <header class="sticky top-0 z-50 bg-[#f8fcfb]/95 dark:bg-[#0f231d]/95 backdrop-blur-sm border-b border-[#cee9e0]/30 dark:border-white/10">
      <div class="flex items-center px-4 h-16 max-w-lg mx-auto w-full">
        <button
          type="button"
          @click="goToLogin"
          aria-label="Volver al inicio de sesión"
          class="flex items-center justify-center w-10 h-10 -ml-2 rounded-full active:bg-gray-100 dark:active:bg-white/10 text-[#0d1c17] dark:text-white transition-colors cursor-pointer"
        >
          <ArrowLeft :size="24" :stroke-width="1.5" />
        </button>
        <h1 class="flex-1 text-center text-lg font-bold tracking-tight pr-8">
          Verifica tu Cuenta
        </h1>
      </div>
    </header>

    <!-- Main Content Container -->
    <main class="w-full max-w-lg mx-auto px-5 py-6 my-auto flex flex-col items-center text-center">
      <!-- Hero Icon with Soft Glow -->
      <div class="relative mb-6">
        <div class="absolute -inset-2 bg-emerald-100 dark:bg-emerald-950/50 rounded-full blur-sm opacity-60 animate-pulse"></div>
        <div class="relative w-24 h-24 rounded-full bg-emerald-50 dark:bg-emerald-900/30 border-2 border-emerald-200 dark:border-emerald-700/50 flex items-center justify-center text-emerald-600 dark:text-emerald-400 shadow-sm">
          <MailIcon class="w-12 h-12 stroke-[1.8]" />
          <span class="absolute bottom-0 right-0 w-7 h-7 bg-emerald-500 text-white rounded-full border-2 border-white dark:border-[#0f231d] flex items-center justify-center shadow-xs">
            <Check class="w-4 h-4 stroke-[2.5]" />
          </span>
        </div>
      </div>

      <!-- Main Headline -->
      <h2 class="text-2xl font-bold text-[#0d1c17] dark:text-white tracking-tight mb-2">
        Revisa tu correo
      </h2>

      <!-- Notice text -->
      <p v-if="email" class="text-sm text-gray-500 dark:text-gray-400 max-w-[290px] leading-relaxed mb-3">
        Hemos enviado un enlace de confirmación a
      </p>
      <div v-else class="mb-6 p-3 bg-amber-50 dark:bg-amber-950/30 rounded-lg border border-amber-200 dark:border-amber-800/50 text-amber-800 dark:text-amber-200 text-sm max-w-sm">
        No pudimos detectar tu correo de registro. Por favor regresa e intenta de nuevo.
      </div>

      <!-- Email Pill Badge -->
      <div v-if="email" class="inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-white dark:bg-white/5 border border-emerald-200 dark:border-emerald-800 text-emerald-700 dark:text-emerald-300 shadow-xs font-medium text-xs mb-3">
        <MailIcon class="w-3.5 h-3.5 text-emerald-500" />
        <span class="font-semibold tracking-tight">{{ email }}</span>
      </div>

      <!-- Return to Registration Action (For Error Correction) -->
      <div class="flex items-center justify-center gap-1.5 text-xs text-gray-500 dark:text-gray-400 mb-5">
        <button
          type="button"
          @click="goToRegister"
          class="inline-flex items-center gap-1.5 text-gray-500 dark:text-gray-400 hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors font-medium hover:underline cursor-pointer"
        >
          <PenLine class="w-3.5 h-3.5 text-gray-400" />
          <span>¿Te equivocaste en algún dato? <strong class="font-semibold text-emerald-600 dark:text-emerald-400 hover:text-emerald-700">Volver al registro</strong></span>
        </button>
      </div>

      <!-- Spam Note Callout -->
      <div class="bg-amber-50/90 dark:bg-amber-950/30 border border-amber-200/80 dark:border-amber-800/50 rounded-xl px-3.5 py-2.5 max-w-[320px] flex items-center gap-2.5 text-left mb-5">
        <AlertCircle class="w-4 h-4 text-amber-600 dark:text-amber-400 flex-shrink-0" />
        <p class="text-xs text-amber-800 dark:text-amber-200 leading-snug">
          ¿No lo ves en la bandeja principal? Recuerda revisar la carpeta de <strong>Spam o No deseados</strong>.
        </p>
      </div>

      <!-- Resend timer section -->
      <div class="flex items-center justify-center gap-1.5 text-xs text-gray-500 dark:text-gray-400 mb-6">
        <span>¿No te llegó el correo?</span>
        <button
          type="button"
          @click="handleResend"
          :disabled="cooldown > 0 || isResending || !email"
          class="font-semibold text-emerald-600 hover:text-emerald-700 dark:text-emerald-400 dark:hover:text-emerald-300 hover:underline inline-flex items-center gap-1 transition-colors disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
        >
          <span v-if="isResending">Enviando...</span>
          <span v-else-if="cooldown > 0">Reenviar en {{ cooldown }}s</span>
          <span v-else>Reenviar correo</span>
        </button>
      </div>

      <!-- Primary Action Button (Single Clean Button) -->
      <a
        :href="mailUrl"
        :target="isGmail ? '_blank' : undefined"
        class="w-full max-w-[320px] py-3.5 px-5 bg-emerald-500 hover:bg-emerald-600 active:scale-[0.99] text-white font-semibold rounded-2xl shadow-lg shadow-emerald-500/25 flex items-center justify-center gap-2.5 transition-all text-sm tracking-wide cursor-pointer"
      >
        <MailIcon class="w-5 h-5 stroke-[2]" />
        <span>Abrir mi Correo</span>
        <ExternalLink class="w-4 h-4 stroke-[2.2] ml-0.5" />
      </a>
    </main>

    <!-- Footer: Waiting confirmation status indicator with soft pulse -->
    <footer class="w-full flex flex-col items-center gap-2 pt-2 pb-6">
      <div class="inline-flex items-center gap-2 text-xs font-medium text-gray-500 dark:text-gray-400">
        <span class="relative flex h-2 w-2">
          <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-500 opacity-75"></span>
          <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
        </span>
        <span class="tracking-tight">Esperando confirmación...</span>
      </div>
    </footer>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '../../lib/supabase';
import { authRepository } from '../../data/repositories/authRepository';
import { 
  Mail as MailIcon, 
  ArrowLeft, 
  Check, 
  PenLine, 
  AlertCircle, 
  ExternalLink 
} from 'lucide-vue-next';
import { useAuthStore } from '../../stores/auth';
import { useToast } from 'vue-toastification';
import { logger } from '../../utils/logger';

const toast = useToast();

const router = useRouter();
const authStore = useAuthStore();
const email = ref<string>('');
const isResending = ref(false);
const cooldown = ref(0);
let intervalId: any = null;
let authSubscription: { unsubscribe: () => void } | null = null;

const isGmail = computed(() => email.value.toLowerCase().includes('@gmail.com'));

const mailUrl = computed(() => {
  if (isGmail.value) return 'https://mail.google.com';
  return 'mailto:';
});

const handleResend = async () => {
  if (cooldown.value > 0 || isResending.value) return;

  if (!email.value) {
    toast.error('No se detectó un correo asociado. Por favor inicia sesión o regístrate.');
    return;
  }
  
  isResending.value = true;
  try {
    const result = await authRepository.resendConfirmationEmail(email.value);
    
    if (result.success) {
      toast.success('Correo de confirmación reenviado exitosamente.');
      cooldown.value = 60;
      const timer = setInterval(() => {
        cooldown.value--;
        if (cooldown.value <= 0) clearInterval(timer);
      }, 1000);
    } else {
      if (result.code === 'RATE_LIMIT') {
        toast.warning(result.error || 'Espera unos momentos antes de intentar nuevamente.');
      } else {
        toast.error(result.error || 'Error al reenviar el correo.');
      }
    }
  } catch (err: any) {
    logger.error('Error resending email:', err);
    toast.error('Error de conexión al reenviar. Intenta más tarde.');
  } finally {
    isResending.value = false;
  }
};

const goToLogin = async () => {
  sessionStorage.removeItem('pending_verification_email');
  await authStore.logout();
  router.push('/login');
};

const goToRegister = async () => {
  sessionStorage.removeItem('pending_verification_email');
  await authStore.logout();
  router.push('/register-store');
};

const checkStatus = async () => {
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error) return;
  
  if (user?.email_confirmed_at) {
    await supabase.auth.refreshSession();
    router.replace({ name: 'dashboard' });
  }
};

onMounted(async () => {
  const routeEmail = router.currentRoute.value.query.email as string;
  const sessionEmail = sessionStorage.getItem('pending_verification_email');
  
  if (routeEmail) {
    email.value = routeEmail;
  } else if (sessionEmail) {
    email.value = sessionEmail;
  } else {
    const { data: { user } } = await supabase.auth.getUser();
    if (user?.email) {
      email.value = user.email;
    } else if (authStore.currentUser?.email) {
      email.value = authStore.currentUser.email;
    }
  }

  // Polling for verification
  intervalId = setInterval(checkStatus, 3000);
  
  // Cross-tab / same-browser confirmation listener
  const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
    if (event === 'SIGNED_IN' || (session?.user?.email_confirmed_at)) {
      await supabase.auth.refreshSession();
      router.replace({ name: 'dashboard' });
    }
  });
  authSubscription = subscription;
});

onUnmounted(() => {
  if (intervalId) clearInterval(intervalId);
  if (authSubscription) {
    authSubscription.unsubscribe();
    authSubscription = null;
  }
});
</script>

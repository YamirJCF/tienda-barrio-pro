<template>
  <div class="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
    <div class="sm:mx-auto sm:w-full sm:max-w-md">
      <div class="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10 text-center">
        <!-- Hero Icon -->
        <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-blue-100 mb-6">
          <MailIcon class="h-8 w-8 text-blue-600" />
        </div>

        <h2 class="text-2xl font-bold text-gray-900 mb-2">Revisa tu correo</h2>
        
        <p v-if="email" class="text-gray-600 mb-8">
          Hemos enviado un enlace de confirmación a <br>
          <strong class="text-gray-900">{{ email }}</strong>
        </p>
        <div v-else class="mb-8 p-3 bg-amber-50 rounded-lg border border-amber-200 text-amber-800 text-sm">
          No pudimos detectar tu correo de registro. Por favor regresa e intenta de nuevo.
        </div>

        <!-- Primary Actions -->
        <div class="space-y-4">
          <a
            v-if="isGmail"
            href="https://mail.google.com"
            target="_blank"
            class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition-colors"
          >
            Abrir Gmail
          </a>

          <a
            href="mailto:"
            class="w-full flex justify-center py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors"
          >
            Abrir Correo
          </a>
        </div>

        <!-- Secondary Actions -->
        <div class="mt-8 pt-6 border-t border-gray-100">
          <div class="text-sm">
            <span class="text-gray-500">¿No llegó el correo? </span>
            <button 
              @click="handleResend"
              :disabled="cooldown > 0 || isResending || !email"
              class="font-medium text-blue-600 hover:text-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <span v-if="isResending">Enviando...</span>
              <span v-else-if="cooldown > 0">Reenviar en {{ cooldown }}s</span>
              <span v-else>Reenviar correo</span>
            </button>
          </div>
          
          <div class="mt-4 text-xs">
            <button 
              @click="handleLogout"
              class="text-gray-400 hover:text-gray-600 underline"
            >
              ¿Te equivocaste de correo? Cerrar sesión
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '../../lib/supabase';
import { authRepository } from '../../data/repositories/authRepository';
import { Mail as MailIcon } from 'lucide-vue-next';
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

const isGmail = computed(() => email.value.includes('@gmail.com'));

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
      // Start cooldown
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

const handleLogout = async () => {
  sessionStorage.removeItem('pending_verification_email');
  await authStore.logout();
  router.push('/login');
};

const checkStatus = async () => {
  // FIX: Use getUser() (server call) instead of getSession() (local cache)
  // getSession() returns stale data that doesn't reflect server-side verification
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error) return; // Network error, skip this cycle
  
  if (user?.email_confirmed_at) {
    // User verified! Refresh local session so Router Guard sees updated state
    await supabase.auth.refreshSession();
    router.replace({ name: 'dashboard' });
  }
};

onMounted(async () => {
  // 1. Prioritize query param
  const routeEmail = router.currentRoute.value.query.email as string;
  // 2. Fallback to sessionStorage
  const sessionEmail = sessionStorage.getItem('pending_verification_email');
  
  if (routeEmail) {
    email.value = routeEmail;
  } else if (sessionEmail) {
    email.value = sessionEmail;
  } else {
    // 3. Fallback to Supabase user or store
    const { data: { user } } = await supabase.auth.getUser();
    if (user?.email) {
      email.value = user.email;
    } else if (authStore.currentUser?.email) {
      email.value = authStore.currentUser.email;
    }
  }

  // Polling for verification
  intervalId = setInterval(checkStatus, 3000);
  
  // Also listen to auth state changes (cross-tab detection)
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

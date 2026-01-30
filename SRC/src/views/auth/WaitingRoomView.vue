<template>
  <div class="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
    <div class="sm:mx-auto sm:w-full sm:max-w-md">
      <div class="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10 text-center">
        <!-- Hero Icon -->
        <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-blue-100 mb-6">
          <MailIcon class="h-8 w-8 text-blue-600" />
        </div>

        <h2 class="text-2xl font-bold text-gray-900 mb-2">Revisa tu correo</h2>
        
        <p class="text-gray-600 mb-8">
          Hemos enviado un enlace de confirmación a <br>
          <strong class="text-gray-900">{{ email }}</strong>
        </p>

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
              :disabled="cooldown > 0 || isResending"
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
import { supabase } from '../../lib/supabase'; // Access direct supabase client or via repo
import { Mail as MailIcon } from 'lucide-vue-next';
import { useAuthStore } from '../../stores/auth';

const router = useRouter();
const authStore = useAuthStore();
const email = ref<string>('');
const isResending = ref(false);
const cooldown = ref(0);
let intervalId: any = null;

const isGmail = computed(() => email.value.includes('@gmail.com'));

const handleResend = async () => {
  if (cooldown.value > 0) return;
  
  isResending.value = true;
  try {
    const { error } = await supabase.auth.resend({
      type: 'signup',
      email: email.value
    });
    
    if (error) throw error;
    
    // Start cooldown
    cooldown.value = 60;
    const timer = setInterval(() => {
      cooldown.value--;
      if (cooldown.value <= 0) clearInterval(timer);
    }, 1000);
    
  } catch (err) {
    console.error('Error resending email:', err);
    alert('Error al reenviar. Intenta más tarde.');
  } finally {
    isResending.value = false;
  }
};

const handleLogout = async () => {
  await authStore.logout();
  router.push('/login');
};

const checkStatus = async () => {
  const { data: { session } } = await supabase.auth.getSession();
  if (session?.user?.email_confirmed_at) {
    // User verified!
    router.push('/dashboard');
  }
};

onMounted(async () => {
  // Get current user email
  const { data: { user } } = await supabase.auth.getUser();
  if (user?.email) {
    email.value = user.email;
  } else {
    // If no user/session, maybe redirect to login? 
    // For waiting room, we assume they just signed up and might have a partial session or local state
    // But Supabase sign up returns session null if email confirmation enabled.
    // We might need to pass email via query param or store if session is null.
    // For now, let's try reading from authStore or query param
    const routeEmail = router.currentRoute.value.query.email as string;
    if (routeEmail) email.value = routeEmail;
  }

  // Polling for verification
  intervalId = setInterval(checkStatus, 3000);
  
  // Also listen to auth state changes
  supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_IN' || (session?.user?.email_confirmed_at)) {
      router.push('/dashboard');
    }
  });
});

onUnmounted(() => {
  if (intervalId) clearInterval(intervalId);
});
</script>

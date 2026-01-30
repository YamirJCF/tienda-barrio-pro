<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-50">
    <div class="text-center">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
      <h2 class="text-xl font-semibold text-gray-700">Verificando sesión...</h2>
      <p class="text-gray-500 text-sm mt-2">Por favor espera un momento.</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '../../lib/supabase';

const router = useRouter();

onMounted(() => {
  // Supabase-js automatically parses the #access_token from the URL
  // and establishes the session. We just need to give it a moment
  // and then redirect to the dashboard.
  
  // We listen for the SIGNED_IN event which usually fires after processing the hash
  const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'SIGNED_IN' || session) {
      router.replace('/dashboard');
    }
  });

  // Fallback: Check if we already have a session after a short delay
  // in case the event fired before we mounted (race condition)
  setTimeout(async () => {
    const { data: { session } } = await supabase.auth.getSession();
    if (session) {
      router.replace('/dashboard');
    } else {
      // If still no session, maybe the link was invalid or expired
      // router.replace('/login'); // Optional: redirect to login
    }
  }, 1000);
});
</script>

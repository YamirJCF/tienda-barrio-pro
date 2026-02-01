<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-50 p-4">
    <div class="text-center max-w-md w-full bg-white p-8 rounded-xl shadow-lg border border-gray-100" v-if="errorMessage">
       <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-red-50 mb-6">
         <!-- Lucide AlertCircle -->
         <svg class="h-8 w-8 text-red-500" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
       </div>
       <h3 class="text-xl font-bold text-gray-900 mb-3">Enlace Inválido</h3>
       <p class="text-base text-gray-600 mb-8 leading-relaxed">{{ errorMessage }}</p>
       <button @click="router.push('/login')" class="w-full inline-flex justify-center items-center px-6 py-3 border border-transparent rounded-lg shadow-sm text-base font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors">
         Volver al Login
       </button>
    </div>

    <div class="text-center" v-else>
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
      <h2 class="text-xl font-semibold text-gray-700">Verificando sesión...</h2>
      <p class="text-gray-500 text-sm mt-2">Por favor espera un momento.</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '../../lib/supabase';
import { useAuthStore } from '../../stores/auth';

const router = useRouter();
const authStore = useAuthStore();
const errorMessage = ref('');

onMounted(async () => {
  // Check for errors in hash (Supabase returns /#error=...)
  const hash = window.location.hash;
  
  if (hash.includes('error=')) {
      if (hash.includes('otp_expired')) {
          errorMessage.value = 'Este enlace ha expirado. Es posible que hayas solicitado uno nuevo posteriormente, lo cual invalida los anteriores.';
      } else {
           // Extract description if possible
           const match = hash.match(/error_description=([^&]*)/);
           if (match) {
               errorMessage.value = decodeURIComponent(match[1]).replace(/\+/g, ' ');
           } else {
               errorMessage.value = 'El enlace no es válido o ha sido usado.';
           }
      }
      return; // Stop processing
  }

  // Handles Supabase Auth Callback logic
  
  // 1. Listen for Supabase events (Standard flow)
  const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
    // CRITICAL: Handle Password Recovery
    if (event === 'PASSWORD_RECOVERY') {
       router.replace('/update-password');
       return;
    }

    if (event === 'SIGNED_IN' || session) {
      router.replace('/dashboard');
    }
  });

  // Manual hash parsing removed per security requirements
  // Flow relies strictly on supabase.auth.onAuthStateChange
});
</script>

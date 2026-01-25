<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { logger } from '../utils/logger';
import BaseInput from '@/components/ui/BaseInput.vue';
import BaseButton from '@/components/ui/BaseButton.vue';
import { LockOpen, Mail, CheckCircle } from 'lucide-vue-next';

const router = useRouter();

// State
const email = ref('');
const isSuccess = ref(false);
// isLoading handled by useAsyncAction

// Composable: Request Management
import { useAsyncAction } from '../composables/useAsyncAction';
const { execute: executeRecovery, isLoading } = useAsyncAction();

// Methods
const handleSubmit = async () => {
  if (!email.value) return;

  await executeRecovery(async () => {
      // Simulate API call
      await new Promise((resolve) => setTimeout(resolve, 1500));
      
      // If success
      isSuccess.value = true;
      logger.log('Password recovery email sent to:', email.value);
  }, {
      successMessage: 'Enlace enviado verificada tu correo',
      errorMessage: 'No se pudo enviar el correo. Intenta tarde',
      checkConnectivity: true
  });
};

const goBackToLogin = () => {
  router.push('/login');
};

const goToHome = () => {
  router.push('/login');
};
</script>

<template>
  <div
    class="bg-gray-50 dark:bg-background-dark min-h-screen flex flex-col items-center justify-center p-4"
  >
    <!-- Input State Card -->
    <main
      v-if="!isSuccess"
      class="w-full max-w-md bg-white dark:bg-[#1a2632] rounded-xl shadow-xl border border-slate-100 dark:border-slate-800 overflow-hidden relative"
    >
      <!-- Decorative top line -->
      <div class="h-1.5 w-full bg-primary"></div>

      <div class="p-6 sm:p-8 flex flex-col items-center text-center">
        <!-- Icon Container -->
        <div
          class="mb-6 flex items-center justify-center w-20 h-20 rounded-full bg-primary/10 text-primary"
        >
          <LockOpen :size="40" />
        </div>

        <!-- Header Section -->
        <header class="mb-6">
          <h1 class="text-2xl font-bold text-slate-900 dark:text-white mb-3 tracking-tight">
            Recuperar Acceso
          </h1>
          <p class="text-slate-600 dark:text-slate-400 text-base font-normal leading-relaxed">
            Ingresa el correo electrónico asociado a tu tienda. Te enviaremos un enlace seguro para
            restablecer tu contraseña.
          </p>
        </header>

        <!-- Form Section -->
        <form @submit.prevent="handleSubmit" class="w-full flex flex-col gap-5">
            <!-- Email Input Field -->
            <div class="text-left w-full">
                <BaseInput
                    v-model="email"
                    type="email"
                    id="email"
                    label="Correo Electrónico"
                    required
                    placeholder="ejemplo@tienda.com"
                >
                    <template #prefix>
                        <Mail :size="20" class="text-gray-400" />
                    </template>
                </BaseInput>
            </div>

          <!-- Primary Button -->
          <BaseButton
            type="submit"
            :loading="isLoading"
            :disabled="isLoading"
            variant="primary"
            class="w-full h-12 mt-2"
          >
            Enviar Enlace de Recuperación
          </BaseButton>

          <!-- Secondary Button -->
          <BaseButton
            type="button"
            @click="goBackToLogin"
            variant="ghost"
            class="w-full"
          >
            Volver al Login
          </BaseButton>
        </form>
      </div>
    </main>

    <!-- Success State Card -->
    <section
      v-else
      class="w-full max-w-md bg-white dark:bg-[#1a2632] rounded-xl shadow-xl border border-slate-100 dark:border-slate-800 overflow-hidden relative animate-[fadeIn_0.3s_ease-out]"
    >
      <div class="h-1.5 w-full bg-green-500"></div>

      <div class="p-6 sm:p-8 flex flex-col items-center text-center">
        <!-- Success Icon -->
        <div
          class="mb-6 flex items-center justify-center w-20 h-20 rounded-full bg-green-50 dark:bg-green-900/20 text-green-500"
        >
          <CheckCircle :size="48" />
        </div>

        <!-- Success Message -->
        <div class="mb-8">
          <h2 class="text-2xl font-bold text-slate-900 dark:text-white mb-3">¡Correo enviado!</h2>
          <p class="text-slate-600 dark:text-slate-400 text-base leading-relaxed">
            Revisa tu bandeja de entrada (y spam) para continuar.
          </p>
        </div>

        <!-- Back to Home Button -->
        <BaseButton
          @click="goToHome"
          variant="secondary"
          class="w-full h-12"
        >
          Volver al inicio
        </BaseButton>
      </div>
    </section>
  </div>
</template>

<style scoped>
@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }

  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>

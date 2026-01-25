<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { Store, Eye, EyeOff, User, Lock } from 'lucide-vue-next';
import { useAuthStore } from '../stores/auth';
import { useEmployeesStore } from '../stores/employees';
import { useRateLimiter } from '../composables/useRateLimiter'; // WO-004 T4.4
import BaseButton from '@/components/ui/BaseButton.vue';
import BaseInput from '@/components/ui/BaseInput.vue';

const router = useRouter();
const authStore = useAuthStore();
const employeesStore = useEmployeesStore();

// WO-004 T4.4: Rate Limiting
const {
  isLocked,
  remainingAttempts,
  remainingLockoutSeconds,
  canAttempt,
  recordFailedAttempt,
  recordSuccess,
} = useRateLimiter();

const username = ref('');
const password = ref('');
const showPassword = ref(false);
const errorMessage = ref('');
// isLoading handled by useAsyncAction

// SPEC-005: Detectar tipo de usuario basado en presencia de @
const isAdminLogin = computed(() => username.value.includes('@'));
const credentialLabel = computed(() => (isAdminLogin.value ? 'Contraseña' : 'PIN'));
const credentialPlaceholder = computed(() => (isAdminLogin.value ? '••••••••' : '••••'));

// Composable: Request Management
import { useAsyncAction } from '../composables/useAsyncAction';
const { execute: executeLogin, isLoading } = useAsyncAction();

const handleLogin = async () => {
  errorMessage.value = '';

  // WO-004 T4.4: Check rate limit before attempting
  if (!canAttempt()) {
    errorMessage.value = `🔒 Demasiados intentos. Espera ${remainingLockoutSeconds.value}s`;
    return;
  }

  await executeLogin(async () => {
    // UX Delay
    await new Promise((resolve) => setTimeout(resolve, 300));

    // 1. VALIDACIÓN PREVENTIVA: ¿Existe tienda?
    if (!authStore.hasStores) {
      throw new Error('No se detecta una tienda registrada en este dispositivo.');
    }

    // SPEC-005: Flujo basado en detección automática
    if (isAdminLogin.value) {
      // =============================================
      // FLUJO ADMIN (contiene @)
      // =============================================
      if (authStore.loginWithCredentials(username.value, password.value)) {
        // Admin siempre tiene acceso completo
        authStore.setDeviceStatus('approved');
        recordSuccess(); 
        router.push('/');
        return;
      }
      recordFailedAttempt();
      // Throwing error for useAsyncAction to handle
      throw new Error(`Correo o contraseña incorrectos (${remainingAttempts.value} intentos restantes)`);
    } else {
      // =============================================
      // FLUJO EMPLEADO (sin @) - PIN de 4 dígitos
      // =============================================
      const firstStore = authStore.getFirstStore();
      if (!firstStore) {
        throw new Error('No hay tienda configurada');
      }

      // OPCIÓN A: Primero intentar login LOCAL usando employeesStore
      const localEmployee = employeesStore.validatePin(username.value, password.value);
      
      if (localEmployee) {
        // Login local exitoso
        authStore.loginAsEmployee(
          {
            id: localEmployee.id,
            name: localEmployee.name,
            username: localEmployee.username,
            permissions: localEmployee.permissions,
          },
          firstStore.id,
        );

        authStore.setDeviceStatus('approved');
        recordSuccess();
        router.push('/');
        return;
      }

      // Si no hay empleado local, mostrar error
      recordFailedAttempt();
      throw new Error(`Usuario o PIN incorrectos (${remainingAttempts.value} intentos restantes)`);
    }
  }, {
    // Options
    checkConnectivity: true, // Login requires internet (mostly) or we want strict check
    errorMessage: '', // We use dynamic error throwing above, so fallback is fine
    showSuccessToast: false // Login typically doesn't need "Success" toast, just redirect
  });
};

// SPEC-005: Simular respuesta del servidor (reemplazar con RPC real)
type ServerResponse = {
  success: boolean;
  employee?: {
    id: string;
    name: string;
    username: string;
    permissions: any; // Keep 'any' for nested permissions or strictly type it if possible
  };
  store_state?: { is_open: boolean };
  error_code?: string;
  error?: string;
};

const simulateServerResponse = (employee: any, fingerprint: string): ServerResponse => {
  // En producción, esto sería la respuesta del RPC login_empleado_unificado
  // Por ahora simulamos éxito
  return {
    success: true,
    employee: employee,
    store_state: { is_open: true }, // Simular tienda abierta
  };
};

// SPEC-005: Manejar códigos de error del servidor
const handleServerError = (errorCode: string, errorMsg: string) => {
  const errorMessages: Record<string, string> = {
    ACCOUNT_LOCKED: '🔒 Cuenta bloqueada. Intenta en 15 minutos.',
    GATEKEEPER_PENDING: '📱 Dispositivo en espera de aprobación del Administrador.',
    GATEKEEPER_REJECTED: '🚫 Acceso denegado desde este dispositivo.',
    INVALID_CREDENTIALS: 'Usuario o PIN incorrectos.',
  };

  errorMessage.value = errorMessages[errorCode] || errorMsg || 'Error desconocido';

  // Para dispositivo pendiente, mostrar estado especial
  if (errorCode === 'GATEKEEPER_PENDING') {
    authStore.setDeviceStatus('pending');
  } else if (errorCode === 'GATEKEEPER_REJECTED') {
    authStore.setDeviceStatus('rejected');
  }
};
</script>

<template>
  <div class="flex flex-col items-center justify-center min-h-screen p-6">
    <div class="w-full max-w-[400px] flex flex-col gap-8">
      <div class="flex flex-col items-center text-center gap-4">
        <div
          class="w-20 h-20 bg-primary/10 dark:bg-primary/20 rounded-full flex items-center justify-center text-primary mb-2">
          <Store :size="40" />
        </div>
        <div class="space-y-1">
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white tracking-tight font-display">
            Tienda de Barrio
          </h1>
          <p class="text-base text-gray-500 dark:text-gray-400">Bienvenido de nuevo</p>
        </div>
      </div>

      <div
        class="bg-surface-light dark:bg-surface-dark p-6 rounded-xl shadow-md border border-gray-100 dark:border-gray-800">
        <form @submit.prevent="handleLogin" class="flex flex-col gap-5">
          <BaseInput 
            v-model="username" 
            label="Usuario" 
            placeholder="Tu usuario o correo"
            :disabled="isLoading"
          >
            <template #prefix>
               <User :size="18" class="text-slate-400" />
            </template>
          </BaseInput>

          <div class="relative">
            <BaseInput 
              v-model="password" 
              :type="showPassword ? 'text' : 'password'" 
              :label="credentialLabel"
              :placeholder="credentialPlaceholder" 
              :disabled="isLoading" 
            >
              <template #prefix>
                 <Lock :size="18" class="text-slate-400" />
              </template>
            </BaseInput>
            <button type="button" @click="showPassword = !showPassword"
              class="absolute top-[29px] right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 focus:outline-none"
              tabindex="-1">
              <Eye v-if="!showPassword" :size="20" />
              <EyeOff v-else :size="20" />
            </button>
          </div>

          <div class="flex justify-end">
            <router-link to="/forgot-password"
              class="text-sm font-medium text-gray-500 hover:text-primary dark:text-gray-400 dark:hover:text-primary transition-colors">
              ¿Olvidaste tu contraseña?
            </router-link>
          </div>

          <!-- Error message -->
          <div v-if="errorMessage"
            class="p-3 rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800">
            <p class="text-sm text-red-600 dark:text-red-400 text-center font-medium">
              {{ errorMessage }}
            </p>
          </div>

          <BaseButton type="submit" variant="primary" size="lg" class="w-full mt-2" :loading="isLoading"
            :disabled="isLoading">
            Ingresar
          </BaseButton>
        </form>
      </div>

      <div class="text-center">
        <p class="text-sm text-gray-600 dark:text-gray-400">
          ¿No tienes cuenta?
          <router-link to="/register-store"
            class="font-bold text-primary hover:text-primary-dark transition-colors ml-1">
            Crea tu tienda aquí
          </router-link>
        </p>
      </div>
    </div>
  </div>
</template>

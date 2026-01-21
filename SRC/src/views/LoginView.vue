<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { Store, Eye, EyeOff } from 'lucide-vue-next';
import { useAuthStore } from '../stores/auth';
import { useEmployeesStore } from '../stores/employees';
import { useDeviceFingerprint } from '../composables/useDeviceFingerprint';
import { useRateLimiter } from '../composables/useRateLimiter'; // WO-004 T4.4
import { logger } from '../utils/logger';
import BaseButton from '@/components/ui/BaseButton.vue';
import BaseInput from '@/components/ui/BaseInput.vue';

const router = useRouter();
const authStore = useAuthStore();
const employeesStore = useEmployeesStore();
const { getFingerprint } = useDeviceFingerprint();

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
const isLoading = ref(false);

// SPEC-005: Detectar tipo de usuario basado en presencia de @
const isAdminLogin = computed(() => username.value.includes('@'));
const credentialLabel = computed(() => (isAdminLogin.value ? 'Contraseña' : 'PIN'));
const credentialPlaceholder = computed(() => (isAdminLogin.value ? '••••••••' : '••••'));

const handleLogin = async () => {
  errorMessage.value = '';
  isLoading.value = true;

  // WO-004 T4.4: Check rate limit before attempting
  if (!canAttempt()) {
    errorMessage.value = `🔒 Demasiados intentos. Espera ${remainingLockoutSeconds.value}s`;
    isLoading.value = false;
    return;
  }

  try {
    // UX Delay
    await new Promise((resolve) => setTimeout(resolve, 300));

    // 1. VALIDACIÓN PREVENTIVA: ¿Existe tienda?
    if (!authStore.hasStores) {
      errorMessage.value = 'No se detecta una tienda registrada en este dispositivo.';
      return;
    }

    // SPEC-005: Flujo basado en detección automática
    if (isAdminLogin.value) {
      // =============================================
      // FLUJO ADMIN (contiene @)
      // =============================================
      if (authStore.loginWithCredentials(username.value, password.value)) {
        // Admin siempre tiene acceso completo
        authStore.setDeviceStatus('approved');
        authStore.setStoreOpenStatus(true); // Admins controlan la tienda
        recordSuccess(); // WO-004 T4.4: Reset rate limiter on success
        router.push('/');
        return;
      }
      recordFailedAttempt(); // WO-004 T4.4: Record failed attempt
      errorMessage.value = `Correo o contraseña incorrectos (${remainingAttempts.value} intentos restantes)`;
    } else {
      // =============================================
      // FLUJO EMPLEADO (sin @) - PIN de 4 dígitos
      // =============================================
      const firstStore = authStore.getFirstStore();
      if (!firstStore) {
        errorMessage.value = 'No hay tienda configurada';
        return;
      }

      // Obtener fingerprint del dispositivo
      const fingerprint = await getFingerprint();
      logger.log('[Login] Fingerprint:', fingerprint.substring(0, 16) + '...');

      // Validar credenciales localmente (simulación - en producción sería RPC)
      const employee = employeesStore.validatePin(username.value, password.value);

      if (employee) {
        // Simular respuesta del servidor con diferentes estados
        // En producción esto vendría del RPC login_empleado_unificado
        const mockServerResponse = simulateServerResponse(employee, fingerprint);

        if (!mockServerResponse.success) {
          handleServerError(mockServerResponse.error_code, mockServerResponse.error);
          return;
        }

        // Login exitoso
        authStore.loginAsEmployee(
          {
            id: employee.id,
            name: employee.name,
            username: employee.username,
            permissions: employee.permissions,
          },
          firstStore.id,
        );

        // Establecer estados IAM
        authStore.setDeviceStatus('approved');

        // SPEC-006: Si tiene permiso de caja, ignorar estado del servidor y permitir gestión
        // "El sistema no valida con el admin si no que pasa directo"
        if (employee.permissions.canOpenCloseCash) {
          console.log('[Login] Empleado con permiso de caja: Acceso directo permitido');
          // Mantener el estado real de la tienda (cerrada/abierta) para que la UI de apertura aparezca
          authStore.setStoreOpenStatus(mockServerResponse.store_state?.is_open ?? false);
        } else {
          authStore.setStoreOpenStatus(mockServerResponse.store_state?.is_open ?? false);
        }

        recordSuccess(); // WO-004 T4.4: Reset rate limiter on success
        router.push('/');
        return;
      }

      recordFailedAttempt(); // WO-004 T4.4: Record failed attempt
      errorMessage.value = `Usuario o PIN incorrectos (${remainingAttempts.value} intentos restantes)`;
    }
  } catch (error) {
    console.error('[Login] Error:', error);
    errorMessage.value = 'Error al iniciar sesión. Intenta nuevamente.';
  } finally {
    isLoading.value = false;
  }
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
          <BaseInput v-model="username" label="Usuario" icon="person" placeholder="Tu usuario o correo"
            :disabled="isLoading" />

          <div class="relative">
            <BaseInput v-model="password" :type="showPassword ? 'text' : 'password'" label="Contraseña" icon="lock"
              placeholder="••••••••" :disabled="isLoading" />
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

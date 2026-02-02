<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { Store, Eye, EyeOff, User, Lock, ArrowLeft, ChevronRight } from 'lucide-vue-next';
import { useAuthStore } from '../stores/auth';
import { authRepository } from '../data/repositories/authRepository';
import { useRateLimiter } from '../composables/useRateLimiter'; // WO-004 T4.4
import BaseButton from '@/components/ui/BaseButton.vue';
import BaseInput from '@/components/ui/BaseInput.vue';
import PinKeypad from '../components/PinKeypad.vue';
import GatekeeperPending from './GatekeeperPending.vue';

const router = useRouter();
const authStore = useAuthStore();

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
const employeeContext = ref<any>(null); // Store info for employee login
// isLoading handled by useAsyncAction

// SPEC-005: Detectar tipo de usuario basado en presencia de @
const isAdminLogin = computed(() => username.value.includes('@'));
const credentialLabel = computed(() => (isAdminLogin.value ? 'Contraseña' : 'PIN'));
const credentialPlaceholder = computed(() => (isAdminLogin.value ? '••••••••' : '••••'));

// Composable: Request Management
import { useAsyncAction } from '../composables/useAsyncAction';
const { execute: executeLogin, isLoading } = useAsyncAction();

// WO-003: Progressive Login State
const currentStep = ref<'identity' | 'credential'>('identity');

const handleContinue = async () => {
  if (!username.value.trim()) {
      errorMessage.value = 'Por favor ingresa tu usuario o correo';
      return;
  }
  errorMessage.value = '';

  // ZERO-AUTH: Resolve Alias if Employee
  if (!isAdminLogin.value) {
    isLoading.value = true;
    try {
        const result = await authRepository.getEmployeePublicInfo(username.value);
        isLoading.value = false;
        
        if (!result.success || !result.data) {
            errorMessage.value = 'Alias de empleado no encontrado';
            return;
        }
        
        employeeContext.value = result.data;
        // Proceed
        currentStep.value = 'credential';
    } catch (e) {
        isLoading.value = false;
        errorMessage.value = 'Error verificando alias';
    }
  } else {
     currentStep.value = 'credential';
  }
};

const handleBack = () => {
  errorMessage.value = '';
  password.value = '';
  currentStep.value = 'identity';
};

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

    // 1. VALIDACIÓN PREVENTIVA: Eliminada.
    // El login valida contra Supabase directamente.
    
    // SPEC-005: Flujo basado en detección automática
    if (isAdminLogin.value) {
      // =============================================
      // FLUJO ADMIN (contiene @)
      // =============================================
      const success = await authStore.login(username.value, password.value);
      
      if (success) {
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
      // FLUJO EMPLEADO (sin @) - PIN de 4 dígitos (Zero-Auth)
      // =============================================
      
      const fingerprint = await authStore.dailyAccessState.fingerprint || 'unknown-device'; // Should be handled by repo, but passing simple string
      
      const result = await authRepository.requestEmployeeAccess(
        username.value,
        password.value,
        fingerprint
      );

      if (result.success) {
         if (result.status === 'approved') {
             // Access Granted
             authStore.loginAsEmployee(
                 {
                    id: result.employee.id,
                    name: result.employee.name,
                    username: username.value,
                    permissions: result.employee.permissions || {}
                 },
                 result.employee.store_id
             );
             
             authStore.setDeviceStatus('approved');
             recordSuccess();
             router.push('/');
             return;
         } else if (result.status === 'pending') {
             // Pending Approval
             // We need to set state so GatekeeperPending component picks it up
             authStore.setDeviceStatus('pending');
             
             // Store PASS_ID for polling
             if (result.pass_id) {
                 authStore.dailyAccessState.passId = result.pass_id;
             }
             
             return; // UI updates automatically via reactive state
         } else {
             throw new Error(result.message || 'Acceso denegado');
         }
      }

      // Si falló logicamente (PIN mal)
      recordFailedAttempt();
      throw new Error(result.message || result.error_code || 'PIN Incorrecto o Error de acceso');
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
    <!-- WO-PHASE4-001: Show Waiting Room if Pending/Rejected -->
    <GatekeeperPending 
      v-if="authStore.deviceApproved === 'pending' || authStore.deviceApproved === 'rejected'"
    />

    <div v-else class="w-full max-w-[400px] flex flex-col gap-8">
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
        class="bg-surface-light dark:bg-surface-dark p-6 rounded-xl shadow-md border border-gray-100 dark:border-gray-800 transition-all duration-300 ease-in-out"
      >
        <form @submit.prevent="handleLogin" class="flex flex-col gap-5 relative overflow-hidden min-h-[300px]">
           
           <!-- Transition Wrapper -->
           <Transition mode="out-in" name="slide-fade">
             
             <!-- STEP 1: IDENTITY -->
             <div v-if="currentStep === 'identity'" key="identity" class="flex flex-col gap-5 w-full">
                <div class="space-y-1">
                   <h2 class="text-sm font-semibold text-gray-700 dark:text-gray-300">Empecemos</h2>
                   <p class="text-xs text-gray-500">Ingresa tu usuario o correo para continuar</p>
                </div>

                <BaseInput 
                  v-model="username" 
                  label="Usuario" 
                  placeholder="ej. admin@mitienda.com"
                  autofocus
                  @keydown.enter.prevent="handleContinue"
                >
                  <template #prefix>
                    <User :size="18" class="text-slate-400" />
                  </template>
                </BaseInput>

                <!-- WO-003: Link Create Store in Step 1 -->
                <div class="text-center -mt-2">
                    <router-link to="/register-store"
                      class="text-xs font-semibold text-primary hover:text-primary-dark transition-colors">
                      ¿No tienes cuenta? Crea tu tienda
                    </router-link>
                </div>

                 <BaseButton 
                    type="button" 
                    variant="primary" 
                    size="lg" 
                    class="w-full mt-2" 
                    @click="handleContinue"
                    :icon="ChevronRight"
                    icon-pos="right"
                  >
                  Continuar
                </BaseButton>
             </div>

             <!-- STEP 2: CREDENTIAL -->
             <div v-else key="credential" class="flex flex-col w-full">
                <!-- User Context Header -->
                <div class="flex items-center gap-3 bg-gray-50 dark:bg-gray-800/50 p-3 rounded-lg border border-gray-100 dark:border-gray-700 mb-6">
                    <div class="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-lg">
                        {{ username.slice(0, 1).toUpperCase() }}
                    </div>
                    <div class="flex-1 overflow-hidden">
                        <p class="text-xs text-gray-500 font-medium">Accediendo como</p>
                        <p class="text-sm font-bold text-gray-900 dark:text-gray-100 truncate">
                            {{ employeeContext ? employeeContext.name : username }}
                        </p>
                        <p v-if="employeeContext" class="text-xs text-primary font-medium truncate">
                            {{ employeeContext.store_name }}
                        </p>
                    </div>
                    <button 
                      type="button" 
                      @click="handleBack"
                      class="p-2 hover:bg-gray-200 dark:hover:bg-gray-700 rounded-full text-gray-500 transition-colors"
                      title="Cambiar usuario"
                    >
                      <ArrowLeft :size="18" />
                    </button>
                </div>

                <!-- Admin Password Input -->
                <div v-if="isAdminLogin" class="flex flex-col gap-4">
                     <div class="relative">
                        <BaseInput 
                          v-model="password" 
                          :type="showPassword ? 'text' : 'password'" 
                          label="Contraseña"
                          placeholder="Ingresa tu contraseña" 
                          :disabled="isLoading" 
                          autofocus
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

                      <!-- Forgot Password Link (Admin Only) -->
                      <div class="flex justify-end">
                        <router-link to="/forgot-password"
                          class="text-xs font-medium text-gray-500 hover:text-primary dark:text-gray-400 dark:hover:text-primary transition-colors">
                          ¿Olvidaste tu contraseña?
                        </router-link>
                      </div>
                </div>

                <!-- Employee PIN Pad -->
                <div v-else class="flex flex-col items-center animate-in fade-in slide-in-from-bottom-4 duration-500">
                    <span class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-4">Ingresa tu PIN de acceso</span>
                    <PinKeypad
                        :length="4"
                        :error="errorMessage"
                        :disabled="isLoading"
                        @change="(pin) => password = pin"
                        @complete="handleLogin"
                    />
                </div>

                <!-- Login Button (Only visible for Admin, PIN auto-submits) -->
                <BaseButton 
                  v-if="isAdminLogin"
                  type="submit" 
                  variant="primary" 
                  size="lg" 
                  class="w-full mt-6" 
                  :loading="isLoading"
                  :disabled="isLoading"
                >
                  Ingresar
                </BaseButton>

             </div>
           </Transition>

          <!-- Global Error message -->
          <div v-if="errorMessage"
            class="p-3 rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 animate-pulse">
            <p class="text-sm text-red-600 dark:text-red-400 text-center font-medium">
              {{ errorMessage }}
            </p>
          </div>

        </form>
      </div>
      
      <!-- Footer links removed from here as they are integrated in steps -->
    </div>

  </div>
</template>

<style scoped>
.slide-fade-enter-active {
  transition: all 0.3s ease-out;
}

.slide-fade-leave-active {
  transition: all 0.2s cubic-bezier(1, 0.5, 0.8, 1);
}

.slide-fade-enter-from {
  transform: translateX(20px);
  opacity: 0;
}

.slide-fade-leave-to {
  transform: translateX(-20px);
  opacity: 0;
}
</style>

<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { Store, User, Lock, Eye, EyeOff } from 'lucide-vue-next';
import { useAuthStore } from '../stores/auth';
import { useEmployeesStore } from '../stores/employees';

const router = useRouter();
const authStore = useAuthStore();
const employeesStore = useEmployeesStore();

const username = ref('');
const password = ref('');
const showPassword = ref(false);
const errorMessage = ref('');
const isLoading = ref(false);

const handleLogin = async () => {
  errorMessage.value = '';
  isLoading.value = true;

  // UX Delay
  await new Promise(resolve => setTimeout(resolve, 300));

  // 1. VALIDACIÓN PREVENTIVA: ¿Existe tienda?
  if (!authStore.hasStores) {
    isLoading.value = false;
    errorMessage.value = 'No se detecta una tienda registrada en este dispositivo.';
    return;
  }

  // 2. Intento Admin
  if (authStore.loginWithCredentials(username.value, password.value)) {
    router.push('/');
    return;
  }

  // 3. Intento Empleado (Fail-Safe)
  const firstStore = authStore.getFirstStore();
  if (firstStore) {
    const employee = employeesStore.validatePin(username.value, password.value);
    if (employee) {
      authStore.loginAsEmployee({
        id: employee.id,
        name: employee.name,
        username: employee.username,
        permissions: employee.permissions,
      }, firstStore.id);
      router.push('/');
      return;
    }
  }

  isLoading.value = false;
  errorMessage.value = 'Credenciales inválidas o cuenta no autorizada';
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
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white tracking-tight font-display">Tienda de Barrio</h1>
          <p class="text-base text-gray-500 dark:text-gray-400">Bienvenido de nuevo</p>
        </div>
      </div>

      <div
        class="bg-surface-light dark:bg-surface-dark p-6 rounded-xl shadow-md border border-gray-100 dark:border-gray-800">
        <form @submit.prevent="handleLogin" class="flex flex-col gap-5">
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Usuario</label>
            <div class="relative group">
              <div
                class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 group-focus-within:text-primary transition-colors">
                <User :size="20" />
              </div>
              <input v-model="username" type="text"
                class="block w-full pl-10 pr-3 py-3 rounded-lg border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-white placeholder-gray-400 focus:border-primary focus:ring-primary focus:ring-1 sm:text-base transition-all outline-none"
                placeholder="Tu usuario o correo" />
            </div>
          </div>

          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-medium text-gray-700 dark:text-gray-300 ml-1">Contraseña</label>
            <div class="relative group">
              <div
                class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-gray-400 group-focus-within:text-primary transition-colors">
                <Lock :size="20" />
              </div>
              <input v-model="password" :type="showPassword ? 'text' : 'password'"
                class="block w-full pl-10 pr-12 py-3 rounded-lg border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-white placeholder-gray-400 focus:border-primary focus:ring-primary focus:ring-1 sm:text-base transition-all outline-none"
                placeholder="••••••••" />
              <button type="button" @click="showPassword = !showPassword"
                class="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 focus:outline-none">
                <Eye v-if="!showPassword" :size="20" />
                <EyeOff v-else :size="20" />
              </button>
            </div>
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

          <button type="submit"
            class="w-full flex justify-center py-3.5 px-4 border border-transparent rounded-lg shadow-sm text-base font-bold text-white bg-primary hover:bg-primary-dark focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary transition-all disabled:opacity-70 disabled:cursor-not-allowed mt-2">
            Ingresar
          </button>
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
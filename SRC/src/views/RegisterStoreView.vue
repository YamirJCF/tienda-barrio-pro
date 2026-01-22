<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { logger } from '../utils/logger';
import BaseInput from '@/components/ui/BaseInput.vue';
import BaseButton from '@/components/ui/BaseButton.vue';

const router = useRouter();
const authStore = useAuthStore();

// ============================================
// FORM STATE
// ============================================
const storeName = ref('');
const ownerName = ref('');
const email = ref('');
const password = ref('');
const confirmPassword = ref('');
// SPEC-006: PIN eliminado del registro, se configura en AdminHub
const showPassword = ref(false);
const showConfirmPassword = ref(false);

// ============================================
// UI STATE
// ============================================
const errorMessage = ref('');
const isLoading = ref(false);

// ============================================
// VALIDATION RULES
// ============================================
// Regex para validación estricta de email
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Computed validations
const isStoreNameValid = computed(() => storeName.value.trim().length >= 3);
const isOwnerNameValid = computed(() => ownerName.value.trim().length > 0);
const isEmailValid = computed(() => emailRegex.test(email.value.trim()));
const isPasswordValid = computed(() => password.value.length >= 6);
// T-004: Validación de confirmación de contraseña
const isConfirmPasswordValid = computed(
  () => confirmPassword.value.length >= 6 && confirmPassword.value === password.value,
);
// SPEC-006: PIN ya no se valida en registro

// Botón habilitado solo si todo es válido y no está cargando
const canSubmit = computed(() => {
  return (
    isStoreNameValid.value &&
    isOwnerNameValid.value &&
    isEmailValid.value &&
    isPasswordValid.value &&
    isConfirmPasswordValid.value && // T-004: Agregado
    !isLoading.value
  );
});

// ============================================
// NAVIGATION METHODS
// ============================================
const goBack = () => {
  router.back();
};

// SPEC-006: Keypad handlers eliminados (PIN se configura en AdminHub)

// ============================================
// PASSWORD VISIBILITY TOGGLE
// ============================================
const togglePassword = () => {
  showPassword.value = !showPassword.value;
};

// T-004: Toggle para confirmar contraseña
const toggleConfirmPassword = () => {
  showConfirmPassword.value = !showConfirmPassword.value;
};

// ============================================
// FORM SUBMISSION (ASYNC + ERROR HANDLING)
// ============================================
const handleSubmit = async () => {
  // Guard clause: previene doble-click y envíos inválidos
  if (!canSubmit.value || isLoading.value) return;

  isLoading.value = true;
  errorMessage.value = '';

  try {
    // Espera artificial para:
    // 1. Dar feedback visual (spinner/loading state)
    // 2. Asegurar que localStorage complete la escritura antes de navegar
    await new Promise((resolve) => setTimeout(resolve, 600));

    // Intentar registro en el store
    const result = authStore.registerStore({
      storeName: storeName.value.trim(),
      ownerName: ownerName.value.trim(),
      email: email.value.trim().toLowerCase(),
      password: password.value,
      // SPEC-006: PIN eliminado del registro
    });

    if (result) {
      logger.log('✅ Tienda registrada exitosamente:', result.storeName);
      // Redirección al Dashboard
      router.push('/');
    } else {
      // Email duplicado (único error conocido del store)
      errorMessage.value = 'Este correo electrónico ya está registrado.';
      isLoading.value = false;
    }
  } catch (error) {
    // Captura errores inesperados (quota de localStorage, etc.)
    console.error('❌ Error crítico en registro:', error);
    errorMessage.value = 'Error del sistema. Por favor, intenta nuevamente.';
    isLoading.value = false;
  }
};
</script>

<template>
  <div
    class="bg-[#f8fcfb] dark:bg-[#0f231d] min-h-screen text-[#0d1c17] dark:text-white font-display"
  >
    <!-- Header -->
    <header
      class="sticky top-0 z-50 bg-[#f8fcfb]/95 dark:bg-[#0f231d]/95 backdrop-blur-sm border-b border-[#cee9e0]/30"
    >
      <div class="flex items-center px-4 h-16 max-w-lg mx-auto">
        <button
          @click="goBack"
          aria-label="Volver"
          class="flex items-center justify-center w-10 h-10 -ml-2 rounded-full active:bg-gray-100 dark:active:bg-white/10 text-[#0d1c17] dark:text-white transition-colors"
        >
          <span class="material-symbols-outlined text-2xl">arrow_back_ios_new</span>
        </button>
        <h1 class="flex-1 text-center text-lg font-bold tracking-tight pr-8">
          Registra tu Negocio
        </h1>
      </div>
    </header>

    <main class="flex flex-col w-full max-w-lg mx-auto pb-10">
      <!-- Section 1: Tu Negocio -->
      <section class="px-5 pt-6 animate-[fadeIn_0.3s_ease-out]">
        <h2 class="text-xl font-bold text-[#0d1c17] dark:text-white mb-4 flex items-center gap-2">
          <span
            class="bg-emerald-500/10 text-emerald-600 w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold"
            >1</span
          >
          Tu Negocio
        </h2>
        <div class="space-y-5">
          <div class="flex flex-col gap-1.5">
            <label
              class="text-sm font-semibold text-[#0d1c17] dark:text-gray-200 ml-1"
              for="storeName"
              >Nombre de la Tienda</label
            >
            <div class="relative">
              <BaseInput
                v-model="storeName"
                id="storeName"
                placeholder="Ej. Abastos La Estrella"
                :icon="isStoreNameValid ? 'check_circle' : undefined"
                :class="{'text-emerald-500': isStoreNameValid}"
              />
  
            </div>
            <p class="text-xs text-[#489d82] dark:text-gray-400 ml-1">
              Así aparecerá en tus recibos digitales.
            </p>
          </div>

          <div class="flex flex-col gap-1.5">
            <label
              class="text-sm font-semibold text-[#0d1c17] dark:text-gray-200 ml-1"
              for="ownerName"
              >Nombre del Dueño</label
            >
            <BaseInput
              v-model="ownerName"
              id="ownerName"
              placeholder="Ej. Juan Pérez"
            />
            <p class="text-xs text-[#489d82] dark:text-gray-400 ml-1">
              Para dirigirnos a ti personalmente.
            </p>
          </div>
        </div>
      </section>

      <div class="h-px bg-[#cee9e0]/50 dark:bg-white/10 my-6 mx-5"></div>

      <!-- Section 2: Tus Credenciales -->
      <section class="px-5 animate-[fadeIn_0.4s_ease-out]">
        <h2 class="text-xl font-bold text-[#0d1c17] dark:text-white mb-4 flex items-center gap-2">
          <span
            class="bg-emerald-500/10 text-emerald-600 w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold"
            >2</span
          >
          Tus Credenciales
        </h2>
        <div class="space-y-5">
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-semibold text-[#0d1c17] dark:text-gray-200 ml-1" for="email"
              >Correo Electrónico</label
            >
            <BaseInput
                v-model="email"
                type="email"
                id="email"
                icon="mail"
                placeholder="tucorreo@ejemplo.com"
            />
          </div>

          <div class="flex flex-col gap-1.5">
            <label
              class="text-sm font-semibold text-[#0d1c17] dark:text-gray-200 ml-1"
              for="password"
              >Contraseña</label
            >
            <div class="relative">
              <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400">
                <span class="material-symbols-outlined text-xl">lock</span>
              </span>
              <input
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                id="password"
                class="w-full pl-11 pr-11 bg-white dark:bg-white/5 border border-[#cee9e0] dark:border-white/10 rounded-xl px-4 py-3.5 text-base outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500 transition-all placeholder:text-gray-400 dark:placeholder:text-gray-500"
                placeholder="Mínimo 6 caracteres"
              />
              <button
                type="button"
                @click="togglePassword"
                class="absolute right-0 top-0 bottom-0 px-4 flex items-center text-gray-400 hover:text-emerald-500 transition-colors focus:outline-none"
              >
                <span class="material-symbols-outlined text-xl">{{
                  showPassword ? 'visibility_off' : 'visibility'
                }}</span>
              </button>
            </div>
          </div>

          <!-- T-004: Campo Confirmar Contraseña -->
          <div class="flex flex-col gap-1.5">
            <label
              class="text-sm font-semibold text-[#0d1c17] dark:text-gray-200 ml-1"
              for="confirmPassword"
              >Confirmar Contraseña</label
            >
            <div class="relative">
              <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400">
                <span class="material-symbols-outlined text-xl">lock</span>
              </span>
              <input
                v-model="confirmPassword"
                :type="showConfirmPassword ? 'text' : 'password'"
                id="confirmPassword"
                class="w-full pl-11 pr-11 bg-white dark:bg-white/5 border rounded-xl px-4 py-3.5 text-base outline-none transition-all placeholder:text-gray-400 dark:placeholder:text-gray-500"
                :class="
                  confirmPassword.length > 0
                    ? isConfirmPasswordValid
                      ? 'border-emerald-500 focus:ring-emerald-500'
                      : 'border-red-400 focus:ring-red-400'
                    : 'border-[#cee9e0] dark:border-white/10 focus:border-emerald-500 focus:ring-emerald-500'
                "
                placeholder="Repite tu contraseña"
              />
              <button
                type="button"
                @click="toggleConfirmPassword"
                class="absolute right-10 top-0 bottom-0 px-2 flex items-center text-gray-400 hover:text-emerald-500 transition-colors focus:outline-none"
              >
                <span class="material-symbols-outlined text-xl">{{
                  showConfirmPassword ? 'visibility_off' : 'visibility'
                }}</span>
              </button>
              <span
                v-if="confirmPassword.length > 0"
                class="absolute right-4 top-1/2 -translate-y-1/2 transition-opacity"
                :class="isConfirmPasswordValid ? 'text-emerald-500' : 'text-red-400'"
              >
                <span class="material-symbols-outlined">{{
                  isConfirmPasswordValid ? 'check_circle' : 'cancel'
                }}</span>
              </span>
            </div>
            <p
              v-if="confirmPassword.length > 0 && !isConfirmPasswordValid"
              class="text-xs text-red-500 ml-1"
            >
              Las contraseñas no coinciden
            </p>
          </div>
        </div>
      </section>

      <!-- SPEC-006: Sección de PIN eliminada - se configura en AdminHub después del registro -->

      <!-- Submit Button -->
      <div class="w-full p-4 mt-4 max-w-lg mx-auto">
        <BaseButton
          @click="handleSubmit"
          :disabled="!canSubmit"
          :loading="isLoading"
          size="lg"
          variant="primary"
          class="w-full h-14 bg-emerald-600 hover:bg-emerald-700 shadow-emerald-500/30"
        >
          <span>Abrir mi Tienda</span>
          <span class="material-symbols-outlined text-xl">storefront</span>
        </BaseButton>
        <p class="text-xs text-center text-[#489d82] mt-3">
          Al crear la cuenta aceptas los
          <a class="underline hover:text-emerald-600" href="#">términos de servicio</a>.
        </p>
      </div>
    </main>
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

@keyframes popIn {
  from {
    transform: scale(0);
    opacity: 0;
  }

  to {
    transform: scale(1);
    opacity: 1;
  }
}
</style>

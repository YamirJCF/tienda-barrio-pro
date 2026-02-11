<script setup lang="ts">
/**
 * ChangePasswordModal - Modal for changing admin password from profile.
 * Flow: Current password → New password → Confirm → supabase.auth.updateUser
 */
import { ref, computed, watch } from 'vue';
import BaseModal from '@/components/ui/BaseModal.vue';
import BaseInput from '@/components/ui/BaseInput.vue';
import BaseButton from '@/components/ui/BaseButton.vue';
import { useAuthStore } from '@/stores/auth';
import { useAsyncAction } from '@/composables/useAsyncAction';
import { Lock, Eye, EyeOff, CheckCircle, ShieldCheck } from 'lucide-vue-next';

interface Props {
  modelValue: boolean;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
}>();

const authStore = useAuthStore();
const { execute, isLoading } = useAsyncAction();

// Form state
const currentPassword = ref('');
const newPassword = ref('');
const confirmPassword = ref('');
const showCurrentPassword = ref(false);
const showNewPassword = ref(false);
const isSuccess = ref(false);

// Validation
const newPasswordError = computed(() => {
  if (!newPassword.value) return '';
  if (newPassword.value.length < 6) return 'Mínimo 6 caracteres';
  return '';
});

const confirmPasswordError = computed(() => {
  if (!confirmPassword.value) return '';
  if (confirmPassword.value !== newPassword.value) return 'Las contraseñas no coinciden';
  return '';
});

const isFormValid = computed(() => {
  return (
    currentPassword.value.length > 0 &&
    newPassword.value.length >= 6 &&
    confirmPassword.value === newPassword.value
  );
});

// Reset form when modal closes
watch(() => props.modelValue, (open) => {
  if (!open) {
    setTimeout(() => {
      currentPassword.value = '';
      newPassword.value = '';
      confirmPassword.value = '';
      showCurrentPassword.value = false;
      showNewPassword.value = false;
      isSuccess.value = false;
    }, 300); // Wait for close animation
  }
});

const handleSubmit = async () => {
  if (!isFormValid.value) return;

  await execute(async () => {
    const result = await authStore.changePassword(
      currentPassword.value,
      newPassword.value
    );

    if (!result.success) {
      throw new Error(result.error || 'Error al cambiar la contraseña');
    }

    isSuccess.value = true;
  }, {
    checkConnectivity: true
  });
};

const close = () => {
  emit('update:modelValue', false);
};
</script>

<template>
  <BaseModal
    :modelValue="modelValue"
    @update:modelValue="emit('update:modelValue', $event)"
    title="Seguridad y Contraseña"
    :showCloseButton="true"
    maxHeight="90vh"
  >
    <!-- Success State -->
    <div v-if="isSuccess" class="px-6 py-10 flex flex-col items-center text-center">
      <div
        class="mb-5 flex items-center justify-center w-20 h-20 rounded-full bg-green-50 dark:bg-green-900/20 text-green-500"
      >
        <CheckCircle :size="48" />
      </div>
      <h3 class="text-xl font-bold text-slate-900 dark:text-white mb-2">
        ¡Contraseña actualizada!
      </h3>
      <p class="text-slate-500 dark:text-slate-400 text-sm leading-relaxed mb-6">
        Tu contraseña ha sido cambiada exitosamente. Utiliza la nueva contraseña en tu próximo inicio de sesión.
      </p>
      <BaseButton
        variant="primary"
        class="w-full h-12"
        @click="close"
      >
        Entendido
      </BaseButton>
    </div>

    <!-- Form State -->
    <form v-else @submit.prevent="handleSubmit" class="px-6 pt-2 pb-6 space-y-5">
      <!-- Info Banner -->
      <div class="flex items-start gap-3 p-3.5 rounded-xl bg-indigo-50 dark:bg-indigo-900/20 border border-indigo-100 dark:border-indigo-900/30">
        <ShieldCheck :size="18" :stroke-width="1.5" class="text-indigo-500 shrink-0 mt-0.5" />
        <p class="text-xs text-indigo-800 dark:text-indigo-200 leading-relaxed font-medium">
          Por seguridad, necesitas ingresar tu contraseña actual antes de establecer una nueva.
        </p>
      </div>

      <!-- Current Password -->
      <div class="relative">
        <BaseInput
          v-model="currentPassword"
          :type="showCurrentPassword ? 'text' : 'password'"
          id="current-password"
          label="Contraseña Actual"
          required
          placeholder="Ingresa tu contraseña actual"
          autocomplete="current-password"
        >
          <template #prefix>
            <Lock :size="18" class="text-slate-400" />
          </template>
        </BaseInput>
        <button
          type="button"
          class="absolute right-3 top-[38px] text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 transition-colors p-1"
          @click="showCurrentPassword = !showCurrentPassword"
        >
          <EyeOff v-if="showCurrentPassword" :size="18" />
          <Eye v-else :size="18" />
        </button>
      </div>

      <!-- Divider -->
      <div class="flex items-center gap-3">
        <div class="flex-1 h-px bg-slate-200 dark:bg-slate-700"></div>
        <span class="text-[10px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-widest">Nueva</span>
        <div class="flex-1 h-px bg-slate-200 dark:bg-slate-700"></div>
      </div>

      <!-- New Password -->
      <div class="relative">
        <BaseInput
          v-model="newPassword"
          :type="showNewPassword ? 'text' : 'password'"
          id="new-password"
          label="Nueva Contraseña"
          required
          placeholder="Mínimo 6 caracteres"
          autocomplete="new-password"
          :error="newPasswordError"
        >
          <template #prefix>
            <Lock :size="18" class="text-slate-400" />
          </template>
        </BaseInput>
        <button
          type="button"
          class="absolute right-3 top-[38px] text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 transition-colors p-1"
          @click="showNewPassword = !showNewPassword"
        >
          <EyeOff v-if="showNewPassword" :size="18" />
          <Eye v-else :size="18" />
        </button>
      </div>

      <!-- Confirm Password -->
      <BaseInput
        v-model="confirmPassword"
        type="password"
        id="confirm-password"
        label="Confirmar Contraseña"
        required
        placeholder="Repite la nueva contraseña"
        autocomplete="new-password"
        :error="confirmPasswordError"
      >
        <template #prefix>
          <Lock :size="18" class="text-slate-400" />
        </template>
      </BaseInput>

      <!-- Submit Button -->
      <BaseButton
        type="submit"
        :loading="isLoading"
        :disabled="!isFormValid || isLoading"
        variant="primary"
        class="w-full h-12 mt-2"
      >
        Actualizar Contraseña
      </BaseButton>
    </form>
  </BaseModal>
</template>

<template>
  <div v-if="isVisible" class="modal-overlay" @click.self="handleClose">
    <div class="modal-container pin-reset-modal">
      <div class="modal-header">
        <h2>🔐 Resetear PIN de Caja</h2>
        <button class="close-btn" @click="handleClose">✕</button>
      </div>

      <div class="modal-content">
        <!-- Step 1: Password -->
        <div v-if="currentStep === 'password'" class="step-password">
          <p class="step-label">Ingresa tu contraseña actual:</p>
          <div class="password-input-container">
            <input
              v-model="password"
              :type="showPassword ? 'text' : 'password'"
              class="password-input"
              placeholder="Tu contraseña"
              @keyup.enter="validatePassword"
            />
            <button class="toggle-password" @click="showPassword = !showPassword">
              {{ showPassword ? '🙈' : '👁️' }}
            </button>
          </div>
          <p v-if="error" class="error-message">{{ error }}</p>
          <div class="action-buttons">
            <button class="btn-secondary" @click="handleClose">Cancelar</button>
            <button class="btn-primary" @click="validatePassword" :disabled="!password || loading">
              Continuar →
            </button>
          </div>
        </div>

        <!-- Step 2: New PIN -->
        <div v-if="currentStep === 'newPin'" class="step-new-pin">
          <p class="step-label">Crea tu nuevo PIN de 6 dígitos:</p>
          <PinKeypad
            ref="newPinKeypad"
            :length="6"
            :error="error"
            :disabled="loading"
            @complete="handleNewPinComplete"
          />
          <button class="btn-back" @click="currentStep = 'password'">← Volver</button>
        </div>

        <!-- Step 3: Confirm PIN -->
        <div v-if="currentStep === 'confirm'" class="step-confirm">
          <p class="step-label">Confirma tu nuevo PIN:</p>
          <PinKeypad
            ref="confirmPinKeypad"
            :length="6"
            :error="error"
            :disabled="loading"
            @complete="handleConfirmPinComplete"
          />
          <button class="btn-back" @click="goBackToNewPin">← Volver</button>
        </div>

        <!-- Step 4: Success -->
        <div v-if="currentStep === 'success'" class="success-step">
          <div class="success-icon">✅</div>
          <h3>¡PIN Reseteado!</h3>
          <p>Tu nuevo PIN ha sido guardado correctamente.</p>
          <button class="btn-primary" @click="handleSuccess">Continuar</button>
        </div>
      </div>

      <div v-if="loading" class="loading-overlay">
        <div class="spinner"></div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import PinKeypad from './PinKeypad.vue';
import { supabase } from '@/lib/supabase';
import { useCashControlStore } from '@/stores/cashControl';
import { useAuthStore } from '@/stores/auth';

defineProps<{
  isVisible: boolean;
}>();

const emit = defineEmits<{
  close: [];
  success: [];
}>();

const authStore = useAuthStore();
const cashControlStore = useCashControlStore();

const currentStep = ref<'password' | 'newPin' | 'confirm' | 'success'>('password');
const password = ref('');
const showPassword = ref(false);
const newPin = ref('');
const error = ref<string | null>(null);
const loading = ref(false);

const newPinKeypad = ref<InstanceType<typeof PinKeypad> | null>(null);
const confirmPinKeypad = ref<InstanceType<typeof PinKeypad> | null>(null);

const validatePassword = async () => {
  if (!password.value) return;

  loading.value = true;
  error.value = null;

  try {
    // Re-authenticate with Supabase
    const { error: authError } = await supabase.auth.signInWithPassword({
      email: authStore.currentUser?.email ?? '',
      password: password.value
    });

    if (authError) {
      error.value = 'Contraseña incorrecta';
      return;
    }

    currentStep.value = 'newPin';
  } catch (err) {
    error.value = 'Error de conexión';
  } finally {
    loading.value = false;
  }
};

const handleNewPinComplete = (pin: string) => {
  newPin.value = pin;
  currentStep.value = 'confirm';
  error.value = null;
};

const handleConfirmPinComplete = async (confirmPin: string) => {
  if (confirmPin !== newPin.value) {
    error.value = 'Los PINs no coinciden';
    confirmPinKeypad.value?.clear();
    return;
  }

  loading.value = true;
  error.value = null;

  try {
    // setupPin without current PIN (we already validated password)
    const result = await cashControlStore.setupPin(newPin.value);

    if (result.success) {
      currentStep.value = 'success';
    } else {
      error.value = result.error ?? 'Error al guardar PIN';
      confirmPinKeypad.value?.clear();
    }
  } catch (err) {
    error.value = 'Error de conexión';
  } finally {
    loading.value = false;
  }
};

const goBackToNewPin = () => {
  currentStep.value = 'newPin';
  error.value = null;
  newPinKeypad.value?.clear();
};

const handleClose = () => {
  resetModal();
  emit('close');
};

const handleSuccess = () => {
  emit('success');
  resetModal();
  emit('close');
};

const resetModal = () => {
  currentStep.value = 'password';
  password.value = '';
  newPin.value = '';
  error.value = null;
  showPassword.value = false;
};

watch(() => props.isVisible, (visible) => {
  if (visible) {
    resetModal();
  }
});

const props = defineProps<{
  isVisible: boolean;
}>();
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
}

.modal-container {
  background: white;
  border-radius: 16px;
  width: 100%;
  max-width: 360px;
  position: relative;
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.5rem;
  border-bottom: 1px solid #e5e7eb;
}

.modal-header h2 {
  margin: 0;
  font-size: 1.125rem;
}

.close-btn {
  background: none;
  border: none;
  font-size: 1.25rem;
  cursor: pointer;
  color: #6b7280;
}

.modal-content {
  padding: 1.5rem;
}

.step-label {
  text-align: center;
  color: #4b5563;
  margin-bottom: 1.5rem;
}

.password-input-container {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 1rem;
}

.password-input {
  flex: 1;
  padding: 0.875rem;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  font-size: 1rem;
}

.toggle-password {
  padding: 0.875rem;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  background: white;
  cursor: pointer;
}

.error-message {
  color: #ef4444;
  text-align: center;
  margin-bottom: 1rem;
  font-size: 0.875rem;
}

.action-buttons {
  display: flex;
  gap: 1rem;
}

.action-buttons button {
  flex: 1;
  padding: 0.875rem;
  border-radius: 8px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
}

.btn-primary {
  background: #6366f1;
  color: white;
  border: none;
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-secondary {
  background: white;
  border: 1px solid #e5e7eb;
  color: #374151;
}

.btn-back {
  width: 100%;
  padding: 0.75rem;
  border: none;
  background: transparent;
  color: #6b7280;
  cursor: pointer;
  margin-top: 1rem;
}

.success-step {
  text-align: center;
  padding: 1rem 0;
}

.success-icon {
  font-size: 4rem;
  margin-bottom: 1rem;
}

.loading-overlay {
  position: absolute;
  inset: 0;
  background: rgba(255,255,255,0.8);
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 16px;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 4px solid #e5e7eb;
  border-top-color: #6366f1;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>

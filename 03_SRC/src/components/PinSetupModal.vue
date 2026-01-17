<template>
  <div v-if="isVisible" class="modal-overlay" @click.self="handleClose">
    <div class="modal-container pin-setup-modal">
      <div class="modal-header">
        <h2>{{ mode === 'setup' ? '🔑 Configura tu PIN de Caja' : '🔑 Cambiar PIN de Caja' }}</h2>
        <button class="close-btn" @click="handleClose">✕</button>
      </div>

      <div class="modal-content">
        <!-- Current PIN (only for change mode) -->
        <div v-if="mode === 'change' && currentStep === 'current'" class="pin-step">
          <p class="step-label">Ingresa tu PIN actual:</p>
          <PinKeypad :length="6" :error="error" :disabled="loading" @complete="handleCurrentPinComplete" />
        </div>

        <!-- New PIN -->
        <div v-if="currentStep === 'new'" class="pin-step">
          <p class="step-label">{{ mode === 'setup' ? 'Crea un PIN de 6 dígitos:' : 'Ingresa tu nuevo PIN:' }}</p>
          <PinKeypad ref="newPinKeypad" :length="6" :error="error" :disabled="loading"
            @complete="handleNewPinComplete" />
        </div>

        <!-- Confirm PIN -->
        <div v-if="currentStep === 'confirm'" class="pin-step">
          <p class="step-label">Confirma tu PIN:</p>
          <PinKeypad ref="confirmPinKeypad" :length="6" :error="error" :disabled="loading"
            @complete="handleConfirmPinComplete" />
          <button class="btn-back" @click="goBack">← Volver</button>
        </div>

        <!-- Success -->
        <div v-if="currentStep === 'success'" class="success-step">
          <div class="success-icon">✅</div>
          <h3>¡PIN {{ mode === 'setup' ? 'configurado' : 'actualizado' }}!</h3>
          <p>Tu PIN de caja ha sido guardado correctamente.</p>
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
import { useCashControlStore } from '../stores/cashControl';

const props = defineProps<{
  mode: 'setup' | 'change';
  isVisible: boolean;
}>();

const emit = defineEmits<{
  close: [];
  success: [];
}>();

const cashControlStore = useCashControlStore();

const currentStep = ref<'current' | 'new' | 'confirm' | 'success'>('new');
const currentPin = ref('');
const newPin = ref('');
const error = ref<string | null>(null);
const loading = ref(false);

const newPinKeypad = ref<InstanceType<typeof PinKeypad> | null>(null);
const confirmPinKeypad = ref<InstanceType<typeof PinKeypad> | null>(null);

const handleCurrentPinComplete = (pin: string) => {
  currentPin.value = pin;
  currentStep.value = 'new';
  error.value = null;
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
    const result = await cashControlStore.setupPin(
      newPin.value,
      props.mode === 'change' ? currentPin.value : undefined
    );

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

const goBack = () => {
  currentStep.value = 'new';
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
  currentStep.value = props.mode === 'change' ? 'current' : 'new';
  currentPin.value = '';
  newPin.value = '';
  error.value = null;
};

watch(() => props.isVisible, (visible) => {
  if (visible) {
    resetModal();
  }
});
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

.success-step h3 {
  margin-bottom: 0.5rem;
}

.success-step p {
  color: #6b7280;
  margin-bottom: 1.5rem;
}

.btn-primary {
  width: 100%;
  padding: 0.875rem;
  background: #6366f1;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
}

.loading-overlay {
  position: absolute;
  inset: 0;
  background: rgba(255, 255, 255, 0.8);
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
  to {
    transform: rotate(360deg);
  }
}
</style>

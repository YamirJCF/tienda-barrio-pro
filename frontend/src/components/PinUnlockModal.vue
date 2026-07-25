<template>
  <div v-if="isVisible" class="modal-overlay">
    <div class="modal-container pin-unlock-modal" :class="{ 'shake': isShaking }">
      <div class="modal-header">
        <h2>🔑 Desbloqueo de Seguridad</h2>
      </div>

      <div class="modal-content">
        <p class="step-label">
          La llave de cifrado local en RAM ha expirado. Ingresa tu PIN de 4 dígitos para desencriptar el sistema:
        </p>

        <PinKeypad
          ref="pinKeypad"
          :length="4"
          :error="error"
          :disabled="loading"
          @complete="handlePinComplete"
        />
      </div>

      <div v-if="loading" class="loading-overlay">
        <div class="spinner"></div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue';
import PinKeypad from './PinKeypad.vue';
import { useAuthStore } from '../stores/auth';

const isVisible = ref(false);
const error = ref<string | null>(null);
const loading = ref(false);
const isShaking = ref(false);
const pinKeypad = ref<InstanceType<typeof PinKeypad> | null>(null);

const authStore = useAuthStore();

const emit = defineEmits<{
  success: [];
}>();

const handlePinRequiredEvent = () => {
  if (!authStore.isCryptoKeyReady) {
    isVisible.value = true;
  }
};

onMounted(() => {
  window.addEventListener('sync:pin_required', handlePinRequiredEvent);
});

onUnmounted(() => {
  window.removeEventListener('sync:pin_required', handlePinRequiredEvent);
});

const handlePinComplete = async (pin: string) => {
  loading.value = true;
  error.value = null;

  try {
    const success = await authStore.setupCryptoKey(pin);

    if (success && authStore.isCryptoKeyReady) {
      isVisible.value = false;
      emit('success');
      // Dispatch unlocked event to resume queue
      window.dispatchEvent(new CustomEvent('sync:pin_unlocked'));
    } else {
      error.value = 'PIN Incorrecto o error derivando llave';
      triggerShake();
    }
  } catch (err) {
    console.error(err);
    error.value = 'Error al verificar PIN';
    triggerShake();
  } finally {
    loading.value = false;
  }
};

const triggerShake = () => {
  isShaking.value = true;
  setTimeout(() => {
    isShaking.value = false;
  }, 500);
  pinKeypad.value?.clear();
};

defineExpose({
  open: () => { isVisible.value = true; },
  close: () => { isVisible.value = false; }
});
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.75);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  padding: 1rem;
  backdrop-filter: blur(8px);
}

.modal-container {
  background: white;
  border-radius: 16px;
  width: 100%;
  max-width: 360px;
  position: relative;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.35);
  overflow: hidden;
}

.modal-container.shake {
  animation: shake 0.5s ease-in-out;
}

@keyframes shake {
  0%, 100% { transform: translateX(0); }
  10%, 30%, 50%, 70%, 90% { transform: translateX(-8px); }
  20%, 40%, 60%, 80% { transform: translateX(8px); }
}

.modal-header {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 1.25rem 1.5rem;
  background: #4f46e5;
  color: white;
}

.modal-header h2 {
  margin: 0;
  font-size: 1.15rem;
  font-weight: 600;
}

.modal-content {
  padding: 1.5rem;
}

.step-label {
  text-align: center;
  color: #4b5563;
  margin-bottom: 1.5rem;
  font-size: 0.9rem;
  line-height: 1.4;
}

.loading-overlay {
  position: absolute;
  inset: 0;
  background: rgba(255, 255, 255, 0.85);
  display: flex;
  align-items: center;
  justify-content: center;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 4px solid #e5e7eb;
  border-top-color: #4f46e5;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

@media (prefers-color-scheme: dark) {
  .modal-container {
    background: #1f2937;
  }
  .step-label {
    color: #d1d5db;
  }
}
</style>

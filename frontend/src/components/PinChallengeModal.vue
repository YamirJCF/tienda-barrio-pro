<template>
  <div v-if="isVisible" class="modal-overlay" @click.self="handleClose">
    <div class="modal-container pin-challenge-modal" :class="{ 'shake': isShaking }">
      <div class="modal-header">
        <h2>🔐 {{ title }}</h2>
        <button class="close-btn" @click="handleClose" :disabled="loading">✕</button>
      </div>

      <div class="modal-content">
        <!-- Locked State -->
        <div v-if="cashControlStore.isLocked" class="locked-state">
          <div class="locked-icon">🔒</div>
          <h3>Acceso Bloqueado</h3>
          <p>Demasiados intentos fallidos.</p>
          <div class="countdown">
            <span class="timer">{{ formatTime(cashControlStore.lockRemainingSeconds) }}</span>
            <span class="timer-label">para reintentar</span>
          </div>
        </div>

        <!-- PIN Input State -->
        <div v-else class="pin-state">
          <p class="step-label">{{ subtitle }}</p>
          <PinKeypad
            ref="pinKeypad"
            :length="4"
            :error="error"
            :disabled="loading"
            @complete="handlePinComplete"
          />
          <p v-if="attemptsRemaining !== null && attemptsRemaining < 5" class="attempts-warning">
            ⚠️ {{ attemptsRemaining }} intentos restantes
          </p>
        </div>
      </div>

      <div v-if="loading" class="loading-overlay">
        <div class="spinner"></div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, computed } from 'vue';
import PinKeypad from './PinKeypad.vue';
import { useCashControlStore } from '../stores/cashControl';
import { useAuthStore } from '../stores/auth';
import { authRepository } from '../data/repositories/authRepository';
import { useDeviceFingerprint } from '../composables/useDeviceFingerprint';

const props = withDefaults(defineProps<{
  isVisible: boolean;
  action: 'open' | 'close';
}>(), {
  action: 'open'
});

const emit = defineEmits<{
  close: [];
  success: [];
}>();

const cashControlStore = useCashControlStore();
const authStore = useAuthStore();
const { getShortFingerprint } = useDeviceFingerprint();

const error = ref<string | null>(null);
const loading = ref(false);
const isShaking = ref(false);
const attemptsRemaining = ref<number | null>(null);
const pinKeypad = ref<InstanceType<typeof PinKeypad> | null>(null);

const title = computed(() => 
  props.action === 'open' ? 'Autorizar Apertura' : 'Autorizar Cierre'
);

const subtitle = computed(() => 
  props.action === 'open' 
    ? 'Ingresa TU PIN de Empleado para abrir el turno:' 
    : 'Ingresa TU PIN de Empleado para cerrar el turno:'
);

const formatTime = (seconds: number): string => {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins}:${secs.toString().padStart(2, '0')}`;
};

const handlePinComplete = async (pin: string) => {
  loading.value = true;
  error.value = null;

  try {
    // SECURITY UPGRADE: Verify against Backend (Zero-Auth Strategy)
    // Instead of local LS hash, we verify if this PIN can request access for current user
    if (!authStore.currentUser?.email) {
        throw new Error("Usuario no identificado");
    }

    // We can re-use requestEmployeeAccess logic or a new verifyPin endpoint.
    // Re-using requestEmployeeAccess is standard for "sudo" mode.
    const fingerprint = await getShortFingerprint(); // Does not need exact match, just value
    
    // We send the ALIAS (which is mapped to email/username in store)
    // If it's an employee, email is the alias. If admin, it's the email. 
    const identity = authStore.currentUser.email; // username field holds alias

    const result = await authRepository.requestEmployeeAccess(
        identity, 
        pin, 
        fingerprint || 'sudo-check'
    );

    if (result.success) {
      // Success! Emit and close
      emit('success');
      resetModal();
      emit('close');
    } else {
      // Failure - shake and show error
      console.warn('[PinChallenge] Validation Failed:', { 
        identity, 
        error: result.message, 
        code: result.error_code 
      });
      
      error.value = result.message || 'PIN Incorrecto';
      
      // Trigger shake animation
      isShaking.value = true;
      setTimeout(() => {
        isShaking.value = false;
      }, 500);

      // Clear keypad for retry
      pinKeypad.value?.clear();
    }
  } catch (err) {
    console.error(err);
    error.value = 'Error de validación';
    pinKeypad.value?.clear();
  } finally {
    loading.value = false;
  }
};

const handleClose = () => {
  if (!loading.value) {
    resetModal();
    emit('close');
  }
};

const resetModal = () => {
  error.value = null;
  attemptsRemaining.value = null;
  isShaking.value = false;
};

watch(
  () => props.isVisible,
  (visible) => {
    if (visible) {
      resetModal();
      // Check lock status on open
      cashControlStore.checkCashStatus();
    }
  }
);
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  padding: 1rem;
  backdrop-filter: blur(4px);
}

.modal-container {
  background: white;
  border-radius: 16px;
  width: 100%;
  max-width: 360px;
  position: relative;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
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
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.5rem;
  border-bottom: 1px solid #e5e7eb;
}

.modal-header h2 {
  margin: 0;
  font-size: 1.125rem;
  font-weight: 600;
}

.close-btn {
  background: none;
  border: none;
  font-size: 1.25rem;
  cursor: pointer;
  color: #6b7280;
  transition: color 0.2s;
}

.close-btn:hover:not(:disabled) {
  color: #1f2937;
}

.close-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.modal-content {
  padding: 1.5rem;
}

.step-label {
  text-align: center;
  color: #4b5563;
  margin-bottom: 1.5rem;
  font-size: 0.95rem;
}

.attempts-warning {
  text-align: center;
  color: #f59e0b;
  font-size: 0.875rem;
  margin-top: 1rem;
  font-weight: 500;
}

/* Locked State */
.locked-state {
  text-align: center;
  padding: 2rem 1rem;
}

.locked-icon {
  font-size: 4rem;
  margin-bottom: 1rem;
}

.locked-state h3 {
  color: #dc2626;
  margin-bottom: 0.5rem;
}

.locked-state p {
  color: #6b7280;
  margin-bottom: 1.5rem;
}

.countdown {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.25rem;
}

.timer {
  font-size: 2.5rem;
  font-weight: 700;
  font-family: 'SF Mono', 'Fira Code', monospace;
  color: #dc2626;
}

.timer-label {
  font-size: 0.875rem;
  color: #6b7280;
}

/* Loading Overlay */
.loading-overlay {
  position: absolute;
  inset: 0;
  background: rgba(255, 255, 255, 0.85);
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

/* Dark Mode */
@media (prefers-color-scheme: dark) {
  .modal-container {
    background: #1f2937;
  }

  .modal-header {
    border-bottom-color: #374151;
  }

  .modal-header h2 {
    color: #f9fafb;
  }

  .close-btn {
    color: #9ca3af;
  }

  .step-label {
    color: #d1d5db;
  }

  .locked-state p,
  .timer-label {
    color: #9ca3af;
  }
}
</style>

<template>
  <div v-if="isVisible" class="modal-overlay" @click.self="handleClose">
    <div class="modal-container cash-control-modal">
      <!-- Header -->
      <div class="modal-header">
        <h2>{{ headerTitle }}</h2>
        <button class="close-btn" @click="handleClose">✕</button>
      </div>

      <!-- Content based on step -->
      <div class="modal-content">
        <!-- STEP 1: Amount Entry -->
        <div v-if="currentStep === 'amount'" class="step-amount">
          <p class="step-label">
            {{ mode === 'open' ? 'Monto inicial en caja:' : '¿Cuánto efectivo hay en caja?' }}
          </p>

          <!-- Daily Summary (only for close) -->
          <div v-if="mode === 'close'" class="daily-summary">
            <p>Resumen del día:</p>
            <p class="summary-value">Ventas totales: {{ formatCurrency(dailySales) }}</p>
          </div>

          <!-- Amount Display -->
          <div class="amount-display">
            <span class="currency">$</span>
            <span class="amount">{{ formatNumber(amount) }}</span>
          </div>

          <!-- Numeric Keypad -->
          <div class="numeric-keypad">
            <button
              v-for="num in ['1', '2', '3', '4', '5', '6', '7', '8', '9']"
              :key="num"
              @click="addDigit(num)"
            >
              {{ num }}
            </button>
            <button @click="clearAmount">🗑️</button>
            <button @click="addDigit('0')">0</button>
            <button @click="addDigit('00')">00</button>
          </div>

          <!-- Action Buttons -->
          <div class="action-buttons">
            <button class="btn-secondary" @click="handleClose">Cancelar</button>
            <button class="btn-primary" @click="goToPinStep" :disabled="loading">✓ Aceptar</button>
          </div>

          <!-- Confirm Zero Amount Modal -->
          <div v-if="showZeroConfirm" class="zero-confirm-overlay">
            <div class="zero-confirm-modal">
              <p>¿{{ mode === 'open' ? 'Abrir' : 'Cerrar' }} caja con $0?</p>
              <p class="warning">Esto es inusual.</p>
              <div class="confirm-buttons">
                <button @click="showZeroConfirm = false">Cancelar</button>
                <button @click="confirmZeroAmount">Sí, Continuar</button>
              </div>
            </div>
          </div>
        </div>

        <!-- STEP 2: PIN Entry -->
        <div v-if="currentStep === 'pin'" class="step-pin">
          <div class="amount-confirmed">
            <p>{{ mode === 'open' ? 'Monto inicial:' : 'Efectivo contado:' }}</p>
            <p class="amount-value">{{ formatCurrency(amount) }}</p>
          </div>

          <!-- Show expected and difference (only for close) -->
          <div v-if="mode === 'close'" class="cash-comparison">
            <div class="comparison-row">
              <span>Efectivo esperado:</span>
              <span>{{ formatCurrency(expectedCash) }}</span>
            </div>
            <div class="comparison-row difference" :class="differenceClass">
              <span>Diferencia:</span>
              <span>{{ formatCurrency(difference) }} {{ differenceLabel }}</span>
            </div>
          </div>

          <div class="divider"></div>

          <p class="pin-label">Ingresa tu PIN:</p>

          <!-- Lockout Warning -->
          <div v-if="isLocked" class="lockout-warning">
            <p>⏳ Demasiados intentos</p>
            <p class="countdown">Espera {{ lockCountdown }} segundos</p>
          </div>

          <PinKeypad
            v-else
            :length="pinLength"
            :error="pinError"
            :disabled="loading"
            @complete="handlePinComplete"
          />

          <button class="btn-back" @click="goBackToAmount">← Volver</button>
        </div>

        <!-- STEP 3: Success -->
        <div v-if="currentStep === 'success'" class="step-success">
          <div class="success-icon">✅</div>
          <h3>¡Caja {{ mode === 'open' ? 'Abierta' : 'Cerrada' }}!</h3>
          <div class="success-details">
            <p>
              {{ mode === 'open' ? 'Monto inicial:' : 'Monto declarado:' }}
              {{ formatCurrency(amount) }}
            </p>
            <p v-if="mode === 'close'">Diferencia: {{ formatCurrency(difference) }}</p>
            <p>Registrado por: {{ authorizedByName }}</p>
            <p>Hora: {{ formatTime(new Date()) }}</p>
          </div>
          <button class="btn-primary" @click="handleSuccess">Continuar</button>
        </div>
      </div>

      <!-- Loading Overlay -->
      <div v-if="loading" class="loading-overlay">
        <div class="spinner"></div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import PinKeypad from './PinKeypad.vue';
import { useCashControlStore } from '@/stores/cashControl';
import { useAuthStore } from '@/stores/auth';

const props = defineProps<{
  mode: 'open' | 'close';
  isVisible: boolean;
}>();

const emit = defineEmits<{
  close: [];
  success: [event: any];
}>();

const cashControlStore = useCashControlStore();
const authStore = useAuthStore();

// State
const currentStep = ref<'amount' | 'pin' | 'success'>('amount');
const amount = ref(0);
const showZeroConfirm = ref(false);
const pinError = ref<string | null>(null);
const loading = ref(false);
const dailySales = ref(0);
const expectedCash = ref(0);
const difference = ref(0);
const lockCountdown = ref(0);
let lockTimer: number | null = null;

// Computed
const headerTitle = computed(() => {
  if (currentStep.value === 'amount') {
    return props.mode === 'open' ? '🏪 Apertura de Caja' : '📋 Cierre de Caja';
  }
  if (currentStep.value === 'pin') {
    return '🔐 Confirmar ' + (props.mode === 'open' ? 'Apertura' : 'Cierre');
  }
  return '';
});

const pinLength = computed(() => (authStore.isAdmin ? 6 : 4));

const authorizedByName = computed(() => authStore.currentUser?.name ?? 'Usuario');

const isLocked = computed(() => cashControlStore.isLocked);

const differenceClass = computed(() => {
  if (difference.value === 0) return 'balanced';
  return difference.value > 0 ? 'surplus' : 'deficit';
});

const differenceLabel = computed(() => {
  if (difference.value === 0) return '✅';
  return difference.value > 0 ? '(Sobrante) ℹ️' : '(Faltante) ⚠️';
});

// Methods
const formatCurrency = (value: number) => {
  return new Intl.NumberFormat('es-CO', {
    style: 'currency',
    currency: 'COP',
    minimumFractionDigits: 0,
  }).format(value);
};

const formatNumber = (value: number) => {
  return new Intl.NumberFormat('es-CO').format(value);
};

const formatTime = (date: Date) => {
  return date.toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit' });
};

const addDigit = (digit: string) => {
  const newAmount = amount.value.toString() + digit;
  if (newAmount.length <= 12) {
    amount.value = parseInt(newAmount);
  }
};

const clearAmount = () => {
  amount.value = 0;
};

const goToPinStep = async () => {
  if (amount.value === 0) {
    showZeroConfirm.value = true;
    return;
  }
  await prepareAndGoToPin();
};

const confirmZeroAmount = async () => {
  showZeroConfirm.value = false;
  await prepareAndGoToPin();
};

const prepareAndGoToPin = async () => {
  if (props.mode === 'close') {
    loading.value = true;
    expectedCash.value = await cashControlStore.getExpectedCash();
    difference.value = amount.value - expectedCash.value;
    loading.value = false;
  }
  currentStep.value = 'pin';
  pinError.value = null;
};

const goBackToAmount = () => {
  currentStep.value = 'amount';
  pinError.value = null;
};

const handlePinComplete = async (pin: string) => {
  loading.value = true;
  pinError.value = null;

  try {
    let result;
    if (props.mode === 'open') {
      result = await cashControlStore.openCash(amount.value, pin, authorizedByName.value);
    } else {
      result = await cashControlStore.closeCash(amount.value, pin, authorizedByName.value);
      if (result.difference !== undefined) {
        difference.value = result.difference;
      }
    }

    if (result.success) {
      currentStep.value = 'success';
    } else {
      pinError.value = result.error ?? 'Error desconocido';

      // Check if locked
      if (cashControlStore.isLocked) {
        startLockCountdown();
      }
    }
  } catch (err) {
    pinError.value = 'Error de conexión';
  } finally {
    loading.value = false;
  }
};

const startLockCountdown = () => {
  lockCountdown.value = cashControlStore.lockRemainingSeconds;
  if (lockTimer) clearInterval(lockTimer);
  lockTimer = window.setInterval(() => {
    lockCountdown.value = cashControlStore.lockRemainingSeconds;
    if (lockCountdown.value <= 0 && lockTimer) {
      clearInterval(lockTimer);
      lockTimer = null;
    }
  }, 1000);
};

const handleClose = () => {
  resetModal();
  emit('close');
};

const handleSuccess = () => {
  emit('success', cashControlStore.currentEvent);
  resetModal();
  emit('close');
};

const resetModal = () => {
  currentStep.value = 'amount';
  amount.value = 0;
  showZeroConfirm.value = false;
  pinError.value = null;
  difference.value = 0;
  expectedCash.value = 0;
};

// Watch for visibility changes
watch(
  () => props.isVisible,
  async (visible) => {
    if (visible) {
      resetModal();
      // Check PIN status
      await cashControlStore.checkPinConfigured();
    }
  },
);
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
  max-width: 400px;
  max-height: 90vh;
  overflow-y: auto;
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
  font-size: 1.25rem;
}

.close-btn {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: #6b7280;
}

.modal-content {
  padding: 1.5rem;
}

.step-label {
  text-align: center;
  color: #4b5563;
  margin-bottom: 1rem;
}

.amount-display {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  font-size: 2rem;
  font-weight: bold;
  padding: 1rem;
  background: #f3f4f6;
  border-radius: 12px;
  margin-bottom: 1rem;
}

.currency {
  color: #6b7280;
}

.numeric-keypad {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.5rem;
  margin-bottom: 1.5rem;
}

.numeric-keypad button {
  padding: 1rem;
  font-size: 1.25rem;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  background: white;
  cursor: pointer;
  transition: all 0.15s;
}

.numeric-keypad button:hover {
  background: #f3f4f6;
}

.numeric-keypad button:active {
  background: #6366f1;
  color: white;
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

/* Step PIN */
.amount-confirmed {
  text-align: center;
  margin-bottom: 1rem;
}

.amount-value {
  font-size: 1.5rem;
  font-weight: bold;
  color: #1f2937;
}

.cash-comparison {
  background: #f9fafb;
  border-radius: 8px;
  padding: 1rem;
  margin-bottom: 1rem;
}

.comparison-row {
  display: flex;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}

.difference.balanced {
  color: #10b981;
}
.difference.surplus {
  color: #3b82f6;
}
.difference.deficit {
  color: #ef4444;
}

.divider {
  height: 1px;
  background: #e5e7eb;
  margin: 1rem 0;
}

.pin-label {
  text-align: center;
  color: #4b5563;
  margin-bottom: 1rem;
}

.lockout-warning {
  text-align: center;
  padding: 2rem;
  background: #fef3c7;
  border-radius: 12px;
}

.countdown {
  font-size: 1.5rem;
  font-weight: bold;
  color: #d97706;
}

/* Step Success */
.step-success {
  text-align: center;
}

.success-icon {
  font-size: 4rem;
  margin-bottom: 1rem;
}

.success-details {
  background: #f0fdf4;
  padding: 1rem;
  border-radius: 8px;
  margin: 1rem 0;
}

.success-details p {
  margin: 0.25rem 0;
  color: #166534;
}

/* Daily Summary */
.daily-summary {
  background: #f3f4f6;
  padding: 0.75rem;
  border-radius: 8px;
  margin-bottom: 1rem;
  text-align: center;
}

.summary-value {
  font-weight: 600;
  color: #1f2937;
}

/* Zero Confirm */
.zero-confirm-overlay {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
}

.zero-confirm-modal {
  background: white;
  padding: 1.5rem;
  border-radius: 12px;
  text-align: center;
}

.warning {
  color: #d97706;
  font-weight: 500;
}

.confirm-buttons {
  display: flex;
  gap: 1rem;
  margin-top: 1rem;
}

.confirm-buttons button {
  flex: 1;
  padding: 0.75rem;
  border-radius: 8px;
  cursor: pointer;
}

/* Loading */
.loading-overlay {
  position: absolute;
  inset: 0;
  background: rgba(255, 255, 255, 0.8);
  display: flex;
  align-items: center;
  justify-content: center;
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

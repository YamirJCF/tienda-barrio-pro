<template>
  <div class="pin-keypad">
    <!-- PIN Display -->
    <div class="pin-display" :class="{ 'has-error': error }">
      <div
        v-for="(_, index) in length"
        :key="index"
        class="pin-dot"
        :class="{
          filled: index < pin.length,
          error: error && index < pin.length,
        }"
      >
        <span v-if="index < pin.length" class="dot-filled">●</span>
        <span v-else class="dot-empty">○</span>
      </div>
    </div>

    <!-- Error Message -->
    <div v-if="error" class="pin-error">
      {{ error }}
    </div>

    <!-- Keypad Grid -->
    <div class="keypad-grid" :class="{ disabled }">
      <button
        v-for="num in numbers"
        :key="num"
        type="button"
        class="keypad-btn"
        :disabled="disabled || pin.length >= length"
        @click="addDigit(num)"
      >
        {{ num }}
      </button>
      <button type="button" class="keypad-btn empty"></button>
      <button
        type="button"
        class="keypad-btn"
        :disabled="disabled || pin.length >= length"
        @click="addDigit('0')"
      >
        0
      </button>
      <button
        type="button"
        class="keypad-btn backspace"
        :disabled="disabled || pin.length === 0"
        @click="deleteDigit"
      >
        ⌫
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';

const props = withDefaults(
  defineProps<{
    length?: number;
    autoSubmit?: boolean;
    disabled?: boolean;
    error?: string | null;
  }>(),
  {
    length: 6,
    autoSubmit: true,
    disabled: false,
    error: null,
  },
);

const emit = defineEmits<{
  complete: [pin: string];
  change: [pin: string];
}>();

const pin = ref('');
const numbers = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];

const addDigit = (digit: string) => {
  if (props.disabled || pin.value.length >= props.length) return;

  pin.value += digit;
  emit('change', pin.value);

  if (props.autoSubmit && pin.value.length === props.length) {
    emit('complete', pin.value);
  }
};

const deleteDigit = () => {
  if (props.disabled || pin.value.length === 0) return;
  pin.value = pin.value.slice(0, -1);
  emit('change', pin.value);
};

const clear = () => {
  pin.value = '';
  emit('change', pin.value);
};

// Watch for error to shake the display
watch(
  () => props.error,
  (newError) => {
    if (newError) {
      // Clear PIN on error
      pin.value = '';
    }
  },
);

// Expose clear method for parent components
defineExpose({ clear });
</script>

<style scoped>
.pin-keypad {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1.5rem;
  padding: 1rem;
}

.pin-display {
  display: flex;
  gap: 0.75rem;
  justify-content: center;
}

.pin-display.has-error {
  animation: shake 0.4s ease-in-out;
}

@keyframes shake {
  0%,
  100% {
    transform: translateX(0);
  }
  25% {
    transform: translateX(-8px);
  }
  50% {
    transform: translateX(8px);
  }
  75% {
    transform: translateX(-8px);
  }
}

.pin-dot {
  width: 20px;
  height: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.5rem;
  transition: all 0.15s ease;
}

.pin-dot.filled {
  animation: popIn 0.15s ease;
}

.pin-dot.error .dot-filled {
  color: var(--color-error, #ef4444);
}

@keyframes popIn {
  0% {
    transform: scale(0.5);
    opacity: 0;
  }
  50% {
    transform: scale(1.2);
  }
  100% {
    transform: scale(1);
    opacity: 1;
  }
}

.dot-empty {
  color: var(--color-text-muted, #9ca3af);
}

.dot-filled {
  color: var(--color-primary, #6366f1);
}

.pin-error {
  color: var(--color-error, #ef4444);
  font-size: 0.875rem;
  text-align: center;
  animation: fadeIn 0.2s ease;
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(-5px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.keypad-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.75rem;
  max-width: 280px;
}

.keypad-grid.disabled {
  opacity: 0.5;
  pointer-events: none;
}

.keypad-btn {
  width: 72px;
  height: 72px;
  border-radius: 50%;
  border: 2px solid var(--color-border, #e5e7eb);
  background: var(--color-surface, #ffffff);
  font-size: 1.5rem;
  font-weight: 600;
  color: var(--color-text, #1f2937);
  cursor: pointer;
  transition: all 0.15s ease;
  display: flex;
  align-items: center;
  justify-content: center;
}

.keypad-btn:hover:not(:disabled) {
  background: var(--color-primary-light, #eef2ff);
  border-color: var(--color-primary, #6366f1);
}

.keypad-btn:active:not(:disabled) {
  transform: scale(0.95);
  background: var(--color-primary, #6366f1);
  color: white;
}

.keypad-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.keypad-btn.empty {
  visibility: hidden;
}

.keypad-btn.backspace {
  font-size: 1.25rem;
}

/* Dark mode support */
@media (prefers-color-scheme: dark) {
  .keypad-btn {
    background: var(--color-surface-dark, #1f2937);
    border-color: var(--color-border-dark, #374151);
    color: var(--color-text-dark, #f9fafb);
  }

  .keypad-btn:hover:not(:disabled) {
    background: var(--color-primary-dark, #4338ca);
  }
}
</style>

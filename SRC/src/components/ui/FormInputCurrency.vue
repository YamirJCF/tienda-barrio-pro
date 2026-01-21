<script setup lang="ts">
import { ref, watch, onMounted, computed } from 'vue';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';

const props = defineProps<{
  modelValue: number;
  placeholder?: string;
  autofocus?: boolean;
  disabled?: boolean;
  readonly?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: number): void;
}>();

const { formatCurrency } = useCurrencyFormat();
const inputRef = ref<HTMLInputElement | null>(null);
const isFocused = ref(false);

const displayValue = computed({
  get: () => {
    if (isFocused.value) {
      return props.modelValue === 0 ? '' : props.modelValue.toString();
    }
    return props.modelValue === 0 ? '' : formatCurrency(props.modelValue);
  },
  set: (val: string) => {
    // Handled by handleInput
  }
});

const handleInput = (event: Event) => {
  const target = event.target as HTMLInputElement;
  const rawValue = target.value.replace(/[^0-9.]/g, '');
  const numericValue = parseFloat(rawValue);
  
  if (isNaN(numericValue)) {
    emit('update:modelValue', 0);
  } else {
    emit('update:modelValue', numericValue);
  }
};

const handleFocus = (event: FocusEvent) => {
  isFocused.value = true;
  (event.target as HTMLInputElement).select();
};

const handleBlur = () => {
  isFocused.value = false;
};

onMounted(() => {
  if (props.autofocus && inputRef.value) {
    inputRef.value.focus();
  }
});
</script>

<template>
  <div class="relative">
    <div v-if="!isFocused && modelValue !== 0" class="pointer-events-none absolute inset-0 flex items-center justify-center sm:justify-start pl-3 text-transparent">
       <!-- Phantom element to reserve space or structure if needed, but for now simple input is fine -->
    </div>
    <input
      ref="inputRef"
      type="text"
      inputmode="decimal"
      :value="displayValue"
      @input="handleInput"
      @focus="handleFocus"
      @blur="handleBlur"
      :placeholder="placeholder"
      :disabled="disabled"
      :readonly="readonly"
      class="w-full bg-transparent border-none focus:ring-0 p-0 placeholder-gray-300 dark:placeholder-gray-600"
      v-bind="$attrs"
    />
  </div>
</template>

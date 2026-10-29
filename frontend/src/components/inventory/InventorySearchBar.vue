<template>
  <div class="w-full space-y-1">
    <div class="relative flex items-center w-full">
      <!-- Search Prefix Icon -->
      <div class="absolute left-3.5 flex items-center pointer-events-none text-slate-400">
        <Search :size="18" :stroke-width="1.5" />
      </div>

      <!-- Main Input -->
      <input
        ref="inputRef"
        v-model="inputValue"
        type="text"
        :placeholder="placeholder"
        enterkeyhint="search"
        @keydown.enter.prevent="handleEnter"
        @input="handleInput"
        class="w-full text-sm pl-10 pr-9 py-2.5 bg-white dark:bg-slate-800 border rounded-full text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-primary/30 transition-all shadow-sm"
        :class="hasErrors
          ? 'border-red-400 dark:border-red-500 focus:border-red-500 focus:ring-red-200'
          : 'border-gray-200 dark:border-slate-700 focus:border-primary'"
      />

      <!-- Clear Button (✕) -->
      <button
        v-if="inputValue"
        type="button"
        @click="handleClear"
        aria-label="Limpiar búsqueda"
        class="absolute right-3 p-1 rounded-full text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-gray-100 dark:hover:bg-slate-700 transition-colors cursor-pointer"
      >
        <X :size="15" :stroke-width="2" />
      </button>
    </div>

    <!-- Inline Error Message (Rama de Error Explícito) -->
    <div v-if="hasErrors" class="px-3 pt-0.5 flex items-start gap-1 text-[11px] text-red-500 font-medium animate-fadeIn">
      <AlertCircle :size="13" class="shrink-0 mt-0.5" />
      <span>{{ errors[0] }}</span>
    </div>

    <!-- Inline Warning Message -->
    <div v-else-if="hasWarnings" class="px-3 pt-0.5 flex items-start gap-1 text-[11px] text-amber-500 font-medium animate-fadeIn">
      <AlertTriangle :size="13" class="shrink-0 mt-0.5" />
      <span>{{ warnings[0] }}</span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, computed } from 'vue';
import { Search, X, AlertCircle, AlertTriangle } from 'lucide-vue-next';

const props = withDefaults(
  defineProps<{
    modelValue: string;
    placeholder?: string;
    errors?: string[];
    warnings?: string[];
  }>(),
  {
    placeholder: 'Buscar producto, PLU, marca...',
    errors: () => [],
    warnings: () => [],
  }
);

const emit = defineEmits<{
  'update:modelValue': [value: string];
  'submit-shortcuts': [rawInput: string];
  'clear': [];
}>();

const inputRef = ref<HTMLInputElement | null>(null);
const inputValue = ref(props.modelValue);

watch(
  () => props.modelValue,
  (newVal) => {
    inputValue.value = newVal;
  }
);

const hasErrors = computed(() => props.errors && props.errors.length > 0);
const hasWarnings = computed(() => props.warnings && props.warnings.length > 0);

const handleInput = () => {
  emit('update:modelValue', inputValue.value);
};

const handleEnter = () => {
  emit('submit-shortcuts', inputValue.value);
};

const handleClear = () => {
  inputValue.value = '';
  emit('update:modelValue', '');
  emit('clear');
  inputRef.value?.focus();
};
</script>

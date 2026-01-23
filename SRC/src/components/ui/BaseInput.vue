<script setup lang="ts">
import { computed, ref, nextTick } from 'vue';

defineOptions({
  inheritAttrs: false // Evita que atributos como maxlength se apliquen al div contenedor
});

interface Props {
    modelValue: string | number;
    label?: string;
    type?: string;
    placeholder?: string;
    error?: string;
    disabled?: boolean;
    required?: boolean;
    icon?: string;
    id?: string;
    list?: string;
    autocomplete?: string;
}

const props = withDefaults(defineProps<Props>(), {
    type: 'text',
    modelValue: '',
    disabled: false,
    required: false,
    id: () => `input-${Math.random().toString(36).substr(2, 9)}`,
    autocomplete: 'off', // Default to off to prevent browser dirty suggestions
});

const emit = defineEmits<{
    (e: 'update:modelValue', value: string | number): void;
    (e: 'blur', event: FocusEvent): void;
    (e: 'focus', event: FocusEvent): void;
}>();

const inputClasses = computed(() => {
    const base = 'block w-full rounded-md shadow-sm sm:text-sm transition-colors focus:outline-none disabled:bg-gray-100 disabled:text-gray-500 dark:disabled:bg-gray-800 dark:bg-gray-700 dark:text-white';
    const state = props.error
        ? 'border-red-300 text-red-900 placeholder-red-300 focus:border-red-500 focus:ring-red-500 dark:border-red-500'
        : 'border-gray-300 focus:border-blue-500 focus:ring-blue-500 dark:border-gray-600';

    return [base, state, props.icon ? 'pl-10' : 'pl-3'].join(' ');
});

const inputRef = ref<HTMLInputElement | null>(null);

const handleInput = (event: Event) => {
    const target = event.target as HTMLInputElement;
    emit('update:modelValue', target.value);

    // FIX: Forzar actualización del DOM si el padre sanitiza el valor (y por tanto el prop no cambia)
    nextTick(() => {
        if (inputRef.value && inputRef.value.value !== String(props.modelValue)) {
            inputRef.value.value = String(props.modelValue);
        }
    });
};

defineExpose({
    focus: () => inputRef.value?.focus(),
});
</script>

<template>
    <div class="space-y-1">
        <label v-if="label" :for="id" class="block text-sm font-medium text-gray-700 dark:text-gray-200">
            {{ label }} <span v-if="required" class="text-red-500">*</span>
        </label>

        <div class="relative rounded-md shadow-sm">
            <div v-if="icon" class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
                <span class="material-symbols-outlined text-gray-400 text-lg">{{ icon }}</span>
            </div>

            <input 
                ref="inputRef" 
                v-bind="$attrs"
                :id="id" 
                :type="type" 
                :value="modelValue" 
                :disabled="disabled" 
                :placeholder="placeholder" 
                :list="list"
                :autocomplete="autocomplete"
                :aria-invalid="!!error" 
                :aria-describedby="error ? `${id}-error` : undefined" 
                :class="inputClasses"
                class="py-2 pr-3" 
                @input="handleInput" 
                @blur="emit('blur', $event)" 
                @focus="emit('focus', $event)" 
            />
        </div>

        <p v-if="error" :id="`${id}-error`" class="mt-1 text-sm text-red-600 dark:text-red-400">
            {{ error }}
        </p>
    </div>
</template>

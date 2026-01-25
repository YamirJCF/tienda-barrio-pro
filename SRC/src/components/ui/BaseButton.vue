<script setup lang="ts">
import { computed } from 'vue';
import { Loader2 } from 'lucide-vue-next';

interface Props {
    variant?: 'primary' | 'secondary' | 'danger' | 'ghost' | 'outline' | 'success' | 'dark';
    size?: 'sm' | 'md' | 'lg' | 'icon';
    type?: 'button' | 'submit' | 'reset';
    disabled?: boolean;
    loading?: boolean;
    icon?: any; // Changed from string to any to support Component
}

const props = withDefaults(defineProps<Props>(), {
    variant: 'primary',
    size: 'md',
    type: 'button',
    disabled: false,
    loading: false,
});

const emit = defineEmits<{
    (e: 'click', event: MouseEvent): void;
}>();

const baseClasses = 'inline-flex items-center justify-center font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed rounded-lg active:scale-95 transition-transform';

const variantClasses = computed(() => {
    const variants = {
        primary: 'bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500 border-transparent',
        secondary: 'bg-gray-200 text-gray-900 hover:bg-gray-300 focus:ring-gray-500 border-transparent dark:bg-gray-700 dark:text-gray-100 dark:hover:bg-gray-600',
        danger: 'bg-red-600 text-white hover:bg-red-700 focus:ring-red-500 border-transparent',
        success: 'bg-emerald-600 text-white hover:bg-emerald-700 focus:ring-emerald-500 border-transparent',
        dark: 'bg-slate-800 text-white hover:bg-slate-900 focus:ring-slate-500 border-transparent shadow-lg',
        ghost: 'bg-transparent text-gray-700 hover:bg-gray-100 focus:ring-gray-500 dark:text-gray-300 dark:hover:bg-gray-800',
        outline: 'bg-transparent border border-gray-300 text-gray-700 hover:bg-gray-50 focus:ring-blue-500 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-800',
    };
    return variants[props.variant];
});

const sizeClasses = computed(() => {
    const sizes = {
        sm: 'text-xs px-2.5 py-1.5 gap-1.5',
        md: 'text-sm px-4 py-2 gap-2',
        lg: 'text-base px-6 py-3 gap-2.5',
        icon: 'p-2',
    };
    return sizes[props.size];
});

const handleClick = (event: MouseEvent) => {
    if (!props.disabled && !props.loading) {
        emit('click', event);
    }
};
</script>

<template>
    <button :type="type" :class="[baseClasses, variantClasses, sizeClasses]" :disabled="disabled || loading"
        @click="handleClick">
        <Loader2 v-if="loading" class="animate-spin text-lg" :size="size === 'lg' ? 24 : 20" />
        <component :is="icon" v-if="icon && !loading" class="text-lg" :size="size === 'lg' ? 24 : 20" />
        <slot />
    </button>
</template>

<script setup lang="ts">
/**
 * SPEC-008: Modal de Alerta Crítica Bloqueante
 * Modal que bloquea la UI hasta que el usuario tome acción
 * Casos de uso: PIN fallidos múltiples, stock crítico, errores de sincronización
 */
import { computed } from 'vue';

interface Props {
    isVisible: boolean;
    type?: 'error' | 'warning' | 'security' | 'info';
    title: string;
    message: string;
    primaryAction?: string;
    secondaryAction?: string;
    showDismiss?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
    type: 'warning',
    primaryAction: 'Entendido',
    secondaryAction: undefined,
    showDismiss: true
});

const emit = defineEmits<{
    (e: 'primary'): void;
    (e: 'secondary'): void;
    (e: 'dismiss'): void;
}>();

const iconConfig = computed(() => {
    const configs = {
        error: { icon: 'error', bgColor: 'bg-red-100 dark:bg-red-900/30', textColor: 'text-red-500', borderColor: 'border-red-500' },
        warning: { icon: 'warning', bgColor: 'bg-amber-100 dark:bg-amber-900/30', textColor: 'text-amber-500', borderColor: 'border-amber-500' },
        security: { icon: 'shield', bgColor: 'bg-red-100 dark:bg-red-900/30', textColor: 'text-red-600', borderColor: 'border-red-600' },
        info: { icon: 'info', bgColor: 'bg-blue-100 dark:bg-blue-900/30', textColor: 'text-blue-500', borderColor: 'border-blue-500' },
    };
    return configs[props.type];
});

const primaryButtonClass = computed(() => {
    if (props.type === 'error' || props.type === 'security') {
        return 'bg-red-500 hover:bg-red-600 text-white';
    }
    if (props.type === 'warning') {
        return 'bg-amber-500 hover:bg-amber-600 text-white';
    }
    return 'bg-primary hover:bg-blue-600 text-white';
});
</script>

<template>
    <Teleport to="body">
        <Transition name="modal">
            <div v-if="isVisible" class="fixed inset-0 z-[300] flex items-center justify-center p-4">
                <!-- Overlay - NO permite cerrar al hacer click -->
                <div class="absolute inset-0 bg-black/70 backdrop-blur-sm"></div>

                <!-- Modal Content -->
                <div class="relative w-full max-w-sm bg-white dark:bg-slate-800 rounded-2xl shadow-2xl overflow-hidden animate-scale-in"
                    :class="`border-t-4 ${iconConfig.borderColor}`">

                    <!-- Content -->
                    <div class="p-6 flex flex-col items-center text-center gap-4">
                        <!-- Icon -->
                        <div class="flex h-16 w-16 items-center justify-center rounded-full"
                            :class="iconConfig.bgColor">
                            <span class="material-symbols-outlined text-4xl" :class="iconConfig.textColor">
                                {{ iconConfig.icon }}
                            </span>
                        </div>

                        <!-- Title -->
                        <h2 class="text-xl font-bold text-slate-900 dark:text-white">
                            {{ title }}
                        </h2>

                        <!-- Message -->
                        <p class="text-sm text-slate-600 dark:text-slate-300 leading-relaxed">
                            {{ message }}
                        </p>

                        <!-- Actions -->
                        <div class="flex flex-col gap-3 w-full mt-2">
                            <button @click="emit('primary')"
                                class="w-full h-12 rounded-xl font-semibold transition-colors shadow-lg"
                                :class="primaryButtonClass">
                                {{ primaryAction }}
                            </button>

                            <button v-if="secondaryAction" @click="emit('secondary')"
                                class="w-full h-11 rounded-xl border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300 font-semibold hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors">
                                {{ secondaryAction }}
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </Transition>
    </Teleport>
</template>

<style scoped>
.modal-enter-active,
.modal-leave-active {
    transition: opacity 0.3s ease;
}

.modal-enter-from,
.modal-leave-to {
    opacity: 0;
}

.animate-scale-in {
    animation: scaleIn 0.3s ease-out;
}

@keyframes scaleIn {
    from {
        opacity: 0;
        transform: scale(0.9);
    }

    to {
        opacity: 1;
        transform: scale(1);
    }
}
</style>

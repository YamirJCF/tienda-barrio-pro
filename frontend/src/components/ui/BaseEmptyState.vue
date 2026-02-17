<script setup lang="ts">
/**
 * BaseEmptyState - Componente reutilizable para estados vacíos.
 * Reemplaza los bloques ad-hoc de "No hay datos" en las vistas.
 * Incluye detección automática de modo offline.
 *
 * Uso:
 *   <BaseEmptyState
 *     title="Sin productos"
 *     description="Agrega tu primer producto."
 *     :icon="Package"
 *     action-label="Crear Producto"
 *     @action="openModal"
 *   />
 */
import { computed, type Component } from 'vue';
import { WifiOff } from 'lucide-vue-next';

const props = withDefaults(
  defineProps<{
    /** Título del estado vacío */
    title: string;
    /** Descripción o ayuda contextual */
    description?: string;
    /** Componente de ícono Lucide */
    icon?: Component;
    /** Tamaño del ícono */
    iconSize?: number;
    /** Texto del botón de acción (opcional) */
    actionLabel?: string;
    /** Si es true, muestra el ícono de desconexión y mensaje offline */
    offline?: boolean;
  }>(),
  {
    iconSize: 56,
    offline: false,
  }
);

defineEmits<{
  (e: 'action'): void;
}>();

const displayTitle = computed(() => {
  if (props.offline) return 'Sin conexión';
  return props.title;
});

const displayDescription = computed(() => {
  if (props.offline) return 'Mostrando solo datos locales. Verifica tu conexión a internet.';
  return props.description;
});
</script>

<template>
  <div class="flex-1 flex flex-col items-center justify-center px-6 py-12 text-center">
    <!-- Ícono -->
    <div class="mb-4 text-slate-300 dark:text-slate-600">
      <component
        v-if="offline"
        :is="WifiOff"
        :size="iconSize"
        :stroke-width="1"
      />
      <component
        v-else-if="icon"
        :is="icon"
        :size="iconSize"
        :stroke-width="1"
      />
    </div>

    <!-- Título -->
    <h3 class="text-lg font-bold text-slate-900 dark:text-white mb-2">
      {{ displayTitle }}
    </h3>

    <!-- Descripción -->
    <p
      v-if="displayDescription"
      class="text-sm text-slate-500 dark:text-slate-400 max-w-xs leading-relaxed"
    >
      {{ displayDescription }}
    </p>

    <!-- Acción -->
    <button
      v-if="actionLabel && !offline"
      @click="$emit('action')"
      class="mt-6 inline-flex items-center gap-2 px-5 py-2.5 bg-primary text-white text-sm font-semibold rounded-xl shadow-md hover:bg-primary-dark transition-all active:scale-95"
    >
      <slot name="action-icon" />
      {{ actionLabel }}
    </button>
  </div>
</template>

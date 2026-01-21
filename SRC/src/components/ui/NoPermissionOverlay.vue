<script setup lang="ts">
/**
 * NoPermissionOverlay - Reusable overlay for permission-restricted views.
 * Displays a full-screen overlay when user lacks permission.
 */
defineProps<{
  title?: string;
  message?: string;
  buttonText?: string;
}>();

const emit = defineEmits<{
  goBack: [];
}>();
</script>

<template>
  <div
    class="absolute inset-0 z-50 bg-slate-900/95 backdrop-blur-sm flex flex-col items-center justify-center p-6"
  >
    <div class="flex flex-col items-center text-center max-w-xs">
      <!-- Icon -->
      <div class="h-20 w-20 rounded-full bg-yellow-500/20 flex items-center justify-center mb-6">
        <span class="material-symbols-outlined text-yellow-500 text-[48px]">block</span>
      </div>

      <!-- Title -->
      <h2 class="text-white text-2xl font-black mb-2">
        {{ title || 'Sin Permiso' }}
      </h2>

      <!-- Message -->
      <p class="text-slate-400 text-sm mb-6">
        {{
          message ||
          'No tienes permiso para acceder a esta sección. Contacta a tu administrador si necesitas acceso.'
        }}
      </p>

      <!-- Action Button -->
      <button
        class="px-6 py-3 bg-slate-700 hover:bg-slate-600 text-white font-bold rounded-xl transition-colors"
        @click="emit('goBack')"
      >
        {{ buttonText || 'Volver al Inicio' }}
      </button>
    </div>
  </div>
</template>

<template>
  <div
    class="skeleton animate-pulse bg-slate-200 dark:bg-slate-700/50"
    :class="[roundedClass]"
    :style="{ width, height }"
  ></div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    width?: string;
    height?: string;
    borderRadius?: string;
    circle?: boolean;
  }>(),
  {
    width: '100%',
    height: '1rem',
    borderRadius: '0.5rem',
    circle: false,
  }
);

const roundedClass = computed(() => {
  if (props.circle) return 'rounded-full';
  return ''; // Default handled by style or could be a class if needed, but style is more flexible for overrides
});
</script>

<style scoped>
.skeleton {
  border-radius: v-bind(borderRadius);
}
</style>

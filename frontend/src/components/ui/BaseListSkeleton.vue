<script setup lang="ts">
/**
 * BaseListSkeleton - Componente reutilizable para estados de carga de listas.
 * Reemplaza los bloques manuales v-for de Skeletons dispersos en las vistas.
 * 
 * Uso:
 *   <BaseListSkeleton v-if="store.isLoading" :count="6" type="card" />
 */
import Skeleton from './Skeleton.vue';

type SkeletonType = 'card' | 'simple' | 'detail';

withDefaults(
  defineProps<{
    /** Cantidad de filas skeleton a mostrar */
    count?: number;
    /** Tipo de skeleton: card (producto), simple (línea), detail (cliente) */
    type?: SkeletonType;
  }>(),
  {
    count: 6,
    type: 'card',
  }
);
</script>

<template>
  <div class="flex flex-col gap-3">
    <!-- Tipo: Card (Inventario, Productos) -->
    <template v-if="type === 'card'">
      <article
        v-for="i in count"
        :key="i"
        class="bg-white dark:bg-surface-dark rounded-2xl p-4 shadow-sm border border-gray-100 dark:border-gray-800 flex flex-col gap-3"
      >
        <div class="flex justify-between items-start gap-4">
          <div class="flex-1 space-y-2">
            <Skeleton width="70%" height="1.25rem" />
            <div class="flex gap-2">
              <Skeleton width="40px" height="0.75rem" />
              <Skeleton width="60px" height="0.75rem" />
            </div>
            <Skeleton width="30%" height="1.25rem" class="mt-1" />
          </div>
          <div>
            <Skeleton width="80px" height="1.75rem" />
          </div>
        </div>
        <div class="flex justify-between items-center pt-2 border-t border-gray-50 dark:border-gray-800">
          <Skeleton width="100px" height="1.5rem" />
          <div class="flex gap-1">
            <Skeleton width="36px" height="36px" border-radius="0.75rem" />
            <Skeleton width="36px" height="36px" border-radius="0.75rem" />
          </div>
        </div>
      </article>
    </template>

    <!-- Tipo: Detail (Clientes con avatar) -->
    <template v-else-if="type === 'detail'">
      <div
        v-for="i in count"
        :key="i"
        class="flex items-center gap-3 bg-white dark:bg-slate-800 rounded-2xl shadow-sm p-3 border-l-[6px] border-slate-200 dark:border-slate-700"
      >
        <Skeleton width="48px" height="48px" border-radius="18px" />
        <div class="flex flex-1 flex-col justify-center min-w-0 gap-2">
          <Skeleton width="60%" height="1rem" />
          <Skeleton width="40%" height="0.75rem" />
        </div>
        <div class="flex flex-col items-end gap-1">
          <Skeleton width="80px" height="1.25rem" />
          <Skeleton width="40px" height="0.75rem" />
        </div>
      </div>
    </template>

    <!-- Tipo: Simple (líneas genéricas) -->
    <template v-else>
      <div
        v-for="i in count"
        :key="i"
        class="bg-white dark:bg-surface-dark rounded-xl p-3 shadow-sm border border-gray-100 dark:border-gray-800 flex items-center gap-3"
      >
        <Skeleton width="40px" height="40px" border-radius="0.5rem" />
        <div class="flex-1 space-y-2">
          <Skeleton width="65%" height="1rem" />
          <Skeleton width="40%" height="0.75rem" />
        </div>
      </div>
    </template>
  </div>
</template>

<script setup lang="ts">
import BaseButton from '../ui/BaseButton.vue';

defineProps<{
  isQuantityMode: boolean;
}>();

const emit = defineEmits<{
  (e: 'click', value: string): void;
  (e: 'backspace'): void;
  (e: 'quantity'): void;
  (e: 'add'): void;
}>();
</script>

<template>
  <div class="grid grid-cols-4 gap-2 h-auto select-none">
    <!-- Row 1 -->
    <BaseButton
      v-for="num in ['7', '8', '9']"
      :key="num"
      @click="emit('click', num)"
      variant="secondary"
      class="h-14 text-2xl font-medium !bg-white dark:!bg-gray-800 !border-gray-200 dark:!border-gray-600 shadow-sm active:!bg-gray-100 dark:active:!bg-gray-700 hover:scale-100"
    >
      {{ num }}
    </BaseButton>

    <!-- CANT. × Button -->
    <button
      class="h-14 border rounded-xl flex items-center justify-center active:scale-95 touch-manipulation transition-all"
      :class="
        isQuantityMode
          ? 'bg-amber-500 border-amber-600 text-white shadow-lg shadow-amber-500/20'
          : 'bg-amber-50 dark:bg-amber-900/30 border-amber-200 dark:border-amber-800 text-amber-700 dark:text-amber-400 hover:bg-amber-100'
      "
      @click="emit('quantity')"
    >
      <span class="text-xs font-bold uppercase block w-full text-center leading-none">
        Cant.<br /><span class="text-xl">×</span>
      </span>
    </button>

    <!-- Row 2 -->
    <BaseButton
      v-for="num in ['4', '5', '6']"
      :key="num"
      @click="emit('click', num)"
      variant="secondary"
      class="h-14 text-2xl font-medium !bg-white dark:!bg-gray-800 !border-gray-200 dark:!border-gray-600 shadow-sm active:!bg-gray-100 dark:active:!bg-gray-700 hover:scale-100"
    >
      {{ num }}
    </BaseButton>

    <button
      class="h-14 bg-red-50 dark:bg-red-900/30 border border-red-200 dark:border-red-800 rounded-xl flex items-center justify-center text-red-600 dark:text-red-400 active:bg-red-100 dark:active:bg-red-900/50 touch-manipulation transition-transform active:scale-95"
      @click="emit('backspace')"
    >
      <span class="material-symbols-outlined">backspace</span>
    </button>

    <!-- Row 3 & 4 (Special Layout) -->
    <!-- Column 1-3 Wrapper -->
    <div class="col-span-3 grid grid-cols-3 gap-2">
      <BaseButton
        v-for="num in ['1', '2', '3']"
        :key="num"
        @click="emit('click', num)"
        variant="secondary"
        class="h-14 text-2xl font-medium !bg-white dark:!bg-gray-800 !border-gray-200 dark:!border-gray-600 shadow-sm active:!bg-gray-100 dark:active:!bg-gray-700 hover:scale-100"
      >
        {{ num }}
      </BaseButton>

      <BaseButton
        @click="emit('click', '0')"
        variant="secondary"
        class="h-14 text-2xl font-medium !bg-white dark:!bg-gray-800 !border-gray-200 dark:!border-gray-600 shadow-sm active:!bg-gray-100 dark:active:!bg-gray-700 hover:scale-100"
      >
        0
      </BaseButton>
      <BaseButton
        @click="emit('click', '00')"
        variant="secondary"
        class="h-14 text-2xl font-medium !bg-white dark:!bg-gray-800 !border-gray-200 dark:!border-gray-600 shadow-sm active:!bg-gray-100 dark:active:!bg-gray-700 hover:scale-100"
      >
         00
      </BaseButton>
      <BaseButton
        @click="emit('click', '.')"
        variant="secondary"
        class="h-14 text-2xl font-medium !bg-white dark:!bg-gray-800 !border-gray-200 dark:!border-gray-600 shadow-sm active:!bg-gray-100 dark:active:!bg-gray-700 hover:scale-100"
      >
        .
      </BaseButton>
    </div>

    <!-- Add Button (Row Span 2) -->
    <button
      class="col-span-1 row-span-2 bg-blue-600 dark:bg-blue-700 hover:bg-blue-700 text-white rounded-xl shadow-lg shadow-blue-500/30 active:scale-95 active:shadow-inner transition-all flex flex-col items-center justify-center gap-1 border-b-4 border-blue-800 touch-manipulation"
      @click="emit('add')"
    >
      <span class="material-symbols-outlined text-3xl font-bold">add</span>
      <span class="text-[10px] font-bold uppercase tracking-wider">Agregar</span>
    </button>
  </div>
</template>

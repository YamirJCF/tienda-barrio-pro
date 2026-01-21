<script setup lang="ts">
import { ref, watch } from 'vue';

// Props
interface Props {
  modelValue: boolean;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  add: [item: { name: string; price: number }];
}>();

// State
const itemName = ref('');
const itemPrice = ref('');
const nameInput = ref<HTMLInputElement | null>(null);

// Methods
const close = () => {
  emit('update:modelValue', false);
  resetForm();
};

const resetForm = () => {
  itemName.value = '';
  itemPrice.value = '';
};

const addItem = () => {
  if (!itemName.value.trim() || !itemPrice.value) return;

  emit('add', {
    name: itemName.value.trim(),
    price: parseFloat(itemPrice.value),
  });
  close();
};

const isValid = () => {
  return itemName.value.trim() !== '' && itemPrice.value !== '' && parseFloat(itemPrice.value) > 0;
};

// Focus input when modal opens
watch(
  () => props.modelValue,
  (isOpen) => {
    if (isOpen) {
      setTimeout(() => {
        nameInput.value?.focus();
      }, 100);
    }
  },
);
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div
        v-if="modelValue"
        class="fixed inset-0 z-50 flex items-end justify-center"
        @click.self="close"
      >
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-slate-900/60 backdrop-blur-[2px]" @click="close"></div>

        <!-- Modal -->
        <div
          class="relative w-full max-w-md bg-white dark:bg-background-dark rounded-t-2xl shadow-2xl flex flex-col animate-slide-up"
        >
          <!-- Header -->
          <div class="border-b border-gray-200 dark:border-gray-700 rounded-t-2xl">
            <!-- Drag Handle -->
            <div class="flex justify-center pt-3 pb-2 cursor-pointer" @click="close">
              <div class="h-1.5 w-12 rounded-full bg-gray-300 dark:bg-gray-600"></div>
            </div>

            <!-- Title -->
            <div class="flex items-center justify-between px-4 pb-3">
              <div class="flex items-center gap-2">
                <span class="material-symbols-outlined text-primary text-xl">edit_note</span>
                <h2 class="text-lg font-bold text-gray-900 dark:text-white">
                  Agregar Nota / Varios
                </h2>
              </div>
              <button
                class="flex h-8 w-8 items-center justify-center rounded-full text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700"
                @click="close"
              >
                <span class="material-symbols-outlined text-xl">close</span>
              </button>
            </div>
          </div>

          <!-- Form -->
          <div class="p-4 space-y-4">
            <!-- Description -->
            <div>
              <label
                class="block text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-1.5"
              >
                Descripción
              </label>
              <input
                ref="nameInput"
                v-model="itemName"
                type="text"
                placeholder="Ej. Servicio, Producto especial..."
                class="w-full h-11 px-3 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder:text-gray-400 focus:border-primary focus:ring-1 focus:ring-primary outline-none text-sm"
              />
            </div>

            <!-- Price -->
            <div>
              <label class="block text-xs font-bold text-primary uppercase tracking-wider mb-1.5">
                Precio
              </label>
              <div class="relative">
                <span class="absolute left-3 top-3 text-primary font-bold text-sm">$</span>
                <input
                  v-model="itemPrice"
                  type="number"
                  placeholder="0"
                  class="w-full h-11 pl-7 pr-3 rounded-lg border border-primary/30 bg-primary/5 dark:bg-primary/10 text-primary font-bold placeholder:text-primary/40 focus:border-primary focus:ring-1 focus:ring-primary outline-none text-lg"
                />
              </div>
            </div>
          </div>

          <!-- Actions -->
          <div class="p-4 pt-0 grid grid-cols-2 gap-3 pb-8">
            <button
              class="h-11 rounded-xl bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-200 font-bold text-sm hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors"
              @click="close"
            >
              Cancelar
            </button>
            <button
              class="h-11 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-sm shadow-lg shadow-primary/20 transition-colors flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
              :disabled="!isValid()"
              @click="addItem"
            >
              <span class="material-symbols-outlined text-lg">add</span>
              Agregar
            </button>
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

@keyframes slideUp {
  from {
    transform: translateY(100%);
  }
  to {
    transform: translateY(0);
  }
}

.animate-slide-up {
  animation: slideUp 0.3s ease-out;
}
</style>

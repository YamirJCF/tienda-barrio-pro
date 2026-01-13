<script setup lang="ts">
import { ref, watch } from 'vue';

interface Props {
  modelValue: boolean;
  currentNote: string;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'save': [note: string];
}>();

// State
const noteText = ref('');

// Methods
const close = () => {
  emit('update:modelValue', false);
};

const save = () => {
  emit('save', noteText.value);
  close();
};

const clear = () => {
  noteText.value = '';
};

// Sync with current note when modal opens
watch(() => props.modelValue, (isOpen) => {
  if (isOpen) {
    noteText.value = props.currentNote || '';
  }
});
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
        <div class="relative w-full max-w-md bg-white dark:bg-surface-dark rounded-t-3xl shadow-2xl flex flex-col animate-slide-up">
          <!-- Drag Handle -->
          <div class="flex justify-center pt-3 pb-2 cursor-pointer" @click="close">
            <div class="h-1.5 w-12 rounded-full bg-gray-300 dark:bg-gray-600"></div>
          </div>
          
          <!-- Header -->
          <div class="px-4 pb-3 flex items-center justify-between">
            <h3 class="text-lg font-bold text-slate-900 dark:text-white">Nota del Ticket</h3>
            <button 
              v-if="noteText"
              @click="clear"
              class="text-red-500 text-sm font-medium"
            >
              Limpiar
            </button>
          </div>
          
          <!-- Content -->
          <div class="px-4 pb-4">
            <textarea
              v-model="noteText"
              placeholder="Escribe una nota para este ticket..."
              class="w-full h-32 p-3 rounded-xl border border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800 text-gray-900 dark:text-white placeholder:text-gray-400 focus:border-primary focus:ring-1 focus:ring-primary outline-none text-sm resize-none"
              autofocus
            ></textarea>
            
            <!-- Suggested Notes -->
            <div class="flex flex-wrap gap-2 mt-3">
              <button 
                v-for="suggestion in ['Sin bolsa', 'Entrega después', 'Cliente frecuente', 'Pendiente']"
                :key="suggestion"
                @click="noteText = noteText ? `${noteText}, ${suggestion}` : suggestion"
                class="px-3 py-1.5 rounded-full bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300 text-xs font-medium hover:bg-gray-200 dark:hover:bg-gray-600 active:scale-95 transition-all"
              >
                {{ suggestion }}
              </button>
            </div>
          </div>
          
          <!-- Actions -->
          <div class="px-4 pb-6 flex gap-2">
            <button
              @click="close"
              class="flex-1 h-12 rounded-xl bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-200 font-semibold active:scale-[0.98] transition-all"
            >
              Cancelar
            </button>
            <button
              @click="save"
              class="flex-1 h-12 rounded-xl bg-primary text-white font-semibold active:scale-[0.98] transition-all flex items-center justify-center gap-2"
            >
              <span class="material-symbols-outlined text-xl">save</span>
              Guardar
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
  from { transform: translateY(100%); }
  to { transform: translateY(0); }
}

.animate-slide-up {
  animation: slideUp 0.3s ease-out;
}
</style>

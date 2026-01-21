<template>
  <Transition
    enter-active-class="transform ease-out duration-300 transition"
    enter-from-class="translate-y-2 opacity-0 sm:translate-y-0 sm:translate-x-2"
    enter-to-class="translate-y-0 opacity-100 sm:translate-x-0"
    leave-active-class="transition ease-in duration-100"
    leave-from-class="opacity-100"
    leave-to-class="opacity-0"
  >
    <div v-if="!isOnline" class="fixed bottom-4 right-4 z-50 max-w-sm w-full bg-white shadow-lg rounded-lg pointer-events-auto ring-1 ring-black ring-opacity-5 overflow-hidden">
      <div class="p-4">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            <i class="material-icons text-gray-400">wifi_off</i>
          </div>
          <div class="ml-3 w-0 flex-1 pt-0.5">
            <p class="text-sm font-medium text-gray-900">Estás en modo Offline</p>
            <p class="mt-1 text-sm text-gray-500">
              Las ventas se guardarán localmente y se sincronizarán cuando recuperes la conexión.
            </p>
          </div>
          <!-- Close button -->
          <div class="ml-4 flex-shrink-0 flex">
            <button @click="dismiss" class="bg-white rounded-md inline-flex text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
              <span class="sr-only">Cerrar</span>
              <i class="material-icons text-lg">close</i>
            </button>
          </div>
        </div>
      </div>
    </div>
  </Transition>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import { useDataSource } from '../../composables/useDataSource';

const { isOnline } = useDataSource();
const dismissed = ref(false);

const dismiss = () => {
    dismissed.value = true;
};

// Reset dismiss when status changes
watch(isOnline, (val) => {
    if (val) dismissed.value = false;
});
</script>

<script setup lang="ts">
import { ref, watch, computed } from 'vue';
import { useClientsStore, type Client } from '../stores/clients';
import { Decimal } from 'decimal.js';

// Props
interface Props {
  modelValue: boolean;
  clientId?: number;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  saved: [client: Client];
}>();

const clientsStore = useClientsStore();

// Form state
const formData = ref({
  name: '',
  cedula: '',
  phone: '',
  creditLimit: '',
});

// Computed
const isEdit = computed(() => !!props.clientId);
const modalTitle = computed(() => (isEdit.value ? 'Editar Cliente' : 'Datos del Cliente'));

const isValid = computed(() => {
  return formData.value.name.trim() !== '' && formData.value.cedula.trim() !== '';
});

// Methods
const resetForm = () => {
  formData.value = {
    name: '',
    cedula: '',
    phone: '',
    creditLimit: '',
  };
};

const close = () => {
  emit('update:modelValue', false);
  setTimeout(resetForm, 300);
};

const save = () => {
  if (!isValid.value) return;

  const data = {
    name: formData.value.name.trim(),
    cedula: formData.value.cedula.trim(),
    phone: formData.value.phone.trim() || undefined,
    creditLimit: new Decimal(formData.value.creditLimit || 0),
  };

  let client: Client | null;

  if (isEdit.value && props.clientId) {
    client = clientsStore.updateClient(props.clientId, data);
  } else {
    client = clientsStore.addClient(data);
  }

  if (client) {
    emit('saved', client);
    close();
  }
};

// Load existing client data for editing
watch(
  () => [props.modelValue, props.clientId],
  ([show, clientId]) => {
    if (show && clientId) {
      const client = clientsStore.getClientById(clientId as number);
      if (client) {
        formData.value = {
          name: client.name,
          cedula: client.cedula,
          phone: client.phone || '',
          creditLimit: client.creditLimit.toString(),
        };
      }
    } else if (show && !clientId) {
      resetForm();
    }
  },
  { immediate: true },
);
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div
        v-if="modelValue"
        class="fixed inset-0 z-50 flex items-end justify-center bg-black/40 backdrop-blur-sm"
        @click.self="close"
      >
        <!-- Modal Container -->
        <div
          class="w-full max-w-md mx-auto bg-white dark:bg-[#1A202C] rounded-t-2xl shadow-2xl flex flex-col max-h-[92vh] overflow-hidden animate-slide-up"
        >
          <!-- Handle & Header -->
          <div class="flex-none pt-3 px-6 pb-2 bg-white dark:bg-[#1A202C]">
            <!-- Drag Handle -->
            <div class="w-full flex justify-center mb-4">
              <div
                class="h-1.5 w-12 rounded-full bg-gray-300 dark:bg-gray-600"
                @click="close"
              ></div>
            </div>
            <!-- Title Row -->
            <div class="flex justify-between items-center">
              <h2 class="text-xl font-bold text-gray-900 dark:text-white tracking-tight">
                {{ modalTitle }}
              </h2>
              <button
                @click="close"
                class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 transition-colors p-2 -mr-2 rounded-full"
              >
                <span class="material-symbols-outlined text-2xl">close</span>
              </button>
            </div>
            <div class="h-[1px] w-full bg-gray-100 dark:bg-gray-700 mt-4"></div>
          </div>

          <!-- Scrollable Form Content -->
          <div class="flex-1 overflow-y-auto px-6 py-4 space-y-5">
            <!-- Field 1: Name -->
            <div class="flex flex-col gap-2">
              <label class="text-gray-700 dark:text-gray-300 text-sm font-semibold leading-normal">
                Nombre Completo
              </label>
              <div class="relative">
                <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400">
                  <span class="material-symbols-outlined text-[20px]">person</span>
                </span>
                <input
                  v-model="formData.name"
                  class="form-input flex w-full rounded-xl text-gray-900 dark:text-white border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800/50 focus:border-primary focus:ring-1 focus:ring-primary h-12 pl-11 pr-4 text-base font-normal placeholder:text-gray-400 transition-all"
                  placeholder="Ej. María Pérez"
                  type="text"
                />
              </div>
            </div>

            <!-- Field 2: ID (Critical) -->
            <div class="flex flex-col gap-2">
              <label
                class="text-gray-700 dark:text-gray-300 text-sm font-semibold leading-normal flex justify-between"
              >
                <span>Número de Identificación (Cédula)</span>
                <span
                  class="text-xs font-normal text-primary bg-primary/10 px-2 py-0.5 rounded-full"
                  >Requerido</span
                >
              </label>
              <div class="relative group">
                <span
                  class="absolute left-4 top-1/2 -translate-y-1/2 text-primary group-focus-within:text-primary"
                >
                  <span class="material-symbols-outlined text-[20px]">badge</span>
                </span>
                <input
                  v-model="formData.cedula"
                  class="form-input flex w-full rounded-xl text-gray-900 dark:text-white border-2 border-primary/30 dark:border-primary/40 bg-white dark:bg-gray-800 focus:border-primary focus:ring-0 h-14 pl-11 pr-4 text-lg font-medium placeholder:text-gray-400 shadow-sm transition-all"
                  inputmode="numeric"
                  pattern="[0-9]*"
                  placeholder="Ej. 1020304050"
                  type="tel"
                  :disabled="isEdit"
                />
                <p class="text-xs text-gray-500 mt-1.5 ml-1">
                  Único identificador válido para deudas.
                </p>
              </div>
            </div>

            <!-- Field 3: Phone -->
            <div class="flex flex-col gap-2">
              <label class="text-gray-700 dark:text-gray-300 text-sm font-semibold leading-normal">
                Teléfono <span class="text-gray-400 font-normal">(Opcional)</span>
              </label>
              <div class="relative">
                <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400">
                  <span class="material-symbols-outlined text-[20px]">call</span>
                </span>
                <input
                  v-model="formData.phone"
                  class="form-input flex w-full rounded-xl text-gray-900 dark:text-white border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800/50 focus:border-primary focus:ring-1 focus:ring-primary h-12 pl-11 pr-4 text-base font-normal placeholder:text-gray-400 transition-all"
                  placeholder="300 123 4567"
                  type="tel"
                />
              </div>
            </div>

            <!-- Field 4: Credit Limit -->
            <div class="flex flex-col gap-2">
              <label class="text-gray-700 dark:text-gray-300 text-sm font-semibold leading-normal">
                Cupo Máximo
              </label>
              <div class="relative">
                <span
                  class="absolute left-4 top-1/2 -translate-y-1/2 text-green-600 dark:text-green-400 font-bold text-lg"
                >
                  $
                </span>
                <input
                  v-model="formData.creditLimit"
                  class="form-input flex w-full rounded-xl text-gray-900 dark:text-white border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-800/50 focus:border-primary focus:ring-1 focus:ring-primary h-12 pl-10 pr-4 text-base font-normal placeholder:text-gray-400 transition-all"
                  placeholder="0"
                  type="number"
                />
                <div
                  class="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 pointer-events-none"
                >
                  <span class="material-symbols-outlined text-[20px]">credit_score</span>
                </div>
              </div>
              <p class="text-xs text-gray-500 ml-1">Límite de crédito permitido para fiar.</p>
            </div>

            <div class="h-4"></div>
          </div>

          <!-- Footer / Action Bar -->
          <div
            class="flex-none p-6 bg-white dark:bg-[#1A202C] border-t border-gray-100 dark:border-gray-700"
          >
            <div class="flex gap-4">
              <button
                @click="close"
                class="flex-1 h-12 rounded-xl border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 font-semibold text-base hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors focus:outline-none"
              >
                Cancelar
              </button>
              <button
                @click="save"
                :disabled="!isValid"
                class="flex-[2] h-12 rounded-xl bg-primary hover:bg-blue-700 text-white font-semibold text-base shadow-lg shadow-blue-500/30 flex items-center justify-center gap-2 transition-all active:scale-[0.98] focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <span class="material-symbols-outlined text-[20px]">save</span>
                Guardar Cliente
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

.animate-slide-up {
  animation: slideUp 0.3s ease-out;
}

@keyframes slideUp {
  from {
    transform: translateY(100%);
  }
  to {
    transform: translateY(0);
  }
}
</style>

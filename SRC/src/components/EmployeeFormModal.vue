<script setup lang="ts">
import { ref, watch, computed } from 'vue';
import { useEmployeesStore, type Employee } from '../stores/employees';

// Props
interface Props {
  modelValue: boolean;
  employeeId?: number;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  saved: [employee: Employee];
}>();

const employeesStore = useEmployeesStore();

// Form state
const formData = ref({
  name: '',
  username: '',
  pin: '',
  canSell: true,
  canViewInventory: true,
  canManageInventory: false,
  canOpenCloseCash: false,
});

// Computed
const isEdit = computed(() => !!props.employeeId);
const modalTitle = computed(() => (isEdit.value ? 'Editar Colaborador' : 'Nuevo Empleado'));

const isValid = computed(() => {
  return (
    formData.value.name.trim() !== '' &&
    formData.value.username.trim() !== '' &&
    formData.value.pin.length === 4
  );
});

// Methods
const resetForm = () => {
  formData.value = {
    name: '',
    username: '',
    pin: '',
    canSell: true,
    canViewInventory: true,
    canManageInventory: false,
    canOpenCloseCash: false,
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
    username: formData.value.username.trim(),
    pin: formData.value.pin,
    permissions: {
      canSell: formData.value.canSell,
      canViewInventory: true, // Always allow viewing if they exist
      canManageInventory: formData.value.canManageInventory,
      canViewReports: false, // Explicitly removed
      canFiar: false, // Explicitly removed
      canOpenCloseCash: formData.value.canOpenCloseCash,
    },
    isActive: true,
  };

  let employee: Employee | null;

  if (isEdit.value && props.employeeId) {
    employee = employeesStore.updateEmployee(props.employeeId, data);
  } else {
    employee = employeesStore.addEmployee(data);
  }

  if (employee) {
    emit('saved', employee);
    close();
  }
};

// Handle Username Input
const handleUsernameInput = (e: Event) => {
  const input = e.target as HTMLInputElement;
  const val = input.value.replace(/\D/g, '');
  formData.value.username = val;
  input.value = val;
};

// Handle PIN input
const handlePinInput = (e: Event) => {
  const input = e.target as HTMLInputElement;
  formData.value.pin = input.value.replace(/\D/g, '').slice(0, 4);
};

// Load existing employee data for editing
watch(
  () => [props.modelValue, props.employeeId],
  ([show, employeeId]) => {
    if (show && employeeId) {
      const employee = employeesStore.getEmployeeById(employeeId as number);
      if (employee) {
        formData.value = {
          name: employee.name,
          username: employee.username,
          pin: employee.pin,
          canSell: true, // Siempre true por regla de negocio
          canViewInventory: true,
          canManageInventory: employee.permissions.canManageInventory || false,
          canOpenCloseCash: employee.permissions.canOpenCloseCash || false,
        };
      }
    } else if (show && !employeeId) {
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
          class="w-full max-w-md mx-auto bg-white dark:bg-slate-800 rounded-t-2xl shadow-2xl flex flex-col max-h-[90vh] overflow-hidden animate-slide-up"
        >
          <!-- Handle -->
          <div class="flex justify-center pt-3 pb-1 cursor-grab" @click="close">
            <div class="h-1 w-12 rounded-full bg-gray-300 dark:bg-gray-600"></div>
          </div>

          <!-- Modal Header -->
          <div class="px-6 pb-4 pt-2 border-b border-gray-100 dark:border-gray-700">
            <h2 class="text-xl font-bold text-gray-900 dark:text-white">{{ modalTitle }}</h2>
          </div>

          <!-- Scrollable Form Area -->
          <div class="overflow-y-auto p-6 space-y-6 flex-1">
            <!-- Basic Info -->
            <div class="space-y-4">
              <div class="space-y-1.5">
                <label class="text-sm font-medium text-gray-600 dark:text-gray-400"
                  >Nombre Completo</label
                >
                <div class="relative">
                  <span
                    class="absolute left-3 top-1/2 -translate-y-1/2 material-symbols-outlined text-gray-400 text-[20px]"
                    >person</span
                  >
                  <input
                    v-model="formData.name"
                    class="w-full h-12 rounded-lg border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 pl-10 pr-4 text-sm focus:border-primary focus:ring-primary text-gray-900 dark:text-white placeholder-gray-400"
                    placeholder="Ej: Juan Pérez"
                    type="text"
                  />
                </div>
              </div>

              <div class="space-y-1.5">
                <label class="text-sm font-medium text-gray-600 dark:text-gray-400"
                  >Usuario de Acceso</label
                >
                <div class="relative">
                  <span
                    class="absolute left-3 top-1/2 -translate-y-1/2 material-symbols-outlined text-gray-400 text-[20px]"
                    >badge</span
                  >
                  <input
                    v-model="formData.username"
                    @input="handleUsernameInput"
                    class="w-full h-12 rounded-lg border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 pl-10 pr-4 text-sm focus:border-primary focus:ring-primary text-gray-900 dark:text-white placeholder-gray-400"
                    placeholder="Número de teléfono o identificación"
                    type="tel"
                    inputmode="numeric"
                  />
                </div>
              </div>
            </div>

            <!-- Security Section -->
            <div
              class="p-4 rounded-xl bg-blue-50/50 dark:bg-blue-900/10 border border-blue-100 dark:border-blue-800 space-y-3"
            >
              <div class="flex items-center gap-2 text-primary font-medium">
                <span class="material-symbols-outlined text-[20px]">lock</span>
                <span class="text-sm">Seguridad</span>
              </div>
              <div class="space-y-1.5">
                <label
                  class="text-xs font-medium uppercase tracking-wider text-gray-600 dark:text-gray-400"
                  >Asignar PIN (4 dígitos)</label
                >
                <input
                  :value="formData.pin"
                  @input="handlePinInput"
                  class="w-full h-12 rounded-lg border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-center text-lg tracking-[0.5em] font-bold focus:border-primary focus:ring-primary text-gray-900 dark:text-white"
                  maxlength="4"
                  inputmode="numeric"
                  placeholder="••••"
                  type="tel"
                />
                <p class="text-xs text-gray-500">El empleado usará este PIN para entrar.</p>
              </div>
            </div>

            <!-- Permissions -->
            <div class="space-y-3">
              <label class="text-sm font-medium text-gray-600 dark:text-gray-400 block"
                >Permisos</label
              >

              <label
                class="flex items-center gap-3 p-3 rounded-lg border border-gray-100 dark:border-gray-700 bg-gray-100 dark:bg-gray-800 cursor-not-allowed opacity-75"
              >
                <input
                  type="checkbox"
                  checked
                  disabled
                  class="size-5 rounded border-gray-300 text-primary focus:ring-primary cursor-not-allowed"
                />
                <span class="text-sm font-medium text-gray-900 dark:text-white"
                  >Puede Vender (Por defecto)</span
                >
              </label>

              <label
                class="flex items-center gap-3 p-3 rounded-lg border border-gray-100 dark:border-gray-700 bg-white dark:bg-gray-700/30 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors"
              >
                <input
                  v-model="formData.canManageInventory"
                  class="size-5 rounded border-gray-300 text-primary focus:ring-primary"
                  type="checkbox"
                />
                <span class="text-sm font-medium text-gray-900 dark:text-white"
                  >Inventario (Acceso Completo)</span
                >
              </label>

              <label
                class="flex items-center gap-3 p-3 rounded-lg border border-gray-100 dark:border-gray-700 bg-white dark:bg-gray-700/30 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors"
              >
                <input
                  v-model="formData.canOpenCloseCash"
                  class="size-5 rounded border-gray-300 text-primary focus:ring-primary"
                  type="checkbox"
                />
                <span class="text-sm font-medium text-gray-900 dark:text-white"
                  >Caja (Abrir/Cerrar)</span
                >
              </label>
            </div>
          </div>

          <!-- Modal Actions -->
          <div
            class="p-6 pt-2 pb-8 flex gap-3 border-t border-gray-100 dark:border-gray-700 bg-white dark:bg-slate-800"
          >
            <button
              @click="close"
              class="flex-1 h-12 rounded-xl text-sm font-semibold text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
            >
              Cancelar
            </button>
            <button
              @click="save"
              :disabled="!isValid"
              class="flex-1 h-12 rounded-xl bg-primary text-white text-sm font-bold shadow-lg shadow-blue-500/20 active:scale-95 transition-all hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed"
            >
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

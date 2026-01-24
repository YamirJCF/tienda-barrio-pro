<script setup lang="ts">
import { ref, watch, computed } from 'vue';
import { useEmployeesStore, type Employee } from '../stores/employees';
import BaseModal from './ui/BaseModal.vue';
import BaseInput from './ui/BaseInput.vue';
import BaseButton from './ui/BaseButton.vue';

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
  canViewInventory: false,
  canFiar: false,
  canViewReports: false,
  canOpenCloseCash: false,
});

// Computed properties
const isEdit = computed(() => !!props.employeeId);

const modalTitle = computed(() => 
  isEdit.value ? 'Editar Empleado' : 'Nuevo Empleado'
);

const isValid = computed(() => {
  const { name, username, pin } = formData.value;
  return (
    name.trim().length >= 2 &&
    username.trim().length >= 4 &&
    pin.length === 4
  );
});

const close = () => {
  emit('update:modelValue', false);
  resetForm();
};

const handleUsernameInput = (event: Event) => {
  const input = event.target as HTMLInputElement;
  // Ensure we only store valid characters if need be, but for now just let v-model handle it 
  // or enforce numeric if inputmode is numeric. 
  // Given inputmode="numeric", let's strip non-digits to be clean.
  const val = input.value.replace(/\D/g, '');
  formData.value.username = val;
  
  if (input.value !== val) {
    input.value = val;
  }
};

const handlePinInput = (event: Event) => {
  const input = event.target as HTMLInputElement;
  // Enforce 4 digits numeric
  const val = input.value.replace(/\D/g, '').slice(0, 4);
  formData.value.pin = val;
  
  if (input.value !== val) {
    input.value = val;
  }
};

// Methods
const resetForm = () => {
  formData.value = {
    name: '',
    username: '',
    pin: '',
    canSell: true,
    canViewInventory: false,
    canFiar: false,
    canViewReports: false,
    canOpenCloseCash: false,
  };
};



const save = () => {
  if (!isValid.value) return;

  const data = {
    name: formData.value.name.trim(),
    username: formData.value.username.trim(),
    pin: formData.value.pin,
    permissions: {
      canSell: true, // Always true
      canViewInventory: formData.value.canViewInventory,
      canViewReports: formData.value.canViewReports,
      canFiar: formData.value.canFiar,
      canOpenCloseCash: formData.value.canOpenCloseCash,
    },
    isActive: true, // New employees start active (unless limit reached, store will throw)
  };
  
  try {
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
  } catch (e: any) {
      alert(e.message);
  }
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
          canSell: true, 
          canViewInventory: employee.permissions.canViewInventory,
          canFiar: employee.permissions.canFiar,
          canViewReports: employee.permissions.canViewReports,
          canOpenCloseCash: employee.permissions.canOpenCloseCash,
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
  <BaseModal
    :model-value="modelValue"
    @update:model-value="close"
    :title="modalTitle"
  >
    <div class="px-6 space-y-6">
      <!-- Basic Info -->
      <div class="space-y-4">
        <BaseInput
           v-model="formData.name"
           label="Nombre Completo"
           placeholder="Ej: Juan Pérez"
           icon="person"
        />

        <BaseInput
           v-model="formData.username"
           @input="handleUsernameInput"
           label="Usuario de Acceso"
           placeholder="Número de teléfono o identificación"
           icon="badge"
           type="tel"
           inputmode="numeric"
        />
      </div>

      <!-- Security Section -->
      <div
        class="p-4 rounded-xl bg-blue-50/50 dark:bg-blue-900/10 border border-blue-100 dark:border-blue-800 space-y-3"
      >
        <div class="flex items-center gap-2 text-primary font-medium">
           <span class="material-symbols-outlined text-[20px]">lock</span>
           <span class="text-sm">Seguridad</span>
        </div>
        
        <BaseInput
            :model-value="formData.pin"
            @input="handlePinInput"
            label="Asignar PIN (4 dígitos)"
            placeholder="••••"
            type="tel"
            inputmode="numeric"
            class="text-center text-lg tracking-[0.5em] font-bold"
            maxlength="4"
        />
        <p class="text-xs text-gray-500">El empleado usará este PIN para entrar.</p>
      </div>

      <!-- Permissions -->
      <div class="space-y-3 pb-6">
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
            v-model="formData.canViewInventory"
            class="size-5 rounded border-gray-300 text-primary focus:ring-primary"
            type="checkbox"
          />
          <span class="text-sm font-medium text-gray-900 dark:text-white"
            >Ver Inventario</span
          >
        </label>

        <label
          class="flex items-center gap-3 p-3 rounded-lg border border-gray-100 dark:border-gray-700 bg-white dark:bg-gray-700/30 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors"
        >
          <input
            v-model="formData.canFiar"
            class="size-5 rounded border-gray-300 text-primary focus:ring-primary"
            type="checkbox"
          />
          <span class="text-sm font-medium text-gray-900 dark:text-white"
            >Puede Fiar (Crédito)</span
          >
        </label>

        <label
          class="flex items-center gap-3 p-3 rounded-lg border border-gray-100 dark:border-gray-700 bg-white dark:bg-gray-700/30 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors"
        >
          <input
            v-model="formData.canViewReports"
            class="size-5 rounded border-gray-300 text-primary focus:ring-primary"
            type="checkbox"
          />
          <span class="text-sm font-medium text-gray-900 dark:text-white"
            >Ver Reportes</span
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

    <!-- Actions Footer -->
    <template #footer>
        <div class="p-6 pt-2 flex gap-3 bg-surface-light dark:bg-surface-dark">
            <BaseButton
                @click="close"
                variant="secondary"
                class="flex-1"
            >
                Cancelar
            </BaseButton>
            <BaseButton
                @click="save"
                :disabled="!isValid"
                variant="primary"
                class="flex-1"
            >
                Guardar
            </BaseButton>
        </div>
    </template>
  </BaseModal>
</template>



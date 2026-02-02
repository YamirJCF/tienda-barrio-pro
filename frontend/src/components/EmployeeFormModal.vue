<script setup lang="ts">
import { ref, watch, computed } from 'vue';
import { useEmployeesStore } from '../stores/employees';
import type { Employee, EmployeePermissions } from '../types'; // Correct import
import { useAuthStore } from '../stores/auth'; 
import BaseModal from './ui/BaseModal.vue';
import BaseInput from './ui/BaseInput.vue';
import BaseButton from './ui/BaseButton.vue';
import { User, IdCard, Lock } from 'lucide-vue-next';
import { useNotifications } from '../composables/useNotifications';

// Props
interface Props {
  modelValue: boolean;
  employeeId?: string; // UUID
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  saved: [employee: Employee];
}>();

const employeesStore = useEmployeesStore();
const authStore = useAuthStore(); // Initialize AuthStore

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
  // PIN is only required when creating new employee
  const pinValid = isEdit.value || pin.length === 4;
  return (
    name.trim().length >= 2 &&
    username.trim().length >= 4 &&
    pinValid
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



const { showError, showSuccess } = useNotifications();

const save = async () => {
  if (!isValid.value) return;

  const baseData = {
    name: formData.value.name.trim(),
    username: formData.value.username.trim(),
    pin: formData.value.pin || '', // Empty string means "don't update PIN" when editing
    permissions: {
      canSell: true, // Always true
      canViewInventory: formData.value.canViewInventory,
      canViewReports: formData.value.canViewReports,
      canFiar: formData.value.canFiar,
      canOpenCloseCash: formData.value.canOpenCloseCash,
    },
    isActive: true, 
    storeId: authStore.currentUser?.storeId || authStore.currentStore?.id || '', // Inject storeId from AuthStore (Robust)
  };
  
  try {
      let employee: Employee | null;

      if (isEdit.value && props.employeeId) {
        // PREVENTIVE CHECK: If trying to change PIN in Edit Mode
        if (formData.value.pin && formData.value.pin.length > 0) {
            showError('Por seguridad, el PIN no se puede cambiar aquí. Usa el botón "Cambiar PIN".');
            return;
        }
        employee = await employeesStore.updateEmployee(props.employeeId, baseData);
      } else {
        employee = await employeesStore.addEmployee(baseData);
      }

      if (employee) {
        emit('saved', employee);
        showSuccess(isEdit.value ? 'Empleado actualizado' : 'Empleado creado');
        close();
      }
  } catch (e: any) {
      showError(e.message);
  }
};



// Load existing employee data for editing
watch(
  () => [props.modelValue, props.employeeId],
  ([show, employeeId]) => {
    if (show && employeeId) {
      const employee = employeesStore.getEmployeeById(employeeId as string);
      if (employee) {
        // Defensive: Handle legacy permission schemas
        const perms = (employee.permissions || {}) as Partial<EmployeePermissions>;
        formData.value = {
          name: employee.name,
          username: employee.username,
          pin: employee.pin,
          canSell: true, 
          canViewInventory: perms.canViewInventory ?? false,
          canFiar: perms.canFiar ?? false,
          canViewReports: perms.canViewReports ?? false,
          canOpenCloseCash: perms.canOpenCloseCash ?? false,
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
           :icon="User"
        />

        <BaseInput
           v-model="formData.username"
           @input="handleUsernameInput"
           label="Usuario de Acceso"
           placeholder="Número de teléfono o identificación"
           :icon="IdCard"
           type="tel"
           inputmode="numeric"
        />
      </div>

      <!-- Security Section -->
      <div
        class="p-4 rounded-xl bg-blue-50/50 dark:bg-blue-900/10 border border-blue-100 dark:border-blue-800 space-y-3"
      >
        <div class="flex items-center gap-2 text-primary font-medium">
           <Lock :size="20" />
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



<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useEmployeesStore, type Employee } from '../stores/employees';
import { useAsyncAction } from '../composables/useAsyncAction'; // Request Management
import EmployeeFormModal from '../components/EmployeeFormModal.vue';
import BottomNav from '../components/BottomNav.vue';
import BaseModal from '../components/ui/BaseModal.vue';
import BaseInput from '../components/ui/BaseInput.vue';
import BaseButton from '../components/ui/BaseButton.vue';

const router = useRouter();
const employeesStore = useEmployeesStore();

// State
const showEmployeeModal = ref(false);
const editingEmployeeId = ref<number | undefined>(undefined);
const showPinModal = ref(false);
const selectedEmployee = ref<Employee | null>(null);
const newPin = ref('');

// Methods
const goBack = () => {
  router.push('/admin');
};

const getInitials = (name: string) => {
  const parts = name.split(' ');
  if (parts.length >= 2) {
    return parts[0][0] + parts[1][0];
  }
  return name.substring(0, 2).toUpperCase();
};

const getAvatarColor = (name: string) => {
  const colors = [
    'bg-blue-100 text-blue-600 dark:bg-blue-900/30 dark:text-blue-400',
    'bg-purple-100 text-purple-600 dark:bg-purple-900/30 dark:text-purple-400',
    'bg-emerald-100 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-400',
    'bg-orange-100 text-orange-600 dark:bg-orange-900/30 dark:text-orange-400',
    'bg-pink-100 text-pink-600 dark:bg-pink-900/30 dark:text-pink-400',
    'bg-cyan-100 text-cyan-600 dark:bg-cyan-900/30 dark:text-cyan-400',
  ];
  const index = name.charCodeAt(0) % colors.length;
  return colors[index];
};

const openNewEmployee = () => {
  if (employeesStore.activeEmployees.length >= 5) {
      alert("Límite de empleados activos alcanzado. Desactiva uno existente para crear nuevo.");
      return;
  }
  editingEmployeeId.value = undefined;
  showEmployeeModal.value = true;
};

const editEmployee = (employee: Employee) => {
  editingEmployeeId.value = employee.id;
  showEmployeeModal.value = true;
};

const { execute: executeToggle } = useAsyncAction();
const { execute: executePin } = useAsyncAction();

const toggleActive = async (employee: Employee) => {
  await executeToggle(async () => {
    employeesStore.toggleActive(employee.id);
  }, {
    errorMessage: 'No se pudo cambiar el estado del empleado',
    // Optimistic toggle usually doesn't need success toast spam
    showSuccessToast: false
  });
};

const openPinModal = (employee: Employee) => {
  selectedEmployee.value = employee;
  newPin.value = '';
  showPinModal.value = true;
};


const handlePinInput = (value: string | number) => {
  newPin.value = String(value).replace(/\D/g, '').slice(0, 4);
};

const savePin = async () => {
  if (selectedEmployee.value && newPin.value.length === 4) {
    await executePin(async () => {
        employeesStore.updatePin(selectedEmployee.value!.id, newPin.value);
        showPinModal.value = false;
        selectedEmployee.value = null;
        newPin.value = '';
    }, {
        successMessage: 'PIN actualizado correctamente',
        errorMessage: 'Error al actualizar el PIN'
    });
  }
};

const handleEmployeeSaved = () => {
  showEmployeeModal.value = false;
};

// WO: initializeSampleData eliminada - SPEC-007
</script>

<template>
  <div class="flex flex-col h-screen bg-background-light dark:bg-background-dark pb-24">
    <!-- Header -->
    <header
      class="flex items-center justify-between px-4 py-4 bg-white dark:bg-slate-800 border-b border-gray-100 dark:border-gray-700 shrink-0"
    >
      <button
        @click="goBack"
        aria-label="Volver"
        class="flex size-10 items-center justify-center rounded-full active:bg-gray-100 dark:active:bg-gray-700 transition-colors"
      >
        <span class="material-symbols-outlined text-gray-900 dark:text-white text-2xl"
          >arrow_back</span
        >
      </button>
      <h1 class="flex-1 text-center text-lg font-bold tracking-tight text-gray-900 dark:text-white">
        Administrar Empleados
      </h1>
      <div class="size-10"></div>
    </header>

    <!-- Main Content Area -->
    <main class="flex-1 overflow-y-auto px-4 pt-4">
      <!-- Empty State -->
      <div
        v-if="employeesStore.employees.length === 0"
        class="flex flex-col items-center justify-center h-full text-center"
      >
        <div
          class="flex h-16 w-16 items-center justify-center rounded-full bg-gray-100 dark:bg-gray-800 text-gray-400 mb-4"
        >
          <span class="material-symbols-outlined text-[32px]">group</span>
        </div>
        <h3 class="text-lg font-bold text-gray-900 dark:text-white mb-2">Sin empleados</h3>
        <p class="text-sm text-gray-500 max-w-xs">
          Agrega empleados para que puedan acceder al sistema
        </p>
        <BaseButton
          @click="openNewEmployee"
          class="mt-6"
          icon="person_add"
          :disabled="employeesStore.activeEmployees.length >= 5"
        >
          {{ employeesStore.activeEmployees.length >= 5 ? 'Límite Alcanzado (5/5)' : 'Agregar Empleado' }}
        </BaseButton>
      </div>

      <!-- Employee List -->
      <div v-else class="flex flex-col gap-3">
        <div
          v-for="employee in employeesStore.employees"
          :key="employee.id"
          class="group flex items-center justify-between p-4 bg-white dark:bg-slate-800 rounded-lg shadow-sm border border-transparent hover:border-gray-100 dark:hover:border-gray-700 transition-all"
          :class="{ 'opacity-60': !employee.isActive }"
          @click="editEmployee(employee)"
        >
          <div class="flex items-center gap-4 flex-1 min-w-0">
            <div class="relative shrink-0">
              <!-- Initials Avatar -->
              <div
                class="flex size-12 items-center justify-center rounded-full font-bold text-lg"
                :class="[getAvatarColor(employee.name), { grayscale: !employee.isActive }]"
              >
                {{ getInitials(employee.name) }}
              </div>
              <!-- Active indicator -->
              <div
                v-if="employee.isActive"
                class="absolute bottom-0 right-0 size-3 rounded-full bg-green-500 border-2 border-white dark:border-slate-800"
              ></div>
            </div>
            <div class="flex flex-col justify-center min-w-0">
              <p
                class="text-base font-semibold truncate"
                :class="
                  employee.isActive
                    ? 'text-gray-900 dark:text-white'
                    : 'text-gray-500 dark:text-gray-400'
                "
              >
                {{ employee.name }}
              </p>
              <p class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">Empleado</p>
            </div>
          </div>
          <div class="flex items-center gap-3 shrink-0 ml-2">
            <!-- Edit PIN Button -->
            <button
              @click.stop="openPinModal(employee)"
              aria-label="Editar PIN"
              class="flex size-10 items-center justify-center rounded-full bg-gray-50 dark:bg-gray-700 text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-600 transition-colors"
            >
              <span class="material-symbols-outlined text-[20px]">key</span>
            </button>
            <!-- Toggle Switch -->
            <label class="relative inline-flex items-center cursor-pointer" @click.stop>
              <input
                :checked="employee.isActive"
                @change="toggleActive(employee)"
                class="sr-only peer"
                type="checkbox"
              />
              <div
                class="w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer dark:bg-gray-600 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"
              ></div>
            </label>
          </div>
        </div>
      </div>

      <div class="h-20"></div>
    </main>

    <!-- FAB -->
    <div class="absolute bottom-24 right-4 z-40">
      <BaseButton
        @click="openNewEmployee"
        label="Nuevo Empleado"
        variant="primary"
        class="size-14 !rounded-2xl shadow-lg"
        :icon="employeesStore.activeEmployees.length >= 5 ? 'block' : 'add'"
        :disabled="employeesStore.activeEmployees.length >= 5"
        :title="employeesStore.activeEmployees.length >= 5 ? 'Límite de 5 empleados alcanzado' : 'Crear nuevo empleado'"
      >
      </BaseButton>
    </div>

    <BottomNav />

    <!-- Employee Form Modal -->
    <EmployeeFormModal
      v-model="showEmployeeModal"
      :employee-id="editingEmployeeId"
      @saved="handleEmployeeSaved"
    />

    <!-- PIN Edit Modal -->
    <BaseModal
      v-model="showPinModal"
      title="Cambiar PIN"
    >
        <div class="p-6">
            <div class="flex items-center gap-3 mb-6">
                <div class="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                    <span class="material-symbols-outlined text-primary">key</span>
                </div>
                <div>
                   <p class="text-sm text-gray-500">Para el empleado:</p>
                   <h3 class="text-lg font-bold text-gray-900 dark:text-white">{{ selectedEmployee?.name }}</h3>
                </div>
            </div>

            <BaseInput
                :model-value="newPin"
                @update:model-value="handlePinInput"
                label="Nuevo PIN (4 dígitos)"
                placeholder="••••"
                type="tel"
                inputmode="numeric"
                icon="lock"
                class="text-center text-2xl tracking-[0.5em] font-bold h-14"
                maxlength="4"
            />
        </div>

        <template #footer>
            <div class="p-6 pt-0 flex gap-3">
                 <BaseButton
                    @click="showPinModal = false"
                    variant="secondary"
                    class="flex-1"
                >
                    Cancelar
                </BaseButton>
                <BaseButton
                    @click="savePin"
                    :disabled="newPin.length !== 4"
                    variant="primary"
                    class="flex-1"
                >
                    Guardar
                </BaseButton>
            </div>
        </template>
    </BaseModal>
  </div>
</template>

<style scoped>
.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.2s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.animate-scale-in {
  animation: scaleIn 0.2s ease-out;
}

@keyframes scaleIn {
  from {
    transform: scale(0.95);
    opacity: 0;
  }

  to {
    transform: scale(1);
    opacity: 1;
  }
}
</style>

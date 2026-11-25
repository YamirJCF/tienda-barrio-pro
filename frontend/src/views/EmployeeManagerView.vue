<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useEmployeesStore } from '../stores/employees';
import { Employee } from '../types';
import { useAuthStore } from '../stores/auth';
import { useAsyncAction } from '../composables/useAsyncAction'; // Request Management
import EmployeeFormModal from '../components/EmployeeFormModal.vue';
import BottomNav from '../components/BottomNav.vue';
import BaseModal from '../components/ui/BaseModal.vue';
import BaseInput from '../components/ui/BaseInput.vue';
import BaseButton from '../components/ui/BaseButton.vue';
import BaseListSkeleton from '../components/ui/BaseListSkeleton.vue';
import { 
  ArrowLeft, 
  Users, 
  UserPlus, 
  KeyRound, 
  Lock, 
  Ban,
  AlertTriangle,
  Plus,
  RefreshCw
} from 'lucide-vue-next';

import { useNotifications } from '../composables/useNotifications';

const router = useRouter();
const authStore = useAuthStore();
const employeesStore = useEmployeesStore();
const { showWarning } = useNotifications();

const loadEmployees = async () => {
  const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
  if (storeId) {
    await employeesStore.initialize(storeId);
  }
};

// Initialize store on mount
onMounted(loadEmployees);

// State
const showEmployeeModal = ref(false);
const editingEmployeeId = ref<string | undefined>(undefined);
const showPinModal = ref(false);
const selectedEmployee = ref<Employee | null>(null);
const newPin = ref('');
const newlyCreatedId = ref<string | null>(null);
const statusFilter = ref<'all' | 'active' | 'inactive'>('all');
const searchQuery = ref('');

// Tope de 5 empleados activos excluye explícitamente perfiles técnicos owner_ (SDD-003 §0.3 D-4)
const operationalEmployees = computed(() => {
  return employeesStore.employees.filter(e => !e.username.startsWith('owner_'));
});

const activeOperationalCount = computed(() => employeesStore.activeOperationalEmployees.length);
const isAtEmployeeLimit = computed(() => activeOperationalCount.value >= 5);

const visibleEmployees = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  return operationalEmployees.value.filter(e => {
    if (statusFilter.value === 'active' && !e.isActive) return false;
    if (statusFilter.value === 'inactive' && e.isActive) return false;
    if (q) {
      return e.name.toLowerCase().includes(q) || e.username.toLowerCase().includes(q);
    }
    return true;
  });
});

const hasOperationalEmployees = computed(() => operationalEmployees.value.length > 0);
const hasVisibleEmployees = computed(() => visibleEmployees.value.length > 0);

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
  if (isAtEmployeeLimit.value) {
      showWarning("Límite de empleados activos alcanzado (5/5). Desactiva uno existente para crear nuevo.");
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

const showDeactivateModal = ref(false);
const employeeToDeactivate = ref<Employee | null>(null);

const confirmDeactivate = async () => {
    if (!employeeToDeactivate.value) return;
    
    await executeToggle(async () => {
        // Find current ID
        const id = employeeToDeactivate.value!.id;
        await employeesStore.toggleActive(id);
        
        showDeactivateModal.value = false;
        employeeToDeactivate.value = null;
    }, {
         errorMessage: 'Error al desactivar empleado',
         successMessage: 'Empleado desactivado correctamente'
    });
};

const toggleActive = async (employee: Employee) => {
  // PE-05: Confirmation on deactivate
  if (employee.isActive) {
      employeeToDeactivate.value = employee;
      showDeactivateModal.value = true;
      return;
  }

  // Activating is instant
  await executeToggle(async () => {
    await employeesStore.toggleActive(employee.id);
  }, {
    errorMessage: 'No se pudo activar el empleado',
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
        await employeesStore.updatePin(selectedEmployee.value!.id, newPin.value);
        showPinModal.value = false;
        selectedEmployee.value = null;
        newPin.value = '';
    }, {
        successMessage: 'PIN actualizado correctamente',
        errorMessage: 'Error al actualizar el PIN'
    });
  }
};

const handleEmployeeSaved = (employee: Employee, action: 'create' | 'update') => {
  showEmployeeModal.value = false;
  if (action === 'create') {
    newlyCreatedId.value = employee.id;
    setTimeout(() => {
      if (newlyCreatedId.value === employee.id) {
        newlyCreatedId.value = null;
      }
    }, 3000);
  }
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
        class="flex size-10 items-center justify-center rounded-xl active:bg-gray-100 dark:active:bg-gray-700 transition-colors"
      >
        <ArrowLeft :size="24" :stroke-width="1.5" class="text-gray-900 dark:text-white" />
      </button>
      <h1 class="flex-1 text-center text-lg font-bold tracking-tight text-gray-900 dark:text-white">
        Administrar Empleados
      </h1>
      <div class="size-10"></div>
    </header>

    <!-- Main Content Area -->
    <main class="flex-1 overflow-y-auto px-4 pt-4">
      <!-- Aviso N1 persistente de límite de personal 5/5 -->
      <div
        v-if="isAtEmployeeLimit"
        role="status"
        data-testid="employees-limit-banner"
        class="mb-4 rounded-xl border border-amber-200 dark:border-amber-800 bg-amber-50 dark:bg-amber-900/20 px-3.5 py-2.5 flex items-center gap-2.5 text-xs font-medium text-amber-800 dark:text-amber-300"
      >
        <AlertTriangle :size="16" class="shrink-0" />
        <span>Límite de 5 empleados operativos activos alcanzado (5/5). Desactiva uno existente para crear o reactivar otro.</span>
      </div>

      <!-- Barra de búsqueda, filtros Activos/Inactivos y cupo 5/5 (sin contar owner_) -->
      <div v-if="hasOperationalEmployees" class="mb-4 space-y-2.5">
        <div class="flex items-center justify-between gap-2">
          <input
            v-model="searchQuery"
            type="search"
            aria-label="Buscar empleado por nombre o alias"
            placeholder="Buscar por nombre o alias..."
            class="flex-1 h-10 px-3 rounded-xl bg-white dark:bg-slate-800 border border-gray-200 dark:border-gray-700 text-sm text-gray-900 dark:text-white placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-primary/40"
          />
          <span
            class="shrink-0 text-xs font-semibold px-2.5 py-1.5 rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 font-mono tabular-nums"
            data-testid="active-employees-count"
          >
            {{ activeOperationalCount }}/5 activos
          </span>
        </div>
        <div class="flex gap-2" role="group" aria-label="Filtrar estado de empleados">
          <button
            type="button"
            @click="statusFilter = 'all'"
            class="px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors"
            :class="statusFilter === 'all' ? 'bg-primary text-white' : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border border-gray-200 dark:border-gray-700'"
          >
            Todos
          </button>
          <button
            type="button"
            @click="statusFilter = 'active'"
            class="px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors"
            :class="statusFilter === 'active' ? 'bg-primary text-white' : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border border-gray-200 dark:border-gray-700'"
          >
            Activos
          </button>
          <button
            type="button"
            @click="statusFilter = 'inactive'"
            class="px-3 py-1.5 rounded-lg text-xs font-semibold transition-colors"
            :class="statusFilter === 'inactive' ? 'bg-primary text-white' : 'bg-white dark:bg-slate-800 text-slate-600 dark:text-slate-300 border border-gray-200 dark:border-gray-700'"
          >
            Inactivos
          </button>
        </div>
      </div>

      <!-- Loading Skeleton -->
      <BaseListSkeleton
        v-if="employeesStore.loading"
        :count="4"
        type="card"
        data-testid="employees-loading-skeleton"
      />

      <!-- Error Banner N3 (Fail-Closed antes del Empty State) -->
      <div
        v-else-if="employeesStore.error"
        role="alert"
        data-testid="employees-error-banner"
        class="rounded-2xl border border-rose-200 dark:border-rose-800 bg-rose-50 dark:bg-rose-950/20 p-5 text-center space-y-3 my-6"
      >
        <AlertTriangle :size="32" class="mx-auto text-rose-500" />
        <p class="text-sm font-semibold text-rose-700 dark:text-rose-300">
          {{ employeesStore.error }}
        </p>
        <BaseButton
          data-testid="employees-retry-btn"
          variant="outline"
          size="sm"
          @click="loadEmployees"
        >
          <RefreshCw :size="14" class="mr-1.5" />
          Reintentar
        </BaseButton>
      </div>

      <!-- Empty State -->
      <div
        v-else-if="!hasOperationalEmployees"
        class="flex flex-col items-center justify-center h-full text-center"
      >
        <div
          class="flex h-16 w-16 items-center justify-center rounded-2xl bg-gray-100 dark:bg-gray-800 text-gray-400 mb-4"
        >
          <Users :size="32" :stroke-width="1" />
        </div>
        <h3 class="text-lg font-bold text-gray-900 dark:text-white mb-2">Sin empleados</h3>
        <p class="text-sm text-gray-500 max-w-xs">
          Agrega empleados para que puedan acceder al sistema
        </p>
        <BaseButton
          @click="openNewEmployee"
          class="mt-6"
          :disabled="isAtEmployeeLimit"
        >
          <UserPlus :size="18" class="mr-2" />
          {{ isAtEmployeeLimit ? 'Límite Alcanzado (5/5)' : 'Agregar Empleado' }}
        </BaseButton>
      </div>

      <div
        v-else-if="!hasVisibleEmployees"
        class="flex flex-col items-center justify-center py-12 text-center"
      >
        <p class="text-sm font-medium text-gray-500 dark:text-gray-400">
          No hay empleados que coincidan con el filtro aplicado.
        </p>
      </div>

      <!-- Employee List -->
      <div v-else class="flex flex-col gap-3">
        <div
          v-for="employee in visibleEmployees"
          :key="employee.id"
          class="group flex items-center justify-between p-4 bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-transparent hover:border-gray-100 dark:hover:border-gray-700 transition-all"
          :class="[
            !employee.isActive ? 'opacity-60' : '',
            employee.id === newlyCreatedId ? 'highlight-new' : ''
          ]"
          @click="editEmployee(employee)"
        >
          <div class="flex items-center gap-4 flex-1 min-w-0">
            <div class="relative shrink-0">
              <!-- Initials Avatar -->
              <div
                class="flex size-12 items-center justify-center rounded-[18px] font-bold text-lg"
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
              <p class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">@{{ employee.username }}</p>
            </div>
          </div>
          <div class="flex items-center gap-3 shrink-0 ml-2">
            <!-- Edit PIN Button -->
            <button
              @click.stop="openPinModal(employee)"
              aria-label="Editar PIN"
              class="flex size-10 items-center justify-center rounded-xl bg-gray-50 dark:bg-gray-700 text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-600 transition-colors"
            >
              <KeyRound :size="20" :stroke-width="1.5" />
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
      <button
        @click="openNewEmployee"
        :disabled="isAtEmployeeLimit"
        class="flex h-14 w-14 items-center justify-center rounded-2xl bg-primary text-white shadow-lg hover:bg-blue-600 transition-all active:scale-90 disabled:opacity-50 disabled:bg-gray-400 disabled:cursor-not-allowed"
        :title="isAtEmployeeLimit ? 'Límite de 5 empleados alcanzado' : 'Crear nuevo empleado'"
      >
         <component :is="isAtEmployeeLimit ? Ban : Plus" :size="32" :stroke-width="1.5" />
      </button>
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
                    <KeyRound :size="20" class="text-primary" />
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
                class="text-center text-2xl tracking-[0.5em] font-bold h-14"
                maxlength="4"
            >
                <template #prefix>
                    <Lock :size="20" class="text-gray-400" />
                </template>
            </BaseInput>
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

    <!-- Deactivate Confirmation Modal -->
     <BaseModal
      v-model="showDeactivateModal"
      title="Confirmar Desactivación"
    >
        <div class="p-6">
             <div class="flex items-center gap-3 mb-4 p-3 bg-red-50 dark:bg-red-900/30 rounded-lg border border-red-100 dark:border-red-900/50">
                <AlertTriangle :size="24" class="text-red-600 dark:text-red-400" />
                <p class="text-sm text-red-700 dark:text-red-300 font-medium">
                    Esta acción quitará el acceso al sistema inmediatamente.
                </p>
             </div>
             <p class="text-gray-600 dark:text-gray-300">
                ¿Estás seguro de desactivar a <strong>{{ employeeToDeactivate?.name }}</strong>?
             </p>
        </div>
        <template #footer>
            <div class="p-6 pt-0 flex gap-3">
                 <BaseButton
                    @click="showDeactivateModal = false"
                    variant="secondary"
                    class="flex-1"
                >
                    Cancelar
                </BaseButton>
                <BaseButton
                    @click="confirmDeactivate"
                    variant="danger"
                    class="flex-1"
                >
                    Desactivar Usuario
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

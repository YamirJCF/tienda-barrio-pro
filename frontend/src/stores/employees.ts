import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Employee, EmployeePermissions } from '../types';
import { employeeRepository } from '../data/repositories/employeeRepository';
import { logger } from '../utils/logger';

export const useEmployeesStore = defineStore(
  'employees',
  () => {
    const employees = ref<Employee[]>([]);
    const loading = ref(false);
    const error = ref<string | null>(null);

    // Computed
    const activeEmployees = computed(() => {
      return employees.value.filter((e) => e.isActive);
    });

    // Computed: Active OPERATIONAL employees (excluding owner/admin)
    // Aligns with backend RPC logic: owner_* accounts don't count against the 5-employee limit
    const activeOperationalEmployees = computed(() => {
      return employees.value.filter((e) => e.isActive && !e.username.startsWith('owner_'));
    });

    // Methods

    /**
     * Initialize Store: Fetch from Repository
     */
    const initialize = async (storeId: string) => {
      if (!storeId) return;

      // AUTO-FIX: Clean corrupted localStorage data before loading
      try {
        const storedData = localStorage.getItem('tienda-employees');
        if (storedData) {
          const parsed = JSON.parse(storedData);
          if (!Array.isArray(parsed)) {
            logger.warn('[EmployeeStore] Detected corrupted localStorage data, cleaning...');
            localStorage.removeItem('tienda-employees');
          }
        }
      } catch (e) {
        logger.warn('[EmployeeStore] Error checking localStorage, cleaning...', e);
        localStorage.removeItem('tienda-employees');
      }

      loading.value = true;
      try {
        const data = await employeeRepository.getAll(storeId);
        employees.value = data;
      } catch (e: any) {
        logger.error('[EmployeeStore] Init failed', e);
        error.value = 'Error al cargar empleados';
      } finally {
        loading.value = false;
      }
    };

    /**
     * Create Employee (Async + RPC)
     */
    const addEmployee = async (data: Omit<Employee, 'id' | 'createdAt' | 'updatedAt'>): Promise<Employee> => {
      // VALIDATION: storeId required
      if (!data.storeId || data.storeId.trim() === '') {
        throw new Error('No se puede crear empleado sin storeId. Sesión inválida.');
      }

      // Connectivity Validation (UX Rule)
      if (!navigator.onLine) {
        throw new Error('Se requiere conexión a internet para crear empleados de forma segura.');
      }

      // Business Rule: Max 5 active OPERATIONAL employees (excluding owner/admin)
      if (activeOperationalEmployees.value.length >= 5 && data.isActive) {
        throw new Error('Límite de empleados activos alcanzado (Máx 5). Desactiva uno existente primero.');
      }

      // Business Rule: Unique Username (Local Check first for speed)
      const exists = employees.value.find(e => e.username.toLowerCase() === data.username.toLowerCase());
      if (exists) {
        throw new Error('El nombre de usuario ya está registrado.');
      }

      try {
        loading.value = true;
        // Call Repository (RPC)
        const newEmployee = await employeeRepository.create(data);

        if (newEmployee) {
          // Add to local state
          employees.value.push(newEmployee);
          return newEmployee;
        } else {
          throw new Error('Error desconocido al crear empleado');
        }
      } catch (e: any) {
        logger.error('[EmployeeStore] addEmployee failed', e);
        throw e;
      } finally {
        loading.value = false;
      }
    };

    const updateEmployee = async (id: string, data: Partial<Omit<Employee, 'id' | 'createdAt'>>) => {
      const index = employees.value.findIndex((e) => e.id === id);
      if (index === -1) return null;

      // Local Validation
      if (data.username) {
        const exists = employees.value.find(e =>
          e.username.toLowerCase() === data.username!.toLowerCase() &&
          e.id !== id
        );
        if (exists) throw new Error('El nombre de usuario ya está registrado.');
      }

      if (data.isActive === true && !employees.value[index].isActive) {
        if (activeEmployees.value.length >= 5) {
          throw new Error('Límite de empleados activos alcanzado (Máx 5).');
        }
      }

      try {
        // Repo Update
        const updated = await employeeRepository.update(id, data as any); // Type cast due to strict Partial
        if (updated) {
          // Update local
          employees.value[index] = updated;
          return updated;
        }
      } catch (e) {
        logger.error('[EmployeeStore] Update failed', e);
        throw e;
      }
      return null;
    };

    const deleteEmployee = async (id: string) => {
      try {
        await employeeRepository.delete(id);
        const index = employees.value.findIndex((e) => e.id === id);
        if (index !== -1) {
          employees.value.splice(index, 1);
        }
      } catch (e) {
        logger.error('[EmployeeStore] Delete failed', e);
        throw e; // Propagate or handle?
      }
    };

    const toggleActive = async (id: string) => {
      const employee = employees.value.find((e) => e.id === id);
      if (employee) {
        // Security Rule: Online Only
        if (!navigator.onLine) {
          throw new Error('Cambiar estado requiere conexión a internet.');
        }

        const newState = !employee.isActive;

        try {
          // Use RPC
          const result = await employeeRepository.toggleActiveSecure(id, newState);

          if (!result.success) {
            // Handle "Limit Reached" specifically if needed, but error message works
            throw new Error(result.error || 'Error al cambiar estado');
          }

          // Update Local State on success
          employee.isActive = newState;
          return true;

        } catch (e: any) {
          logger.error('[EmployeeStore] Toggle Active failed', e);
          throw e;
        }
      }
      return false;
    };

    const updatePin = async (id: string, newPin: string) => {
      // Security: Require Online
      if (!navigator.onLine) {
        throw new Error('Cambio de PIN requiere internet (Seguridad).');
      }

      try {
        const result = await employeeRepository.updatePin(id, newPin);
        if (!result.success) {
          throw new Error(result.error || 'Error al actualizar PIN');
        }
        return true;
      } catch (e: any) {
        logger.error('[EmployeeStore] Update PIN failed', e);
        throw e;
      }
    };

    const getEmployeeById = (id: string) => {
      return employees.value.find((e) => e.id === id);
    };

    const getEmployeeByUsername = (username: string) => {
      return employees.value.find((e) => e.username.toLowerCase() === username.toLowerCase());
    };

    /**
     * Validate PIN (Async + RPC)
     */
    const validatePin = async (username: string, pin: string) => {
      try {
        // Use Repo RPC
        const validEmployee = await employeeRepository.validatePin(username, pin);
        return validEmployee;
      } catch (e) {
        console.error('PIN Validation failed', e);
        return null;
      }
    };

    return {
      employees,
      activeEmployees,
      activeOperationalEmployees,
      loading,
      error,
      initialize,
      addEmployee,
      updateEmployee,
      deleteEmployee,
      toggleActive,
      updatePin,
      getEmployeeById,
      getEmployeeByUsername,
      validatePin,
    };
  },
  {
    persist: {
      key: 'tienda-employees',
      // We still keep persist to save the "Last Known State" (offline cache)
      // The Repo also saves to LS, so this might be redundant or conflicting?
      // Pinia Persist saves the whole state. Repo saves raw rows.
      // It's benign to keep it for now as "View Model Cache".
    },
  },
);


import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { generateUUID } from '../utils/uuid';

export interface EmployeePermissions {
  canSell: boolean;
  canViewInventory: boolean;
  canViewReports: boolean;
  canFiar: boolean;
  canOpenCloseCash: boolean;
  canManageClients?: boolean;
}

// Fase 1 Blindaje: UUID + storeId requerido
export interface Employee {
  id: string; // UUID (was number)
  storeId: string; // REQUIRED - RLS compliance
  name: string;
  username: string;
  pin: string;
  permissions: EmployeePermissions;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export const useEmployeesStore = defineStore(
  'employees',
  () => {
    const employees = ref<Employee[]>([]);

    // Computed
    const activeEmployees = computed(() => {
      return employees.value.filter((e) => e.isActive);
    });

    // Methods
    // Fase 1: Now requires storeId
    const addEmployee = (data: Omit<Employee, 'id' | 'createdAt' | 'updatedAt'>) => {
      // VALIDATION: storeId required
      if (!data.storeId || data.storeId.trim() === '') {
        throw new Error('No se puede crear empleado sin storeId. Sesión inválida.');
      }

      // Business Rule: Max 5 active employees
      if (activeEmployees.value.length >= 5 && data.isActive) {
        throw new Error('Límite de empleados activos alcanzado (Máx 5). Desactiva uno existente primero.');
      }

      // Business Rule: Unique Username
      const exists = employees.value.find(e => e.username.toLowerCase() === data.username.toLowerCase());
      if (exists) {
        throw new Error('El nombre de usuario ya está registrado.');
      }

      const now = new Date().toISOString();
      const employee: Employee = {
        id: generateUUID(), // UUID instead of number
        ...data,
        createdAt: now,
        updatedAt: now,
      };
      employees.value.push(employee);
      return employee;
    };

    // Fase 1: id is now string
    const updateEmployee = (id: string, data: Partial<Omit<Employee, 'id' | 'createdAt'>>) => {
      const index = employees.value.findIndex((e) => e.id === id);
      if (index !== -1) {
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

        employees.value[index] = {
          ...employees.value[index],
          ...data,
          updatedAt: new Date().toISOString(),
        };
        return employees.value[index];
      }
      return null;
    };

    const deleteEmployee = (id: string) => {
      const index = employees.value.findIndex((e) => e.id === id);
      if (index !== -1) {
        employees.value.splice(index, 1);
      }
    };

    const toggleActive = (id: string) => {
      const employee = employees.value.find((e) => e.id === id);
      if (employee) {
        if (!employee.isActive && activeEmployees.value.length >= 5) {
          throw new Error('Límite de empleados activos alcanzado. No se puede activar.');
        }
        employee.isActive = !employee.isActive;
        employee.updatedAt = new Date().toISOString();
        return true;
      }
      return false;
    };

    const updatePin = (id: string, newPin: string) => {
      const employee = employees.value.find((e) => e.id === id);
      if (employee && newPin.length === 4) {
        employee.pin = newPin;
        employee.updatedAt = new Date().toISOString();
        return true;
      }
      return false;
    };

    const getEmployeeById = (id: string) => {
      return employees.value.find((e) => e.id === id);
    };

    const getEmployeeByUsername = (username: string) => {
      return employees.value.find((e) => e.username.toLowerCase() === username.toLowerCase());
    };

    const validatePin = (username: string, pin: string) => {
      const employee = getEmployeeByUsername(username);
      if (employee && employee.isActive && employee.pin === pin) {
        return employee;
      }
      return null;
    };

    return {
      employees,
      activeEmployees,
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
    },
  },
);

import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

export interface EmployeePermissions {
    canSell: boolean;
    canViewInventory: boolean;
    canViewReports: boolean;
    canFiar: boolean;
    canOpenCloseCash: boolean;  // SPEC-006
    canManageInventory?: boolean; // New granular permission
    canManageClients?: boolean;   // New granular permission
}

export interface Employee {
    id: number;
    name: string;
    username: string;
    pin: string; // 4-digit PIN
    permissions: EmployeePermissions;
    isActive: boolean;
    createdAt: string;
    updatedAt: string;
}

export const useEmployeesStore = defineStore('employees', () => {
    const employees = ref<Employee[]>([]);
    const nextId = ref(1);

    // Computed
    const activeEmployees = computed(() => {
        return employees.value.filter(e => e.isActive);
    });

    // Methods
    const addEmployee = (data: Omit<Employee, 'id' | 'createdAt' | 'updatedAt'>) => {
        const now = new Date().toISOString();
        const employee: Employee = {
            id: nextId.value++,
            ...data,
            createdAt: now,
            updatedAt: now,
        };
        employees.value.push(employee);
        return employee;
    };

    const updateEmployee = (id: number, data: Partial<Omit<Employee, 'id' | 'createdAt'>>) => {
        const index = employees.value.findIndex(e => e.id === id);
        if (index !== -1) {
            employees.value[index] = {
                ...employees.value[index],
                ...data,
                updatedAt: new Date().toISOString(),
            };
            return employees.value[index];
        }
        return null;
    };

    const deleteEmployee = (id: number) => {
        const index = employees.value.findIndex(e => e.id === id);
        if (index !== -1) {
            employees.value.splice(index, 1);
        }
    };

    const toggleActive = (id: number) => {
        const employee = employees.value.find(e => e.id === id);
        if (employee) {
            employee.isActive = !employee.isActive;
            employee.updatedAt = new Date().toISOString();
        }
    };

    const updatePin = (id: number, newPin: string) => {
        const employee = employees.value.find(e => e.id === id);
        if (employee && newPin.length === 4) {
            employee.pin = newPin;
            employee.updatedAt = new Date().toISOString();
            return true;
        }
        return false;
    };

    const getEmployeeById = (id: number) => {
        return employees.value.find(e => e.id === id);
    };

    const getEmployeeByUsername = (username: string) => {
        return employees.value.find(e => e.username.toLowerCase() === username.toLowerCase());
    };

    const validatePin = (username: string, pin: string) => {
        const employee = getEmployeeByUsername(username);
        if (employee && employee.isActive && employee.pin === pin) {
            return employee;
        }
        return null;
    };

    // WO-002: initializeSampleData ELIMINADA - SPEC-007

    return {
        employees,
        nextId,
        activeEmployees,
        addEmployee,
        updateEmployee,
        deleteEmployee,
        toggleActive,
        updatePin,
        getEmployeeById,
        getEmployeeByUsername,
        validatePin,
        // initializeSampleData ELIMINADA
    };
}, {
    persist: {
        key: 'tienda-employees',
    },
});

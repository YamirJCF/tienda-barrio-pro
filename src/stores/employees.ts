import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

export interface EmployeePermissions {
    canSell: boolean;
    canViewReports: boolean;
    canFiar: boolean;
}

export interface Employee {
    id: number;
    name: string;
    username: string;
    pin: string; // 4-digit PIN
    role: string;
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

    // Initialize with sample data
    const initializeSampleData = () => {
        if (employees.value.length > 0) return;

        const sampleEmployees = [
            {
                name: 'Carlos Pérez',
                username: 'carlos01',
                pin: '1234',
                role: 'Vendedor',
                permissions: { canSell: true, canViewReports: false, canFiar: false },
                isActive: true,
            },
            {
                name: 'María Rodriguez',
                username: 'maria02',
                pin: '5678',
                role: 'Cajera',
                permissions: { canSell: true, canViewReports: true, canFiar: true },
                isActive: false,
            },
            {
                name: 'Juan Gómez',
                username: 'juan03',
                pin: '9012',
                role: 'Repartidor',
                permissions: { canSell: true, canViewReports: false, canFiar: false },
                isActive: true,
            },
        ];

        sampleEmployees.forEach(e => {
            const now = new Date().toISOString();
            employees.value.push({
                id: nextId.value++,
                ...e,
                createdAt: now,
                updatedAt: now,
            });
        });
    };

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
        initializeSampleData,
    };
}, {
    persist: {
        key: 'tienda-employees',
    },
});

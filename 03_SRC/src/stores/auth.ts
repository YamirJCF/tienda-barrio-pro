import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

export type UserType = 'admin' | 'employee';

export interface StoreAccount {
    id: string;
    storeName: string;
    ownerName: string;
    email: string;
    password: string;
    pin: string;
    createdAt: string;
}

export interface CurrentUser {
    id: string;
    name: string;
    email: string;
    type: UserType;
    storeId: string;
    // For employees
    employeeId?: number;
    permissions?: {
        canSell: boolean;
        canViewInventory: boolean;
        canViewReports: boolean;
        canFiar: boolean;
    };
}

export const useAuthStore = defineStore('auth', () => {
    // State
    const stores = ref<StoreAccount[]>([]);
    const currentUser = ref<CurrentUser | null>(null);
    const isAuthenticated = ref(false);

    // Computed
    const isAdmin = computed(() => currentUser.value?.type === 'admin');
    const isEmployee = computed(() => currentUser.value?.type === 'employee');
    const currentStore = computed(() => {
        if (!currentUser.value) return null;
        return stores.value.find(s => s.id === currentUser.value!.storeId);
    });

    // Permission helpers - admins have all permissions, employees check their assigned permissions
    const canSell = computed(() => {
        if (!currentUser.value) return false;
        if (isAdmin.value) return true;
        return currentUser.value.permissions?.canSell ?? false;
    });

    const canViewInventory = computed(() => {
        if (!currentUser.value) return false;
        if (isAdmin.value) return true;
        return currentUser.value.permissions?.canViewInventory ?? false;
    });

    const canViewReports = computed(() => {
        if (!currentUser.value) return false;
        if (isAdmin.value) return true;
        return currentUser.value.permissions?.canViewReports ?? false;
    });

    const canFiar = computed(() => {
        if (!currentUser.value) return false;
        if (isAdmin.value) return true;
        return currentUser.value.permissions?.canFiar ?? false;
    });

    // Methods
    const generateId = () => {
        return Date.now().toString(36) + Math.random().toString(36).substr(2);
    };

    const registerStore = (data: {
        storeName: string;
        ownerName: string;
        email: string;
        password: string;
        pin: string;
    }): StoreAccount | null => {
        // Check if email already exists
        const exists = stores.value.find(s => s.email.toLowerCase() === data.email.toLowerCase());
        if (exists) {
            console.warn('Email already registered');
            return null;
        }

        const newStore: StoreAccount = {
            id: generateId(),
            storeName: data.storeName,
            ownerName: data.ownerName,
            email: data.email,
            password: data.password,
            pin: data.pin,
            createdAt: new Date().toISOString(),
        };

        stores.value.push(newStore);

        // Auto-login as admin after registration
        loginAsAdmin(newStore);

        return newStore;
    };

    const loginAsAdmin = (store: StoreAccount) => {
        currentUser.value = {
            id: store.id,
            name: store.ownerName,
            email: store.email,
            type: 'admin',
            storeId: store.id,
        };
        isAuthenticated.value = true;
    };

    const loginWithCredentials = (emailOrUsername: string, password: string): boolean => {
        // First, try to find an admin account
        const store = stores.value.find(
            s => s.email.toLowerCase() === emailOrUsername.toLowerCase() && s.password === password
        );

        if (store) {
            loginAsAdmin(store);
            return true;
        }

        return false;
    };

    const loginAsEmployee = (employee: {
        id: number;
        name: string;
        username: string;
        permissions: {
            canSell: boolean;
            canViewInventory: boolean;
            canViewReports: boolean;
            canFiar: boolean;
        };
    }, storeId: string): boolean => {
        currentUser.value = {
            id: `emp-${employee.id}`,
            name: employee.name,
            email: employee.username,
            type: 'employee',
            storeId: storeId,
            employeeId: employee.id,
            permissions: employee.permissions,
        };
        isAuthenticated.value = true;
        return true;
    };

    const logout = () => {
        currentUser.value = null;
        isAuthenticated.value = false;
    };

    const getStoreById = (id: string) => {
        return stores.value.find(s => s.id === id);
    };

    const getFirstStore = () => {
        return stores.value.length > 0 ? stores.value[0] : null;
    };

    const hasStores = computed(() => stores.value.length > 0);

    return {
        // State
        stores,
        currentUser,
        isAuthenticated,
        // Computed
        isAdmin,
        isEmployee,
        currentStore,
        hasStores,
        // Permission helpers
        canSell,
        canViewInventory,
        canViewReports,
        canFiar,
        // Methods
        registerStore,
        loginWithCredentials,
        loginAsAdmin,
        loginAsEmployee,
        logout,
        getStoreById,
        getFirstStore,
        generateId,
    };
}, {
    persist: {
        key: 'tienda-auth',
    },
});

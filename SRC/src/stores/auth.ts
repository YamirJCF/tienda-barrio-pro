import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { logger } from '../utils/logger';

export type UserType = 'admin' | 'employee';

export interface StoreAccount {
  id: string;
  storeName: string;
  ownerName: string;
  email: string;
  password: string;
  // SPEC-006: PIN movido a Supabase (owner_pin_hash en tabla stores)
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
    canOpenCloseCash: boolean; // SPEC-006
    canManageInventory?: boolean; // New granular permission
    canManageClients?: boolean; // New granular permission
  };
}

// =============================================
// CUENTA DEMO POR DEFECTO
// =============================================
const DEMO_ACCOUNT: StoreAccount = {
  id: 'demo-store-001',
  storeName: 'Mi Tienda Demo',
  ownerName: 'Usuario Demo',
  email: 'demo@tienda.com',
  password: 'demo123',
  createdAt: new Date().toISOString(),
};

export const useAuthStore = defineStore(
  'auth',
  () => {
    // State - inicializado con cuenta demo
    const stores = ref<StoreAccount[]>([DEMO_ACCOUNT]);
    const currentUser = ref<CurrentUser | null>(null);
    const isAuthenticated = ref(false);

    // SPEC-005: Estados IAM
    const deviceApproved = ref<'pending' | 'approved' | 'rejected' | null>(null);
    const storeOpenStatus = ref<boolean>(false);

    // Computed
    const isAdmin = computed(() => currentUser.value?.type === 'admin');
    const isEmployee = computed(() => currentUser.value?.type === 'employee');
    const currentStore = computed(() => {
      if (!currentUser.value) return null;
      return stores.value.find((s) => s.id === currentUser.value!.storeId);
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

    // SPEC-006: Permiso para control de caja
    const canOpenCloseCash = computed(() => {
      if (!currentUser.value) return false;
      if (isAdmin.value) return true;
      return currentUser.value.permissions?.canOpenCloseCash ?? false;
    });

    // SPEC-005: Computed para acceso al POS
    const canAccessPOS = computed(() => {
      if (!isAuthenticated.value) return false;
      // Admins siempre pueden acceder
      if (isAdmin.value) return true;
      // Empleados: dispositivo aprobado Y tienda abierta
      return deviceApproved.value === 'approved' && storeOpenStatus.value;
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
      // SPEC-006: PIN eliminado del registro
    }): StoreAccount | null => {
      // Check if email already exists
      const exists = stores.value.find((s) => s.email.toLowerCase() === data.email.toLowerCase());
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
        (s) => s.email.toLowerCase() === emailOrUsername.toLowerCase() && s.password === password,
      );

      if (store) {
        loginAsAdmin(store);
        return true;
      }

      return false;
    };

    const loginAsEmployee = (
      employee: {
        id: number;
        name: string;
        username: string;
        permissions: {
          canSell: boolean;
          canViewInventory: boolean;
          canViewReports: boolean;
          canFiar: boolean;
          canOpenCloseCash: boolean; // SPEC-006
        };
      },
      storeId: string,
    ): boolean => {
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
      // Reset IAM states
      deviceApproved.value = null;
      storeOpenStatus.value = false;
    };

    // SPEC-005: Actions para estados IAM
    const setDeviceStatus = (status: 'pending' | 'approved' | 'rejected') => {
      deviceApproved.value = status;
    };

    const setStoreOpenStatus = (isOpen: boolean) => {
      storeOpenStatus.value = isOpen;
    };

    // Resetear a cuenta demo (limpia todo excepto la cuenta demo)
    const resetToDemo = () => {
      stores.value = [DEMO_ACCOUNT];
      currentUser.value = null;
      isAuthenticated.value = false;
      deviceApproved.value = null;
      storeOpenStatus.value = false;
      // Limpiar otros stores del localStorage
      localStorage.removeItem('tienda-employees');
      localStorage.removeItem('tienda-inventory');
      localStorage.removeItem('tienda-sales');
      localStorage.removeItem('tienda-cart');
      localStorage.removeItem('tienda-clients');
      localStorage.removeItem('tienda-expenses');
      logger.log('✅ Sistema reseteado a cuenta demo');
    };

    // Auto-inicializar: asegurar que siempre exista la cuenta demo
    if (!stores.value.find((s) => s.id === DEMO_ACCOUNT.id)) {
      stores.value = [DEMO_ACCOUNT];
    }

    const getStoreById = (id: string) => {
      return stores.value.find((s) => s.id === id);
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
      // SPEC-005: IAM States
      deviceApproved,
      storeOpenStatus,
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
      canOpenCloseCash, // SPEC-006
      canAccessPOS,
      // Methods
      registerStore,
      loginWithCredentials,
      loginAsAdmin,
      loginAsEmployee,
      logout,
      getStoreById,
      getFirstStore,
      generateId,
      resetToDemo, // Nueva función
      // SPEC-005: IAM Methods
      setDeviceStatus,
      setStoreOpenStatus,
    };
  },
  {
    persist: {
      key: 'tienda-auth',
    },
  },
);

import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { logger } from '../utils/logger';
import { getStorageKey } from '../utils/storage';

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
// Demo Account definition removed for Audit Mode security

export const useAuthStore = defineStore(
  'auth',
  () => {
    // State - inicializado vacío (sin cuenta demo)
    const stores = ref<StoreAccount[]>([]);
    const currentUser = ref<CurrentUser | null>(null);
    const isAuthenticated = ref(false);

    // SPEC-005: Estados IAM
    const deviceApproved = ref<'pending' | 'approved' | 'rejected' | null>(null);
    // storeOpenStatus removed - replaced by Offline Accountability logic

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
      // Empleados: dispositivo aprobado (ya no se chequea storeOpenStatus)
      return deviceApproved.value === 'approved';
    });

    // SPEC-006: Permisos granulares de gestión (Fix para botones CRUD)
    const canManageInventory = computed(() => {
      if (!currentUser.value) return false;
      if (isAdmin.value) return true;
      return currentUser.value.permissions?.canManageInventory ?? false;
    });

    const canManageClients = computed(() => {
      if (!currentUser.value) return false;
      if (isAdmin.value) return true;
      return currentUser.value.permissions?.canManageClients ?? false;
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
    };

    // SPEC-005: Actions para estados IAM
    const setDeviceStatus = (status: 'pending' | 'approved' | 'rejected') => {
      deviceApproved.value = status;
    };

    // WO-005: Daily Pass Logic (Stubs)
    const checkDailyApproval = async () => {
      // En producción: RPC check_daily_pass()
      // Por ahora devuelve el estado actual de deviceApproved
      // Simulando que 'approved' === pase diario activo
      return deviceApproved.value;
    };

    const requestDailyPass = async () => {
      // En producción: RPC request_daily_pass() con ping count
      console.log("Ping enviado al admin");
      return true;
    };

    // storeOpenStatus setter removed

    // Reset function removed to prevent demo account restoration
    const resetToDemo = () => {
      // Logic removed for audit integrity
      currentUser.value = null;
      isAuthenticated.value = false;
      stores.value = [];
      localStorage.clear();
      logger.log('✅ System cleared (No Demo restored)');
    };

    // Auto-initialization removed

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
      // storeOpenStatus removed
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
      canManageInventory, // Fix
      canManageClients,   // Fix
      // Methods
      registerStore,
      loginWithCredentials,
      loginAsAdmin,
      loginAsEmployee,
      logout,
      getStoreById,
      getFirstStore,
      generateId,
      resetToDemo,
      // SPEC-005: IAM Methods
      setDeviceStatus,
      checkDailyApproval,
      requestDailyPass
    };
  },
  {
    persist: {
      key: getStorageKey('tienda-auth'),
    },
  },
);

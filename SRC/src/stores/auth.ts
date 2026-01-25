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
    // deviceApproved ref removed -> replaced by computed dailyAccessState
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
      dailyAccessState.value = {
        status: 'expired',
        lastApprovedAt: null,
        fingerprint: null,
        requestedAt: null
      };
    };

    // STUB: Daily Pass Logic (Local Simulation for FRD-001)
    // -----------------------------------------------------

    interface DailyPassState {
      status: 'pending' | 'approved' | 'rejected' | 'expired';
      lastApprovedAt: string | null; // ISO
      fingerprint: string | null;
      requestedAt: string | null;
    }

    // State principal de seguridad diaria
    const dailyAccessState = ref<DailyPassState>({
      status: 'expired', // Default to expired for Zero Trust
      lastApprovedAt: null,
      fingerprint: null,
      requestedAt: null
    });

    // Mantenemos propiedad computada para compatibilidad
    // 'deviceApproved' ahora deriva calculando la expiración
    const deviceApproved = computed(() => {
      // Regla 1: Expiración Diaria
      if (dailyAccessState.value.status === 'approved' && dailyAccessState.value.lastApprovedAt) {
        const lastDate = new Date(dailyAccessState.value.lastApprovedAt).toDateString();
        const today = new Date().toDateString();
        if (lastDate !== today) {
          return 'expired';
        }
      }
      return dailyAccessState.value.status;
    });

    // Utilidad: Fingerprinting simplificado (Local)
    const getDeviceFingerprint = () => {
      return btoa(`${navigator.userAgent}-${window.screen.width}x${window.screen.height}-${Intl.DateTimeFormat().resolvedOptions().timeZone}`);
    };

    // Action: Verificar estado al cargar app
    const checkDailyApproval = async () => {
      // En producción: Supabase RPC check_daily_pass(fingerprint)

      // Simulación Local: Auto-expirar si cambió el día
      if (dailyAccessState.value.status === 'approved' && dailyAccessState.value.lastApprovedAt) {
        const lastDate = new Date(dailyAccessState.value.lastApprovedAt).toDateString();
        const today = new Date().toDateString();

        if (lastDate !== today) {
          console.log('[Auth] Daily Pass vencido (Nuevo día)');
          dailyAccessState.value.status = 'expired';
        }
      }
      return dailyAccessState.value.status;
    };

    // Action: Solicitar acceso
    const requestDailyPass = async () => {
      // En producción: RPC request_daily_pass() con ping count
      console.log("[Auth] Solicitando Pase Diario...");
      dailyAccessState.value.status = 'pending';
      dailyAccessState.value.requestedAt = new Date().toISOString();
      dailyAccessState.value.fingerprint = getDeviceFingerprint();
      return true;
    };

    // Action: Aprobar (Solo Admin - Simulado)
    const approveRequest = async () => {
      if (!isAdmin.value) return false;

      console.log("[Auth] Admin aprobando solicitud...");
      dailyAccessState.value.status = 'approved';
      dailyAccessState.value.lastApprovedAt = new Date().toISOString();
      return true;
    };

    // Action: Rechazar (Solo Admin)
    const rejectRequest = async () => {
      if (!isAdmin.value) return false;

      dailyAccessState.value = {
        status: 'rejected',
        lastApprovedAt: null,
        fingerprint: null,
        requestedAt: null
      };
      return true;
    };

    // Helper functions restored
    const resetToDemo = () => {
      currentUser.value = null;
      isAuthenticated.value = false;
      stores.value = [];
      localStorage.clear();
      logger.log('✅ System cleared (No Demo restored)');
    };

    const getStoreById = (id: string) => {
      return stores.value.find((s) => s.id === id);
    };

    const getFirstStore = () => {
      return stores.value.length > 0 ? stores.value[0] : null;
    };

    const hasStores = computed(() => stores.value.length > 0);

    // Accessors
    const dailyAccessStatus = computed(() => deviceApproved.value);
    const pendingRequestTime = computed(() => dailyAccessState.value.requestedAt);

    return {
      // State
      stores,
      currentUser,
      isAuthenticated,
      dailyAccessState, // Exposed for Persistence
      // SPEC-005: IAM States
      dailyAccessStatus, // Replaces direct exposure of deviceApproved
      pendingRequestTime,

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
      checkDailyApproval,
      requestDailyPass,
      approveRequest,
      rejectRequest
    };
  },
  {
    persist: {
      key: getStorageKey('tienda-auth'),
    },
  },
);

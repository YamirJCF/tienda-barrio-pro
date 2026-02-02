import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { logger } from '../utils/logger';
import { getStorageKey } from '../utils/storage';
import { authRepository, type RegisterResponse } from '../data/repositories/authRepository';

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
  employeeId?: string; // UUID (migrated from number)
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
    // State - inicializado vacía (sin cuenta demo)
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

    const registerStore = async (data: {
      storeName: string;
      ownerName: string;
      email: string;
      password: string;
    }): Promise<RegisterResponse> => {

      const response = await authRepository.registerStore({
        storeName: data.storeName,
        ownerName: data.ownerName,
        email: data.email,
        password: data.password
      });

      if (response.success && response.user) {
        // Logic as in restored file
      }

      return response;
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

      // FIX: Auto-aprobar Daily Pass para Admin (evita redirect a waiting room)
      dailyAccessState.value.status = 'approved';
      dailyAccessState.value.lastApprovedAt = new Date().toISOString();
    };

    const login = async (email: string, password: string): Promise<boolean> => {
      try {
        const response = await authRepository.loginStore(email, password);

        if (response.success && response.employee) {
          currentUser.value = response.employee;
          isAuthenticated.value = true;

          // Admin auto-approval for daily pass
          dailyAccessState.value.status = 'approved';
          dailyAccessState.value.lastApprovedAt = new Date().toISOString();

          // FIX: Populate cached store to valid 'currentStore' computed property
          if (response.store_details) {
            const existingIndex = stores.value.findIndex(s => s.id === response.store_details!.id);
            const storeData: StoreAccount = {
              id: response.store_details.id,
              storeName: response.store_details.name,
              ownerName: response.store_details.owner,
              email: response.store_details.email,
              password: '', // Not stored/needed for session
              createdAt: new Date().toISOString()
            };

            if (existingIndex >= 0) {
              stores.value[existingIndex] = storeData;
            } else {
              stores.value.push(storeData);
            }
          }

          return true;
        }
        return false;
      } catch (error) {
        console.error('Login Store Error', error);
        return false;
      }
    };

    const loginAsEmployee = (
      employee: {
        id: string; // UUID
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

      // Zero Trust: Check daily pass immediately
      checkDailyApproval();

      return true;
    };

    const logout = async () => {
      await authRepository.logout();
      currentUser.value = null;
      isAuthenticated.value = false;
      localStorage.removeItem('pin_auth_token');
      // Reset daily access? Maybe not, device is still same.
      // But user session is gone.
      // Reset IAM states
      dailyAccessState.value = {
        status: 'expired',
        lastApprovedAt: null,
        fingerprint: null,
        requestedAt: null
      };
    };

    const recoverPassword = async (email: string) => {
      return await authRepository.recoverPassword(email);
    };

    // STUB: Daily Pass Logic (Local Simulation for FRD-001)
    // -----------------------------------------------------

    interface DailyPassState {
      status: 'pending' | 'approved' | 'rejected' | 'expired' | 'none';
      lastApprovedAt: string | null | undefined; // ISO
      fingerprint: string | null;
      requestedAt: string | null;
      approvedBy?: string;
    }

    // State principal de seguridad diaria
    // State principal de seguridad diaria
    const dailyAccessState = ref<DailyPassState>({
      status: 'expired',
      lastApprovedAt: null,
      fingerprint: null,
      requestedAt: null
    });

    // Admin: Pending Requests State
    const pendingRequests = ref<any[]>([]);


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
    // Action: Verificar estado al cargar app (Real Backend)
    const checkDailyApproval = async () => {
      if (!currentUser.value || !('username' in currentUser.value)) return 'none';

      const fingerprint = getDeviceFingerprint(); // Sync
      const result = await authRepository.checkDailyPassStatus(currentUser.value.id, fingerprint);

      dailyAccessState.value.status = result.status;

      if (result.status === 'approved') {
        dailyAccessState.value.approvedBy = 'system'; // Or fetch who approved
        dailyAccessState.value.lastApprovedAt = new Date().toISOString();
      }

      return dailyAccessState.value.status;
    };

    // Action: Solicitar acceso (Real Backend)
    const requestDailyPass = async () => {
      if (!currentUser.value || !('username' in currentUser.value)) return false;

      const fingerprint = getDeviceFingerprint(); // Sync
      const result = await authRepository.requestDailyPass(currentUser.value.id, fingerprint);

      if (result.success) {
        dailyAccessState.value.status = (result.status as any) || 'pending';
        dailyAccessState.value.fingerprint = fingerprint;
        dailyAccessState.value.requestedAt = new Date().toISOString();
        return true;
      } else {
        console.error("Pass Request Error:", result.error);
        return false;
      }
    };

    // Action: Fetch Pending Requests (Admin)
    const fetchPendingRequests = async () => {
      if (!currentStore.value?.id) return;
      const requests = await authRepository.getPendingAccessRequests(currentStore.value.id);
      pendingRequests.value = requests || [];
    };

    // Action: Aprobar (Real Backend)
    const approveRequest = async (requestId: string) => {
      if (!currentUser.value) return false;
      try {
        await authRepository.updateAccessRequestStatus(requestId, 'approved', currentUser.value.id);
        // Refresh list
        await fetchPendingRequests();
        return true;
      } catch (e) {
        console.error(e);
        return false;
      }
    };

    // Action: Rechazar (Real Backend)
    const rejectRequest = async (requestId: string) => {
      if (!currentUser.value) return false;
      try {
        await authRepository.updateAccessRequestStatus(requestId, 'rejected', currentUser.value.id);
        await fetchPendingRequests();
        return true;
      } catch (e) {
        console.error(e);
        return false;
      }
    };



    // Helper to manually set status (used by Login flows)
    const setDeviceStatus = (status: 'pending' | 'approved' | 'rejected' | 'expired') => {
      dailyAccessState.value.status = status;
      if (status === 'approved') {
        dailyAccessState.value.lastApprovedAt = new Date().toISOString();
      }
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
      deviceApproved, // Exposed for LoginView and GatekeeperPending
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
      canOpenCloseCash,
      canAccessPOS,
      canManageInventory,
      canManageClients,

      // Admin Lists
      pendingRequests,

      // Methods
      registerStore,
      login,
      loginAsAdmin,
      loginAsEmployee,
      recoverPassword,
      logout,
      getStoreById,
      getFirstStore,
      generateId,
      resetToDemo,
      // SPEC-005: IAM Methods
      checkDailyApproval,
      requestDailyPass,
      approveRequest,
      rejectRequest,
      fetchPendingRequests,
      setDeviceStatus,
    };
  },
  {
    persist: {
      key: getStorageKey('tienda-auth'),
    },
  },
);

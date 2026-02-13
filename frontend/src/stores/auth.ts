import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { logger } from '../utils/logger';
import { getStorageKey } from '../utils/storage';
import { authRepository, type RegisterResponse } from '../data/repositories/authRepository';
import { useNotificationsStore } from './notificationsStore';
import { requireSupabase } from '../data/supabaseClient';

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

    const isEmailConfirmed = computed(() => {
      if (!currentUser.value) return false;
      // Employees (Zero-Auth) don't need email confirmation usually, but Admins do.
      if (currentUser.value.type === 'admin') {
        // We can't easily check 'email_confirmed_at' from here because 'CurrentUser' doesn't have it.
        // We need to fetch it or store it.
        // For now, let's assume if they are logged in via Supabase and we have a session, 
        // we should check the actual Supabase session user.
        return true; // Placeholder until we integrate with supabase.auth.getUser()
      }
      return true;
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

    /**
     * Initializes auth store from an existing Supabase session.
     * Used after email confirmation redirect (token interceptor has already
     * established the session via setSession()).
     * Does NOT require credentials — the session already exists.
     */
    const initializeFromSession = async (): Promise<boolean> => {
      try {
        // 1. Check if the interceptor cached a profile in sessionStorage
        const cachedProfile = sessionStorage.getItem('__auth_callback_profile__');
        let response;

        if (cachedProfile) {
          response = JSON.parse(cachedProfile);
          sessionStorage.removeItem('__auth_callback_profile__');
          logger.log('[Auth Store] Initialized from cached callback profile');
        } else {
          // 2. Fallback: fetch profile from Supabase directly
          const supabase = requireSupabase();
          const { data: { session } } = await supabase.auth.getSession();
          if (!session?.user) {
            logger.warn('[Auth Store] No active session for initializeFromSession');
            return false;
          }
          response = await authRepository.getAdminProfile(session.user.id);
        }

        if (response.success && response.employee) {
          currentUser.value = response.employee;
          isAuthenticated.value = true;

          // Admin auto-approval for daily pass
          dailyAccessState.value.status = 'approved';
          dailyAccessState.value.lastApprovedAt = new Date().toISOString();

          // Populate cached store
          if (response.store_details) {
            const existingIndex = stores.value.findIndex(s => s.id === response.store_details!.id);
            const storeData: StoreAccount = {
              id: response.store_details.id,
              storeName: response.store_details.name,
              ownerName: response.store_details.owner,
              email: response.store_details.email,
              password: '',
              createdAt: new Date().toISOString()
            };

            if (existingIndex >= 0) {
              stores.value[existingIndex] = storeData;
            } else {
              stores.value.push(storeData);
            }
          }

          logger.log('[Auth Store] ✅ Session initialized successfully');
          return true;
        }
        return false;
      } catch (error) {
        logger.error('[Auth Store] initializeFromSession error:', error);
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
        permissions: {
          ...employee.permissions,
          // Default to true if not present but required for basic operation
          canManageClients: (employee.permissions as any).canManageClients ?? true,
          canManageInventory: (employee.permissions as any).canManageInventory ?? false
        },
      };
      isAuthenticated.value = true;

      // FIX: Populate 'stores' so 'currentStore' computed property works for employees
      const existingStore = stores.value.find(s => s.id === storeId);
      if (!existingStore) {
        stores.value.push({
          id: storeId,
          storeName: 'Tienda', // Placeholder until fetched
          ownerName: 'Owner',  // Placeholder
          email: '',
          password: '',
          createdAt: new Date().toISOString()
        });
      }

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

    const changePassword = async (currentPassword: string, newPassword: string) => {
      const email = currentUser.value?.email;
      if (!email) {
        return { success: false, error: 'No se encontró el email del usuario actual' };
      }
      return await authRepository.changePassword(email, currentPassword, newPassword);
    };

    // STUB: Daily Pass Logic (Local Simulation for FRD-001)
    // -----------------------------------------------------

    interface DailyPassState {
      status: 'pending' | 'approved' | 'rejected' | 'expired' | 'none';
      lastApprovedAt: string | null | undefined; // ISO
      fingerprint: string | null;
      requestedAt: string | null;
      approvedBy?: string;
      passId?: string; // New field for polling
    }

    // State principal de seguridad diaria
    // State principal de seguridad diaria
    const dailyAccessState = ref<DailyPassState>({
      status: 'expired',
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
    // Action: Verificar estado al cargar app (Real Backend)
    // Action: Verificar estado al cargar app (Real Backend)
    const checkDailyApproval = async () => {
      // FIX: Removed 'username' check as CurrentUser interface uses 'email' for employees/admins
      if (!currentUser.value) return 'none';

      // Auto-recover fingerprint if lost (Critical for page refresh)
      if (!dailyAccessState.value.fingerprint) {
        dailyAccessState.value.fingerprint = getDeviceFingerprint();
      }

      const result = await authRepository.checkDailyPassStatus(currentUser.value.id, dailyAccessState.value.fingerprint);

      dailyAccessState.value.status = result.status;

      if (result.status === 'approved') {
        dailyAccessState.value.approvedBy = 'system'; // Or fetch who approved
        dailyAccessState.value.lastApprovedAt = new Date().toISOString();
      }

      return dailyAccessState.value.status;
    };

    // Action: Solicitar acceso (Real Backend)
    const requestDailyPass = async (): Promise<{ success: boolean; error?: string }> => {
      // FIX: Removed 'username' check as CurrentUser interface uses 'email' for employees/admins
      if (!currentUser.value) return { success: false, error: 'No user session' };

      const fingerprint = getDeviceFingerprint(); // Sync
      const result = await authRepository.requestDailyPass(currentUser.value.id, fingerprint);

      if (result.success) {
        dailyAccessState.value.status = (result.status as any) || 'pending';
        dailyAccessState.value.fingerprint = fingerprint;
        dailyAccessState.value.requestedAt = new Date().toISOString();
        return { success: true };
      } else {
        console.error("Pass Request Error:", result.error);
        return { success: false, error: result.error || 'Unknown error' };
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


      // Methods
      registerStore,
      login,
      initializeFromSession,
      loginAsAdmin,
      loginAsEmployee,
      recoverPassword,
      changePassword,
      logout,
      getStoreById,
      getFirstStore,
      generateId,
      resetToDemo,
      // SPEC-005: IAM Methods
      checkDailyApproval,
      requestDailyPass,
      setDeviceStatus,
    };
  },
  {
    persist: {
      key: getStorageKey('tienda-auth'),
    },
  },
);

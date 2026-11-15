import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { logger } from '../utils/logger';
import { getStorageKey } from '../utils/storage';
import { authRepository, type RegisterResponse, type SessionVerificationResult } from '../data/repositories/authRepository';
import {
  legalRepository,
  type ActiveLegalDocument,
  type LegalComplianceStatus,
} from '../data/repositories/legalRepository';
import { useNotificationsStore } from './notificationsStore';
import { useInventoryStore } from './inventory';
import { useSalesStore } from './sales';
import { useClientsStore } from './clients';
import { useCashRegisterStore } from './cashRegister';
import { useSuppliersStore } from './suppliers';
import { useEmployeesStore } from './employees';
import { useFinancialStore } from './financial';
import { usePayablesStore } from './payables';
import { useCartStore } from './cart';
import { getDB } from '../data/sources/IndexedDBDataSource';
import { systemCacheManager } from '../services/systemCacheManager';
import { deriveKeyFromPin } from '../utils/crypto';
import { getQueueSize } from '../data/syncQueue';
import { requireSupabase } from '../data/supabaseClient';
import { useDeviceFingerprint } from '../composables/useDeviceFingerprint';

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

/**
 * Protocolo de Autodestrucción Total (Scorched Earth Teardown)
 * Destruye el 100% de datos en memoria RAM viva, localStorage, sessionStorage,
 * IndexedDB y SystemCacheManager para garantizar un navegador virgen tras logout.
 */
export async function destroyAllLocalData() {
  logger.log('[Auth Store] 💥 Ejecutando Autodestrucción Total (RAM + Disco)...');

  // 1. Vaciar estado en memoria RAM viva de los Stores activos de Pinia
  try {
    const invStore = useInventoryStore();
    invStore.products = [];
    invStore.initialized = false;
    invStore.loadedStoreId = null;
  } catch (e) {}

  try {
    const salesStore = useSalesStore();
    salesStore.sales = [];
    salesStore.nextTicketNumber = 1;
    salesStore.loadedStoreId = null;
  } catch (e) {}

  try {
    const clientsStore = useClientsStore();
    clientsStore.clients = [];
    clientsStore.transactions = [];
  } catch (e) {}

  try {
    const cashStore = useCashRegisterStore();
    cashStore.currentSession = null;
    cashStore.sessionHistory = [];
  } catch (e) {}

  try {
    useSuppliersStore().suppliers = [];
  } catch (e) {}

  try {
    useEmployeesStore().employees = [];
  } catch (e) {}

  try {
    const finStore = useFinancialStore();
    finStore.summary = null;
    finStore.inventoryHealth = null;
    finStore.clientLedger = null;
    finStore.stagnantProducts = [];
    finStore.topProductsByUnits = [];
  } catch (e) {}

  try {
    usePayablesStore().invoices = [];
  } catch (e) {}

  try {
    useCartStore().clearCart();
  } catch (e) {}

  // 2. Limpiar colecciones locales en IndexedDB
  if (typeof indexedDB !== 'undefined') {
    try {
      const db = await getDB();
      await db.clear('products');
      await db.clear('clients');
      await db.clear('sales');
    } catch (e) {
      logger.warn('[Auth Store] Advertencia limpiando caché IndexedDB:', e);
    }
  }

  // 3. Resetear Gestor de Caché SWR
  try {
    systemCacheManager.reset();
  } catch (e) {
    logger.warn('[Auth Store] Advertencia reseteando systemCacheManager:', e);
  }

  // 4. Barrido total de almacenamiento local (Disco)
  try {
    if (typeof localStorage !== 'undefined') {
      localStorage.clear();
    }
    if (typeof sessionStorage !== 'undefined') {
      sessionStorage.clear();
    }
  } catch (e) {
    logger.warn('[Auth Store] Error en barrido localStorage/sessionStorage:', e);
  }
}

export const clearTenantLocalData = destroyAllLocalData;

export const useAuthStore = defineStore(
  'auth',
  () => {
    // State - inicializado vacía (sin cuenta demo)
    const stores = ref<StoreAccount[]>([]);
    const currentUser = ref<CurrentUser | null>(null);
    const isAuthenticated = ref(false);
    const lastLoginError = ref<string | null>(null);

    // SDD-029: Estado de cumplimiento legal en RAM (siempre verificado con servidor, nunca persistido)
    const legalComplianceStatus = ref<LegalComplianceStatus | null>(null);
    const legalPendingMajorDocs = ref<ActiveLegalDocument[]>([]);
    const legalPendingMinorNotices = ref<ActiveLegalDocument[]>([]);
    const legalSupportChannel = ref<{ contact: string; message: string } | null>(null);
    const legalHasCheckedThisSession = ref(false);
    const legalCheckError = ref<string | null>(null);
    const isCheckingLegal = ref(false);
    const isAcceptingLegal = ref(false);
    const minorNoticeDismissed = ref(false);

    // Crypto State (RAM ONLY - Never persisted to localStorage)
    const sessionCryptoKey = ref<CryptoKey | null>(null);
    const storeCryptoSalt = ref<string | null>(null);

    // SPEC-005: Estados IAM
    // deviceApproved ref removed -> replaced by computed dailyAccessState
    // storeOpenStatus removed - replaced by Offline Accountability logic

    // Computed
    const isCryptoKeyReady = computed(() => sessionCryptoKey.value !== null);
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
    const registerStore = async (data: {
      storeName: string;
      ownerName: string;
      email: string;
      password: string;
      acceptedTermsVersionId: string;
      acceptedPrivacyVersionId: string;
      originChannel?: string;
      clientUserAgent?: string;
    }): Promise<RegisterResponse> => {

      const response = await authRepository.registerStore({
        storeName: data.storeName,
        ownerName: data.ownerName,
        email: data.email,
        password: data.password,
        acceptedTermsVersionId: data.acceptedTermsVersionId,
        acceptedPrivacyVersionId: data.acceptedPrivacyVersionId,
        originChannel: data.originChannel,
        clientUserAgent: data.clientUserAgent,
      });

      if (response.success && response.user) {
        // Logic as in restored file
      }

      return response;
    };

    const login = async (email: string, password: string): Promise<boolean> => {
      lastLoginError.value = null;
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

          await checkLegalCompliance(response.employee.storeId);

          return true;
        }
        lastLoginError.value = response.error || null;
        return false;
      } catch (error: any) {
        console.error('Login Store Error', error);
        lastLoginError.value = error?.message || null;
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
          // FIX: Use getUser() (server call) instead of getSession() (local cache)
          // This ensures email_confirmed_at and other flags are fresh
          const supabase = requireSupabase();
          const { data: { user }, error } = await supabase.auth.getUser();
          if (!user || error) {
            logger.warn('[Auth Store] No active user for initializeFromSession');
            return false;
          }
          response = await authRepository.getAdminProfile(user.id);
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

          await checkLegalCompliance(response.employee.storeId);

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
          // Default to false — client management is admin-only
          canManageClients: (employee.permissions as any).canManageClients ?? false,
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

    const fetchStoreSalt = async (): Promise<string> => {
      if (storeCryptoSalt.value) return storeCryptoSalt.value;
      const storeId = currentUser.value?.storeId;
      if (!storeId) throw new Error('No active store ID for salt retrieval');

      try {
        const supabase = requireSupabase();
        const { data, error } = await supabase
          .from('stores')
          .select('crypto_salt')
          .eq('id', storeId)
          .single();

        if (error) throw error;

        if (data?.crypto_salt) {
          storeCryptoSalt.value = data.crypto_salt;
          return data.crypto_salt;
        }

        // If no salt exists yet, generate a new random salt and store it in DB
        const newSalt = Array.from(window.crypto.getRandomValues(new Uint8Array(16)))
          .map(b => b.toString(16).padStart(2, '0'))
          .join('');

        await supabase
          .from('stores')
          .update({ crypto_salt: newSalt })
          .eq('id', storeId);

        storeCryptoSalt.value = newSalt;
        return newSalt;
      } catch (err) {
        logger.error('[Auth Store] Failed to fetch store salt:', err);
        // Fallback salt derived from storeId to prevent total failure if offline
        const fallbackSalt = `salt-${storeId}`;
        storeCryptoSalt.value = fallbackSalt;
        return fallbackSalt;
      }
    };

    const setupCryptoKey = async (pin: string): Promise<boolean> => {
      try {
        const salt = await fetchStoreSalt();
        sessionCryptoKey.value = await deriveKeyFromPin(pin, salt);
        logger.log('[Auth Store] CryptoKey setup successfully in RAM');
        return true;
      } catch (err) {
        logger.error('[Auth Store] Failed to setup CryptoKey:', err);
        return false;
      }
    };

    const clearCryptoKey = () => {
      sessionCryptoKey.value = null;
      logger.log('[Auth Store] CryptoKey cleared from RAM');
    };

    const logout = async (): Promise<boolean> => {
      // Guardia de salida: No permitir cierre sin internet o con transacciones pendientes en cola
      if (typeof navigator !== 'undefined' && !navigator.onLine) {
        logger.warn('[Auth Store] 🔒 Cierre de sesión bloqueado: Dispositivo fuera de línea.');
        return false;
      }

      try {
        const pendingCount = await getQueueSize();
        if (pendingCount > 0) {
          logger.warn(`[Auth Store] 🔒 Cierre de sesión bloqueado: Hay ${pendingCount} transacciones pendientes por sincronizar.`);
          return false;
        }
      } catch (e) {
        logger.warn('[Auth Store] No se pudo verificar la cola de sincronización:', e);
      }

      try {
        await authRepository.logout();
      } catch (e) {
        logger.warn('[Auth Store] Fallo al cerrar sesión en authRepository:', e);
      }

      currentUser.value = null;
      isAuthenticated.value = false;
      clearCryptoKey();
      resetLegalState();

      dailyAccessState.value = {
        status: 'expired',
        lastApprovedAt: null,
        fingerprint: null,
        requestedAt: null
      };

      await destroyAllLocalData();
      return true;
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
    // 'deviceApproved' ya NO expira por reloj astronómico (FRD-017 v3.0).
    // La expiración ocurre por trigger en la base de datos al cerrar el turno.
    const deviceApproved = computed(() => {
      return dailyAccessState.value.status;
    });

    /**
     * SDD-013 v3.1.0: Consulta al Backend la verdad de la sesión (Supabase Auth + Daily Passes + Roles)
     * Resuelve inconsistencias cuando el cliente tiene token expirado o pase vencido.
     */
    const verifySessionWithServer = async (): Promise<SessionVerificationResult> => {
      try {
        const result = await authRepository.verifySessionAccessState();

        if (result.status === 'active') {
          // Sesión válida en servidor
          if (dailyAccessState.value.status !== 'approved') {
            dailyAccessState.value.status = 'approved';
            dailyAccessState.value.lastApprovedAt = new Date().toISOString();
          }
          if (result.pass_id) {
            dailyAccessState.value.passId = result.pass_id;
          }
          return result;
        }

        // Si no está activa en servidor
        logger.warn(`[Auth Store] Sesión no activa en servidor: ${result.status} (${result.reason || 'Sin razón'})`);

        if (result.status === 'requires_daily_pass') {
          // El pase expiró (ej. cambio de día o medianoche superada)
          dailyAccessState.value.status = 'expired';
          // Descartar carrito en curso (RN-013-12)
          try {
            useCartStore().clearCart();
          } catch (e) {
            // Cart store might not be ready yet
          }
        } else if (result.status === 'requires_login' || result.status === 'revoked_or_disabled') {
          // Token expirado o revocado en servidor: invocar autodestrucción total
          await logout();
          try {
            useCartStore().clearCart();
          } catch (e) {
            // Cart store might not be ready yet
          }
        }

        // Notificar a otras pestañas mediante BroadcastChannel (RN-013-13)
        if (typeof BroadcastChannel !== 'undefined') {
          try {
            const channel = new BroadcastChannel('tienda-auth-sync');
            channel.postMessage({
              type: 'SESSION_STATE_CHANGED',
              status: result.status,
              reason: result.reason,
              timestamp: Date.now()
            });
            channel.close();
          } catch (e) {
            logger.warn('[Auth Store] BroadcastChannel postMessage error:', e);
          }
        }

        return result;
      } catch (err: any) {
        logger.error('[Auth Store] verifySessionWithServer exception:', err);
        return {
          success: false,
          status: 'requires_login',
          reason: err?.message || 'EXCEPTION'
        };
      }
    };

    // Action: Verificar estado al cargar app (Real Backend)
    const checkDailyApproval = async () => {
      // FIX: Removed 'username' check as CurrentUser interface uses 'email' for employees/admins
      if (!currentUser.value) return 'none';

      // Auto-recover fingerprint if lost (Critical for page refresh)
      if (!dailyAccessState.value.fingerprint) {
        dailyAccessState.value.fingerprint = await useDeviceFingerprint().getFingerprint();
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

      const fingerprint = await useDeviceFingerprint().getFingerprint();
      const result = await authRepository.requestDailyPass(currentUser.value.id, fingerprint);

      if (result.success) {
        dailyAccessState.value.status = (result.status as any) || 'pending';
        dailyAccessState.value.fingerprint = fingerprint;
        dailyAccessState.value.requestedAt = new Date().toISOString();
        // OT-6: Persist passId so DailyWaitingRoom can subscribe to the correct Realtime row
        if (result.pass_id) {
          dailyAccessState.value.passId = result.pass_id;
        }
        return { success: true };
      } else {
        console.error("Pass Request Error:", result.error);
        return { success: false, error: result.error || 'Unknown error' };
      }
    };




    const resetLegalState = () => {
      legalComplianceStatus.value = null;
      legalPendingMajorDocs.value = [];
      legalPendingMinorNotices.value = [];
      legalSupportChannel.value = null;
      legalHasCheckedThisSession.value = false;
      legalCheckError.value = null;
      isCheckingLegal.value = false;
      isAcceptingLegal.value = false;
      minorNoticeDismissed.value = false;
    };

    const isLegalBlocked = computed(() => {
      return (
        isAuthenticated.value &&
        isAdmin.value &&
        legalComplianceStatus.value === 'requires_major_acceptance'
      );
    });

    const checkLegalCompliance = async (storeIdOverride?: string) => {
      const targetStoreId = storeIdOverride || currentUser.value?.storeId;
      if (!targetStoreId || !isAdmin.value) {
        return null;
      }

      isCheckingLegal.value = true;
      legalCheckError.value = null;
      try {
        const status = await legalRepository.checkStoreLegalStatus(targetStoreId);
        legalComplianceStatus.value = status.compliance_status;
        legalPendingMajorDocs.value = status.pending_major_documents || [];
        legalPendingMinorNotices.value = status.pending_minor_notices || [];
        legalSupportChannel.value = status.support_channel || null;
        legalHasCheckedThisSession.value = true;
        if (status.compliance_status !== 'minor_notice_available') {
          minorNoticeDismissed.value = false;
        }
        return status;
      } catch (err: any) {
        logger.error('[Auth Store] Error verificando cumplimiento legal:', err);
        legalCheckError.value =
          err?.message || 'No se pudo verificar el estado de documentos legales en el servidor.';
        return null;
      } finally {
        isCheckingLegal.value = false;
      }
    };

    const acceptPendingLegalVersions = async (
      versionIds: string[],
      originChannel: string = 'web_login_gate'
    ) => {
      const targetStoreId = currentUser.value?.storeId;
      if (!targetStoreId) {
        throw new Error('No se identificó la tienda activa para registrar la aceptación.');
      }

      isAcceptingLegal.value = true;
      try {
        await legalRepository.acceptLegalVersions(targetStoreId, versionIds, originChannel);
        return await checkLegalCompliance(targetStoreId);
      } catch (err: any) {
        if (err?.code === 'LEGAL_VERSION_SUPERSEDED') {
          await checkLegalCompliance(targetStoreId);
        }
        throw err;
      } finally {
        isAcceptingLegal.value = false;
      }
    };

    const dismissMinorNotice = () => {
      minorNoticeDismissed.value = true;
    };

    // Helper to manually set status (used by Login flows)
    const setDeviceStatus = (status: 'pending' | 'approved' | 'rejected' | 'expired') => {
      dailyAccessState.value.status = status;
      if (status === 'approved') {
        dailyAccessState.value.lastApprovedAt = new Date().toISOString();
      }
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
      lastLoginError,
      dailyAccessState, // Exposed for Persistence
      // Accessors
      dailyAccessStatus, // Replaces direct exposure of deviceApproved
      deviceApproved, // Exposed for LoginView and GatekeeperPending
      pendingRequestTime,

      // Crypto State & Methods (RAM ONLY)
      sessionCryptoKey,
      isCryptoKeyReady,
      setupCryptoKey,
      clearCryptoKey,
      fetchStoreSalt,

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
      loginAsEmployee,
      recoverPassword,
      changePassword,
      logout,
      // SPEC-005: IAM Methods
      checkDailyApproval,
      verifySessionWithServer,
      requestDailyPass,
      setDeviceStatus,
      // SDD-029: Legal Compliance
      legalComplianceStatus,
      legalPendingMajorDocs,
      legalPendingMinorNotices,
      legalSupportChannel,
      legalHasCheckedThisSession,
      legalCheckError,
      isCheckingLegal,
      isAcceptingLegal,
      minorNoticeDismissed,
      isLegalBlocked,
      checkLegalCompliance,
      acceptPendingLegalVersions,
      dismissMinorNotice,
      resetLegalState,
    };
  },
  {
    persist: {
      key: getStorageKey('tienda-auth'),
      paths: ['stores', 'currentUser', 'isAuthenticated', 'dailyAccessState'],
    } as any,
  },
);

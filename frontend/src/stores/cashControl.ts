import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { useAuthStore } from './auth';
import { logger } from '../utils/logger';

/**
 * Cash Control Store - SPEC-006
 *
 * Implementación local con localStorage para desarrollo.
 * TODO: Migrar a Supabase cuando el backend esté configurado.
 */

export interface CashControlEvent {
  id: string;
  storeId: string;
  eventType: 'open' | 'close';
  authorizedById: string | null;
  authorizedByType: 'admin' | 'employee';
  authorizedByName: string;
  amountDeclared: number;
  amountExpected: number | null;
  difference: number | null;
  pinVerified: boolean;
  createdAt: string;
}

// Storage keys
const STORAGE_KEYS = {
  PIN_HASH: 'tienda_pro:pin_hash',
  PIN_ATTEMPTS: 'tienda_pro:pin_attempts',
  PIN_LOCKED_UNTIL: 'tienda_pro:pin_locked',
  CASH_OPEN: 'tienda_pro:cash_open',
  CASH_BASE: 'tienda_pro:cash_base',
  CASH_EVENTS: 'tienda_pro:cash_events',
};

// Simple hash function for PIN (not cryptographically secure, but ok for dev)
const simpleHash = (str: string): string => {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash = hash & hash;
  }
  return hash.toString(36);
};

export const useCashControlStore = defineStore('cashControl', () => {
  const authStore = useAuthStore();

  // State
  const isOpen = ref(false);
  const currentEvent = ref<CashControlEvent | null>(null);
  const pinAttempts = ref(0);
  const lockedUntil = ref<Date | null>(null);
  const loading = ref(false);
  const hasPinConfigured = ref(false);
  const expectedCash = ref<number>(0);

  // Constants
  const MAX_ATTEMPTS = 5;
  const LOCK_DURATION_MS = 5 * 60 * 1000; // 5 minutes
  const PIN_LENGTH = 6;

  // Initialize from localStorage
  const init = () => {
    const storedHash = localStorage.getItem(STORAGE_KEYS.PIN_HASH);
    hasPinConfigured.value = !!storedHash;

    const storedAttempts = localStorage.getItem(STORAGE_KEYS.PIN_ATTEMPTS);
    pinAttempts.value = storedAttempts ? parseInt(storedAttempts, 10) : 0;

    const storedLocked = localStorage.getItem(STORAGE_KEYS.PIN_LOCKED_UNTIL);
    if (storedLocked) {
      const lockedDate = new Date(storedLocked);
      if (lockedDate > new Date()) {
        lockedUntil.value = lockedDate;
      } else {
        localStorage.removeItem(STORAGE_KEYS.PIN_LOCKED_UNTIL);
        localStorage.setItem(STORAGE_KEYS.PIN_ATTEMPTS, '0');
        pinAttempts.value = 0;
      }
    }

    isOpen.value = localStorage.getItem(STORAGE_KEYS.CASH_OPEN) === 'true';
    const storedBase = localStorage.getItem(STORAGE_KEYS.CASH_BASE);
    expectedCash.value = storedBase ? parseFloat(storedBase) : 0;
  };

  // Computed
  const isLocked = computed(() => lockedUntil.value !== null && lockedUntil.value > new Date());

  const lockRemainingSeconds = computed(() => {
    if (!lockedUntil.value) return 0;
    return Math.max(0, Math.ceil((lockedUntil.value.getTime() - Date.now()) / 1000));
  });

  // Actions
  const checkPinConfigured = async (): Promise<boolean> => {
    const storedHash = localStorage.getItem(STORAGE_KEYS.PIN_HASH);
    hasPinConfigured.value = !!storedHash;
    return hasPinConfigured.value;
  };

  const validatePin = async (
    pin: string,
  ): Promise<{ success: boolean; error?: string; attemptsRemaining?: number }> => {
    // Check if locked
    if (isLocked.value) {
      return {
        success: false,
        error: `Cuenta bloqueada. Espera ${lockRemainingSeconds.value} segundos.`,
      };
    }

    // Check if PIN is configured
    const storedHash = localStorage.getItem(STORAGE_KEYS.PIN_HASH);
    if (!storedHash) {
      return { success: false, error: 'Debes configurar un PIN primero' };
    }

    // Validate PIN
    const inputHash = simpleHash(pin);
    if (inputHash === storedHash) {
      // Success - reset attempts
      pinAttempts.value = 0;
      localStorage.setItem(STORAGE_KEYS.PIN_ATTEMPTS, '0');
      localStorage.removeItem(STORAGE_KEYS.PIN_LOCKED_UNTIL);
      lockedUntil.value = null;
      return { success: true };
    }

    // Wrong PIN
    pinAttempts.value++;
    localStorage.setItem(STORAGE_KEYS.PIN_ATTEMPTS, pinAttempts.value.toString());

    const attemptsRemaining = MAX_ATTEMPTS - pinAttempts.value;

    if (attemptsRemaining <= 0) {
      // Lock the account
      const lockTime = new Date(Date.now() + LOCK_DURATION_MS);
      lockedUntil.value = lockTime;
      localStorage.setItem(STORAGE_KEYS.PIN_LOCKED_UNTIL, lockTime.toISOString());
      return {
        success: false,
        error: 'Demasiados intentos. Cuenta bloqueada por 5 minutos.',
        attemptsRemaining: 0,
      };
    }

    return {
      success: false,
      error: `PIN incorrecto. ${attemptsRemaining} intentos restantes.`,
      attemptsRemaining,
    };
  };

  const setupPin = async (
    newPin: string,
    currentPin?: string,
  ): Promise<{ success: boolean; error?: string }> => {
    // Validate PIN format
    if (newPin.length !== PIN_LENGTH || !/^\d+$/.test(newPin)) {
      return { success: false, error: `El PIN debe tener ${PIN_LENGTH} dígitos` };
    }

    // If changing PIN, verify current PIN first
    if (currentPin) {
      const storedHash = localStorage.getItem(STORAGE_KEYS.PIN_HASH);
      if (!storedHash) {
        return { success: false, error: 'No hay PIN configurado' };
      }
      const currentHash = simpleHash(currentPin);
      if (currentHash !== storedHash) {
        return { success: false, error: 'PIN actual incorrecto' };
      }
    }

    // Save new PIN
    const newHash = simpleHash(newPin);
    localStorage.setItem(STORAGE_KEYS.PIN_HASH, newHash);
    hasPinConfigured.value = true;

    logger.log('[CashControl] PIN configurado exitosamente');
    return { success: true };
  };

  // NOTE: openCash/closeCash methods were REMOVED per WO-007.
  // Cash session operations are handled by cashRegister.ts.
  // This store ONLY handles PIN validation and security.
  // The UI (CashControlView) should call verifyPin() first, 
  // then if successful, call cashRegisterStore.openRegister().

  const saveEvent = (event: CashControlEvent) => {
    const events = JSON.parse(localStorage.getItem(STORAGE_KEYS.CASH_EVENTS) || '[]');
    events.push(event);
    localStorage.setItem(STORAGE_KEYS.CASH_EVENTS, JSON.stringify(events));
  };

  const checkCashStatus = async (): Promise<void> => {
    isOpen.value = localStorage.getItem(STORAGE_KEYS.CASH_OPEN) === 'true';
    const storedBase = localStorage.getItem(STORAGE_KEYS.CASH_BASE);
    if (storedBase) {
      expectedCash.value = parseFloat(storedBase);
    }
  };

  const getExpectedCash = async (): Promise<number> => {
    // In a real app, this would sum: base + cash sales - payments
    // For now, just return the base + simulated sales
    const base = parseFloat(localStorage.getItem(STORAGE_KEYS.CASH_BASE) || '0');

    // TODO: Get actual cash sales from salesStore
    // const salesStore = useSalesStore();
    // const cashSales = salesStore.todayCashTotal;

    expectedCash.value = base;
    return base;
  };

  // Initialize on store creation
  init();

  return {
    // State
    isOpen,
    currentEvent,
    pinAttempts,
    lockedUntil,
    loading,
    hasPinConfigured,
    expectedCash,
    // Computed
    isLocked,
    lockRemainingSeconds,
    // Actions
    checkPinConfigured,
    validatePin,
    setupPin,
    // NOTE: openCash/closeCash REMOVED - use cashRegister.ts for operations
    checkCashStatus,
    getExpectedCash,
  };
});

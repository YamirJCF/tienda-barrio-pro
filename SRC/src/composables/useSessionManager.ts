/**
 * Session Manager Composable
 * WO-004 T4.5: Manages volatile sessions using sessionStorage
 * 
 * SPEC-005 R-02: Sessions are VOLATILE (sessionStorage)
 * - Lost on tab close (intentional security feature)
 * - Auto-logout after 30 min inactivity
 * 
 * @module composables/useSessionManager
 * @see SPEC-005: auth-unificada-iam.md Section 7
 */

import { ref, onMounted, onUnmounted } from 'vue';
import { logger } from '../utils/logger';

const SESSION_TOKEN_KEY = 'tienda-session-token';
const SESSION_EXPIRY_KEY = 'tienda-session-expiry';
const SESSION_TIMEOUT_MS = 30 * 60 * 1000; // 30 minutes

let activityTimer: ReturnType<typeof setTimeout> | null = null;

/**
 * Composable for managing volatile employee sessions
 */
export function useSessionManager() {
    const isSessionValid = ref(false);
    const remainingTime = ref(0);

    /**
     * Store session token in volatile storage (sessionStorage)
     * R-02: PIN is never exposed to frontend after login
     */
    const storeSession = (token: string): void => {
        const expiry = Date.now() + SESSION_TIMEOUT_MS;
        sessionStorage.setItem(SESSION_TOKEN_KEY, token);
        sessionStorage.setItem(SESSION_EXPIRY_KEY, expiry.toString());
        isSessionValid.value = true;
        resetActivityTimer();
        logger.log('[SessionManager] Session stored, expires at:', new Date(expiry).toISOString());
    };

    /**
     * Get current session token if still valid
     */
    const getSession = (): string | null => {
        const token = sessionStorage.getItem(SESSION_TOKEN_KEY);
        const expiryStr = sessionStorage.getItem(SESSION_EXPIRY_KEY);

        if (!token || !expiryStr) {
            isSessionValid.value = false;
            return null;
        }

        const expiry = parseInt(expiryStr, 10);
        if (Date.now() > expiry) {
            // Session expired
            clearSession();
            return null;
        }

        isSessionValid.value = true;
        remainingTime.value = Math.max(0, expiry - Date.now());
        return token;
    };

    /**
     * Clear session (logout)
     */
    const clearSession = (): void => {
        sessionStorage.removeItem(SESSION_TOKEN_KEY);
        sessionStorage.removeItem(SESSION_EXPIRY_KEY);
        isSessionValid.value = false;
        remainingTime.value = 0;
        if (activityTimer) {
            clearTimeout(activityTimer);
            activityTimer = null;
        }
        logger.log('[SessionManager] Session cleared');
    };

    /**
     * Reset the activity timer (extend session on user activity)
     */
    const resetActivityTimer = (): void => {
        if (activityTimer) {
            clearTimeout(activityTimer);
        }

        // Extend session expiry
        const newExpiry = Date.now() + SESSION_TIMEOUT_MS;
        sessionStorage.setItem(SESSION_EXPIRY_KEY, newExpiry.toString());
        remainingTime.value = SESSION_TIMEOUT_MS;

        activityTimer = setTimeout(() => {
            logger.log('[SessionManager] Session expired due to inactivity');
            clearSession();
            // Optionally trigger redirect to login
            window.dispatchEvent(new CustomEvent('session-expired'));
        }, SESSION_TIMEOUT_MS);
    };

    /**
     * Register activity listeners
     */
    const registerActivityListeners = (): void => {
        const events = ['mousedown', 'keydown', 'touchstart', 'scroll'];
        events.forEach(event => {
            window.addEventListener(event, resetActivityTimer, { passive: true });
        });
    };

    /**
     * Cleanup activity listeners
     */
    const unregisterActivityListeners = (): void => {
        const events = ['mousedown', 'keydown', 'touchstart', 'scroll'];
        events.forEach(event => {
            window.removeEventListener(event, resetActivityTimer);
        });
    };

    /**
     * Check if session exists on mount
     */
    const checkSession = (): boolean => {
        return getSession() !== null;
    };

    // Lifecycle hooks for automatic management
    onMounted(() => {
        if (checkSession()) {
            registerActivityListeners();
            resetActivityTimer();
        }
    });

    onUnmounted(() => {
        unregisterActivityListeners();
        if (activityTimer) {
            clearTimeout(activityTimer);
        }
    });

    return {
        isSessionValid,
        remainingTime,
        storeSession,
        getSession,
        clearSession,
        checkSession,
        resetActivityTimer,
        registerActivityListeners,
        unregisterActivityListeners,
    };
}

export default useSessionManager;

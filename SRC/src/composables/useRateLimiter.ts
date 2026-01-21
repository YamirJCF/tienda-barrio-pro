/**
 * Rate Limiter Composable
 * WO-004 T4.4: Frontend rate limiting for login attempts
 * 
 * Rules:
 * - 3 failed attempts → 30 second lockout
 * - Counter visible in UI
 * - Uses sessionStorage (cleared on tab close)
 * 
 * @module composables/useRateLimiter
 * @see SPEC-005: auth-unificada-iam.md Section 7
 */

import { ref, computed, onMounted } from 'vue';

const RATE_LIMIT_KEY = 'tienda-rate-limit';
const MAX_ATTEMPTS = 3;
const LOCKOUT_DURATION_MS = 30 * 1000; // 30 seconds

interface RateLimitState {
    attempts: number;
    lockedUntil: number | null;
}

/**
 * Composable for rate limiting login attempts
 */
export function useRateLimiter() {
    const attempts = ref(0);
    const lockedUntil = ref<number | null>(null);
    const remainingLockoutSeconds = ref(0);

    let countdownInterval: ReturnType<typeof setInterval> | null = null;

    /**
     * Check if currently locked out
     */
    const isLocked = computed(() => {
        if (!lockedUntil.value) return false;
        return Date.now() < lockedUntil.value;
    });

    /**
     * Remaining attempts before lockout
     */
    const remainingAttempts = computed(() => {
        return Math.max(0, MAX_ATTEMPTS - attempts.value);
    });

    /**
     * Load state from sessionStorage
     */
    const loadState = (): void => {
        const stored = sessionStorage.getItem(RATE_LIMIT_KEY);
        if (stored) {
            try {
                const state: RateLimitState = JSON.parse(stored);
                attempts.value = state.attempts;
                lockedUntil.value = state.lockedUntil;

                // Start countdown if still locked
                if (lockedUntil.value && Date.now() < lockedUntil.value) {
                    startCountdown();
                } else if (lockedUntil.value && Date.now() >= lockedUntil.value) {
                    // Lockout expired, reset
                    reset();
                }
            } catch {
                reset();
            }
        }
    };

    /**
     * Save state to sessionStorage
     */
    const saveState = (): void => {
        const state: RateLimitState = {
            attempts: attempts.value,
            lockedUntil: lockedUntil.value,
        };
        sessionStorage.setItem(RATE_LIMIT_KEY, JSON.stringify(state));
    };

    /**
     * Start countdown timer for lockout display
     */
    const startCountdown = (): void => {
        if (countdownInterval) {
            clearInterval(countdownInterval);
        }

        const updateRemaining = () => {
            if (!lockedUntil.value) {
                remainingLockoutSeconds.value = 0;
                return;
            }
            const remaining = Math.max(0, lockedUntil.value - Date.now());
            remainingLockoutSeconds.value = Math.ceil(remaining / 1000);

            if (remaining <= 0) {
                reset();
                if (countdownInterval) {
                    clearInterval(countdownInterval);
                    countdownInterval = null;
                }
            }
        };

        updateRemaining();
        countdownInterval = setInterval(updateRemaining, 1000);
    };

    /**
     * Record a failed login attempt
     * @returns true if now locked out
     */
    const recordFailedAttempt = (): boolean => {
        attempts.value++;

        if (attempts.value >= MAX_ATTEMPTS) {
            lockedUntil.value = Date.now() + LOCKOUT_DURATION_MS;
            saveState();
            startCountdown();
            return true;
        }

        saveState();
        return false;
    };

    /**
     * Check if can attempt login
     */
    const canAttempt = (): boolean => {
        if (!isLocked.value) return true;

        // Check if lockout expired
        if (lockedUntil.value && Date.now() >= lockedUntil.value) {
            reset();
            return true;
        }

        return false;
    };

    /**
     * Reset rate limiter (after successful login or lockout expiry)
     */
    const reset = (): void => {
        attempts.value = 0;
        lockedUntil.value = null;
        remainingLockoutSeconds.value = 0;
        sessionStorage.removeItem(RATE_LIMIT_KEY);
        if (countdownInterval) {
            clearInterval(countdownInterval);
            countdownInterval = null;
        }
    };

    /**
     * Record successful login (resets limiter)
     */
    const recordSuccess = (): void => {
        reset();
    };

    // Load state on mount
    onMounted(() => {
        loadState();
    });

    return {
        attempts,
        isLocked,
        remainingAttempts,
        remainingLockoutSeconds,
        maxAttempts: MAX_ATTEMPTS,
        lockoutDurationSeconds: LOCKOUT_DURATION_MS / 1000,
        canAttempt,
        recordFailedAttempt,
        recordSuccess,
        reset,
    };
}

export default useRateLimiter;

import { forceOffline } from '../data/supabaseClient';
import { localStorageAdapter } from '../data/repositories/localStorageAdapter';
import { logger } from './logger';

const AUDIT_MODE_KEY = 'app_audit_mode_enabled';

/**
 * Initialize Audit Mode state on app startup
 */
export const initAuditMode = () => {
    let isEnabled = localStorage.getItem(AUDIT_MODE_KEY) === 'true';

    // 🔓 FORCE DISABLE AUDIT MODE (User Request: Connect to DB)
    // We override any persisted state to ensure we connect to production DB
    if (isEnabled) {

        localStorage.setItem(AUDIT_MODE_KEY, 'false');
        isEnabled = false;
    }

    if (isEnabled) {
        logger.log('🕵️‍♀️ AUDIT MODE: ACTIVATED');
        forceOffline(true);
        localStorageAdapter.setPrefix('audit-');
        // Add visual indicator to body
        document.body.classList.add('audit-mode-active');
    } else {
        forceOffline(false);
        localStorageAdapter.setPrefix('');
        document.body.classList.remove('audit-mode-active');
    }
};

/**
 * Toggle Audit Mode and reload
 */
export const toggleAuditMode = (enable: boolean) => {
    localStorage.setItem(AUDIT_MODE_KEY, String(enable));
    window.location.reload();
};

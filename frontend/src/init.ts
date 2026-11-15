import { initAuditMode, toggleAuditMode } from './utils/audit';
import { logger } from './utils/logger';

// Initialize Audit Mode before app starts
initAuditMode();

// Expose Audit Controls globally for easy access
(window as any).Audit = {
    on: () => toggleAuditMode(true),
    off: () => toggleAuditMode(false),
    status: () => localStorage.getItem('app_audit_mode_enabled') === 'true' ? '🔒 AUDIT MODE ACTIVE' : '☁️ PRODUCTION MODE',
    help: () => {
        console.group('🛡️ Audit Mode Commands');
        logger.log('Audit.on()    -> Activate Simulator Mode');
        logger.log('Audit.off()   -> Deactivate / Return to Production');
        logger.log('Audit.status() -> Check current status');
        console.groupEnd();
    }
};

logger.log('🛡️ Audit Controls Loaded. Type "Audit.help()" for instructions.');

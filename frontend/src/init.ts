import { initAuditMode, toggleAuditMode } from './utils/audit';

// Initialize Audit Mode before app starts
initAuditMode();

// Expose Audit Controls globally for easy access
(window as any).Audit = {
    on: () => toggleAuditMode(true),
    off: () => toggleAuditMode(false),
    status: () => localStorage.getItem('app_audit_mode_enabled') === 'true' ? '🔒 AUDIT MODE ACTIVE' : '☁️ PRODUCTION MODE',
    help: () => {
        console.group('🛡️ Audit Mode Commands');
        console.log('Audit.on()    -> Activate Simulator Mode');
        console.log('Audit.off()   -> Deactivate / Return to Production');
        console.log('Audit.status() -> Check current status');
        console.groupEnd();
    }
};

if (import.meta.env.DEV) {
    console.log('🛡️ Audit Controls Loaded. Type "Audit.help()" for instructions.');
}

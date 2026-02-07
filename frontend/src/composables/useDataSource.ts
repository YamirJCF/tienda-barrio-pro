/**
 * useDataSource Composable
 * WO-002 T2.5: Manages data source selection and connection monitoring
 * 
 * Reads VITE_SUPABASE_ENABLED to toggle between:
 * - Supabase (online, multi-device sync)
 * - localStorage (offline, single-device)
 * 
 * @module composables/useDataSource
 * @see sync_protocol_spec.md
 */

import { ref, computed, onMounted, onUnmounted } from 'vue';
import { isSupabaseConfigured, checkSupabaseConnection, type DataSource } from '../data/supabaseClient';
import { logger } from '../utils/logger';

const currentSource = ref<DataSource>('localStorage');
const isOnline = ref(navigator.onLine);
const supabaseConnected = ref(false);
const lastConnectionCheck = ref<Date | null>(null);
const isChecking = ref(false);

// Connection check interval (30 seconds)
const CONNECTION_CHECK_INTERVAL = 30 * 1000;
let connectionCheckTimer: ReturnType<typeof setInterval> | null = null;

/**
 * Composable for managing data source
 */
export function useDataSource() {
    /**
     * Effective data source considering online state
     */
    const effectiveSource = computed<DataSource>(() => {
        if (!isOnline.value) return 'localStorage';
        if (!isSupabaseConfigured()) return 'localStorage';
        if (!supabaseConnected.value) return 'localStorage';
        return 'supabase';
    });

    /**
     * Human-readable status message
     */
    const statusMessage = computed(() => {
        if (!isOnline.value) return 'Sin conexión - Modo offline';
        if (!isSupabaseConfigured()) return 'Supabase no configurado - Modo local';
        if (!supabaseConnected.value) return 'Conectando a Supabase...';
        return 'Conectado - Sincronización activa';
    });

    /**
     * Status icon for UI
     */
    const statusIcon = computed(() => {
        if (!isOnline.value) return 'cloud_off';
        if (!supabaseConnected.value) return 'sync';
        return 'cloud_done';
    });

    /**
     * Status color for UI
     */
    const statusColor = computed(() => {
        if (!isOnline.value) return 'text-red-500';
        if (!supabaseConnected.value) return 'text-amber-500';
        return 'text-green-500';
    });

    /**
     * Check Supabase connection
     */
    const checkConnection = async (): Promise<boolean> => {
        if (!isOnline.value || !isSupabaseConfigured()) {
            supabaseConnected.value = false;
            currentSource.value = 'localStorage';
            return false;
        }

        isChecking.value = true;
        try {
            const connected = await checkSupabaseConnection();
            supabaseConnected.value = connected;
            currentSource.value = connected ? 'supabase' : 'localStorage';
            lastConnectionCheck.value = new Date();
            logger.log('[DataSource] Connection check:', connected ? 'connected' : 'disconnected');
            return connected;
        } catch (error) {
            supabaseConnected.value = false;
            currentSource.value = 'localStorage';
            return false;
        } finally {
            isChecking.value = false;
        }
    };

    /**
     * Handle online event
     */
    const handleOnline = async () => {
        console.log('🟢 [DataSource] Network came online - handleOnline fired!');
        logger.log('[DataSource] Network came online');
        isOnline.value = true;
        await checkConnection();

        // Trigger sync queue processing for offline transactions
        console.log('🔄 [DataSource] Importing and calling processSyncQueue...');
        const { processSyncQueue } = await import('../data/syncQueue');
        processSyncQueue(); // Fire and forget

        // Trigger sync event
        window.dispatchEvent(new CustomEvent('data-source-online'));
    };

    /**
     * Handle offline event
     */
    const handleOffline = () => {
        logger.log('[DataSource] Network went offline');
        isOnline.value = false;
        supabaseConnected.value = false;
        currentSource.value = 'localStorage';
        window.dispatchEvent(new CustomEvent('data-source-offline'));
    };

    /**
     * Start periodic connection checking
     */
    const startConnectionMonitoring = () => {
        if (connectionCheckTimer) return;

        // Initial check
        checkConnection();

        // Periodic checks
        connectionCheckTimer = setInterval(checkConnection, CONNECTION_CHECK_INTERVAL);
    };

    /**
     * Stop periodic connection checking
     */
    const stopConnectionMonitoring = () => {
        if (connectionCheckTimer) {
            clearInterval(connectionCheckTimer);
            connectionCheckTimer = null;
        }
    };

    // Setup event listeners on mount
    onMounted(() => {
        console.log('🎯 [DataSource] useDataSource composable MOUNTED - registering event listeners');
        isOnline.value = navigator.onLine;
        window.addEventListener('online', handleOnline);
        window.addEventListener('offline', handleOffline);
        console.log('✅ [DataSource] Event listeners registered. Current navigator.onLine:', navigator.onLine);
        startConnectionMonitoring();
    });

    // Cleanup on unmount
    onUnmounted(() => {
        window.removeEventListener('online', handleOnline);
        window.removeEventListener('offline', handleOffline);
        stopConnectionMonitoring();
    });

    return {
        // State
        currentSource,
        effectiveSource,
        isOnline,
        supabaseConnected,
        lastConnectionCheck,
        isChecking,

        // Computed
        statusMessage,
        statusIcon,
        statusColor,

        // Methods
        checkConnection,
        startConnectionMonitoring,
        stopConnectionMonitoring,
    };
}

export default useDataSource;

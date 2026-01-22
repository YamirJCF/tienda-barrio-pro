/**
 * Supabase Client
 * WO-002 T2.1: Centralized Supabase client configuration
 * 
 * Reads from environment variables:
 * - VITE_SUPABASE_URL
 * - VITE_SUPABASE_ANON_KEY
 * - VITE_SUPABASE_ENABLED (optional, defaults to false)
 * 
 * @module data/supabaseClient
 * @see SPEC: sync_protocol_spec.md
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { logger } from '../utils/logger';

// Environment variables
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string;
const supabaseEnabled = import.meta.env.VITE_SUPABASE_ENABLED === 'true';

// Singleton instance
let supabaseInstance: SupabaseClient | null = null;
let isForcedOffline = false; // Audit Mode Flag

/**
 * Force offline mode (Audit Mode)
 * @param value - true to force offline, false to resume normal operation
 */
export const forceOffline = (value: boolean): void => {
    isForcedOffline = value;
    if (value) {
        logger.log('[Supabase] Forced OFFLINE (Audit Mode)');
    } else {
        logger.log('[Supabase] Resumed ONLINE mode');
    }
};

export const isAuditMode = (): boolean => isForcedOffline;

/**
 * Check if Supabase is properly configured
 */
/**
 * Check if Supabase is properly configured
 */
export const isSupabaseConfigured = (): boolean => {
    if (isForcedOffline) return false;
    return Boolean(supabaseUrl && supabaseAnonKey && supabaseEnabled);
};

/**
 * Get the Supabase client instance
 * Creates the client lazily on first call
 * 
 * @returns SupabaseClient or null if not configured
 */
export const getSupabaseClient = (): SupabaseClient | null => {
    if (isForcedOffline) {
        return null;
    }

    if (!isSupabaseConfigured()) {
        logger.log('[Supabase] Not configured - using localStorage fallback');
        return null;
    }

    if (!supabaseInstance) {
        try {
            supabaseInstance = createClient(supabaseUrl, supabaseAnonKey, {
                auth: {
                    persistSession: false, // WO-004 T4.5: Sessions are volatile
                    autoRefreshToken: true,
                    detectSessionInUrl: false,
                },
                realtime: {
                    params: {
                        eventsPerSecond: 10,
                    },
                },
            });
            logger.log('[Supabase] Client initialized successfully');
        } catch (error) {
            console.error('[Supabase] Failed to initialize client:', error);
            return null;
        }
    }

    return supabaseInstance;
};

/**
 * Get the Supabase client or throw if not available
 * Use this when Supabase is required
 * 
 * @throws Error if Supabase is not configured
 */
export const requireSupabase = (): SupabaseClient => {
    const client = getSupabaseClient();
    if (!client) {
        throw new Error('Supabase is required but not configured');
    }
    return client;
};

/**
 * Check connection status
 * Useful for determining online/offline state
 */
export const checkSupabaseConnection = async (): Promise<boolean> => {
    const client = getSupabaseClient();
    if (!client) return false;

    try {
        // Simple health check via a lightweight query
        const { error } = await client.from('stores').select('id').limit(1);
        return !error;
    } catch {
        return false;
    }
};

/**
 * Data source enum for typing
 */
export type DataSource = 'supabase' | 'localStorage';

/**
 * Get current active data source
 */
export const getActiveDataSource = (): DataSource => {
    return isSupabaseConfigured() ? 'supabase' : 'localStorage';
};

export default getSupabaseClient;

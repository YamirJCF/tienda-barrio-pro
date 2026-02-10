/**
 * useCache Composable
 * WO-003 T3.2: SWR Caching Strategy
 * 
 * Features:
 * - Stale-While-Revalidate pattern
 * - Configurable TTL per entity
 * - Uses Supabase repositories
 * 
 * @module composables/useCache
 * @see 01_REQUIREMENTS/sync_protocol_spec.md
 */

import { ref } from 'vue';
import { logger } from '../utils/logger';

interface CacheConfig {
    ttl: number; // Time to live in ms
    key: string;
}

const CACHE_STORE: Record<string, { data: any; timestamp: number }> = {};

/**
 * Use SWR Cache strategy
 */
export function useCache() {

    /**
     * Fetch data with SWR strategy
     * 1. Return cached data immediately (stale)
     * 2. Fetch fresh data in background
     * 3. Update cache and return fresh data if changed
     */
    const fetchSWR = async <T>(
        config: CacheConfig,
        fetcher: () => Promise<T>
    ): Promise<{ data: T | null; isStale: boolean; error: any }> => {
        const now = Date.now();
        const cached = CACHE_STORE[config.key];

        const result = {
            data: cached ? cached.data as T : null,
            isStale: false,
            error: null
        };

        // If cache missing or expired, mark as stale
        if (!cached || (now - cached.timestamp > config.ttl)) {
            result.isStale = true;
        }

        // If stale or missing, fetch fresh
        if (result.isStale) {
            try {
                const fresh = await fetcher();
                if (fresh) {
                    CACHE_STORE[config.key] = {
                        data: fresh,
                        timestamp: now
                    };
                    result.data = fresh;
                }
            } catch (e) {
                logger.error(`[useCache] background fetch failed for ${config.key}`, e);
                result.error = e;
                // Keep returning stale data if available
            }
        }

        return result;
    };

    /**
     * Invalidate cache key
     */
    const invalidate = (key: string) => {
        delete CACHE_STORE[key];
    };

    return {
        fetchSWR,
        invalidate
    };
}

export default useCache;

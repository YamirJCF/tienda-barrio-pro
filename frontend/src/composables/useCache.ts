/**
 * useCache Composable v2.0
 * Conforme con SDD-028 v2.0.0
 * 
 * Envoltorio ergonómico de Vue para SystemCacheManager:
 * - Stale-While-Revalidate pattern (SWR)
 * - Deduplicación de promesas en vuelo
 * - Generación reactiva anti-carreras
 * - TTL por niveles de datos
 * - Acotamiento LRU
 * 
 * @module composables/useCache
 */

import {
  systemCacheManager,
  SystemCacheManager,
  CacheLevel,
  CACHE_TTL_CONFIG,
  type CacheEntry,
  type FetchSWROptions,
  type SWRResult,
} from '../services/systemCacheManager';

export {
  systemCacheManager,
  SystemCacheManager,
  CacheLevel,
  CACHE_TTL_CONFIG,
  type CacheEntry,
  type FetchSWROptions,
  type SWRResult,
};

export interface LegacyCacheConfig {
  key: string;
  ttl?: number;
  level?: CacheLevel;
  namespace?: string;
  forceFresh?: boolean;
}

export function useCache() {
  /**
   * fetchSWR sobrecargado: soporta firma clásica { key, ttl } o firma limpia (key, fetcher, options)
   */
  async function fetchSWR<T>(
    keyOrConfig: string | LegacyCacheConfig,
    fetcher: () => Promise<T>,
    options?: FetchSWROptions
  ): Promise<SWRResult<T>> {
    let key: string;
    let opts: FetchSWROptions = options || {};

    if (typeof keyOrConfig === 'string') {
      key = keyOrConfig;
    } else {
      key = keyOrConfig.key;
      opts = {
        ttl: keyOrConfig.ttl,
        level: keyOrConfig.level,
        namespace: keyOrConfig.namespace,
        forceFresh: keyOrConfig.forceFresh,
        ...options,
      };
    }

    return systemCacheManager.fetchSWR<T>(key, fetcher, opts);
  }

  const invalidate = (key: string) => {
    systemCacheManager.invalidate(key);
  };

  const invalidateNamespace = (namespace: string) => {
    systemCacheManager.invalidateNamespace(namespace);
  };

  const invalidateAll = () => {
    systemCacheManager.invalidateAll();
  };

  const get = <T>(key: string): T | null => {
    return systemCacheManager.get<T>(key);
  };

  const set = <T>(
    key: string,
    data: T,
    options?: { level?: CacheLevel; namespace?: string }
  ) => {
    return systemCacheManager.set<T>(key, data, options);
  };

  const coldStart = <T>(
    key: string,
    data: T,
    level?: CacheLevel,
    namespace?: string
  ) => {
    systemCacheManager.coldStart<T>(key, data, level, namespace);
  };

  const markStale = (key: string) => {
    systemCacheManager.markStale(key);
  };

  const subscribe = <T>(
    keyOrNamespace: string,
    callback: (data: T, key: string) => void
  ) => {
    return systemCacheManager.subscribe<T>(keyOrNamespace, callback);
  };

  return {
    fetchSWR,
    invalidate,
    invalidateNamespace,
    invalidateAll,
    get,
    set,
    coldStart,
    markStale,
    subscribe,
    manager: systemCacheManager,
  };
}

export default useCache;

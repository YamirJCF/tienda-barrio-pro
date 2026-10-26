/**
 * SystemCacheManager - Gestor Centralizado de Caché Operacional en RAM
 * 
 * Cumple con SDD-028 v2.0.0 (§4.5, §4.6, §4.7):
 * - Singleton SWR en memoria volátil (RAM)
 * - TTLs estratificados por nivel (Nivel 1 al 5)
 * - Deduplicación de promesas en vuelo (in-flight deduplication)
 * - Contadores de generación contra carreras de invalidación (race conditions)
 * - Acotamiento LRU (máx 10 entradas por namespace de consultas)
 * - Resiliencia ante desconexión (>5s marca stale) y reconexión (invalidateAll)
 * - Política de arranque en frío (coldStart con timestamp = 0)
 * 
 * @module services/systemCacheManager
 */

import { logger } from '../utils/logger';

export enum CacheLevel {
  LEVEL_1_STATIC = 'LEVEL_1_STATIC',             // 60 min TTL, max stale 24h (Cache-First)
  LEVEL_2_CATALOG = 'LEVEL_2_CATALOG',           // 5 min TTL, max stale 30 min (SWR)
  LEVEL_3_FINANCIAL = 'LEVEL_3_FINANCIAL',       // 30 sec TTL, max stale 2 min (SWR Corto)
  LEVEL_4_TRANSACTIONAL = 'LEVEL_4_TRANSACTIONAL',// 0s TTL (Network-Only)
  LEVEL_5_QUERIES = 'LEVEL_5_QUERIES',           // 2 min TTL, max stale 10 min (LRU Bounded)
}

export interface CacheTTLConfig {
  ttl: number;       // Tiempo de vigencia fresca en ms
  maxStale: number;  // Tiempo máximo que se tolera servir stale mientras revalida en ms
}

export const CACHE_TTL_CONFIG: Record<CacheLevel, CacheTTLConfig> = {
  [CacheLevel.LEVEL_1_STATIC]: {
    ttl: 60 * 60 * 1000,          // 60 min
    maxStale: 24 * 60 * 60 * 1000, // 24 horas
  },
  [CacheLevel.LEVEL_2_CATALOG]: {
    ttl: 5 * 60 * 1000,           // 5 min
    maxStale: 30 * 60 * 1000,      // 30 min
  },
  [CacheLevel.LEVEL_3_FINANCIAL]: {
    ttl: 30 * 1000,               // 30 segundos
    maxStale: 2 * 60 * 1000,       // 2 min
  },
  [CacheLevel.LEVEL_4_TRANSACTIONAL]: {
    ttl: 0,
    maxStale: 0,
  },
  [CacheLevel.LEVEL_5_QUERIES]: {
    ttl: 2 * 60 * 1000,           // 2 min
    maxStale: 10 * 60 * 1000,      // 10 min
  },
};

export interface CacheEntry<T = any> {
  key: string;
  namespace: string;
  data: T;
  timestamp: number;         // Date.now() de captura (o 0 en arranque en frío)
  generation: number;        // Versión de la clave para evitar carreras
  lastAccessed: number;      // Timestamp de último acceso para política LRU
  level: CacheLevel;
  isStale: boolean;
}

export interface FetchSWROptions {
  level?: CacheLevel;
  namespace?: string;
  ttl?: number;              // Sobrescritura personalizada de TTL (opcional)
  maxStale?: number;         // Sobrescritura personalizada de maxStale (opcional)
  forceFresh?: boolean;      // Forzar llamada a red ignorando caché actual
}

export interface SWRResult<T> {
  data: T | null;
  isStale: boolean;
  error: any;
  fromCache: boolean;
}

type CacheSubscriber<T = any> = (data: T, key: string) => void;

export class SystemCacheManager {
  private static instance: SystemCacheManager | null = null;

  private store: Map<string, CacheEntry> = new Map();
  private inFlightPromises: Map<string, Promise<any>> = new Map();
  private keyGenerations: Map<string, number> = new Map();
  private namespaceIndex: Map<string, Set<string>> = new Map();
  private subscribers: Map<string, Set<CacheSubscriber>> = new Map();

  private disconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private isOnlineState: boolean = typeof navigator !== 'undefined' ? navigator.onLine : true;
  private accessCounter: number = 0;

  private readonly LRU_MAX_ENTRIES_PER_NAMESPACE = 10;

  private constructor() {
    this.setupNetworkListeners();
  }

  public static getInstance(): SystemCacheManager {
    if (!SystemCacheManager.instance) {
      SystemCacheManager.instance = new SystemCacheManager();
    }
    return SystemCacheManager.instance;
  }

  /**
   * Configura listeners de red para invalidación y marcado de stale (RN-CACHE-06)
   */
  private setupNetworkListeners(): void {
    if (typeof window === 'undefined') return;

    window.addEventListener('offline', () => {
      this.isOnlineState = false;
      // RN-CACHE-06: Desconexión superior a 5 segundos marca Level 2 y Level 3 como stale
      if (this.disconnectTimer) clearTimeout(this.disconnectTimer);
      this.disconnectTimer = setTimeout(() => {
        logger.warn('[SystemCacheManager] Conexión caída > 5s: Marcando Nivel 2 y 3 como stale');
        this.markVolatileLevelsAsStale();
      }, 5000);
    });

    window.addEventListener('online', () => {
      this.isOnlineState = true;
      if (this.disconnectTimer) {
        clearTimeout(this.disconnectTimer);
        this.disconnectTimer = null;
      }
      logger.log('[SystemCacheManager] Conexión restaurada: Disparando invalidación global para revalidar');
      this.invalidateAll();
    });
  }

  /**
   * Marca todas las entradas de Nivel 2 y Nivel 3 como obsoletas (isStale = true)
   */
  public markVolatileLevelsAsStale(): void {
    for (const entry of this.store.values()) {
      if (
        entry.level === CacheLevel.LEVEL_2_CATALOG ||
        entry.level === CacheLevel.LEVEL_3_FINANCIAL
      ) {
        entry.isStale = true;
      }
    }
  }

  /**
   * Obtiene la generación activa para una clave
   */
  public getGeneration(key: string): number {
    return this.keyGenerations.get(key) || 0;
  }

  /**
   * Incrementa la generación de una clave (invalida cualquier promesa en vuelo)
   */
  private bumpGeneration(key: string): number {
    const nextGen = (this.keyGenerations.get(key) || 0) + 1;
    this.keyGenerations.set(key, nextGen);
    return nextGen;
  }

  /**
   * Registra una clave dentro de un namespace para control de ciclo de vida
   */
  private registerNamespace(namespace: string, key: string): void {
    if (!this.namespaceIndex.has(namespace)) {
      this.namespaceIndex.set(namespace, new Set());
    }
    this.namespaceIndex.get(namespace)!.add(key);
  }

  /**
   * Aplica expulsión LRU si el namespace excede el límite máximo (10 entradas)
   */
  private applyLRU(namespace: string): void {
    const keys = this.namespaceIndex.get(namespace);
    if (!keys || keys.size <= this.LRU_MAX_ENTRIES_PER_NAMESPACE) return;

    let oldestKey: string | null = null;
    let oldestCounter = Infinity;

    for (const key of keys) {
      const entry = this.store.get(key);
      if (entry && entry.lastAccessed < oldestCounter) {
        oldestCounter = entry.lastAccessed;
        oldestKey = key;
      }
    }

    if (oldestKey) {
      logger.log(`[SystemCacheManager] LRU Eviction: Desalojando ${oldestKey} de namespace ${namespace}`);
      this.store.delete(oldestKey);
      keys.delete(oldestKey);
    }
  }

  /**
   * Obtiene directamente el dato almacenado en memoria si existe
   */
  public get<T>(key: string): T | null {
    const entry = this.store.get(key);
    if (!entry) return null;
    entry.lastAccessed = ++this.accessCounter;
    return entry.data as T;
  }

  /**
   * Almacena explícitamente un dato en memoria
   */
  public set<T>(
    key: string,
    data: T,
    options: {
      level?: CacheLevel;
      namespace?: string;
      timestamp?: number;
      isStale?: boolean;
    } = {}
  ): CacheEntry<T> {
    const level = options.level || CacheLevel.LEVEL_2_CATALOG;
    const namespace = options.namespace || 'global';
    const timestamp = options.timestamp !== undefined ? options.timestamp : Date.now();
    const isStale = options.isStale || false;
    const currentGen = this.getGeneration(key);

    const entry: CacheEntry<T> = {
      key,
      namespace,
      data,
      timestamp,
      generation: currentGen,
      lastAccessed: ++this.accessCounter,
      level,
      isStale,
    };

    this.store.set(key, entry);
    this.registerNamespace(namespace, key);

    if (level === CacheLevel.LEVEL_5_QUERIES) {
      this.applyLRU(namespace);
    }

    // Notificar a los suscriptores si los hay
    this.notifySubscribers(key, data);

    return entry;
  }

  /**
   * Registra dato en arranque en frío (Cold Start - RN-CACHE-07)
   * lastFetchedAt = 0 garantiza que la UI pinte de inmediato y revalide de fondo
   */
  public coldStart<T>(key: string, data: T, level: CacheLevel = CacheLevel.LEVEL_2_CATALOG, namespace?: string): void {
    this.set(key, data, {
      level,
      namespace,
      timestamp: 0,
      isStale: true,
    });
  }

  /**
   * Invalidación de una clave puntual
   */
  public invalidate(key: string): void {
    this.bumpGeneration(key);
    const entry = this.store.get(key);
    if (entry) {
      const nsKeys = this.namespaceIndex.get(entry.namespace);
      if (nsKeys) nsKeys.delete(key);
    }
    this.store.delete(key);
  }

  /**
   * Invalidación de todas las claves pertenecientes a un namespace
   */
  public invalidateNamespace(namespace: string): void {
    const keys = this.namespaceIndex.get(namespace);
    if (!keys) return;

    for (const key of keys) {
      this.bumpGeneration(key);
      this.store.delete(key);
    }
    keys.clear();
  }

  /**
   * Invalidación global de todo el caché en RAM
   */
  public invalidateAll(): void {
    for (const key of this.store.keys()) {
      this.bumpGeneration(key);
    }
    this.store.clear();
    this.namespaceIndex.clear();
  }

  /**
   * Marca una clave como obsoleta para forzar revalidación de fondo en el próximo acceso
   */
  public markStale(key: string): void {
    const entry = this.store.get(key);
    if (entry) {
      entry.isStale = true;
    }
  }

  /**
   * Suscribe un callback ante actualizaciones de fondo de una clave o namespace
   */
  public subscribe<T>(keyOrNamespace: string, callback: CacheSubscriber<T>): () => void {
    if (!this.subscribers.has(keyOrNamespace)) {
      this.subscribers.set(keyOrNamespace, new Set());
    }
    this.subscribers.get(keyOrNamespace)!.add(callback);

    return () => {
      const subs = this.subscribers.get(keyOrNamespace);
      if (subs) {
        subs.delete(callback);
        if (subs.size === 0) this.subscribers.delete(keyOrNamespace);
      }
    };
  }

  private notifySubscribers(key: string, data: any): void {
    // 1. Notificar por clave directa
    const directSubs = this.subscribers.get(key);
    if (directSubs) {
      directSubs.forEach((cb) => {
        try {
          cb(data, key);
        } catch (e) {
          logger.error(`[SystemCacheManager] Error en suscriptor de clave ${key}:`, e);
        }
      });
    }

    // 2. Notificar por namespace
    const entry = this.store.get(key);
    if (entry && entry.namespace) {
      const nsSubs = this.subscribers.get(entry.namespace);
      if (nsSubs) {
        nsSubs.forEach((cb) => {
          try {
            cb(data, key);
          } catch (e) {
            logger.error(`[SystemCacheManager] Error en suscriptor de namespace ${entry.namespace}:`, e);
          }
        });
      }
    }
  }

  /**
   * Obtiene la promesa en vuelo si existe para una clave (útil para coordinar flujos o tests)
   */
  public getInFlightPromise<T = any>(key: string): Promise<T> | undefined {
    return this.inFlightPromises.get(key);
  }

  /**
   * fetchSWR - Motor principal Stale-While-Revalidate
   * 
   * Flujo garantizado:
   * 1. Nivel 4 Transaccional -> Network Only absoluto (cero caché).
   * 2. Si hay dato en RAM y está fresco -> Retorna de inmediato (0ms, isStale: false).
   * 3. Si hay dato en RAM y es Cold Start (timestamp = 0) o stale dentro de maxStale ->
   *    Retorna stale de inmediato (0ms) y dispara fetch de fondo deduplicado con chequeo de generación.
   * 4. Si es cache miss -> Espera la promesa deduplicada y retorna dato fresco.
   */
  public async fetchSWR<T>(
    key: string,
    fetcher: () => Promise<T>,
    options: FetchSWROptions = {}
  ): Promise<SWRResult<T>> {
    const level = options.level || CacheLevel.LEVEL_2_CATALOG;
    const namespace = options.namespace || 'global';
    const config = CACHE_TTL_CONFIG[level];
    const ttl = options.ttl !== undefined ? options.ttl : config.ttl;
    const maxStale = options.maxStale !== undefined ? options.maxStale : config.maxStale;

    // 1. Nivel 4 (Transaccional): Red pura sin caché
    if (level === CacheLevel.LEVEL_4_TRANSACTIONAL) {
      try {
        const fresh = await fetcher();
        return { data: fresh, isStale: false, error: null, fromCache: false };
      } catch (err) {
        return { data: null, isStale: false, error: err, fromCache: false };
      }
    }

    const now = Date.now();
    const entry = this.store.get(key) as CacheEntry<T> | undefined;
    const currentGen = this.getGeneration(key);

    const isAvailable = Boolean(entry && entry.generation === currentGen);
    const isColdStart = Boolean(isAvailable && entry!.timestamp === 0);
    const age = isAvailable ? (isColdStart ? Infinity : now - entry!.timestamp) : Infinity;
    const isFresh = isAvailable && !isColdStart && !entry!.isStale && age <= ttl && !options.forceFresh;
    const canServeStale = isColdStart || (isAvailable && age <= ttl + maxStale && !options.forceFresh);

    // 2. Dato fresco en memoria -> Retorno instantáneo
    if (isFresh && entry) {
      entry.lastAccessed = ++this.accessCounter;
      return {
        data: entry.data,
        isStale: false,
        error: null,
        fromCache: true,
      };
    }

    // 3. Crear o unirse a la promesa en vuelo (Deduplicación)
    const runBackgroundFetch = (): Promise<T> => {
      if (this.inFlightPromises.has(key)) {
        logger.log(`[SystemCacheManager] Deduplicando petición en vuelo para: ${key}`);
        return this.inFlightPromises.get(key)!;
      }

      const fetchGen = currentGen;
      const fetchPromise = (async () => {
        try {
          const freshData = await fetcher();
          // Control contra carreras de invalidación (RN-CACHE-05.3):
          // Solo actualizamos el caché si la generación no cambió mientras la petición viajaba
          if (this.getGeneration(key) === fetchGen) {
            this.set(key, freshData, { level, namespace });
          } else {
            logger.warn(
              `[SystemCacheManager] Descartando respuesta de red para ${key}: Generación desfasada (${fetchGen} vs ${this.getGeneration(key)})`
            );
          }
          return freshData;
        } finally {
          this.inFlightPromises.delete(key);
        }
      })();

      this.inFlightPromises.set(key, fetchPromise);
      return fetchPromise;
    };

    // 4. Si tenemos dato en memoria apto para Stale -> Devolverlo ya y revalidar en segundo plano
    if (canServeStale && entry) {
      entry.lastAccessed = ++this.accessCounter;
      // Disparar en background silenciosamente
      runBackgroundFetch().catch((e) => {
        logger.warn(`[SystemCacheManager] Error en revalidación background para ${key}:`, e);
      });

      return {
        data: entry.data,
        isStale: true,
        error: null,
        fromCache: true,
      };
    }

    // 5. Cache Miss o dato demasiado viejo: Esperar la promesa en vuelo
    try {
      const freshData = await runBackgroundFetch();
      return {
        data: freshData,
        isStale: false,
        error: null,
        fromCache: false,
      };
    } catch (err) {
      logger.error(`[SystemCacheManager] Error crítico en fetch para ${key}:`, err);
      // Si existía un dato previo en caché aunque expirado, se retorna como último recurso defensivo
      if (entry) {
        return {
          data: entry.data,
          isStale: true,
          error: err,
          fromCache: true,
        };
      }
      return {
        data: null,
        isStale: false,
        error: err,
        fromCache: false,
      };
    }
  }

  /**
   * Limpia toda la memoria (útil en pruebas)
   */
  public reset(): void {
    if (this.disconnectTimer) {
      clearTimeout(this.disconnectTimer);
      this.disconnectTimer = null;
    }
    this.store.clear();
    this.inFlightPromises.clear();
    this.keyGenerations.clear();
    this.namespaceIndex.clear();
    this.subscribers.clear();
  }
}

export const systemCacheManager = SystemCacheManager.getInstance();

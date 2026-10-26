import { describe, it, expect, beforeEach, vi } from 'vitest';
import {
  systemCacheManager,
  CacheLevel,
  CACHE_TTL_CONFIG,
} from '../../services/systemCacheManager';

describe('SystemCacheManager - SDD-028 v2.0.0 Unit Tests', () => {
  beforeEach(() => {
    systemCacheManager.reset();
    vi.restoreAllMocks();
  });

  describe('Deduplicación de Peticiones en Vuelo (In-Flight Deduplication)', () => {
    it('debe compartir la misma promesa y llamar al fetcher exactamente UNA vez si se invocan concurrentemente', async () => {
      let callCount = 0;
      const delayedFetcher = vi.fn(async () => {
        callCount++;
        await new Promise((resolve) => setTimeout(resolve, 50));
        return [{ id: 'p1', name: 'Arroz' }];
      });

      // Tres llamadas simultáneas a la misma clave
      const [res1, res2, res3] = await Promise.all([
        systemCacheManager.fetchSWR('products:all', delayedFetcher, {
          level: CacheLevel.LEVEL_2_CATALOG,
        }),
        systemCacheManager.fetchSWR('products:all', delayedFetcher, {
          level: CacheLevel.LEVEL_2_CATALOG,
        }),
        systemCacheManager.fetchSWR('products:all', delayedFetcher, {
          level: CacheLevel.LEVEL_2_CATALOG,
        }),
      ]);

      expect(callCount).toBe(1);
      expect(delayedFetcher).toHaveBeenCalledTimes(1);
      expect(res1.data).toEqual([{ id: 'p1', name: 'Arroz' }]);
      expect(res2.data).toEqual([{ id: 'p1', name: 'Arroz' }]);
      expect(res3.data).toEqual([{ id: 'p1', name: 'Arroz' }]);
    });
  });

  describe('Gobernanza SWR y Frescura de Datos', () => {
    it('debe retornar dato de caché instantáneamente (0ms, isStale: false) si está dentro del TTL', async () => {
      const fetcher = vi.fn().mockResolvedValue(['Cliente A']);

      // 1. Primer fetch (Cache Miss)
      const first = await systemCacheManager.fetchSWR('clients:store1', fetcher, {
        level: CacheLevel.LEVEL_2_CATALOG,
      });
      expect(first.fromCache).toBe(false);
      expect(fetcher).toHaveBeenCalledTimes(1);

      // 2. Segundo fetch inmediato (Dato fresco en RAM)
      const second = await systemCacheManager.fetchSWR('clients:store1', fetcher, {
        level: CacheLevel.LEVEL_2_CATALOG,
      });
      expect(second.fromCache).toBe(true);
      expect(second.isStale).toBe(false);
      expect(second.data).toEqual(['Cliente A']);
      expect(fetcher).toHaveBeenCalledTimes(1); // No vuelve a llamar al fetcher
    });

    it('debe retornar dato stale de inmediato y revalidar en background si excedió el TTL pero está dentro de maxStale', async () => {
      let callCount = 0;
      const fetcher = vi.fn(async () => {
        callCount++;
        return `Version_${callCount}`;
      });

      // Insertar con timestamp de hace 6 minutos (TTL de catálogo es 5m, maxStale es 30m)
      const sixMinutesAgo = Date.now() - 6 * 60 * 1000;
      systemCacheManager.set('products:list', 'Version_0', {
        level: CacheLevel.LEVEL_2_CATALOG,
        timestamp: sixMinutesAgo,
      });

      // Llamar fetchSWR
      const res = await systemCacheManager.fetchSWR('products:list', fetcher, {
        level: CacheLevel.LEVEL_2_CATALOG,
      });

      // Retorna stale de inmediato (0ms)
      expect(res.fromCache).toBe(true);
      expect(res.isStale).toBe(true);
      expect(res.data).toBe('Version_0');

      // Esperar la promesa en vuelo que corre en background
      const bgPromise = systemCacheManager.getInFlightPromise('products:list');
      if (bgPromise) await bgPromise;

      expect(fetcher).toHaveBeenCalledTimes(1);
      // Tras el background fetch, el dato en caché se actualizó a Version_1
      expect(systemCacheManager.get('products:list')).toBe('Version_1');
    });

    it('Nivel 4 Transaccional debe ejecutar Network-Only ignorando cualquier dato en memoria', async () => {
      const fetcher = vi.fn().mockResolvedValue({ balance: 50000 });
      systemCacheManager.set('cash:session:1', { balance: 10000 }, {
        level: CacheLevel.LEVEL_4_TRANSACTIONAL,
      });

      const res = await systemCacheManager.fetchSWR('cash:session:1', fetcher, {
        level: CacheLevel.LEVEL_4_TRANSACTIONAL,
      });

      expect(res.fromCache).toBe(false);
      expect(res.data).toEqual({ balance: 50000 });
      expect(fetcher).toHaveBeenCalledTimes(1);
    });
  });

  describe('Contadores de Generación y Protección Anti-Carreras', () => {
    it('debe descartar la respuesta de red si la clave fue invalidada mientras la petición viajaba', async () => {
      let resolvePromise: (val: any) => void;
      const slowFetcher = vi.fn(
        () =>
          new Promise((resolve) => {
            resolvePromise = resolve;
          })
      );

      // Iniciar fetch de fondo
      const promise = systemCacheManager.fetchSWR('product:123', slowFetcher, {
        level: CacheLevel.LEVEL_2_CATALOG,
      });

      // En medio del viaje, se emite una invalidación de la clave (ej. evento Realtime o mutación)
      systemCacheManager.invalidate('product:123');

      // Ahora la promesa de red se resuelve con datos viejos
      resolvePromise!({ id: '123', name: 'Viejo' });
      await promise;

      // El resultado no debe guardarse en el caché porque su generación fue desfasada
      expect(systemCacheManager.get('product:123')).toBeNull();
    });
  });

  describe('Acotamiento LRU (Máximo 10 entradas por namespace de consultas)', () => {
    it('debe desalojar la clave consultada hace más tiempo al superar 10 entradas en Nivel 5', async () => {
      const namespace = 'reports:kardex';

      // Insertar 10 entradas
      for (let i = 1; i <= 10; i++) {
        systemCacheManager.set(`kardex:p${i}`, { id: `p${i}` }, {
          level: CacheLevel.LEVEL_5_QUERIES,
          namespace,
        });
      }

      // Acceder a kardex:p1 para que no sea el más antiguo
      systemCacheManager.get('kardex:p1');

      // Insertar la entrada número 11
      systemCacheManager.set('kardex:p11', { id: 'p11' }, {
        level: CacheLevel.LEVEL_5_QUERIES,
        namespace,
      });

      // p1 debe seguir existiendo (fue accedido recientemente)
      expect(systemCacheManager.get('kardex:p1')).not.toBeNull();
      // p11 debe existir
      expect(systemCacheManager.get('kardex:p11')).not.toBeNull();
      // p2 (el que no fue accedido) debió ser desalojado por LRU
      expect(systemCacheManager.get('kardex:p2')).toBeNull();
    });
  });

  describe('Arranque en Frío (Cold Start - RN-CACHE-07)', () => {
    it('coldStart debe fijar timestamp = 0 y permitir retorno stale inmediato revalidando de fondo', async () => {
      const fetcher = vi.fn().mockResolvedValue([{ id: 'p1', name: 'Fresco de BD' }]);

      // Hidratación desde persistencia local (F5)
      systemCacheManager.coldStart('products:catalog', [{ id: 'p1', name: 'Persistido Local' }]);

      const res = await systemCacheManager.fetchSWR('products:catalog', fetcher, {
        level: CacheLevel.LEVEL_2_CATALOG,
      });

      // Debe pintar el dato persistido de inmediato en la UI
      expect(res.fromCache).toBe(true);
      expect(res.isStale).toBe(true);
      expect(res.data).toEqual([{ id: 'p1', name: 'Persistido Local' }]);

      // Esperar revalidación background
      const bgPromise = systemCacheManager.getInFlightPromise('products:catalog');
      if (bgPromise) await bgPromise;

      expect(fetcher).toHaveBeenCalledTimes(1);
      expect(systemCacheManager.get('products:catalog')).toEqual([{ id: 'p1', name: 'Fresco de BD' }]);
    });
  });
});

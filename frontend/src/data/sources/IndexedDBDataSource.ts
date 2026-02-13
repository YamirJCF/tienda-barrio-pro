/**
 * IndexedDB Data Source
 * Cache-Ahead Repository Pattern — Phase 2
 * 
 * High-performance local storage engine using IndexedDB via the `idb` library.
 * Replaces localStorage for large datasets (products, sales) to avoid:
 * - Main thread blocking (JSON.parse on 5MB+ data)
 * - 5MB storage limit crashes
 * 
 * Features:
 * - Async (Promise-based) — never blocks UI
 * - Indexed lookups (PLU, category) — O(1) instead of O(n)
 * - Bulk save with single transaction — fast hydration
 * - Automatic Decimal serialization/deserialization
 * 
 * @module data/sources/IndexedDBDataSource
 */

import { openDB, IDBPDatabase, DBSchema } from 'idb';
import { Decimal } from 'decimal.js';
import type { LocalDataSource } from '../interfaces/DataSource';
import { logger } from '../../utils/logger';

// ============================================
// DATABASE SCHEMA
// ============================================

const DB_NAME = 'tienda-cache-db';
const DB_VERSION = 1;

/**
 * Store names that can be created in the database.
 * Each entity type gets its own object store.
 */
export type StoreName = 'products' | 'clients' | 'sales';

/**
 * Index definitions per store.
 * Used for fast lookups without scanning all items.
 */
const STORE_INDEXES: Record<StoreName, { name: string; keyPath: string; unique: boolean }[]> = {
    products: [
        { name: 'by_plu', keyPath: 'plu', unique: false },
        { name: 'by_category', keyPath: 'category', unique: false },
        { name: 'by_store', keyPath: 'storeId', unique: false },
    ],
    clients: [
        { name: 'by_cc', keyPath: 'cc', unique: false },
        { name: 'by_store', keyPath: 'storeId', unique: false },
    ],
    sales: [
        { name: 'by_date', keyPath: 'date', unique: false },
        { name: 'by_store', keyPath: 'storeId', unique: false },
    ],
};

/**
 * Fields in each store that contain Decimal values.
 * These are serialized to strings on save and hydrated back to Decimal on read.
 */
const DECIMAL_FIELDS: Record<StoreName, string[]> = {
    products: ['price', 'stock', 'cost'],
    clients: ['totalDebt', 'creditLimit'],
    sales: ['total', 'effectiveTotal', 'amountReceived', 'change', 'roundingDifference'],
};

// ============================================
// DATABASE INITIALIZATION
// ============================================

let dbPromise: Promise<IDBPDatabase> | null = null;

/**
 * Gets or creates the shared IndexedDB connection.
 * Uses a singleton pattern to avoid multiple connections.
 */
function getDB(): Promise<IDBPDatabase> {
    if (!dbPromise) {
        dbPromise = openDB(DB_NAME, DB_VERSION, {
            upgrade(db) {
                // Create all object stores and their indexes
                for (const [storeName, indexes] of Object.entries(STORE_INDEXES)) {
                    if (!db.objectStoreNames.contains(storeName)) {
                        const store = db.createObjectStore(storeName, { keyPath: 'id' });
                        for (const index of indexes) {
                            store.createIndex(index.name, index.keyPath, { unique: index.unique });
                        }
                        logger.log(`[IDB] Created store: ${storeName} with ${indexes.length} indexes`);
                    }
                }
            },
            blocked() {
                logger.warn('[IDB] Database upgrade blocked — close other tabs');
            },
            blocking() {
                logger.warn('[IDB] Current connection blocking a newer version');
            },
        });
    }
    return dbPromise;
}

// ============================================
// SERIALIZATION HELPERS
// ============================================

/**
 * Serialize Decimal instances to strings for IDB storage.
 * IDB can't store class instances (Decimal), only plain objects.
 */
function serializeForIDB<T>(item: T, decimalFields: string[]): Record<string, any> {
    const serialized: Record<string, any> = { ...item as any };
    for (const field of decimalFields) {
        if (serialized[field] instanceof Decimal) {
            serialized[field] = serialized[field].toString();
        }
    }
    return serialized;
}

/**
 * Hydrate Decimal fields from stored strings back to Decimal instances.
 */
function hydrateFromIDB<T>(raw: Record<string, any>, decimalFields: string[]): T {
    const hydrated: Record<string, any> = { ...raw };
    for (const field of decimalFields) {
        if (hydrated[field] !== null && hydrated[field] !== undefined) {
            try {
                hydrated[field] = new Decimal(hydrated[field]);
            } catch {
                // If the value can't be parsed as Decimal, leave it as-is
                logger.warn(`[IDB] Failed to hydrate Decimal field: ${field}`, hydrated[field]);
            }
        }
    }
    return hydrated as T;
}

// ============================================
// FACTORY
// ============================================

/**
 * Creates an IndexedDB-backed LocalDataSource for a specific entity store.
 * 
 * @param storeName - The IDB object store to use (e.g., 'products')
 * @returns A LocalDataSource implementation
 * 
 * @example
 * ```typescript
 * const productCache = createIndexedDBDataSource<Product>('products');
 * const products = await productCache.getAll();
 * await productCache.saveBulk(newProducts);
 * ```
 */
export function createIndexedDBDataSource<T extends { id: string }>(
    storeName: StoreName
): LocalDataSource<T> {

    const decimalFields = DECIMAL_FIELDS[storeName] || [];

    return {
        async getAll(): Promise<T[]> {
            try {
                const db = await getDB();
                const items = await db.getAll(storeName);
                return items.map(item => hydrateFromIDB<T>(item, decimalFields));
            } catch (e) {
                logger.error(`[IDB] getAll(${storeName}) failed:`, e);
                return [];
            }
        },

        async getById(id: string): Promise<T | null> {
            try {
                const db = await getDB();
                const item = await db.get(storeName, id);
                return item ? hydrateFromIDB<T>(item, decimalFields) : null;
            } catch (e) {
                logger.error(`[IDB] getById(${storeName}, ${id}) failed:`, e);
                return null;
            }
        },

        async getByIndex(indexName: string, value: string | number): Promise<T[]> {
            try {
                const db = await getDB();
                const items = await db.getAllFromIndex(storeName, indexName, value);
                return items.map(item => hydrateFromIDB<T>(item, decimalFields));
            } catch (e) {
                logger.error(`[IDB] getByIndex(${storeName}, ${indexName}) failed:`, e);
                return [];
            }
        },

        async save(item: T): Promise<void> {
            try {
                const db = await getDB();
                const serialized = serializeForIDB(item, decimalFields);
                await db.put(storeName, serialized);
            } catch (e) {
                logger.error(`[IDB] save(${storeName}) failed:`, e);
            }
        },

        async saveBulk(items: T[]): Promise<void> {
            if (items.length === 0) return;

            try {
                const db = await getDB();
                const tx = db.transaction(storeName, 'readwrite');
                const store = tx.objectStore(storeName);

                // Clear existing data before bulk save to ensure consistency
                await store.clear();

                // Insert all items in a single transaction
                for (const item of items) {
                    const serialized = serializeForIDB(item, decimalFields);
                    await store.put(serialized);
                }

                await tx.done;
                logger.log(`[IDB] saveBulk(${storeName}): ${items.length} items saved`);
            } catch (e) {
                logger.error(`[IDB] saveBulk(${storeName}) failed:`, e);
            }
        },

        async remove(id: string): Promise<void> {
            try {
                const db = await getDB();
                await db.delete(storeName, id);
            } catch (e) {
                logger.error(`[IDB] remove(${storeName}, ${id}) failed:`, e);
            }
        },

        async clear(): Promise<void> {
            try {
                const db = await getDB();
                await db.clear(storeName);
                logger.log(`[IDB] clear(${storeName}): Store cleared`);
            } catch (e) {
                logger.error(`[IDB] clear(${storeName}) failed:`, e);
            }
        },

        async count(): Promise<number> {
            try {
                const db = await getDB();
                return await db.count(storeName);
            } catch (e) {
                logger.error(`[IDB] count(${storeName}) failed:`, e);
                return 0;
            }
        },
    };
}

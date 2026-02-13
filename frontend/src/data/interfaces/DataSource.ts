/**
 * Data Source Interfaces
 * Cache-Ahead Repository Pattern — Phase 1
 * 
 * Defines the contracts for local (IndexedDB) and remote (Supabase) data sources.
 * These interfaces decouple storage mechanism from repository orchestration logic.
 * 
 * @module data/interfaces/DataSource
 */

/**
 * Local Data Source — Asynchronous local storage contract.
 * Implementors: IndexedDBDataSource
 * 
 * Responsible for HOW data is persisted locally (bytes on disk).
 * Must be async (Promise-based) to avoid blocking the main thread.
 */
export interface LocalDataSource<T> {
    /** Retrieve all items from the local store */
    getAll(): Promise<T[]>;

    /** Retrieve a single item by its primary key */
    getById(id: string): Promise<T | null>;

    /** Find items matching a specific indexed field value (e.g., PLU lookup) */
    getByIndex(indexName: string, value: string | number): Promise<T[]>;

    /** Save or update a single item */
    save(item: T): Promise<void>;

    /** Save multiple items in a single transaction (bulk upsert) */
    saveBulk(items: T[]): Promise<void>;

    /** Remove a single item by its primary key */
    remove(id: string): Promise<void>;

    /** Clear all items from this store */
    clear(): Promise<void>;

    /** Get the count of items without loading them all */
    count(): Promise<number>;
}

/**
 * Remote Data Source — Network data access contract.
 * Implementors: SupabaseDataSource (future)
 * 
 * Responsible for HOW data is fetched/persisted over the network.
 * For now, repositories call Supabase directly. This interface is
 * defined for future decoupling when we extract SupabaseDataSource.
 */
export interface RemoteDataSource<TDomain, TRemote = TDomain> {
    /** Fetch all items, optionally filtered by store */
    fetchAll(storeId: string): Promise<TDomain[]>;

    /** Fetch a single item by ID */
    fetchById(id: string): Promise<TDomain | null>;

    /** Create or update item on the remote */
    persist(item: TDomain): Promise<TDomain | null>;

    /** Delete item from the remote */
    remove(id: string): Promise<boolean>;
}

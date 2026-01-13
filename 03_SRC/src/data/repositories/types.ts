/**
 * Generic interface for storage adapters.
 * Allows swapping localStorage for other backends (e.g., Supabase).
 */
export interface StorageAdapter {
    get<T>(key: string): T | null;
    set<T>(key: string, value: T): void;
    remove(key: string): void;
    clear(): void;
}

/**
 * Interface for persist configuration used by Pinia stores.
 */
export interface PersistConfig<T> {
    key: string;
    storage?: Storage;
    serializer?: {
        serialize: (state: T) => string;
        deserialize: (value: string) => Partial<T>;
    };
}

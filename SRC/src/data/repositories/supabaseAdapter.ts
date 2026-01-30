/**
 * Supabase Repository Adapter
 * WO-002 T2.2: Implements StorageAdapter for Supabase
 * WO-FE-005: Adds Mapper Layer for Domain/Persistence separation
 * 
 * Provides CRUD operations against Supabase tables
 * with automatic fallback to localStorage if connection fails
 * 
 * @module data/repositories/supabaseAdapter
 */

import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { localStorageAdapter } from './localStorageAdapter';
import { logger } from '../../utils/logger';

/**
 * Generic repository interface for entity operations
 */
export interface EntityRepository<T> {
    getAll(storeId?: string): Promise<T[]>;
    getById(id: string): Promise<T | null>;
    create(data: Omit<T, 'id'>): Promise<T | null>;
    update(id: string, data: Partial<T>): Promise<T | null>;
    delete(id: string): Promise<boolean>;
}

/**
 * Mapper interface for transforming between Persistence (DB) and Domain (App) models
 * WO-FE-005: Enforces strict separation.
 */
export interface RepositoryMappers<TPersistence, TDomain> {
    toDomain: (row: TPersistence) => TDomain;
    toPersistence: (entity: TDomain) => TPersistence;
}

/**
 * Create a Supabase repository for a specific table
 * @param tableName - Name of the Supabase table
 * @param localStorageKey - Key for localStorage fallback
 * @param mappers - Optional mappers for data transformation. If provided, localStorage saves TPersistence.
 */
export function createSupabaseRepository<TDomain extends { id: string }, TPersistence extends { id: string } = any>(
    tableName: string,
    localStorageKey: string,
    mappers?: RepositoryMappers<TPersistence, TDomain>
): EntityRepository<TDomain> {
    /**
     * Check if Supabase is available
     */
    const isAvailable = (): boolean => {
        return isSupabaseConfigured() && getSupabaseClient() !== null;
    };

    /**
     * Helper to transform row(s) to domain
     */
    const mapToDomain = (data: TPersistence | TPersistence[]): TDomain | TDomain[] => {
        if (!mappers) return data as unknown as TDomain | TDomain[];
        if (Array.isArray(data)) {
            return data.map(mappers.toDomain);
        }
        return mappers.toDomain(data);
    };

    /**
     * Get all records
     */
    const getAll = async (storeId?: string): Promise<TDomain[]> => {
        if (!isAvailable()) {
            // Fallback to localStorage
            // Data in LS is TPersistence (if mappers exist) or TDomain (if not)
            const data = localStorageAdapter.get<TPersistence[]>(localStorageKey) || [];
            if (mappers) {
                return data.map(mappers.toDomain);
            }
            return data as unknown as TDomain[];
        }

        const supabase = getSupabaseClient()!;
        try {
            let query = supabase.from(tableName).select('*');
            if (storeId) {
                query = query.eq('store_id', storeId);
            }
            const { data, error } = await query;

            if (error) {
                logger.log(`[SupabaseRepo:${tableName}] getAll error:`, error.message);
                // Fallback to localStorage
                const localData = localStorageAdapter.get<TPersistence[]>(localStorageKey) || [];
                if (mappers) {
                    return localData.map(mappers.toDomain);
                }
                return localData as unknown as TDomain[];
            }

            // Sync/Cache to local storage on successful fetch?
            // "Offline First" usually implies keeping local cache updated.
            // For simplicity in this phase, we act as simple Repo.
            // But to support "Read Offline after Online", we should update LS here?
            // ADR says: "localStorage guarda copias exactas de DB".
            // So we should save `data` (TPersistence) to LS.
            if (data) {
                localStorageAdapter.set(localStorageKey, data);
            }

            return mapToDomain(data as unknown as TPersistence[]) as TDomain[];
        } catch (error) {
            logger.log(`[SupabaseRepo:${tableName}] getAll exception:`, error);
            const localData = localStorageAdapter.get<TPersistence[]>(localStorageKey) || [];
            if (mappers) {
                return localData.map(mappers.toDomain);
            }
            return localData as unknown as TDomain[];
        }
    };

    /**
     * Get record by ID
     */
    const getById = async (id: string): Promise<TDomain | null> => {
        // Try Online 
        if (isAvailable()) {
            const supabase = getSupabaseClient()!;
            try {
                const { data, error } = await supabase
                    .from(tableName)
                    .select('*')
                    .eq('id', id)
                    .single();

                if (!error && data) {
                    return mapToDomain(data as unknown as TPersistence) as TDomain;
                }
                logger.log(`[SupabaseRepo:${tableName}] getById error or not found:`, error?.message);
            } catch (error) {
                logger.log(`[SupabaseRepo:${tableName}] getById exception:`, error);
            }
        }

        // Fallback or if not available
        const localData = localStorageAdapter.get<TPersistence[]>(localStorageKey);
        const item = localData?.find(item => item.id === id);

        if (item) {
            return mappers ? mappers.toDomain(item) : (item as unknown as TDomain);
        }
        return null;
    };

    /**
     * Create new record
     */
    const create = async (data: Omit<TDomain, 'id'>): Promise<TDomain | null> => {
        // Generate ID locally for consistency (or depend on DB?)
        // To satisfy "TDomain", we need an ID.
        const newId = crypto.randomUUID();
        const newEntityDomain = { ...data, id: newId } as TDomain;

        let payload: TPersistence;

        if (mappers) {
            payload = mappers.toPersistence(newEntityDomain);
        } else {
            payload = newEntityDomain as unknown as TPersistence;
        }

        // 1. Optimistic / Offline Save (Always save to LS)
        const existing = localStorageAdapter.get<TPersistence[]>(localStorageKey) || [];
        existing.push(payload);
        localStorageAdapter.set(localStorageKey, existing);

        // 2. Try Online
        if (isAvailable()) {
            const supabase = getSupabaseClient()!;
            try {
                const { data: created, error } = await supabase
                    .from(tableName)
                    .insert(payload)
                    .select()
                    .single();

                if (error) {
                    logger.log(`[SupabaseRepo:${tableName}] create error (saved locally):`, error.message);
                    // Return local entity since we saved it
                    return newEntityDomain;
                }

                // If success, we might get back updated fields (defaults).
                // Should we update LS with what DB returned? Yes.
                const createdPersistence = created as unknown as TPersistence;

                // Update the item in LS with authoritative data
                const index = existing.findIndex(e => e.id === newId);
                if (index !== -1) {
                    existing[index] = createdPersistence;
                    localStorageAdapter.set(localStorageKey, existing);
                }

                return mapToDomain(createdPersistence) as TDomain;
            } catch (error) {
                logger.log(`[SupabaseRepo:${tableName}] create exception (saved locally):`, error);
                return newEntityDomain;
            }
        }

        // Offline mode
        return newEntityDomain;
    };

    /**
     * Update existing record
     */
    const update = async (id: string, updateData: Partial<TDomain>): Promise<TDomain | null> => {
        // We need the full object to map properly if using toPersistence?
        // OR we need a partial mapper?
        // `toPersistence` takes a FULL TDomain.
        // So we must fetch, merge, map, then save.

        // 1. Get current state (Local prefered for speed/merging?)
        // Let's get from LS first to merge.
        const existingList = localStorageAdapter.get<TPersistence[]>(localStorageKey) || [];
        const index = existingList.findIndex(item => item.id === id);

        if (index === -1) {
            // If not in LS, maybe check online? 
            // Implementing read-modify-write logic here.
            // For simplify, if not in LS, we can't update offline.
            // If online, we can patch.
            // BUT `updateData` is Partial<TDomain>. Supabase expects Partial<TPersistence>.
            // Using `toPersistence` on a Partial is risky/impossible if type is strict.
            // Strategy: Fetch full -> Merge -> Map -> Save.
        }

        // Simplified Strategy for Phase 5:
        // We assume we have the item in LS or can fetch it.
        let currentDomain: TDomain | null = null;

        // Try fetch local
        if (index !== -1) {
            const currentPersistence = existingList[index];
            currentDomain = mappers ? mappers.toDomain(currentPersistence) : (currentPersistence as unknown as TDomain);
        } else if (isAvailable()) {
            // Try fetch online
            const fetched = await getById(id);
            if (fetched) currentDomain = fetched;
        }

        if (!currentDomain) return null;

        // Merge
        const updatedDomain = { ...currentDomain, ...updateData };

        let payload: TPersistence;
        if (mappers) {
            payload = mappers.toPersistence(updatedDomain);
        } else {
            payload = updatedDomain as unknown as TPersistence;
        }

        // 1. Save Local
        if (index !== -1) {
            existingList[index] = payload;
        } else {
            existingList.push(payload);
        }
        localStorageAdapter.set(localStorageKey, existingList);

        // 2. Try Online
        if (isAvailable()) {
            const supabase = getSupabaseClient()!;
            try {
                // We send the FULL payload (PUT semantics) or Partial?
                // `supabase.update` takes Partial. `payload` is Full TPersistence.
                // It's safe to send full payload for update if RLS allows.
                const { data: updated, error } = await supabase
                    .from(tableName)
                    .update(payload)
                    .eq('id', id)
                    .select()
                    .single();

                if (error) {
                    logger.log(`[SupabaseRepo:${tableName}] update error (saved locally):`, error.message);
                    return updatedDomain;
                }

                const updatedPersistence = updated as unknown as TPersistence;
                // Update LS with authoritative
                // (Re-read list in case it changed)
                const freshList = localStorageAdapter.get<TPersistence[]>(localStorageKey) || [];
                const freshIndex = freshList.findIndex(e => e.id === id);
                if (freshIndex !== -1) {
                    freshList[freshIndex] = updatedPersistence;
                    localStorageAdapter.set(localStorageKey, freshList);
                }

                return mapToDomain(updatedPersistence) as TDomain;

            } catch (error) {
                logger.log(`[SupabaseRepo:${tableName}] update exception (saved locally):`, error);
                return updatedDomain;
            }
        }

        return updatedDomain;
    };

    /**
     * Delete record
     */
    const deleteRecord = async (id: string): Promise<boolean> => {
        // 1. Delete Local
        const existing = localStorageAdapter.get<TPersistence[]>(localStorageKey) || [];
        const filtered = existing.filter(item => item.id !== id);

        if (filtered.length !== existing.length) {
            localStorageAdapter.set(localStorageKey, filtered);
        }

        // 2. Delete Online
        if (isAvailable()) {
            const supabase = getSupabaseClient()!;
            try {
                const { error } = await supabase
                    .from(tableName)
                    .delete()
                    .eq('id', id);

                if (error) {
                    logger.log(`[SupabaseRepo:${tableName}] delete error:`, error.message);
                    return false; // Or true if we consider local delete enough? 
                    // Usually for sync we need to track "deleted items".
                    // Phase 5 doesn't specify soft-delete sync queues yet.
                    // For now, return false implies sync failed.
                }
                return true;
            } catch (error) {
                logger.log(`[SupabaseRepo:${tableName}] delete exception:`, error);
                // Return true because we deleted locally?
                // "Offline First" dictates local op is primary.
                return true;
            }
        }

        return true; // Performed locally
    };

    return {
        getAll,
        getById,
        create,
        update,
        delete: deleteRecord,
    };
}

export default createSupabaseRepository;

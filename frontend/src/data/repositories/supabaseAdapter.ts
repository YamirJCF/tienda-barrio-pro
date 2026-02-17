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
import { enrichPayloadWithContext, validatePayloadSchema, SyncEvents, emitSyncEvent } from '../../services/syncInterceptor';

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
     * QA-FIX-007: Safely read array data from localStorage.
     * Handles two formats:
     *   - Raw array (written by supabaseAdapter): [item1, item2, ...]
     *   - Pinia-wrapped (written by pinia-plugin-persistedstate): { products: [...] }
     * Returns empty array if data is missing or unrecognizable.
     */
    const getLocalArray = (): TPersistence[] => {
        const raw = localStorageAdapter.get<any>(localStorageKey);
        if (!raw) return [];
        if (Array.isArray(raw)) return raw;
        // Pinia persist wraps store state in an object — extract the main array
        if (typeof raw === 'object' && raw !== null) {
            // Try common Pinia state keys (products, items, etc.)
            const arrayKey = Object.keys(raw).find(k => Array.isArray(raw[k]));
            if (arrayKey) return raw[arrayKey] as TPersistence[];
        }
        return [];
    };
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
            const data = getLocalArray();
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
                const localData = getLocalArray();
                if (mappers) {
                    return localData.map(mappers.toDomain);
                }
                return localData as unknown as TDomain[];
            }

            // Sync cache to localStorage on successful fetch
            // SAFETY: Only update LS if Supabase returned data  
            // Protect against wiping local cache when RLS returns empty due to session issues
            if (data && data.length > 0) {
                localStorageAdapter.set(localStorageKey, data);
            } else if (data && data.length === 0) {
                // Supabase returned empty - check if we had local data
                const localData = localStorageAdapter.get<TPersistence[]>(localStorageKey) || [];
                if (localData.length > 0) {
                    logger.warn(`[SupabaseRepo:${tableName}] ⚠️ Supabase returned 0 items but localStorage has ${localData.length}. Possible RLS issue. NOT overwriting localStorage.`);
                    // Emit event so the UI can warn the user
                    window.dispatchEvent(new CustomEvent('sync:data_desync', {
                        detail: {
                            table: tableName,
                            localCount: localData.length,
                            remoteCount: 0,
                            message: `Supabase devolvió 0 ${tableName} pero hay ${localData.length} localmente. Posible problema de sesión/RLS.`
                        }
                    }));
                } else {
                    // Both empty - safe to sync
                    localStorageAdapter.set(localStorageKey, data);
                }
            }

            // Defensive: Ensure data is not null
            if (!data) {
                logger.warn(`[SupabaseRepo:${tableName}] getAll returned null, using empty array`);
                return [];
            }

            return mapToDomain(data as unknown as TPersistence[]) as TDomain[];
        } catch (error) {
            logger.log(`[SupabaseRepo:${tableName}] getAll exception:`, error);
            const localData = getLocalArray();
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
        const localData = getLocalArray();
        const item = localData.find(item => item.id === id) || null;

        if (item) {
            return mappers ? mappers.toDomain(item) : (item as unknown as TDomain);
        }
        return null;
    };

    /**
     * Create new record
     * FRD-006: Uses Sync Interceptor for validation and auto-healing
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

        // FRD-006: Auto-heal store_id from session context
        const enrichedPayload = await enrichPayloadWithContext(
            payload as unknown as Record<string, any>,
            tableName
        ) as unknown as TPersistence;

        // FRD-006: Validate schema before network request
        const schemaValidation = validatePayloadSchema(
            enrichedPayload as unknown as Record<string, any>,
            tableName
        );

        if (!schemaValidation.valid) {
            const errorMsg = `Schema validation failed for ${tableName}: ` +
                schemaValidation.missingFields.join(', ');
            logger.error(`[SupabaseRepo:${tableName}] ${errorMsg}`);
            emitSyncEvent(SyncEvents.SCHEMA_ERROR, { table: tableName, ...schemaValidation });
            // Don't proceed - this would fail RLS anyway
            return null;
        }

        // 1. Optimistic / Offline Save (Always save to LS)
        let existing = getLocalArray();
        existing.push(enrichedPayload);
        localStorageAdapter.set(localStorageKey, existing);

        // 2. Try Online
        if (isAvailable()) {
            const supabase = getSupabaseClient()!;
            try {
                const { data: created, error } = await supabase
                    .from(tableName)
                    .insert(enrichedPayload)
                    .select()
                    .single();

                if (error) {
                    // CRITICAL: Remove from localStorage since DB rejected it
                    // This prevents phantom data that disappears on reload
                    const rollbackList = localStorageAdapter.get<TPersistence[]>(localStorageKey) || [];
                    const filteredList = rollbackList.filter(e => e.id !== newId);
                    localStorageAdapter.set(localStorageKey, filteredList);

                    // FRD-006: Check for RLS error specifically
                    if (error.code === '42501' || error.message?.includes('row-level security')) {
                        logger.error(`[SupabaseRepo:${tableName}] RLS rejection:`, error.message);
                        emitSyncEvent(SyncEvents.RLS_ERROR, { table: tableName, error: error.message });
                    }

                    logger.error(`[SupabaseRepo:${tableName}] ❌ create FAILED - rolled back localStorage:`, error.message);

                    // Throw so the store layer can show an error to the user
                    throw new Error(`Error al crear ${tableName}: ${error.message}`);
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
        let existingList = getLocalArray();

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
                    // CRITICAL: Rollback localStorage to previous state
                    if (index !== -1) {
                        // Restore original data
                        const rollbackList = localStorageAdapter.get<TPersistence[]>(localStorageKey) || [];
                        const ri = rollbackList.findIndex(e => e.id === id);
                        if (ri !== -1) {
                            const origPersistence = existingList[index]; // original before merge
                            rollbackList[ri] = origPersistence;
                            localStorageAdapter.set(localStorageKey, rollbackList);
                        }
                    }

                    logger.error(`[SupabaseRepo:${tableName}] ❌ update FAILED - rolled back localStorage:`, error.message);
                    throw new Error(`Error al actualizar ${tableName}: ${error.message}`);
                }

                const updatedPersistence = updated as unknown as TPersistence;
                // Update LS with authoritative
                // (Re-read list in case it changed)
                const freshList = getLocalArray();
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
        let existing = getLocalArray();
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

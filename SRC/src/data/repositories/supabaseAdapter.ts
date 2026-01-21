/**
 * Supabase Repository Adapter
 * WO-002 T2.2: Implements StorageAdapter for Supabase
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
 * Create a Supabase repository for a specific table
 * @param tableName - Name of the Supabase table
 * @param localStorageKey - Key for localStorage fallback
 */
export function createSupabaseRepository<T extends { id: string }>(
    tableName: string,
    localStorageKey: string
): EntityRepository<T> {
    /**
     * Check if Supabase is available
     */
    const isAvailable = (): boolean => {
        return isSupabaseConfigured() && getSupabaseClient() !== null;
    };

    /**
     * Get all records
     */
    const getAll = async (storeId?: string): Promise<T[]> => {
        if (!isAvailable()) {
            // Fallback to localStorage
            const data = localStorageAdapter.get<T[]>(localStorageKey);
            return data || [];
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
                const localData = localStorageAdapter.get<T[]>(localStorageKey);
                return localData || [];
            }

            return data as T[];
        } catch (error) {
            logger.log(`[SupabaseRepo:${tableName}] getAll exception:`, error);
            const localData = localStorageAdapter.get<T[]>(localStorageKey);
            return localData || [];
        }
    };

    /**
     * Get record by ID
     */
    const getById = async (id: string): Promise<T | null> => {
        if (!isAvailable()) {
            const data = localStorageAdapter.get<T[]>(localStorageKey);
            return data?.find(item => item.id === id) || null;
        }

        const supabase = getSupabaseClient()!;
        try {
            const { data, error } = await supabase
                .from(tableName)
                .select('*')
                .eq('id', id)
                .single();

            if (error) {
                logger.log(`[SupabaseRepo:${tableName}] getById error:`, error.message);
                const localData = localStorageAdapter.get<T[]>(localStorageKey);
                return localData?.find(item => item.id === id) || null;
            }

            return data as T;
        } catch (error) {
            const localData = localStorageAdapter.get<T[]>(localStorageKey);
            return localData?.find(item => item.id === id) || null;
        }
    };

    /**
     * Create new record
     */
    const create = async (data: Omit<T, 'id'>): Promise<T | null> => {
        if (!isAvailable()) {
            // For localStorage, we need to generate ID
            const id = crypto.randomUUID();
            const newItem = { id, ...data } as T;
            const existing = localStorageAdapter.get<T[]>(localStorageKey) || [];
            existing.push(newItem);
            localStorageAdapter.set(localStorageKey, existing);
            return newItem;
        }

        const supabase = getSupabaseClient()!;
        try {
            const { data: created, error } = await supabase
                .from(tableName)
                .insert(data)
                .select()
                .single();

            if (error) {
                logger.log(`[SupabaseRepo:${tableName}] create error:`, error.message);
                // Try localStorage as fallback
                const id = crypto.randomUUID();
                const newItem = { id, ...data } as T;
                const existing = localStorageAdapter.get<T[]>(localStorageKey) || [];
                existing.push(newItem);
                localStorageAdapter.set(localStorageKey, existing);
                return newItem;
            }

            return created as T;
        } catch (error) {
            logger.log(`[SupabaseRepo:${tableName}] create exception:`, error);
            return null;
        }
    };

    /**
     * Update existing record
     */
    const update = async (id: string, updateData: Partial<T>): Promise<T | null> => {
        if (!isAvailable()) {
            const existing = localStorageAdapter.get<T[]>(localStorageKey) || [];
            const index = existing.findIndex(item => item.id === id);
            if (index === -1) return null;

            existing[index] = { ...existing[index], ...updateData };
            localStorageAdapter.set(localStorageKey, existing);
            return existing[index];
        }

        const supabase = getSupabaseClient()!;
        try {
            const { data: updated, error } = await supabase
                .from(tableName)
                .update(updateData)
                .eq('id', id)
                .select()
                .single();

            if (error) {
                logger.log(`[SupabaseRepo:${tableName}] update error:`, error.message);
                // Try localStorage
                const existing = localStorageAdapter.get<T[]>(localStorageKey) || [];
                const index = existing.findIndex(item => item.id === id);
                if (index === -1) return null;
                existing[index] = { ...existing[index], ...updateData };
                localStorageAdapter.set(localStorageKey, existing);
                return existing[index];
            }

            return updated as T;
        } catch (error) {
            logger.log(`[SupabaseRepo:${tableName}] update exception:`, error);
            return null;
        }
    };

    /**
     * Delete record
     */
    const deleteRecord = async (id: string): Promise<boolean> => {
        if (!isAvailable()) {
            const existing = localStorageAdapter.get<T[]>(localStorageKey) || [];
            const filtered = existing.filter(item => item.id !== id);
            localStorageAdapter.set(localStorageKey, filtered);
            return filtered.length < existing.length;
        }

        const supabase = getSupabaseClient()!;
        try {
            const { error } = await supabase
                .from(tableName)
                .delete()
                .eq('id', id);

            if (error) {
                logger.log(`[SupabaseRepo:${tableName}] delete error:`, error.message);
                // Try localStorage
                const existing = localStorageAdapter.get<T[]>(localStorageKey) || [];
                const filtered = existing.filter(item => item.id !== id);
                localStorageAdapter.set(localStorageKey, filtered);
                return filtered.length < existing.length;
            }

            return true;
        } catch (error) {
            logger.log(`[SupabaseRepo:${tableName}] delete exception:`, error);
            return false;
        }
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

/**
 * Client Repository
 * WO-002 T2.2: Implementing repository pattern for Clients
 * 
 * Uses SupabaseAdapter to provide data access for Clients
 * Handles fallback to localStorage automatically via adapter
 * 
 * @module data/repositories/clientRepository
 */

import { Client } from '../../types';
import { createSupabaseRepository, EntityRepository } from './supabaseAdapter';

// Constants
const TABLE_NAME = 'clients';
const STORAGE_KEY = 'tienda-clients';

/**
 * Interface extending base repository with client-specific methods
 */
export interface ClientRepository extends EntityRepository<Client> {
    getByCedula(cedula: string, storeId?: string): Promise<Client | null>;
    searchByName(query: string, storeId?: string): Promise<Client[]>;
    updateDebt(id: string, amount: number): Promise<boolean>;
}

// Create base repository
const baseRepository = createSupabaseRepository<Client>(TABLE_NAME, STORAGE_KEY);

/**
 * Extended Client Repository implementation
 */
export const clientRepository: ClientRepository = {
    ...baseRepository,

    /**
     * Get client by Cedula
     */
    async getByCedula(cedula: string, storeId?: string): Promise<Client | null> {
        const all = await baseRepository.getAll(storeId);
        return all.find(c => c.cc === cedula) || null;
    },

    /**
     * Search clients by name
     */
    async searchByName(query: string, storeId?: string): Promise<Client[]> {
        const all = await baseRepository.getAll(storeId);
        const lowerQuery = query.toLowerCase();
        return all.filter(c => c.name.toLowerCase().includes(lowerQuery));
    },

    /**
     * Update client debt
     * Adds amount to current balance
     */
    async updateDebt(id: string, amount: number): Promise<boolean> {
        const client = await baseRepository.getById(id);
        if (!client) return false;

        // Use current balance, default to 0 if undefined
        // Note: Type definition might need adjustment if totalDebt is Decimal
        const currentDebt = Number(client.totalDebt) || 0;
        const newDebt = currentDebt + amount;

        const updated = await baseRepository.update(id, {
            totalDebt: newDebt
        } as any);

        return updated !== null;
    }
};

export default clientRepository;

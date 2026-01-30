/**
 * Client Repository
 * WO-002 T2.2: Implementing repository pattern for Clients
 * WO-FE-008: Map Schema v2 (snake_case) to Domain (camelCase)
 * 
 * Uses SupabaseAdapter to provide data access for Clients
 * Handles fallback to localStorage automatically via adapter
 * 
 * @module data/repositories/clientRepository
 */

import { Client } from '../../types';
import { Database } from '../../types/database.types';
import { Decimal } from 'decimal.js';
import { createSupabaseRepository, EntityRepository, RepositoryMappers } from './supabaseAdapter';

// Constants
const TABLE_NAME = 'clients';
const STORAGE_KEY = 'tienda-clients';

// Type definitions
type ClientDB = Database['public']['Tables']['clients']['Row'];

/**
 * Mapper Implementation for Client
 * Enforces:
 * 1. cc (Domain) <-> id_number (DB)
 * 2. totalDebt (Decimal) <-> balance (number)
 */
export const clientMapper: RepositoryMappers<ClientDB, Client> = {
    toDomain: (row: ClientDB): Client => {
        return {
            id: row.id,
            name: row.name,
            cc: row.id_number,
            phone: row.phone || undefined,
            email: undefined, // Not in DB schema v2 view?
            totalDebt: new Decimal(row.balance || 0),
            notes: undefined, // Not in DB Row shown
            creditLimit: new Decimal(row.credit_limit || 0),
            createdAt: row.created_at,
            updatedAt: row.updated_at
        };
    },
    toPersistence: (entity: Client): ClientDB => {
        return {
            id: entity.id,
            name: entity.name,
            id_number: entity.cc,
            phone: entity.phone || null,
            balance: entity.totalDebt.toNumber(),
            credit_limit: entity.creditLimit ? entity.creditLimit.toNumber() : 0,
            created_at: entity.createdAt || new Date().toISOString(),
            updated_at: new Date().toISOString(),
            store_id: '', // Context should fill this or existing logic
            deleted_at: null,
            is_deleted: false
        };
    }
};

/**
 * Interface extending base repository with client-specific methods
 */
export interface ClientRepository extends EntityRepository<Client> {
    getByCedula(cedula: string, storeId?: string): Promise<Client | null>;
    searchByName(query: string, storeId?: string): Promise<Client[]>;
    updateDebt(id: string, amount: number): Promise<boolean>;
}

// Create base repository
const baseRepository = createSupabaseRepository<Client, ClientDB>(
    TABLE_NAME,
    STORAGE_KEY,
    clientMapper
);

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

        // Use Domain Decimal for calculation
        const currentDebt = client.totalDebt;
        const newDebt = currentDebt.plus(amount);

        // Update using Domain Partial (Adapter maps to persistence)
        const updated = await baseRepository.update(id, {
            totalDebt: newDebt
        } as Partial<Client>);

        return updated !== null;
    }
};

export default clientRepository;

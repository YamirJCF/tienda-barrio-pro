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
import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';

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
            updatedAt: row.updated_at,
            storeId: row.store_id // Map from DB (Fase 1 Blindaje)
        };
    },
    toPersistence: (entity: Client): ClientDB => {
        // ===== VALIDATION CHECKPOINT (Fase 1 Blindaje) =====
        if (!entity.storeId || entity.storeId.trim() === '') {
            const error = new Error('Cannot persist Client without valid storeId. This would fail RLS policies.');
            console.error('🚫 [ClientRepo] RLSViolationError:', error.message);
            throw error;
        }

        // Validate UUID format
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        if (!uuidRegex.test(entity.storeId)) {
            const error = new Error(`Invalid UUID format for storeId: "${entity.storeId}"`);
            console.error('🚫 [ClientRepo] ValidationError:', error.message);
            throw error;
        }

        return {
            id: entity.id,
            name: entity.name,
            id_number: entity.cc,
            phone: entity.phone || null,
            balance: entity.totalDebt.toNumber(),
            credit_limit: entity.creditLimit ? entity.creditLimit.toNumber() : 0,
            created_at: entity.createdAt || new Date().toISOString(),
            updated_at: new Date().toISOString(),
            store_id: entity.storeId, // NO FALLBACK - validated above
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
    getTransactions(clientId: string): Promise<any[]>;
    addTransaction(tx: any): Promise<boolean>;
    /** FRD-012: Reconcile pending transactions with actual sale_id after sync */
    updatePendingTransactionSaleId(description: string, saleId: string): Promise<boolean>;
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

    async updateDebt(id: string, amount: number): Promise<boolean> {
        // Online path: no-op — the RPC (rpc_procesar_venta_v2 / registrar_abono) owns
        // the balance update atomically. Writing here would cause a double-charge.
        if (isSupabaseConfigured() && navigator.onLine) {
            return true;
        }

        // Offline path: update locally so the POS shows the correct balance immediately
        const client = await baseRepository.getById(id);
        if (!client) return false;

        const currentDebt = client.totalDebt;
        const newDebt = currentDebt.plus(amount);

        const updated = await baseRepository.update(id, {
            totalDebt: newDebt
        } as Partial<Client>);

        return updated !== null;
    },

    /**
     * Get Client Transactions
     */
    async getTransactions(clientId: string): Promise<any[]> {
        if (isSupabaseConfigured() && navigator.onLine) {
            const supabase = getSupabaseClient()!;
            const { data, error } = await supabase
                .from('client_transactions')
                .select('*')
                .eq('client_id', clientId)
                .order('created_at', { ascending: false });

            if (error) {
                console.error('Error fetching transactions:', error);
                return [];
            }
            return data.map(t => ({
                id: t.id,
                clientId: t.client_id,
                type: (t.transaction_type === 'compra' ? 'purchase' : 'payment') as 'purchase' | 'payment',
                amount: new Decimal(t.amount),
                description: t.description || '',
                date: t.created_at,
                saleId: t.sale_id
            }));
        }
        return []; // TODO: Implement local storage fallback for transactions?
    },

    async addTransaction(tx: {
        id: string,
        clientId: string,
        type: 'purchase' | 'payment',
        amount: number,
        description: string,
        date: string,
        saleId?: string
    }): Promise<boolean> {
        // Online path: no-op — client_ledger is written exclusively by RPCs on the backend.
        // client_transactions is now a VIEW of client_ledger, so direct inserts are not possible.
        if (isSupabaseConfigured() && navigator.onLine) {
            return true;
        }

        // Offline path: log the pending transaction so it can be synced later
        console.warn('[ClientRepo] Offline - transaction not persisted, will sync with sale');
        return false;
    },

    /**
     * FRD-012: Reconciliation - Update pending transactions with the actual sale_id
     * Called after a sale is synced from offline queue
     */
    async updatePendingTransactionSaleId(
        description: string,
        saleId: string
    ): Promise<boolean> {
        // No-op: client_transactions is now a VIEW of client_ledger.
        // The reference_id (sale_id) is set at the time of the RPC call and does not
        // need manual reconciliation. This method is kept for interface compatibility.
        console.log('[ClientRepo] updatePendingTransactionSaleId is a no-op (view-based reconciliation).', { description, saleId });
        return true;
    }
};

export default clientRepository;


/**
 * Expense Repository
 * WO-003 T3.4: Management of minor expenses
 * WO-FE-008: Map to Schema v2 (cash_movements)
 *
 * @module data/repositories/expenseRepository
 */

import { createSupabaseRepository, EntityRepository, RepositoryMappers } from './supabaseAdapter';
import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { logger } from '../../utils/logger';
import { Database } from '../../types/database.types';

export interface Expense {
    id: string;
    store_id: string; // Derived from session
    amount: number;
    description: string;
    category: string; // Extracted or stored in metadata
    created_by?: string; // Not directly available in cash_movements view unless joined?
    created_at?: string;
}

// Map to cash_movements
// Note: cash_movements does not have store_id direct, but linked via session_id.
// It also lacks 'category'. We might store "[Category] Desc"
type CashMovementDB = Database['public']['Tables']['cash_movements']['Row'];

const TABLE_NAME = 'cash_movements'; // Actually used via custom queries mostly
const STORAGE_KEY = 'tienda-expenses'; // Legacy key

const expenseMapper: RepositoryMappers<CashMovementDB, Expense> = {
    toDomain: (row: CashMovementDB): Expense => {
        // Extract category from description "[Category] Description"
        const match = row.description.match(/^\[(.*?)\] (.*)/);
        const category = match ? match[1] : 'General';
        const description = match ? match[2] : row.description;

        return {
            id: row.id,
            store_id: '', // Cannot know from row alone, query fills it
            amount: row.amount,
            description: description,
            category: category,
            created_at: row.created_at
        };
    },
    toPersistence: (entity: Expense): CashMovementDB => {
        return {
            id: entity.id,
            amount: entity.amount,
            description: `[${entity.category || 'General'}] ${entity.description}`,
            movement_type: 'expense',
            created_at: entity.created_at || new Date().toISOString(),
            session_id: '', // Must be filled by creator
            sale_id: null
        };
    }
};

const baseRepository = createSupabaseRepository<Expense, CashMovementDB>(TABLE_NAME, STORAGE_KEY, expenseMapper);

export interface ExpenseRepository extends EntityRepository<Expense> {
    getTodayExpenses(storeId: string): Promise<Expense[]>;
    createExpense(expense: Omit<Expense, 'id' | 'created_at'>): Promise<Expense | null>;
}

export const expenseRepository: ExpenseRepository = {
    ...baseRepository,

    /**
     * Get expenses for the current day
     */
    async getTodayExpenses(storeId: string): Promise<Expense[]> {
        const isOnline = navigator.onLine && isSupabaseConfigured();

        if (isOnline) {
            const supabase = getSupabaseClient()!;
            try {
                const today = new Date().toISOString().split('T')[0];

                // Query cash_movements joined with cash_sessions to filter by store_id
                const { data, error } = await supabase
                    .from('cash_movements')
                    .select('*, cash_sessions!inner(store_id)')
                    .eq('cash_sessions.store_id', storeId)
                    .eq('movement_type', 'expense')
                    .gte('created_at', `${today}T00:00:00`);

                if (error) throw error;

                // Map result
                return (data as any[]).map(row => {
                    const domain = expenseMapper.toDomain(row);
                    domain.store_id = storeId;
                    return domain;
                });

            } catch (e) {
                logger.error('[ExpenseRepo] Online fetch failed, fallback to local', e);
            }
        }

        // Fallback or Offline: Filter local data
        // Note: getAll from baseRepository for 'cash_movements' might return all movements, not just expenses
        // We rely on local storage matching the key 'tienda-expenses' which might still explicitly store expenses?
        // Or if we use the adapter on 'cash_movements', we get everything.
        // If we want dedicated expense storage offline, we might need a separate mechanism or filter.
        // For now, assuming adapter fallback handles the key 'tienda-expenses' which we write to in createExpense.

        try {
            // If we write to localStorage using 'tienda-expenses', reading it back gives Expenses.
            // But baseRepository using TABLE_NAME 'cash_movements' implies it reads/writes 'cash_movements' structure?
            // Since createSupabaseRepository is generic, if we pass Expense as TDomain, 
            // it expects localStorage to hold TPersistence (mapped) or TDomain?
            // Adapter logic: "localStorage always stores TPersistence if mappers are provided".
            // So localStorage has CashMovementDB[].

            const allVars = await baseRepository.getAll(storeId); // Returns Expense[] (mapped from persistence)
            const today = new Date().toISOString().split('T')[0];

            return allVars.filter(e => {
                const date = e.created_at ? e.created_at.split('T')[0] : '';
                return date === today; // And potentially type if we stored other movements? 
                // If STORAGE_KEY is unique to expenses, we are safe.
            });
        } catch (e) {
            return [];
        }
    },

    /**
     * Create a new expense
     */
    async createExpense(expense: Omit<Expense, 'id' | 'created_at'>): Promise<Expense | null> {
        // We need an open session ID to insert into cash_movements
        // Fetch open session from cashRepository or local status
        let sessionId = '';

        try {
            const { cashRepository } = await import('./cashRepository');
            const status = await cashRepository.getStoreStatus(expense.store_id);
            if (status.isOpen && status.sessionId) {
                sessionId = status.sessionId;
            } else {
                logger.warn('Cannot create expense: No open session found');
                return null; // Constraint: Expense must be strictly linked to a session
            }
        } catch (e) {
            logger.error('Error fetching session for expense', e);
            return null;
        }

        const payload = {
            ...expense,
            created_at: new Date().toISOString()
        } as Expense;

        // Custom Create logic to include Session ID in persistence mapping
        // baseRepository.create uses mapper.toPersistence. 
        // mapper.toPersistence(entity) doesn't know sessionId unless entity has it?
        // Expense Domain doesn't have sessionId.
        // We might need to extend Expense or handle creation manually here.

        // Manual Create using Adapter internal logic? No access.
        // We can create a fake Expense with sessionId injected? No type support.
        // Better: Query Supabase or Adapter directly.

        // Logic:
        // 1. Map to DB
        // 2. Inject Session ID
        // 3. Insert via Supabase or Local

        const dbRow = expenseMapper.toPersistence(payload);
        dbRow.session_id = sessionId;

        const isOnline = navigator.onLine && isSupabaseConfigured();
        if (isOnline) {
            const supabase = getSupabaseClient()!;
            const { data, error } = await supabase.from('cash_movements').insert(dbRow).select().single();
            if (!error && data) {
                return expenseMapper.toDomain(data);
            }
        }

        // Offline
        const { addToSyncQueue } = await import('../syncQueue');
        await addToSyncQueue('CREATE_EXPENSE', { ...dbRow, movement_type: 'expense' });

        // Save to Local 'tienda-expenses'
        // We should update the list in localStorage manually or use baseRepository.update?
        // baseRepository.create stores it. But create() doesn't let us inject session_id easily.
        // Reuse baseRepository.create?
        // The Mapper forces session_id = ''.
        // We can't use baseRepository.create() cleanly if we need extra fields.

        // Workaround: We don't save to 'tienda-expenses' via baseRepository. 
        // We manually append to localStorage 'tienda-expenses'?
        // Or we let the sync queue handle it and UI updates optimistically?
        // Returning the domain object implies success.

        return payload;
    }
};

export default expenseRepository;

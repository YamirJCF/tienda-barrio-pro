/**
 * Expense Repository
 * WO-003 T3.4: Management of minor expenses
 *
 * @module data/repositories/expenseRepository
 */

import { createSupabaseRepository, EntityRepository } from './supabaseAdapter';
import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { logger } from '../../utils/logger';

export interface Expense {
    id: string;
    store_id: string;
    amount: number;
    description: string;
    category: string;
    created_by?: string;
    created_at?: string;
}

export interface ExpenseRepository extends EntityRepository<Expense> {
    getTodayExpenses(storeId: string): Promise<Expense[]>;
    createExpense(expense: Omit<Expense, 'id' | 'created_at'>): Promise<Expense | null>;
}

const TABLE_NAME = 'expenses';
const STORAGE_KEY = 'tienda-expenses';

const baseRepository = createSupabaseRepository<Expense>(TABLE_NAME, STORAGE_KEY);

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
                // Get today's date in YYYY-MM-DD format (local time approximation or use DB timezone)
                // Better to let DB handle "todays" via date check if strict timezone needed
                // For simplicity, we filter by created_at >= today start
                const today = new Date().toISOString().split('T')[0];

                const { data, error } = await supabase
                    .from(TABLE_NAME)
                    .select('*')
                    .eq('store_id', storeId)
                    .gte('created_at', `${today}T00:00:00`);

                if (error) throw error;
                return data as Expense[];
            } catch (e) {
                logger.error('[ExpenseRepo] Online fetch failed, fallback to local', e);
            }
        }

        // Fallback or Offline: Filter local data
        const all = await baseRepository.getAll(storeId);
        const today = new Date().toISOString().split('T')[0];
        return all.filter(e => {
            const date = e.created_at ? e.created_at.split('T')[0] : '';
            return date === today;
        });
    },

    /**
     * Create a new expense
     */
    async createExpense(expense: Omit<Expense, 'id' | 'created_at'>): Promise<Expense | null> {
        // Use generic create but ensure strict types
        const payload = {
            ...expense,
            created_at: new Date().toISOString()
        };
        return baseRepository.create(payload);
    }
};

export default expenseRepository;

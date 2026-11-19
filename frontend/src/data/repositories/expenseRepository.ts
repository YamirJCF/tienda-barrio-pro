/**
 * Expense Repository
 * WO-003 T3.4: Management of minor expenses
 * WO-FE-008: Map to Schema v2 (cash_movements)
 *
 * @module data/repositories/expenseRepository
 */

import { createSupabaseRepository, EntityRepository, RepositoryMappers } from './supabaseAdapter';
import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { cashRepository } from './cashRepository';
import { logger } from '../../utils/logger';
import { Database } from '../../types/database.types';

export interface Expense {
    id: string;
    store_id: string; // Derived from session
    amount: number;
    description: string;
    category: string; // Extracted or stored in metadata
    payment_method?: 'efectivo' | 'nequi' | 'llave_bre';
    voucher_ref?: string | null;
    created_by?: string;
    actor_name?: string | null;
    actor_role?: string | null;
    created_at?: string;
}

// Map to cash_movements
type CashMovementDB = Database['public']['Tables']['cash_movements']['Row'];

const TABLE_NAME = 'cash_movements';
const STORAGE_KEY = 'tienda-expenses';

const expenseMapper: RepositoryMappers<CashMovementDB, Expense> = {
    toDomain: (row: CashMovementDB): Expense => {
        const match = row.description.match(/^\[(.*?)\] (.*)/);
        const category = match ? match[1] : 'General';
        const description = match ? match[2] : row.description;

        return {
            id: row.id,
            store_id: '',
            amount: row.amount,
            description: description,
            category: row.category || category,
            payment_method: (row.payment_method as Expense['payment_method']) || 'efectivo',
            voucher_ref: row.voucher_ref ?? null,
            created_by: row.actor_id ?? undefined,
            actor_name: (row as any).actor_name ?? null,
            actor_role: (row as any).actor_role ?? null,
            created_at: row.created_at
        };
    },
    toPersistence: (entity: Expense): CashMovementDB => {
        return {
            id: entity.id,
            actor_id: entity.created_by ?? null,
            actor_name: entity.actor_name ?? null,
            actor_role: entity.actor_role ?? null,
            amount: entity.amount,
            description: entity.description,
            category: entity.category || 'Servicios',
            payment_method: entity.payment_method || 'efectivo',
            voucher_ref: entity.voucher_ref ?? null,
            movement_type: 'gasto',
            created_at: entity.created_at || new Date().toISOString(),
            session_id: '',
            sale_id: null
        };
    }
};

const baseRepository = createSupabaseRepository<Expense, CashMovementDB>(TABLE_NAME, STORAGE_KEY, expenseMapper);

export interface ExpenseRepository extends EntityRepository<Expense> {
    getTodayExpenses(storeId: string): Promise<Expense[]>;
    createExpense(expense: Omit<Expense, 'id' | 'created_at'>): Promise<Expense>;
}

const getBogotaTodayDate = (): string =>
    new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Bogota' }).format(new Date());

export const expenseRepository: ExpenseRepository = {
    ...baseRepository,

    /**
     * Get expenses for the current business day (America/Bogota)
     */
    async getTodayExpenses(storeId: string): Promise<Expense[]> {
        const isOnline = navigator.onLine && isSupabaseConfigured();
        const today = getBogotaTodayDate();

        if (isOnline) {
            const supabase = getSupabaseClient()!;
            const { data, error } = await supabase
                .from('cash_movements')
                .select('*, cash_sessions!inner(store_id)')
                .eq('cash_sessions.store_id', storeId)
                .eq('movement_type', 'gasto')
                .gte('created_at', `${today}T00:00:00-05:00`);

            if (error) {
                logger.error('[ExpenseRepo] Online fetch failed:', error);
                throw new Error(error.message || 'Error cargando gastos del servidor');
            }

            return (data as any[]).map(row => {
                const domain = expenseMapper.toDomain(row);
                domain.store_id = storeId;
                return domain;
            });
        }

        // Offline-only cache fallback
        try {
            const allVars = await baseRepository.getAll(storeId);
            return allVars.filter(e => {
                const date = e.created_at
                    ? new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Bogota' }).format(new Date(e.created_at))
                    : '';
                return date === today;
            });
        } catch (e) {
            logger.error('[ExpenseRepo] Offline fallback failed:', e);
            return [];
        }
    },

    /**
     * Create a new expense (Regla 3: nunca retorna null en error o sin caja abierta)
     */
    async createExpense(expense: Omit<Expense, 'id' | 'created_at'>): Promise<Expense> {
        if (!navigator.onLine) {
            logger.error('[ExpenseRepo] Expense creation failed: offline not supported for minor cash expenses');
            throw new Error('No es posible registrar gastos en modo sin conexión');
        }

        if (!expense.store_id || expense.store_id.trim() === '') {
            const error = new Error('Cannot create Expense without valid store_id. This would fail RLS policies.');
            console.error('🚫 [ExpenseRepo] RLSViolationError:', error.message);
            throw error;
        }

        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        if (!uuidRegex.test(expense.store_id)) {
            const error = new Error(`Invalid UUID format for store_id: "${expense.store_id}"`);
            console.error('🚫 [ExpenseRepo] ValidationError:', error.message);
            throw error;
        }

        const status = await cashRepository.getStoreStatus(expense.store_id);
        if (!status.isOpen || !status.sessionId) {
            throw new Error('NO_OPEN_SESSION: No existe una sesión de caja abierta para registrar el gasto.');
        }

        const isOnline = navigator.onLine && isSupabaseConfigured();
        if (!isOnline) {
            throw new Error('Supabase no configurado para registrar gastos en línea.');
        }

        const supabase = getSupabaseClient()!;
        const { data, error } = await supabase.rpc('rpc_registrar_gasto_v2', {
            p_session_id: status.sessionId,
            p_amount: expense.amount,
            p_description: expense.description,
            p_category: expense.category || 'Servicios',
            p_payment_method: expense.payment_method || 'efectivo',
            p_voucher_ref: expense.voucher_ref || undefined
        });

        if (error) {
            logger.error('[ExpenseRepo] RPC Error registering expense:', error);
            throw new Error(error.message);
        }

        const res = data as any;
        if (res && res.success === false) {
            logger.error('[ExpenseRepo] Failed registering expense:', res.error);
            throw new Error(res.error || res.message || 'Error al registrar gasto');
        }

        return {
            id: res?.data?.movement_id || crypto.randomUUID(),
            store_id: expense.store_id,
            amount: expense.amount,
            description: expense.description,
            category: expense.category || 'Servicios',
            payment_method: (res?.data?.payment_method || expense.payment_method || 'efectivo') as Expense['payment_method'],
            voucher_ref: res?.data?.voucher_ref ?? expense.voucher_ref ?? null,
            actor_name: res?.data?.actor_name ?? null,
            actor_role: res?.data?.actor_role ?? null,
            created_at: res?.data?.created_at || new Date().toISOString()
        };
    }
};

export default expenseRepository;

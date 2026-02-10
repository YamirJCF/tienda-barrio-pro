import { ref, computed } from 'vue';
import { useAuthStore } from '../stores/auth';
import { auditRepository } from '../data/repositories/auditRepository';
import { getSupabaseClient } from '../data/supabaseClient';
import { logger } from '../utils/logger';
import { formatCurrency } from '../utils/currency';

export type HistoryType = 'sales' | 'cash' | 'audit' | 'inventory' | 'expenses' | 'prices';
export type DatePreset = 'today' | 'yesterday' | 'week' | 'month';

export interface HistoryItem {
    id: string;
    type: HistoryType;
    title: string;
    subtitle: string;
    date: string;
    amount?: number;
    amountFormatted?: string;
    user: string;
    icon: string;
    colorClass: string;
    badge?: { text: string; color: string };
    metadata?: any;
}

export interface HistorySummary {
    totalAmount: number;
    count: number;
    label: string;
}

/**
 * Returns {start, end} date strings for a given preset
 */
function getDateRange(preset: DatePreset): { start: string; end: string } {
    const now = new Date();
    const todayStr = now.toISOString().split('T')[0];

    switch (preset) {
        case 'today':
            return { start: todayStr, end: todayStr };
        case 'yesterday': {
            const yesterday = new Date(now);
            yesterday.setDate(yesterday.getDate() - 1);
            return { start: yesterday.toISOString().split('T')[0], end: yesterday.toISOString().split('T')[0] };
        }
        case 'week': {
            const weekAgo = new Date(now);
            weekAgo.setDate(weekAgo.getDate() - 7);
            return { start: weekAgo.toISOString().split('T')[0], end: todayStr };
        }
        case 'month': {
            const monthAgo = new Date(now);
            monthAgo.setDate(monthAgo.getDate() - 30);
            return { start: monthAgo.toISOString().split('T')[0], end: todayStr };
        }
    }
}

export function useHistory() {
    const authStore = useAuthStore();
    const isLoading = ref(false);
    const items = ref<HistoryItem[]>([]);
    const error = ref<string | null>(null);

    // Filters
    const currentType = ref<HistoryType>('sales');
    const dateFilter = ref<DatePreset>('today');
    const employeeFilter = ref<string | null>(null); // UUID or null for all

    // Summary
    const summary = computed<HistorySummary>(() => {
        const total = items.value.reduce((sum, item) => sum + (item.amount || 0), 0);
        const labels: Record<HistoryType, string> = {
            sales: 'Total Ventas',
            cash: 'Sesiones',
            audit: 'Eventos',
            inventory: 'Entradas',
            expenses: 'Total Gastos',
            prices: 'Cambios'
        };
        return {
            totalAmount: total,
            count: items.value.length,
            label: labels[currentType.value] || 'Total'
        };
    });

    const fetchHistory = async (type?: HistoryType, preset?: DatePreset) => {
        if (!authStore.currentStore) return;

        if (type) currentType.value = type;
        if (preset) dateFilter.value = preset;

        isLoading.value = true;
        error.value = null;
        items.value = [];

        const storeId = authStore.currentStore.id;

        try {
            switch (currentType.value) {
                case 'sales':
                    await fetchSalesLogs(storeId);
                    break;
                case 'cash':
                    await fetchCashLogs(storeId);
                    break;
                case 'inventory':
                    await fetchInventoryLogs(storeId);
                    break;
                case 'audit':
                    await fetchAuditLogs(storeId);
                    break;
                case 'prices':
                    await fetchPriceLogs(storeId);
                    break;
                case 'expenses':
                    await fetchExpenseLogs(storeId);
                    break;
                default:
                    items.value = [];
            }
        } catch (e: any) {
            logger.error('[useHistory] Error fetching', e);
            error.value = 'Error al cargar el historial';
        } finally {
            isLoading.value = false;
        }
    };

    // =============================================
    // Sales — via RPC get_history_ventas
    // =============================================
    const fetchSalesLogs = async (storeId: string) => {
        const supabase = getSupabaseClient();
        if (!supabase) { error.value = 'Sin conexión'; return; }

        const { start, end } = getDateRange(dateFilter.value);

        const params: any = {
            p_store_id: storeId,
            p_start_date: start,
            p_end_date: end
        };
        if (employeeFilter.value) {
            params.p_employee_id = employeeFilter.value;
        }

        const { data, error: rpcError } = await supabase.rpc('get_history_ventas' as any, params);

        if (rpcError) {
            logger.error('[useHistory] get_history_ventas RPC error', rpcError);
            error.value = 'Error al obtener ventas';
            return;
        }

        const rows = (data || []) as any[];
        items.value = rows.map(sale => {
            const paymentLabel: Record<string, string> = {
                'efectivo': '💵 Efectivo',
                'nequi': '📱 Nequi',
                'daviplata': '📱 Daviplata',
                'fiado': '📋 Fiado'
            };
            return {
                id: sale.id,
                type: 'sales' as HistoryType,
                title: `Venta #${sale.ticket_number}`,
                subtitle: `${sale.items_count} producto${sale.items_count !== 1 ? 's' : ''} · ${paymentLabel[sale.payment_method] || sale.payment_method}${sale.client_name ? ` · ${sale.client_name}` : ''}`,
                date: sale.created_at,
                amount: Number(sale.total),
                amountFormatted: formatCurrency(sale.total),
                user: sale.employee_name,
                icon: 'shopping_cart',
                colorClass: sale.is_voided
                    ? 'text-red-600 bg-red-100 dark:bg-red-900/30 dark:text-red-400'
                    : 'text-green-600 bg-green-100 dark:bg-green-900/30 dark:text-green-400',
                badge: sale.is_voided ? { text: 'Anulada', color: 'bg-red-100 text-red-700 dark:bg-red-900/50 dark:text-red-300' } : undefined,
                metadata: sale
            };
        });
    };

    // =============================================
    // Cash Sessions — via RPC get_history_caja
    // =============================================
    const fetchCashLogs = async (storeId: string) => {
        const supabase = getSupabaseClient();
        if (!supabase) { error.value = 'Sin conexión'; return; }

        const { start, end } = getDateRange(dateFilter.value);

        const { data, error: rpcError } = await supabase.rpc('get_history_caja' as any, {
            p_store_id: storeId,
            p_start_date: start,
            p_end_date: end
        });

        if (rpcError) {
            logger.error('[useHistory] get_history_caja RPC error', rpcError);
            error.value = 'Error al obtener historial de caja';
            return;
        }

        const rows = (data || []) as any[];
        items.value = rows.map(session => {
            const isClosed = session.status === 'closed';
            const diffNum = Number(session.difference || 0);
            const diffText = diffNum === 0 ? 'Cuadrada' : diffNum > 0 ? `Sobrante: ${formatCurrency(Math.abs(diffNum))}` : `Faltante: ${formatCurrency(Math.abs(diffNum))}`;

            return {
                id: session.id,
                type: 'cash' as HistoryType,
                title: isClosed ? 'Turno Cerrado' : '🟢 Turno Abierto',
                subtitle: isClosed
                    ? `Base: ${formatCurrency(session.opening_balance)} · Ingresos: ${formatCurrency(session.total_income)} · ${diffText}`
                    : `Base: ${formatCurrency(session.opening_balance)} · ${session.total_movements} movimientos`,
                date: isClosed ? session.closed_at : session.opened_at,
                amount: Number(session.opening_balance) + Number(session.total_income) - Number(session.total_expenses),
                amountFormatted: isClosed ? formatCurrency(session.actual_balance) : formatCurrency(Number(session.opening_balance) + Number(session.total_income)),
                user: isClosed ? `${session.opened_by_name} → ${session.closed_by_name}` : session.opened_by_name,
                icon: 'vault',
                colorClass: isClosed
                    ? 'text-slate-600 bg-slate-100 dark:bg-slate-800 dark:text-slate-300'
                    : 'text-emerald-600 bg-emerald-100 dark:bg-emerald-900/30 dark:text-emerald-400',
                badge: isClosed
                    ? { text: 'Cerrado', color: 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300' }
                    : { text: 'Abierto', color: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/50 dark:text-emerald-300' },
                metadata: session
            };
        });
    };

    // =============================================
    // Inventory (Compras) — via RPC get_history_compras
    // =============================================
    const fetchInventoryLogs = async (storeId: string) => {
        const supabase = getSupabaseClient();
        if (!supabase) { error.value = 'Sin conexión'; return; }

        const { start, end } = getDateRange(dateFilter.value);

        const { data, error: rpcError } = await supabase.rpc('get_history_compras' as any, {
            p_store_id: storeId,
            p_start_date: start,
            p_end_date: end
        });

        if (rpcError) {
            logger.error('[useHistory] get_history_compras RPC error', rpcError);
            error.value = 'Error al obtener historial de compras';
            return;
        }

        const rows = (data || []) as any[];
        items.value = rows.map(mov => {
            const supplier = mov.supplier_name ? ` · Proveedor: ${mov.supplier_name}` : '';
            const invoice = mov.invoice_reference ? ` · Ref: ${mov.invoice_reference}` : '';
            const payment = mov.payment_type ? ` · ${mov.payment_type}` : '';

            return {
                id: mov.id,
                type: 'inventory' as HistoryType,
                title: `📦 ${mov.product_name}`,
                subtitle: `+${mov.quantity} unidades${supplier}${invoice}${payment}`,
                date: mov.created_at,
                user: mov.created_by_name,
                icon: 'package',
                colorClass: 'text-indigo-600 bg-indigo-100 dark:bg-indigo-900/30 dark:text-indigo-400',
                metadata: mov
            };
        });
    };

    // =============================================
    // Audit Logs (existing logic, preserved)
    // =============================================
    const fetchAuditLogs = async (storeId: string) => {
        const logs = await auditRepository.getLogs(storeId, 50);
        items.value = logs.map(log => ({
            id: log.id,
            type: 'audit' as HistoryType,
            title: mapAuditEventTitle(log.event_type),
            subtitle: log.details?.description || 'Evento del sistema',
            date: log.created_at,
            user: log.user_name || 'Sistema',
            icon: getAuditIcon(log.event_type),
            colorClass: getAuditColor(log.severity),
            metadata: log
        }));
    };

    // =============================================
    // Price Logs (existing logic, preserved)
    // =============================================
    const fetchPriceLogs = async (storeId: string) => {
        const logs = await auditRepository.getPriceChangeLogs(storeId, 50);
        items.value = logs.map(log => ({
            id: log.id,
            type: 'prices' as HistoryType,
            title: `Cambio: ${log.productName}`,
            subtitle: `Anterior: ${formatCurrency(log.oldPrice)} → Nuevo: ${formatCurrency(log.newPrice)}`,
            date: log.date,
            user: log.employeeName || 'Desconocido',
            icon: 'price_change',
            colorClass: 'text-purple-600 bg-purple-100 dark:bg-purple-900/30 dark:text-purple-400',
            metadata: log
        }));
    };

    // =============================================
    // Expenses (existing, uses expenseRepository)
    // =============================================
    const fetchExpenseLogs = async (storeId: string) => {
        const { expenseRepository } = await import('../data/repositories/expenseRepository');
        const expenses = await expenseRepository.getTodayExpenses(storeId);
        items.value = expenses.map(exp => ({
            id: exp.id,
            type: 'expenses' as HistoryType,
            title: exp.category || 'Gasto',
            subtitle: exp.description,
            date: exp.created_at || '',
            amount: exp.amount,
            amountFormatted: formatCurrency(exp.amount),
            user: 'Cajero',
            icon: 'payments',
            colorClass: 'text-orange-600 bg-orange-100 dark:bg-orange-900/30 dark:text-orange-400',
            metadata: exp
        }));
    };

    // Utils
    const mapAuditEventTitle = (type: string) => {
        const map: Record<string, string> = {
            'login_success': 'Inicio de Sesión',
            'login_failed': 'Intento Fallido',
            'pin_change': 'Cambio de PIN',
            'unauthorized_access': 'Acceso Denegado'
        };
        return map[type] || type;
    };

    const getAuditIcon = (type: string) => {
        if (type.includes('login')) return 'login';
        if (type.includes('pin')) return 'lock';
        return 'shield';
    };

    const getAuditColor = (severity: string) => {
        if (severity === 'critical') return 'text-red-600 bg-red-100 dark:bg-red-900/30 dark:text-red-400';
        if (severity === 'warning') return 'text-amber-600 bg-amber-100 dark:bg-amber-900/30 dark:text-amber-400';
        return 'text-blue-600 bg-blue-100 dark:bg-blue-900/30 dark:text-blue-400';
    };

    return {
        items,
        isLoading,
        error,
        currentType,
        dateFilter,
        employeeFilter,
        summary,
        fetchHistory,
        getDateRange
    };
}

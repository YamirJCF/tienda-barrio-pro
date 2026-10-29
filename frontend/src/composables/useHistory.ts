import { ref, computed } from 'vue';
import { useAuthStore } from '../stores/auth';
import { auditRepository } from '../data/repositories/auditRepository';
import { getSupabaseClient } from '../data/supabaseClient';
import { logger } from '../utils/logger';
import { formatCurrency } from '../utils/currency';
import { parseHistoryShortcuts, type EmployeeRef } from '../utils/historyShortcutParser';

export type HistoryType = 'sales' | 'cash' | 'audit' | 'inventory' | 'expenses' | 'prices' | 'credits';
export type DatePreset = 'today' | 'yesterday' | 'week' | 'month' | 'custom';

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
    totalAmount?: number;
    count: number;
    label: string;
}

function toLocalDateStr(d: Date): string {
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
}

/**
 * Returns {start, end} date strings for a given preset.
 * For 'custom', uses externally provided dates.
 */
function getDateRange(preset: DatePreset, customStart?: string, customEnd?: string): { start: string; end: string } {
    const now = new Date();
    const todayStr = toLocalDateStr(now);

    switch (preset) {
        case 'today':
            return { start: todayStr, end: todayStr };
        case 'yesterday': {
            const yesterday = new Date(now);
            yesterday.setDate(yesterday.getDate() - 1);
            const yesterdayStr = toLocalDateStr(yesterday);
            return { start: yesterdayStr, end: yesterdayStr };
        }
        case 'week': {
            const weekAgo = new Date(now);
            weekAgo.setDate(weekAgo.getDate() - 7);
            return { start: toLocalDateStr(weekAgo), end: todayStr };
        }
        case 'month': {
            const monthAgo = new Date(now);
            monthAgo.setDate(monthAgo.getDate() - 30);
            return { start: toLocalDateStr(monthAgo), end: todayStr };
        }
        case 'custom': {
            return {
                start: customStart || todayStr,
                end: customEnd || todayStr
            };
        }
    }
}

function isDateWithinRange(dateStr?: string, startStr?: string, endStr?: string): boolean {
    if (!dateStr || !startStr || !endStr) return true;
    const itemDate = dateStr.slice(0, 10);
    return itemDate >= startStr && itemDate <= endStr;
}

export function useHistory() {
    const authStore = useAuthStore();
    const isLoading = ref(false);
    const items = ref<HistoryItem[]>([]);
    const error = ref<string | null>(null);

    // Filters (FRD-005 Regla 6: Por defecto muestra los últimos 7 días)
    const currentType = ref<HistoryType>('sales');
    const dateFilter = ref<DatePreset>('week');
    const employeeFilter = ref<string | null>(null); // UUID or null for all
    const eventTypeFilter = ref<string>('all');
    const paymentMethodFilter = ref<string>('all'); // 'all', 'efectivo', 'digital', 'nequi', 'daviplata'

    // Custom date range
    const customStartDate = ref<string>('');
    const customEndDate = ref<string>('');

    // Search
    const searchQuery = ref<string>('');

    // Filtered items — client-side search and filters over loaded data
    const filteredItems = computed<HistoryItem[]>(() => {
        let result = items.value;

        // Apply employee filter
        if (employeeFilter.value) {
            const empId = employeeFilter.value;
            result = result.filter(item => {
                const m = item.metadata || {};
                if (m.employee_id === empId || m.cashier_id === empId || m.user_id === empId || m.created_by === empId) {
                    return true;
                }
                if (item.user && item.user.toLowerCase().includes(empId.toLowerCase())) {
                    return true;
                }
                return false;
            });
        }

        // Apply event type filter
        if (eventTypeFilter.value && eventTypeFilter.value.toLowerCase() !== 'all') {
            const ef = eventTypeFilter.value.toLowerCase();
            result = result.filter(item => {
                const m = item.metadata || {};
                const et = (m.event_type || m.transaction_type || '').toLowerCase();

                // Sales
                if (currentType.value === 'sales') {
                    if (ef === 'cancellations' || ef === 'anulaciones') return Boolean(m.is_voided);
                    if (ef === 'creations' || ef === 'creaciones') return !m.is_voided;
                }

                // Inventory / Compras
                if (currentType.value === 'inventory') {
                    if (ef === 'entries' || ef === 'entradas') return (m.quantity || 0) > 0 || et === 'entry';
                    if (ef === 'adjustments' || ef === 'ajustes') return et === 'adjustment' || et === 'ajuste';
                }

                // Cash
                if (currentType.value === 'cash') {
                    return et.includes(ef);
                }

                // Audit
                if (currentType.value === 'audit') {
                    return et.includes(ef) || (item.title && item.title.toLowerCase().includes(ef));
                }

                return et === ef;
            });
        }

        // Apply payment method filter (Multichannel - FRD-021)
        if (paymentMethodFilter.value && paymentMethodFilter.value.toLowerCase() !== 'all') {
            const pmKey = paymentMethodFilter.value.toLowerCase();
            result = result.filter(item => {
                const m = item.metadata;
                if (!m) return false;
                
                const pm = (m.payment_method || m.payment_type || '').toLowerCase();
                if (!pm) return false;

                if (pmKey === 'digital') {
                    return pm === 'nequi' || pm === 'daviplata' || pm === 'digital';
                }
                
                return pm === pmKey;
            });
        }

        // Apply free text search
        const q = searchQuery.value.trim().toLowerCase();
        if (!q) return result;

        return result.filter(item => {
            if (item.title.toLowerCase().includes(q)) return true;
            if (item.subtitle.toLowerCase().includes(q)) return true;
            if (item.user.toLowerCase().includes(q)) return true;

            const m = item.metadata;
            if (!m) return false;

            if (m.client_name && String(m.client_name).toLowerCase().includes(q)) return true;
            if (m.product_name && String(m.product_name).toLowerCase().includes(q)) return true;
            if (m.supplier_name && String(m.supplier_name).toLowerCase().includes(q)) return true;
            if (m.ticket_number && String(m.ticket_number).includes(q)) return true;
            if (m.payment_method && String(m.payment_method).toLowerCase().includes(q)) return true;

            return false;
        });
    });

    // Summary — cumple SPEC-010/011 (no suma montos financieros en frontend)
    const summary = computed<HistorySummary>(() => {
        const labels: Record<HistoryType, string> = {
            sales: 'Total Ventas',
            cash: 'Sesiones',
            audit: 'Eventos',
            inventory: 'Entradas',
            expenses: 'Total Gastos',
            prices: 'Cambios',
            credits: 'Movimientos'
        };
        return {
            count: filteredItems.value.length,
            label: labels[currentType.value] || 'Total'
        };
    });

    const activeDateLabel = computed<string>(() => {
        switch (dateFilter.value) {
            case 'today': return 'Hoy';
            case 'yesterday': return 'Ayer';
            case 'week': return 'Últimos 7 días';
            case 'month': return 'Últimos 30 días';
            case 'custom': return `${customStartDate.value || '...'} a ${customEndDate.value || '...'}`;
            default: return 'Período';
        }
    });

    const hasActiveFilters = computed<boolean>(() => {
        return (
            dateFilter.value !== 'week' ||
            paymentMethodFilter.value.toLowerCase() !== 'all' ||
            eventTypeFilter.value.toLowerCase() !== 'all' ||
            employeeFilter.value !== null ||
            searchQuery.value.trim().length > 0
        );
    });

    const setCustomDateRange = async (start: string, end: string) => {
        customStartDate.value = start;
        customEndDate.value = end;
        dateFilter.value = 'custom';
        await fetchHistory();
    };

    const resetFilters = async () => {
        searchQuery.value = '';
        paymentMethodFilter.value = 'all';
        eventTypeFilter.value = 'all';
        employeeFilter.value = null;
        customStartDate.value = '';
        customEndDate.value = '';
        if (dateFilter.value !== 'week') {
            dateFilter.value = 'week';
            await fetchHistory();
        }
    };

    const applyShortcutQuery = async (rawQuery: string, employees?: EmployeeRef[]) => {
        const { freeText, patches, matchedCount } = parseHistoryShortcuts(rawQuery, employees);
        let needsRefetch = false;

        if (patches.domain && patches.domain !== currentType.value) {
            currentType.value = patches.domain;
            needsRefetch = true;
        }
        if (patches.datePreset && patches.datePreset !== dateFilter.value) {
            dateFilter.value = patches.datePreset;
            needsRefetch = true;
        }
        if (patches.paymentMethod) {
            paymentMethodFilter.value = patches.paymentMethod;
        }
        if (patches.eventType) {
            eventTypeFilter.value = patches.eventType;
        }
        if (patches.employeeId !== undefined) {
            employeeFilter.value = patches.employeeId;
        }

        if (needsRefetch) {
            await fetchHistory();
        }

        searchQuery.value = freeText;

        return { matchedCount, freeText };
    };

    const fetchHistory = async (type?: HistoryType, preset?: DatePreset) => {
        if (!authStore.currentStore) return;

        if (type && type !== currentType.value) {
            currentType.value = type;
            eventTypeFilter.value = 'all'; // reset event filter on type change
        }
        if (preset) dateFilter.value = preset;

        // Clear search when switching type/period
        searchQuery.value = '';

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
                case 'credits':
                    await fetchCreditLogs(storeId);
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

        const { start, end } = getDateRange(dateFilter.value, customStartDate.value, customEndDate.value);

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

        const { start, end } = getDateRange(dateFilter.value, customStartDate.value, customEndDate.value);

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
            const isForced = Boolean(session.forced_close);
            const hasActualBalance = session.actual_balance !== null && session.actual_balance !== undefined;
            const hasDifference = session.difference !== null && session.difference !== undefined;
            const isPendingReconciliation =
                isClosed &&
                (session.reconciliation_status === 'forced_pending_reconciliation' || !hasActualBalance);

            let diffText: string;
            if (isPendingReconciliation) {
                diffText = 'Pendiente de reconciliación';
            } else if (!hasDifference) {
                diffText = 'Sin arqueo';
            } else {
                const diffNum = Number(session.difference);
                diffText = diffNum === 0
                    ? 'Cuadrada'
                    : diffNum > 0
                        ? `Sobrante: ${formatCurrency(Math.abs(diffNum))}`
                        : `Faltante: ${formatCurrency(Math.abs(diffNum))}`;
            }

            const title = !isClosed
                ? '🟢 Turno Abierto'
                : isPendingReconciliation
                    ? '⚠️ Cierre Forzado (24h)'
                    : isForced
                        ? 'Turno Cerrado (Reconciliado)'
                        : 'Turno Cerrado';

            const netBalance = session.net_session_balance ?? session.expected_balance ?? session.opening_balance;
            const hasExpectedBalance = session.expected_balance !== null && session.expected_balance !== undefined;

            const amountFormatted = !isClosed
                ? formatCurrency(netBalance)
                : isPendingReconciliation
                    ? (hasExpectedBalance ? `Esp: ${formatCurrency(session.expected_balance)}` : 'Pendiente arqueo')
                    : formatCurrency(session.actual_balance);

            const closedByLabel = session.closed_by_name || (isForced ? 'Sistema (24h)' : 'Sin registro');
            const eventType = session.event_type || (isClosed ? 'CIERRE' : 'APERTURA');

            const colorClass = !isClosed
                ? 'text-emerald-600 bg-emerald-100 dark:bg-emerald-900/30 dark:text-emerald-400'
                : isPendingReconciliation
                    ? 'text-amber-600 bg-amber-100 dark:bg-amber-900/30 dark:text-amber-400'
                    : 'text-slate-600 bg-slate-100 dark:bg-slate-800 dark:text-slate-300';

            const badge = !isClosed
                ? { text: 'Abierto', color: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/50 dark:text-emerald-300' }
                : isPendingReconciliation
                    ? { text: 'Sin Reconciliar', color: 'bg-amber-100 text-amber-700 dark:bg-amber-900/50 dark:text-amber-300' }
                    : isForced
                        ? { text: 'Forzado · Reconciliado', color: 'bg-orange-100 text-orange-700 dark:bg-orange-900/50 dark:text-orange-300' }
                        : { text: 'Cerrado', color: 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300' };

            return {
                id: session.id,
                type: 'cash' as HistoryType,
                title,
                subtitle: isClosed
                    ? `Base: ${formatCurrency(session.opening_balance)} · Ingresos: ${formatCurrency(session.total_income)} · ${diffText}`
                    : `Base: ${formatCurrency(session.opening_balance)} · ${session.total_movements} movimientos`,
                date: isClosed ? (session.closed_at || session.opened_at) : session.opened_at,
                amount: isClosed && hasActualBalance ? Number(session.actual_balance) : Number(netBalance),
                amountFormatted,
                user: isClosed ? `${session.opened_by_name} → ${closedByLabel}` : session.opened_by_name,
                icon: 'vault',
                colorClass,
                badge,
                metadata: { ...session, event_type: eventType }
            };
        });
    };

    // =============================================
    // Inventory (Compras) — via RPC get_history_compras
    // =============================================
    const fetchInventoryLogs = async (storeId: string) => {
        const supabase = getSupabaseClient();
        if (!supabase) { error.value = 'Sin conexión'; return; }

        const { start, end } = getDateRange(dateFilter.value, customStartDate.value, customEndDate.value);

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
    // Audit Logs (FRD-005)
    // =============================================
    const fetchAuditLogs = async (storeId: string) => {
        const { start, end } = getDateRange(dateFilter.value, customStartDate.value, customEndDate.value);
        const logs = await auditRepository.getLogs(storeId, 200);
        const filteredLogs = logs.filter(log => isDateWithinRange(log.created_at, start, end));

        items.value = filteredLogs.map(log => ({
            id: log.id,
            type: 'audit' as HistoryType,
            title: mapAuditEventTitle(log.event_type),
            subtitle: log.details?.description || 'Evento del sistema',
            date: log.created_at,
            user: log.user_name || 'Sistema',
            icon: getAuditIcon(log.event_type),
            colorClass: getAuditColor(log.severity),
            metadata: { ...log, event_type: log.event_type }
        }));
    };

    // =============================================
    // Price Logs (FRD-010)
    // =============================================
    const fetchPriceLogs = async (storeId: string) => {
        const { start, end } = getDateRange(dateFilter.value, customStartDate.value, customEndDate.value);
        const logs = await auditRepository.getPriceChangeLogs(storeId, 200);
        const filteredLogs = logs.filter(log => isDateWithinRange(log.date, start, end));

        items.value = filteredLogs.map(log => ({
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
    // Expenses
    // =============================================
    const fetchExpenseLogs = async (storeId: string) => {
        const { start, end } = getDateRange(dateFilter.value, customStartDate.value, customEndDate.value);
        const { expenseRepository } = await import('../data/repositories/expenseRepository');
        const expenses = await expenseRepository.getTodayExpenses(storeId);
        const filtered = expenses.filter(exp => isDateWithinRange(exp.created_at, start, end));

        items.value = filtered.map(exp => ({
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

    // =============================================
    // Credits — via RPC get_history_creditos
    // =============================================
    const fetchCreditLogs = async (storeId: string) => {
        const supabase = getSupabaseClient();
        if (!supabase) { error.value = 'Sin conexión'; return; }

        const { start, end } = getDateRange(dateFilter.value, customStartDate.value, customEndDate.value);

        const { data, error: rpcError } = await supabase.rpc('get_history_creditos' as any, {
            p_store_id: storeId,
            p_start_date: start,
            p_end_date: end
        });

        if (rpcError) {
            logger.error('[useHistory] get_history_creditos RPC error', rpcError);
            error.value = 'Error al obtener historial de créditos';
            return;
        }

        const rows = (data || []) as any[];
        items.value = rows.map(cred => {
            const isPayment = cred.transaction_type === 'payment';
            return {
                id: cred.id,
                type: 'credits' as HistoryType,
                title: cred.client_name || 'Cliente',
                subtitle: cred.description || (isPayment ? 'Abono' : 'Nueva deuda'),
                date: cred.created_at,
                amount: Number(cred.amount),
                amountFormatted: formatCurrency(cred.amount),
                user: cred.employee_name || 'Desconocido',
                icon: 'credit_card',
                colorClass: isPayment
                    ? 'text-emerald-600 bg-emerald-100 dark:bg-emerald-900/30 dark:text-emerald-400'
                    : 'text-red-600 bg-red-100 dark:bg-red-900/30 dark:text-red-400',
                metadata: { ...cred, event_type: cred.transaction_type }
            };
        });
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
        filteredItems,
        isLoading,
        error,
        currentType,
        dateFilter,
        employeeFilter,
        eventTypeFilter,
        paymentMethodFilter,
        searchQuery,
        customStartDate,
        customEndDate,
        summary,
        activeDateLabel,
        hasActiveFilters,
        fetchHistory,
        setCustomDateRange,
        getDateRange,
        resetFilters,
        applyShortcutQuery
    };
}

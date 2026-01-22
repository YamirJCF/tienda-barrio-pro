import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';
import { useAuthStore } from '../stores/auth';
import { auditRepository } from '../data/repositories/auditRepository';
import { saleRepository } from '../data/repositories/saleRepository';
import { expenseRepository } from '../data/repositories/expenseRepository';
import { productRepository } from '../data/repositories/productRepository';
import { logger } from '../utils/logger';
import { formatCurrency } from '../utils/currency';
import { formatRelativeTime } from './useRelativeTime';

export type HistoryType = 'sales' | 'cash' | 'audit' | 'inventory' | 'expenses' | 'prices';

export interface HistoryItem {
    id: string;
    type: HistoryType;
    title: string;
    subtitle: string;
    date: string;
    amount?: number;
    amountFormatted?: string; // Optional pre-formatted amount
    user: string;
    icon: string;
    colorClass: string;
    metadata?: any; // Original raw data for detail view
}

export function useHistory() {
    const authStore = useAuthStore();
    const isLoading = ref(false);
    const items = ref<HistoryItem[]>([]);
    const error = ref<string | null>(null);

    // Filters
    const currentType = ref<HistoryType>('sales');
    const dateFilter = ref<'today' | 'week' | 'month'>('today');

    const fetchHistory = async (type: HistoryType = currentType.value) => {
        if (!authStore.currentStore) return;

        isLoading.value = true;
        error.value = null;
        currentType.value = type;
        items.value = [];

        const storeId = authStore.currentStore.id;

        try {
            // Logic to fetch based on type
            switch (type) {
                case 'audit':
                    await fetchAuditLogs(storeId);
                    break;
                case 'prices':
                    await fetchPriceLogs(storeId);
                    break;
                case 'inventory':
                    // For inventory, we usually need a specific product, but global movement history 
                    // might be heavy. We'll fetch recent movements for ALL products if possible
                    // or we might need to adjust repo to allow global fetch.
                    // For now, let's assume specific product or limited global fetch?
                    // The repo has getMovementHistory(limit). I'll check if it filters by product required.
                    // It requires productId. We might need a "getAllMovements" in repo.
                    // Fallback: Show empty or "Select Product" hint?
                    // Actually, SPEC-009 says "Kardex de Inventario". A global view is useful.
                    // I will fetch empty for now and note it, or hack a "recent global" endpoint.
                    await fetchInventoryLogs(storeId);
                    break;
                case 'sales':
                    await fetchSalesLogs(storeId);
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

    // Mappers
    const fetchAuditLogs = async (storeId: string) => {
        const logs = await auditRepository.getLogs(storeId, 50);
        items.value = logs.map(log => ({
            id: log.id,
            type: 'audit',
            title: mapAuditEventTitle(log.event_type),
            subtitle: log.details?.description || 'Evento del sistema',
            date: log.created_at,
            user: log.user_name || 'Sistema',
            icon: getAuditIcon(log.event_type),
            colorClass: getAuditColor(log.severity),
            metadata: log
        }));
    };

    const fetchPriceLogs = async (storeId: string) => {
        const logs = await auditRepository.getPriceChangeLogs(storeId, 50);
        items.value = logs.map(log => ({
            id: log.id,
            type: 'prices',
            title: `Cambio: ${log.productName}`,
            subtitle: `Anterior: ${formatCurrency(log.oldPrice)} → Nuevo: ${formatCurrency(log.newPrice)}`,
            date: log.date,
            user: log.employeeName || 'Desconocido',
            icon: 'price_change',
            colorClass: 'text-purple-600 bg-purple-100 dark:bg-purple-900/30 dark:text-purple-400',
            metadata: log
        }));
    };

    const fetchSalesLogs = async (storeId: string) => {
        // We need getByDateRange. For 'today', we simulate range.
        const now = new Date();
        const todayStr = now.toISOString().split('T')[0];
        const start = `${todayStr}T00:00:00`;
        const end = `${todayStr}T23:59:59`;

        // Using saleRepository
        const sales = await saleRepository.getByDateRange(start, end, storeId);
        items.value = sales.map(sale => ({
            id: sale.id,
            type: 'sales',
            title: `Venta #${sale.id.slice(0, 8)}`,
            subtitle: `${sale.items?.length || 0} productos - ${sale.paymentMethod || 'Efectivo'}`,
            date: sale.timestamp || '',
            amount: new Decimal(sale.total || 0).toNumber(),
            amountFormatted: formatCurrency(sale.total),
            user: 'Cajero', // TODO: Join with employee name if available in sale object
            icon: 'shopping_cart',
            colorClass: 'text-green-600 bg-green-100 dark:bg-green-900/30 dark:text-green-400',
            metadata: sale
        }));
    };

    const fetchExpenseLogs = async (storeId: string) => {
        const expenses = await expenseRepository.getTodayExpenses(storeId);
        items.value = expenses.map(exp => ({
            id: exp.id,
            type: 'expenses',
            title: exp.category || 'Gasto',
            subtitle: exp.description,
            date: exp.created_at || '',
            amount: exp.amount,
            amountFormatted: formatCurrency(exp.amount),
            user: 'Cajero', // Repository needs update to fetch names
            icon: 'payments',
            colorClass: 'text-orange-600 bg-orange-100 dark:bg-orange-900/30 dark:text-orange-400',
            metadata: exp
        }));
    };

    // Helper for inventory (placeholder)
    const fetchInventoryLogs = async (storeId: string) => {
        // TODO: Implement global inventory history in Repo
        items.value = [];
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
        fetchHistory
    };
}

import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { getSupabaseClient } from '../data/supabaseClient';
import { useAuthStore } from './auth';

// --- Interfaces matching RPC payloads ---

export interface FinancialSummary {
    total_sales: number;
    total_cost: number;
    net_profit: number;
    profit_margin: number;
    money_breakdown: { cash: number; transfer: number; credit: number };
    fiado_pendiente: number;
    traffic_light: { status: 'green' | 'red' | 'gray'; message: string };
}

export interface TopProduct {
    product_id: string;
    product_name: string;
    units_sold: number;
    revenue: number;
    profit: number;
    stock_remaining: number;
    stock_status: 'ok' | 'low' | 'critical' | 'out';
}

export interface StagnantProduct {
    product_id: string;
    product_name: string;
    last_sale_date: string | null;
    days_stagnant: number;
    stock_value: number;
}

export type PeriodType = 'today' | 'week' | 'month';

export const useFinancialStore = defineStore('financial', () => {
    // State
    const summary = ref<FinancialSummary | null>(null);
    const topProducts = ref<TopProduct[]>([]);
    const stagnantProducts = ref<StagnantProduct[]>([]);
    const isLoading = ref(false);
    const error = ref<string | null>(null);
    const activePeriod = ref<PeriodType>('today');

    // Dependencies
    const authStore = useAuthStore();

    // --- Helpers ---

    function getDateRange(period: PeriodType): { start: string; end: string } {
        const today = new Date();
        const end = today.toISOString().split('T')[0]; // YYYY-MM-DD

        switch (period) {
            case 'week': {
                const weekAgo = new Date(today);
                weekAgo.setDate(today.getDate() - 6); // Include today = 7 days
                return { start: weekAgo.toISOString().split('T')[0], end };
            }
            case 'month': {
                const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
                return { start: monthStart.toISOString().split('T')[0], end };
            }
            default: // 'today'
                return { start: end, end };
        }
    }

    // --- Actions ---

    const fetchFinancialSummary = async (startDate: string, endDate: string) => {
        const supabase = getSupabaseClient();
        if (!supabase || !authStore.currentUser?.storeId) return;

        const { data, error: rpcError } = await supabase.rpc('get_financial_summary', {
            p_store_id: authStore.currentUser.storeId,
            p_start_date: startDate,
            p_end_date: endDate,
        });

        if (rpcError) throw rpcError;
        summary.value = data as FinancialSummary;
    };

    const fetchTopProducts = async (startDate: string, endDate: string, limit = 10) => {
        const supabase = getSupabaseClient();
        if (!supabase || !authStore.currentUser?.storeId) return;

        const { data, error: rpcError } = await supabase.rpc('get_top_selling_products', {
            p_store_id: authStore.currentUser.storeId,
            p_start_date: startDate,
            p_end_date: endDate,
            p_limit: limit,
        });

        if (rpcError) throw rpcError;
        topProducts.value = (data ?? []) as TopProduct[];
    };

    const fetchStagnantProducts = async (threshold = 30) => {
        const supabase = getSupabaseClient();
        if (!supabase || !authStore.currentUser?.storeId) return;

        const { data, error: rpcError } = await supabase.rpc('get_stagnant_products', {
            p_store_id: authStore.currentUser.storeId,
            p_days_threshold: threshold,
        });

        if (rpcError) throw rpcError;
        stagnantProducts.value = (data ?? []) as StagnantProduct[];
    };

    /** Coordina la carga de los 3 datasets según el período seleccionado */
    const setPeriod = async (period: PeriodType) => {
        // Guard: prevent concurrent calls (QA #6)
        if (isLoading.value) return;

        activePeriod.value = period;
        isLoading.value = true;
        error.value = null;

        try {
            const { start, end } = getDateRange(period);

            // Use allSettled to allow partial data display (QA #4)
            const results = await Promise.allSettled([
                fetchFinancialSummary(start, end),
                fetchTopProducts(start, end),
                fetchStagnantProducts(),
            ]);

            // Log individual failures but keep partial data
            results.forEach((result, i) => {
                if (result.status === 'rejected') {
                    console.warn(`[FinancialStore] Fetch #${i} failed:`, result.reason);
                }
            });

            // If ALL failed, set error state
            const allFailed = results.every(r => r.status === 'rejected');
            if (allFailed) {
                const firstError = (results[0] as PromiseRejectedResult).reason;
                throw firstError;
            }
        } catch (err: any) {
            console.error('[FinancialStore] Error loading data:', err);
            error.value = err.message || 'Error al cargar los datos financieros';
            summary.value = null;
            topProducts.value = [];
            stagnantProducts.value = [];
        } finally {
            isLoading.value = false;
        }
    };

    // --- Computed ---

    // EXCEPCIÓN DOCUMENTADA (QA #3): Este reduce NO calcula valores de negocio.
    // Solo suma stock_value ya calculado por el RPC get_stagnant_products.
    // Reclasificado como agregación de presentación (UX), no lógica financiera.
    const totalStagnantValue = computed(() =>
        stagnantProducts.value.reduce((sum, p) => sum + Number(p.stock_value ?? 0), 0)
    );

    return {
        // State
        summary,
        topProducts,
        stagnantProducts,
        isLoading,
        error,
        activePeriod,

        // Computed
        totalStagnantValue,

        // Actions
        fetchFinancialSummary,
        fetchTopProducts,
        fetchStagnantProducts,
        setPeriod,
    };
});

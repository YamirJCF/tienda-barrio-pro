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

// NUEVAS INTERFACES (Reportes v2.0)
export interface InventoryHealth {
    valor_total: number;
    dias_inventario: number;
    estado: 'optimo' | 'riesgo' | 'saludable' | 'sobre_inventario' | 'desconocido';
    distribucion_rotacion: {
        rapida: { count: number; valor: number; porcentaje: number };
        normal: { count: number; valor: number; porcentaje: number };
        lenta: { count: number; valor: number; porcentaje: number };
    };
}

export interface ClientLedgerSummary {
    cartera_total: number;
    cartera_vencida: number;
    clientes_con_deuda: number;
    clientes_morosos: number;
    top_deudores: Array<{
        client_id: string;
        client_name: string;
        balance: number;
        dias_sin_pagar: number;
        ultima_compra: string;
    }>;
}

export interface TopProductUnit {
    product_id: string;
    product_name: string;
    units_sold: number;
    dias_rotacion: number;
    stock_actual: number;
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
    // State - Snapshots (Static for the session)
    const inventoryHealth = ref<InventoryHealth | null>(null);
    const clientLedger = ref<ClientLedgerSummary | null>(null);
    const stagnantProducts = ref<StagnantProduct[]>([]);
    
    // State - Time-Series (Dynamic based on period)
    const summary = ref<FinancialSummary | null>(null);
    const topProductsByUnits = ref<TopProductUnit[]>([]);
    
    const isLoadingSnapshots = ref(false);
    const isLoadingTimeSeries = ref(false);
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

    // --- Actions: SNAPSHOTS (Load Once) ---
    
    const fetchInventoryHealth = async () => {
        const supabase = getSupabaseClient();
        if (!supabase || !authStore.currentUser?.storeId) return;
        const { data, error: rpcError } = await supabase.rpc('get_inventory_health', {
            p_store_id: authStore.currentUser.storeId
        });
        if (rpcError) throw rpcError;
        inventoryHealth.value = data as InventoryHealth;
    };

    const fetchClientLedgerSummary = async () => {
        const supabase = getSupabaseClient();
        if (!supabase || !authStore.currentUser?.storeId) return;
        const { data, error: rpcError } = await supabase.rpc('get_client_ledger_summary', {
            p_store_id: authStore.currentUser.storeId
        });
        if (rpcError) throw rpcError;
        clientLedger.value = data as ClientLedgerSummary;
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
    
    const loadSnapshots = async () => {
        if (isLoadingSnapshots.value) return;
        isLoadingSnapshots.value = true;
        try {
            await Promise.allSettled([
                fetchInventoryHealth(),
                fetchClientLedgerSummary(),
                fetchStagnantProducts()
            ]);
        } catch (err: any) {
            console.error('[FinancialStore] Error loading snapshots:', err);
        } finally {
            isLoadingSnapshots.value = false;
        }
    };

    // --- Actions: TIME-SERIES (Load on Period Change) ---

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

    const fetchTopProductsByUnits = async (startDate: string, endDate: string, limit = 10) => {
        const supabase = getSupabaseClient();
        if (!supabase || !authStore.currentUser?.storeId) return;
        const { data, error: rpcError } = await supabase.rpc('get_top_products_by_units', {
            p_store_id: authStore.currentUser.storeId,
            p_start_date: startDate,
            p_end_date: endDate,
            p_limit: limit,
        });
        if (rpcError) throw rpcError;
        topProductsByUnits.value = (data ?? []) as TopProductUnit[];
    };

    /** Carga estricta de la serie de tiempo según el periodo seleccionado */
    const setPeriod = async (period: PeriodType) => {
        if (isLoadingTimeSeries.value) return;
        activePeriod.value = period;
        isLoadingTimeSeries.value = true;
        error.value = null;

        try {
            const { start, end } = getDateRange(period);
            const results = await Promise.allSettled([
                fetchFinancialSummary(start, end),
                fetchTopProductsByUnits(start, end)
            ]);

            results.forEach((result, i) => {
                if (result.status === 'rejected') {
                    console.warn(`[FinancialStore] Fetch TimeSeries #${i} failed:`, result.reason);
                }
            });

            const allFailed = results.every(r => r.status === 'rejected');
            if (allFailed) throw (results[0] as PromiseRejectedResult).reason;
            
        } catch (err: any) {
            console.error('[FinancialStore] Error loading time-series data:', err);
            error.value = err.message || 'Error al cargar los datos financieros del periodo';
            summary.value = null;
            topProductsByUnits.value = [];
        } finally {
            isLoadingTimeSeries.value = false;
        }
    };

    // --- Computed ---
    const totalStagnantValue = computed(() =>
        stagnantProducts.value.reduce((sum, p) => sum + Number(p.stock_value ?? 0), 0)
    );

    return {
        // State Arrays/Objects
        inventoryHealth,
        clientLedger,
        stagnantProducts,
        summary,
        topProductsByUnits,
        
        // UI State
        isLoadingSnapshots,
        isLoadingTimeSeries,
        error,
        activePeriod,

        // Computed
        totalStagnantValue,

        // Orquestadores de Negocio
        loadSnapshots,
        setPeriod,
    };
});

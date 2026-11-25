import { defineStore } from 'pinia';
import { ref } from 'vue';
import { getSupabaseClient } from '../data/supabaseClient';
import { useAuthStore } from './auth';

// --- Interfaces matching RPC payloads ---

export interface OpexBreakdown {
    cash_expenses: number;
    servicios: number;
    nomina: number;
    transporte: number;
    mantenimiento: number;
    insumos: number;
    otros: number;
    merma_cost: number;
    consumo_negocio_cost: number;
    consumo_personal_cost: number;
    total: number;
}

export interface PersonalConsumptionProfileItem {
    profile_id: string | null;
    profile_key: string;
    profile_name: string;
    profile_role: string;
    total_cost: number;
    total_reference_sale_price: number;
    movements_count: number;
    items_count: number;
}

export interface PersonalConsumptionsSummary {
    total_cost: number;
    total_reference_sale_price: number;
    movements_count: number;
    by_profile: PersonalConsumptionProfileItem[];
}

export interface FinancialReportPayload {
    period: { start: string; end: string };
    gross_sales?: number;
    refunds_total?: number;
    revenue: number;
    cogs: number;
    gross_profit: number;
    gross_margin: number;
    operational_expenses: number;
    net_profit: number;
    opex_breakdown?: OpexBreakdown;
    personal_consumptions_summary?: PersonalConsumptionsSummary;
    inventory_value: number;
    payment_breakdown: {
        cash: number;
        transfer: number;
        credit: number;
        efectivo?: number;
        fiado?: number;
        nequi?: number;
        llave_bre?: number;
    };
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
    const summary = ref<FinancialReportPayload | null>(null);
    const topProductsByUnits = ref<TopProductUnit[]>([]);
    
    const isLoadingSnapshots = ref(false);
    const isLoadingTimeSeries = ref(false);
    const error = ref<string | null>(null);
    const activePeriod = ref<PeriodType>('today');

    // Dependencies
    const authStore = useAuthStore();

    // --- Helpers ---

    function toBogotaDateStr(date: Date): string {
        return new Intl.DateTimeFormat('en-CA', {
            timeZone: 'America/Bogota',
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
        }).format(date);
    }

    function getDateRange(period: PeriodType): { start: string; end: string } {
        const now = new Date();
        const end = toBogotaDateStr(now); // YYYY-MM-DD en America/Bogota (RVC L50)

        switch (period) {
            case 'week': {
                const weekAgo = new Date(now.getTime() - 6 * 24 * 60 * 60 * 1000); // Incluye hoy = 7 días
                return { start: toBogotaDateStr(weekAgo), end };
            }
            case 'month': {
                const [year, month] = end.split('-');
                return { start: `${year}-${month}-01`, end };
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
        if (!authStore.isAdmin) {
            error.value = 'Acceso restringido: solo administradores pueden consultar el panel financiero.';
            return;
        }
        if (typeof navigator !== 'undefined' && !navigator.onLine) {
            error.value = 'Sin conexión a internet. El Centro de Inteligencia requiere conexión en línea.';
            return;
        }
        if (isLoadingSnapshots.value) return;
        isLoadingSnapshots.value = true;
        error.value = null;
        try {
            const results = await Promise.allSettled([
                fetchInventoryHealth(),
                fetchClientLedgerSummary(),
                fetchStagnantProducts()
            ]);
            const rejected = results.find((r): r is PromiseRejectedResult => r.status === 'rejected');
            if (rejected) {
                const msg = rejected.reason?.message || 'Error al cargar indicadores financieros';
                error.value = msg.includes('ADMIN_ONLY_ACTION')
                    ? 'Acceso exclusivo del Administrador.'
                    : msg;
            }
        } catch (err: any) {
            console.error('[FinancialStore] Error loading snapshots:', err);
            error.value = err?.message || 'Error al cargar indicadores financieros';
        } finally {
            isLoadingSnapshots.value = false;
        }
    };

    // --- Actions: TIME-SERIES (Load on Period Change) ---

    const fetchFinancialReport = async (startDate: string, endDate: string) => {
        const supabase = getSupabaseClient();
        if (!supabase || !authStore.currentUser?.storeId) return;
        const { data, error: rpcError } = await supabase.rpc('rpc_get_comprehensive_financial_report', {
            p_store_id: authStore.currentUser.storeId,
            p_start_date: startDate,
            p_end_date: endDate,
        });
        if (rpcError) throw rpcError;
        summary.value = data as FinancialReportPayload;
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
        if (!authStore.isAdmin) {
            error.value = 'Acceso restringido: solo administradores pueden consultar reportes financieros.';
            summary.value = null;
            topProductsByUnits.value = [];
            return;
        }
        if (typeof navigator !== 'undefined' && !navigator.onLine) {
            activePeriod.value = period;
            error.value = 'Sin conexión a internet. El Centro de Inteligencia requiere conexión en línea.';
            summary.value = null;
            topProductsByUnits.value = [];
            return;
        }
        if (isLoadingTimeSeries.value) return;
        activePeriod.value = period;
        isLoadingTimeSeries.value = true;
        error.value = null;

        try {
            const { start, end } = getDateRange(period);
            const results = await Promise.allSettled([
                fetchFinancialReport(start, end),
                fetchTopProductsByUnits(start, end)
            ]);

            const rejected = results.find((r): r is PromiseRejectedResult => r.status === 'rejected');
            if (rejected) {
                const msg = rejected.reason?.message || 'Error al cargar los datos financieros del periodo';
                console.warn('[FinancialStore] Fetch TimeSeries failed:', rejected.reason);
                if (results.every(r => r.status === 'rejected')) {
                    throw rejected.reason;
                }
                error.value = msg.includes('ADMIN_ONLY_ACTION') ? 'Acceso exclusivo del Administrador.' : msg;
            }
        } catch (err: any) {
            console.error('[FinancialStore] Error loading time-series data:', err);
            const msg = err?.message || 'Error al cargar los datos financieros del periodo';
            error.value = msg.includes('ADMIN_ONLY_ACTION') ? 'Acceso exclusivo del Administrador.' : msg;
            summary.value = null;
            topProductsByUnits.value = [];
        } finally {
            isLoadingTimeSeries.value = false;
        }
    };

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

        // Orquestadores de Negocio
        loadSnapshots,
        fetchFinancialReport,
        setPeriod,
        getDateRange,
    };
});

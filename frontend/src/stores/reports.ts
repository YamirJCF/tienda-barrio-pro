import { defineStore } from 'pinia';
import { ref } from 'vue';
import { getSupabaseClient } from '../data/supabaseClient';
import { useAuthStore } from './auth';
import { logger } from '../utils/logger';

export interface TrafficLight {
    status: 'green' | 'red' | 'gray';
    message: string;
}

export interface MoneyBreakdown {
    cash: number;
    transfer: number;
    credit: number;
    nequi?: number;
    llave_bre?: number;
}

export interface Alert {
    type: string;
    message: string;
    target_id?: string;
    stock?: number;
}

export interface Reminder {
    message: string;
}

export interface DailySummary {
    traffic_light: TrafficLight;
    hero_number: number;
    money_breakdown: MoneyBreakdown;
    alerts: Alert[];
    reminder: Reminder;
}

export interface SmartSupplyItem {
    product_id: string;
    product_name: string;
    current_stock: number;
    velocity: number;
    doi: number;
    revenue_at_risk: number;
    status: 'CRITICAL' | 'WARNING' | 'OK' | 'LEARNING' | 'UNKNOWN';
    suggestion: string;
}

function mapReportError(err: any, fallback: string): string {
    const raw = String(err?.message || err || '');
    if (raw.includes('ADMIN_ONLY_ACTION') || err?.code === '42501') {
        return 'Acceso exclusivo del Administrador.';
    }
    if (raw.includes('STORE_ACCESS_DENIED')) {
        return 'No tienes acceso a esta tienda.';
    }
    return raw || fallback;
}

export const useReportsStore = defineStore('reports', () => {
    const summary = ref<DailySummary | null>(null);
    const smartSupply = ref<SmartSupplyItem[]>([]);
    const isLoading = ref(false);
    const isLoadingSupply = ref(false);
    const error = ref<string | null>(null);
    const lastFetched = ref<number | null>(null);

    const authStore = useAuthStore();

    const clear = () => {
        summary.value = null;
        smartSupply.value = [];
        error.value = null;
        lastFetched.value = null;
    };

    const fetchDailySummary = async (date?: string) => {
        if (!authStore.isAdmin) {
            summary.value = null;
            error.value = null;
            isLoading.value = false;
            return;
        }

        const storeId = authStore.currentStore?.id || authStore.currentUser?.storeId;
        if (!storeId) {
            error.value = 'Tienda no seleccionada';
            return;
        }

        isLoading.value = true;
        error.value = null;

        try {
            const supabase = getSupabaseClient();
            if (!supabase) throw new Error('Sin conexión con el servidor');

            const params: { p_store_id: string; p_date?: string } = { p_store_id: storeId };
            if (date) {
                params.p_date = date;
            }

            const { data, error: rpcError } = await supabase.rpc('get_daily_summary', params);

            if (rpcError) throw rpcError;

            summary.value = data as unknown as DailySummary;
            lastFetched.value = Date.now();
        } catch (err: any) {
            logger.error('[ReportsStore] Error fetching daily summary:', err);
            summary.value = null;
            error.value = mapReportError(err, 'Error al cargar resumen diario');
        } finally {
            isLoading.value = false;
        }
    };

    const fetchSmartSupplyReport = async () => {
        if (!authStore.isAdmin) {
            smartSupply.value = [];
            error.value = 'Acceso exclusivo del Administrador.';
            throw new Error(error.value);
        }

        const storeId = authStore.currentStore?.id || authStore.currentUser?.storeId;
        if (!storeId) {
            error.value = 'Tienda no seleccionada';
            return [];
        }

        isLoadingSupply.value = true;
        error.value = null;

        try {
            const supabase = getSupabaseClient();
            if (!supabase) throw new Error('Sin conexión con el servidor');

            const { data, error: rpcError } = await supabase.rpc('get_smart_supply_report', {
                p_store_id: storeId,
            });

            if (rpcError) throw rpcError;

            smartSupply.value = ((data || []) as unknown) as SmartSupplyItem[];
            return smartSupply.value;
        } catch (err: any) {
            logger.error('[ReportsStore] Error fetching smart supply report:', err);
            smartSupply.value = [];
            error.value = mapReportError(err, 'Error al cargar reporte de abastecimiento');
            throw new Error(error.value);
        } finally {
            isLoadingSupply.value = false;
        }
    };

    return {
        summary,
        smartSupply,
        isLoading,
        isLoadingSupply,
        error,
        lastFetched,
        clear,
        fetchDailySummary,
        fetchSmartSupplyReport,
    };
});

import { defineStore } from 'pinia';
import { ref } from 'vue';
import { getSupabaseClient } from '../data/supabaseClient';
import { useAuthStore } from './auth';

// --- Interfaces matching RPC JSON ---

export interface TrafficLight {
    status: 'green' | 'yellow' | 'red' | 'gray';
    message: string;
}

export interface MoneyBreakdown {
    cash: number;
    transfer: number; // Sum of Nequi + Daviplata
    credit: number;   // Fiado
}

export interface Alert {
    type: string; // e.g. 'stock_critical'
    message: string;
    target_id: any;
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

export const useReportsStore = defineStore('reports', () => {
    // State
    const summary = ref<DailySummary | null>(null);
    const isLoading = ref(false);
    const error = ref<string | null>(null);

    // Dependencies
    const authStore = useAuthStore();

    // Actions
    const fetchDailySummary = async (date?: string) => {
        // Reset state
        isLoading.value = true;
        error.value = null;

        try {
            const supabase = getSupabaseClient();
            if (!supabase) {
                throw new Error('Sin conexión: Supabase no disponible');
            }

            if (!authStore.currentUser?.storeId) {
                throw new Error('No active store session found.');
            }

            // Default to today if no date provided
            // Format YYYY-MM-DD requires careful handling locally or just pass undefined to let backend default to CURRENT_DATE
            // Backend signature: get_daily_summary(p_store_id UUID, p_date DATE DEFAULT CURRENT_DATE)

            const params: any = {
                p_store_id: authStore.currentUser.storeId
            };

            if (date) {
                params.p_date = date;
            }

            const { data, error: rpcError } = await supabase
                .rpc('get_daily_summary', params);

            if (rpcError) throw rpcError;

            // Type cast the response
            summary.value = data as DailySummary;

        } catch (err: any) {
            console.error('Error fetching daily summary:', err);
            error.value = err.message || 'Failed to load report';
            summary.value = null;
        } finally {
            isLoading.value = false;
        }
    };

    return {
        // State
        summary,
        isLoading,
        error,

        // Actions
        fetchDailySummary
    };
});

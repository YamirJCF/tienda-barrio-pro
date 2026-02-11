import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { getSupabaseClient } from '../data/supabaseClient';
import { logger } from '../utils/logger';

export interface PaymentMethod {
    id: string;
    code: string;
    name: string;
    isActive: boolean;
    requiresReference: boolean;
    allowsChange: boolean;
    sortOrder: number;
}

export interface TransactionType {
    code: string;
    description: string;
    impactStock: number;
    impactCash: number;
}

export interface SystemConfig {
    paymentMethods: PaymentMethod[];
    transactionTypes: TransactionType[];
    serverTimestamp: string;
}

export const useConfigStore = defineStore('config', () => {
    // State
    const paymentMethods = ref<PaymentMethod[]>([]);
    const transactionTypes = ref<TransactionType[]>([]);
    const lastSync = ref<string | null>(null);
    const loading = ref(false);
    const error = ref<string | null>(null);

    // Getters
    const activePaymentMethods = computed(() => {
        return paymentMethods.value.filter(pm => pm.isActive).sort((a, b) => a.sortOrder - b.sortOrder);
    });

    const getMethodByCode = (code: string) => {
        return paymentMethods.value.find(pm => pm.code === code);
    };

    /**
     * Fetch configuration from Backend (RPC)
     * Falls back to local storage provided by pinia-plugin-persistedstate if offline
     */
    async function fetchSystemConfig() {
        loading.value = true;
        error.value = null;

        try {
            const supabase = getSupabaseClient();
            if (!supabase) throw new Error('Supabase client not initialized');

            const { data, error: rpcError } = await supabase.rpc('rpc_get_system_config');

            if (rpcError) throw rpcError;

            if (data) {
                // Map snake_case from DB to camelCase for Frontend
                paymentMethods.value = (data.payment_methods || []).map((pm: any) => ({
                    code: pm.code,
                    name: pm.name,
                    isActive: pm.is_active !== false, // Default true if undefined
                    requiresReference: pm.requires_reference,
                    allowsChange: pm.allows_change,
                    sortOrder: pm.sort_order || 0
                }));

                transactionTypes.value = (data.transaction_types || []).map((tt: any) => ({
                    code: tt.code,
                    description: tt.description,
                    impactStock: tt.impact_stock,
                    impactCash: tt.impact_cash
                }));

                lastSync.value = new Date().toISOString();
                logger.log('[ConfigStore] System config synced successfully', {
                    methods: paymentMethods.value.length
                });
            }

        } catch (e: any) {
            logger.error('[ConfigStore] Failed to fetch system config', e);
            // Don't clear state if fetch fails - rely on persistence
            error.value = e.message || 'Error syncing config';
        } finally {
            loading.value = false;
        }
    }

    /**
     * Initialize Store
     * Should be called on App mount
     */
    async function init() {
        if (paymentMethods.value.length === 0) {
            await fetchSystemConfig();
        } else {
            // Refresh in background if data exists
            fetchSystemConfig();
        }
    }

    return {
        paymentMethods,
        transactionTypes,
        lastSync,
        loading,
        error,
        activePaymentMethods,
        getMethodByCode,
        fetchSystemConfig,
        init
    };
}, {
    persist: true // Enable local storage persistence
});

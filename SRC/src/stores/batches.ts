import { defineStore } from 'pinia';
import { ref } from 'vue';
import { getSupabaseClient } from '../data/supabaseClient';
import { logger } from '../utils/logger';

export interface InventoryBatch {
    id: string;
    product_id: string;
    quantity_initial: number;
    quantity_remaining: number;
    cost_unit: number;
    is_active: boolean;
    created_at: string;
}

export const useBatchStore = defineStore('batches', () => {
    const batches = ref<InventoryBatch[]>([]);
    const isLoading = ref(false);
    const error = ref<string | null>(null);

    /**
     * Fetch batches for a specific product, ordered by creation date (FIFO)
     */
    async function fetchBatchesByProduct(productId: string) {
        isLoading.value = true;
        error.value = null;
        batches.value = [];

        try {
            const supabase = getSupabaseClient();

            // Audit/Offline Mode
            if (!supabase) {
                logger.log('[BatchStore] Offline/Audit mode: Loading from localStorage.');
                try {
                    const stored = localStorage.getItem('audit-batches');
                    if (stored) {
                        const allBatches: InventoryBatch[] = JSON.parse(stored);
                        batches.value = allBatches
                            .filter(b => b.product_id === productId)
                            .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());
                    }
                } catch (e) {
                    logger.warn('[BatchStore] Error reading local batches', e);
                }
                return;
            }

            // Online Mode
            const { data, error: err } = await supabase
                .from('inventory_batches')
                .select('*')
                .eq('product_id', productId)
                .order('created_at', { ascending: true });

            if (err) throw err;

            batches.value = data || [];
        } catch (err: any) {
            logger.error('Error fetching batches:', err);
            error.value = err.message || 'Error al cargar lotes';
        } finally {
            isLoading.value = false;
        }
    }

    /**
     * Audit Mode Only: Simulate batch creation locally
     */
    function addLocalBatch(batch: Omit<InventoryBatch, 'id' | 'created_at' | 'is_active' | 'quantity_remaining'>) {
        const supabase = getSupabaseClient();
        if (supabase) return; // Do nothing if online (DB handles it)

        const newBatch: InventoryBatch = {
            id: crypto.randomUUID(),
            created_at: new Date().toISOString(),
            is_active: true,
            quantity_remaining: batch.quantity_initial,
            ...batch
        };

        const stored = localStorage.getItem('audit-batches');
        const allBatches: InventoryBatch[] = stored ? JSON.parse(stored) : [];
        allBatches.push(newBatch);
        localStorage.setItem('audit-batches', JSON.stringify(allBatches));

        logger.log('[BatchStore] Local batch created:', newBatch);
    }

    return {
        batches,
        isLoading,
        error,
        fetchBatchesByProduct,
        addLocalBatch
    };
});

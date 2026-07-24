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
    sale_price: number;
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
    async function fetchBatchesByProduct(productId: string): Promise<InventoryBatch[]> {
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
                    return batches.value;
                } catch (e) {
                    logger.warn('[BatchStore] Error reading local batches', e);
                }
                return [];
            }

            // Online Mode
            const { data, error: err } = await supabase
                .from('inventory_batches')
                .select('*')
                .eq('product_id', productId)
                .order('created_at', { ascending: true });

            if (err) throw err;

            batches.value = data || [];
            return batches.value;
        } catch (err: any) {
            logger.error('Error fetching batches:', err);
            error.value = err.message || 'Error al cargar lotes';
            return [];
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
            sale_price: batch.sale_price || 0,
            ...batch
        };

        const stored = localStorage.getItem('audit-batches');
        const allBatches: InventoryBatch[] = stored ? JSON.parse(stored) : [];
        allBatches.push(newBatch);
        localStorage.setItem('audit-batches', JSON.stringify(allBatches));

        logger.log('[BatchStore] Local batch created:', newBatch);
    }

    /**
     * Update cost and sale price of a specific batch
     */
    async function updateBatchPrice(batchId: string, costUnit: number, salePrice: number): Promise<{ success: boolean; error?: string }> {
        isLoading.value = true;
        error.value = null;

        try {
            const supabase = getSupabaseClient();

            // Audit/Offline Mode
            if (!supabase) {
                logger.log('[BatchStore] Offline/Audit mode: Updating local batch.');
                const stored = localStorage.getItem('audit-batches');
                if (stored) {
                    let allBatches: InventoryBatch[] = JSON.parse(stored);
                    allBatches = allBatches.map(b => 
                        b.id === batchId ? { ...b, cost_unit: costUnit, sale_price: salePrice } : b
                    );
                    localStorage.setItem('audit-batches', JSON.stringify(allBatches));
                    
                    // Update current list if loaded
                    batches.value = batches.value.map(b => 
                        b.id === batchId ? { ...b, cost_unit: costUnit, sale_price: salePrice } : b
                    );
                }
                return { success: true };
            }

            // Online Mode
            const { data, error: err } = await supabase.rpc('rpc_actualizar_precio_lote', {
                p_batch_id: batchId,
                p_cost_unit: costUnit,
                p_sale_price: salePrice
            });

            if (err) throw err;
            if (data && !data.success) throw new Error(data.error || 'Error al actualizar lote');

            // Update local state
            batches.value = batches.value.map(b => 
                b.id === batchId ? { ...b, cost_unit: costUnit, sale_price: salePrice } : b
            );

            return { success: true };
        } catch (err: any) {
            logger.error('Error updating batch:', err);
            error.value = err.message || 'Error al actualizar lote';
            return { success: false, error: error.value };
        } finally {
            isLoading.value = false;
        }
    }

    return {
        batches,
        isLoading,
        error,
        fetchBatchesByProduct,
        addLocalBatch,
        updateBatchPrice
    };
});

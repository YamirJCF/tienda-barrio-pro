import { defineStore } from 'pinia';
import { ref } from 'vue';
import { supabase } from '@/lib/supabase';
import { logger } from '@/utils/logger';
import type { Database } from '@/types/database.types';

type Supplier = Database['public']['Tables']['suppliers']['Row'];
type SupplierInsert = Database['public']['Tables']['suppliers']['Insert'];

export const useSuppliersStore = defineStore(
    'suppliers',
    () => {
        const suppliers = ref<Supplier[]>([]);
        const isLoading = ref(false);
        const error = ref<string | null>(null);

        /**
         * Fetch all suppliers for a store
         */
        const fetchSuppliers = async (storeId: string) => {
            if (!storeId) return;

            isLoading.value = true;
            error.value = null;

            try {
                const { data, error: fetchError } = await supabase
                    .from('suppliers')
                    .select('*')
                    .eq('store_id', storeId)
                    .order('is_default', { ascending: false })
                    .order('name');

                if (fetchError) throw fetchError;
                suppliers.value = data || [];
            } catch (e: any) {
                logger.error('[SuppliersStore] Fetch failed', e);
                error.value = 'Error al cargar proveedores';
            } finally {
                isLoading.value = false;
            }
        };

        /**
         * Create a new supplier
         */
        const createSupplier = async (supplier: SupplierInsert): Promise<{ success: boolean; data?: Supplier; error?: string }> => {
            try {
                const { data, error: insertError } = await supabase
                    .from('suppliers')
                    .insert(supplier)
                    .select()
                    .single();

                if (insertError) throw insertError;

                if (data) {
                    suppliers.value.push(data);
                    return { success: true, data };
                }
                return { success: false, error: 'No data returned' };
            } catch (e: any) {
                logger.error('[SuppliersStore] Create failed', e);
                return { success: false, error: e.message || 'Error al crear proveedor' };
            }
        };

        /**
         * Update an existing supplier
         */
        const updateSupplier = async (id: string, updates: Partial<Supplier>): Promise<{ success: boolean; error?: string }> => {
            try {
                const { error: updateError } = await supabase
                    .from('suppliers')
                    .update({ ...updates, updated_at: new Date().toISOString() })
                    .eq('id', id);

                if (updateError) throw updateError;

                const index = suppliers.value.findIndex(s => s.id === id);
                if (index !== -1) {
                    suppliers.value[index] = { ...suppliers.value[index], ...updates };
                }
                return { success: true };
            } catch (e: any) {
                logger.error('[SuppliersStore] Update failed', e);
                return { success: false, error: e.message || 'Error al actualizar proveedor' };
            }
        };

        /**
         * Delete a supplier (only if not default)
         */
        const deleteSupplier = async (id: string): Promise<{ success: boolean; error?: string }> => {
            const supplier = suppliers.value.find(s => s.id === id);
            if (supplier?.is_default) {
                return { success: false, error: 'No se puede eliminar el proveedor por defecto' };
            }

            try {
                const { error: deleteError } = await supabase
                    .from('suppliers')
                    .delete()
                    .eq('id', id);

                if (deleteError) throw deleteError;

                suppliers.value = suppliers.value.filter(s => s.id !== id);
                return { success: true };
            } catch (e: any) {
                logger.error('[SuppliersStore] Delete failed', e);
                return { success: false, error: e.message || 'Error al eliminar proveedor' };
            }
        };

        /**
         * Bulk assign a supplier to multiple products
         */
        const bulkAssignSupplier = async (productIds: string[], supplierId: string): Promise<{ success: boolean; error?: string }> => {
            if (productIds.length === 0) {
                return { success: false, error: 'No se seleccionaron productos' };
            }

            try {
                const { error: updateError } = await supabase
                    .from('products')
                    .update({ supplier_id: supplierId, updated_at: new Date().toISOString() })
                    .in('id', productIds);

                if (updateError) throw updateError;

                return { success: true };
            } catch (e: any) {
                logger.error('[SuppliersStore] Bulk assign failed', e);
                return { success: false, error: e.message || 'Error al asignar proveedor' };
            }
        };

        /**
         * Get the default supplier for a store
         */
        const getDefaultSupplier = () => {
            return suppliers.value.find(s => s.is_default);
        };

        /**
         * Get supplier by ID
         */
        const getSupplierById = (id: string) => {
            return suppliers.value.find(s => s.id === id);
        };

        return {
            suppliers,
            isLoading,
            error,
            fetchSuppliers,
            createSupplier,
            updateSupplier,
            deleteSupplier,
            bulkAssignSupplier,
            getDefaultSupplier,
            getSupplierById,
        };
    }
);

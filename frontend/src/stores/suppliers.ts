import { defineStore } from 'pinia';
import { ref } from 'vue';
import { supabase } from '@/lib/supabase';
import { logger } from '@/utils/logger';
import { useAuthStore } from './auth';
import type { Database } from '@/types/database.types';

export type Supplier = Database['public']['Tables']['suppliers']['Row'] & {
    pending_debt?: number;
    open_invoices_count?: number;
};
type SupplierInsert = Database['public']['Tables']['suppliers']['Insert'];

function mapSuppliersError(err: any, fallback: string): string {
    const code = String(err?.code || '');
    const raw = String(err?.message || err || '');

    if (code === '23503' || /foreign key|violates foreign key constraint/i.test(raw)) {
        return 'No se puede eliminar este proveedor porque tiene facturas, productos o entradas asociadas en el historial.';
    }
    if (code === '23505' || /duplicate key|unique constraint/i.test(raw)) {
        return 'Ya existe un proveedor con ese nombre en la tienda.';
    }
    if (code === '42501' || raw.includes('ADMIN_ONLY_ACTION') || raw.includes('UNAUTHORIZED') || raw.includes('42501')) {
        return 'Acción restringida exclusivamente al Administrador de la tienda.';
    }
    return raw || fallback;
}

export const useSuppliersStore = defineStore(
    'suppliers',
    () => {
        const suppliers = ref<Supplier[]>([]);
        const isLoading = ref(false);
        const error = ref<string | null>(null);

        /**
         * Fetch suppliers with server-computed pending debt and open invoices count (Admin only RPC)
         */
        const fetchSuppliersWithPayables = async (storeId: string) => {
            if (!storeId) return;

            isLoading.value = true;
            error.value = null;

            try {
                const { data: rpcData, error: rpcError } = await supabase.rpc('rpc_obtener_proveedores_con_cxp', {
                    p_store_id: storeId,
                });

                if (rpcError) throw rpcError;

                const payload = rpcData as any;
                if (!payload?.success || !Array.isArray(payload?.data)) {
                    throw new Error(payload?.error || 'Respuesta inválida al consultar proveedores');
                }

                suppliers.value = (payload.data as any[]).map((row) => ({
                    ...row,
                    pending_debt: Number(row.pending_debt ?? 0),
                    open_invoices_count: Number(row.open_invoices_count ?? 0),
                }));
            } catch (e: any) {
                logger.error('[SuppliersStore] Fetch with payables failed', e);
                error.value = mapSuppliersError(e, 'Error al cargar proveedores');
            } finally {
                isLoading.value = false;
            }
        };

        /**
         * Fetch all suppliers for a store (delegates to Admin RPC when Admin; read-only select for inventory staff)
         */
        const fetchSuppliers = async (storeId: string) => {
            if (!storeId) return;

            const authStore = useAuthStore();
            if (authStore.isAdmin) {
                await fetchSuppliersWithPayables(storeId);
                return;
            }

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
                suppliers.value = (data || []).map((row) => ({
                    ...row,
                    pending_debt: 0,
                    open_invoices_count: 0,
                }));
            } catch (e: any) {
                logger.error('[SuppliersStore] Fetch failed', e);
                error.value = mapSuppliersError(e, 'Error al cargar proveedores');
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
                return { success: false, error: mapSuppliersError(e, 'Error al crear proveedor') };
            }
        };

        /**
         * Update an existing supplier
         */
        const updateSupplier = async (id: string, updates: Partial<Supplier>): Promise<{ success: boolean; error?: string }> => {
            try {
                const payload: Record<string, any> = {
                    updated_at: new Date().toISOString(),
                };
                if (updates.name !== undefined) payload.name = updates.name;
                if (updates.delivery_day !== undefined) payload.delivery_day = updates.delivery_day;
                if (updates.frequency_days !== undefined) payload.frequency_days = updates.frequency_days;
                if (updates.lead_time_days !== undefined) payload.lead_time_days = updates.lead_time_days;

                const { error: updateError } = await supabase
                    .from('suppliers')
                    .update(payload)
                    .eq('id', id);

                if (updateError) throw updateError;

                const index = suppliers.value.findIndex(s => s.id === id);
                if (index !== -1) {
                    suppliers.value[index] = { ...suppliers.value[index], ...payload };
                }
                return { success: true };
            } catch (e: any) {
                logger.error('[SuppliersStore] Update failed', e);
                return { success: false, error: mapSuppliersError(e, 'Error al actualizar proveedor') };
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
                return { success: false, error: mapSuppliersError(e, 'Error al eliminar proveedor') };
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
                const authStore = useAuthStore();
                const storeId = authStore.currentStore?.id || authStore.currentUser?.storeId;
                if (!storeId) throw new Error('No hay sesión de tienda activa');

                const { data, error: rpcError } = await supabase.rpc('rpc_asignar_proveedor_masivo', {
                    p_store_id: storeId,
                    p_supplier_id: supplierId,
                    p_product_ids: productIds
                });

                if (rpcError) throw rpcError;
                if (data && !(data as any).success) {
                    throw new Error((data as any).error || 'Error al asignar proveedor');
                }

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
            fetchSuppliersWithPayables,
            createSupplier,
            updateSupplier,
            deleteSupplier,
            bulkAssignSupplier,
            getDefaultSupplier,
            getSupplierById,
        };
    }
);

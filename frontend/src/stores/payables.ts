import { defineStore } from 'pinia';
import { ref } from 'vue';
import { supabase } from '@/lib/supabase';
import { logger } from '@/utils/logger';
export interface SupplierInvoiceRow {
    id: string;
    supplier_id: string;
    invoice_number: string;
    total_amount: number;
    amount_paid: number;
    issue_date: string;
    due_date?: string;
    created_at?: string;
    updated_at?: string;
}

export interface SupplierInvoice extends SupplierInvoiceRow {
    status: 'pagada' | 'vencida' | 'pendiente';
    supplier?: {
        name: string;
    };
}

export const usePayablesStore = defineStore('payables', () => {
    const invoices = ref<SupplierInvoice[]>([]);
    const isLoading = ref(false);
    const error = ref<string | null>(null);

    const fetchInvoices = async (supplierId?: string) => {
        isLoading.value = true;
        error.value = null;

        try {
            let query = supabase
                .from('supplier_invoices')
                .select(`
                    *,
                    supplier:suppliers(name)
                `)
                .order('created_at', { ascending: false });

            if (supplierId) {
                query = query.eq('supplier_id', supplierId);
            }

            const { data, error: fetchError } = await query;

            if (fetchError) throw fetchError;

            const today = new Date().toISOString().split('T')[0];

            invoices.value = (data || []).map(invoice => {
                let status: 'pagada' | 'vencida' | 'pendiente' = 'pendiente';
                
                if (invoice.amount_paid >= invoice.total_amount) {
                    status = 'pagada';
                } else if (invoice.due_date && invoice.due_date < today) {
                    status = 'vencida';
                }

                return {
                    ...invoice,
                    supplier: Array.isArray(invoice.supplier) ? invoice.supplier[0] : invoice.supplier,
                    status
                } as SupplierInvoice;
            });

        } catch (e: any) {
            logger.error('[PayablesStore] Fetch failed', e);
            error.value = e.message || 'Error al cargar facturas de proveedores';
        } finally {
            isLoading.value = false;
        }
    };

    const payInvoice = async (invoiceId: string, amount: number): Promise<{ success: boolean; error?: string }> => {
        try {
            const { error: rpcError } = await supabase.rpc('rpc_pay_supplier_invoice', {
                p_invoice_id: invoiceId,
                p_amount: amount
            });

            if (rpcError) throw rpcError;

            return { success: true };
        } catch (e: any) {
            logger.error('[PayablesStore] Pay invoice failed', e);
            return { success: false, error: e.message || 'Error al procesar el pago' };
        }
    };

    return {
        invoices,
        isLoading,
        error,
        fetchInvoices,
        payInvoice
    };
});

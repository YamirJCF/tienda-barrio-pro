import { defineStore } from 'pinia';
import { ref } from 'vue';
import { supabase } from '@/lib/supabase';
import { logger } from '@/utils/logger';
import { useAuthStore } from './auth';

export interface SupplierInvoiceRow {
    id: string;
    store_id?: string;
    supplier_id: string;
    invoice_number?: string | null;
    total_amount: number;
    amount_paid: number;
    pending_balance?: number;
    issue_date?: string;
    due_date?: string | null;
    created_at?: string;
    updated_at?: string;
}

export interface SupplierInvoice extends SupplierInvoiceRow {
    status: 'pagada' | 'vencida' | 'pendiente';
    supplier?: {
        name: string;
    };
}

export interface FetchInvoicesOptions {
    storeId?: string;
    supplierId?: string;
    status?: string;
    limit?: number;
    offset?: number;
    append?: boolean;
}

function mapPayablesRpcError(rawMessage?: string): string {
    const raw = String(rawMessage || '');
    if (raw.includes('INSUFFICIENT_CHANNEL_BALANCE')) {
        return raw;
    }
    if (raw.includes('NO_OPEN_CASH_SESSION')) {
        return 'Debes abrir turno de caja para pagar desde Efectivo/Digital, o seleccionar Pago externo / fuera de caja.';
    }
    if (raw.includes('SHIFT_EXPIRED_24H')) {
        return 'El turno de caja superó 24 horas. Cierra el turno o registra el pago como Pago externo / fuera de caja.';
    }
    if (raw.includes('DESCRIPTION_REQUIRED')) {
        return 'La descripción del abono es obligatoria para egresos desde canales internos de caja.';
    }
    if (raw.includes('AMOUNT_EXCEEDS_PENDING')) {
        return 'El monto del abono supera el saldo pendiente de la factura.';
    }
    if (raw.includes('ADMIN_ONLY_ACTION') || raw.includes('UNAUTHORIZED') || raw.includes('42501')) {
        return 'Acción restringida exclusivamente al Administrador de la tienda.';
    }
    if (raw.includes('INVOICE_NOT_FOUND')) {
        return 'La factura seleccionada no existe en la tienda activa.';
    }
    return raw || 'Error al procesar operación de Cuentas por Pagar';
}

export const usePayablesStore = defineStore('payables', () => {
    const invoices = ref<SupplierInvoice[]>([]);
    const totalCount = ref<number>(0);
    const isLoading = ref(false);
    const error = ref<string | null>(null);

    const fetchInvoices = async (supplierIdOrOptions?: string | FetchInvoicesOptions) => {
        const opts: FetchInvoicesOptions =
            typeof supplierIdOrOptions === 'string'
                ? { supplierId: supplierIdOrOptions }
                : (supplierIdOrOptions || {});

        const authStore = useAuthStore();
        const storeId = opts.storeId || authStore.currentUser?.storeId || authStore.currentStore?.id;
        if (!storeId) {
            error.value = 'No hay tienda activa para consultar Cuentas por Pagar.';
            return;
        }

        if (!opts.append) {
            isLoading.value = true;
        }
        error.value = null;

        try {
            const { data: rpcData, error: rpcError } = await supabase.rpc('rpc_obtener_cuentas_por_pagar', {
                p_store_id: storeId,
                p_status: opts.status || null,
                p_supplier_id: opts.supplierId || null,
                p_limit: opts.limit ?? 50,
                p_offset: opts.offset ?? 0,
            });

            if (rpcError) throw rpcError;

            const payload = rpcData as any;
            if (!payload?.success || !Array.isArray(payload?.data)) {
                throw new Error(payload?.error || 'Respuesta inválida de Cuentas por Pagar');
            }

            const mapped = payload.data as SupplierInvoice[];
            if (opts.append) {
                const seen = new Set(invoices.value.map((i) => i.id));
                invoices.value = [...invoices.value, ...mapped.filter((i) => !seen.has(i.id))];
            } else {
                invoices.value = mapped;
            }
            totalCount.value = Number(payload.count ?? invoices.value.length);
        } catch (e: any) {
            logger.error('[PayablesStore] Fetch failed', e);
            error.value = mapPayablesRpcError(e?.message);
        } finally {
            isLoading.value = false;
        }
    };

    const createInvoice = async (params: {
        storeId: string;
        supplierName: string;
        totalAmount: number;
        dueDate?: string | null;
        invoiceNumber?: string | null;
    }): Promise<{ success: boolean; invoice?: SupplierInvoice; error?: string }> => {
        try {
            const { data: rpcData, error: rpcError } = await supabase.rpc('rpc_crear_factura_proveedor', {
                p_store_id: params.storeId,
                p_supplier_name: params.supplierName,
                p_total_amount: params.totalAmount,
                p_due_date: params.dueDate || null,
                p_invoice_number: params.invoiceNumber || null,
            });

            if (rpcError) throw rpcError;

            const payload = rpcData as any;
            if (!payload?.success || !payload?.data?.invoice) {
                return { success: false, error: mapPayablesRpcError(payload?.error) };
            }

            return { success: true, invoice: payload.data.invoice as SupplierInvoice };
        } catch (e: any) {
            logger.error('[PayablesStore] Create invoice failed', e);
            return { success: false, error: mapPayablesRpcError(e?.message) };
        }
    };

    const payInvoice = async (
        invoiceId: string,
        amount: number,
        paymentMethod: string,
        description?: string
    ): Promise<{ success: boolean; error?: string }> => {
        try {
            const { data: rpcData, error: rpcError } = await supabase.rpc('rpc_pay_supplier_invoice', {
                p_invoice_id: invoiceId,
                p_amount: amount,
                p_payment_method: paymentMethod,
                p_description: description ?? null,
            });

            if (rpcError) throw rpcError;

            const payload = rpcData as any;
            if (payload && payload.success === false) {
                return { success: false, error: mapPayablesRpcError(payload.error) };
            }

            return { success: true };
        } catch (e: any) {
            logger.error('[PayablesStore] Pay invoice failed', e);
            return { success: false, error: mapPayablesRpcError(e?.message) };
        }
    };

    return {
        invoices,
        totalCount,
        isLoading,
        error,
        fetchInvoices,
        createInvoice,
        payInvoice
    };
});

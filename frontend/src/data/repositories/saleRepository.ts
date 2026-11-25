/**
 * Sale Repository
 * WO-002 T2.2: Implementing repository pattern for Sales
 * WO-FE-007: Implementing Mapper Layer for Schema v2 Compatibility
 * 
 * Uses SupabaseAdapter to provide data access for Sales
 * Favor RPC `procesar_venta` for atomic creation
 * 
 * @module data/repositories/saleRepository
 */

import { Sale, SaleItem, SalePayload, SaleResponse } from '../../types';
import { Database } from '../../types/database.types';
import { Decimal } from 'decimal.js';
import { createSupabaseRepository, EntityRepository, RepositoryMappers } from './supabaseAdapter';
import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { logger } from '../../utils/logger';
import { addToSyncQueue } from '../syncQueue';
import { useInventoryStore } from '../../stores/inventory';
import { useClientsStore } from '../../stores/clients';
import { useQuantityFormat } from '../../composables/useQuantityFormat';

// Constants
const TABLE_NAME = 'sales';
const STORAGE_KEY = 'tienda-sales-db-cache'; // Changed to avoid collision with Pinia persist

// Type definitions
type SaleDB = Database['public']['Tables']['sales']['Row'];
type SaleInsert = Database['public']['Tables']['sales']['Insert'];

function mapSaleRpcError(rawMessage?: string): { message: string; code?: string } {
    const raw = String(rawMessage || '');
    if (raw.includes('PERMISSION_DENIED')) {
        return {
            message: 'No tienes permiso autorizado para realizar esta operación (canFiar o rol Administrador requerido).',
            code: 'PERMISSION_DENIED'
        };
    }
    if (raw.includes('CLIENT_NOT_FOUND')) {
        return {
            message: 'El cliente seleccionado no existe o fue archivado en la cartera.',
            code: 'CLIENT_NOT_FOUND'
        };
    }
    if (raw.includes('CLIENT_REQUIRED')) {
        return {
            message: 'Debes seleccionar un cliente activo para procesar una venta Fiado.',
            code: 'CLIENT_REQUIRED'
        };
    }
    if (raw.includes('CREDIT_REVERSAL_BLOCKED')) {
        return {
            message: 'No se puede anular esta venta fiada porque el cliente ya abonó o no tiene saldo suficiente para revertir la deuda.',
            code: 'CREDIT_REVERSAL_BLOCKED'
        };
    }
    if (raw.includes('CREDIT_LIMIT_EXCEEDED')) {
        return { message: raw, code: 'CREDIT_LIMIT_EXCEEDED' };
    }
    if (raw.includes('NO_OPEN_CASH_SESSION')) {
        return {
            message: 'No hay turno de caja abierto. Abre caja para procesar ventas o retiros.',
            code: 'NO_OPEN_CASH_SESSION'
        };
    }
    if (raw.includes('SHIFT_EXPIRED_24H')) {
        return {
            message: 'El turno de caja superó las 24 horas y debe cerrarse antes de continuar.',
            code: 'SHIFT_EXPIRED_24H'
        };
    }
    if (raw.includes('EMPLOYEE_NOT_FOUND')) {
        return {
            message: 'El empleado beneficiario seleccionado no existe o está inactivo.',
            code: 'EMPLOYEE_NOT_FOUND'
        };
    }
    return { message: raw || 'Error procesando operación de venta' };
}

export interface RefundCandidateFifoBatch {
    batch_id: string;
    quantity: number;
    unit_cost: number;
    created_at?: string | null;
}

export interface RefundCandidateItem {
    sale_item_id: string;
    product_id: string;
    product_name: string;
    plu?: string | null;
    current_stock: number;
    is_weighable: boolean;
    measurement_unit?: string | null;
    quantity: number;
    refunded_quantity: number;
    remaining_quantity: number;
    unit_price: number;
    subtotal: number;
    fifo_batches?: RefundCandidateFifoBatch[];
}

export interface RefundCandidateSale {
    sale_id: string;
    ticket_number: number;
    created_at: string;
    total: number;
    payment_method: string;
    actor_name: string;
    items: RefundCandidateItem[];
}

export interface ProcessRefundPayload {
    saleItemId: string;
    quantity: number;
    refundChannel: 'efectivo' | 'nequi' | 'llave_bre';
    originalChannel: 'efectivo' | 'nequi' | 'llave_bre' | 'fiado' | 'transferencia';
    reason: string;
    isMerma: boolean;
}

export interface ProcessRefundResult {
    cashMovementId: string;
    inventoryMovementId: string;
    saleId: string;
    saleItemId: string;
    ticketNumber: number;
    amountRefunded: number;
    quantityRefunded: number;
    refundChannel: string;
    originalChannel: string;
    isMerma: boolean;
    newStock: number;
    actorName: string;
    actorRole: string;
}

function mapRefundRpcError(rawMessage?: string): { message: string; code?: string } {
    const raw = String(rawMessage || '');
    if (raw.includes('INSUFFICIENT_FUNDS_IN_CHANNEL')) {
        return {
            message: raw.replace(/^.*INSUFFICIENT_FUNDS_IN_CHANNEL:\s*/i, ''),
            code: 'INSUFFICIENT_FUNDS_IN_CHANNEL'
        };
    }
    if (raw.includes('QUANTITY_EXCEEDED')) {
        return {
            message: raw.replace(/^.*QUANTITY_EXCEEDED:\s*/i, ''),
            code: 'QUANTITY_EXCEEDED'
        };
    }
    if (raw.includes('SALE_ALREADY_VOIDED')) {
        return {
            message: 'Esta venta fue anulada y no admite reembolsos por ítem.',
            code: 'SALE_ALREADY_VOIDED'
        };
    }
    if (raw.includes('SALE_HAS_PARTIAL_REFUNDS')) {
        return {
            message: 'Esta venta tiene reembolsos parciales registrados y no puede anularse completa.',
            code: 'SALE_HAS_PARTIAL_REFUNDS'
        };
    }
    return mapSaleRpcError(rawMessage);
}

/**
 * Mapper Implementation for Sale
 * Enforces:
 * 1. Decimal (Domain) <-> number (DB)
 * 2. snake_case (DB) <-> camelCase (Domain)
 */
export const saleMapper: RepositoryMappers<SaleDB, Sale> = {
    toDomain: (row: SaleDB): Sale => {
        return {
            id: row.id,
            ticketNumber: row.ticket_number,
            date: row.created_at.split('T')[0], // Extract YYYY-MM-DD
            timestamp: row.created_at,
            // Items are not in the sales table (relation).
            // For list views, we might effectively return empty items or fetch separate.
            // As this is a generic getAll wrapper, we return empty structure adhering to type.
            items: [],
            total: new Decimal(row.total),
            paymentMethod: row.payment_method as any,
            // payments: Not stored in sales row directly (related tables)
            roundingDifference: row.rounding_difference ? new Decimal(row.rounding_difference) : undefined,
            effectiveTotal: new Decimal(row.total).add(row.rounding_difference ? new Decimal(row.rounding_difference) : 0),
            amountReceived: row.amount_received ? new Decimal(row.amount_received) : undefined,
            change: row.change_given ? new Decimal(row.change_given) : undefined,
            clientId: row.client_id || undefined,
            employeeId: row.employee_id || undefined,
            beneficiaryEmployeeId: row.beneficiary_employee_id || undefined,
            'syncStatus': row.sync_status as any
        };
    },
    toPersistence: (entity: Sale): SaleDB => {
        // ===== VALIDATION CHECKPOINT (Fase 1 Blindaje) =====
        // Note: Sale uses storeId passed via processSale, not entity field
        // This mapper is for generic CRUD, storeId must be present
        const storeId = (entity as any).storeId;
        if (!storeId || storeId.trim() === '') {
            const error = new Error('Cannot persist Sale without valid storeId. This would fail RLS policies.');
            console.error('🚫 [SaleRepo] RLSViolationError:', error.message);
            throw error;
        }

        // Validate UUID format
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        if (!uuidRegex.test(storeId)) {
            const error = new Error(`Invalid UUID format for storeId: "${storeId}"`);
            console.error('🚫 [SaleRepo] ValidationError:', error.message);
            throw error;
        }

        return {
            id: entity.id,
            ticket_number: entity.ticketNumber || 0,
            created_at: entity.timestamp || new Date().toISOString(),
            payment_method: (entity.paymentMethod === 'cash' || (entity.paymentMethod as string) === 'mixed') ? 'efectivo' : entity.paymentMethod,
            total: entity.total.toNumber(),
            employee_id: entity.employeeId || null,
            beneficiary_employee_id: entity.beneficiaryEmployeeId || null,
            actor_name: null,
            actor_role: null,
            client_id: entity.clientId || null,
            amount_received: entity.amountReceived ? entity.amountReceived.toNumber() : null,
            change_given: entity.change ? entity.change.toNumber() : null,
            rounding_difference: entity.roundingDifference ? entity.roundingDifference.toNumber() : null,
            is_voided: false,
            void_reason: null,
            voided_by: null,
            voided_by_name: null,
            voided_by_role: null,
            voided_at: null,
            void_session_id: null,
            idempotency_key: null,
            local_id: null,
            sync_status: entity.syncStatus || 'synced',
            store_id: storeId // NO FALLBACK - validated above
        };
    }
};

/**
 * Interface extending base repository with sale-specific methods
 */
export interface SaleRepository extends EntityRepository<Sale> {
    processSale(saleData: SalePayload, storeId: string): Promise<SaleResponse>;
    forceSale(saleData: SalePayload, storeId: string, justification: string): Promise<SaleResponse>;
    getByDateRange(startDate: string, endDate: string, storeId?: string): Promise<Sale[]>;
    getLastTicketNumber(storeId: string): Promise<number>;
    voidSale(saleId: string, reason: string): Promise<{ success: boolean; error?: string }>;
    getSaleDetail(saleId: string): Promise<any>;
    searchRefundCandidates(storeId: string, query?: string, limit?: number): Promise<RefundCandidateSale[]>;
    processItemRefund(payload: ProcessRefundPayload): Promise<ProcessRefundResult>;
}

// Create base repository with Mappers
const baseRepository = createSupabaseRepository<Sale, SaleDB>(
    TABLE_NAME,
    STORAGE_KEY,
    saleMapper
);

/**
 * Extended Sale Repository implementation
 */
export const saleRepository: SaleRepository = {
    ...baseRepository,

    /**
     * Process a new sale (Atomic Transaction)
     * Uses RPC 'procesar_venta' if online, fallback to Sync Queue if offline
     */
    /**
     * Process a new sale (Atomic Transaction V2)
     * Uses RPC 'rpc_procesar_venta_v2' - Financial Core
     */
    async processSale(saleData: SalePayload, storeId: string): Promise<SaleResponse> {
        const isOnline = navigator.onLine && isSupabaseConfigured();

        // 1. Try Online (RPC V2)
        if (isOnline) {
            const supabase = getSupabaseClient();
            if (supabase) {
                try {
                    // Refactoring: Ensure Strict Types for RPC & Validate Inputs
                    const p_items = saleData.items.map(item => {
                        const q = Number(item.quantity);
                        // V2: Price is NOT sent to backend for calculation, only ID and Qty
                        if (!Number.isFinite(q)) {
                            throw new Error(`Invalid item quantity: ${q}`);
                        }
                        return {
                            product_id: item.productId,
                            quantity: q
                        };
                    });

                    if (saleData.paymentMethod === 'mixed') {
                        throw new Error('El método de pago mixto no está permitido en este terminal POS.');
                    }

                    const p_amount_received = saleData.amountReceived ? new Decimal(saleData.amountReceived).toNumber() : null;

                    // Validate Employee ID
                    if (saleData.employeeId && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(saleData.employeeId)) {
                        console.warn('[SaleRepo] Invalid Employee UUID, sending NULL:', saleData.employeeId);
                        saleData.employeeId = undefined;
                    }

                    const normalizedPaymentMethod = (saleData.paymentMethod === 'cash') ? 'efectivo' : saleData.paymentMethod;
                    const sanitizedClientId = normalizedPaymentMethod === 'fiado' ? (saleData.clientId || null) : null;
                    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
                    const sanitizedBeneficiaryId = normalizedPaymentMethod === 'consumo_personal'
                        && saleData.beneficiaryEmployeeId
                        && uuidRegex.test(saleData.beneficiaryEmployeeId)
                        ? saleData.beneficiaryEmployeeId
                        : null;
                    const sanitizedOriginSessionId = saleData.originSessionId && uuidRegex.test(saleData.originSessionId)
                        ? saleData.originSessionId
                        : null;
                    const sanitizedSoldBy = saleData.employeeId && uuidRegex.test(saleData.employeeId)
                        ? saleData.employeeId
                        : null;

                    const rpcPayload = {
                        p_store_id: storeId,
                        p_client_id: sanitizedClientId,
                        p_payment_method: normalizedPaymentMethod,
                        p_amount_received: normalizedPaymentMethod === 'consumo_personal' ? 0 : p_amount_received,
                        p_items: p_items,
                        p_idempotency_key: crypto.randomUUID(),
                        p_local_id: crypto.randomUUID(),
                        p_is_offline_sync: false,
                        p_origin_session_id: sanitizedOriginSessionId,
                        p_sold_by: sanitizedSoldBy,
                        p_beneficiary_employee_id: sanitizedBeneficiaryId
                    };

                    const { data, error } = await supabase.rpc('rpc_procesar_venta_v3', rpcPayload);

                    if (error) {
                        logger.error('[SaleRepo] RPC V3 error:', error);
                        if (error.message && (error.message.includes('FetchError') || error.message.includes('Network request failed'))) {
                            // Fallthrough to offline
                        } else {
                            const mapped = mapSaleRpcError(error.message);
                            return { success: false, error: mapped.message, code: mapped.code };
                        }
                    } else {
                        if (data && data.success) {
                            const payloadData = (data as any).data ?? data;
                            return { 
                                success: true, 
                                id: payloadData.sale_id, 
                                ticketNumber: payloadData.ticket_number,
                                total: payloadData.total,
                                roundingDifference: payloadData.rounding_difference,
                                changeGiven: payloadData.change_given
                            };
                        } else {
                            const mapped = mapSaleRpcError((data as any)?.error);
                            return { success: false, error: mapped.message || 'Unknown RPC error', code: mapped.code };
                        }
                    }

                } catch (e) {
                    logger.error('[SaleRepo] RPC V2 exception:', e);
                }
            }
        }

        // 2. Offline Mode (Sync Queue)
        // PRODUCT.md / UX-ADR-007: Fiado y Retiro Personal ($0) exigen conexión en línea
        const normalizedOfflineMethod = (saleData.paymentMethod === 'mixed' || saleData.paymentMethod === 'cash')
            ? 'efectivo'
            : saleData.paymentMethod;
        if (normalizedOfflineMethod === 'fiado' || normalizedOfflineMethod === 'consumo_personal') {
            return {
                success: false,
                error: 'Las ventas fiadas y los retiros personales requieren conexión en línea.',
                code: 'OFFLINE_NOT_ALLOWED',
            };
        }

        // FRD-012-R: Validate locally BEFORE queueing to prevent invalid sales
        try {
            // 2.1 Validate Stock Local (RN-R01)
            const inventoryStore = useInventoryStore();

            for (const item of saleData.items) {
                const product = inventoryStore.getProductById(item.productId);
                if (!product) {
                    return {
                        success: false,
                        error: `Producto no encontrado: ${item.productName}`
                    };
                }
                const qty = new Decimal(item.quantity);
                if (product.stock.lt(qty)) {
                    // SPEC-011: Format decimal stock for UX consistency
                    const { formatStock } = useQuantityFormat();
                    const available = formatStock(product.stock, product.measurementUnit);

                    return {
                        success: false,
                        error: `Stock insuficiente para ${item.productName}. Disponible: ${available} ${product.measurementUnit || ''}`
                    };
                }
            }

            // 2.3 Queue Sale
            const newId = crypto.randomUUID();

            // FIX: Map payment method to DB constraint values BEFORE queueing
            // DB Constraint: payment_method = ANY (ARRAY['efectivo', 'nequi', 'llave_bre', 'fiado', 'consumo_personal'])
            const dbPaymentMethod = normalizedOfflineMethod;

            const enrichedPayload: Record<string, any> = {
                id: newId,
                localId: newId,
                storeId,
                clientId: dbPaymentMethod === 'fiado' ? (saleData.clientId ?? null) : null,
                employeeId: saleData.employeeId ?? null,
                originSessionId: saleData.originSessionId ?? null,
                beneficiaryEmployeeId: dbPaymentMethod === 'consumo_personal' ? (saleData.beneficiaryEmployeeId ?? null) : null,
                paymentMethod: dbPaymentMethod, // Override with DB-compatible value
                total: dbPaymentMethod === 'consumo_personal' ? 0 : new Decimal(saleData.total).toNumber(),
                items: saleData.items.map(item => ({
                    ...item,
                    price: new Decimal(item.price).toNumber(),
                    subtotal: new Decimal(item.subtotal).toNumber()
                }))
            };
            if (saleData.amountReceived !== undefined && saleData.amountReceived !== null) {
                enrichedPayload.amountReceived = new Decimal(saleData.amountReceived).toNumber();
            }
            if (saleData.payments) {
                enrichedPayload.payments = saleData.payments;
            }
            const queued = await addToSyncQueue('CREATE_SALE', enrichedPayload);

            if (queued) {
                return { success: true, id: newId };
            } else {
                return { success: false, error: 'Queue full or storage error' };
            }

        } catch (e: any) {
            return { success: false, error: e.message || 'Offline save failed' };
        }
    },

    /**
     * Force Sale (Admin Override for Insufficient Stock)
     * Uses RPC 'rpc_force_sale' - FRD-014
     * 
     * ARCHITECTURAL DECISION (2026-02-07): Force Sale is ONLINE ONLY.
     * Offline attempts are rejected to maintain data integrity and audit trail.
     */
    async forceSale(saleData: SalePayload, storeId: string, justification: string): Promise<{ success: boolean; id?: string; ticketNumber?: number; error?: string }> {
        const isOnline = navigator.onLine && isSupabaseConfigured();

        // ARCH DECISION: Force Sale requires online connection
        if (!isOnline) {
            logger.warn('[SaleRepo] Force Sale blocked - requires online connection');
            return {
                success: false,
                error: 'Conecta a internet para forzar ventas. Las ventas forzadas requieren conexión para auditoría inmediata.'
            };
        }

        // Online RPC Call
        const supabase = getSupabaseClient();
        if (!supabase) {
            return { success: false, error: 'Supabase client not configured' };
        }

        try {
            const p_items = saleData.items.map(item => {
                const q = Number(item.quantity);
                if (!Number.isFinite(q)) {
                    throw new Error(`Invalid item quantity: ${q}`);
                }
                return {
                    product_id: item.productId,
                    quantity: q
                };
            });

            const rpcPayload = {
                p_store_id: storeId,
                p_client_id: saleData.clientId || null,
                p_payment_method: (saleData.paymentMethod === 'mixed' || saleData.paymentMethod === 'cash') ? 'efectivo' : saleData.paymentMethod,
                p_amount_received: saleData.amountReceived ? Number(saleData.amountReceived) : null,
                p_items: p_items,
                p_justification: justification
            };

            const { data, error } = await supabase.rpc('rpc_force_sale', rpcPayload);

            if (error) {
                logger.error('[SaleRepo] Force Sale RPC error:', error);
                return { success: false, error: error.message };
            }

            if (data && data.success) {
                logger.log('[SaleRepo] ✅ Force Sale successful:', data.sale_id);
                return { success: true, id: data.sale_id, ticketNumber: data.ticket_number };
            }

            return { success: false, error: data?.error || 'Unknown RPC error' };
        } catch (e: any) {
            logger.error('[SaleRepo] Force Sale exception:', e);
            return { success: false, error: e.message || 'Force sale failed' };
        }
    },

    /**
     * Void a sale (Atomic Reversal)
     * Uses RPC 'rpc_anular_venta'
     */
    async voidSale(saleId: string, reason: string): Promise<{ success: boolean; error?: string }> {
        if (!navigator.onLine || !isSupabaseConfigured()) {
            return { success: false, error: 'Voiding requires online connection' };
        }

        const supabase = getSupabaseClient();
        if (!supabase) return { success: false, error: 'Supabase not initialized' };

        try {
            const { data, error } = await supabase.rpc('rpc_anular_venta', {
                p_sale_id: saleId,
                p_reason: reason
            });

            if (error) {
                logger.error('[SaleRepo] Void Sale RPC error:', error);
                const mapped = mapSaleRpcError(error.message);
                return { success: false, error: mapped.message };
            }

            if (data && data.success) {
                return { success: true };
            } else {
                const mapped = mapSaleRpcError(data?.error);
                return { success: false, error: mapped.message || 'Void failed' };
            }
        } catch (e: any) {
            return { success: false, error: e.message };
        }
    },

    /**
     * Get sales by date range with full items join
     */
    async getByDateRange(startDate: string, endDate: string, storeId?: string): Promise<Sale[]> {
        if (!storeId) return [];
        const isOnline = navigator.onLine && isSupabaseConfigured();

        if (isOnline) {
            const supabase = getSupabaseClient();
            if (supabase) {
                // Normalize Start/End dates to ISO timestamps
                const startIso = startDate.includes('T') ? startDate : `${startDate}T00:00:00`;
                const endIso = endDate.includes('T') ? endDate : `${endDate}T23:59:59`;

                // Fetch sales with items and product names
                const { data, error } = await supabase
                    .from('sales')
                    .select(`
                        *,
                        sale_items (
                            product_id,
                            quantity,
                            unit_price,
                            subtotal,
                            products ( name )
                        )
                    `)
                    .eq('store_id', storeId)
                    .gte('created_at', startIso)
                    .lte('created_at', endIso)
                    .order('created_at', { ascending: false });

                if (error) {
                    logger.error('[SaleRepo] Failed to fetch sales breakdown', error);
                    return [];
                }

                if (data) {
                    return data.map((row: any) => ({
                        id: row.id,
                        ticketNumber: row.ticket_number,
                        date: row.created_at.split('T')[0],
                        timestamp: row.created_at,
                        // Fix 1: Map 'efectivo' to 'cash' for frontend consistency
                        paymentMethod: row.payment_method === 'efectivo' ? 'cash' : row.payment_method,
                        total: new Decimal(row.total),
                        items: row.sale_items.map((item: any) => ({
                            productId: item.product_id,
                            productName: item.products?.name || 'Producto Desconocido',
                            quantity: item.quantity, // Number in DB
                            price: new Decimal(item.unit_price),
                            subtotal: new Decimal(item.subtotal)
                        })),
                        roundingDifference: row.rounding_difference ? new Decimal(row.rounding_difference) : undefined,
                        effectiveTotal: new Decimal(row.total).add(row.rounding_difference ? new Decimal(row.rounding_difference) : 0),
                        amountReceived: row.amount_received ? new Decimal(row.amount_received) : undefined,
                        change: row.change_given ? new Decimal(row.change_given) : undefined,
                        clientId: row.client_id || undefined,
                        employeeId: row.employee_id,
                        syncStatus: row.sync_status
                    }));
                }
            }
        }

        // Fallback to basic getAll (local persistence might lack items if not cached properly, 
        // but typically serialization saves items)
        const all = await baseRepository.getAll(storeId);
        return all.filter(s => {
            return s.date >= startDate && s.date <= endDate;
        });
    },

    async getLastTicketNumber(storeId: string): Promise<number> {
        if (navigator.onLine && isSupabaseConfigured()) {
            // Optimizing query to handle "no sales" case without 406 error
            const supabase = getSupabaseClient();
            if (supabase) {
                const { data } = await supabase
                    .from('sales')
                    .select('ticket_number')
                    .eq('store_id', storeId)
                    .order('ticket_number', { ascending: false })
                    .limit(1)
                    .maybeSingle();

                if (data) return data.ticket_number;
            }
        }
        return 0;
    },

    async getSaleDetail(saleId: string): Promise<any> {
        const supabase = getSupabaseClient();
        if (!supabase) throw new Error('Sin conexión');
        const { data, error } = await supabase.rpc('get_sale_detail' as any, {
            p_sale_id: saleId
        });
        if (error) throw error;
        return data;
    },

    async searchRefundCandidates(storeId: string, query?: string, limit: number = 20): Promise<RefundCandidateSale[]> {
        const supabase = getSupabaseClient();
        if (!supabase) throw new Error('Sin conexión activa con el servidor.');

        const { data, error } = await supabase.rpc('rpc_buscar_ventas_para_reembolso', {
            p_store_id: storeId,
            p_query: query?.trim() || undefined,
            p_limit: limit
        });

        if (error) {
            const mapped = mapRefundRpcError(error.message);
            const err: any = new Error(mapped.message);
            err.code = mapped.code;
            throw err;
        }

        const res = data as any;
        const rows: RefundCandidateSale[] = Array.isArray(res?.data) ? res.data : [];
        return rows.map((sale) => ({
            ...sale,
            items: Array.isArray(sale.items)
                ? sale.items.map((item) => ({
                    ...item,
                    fifo_batches: Array.isArray(item.fifo_batches)
                        ? item.fifo_batches.map((b) => ({
                            batch_id: String(b.batch_id),
                            quantity: Number(b.quantity),
                            unit_cost: Number(b.unit_cost),
                            created_at: b.created_at ?? null,
                        }))
                        : [],
                }))
                : [],
        }));
    },

    async processItemRefund(payload: ProcessRefundPayload): Promise<ProcessRefundResult> {
        const supabase = getSupabaseClient();
        if (!supabase) throw new Error('Sin conexión activa con el servidor.');

        const { data, error } = await supabase.rpc('rpc_procesar_reembolso_item', {
            p_sale_item_id: payload.saleItemId,
            p_quantity: payload.quantity,
            p_refund_channel: payload.refundChannel,
            p_original_channel: payload.originalChannel,
            p_reason: payload.reason,
            p_is_merma: payload.isMerma
        });

        if (error) {
            const mapped = mapRefundRpcError(error.message);
            const err: any = new Error(mapped.message);
            err.code = mapped.code;
            throw err;
        }

        const res = data as any;
        if (!res || res.success === false || !res.data) {
            const mapped = mapRefundRpcError(res?.error || 'Error procesando reembolso');
            const err: any = new Error(mapped.message);
            err.code = mapped.code;
            throw err;
        }

        const d = res.data;
        try {
            const inventoryStore = useInventoryStore();
            if (payload.isMerma === false && typeof d.new_stock === 'number') {
                // Re-sincronizar stock del producto reembolsado en memoria desde la verdad del servidor
                await inventoryStore.fetchProducts(undefined);
            }
        } catch (syncErr) {
            logger.warn('[SaleRepo] No se pudo refrescar inventario tras reembolso:', syncErr);
        }

        return {
            cashMovementId: d.cash_movement_id,
            inventoryMovementId: d.inventory_movement_id,
            saleId: d.sale_id,
            saleItemId: d.sale_item_id,
            ticketNumber: Number(d.ticket_number),
            amountRefunded: Number(d.amount_refunded),
            quantityRefunded: Number(d.quantity_refunded),
            refundChannel: d.refund_channel,
            originalChannel: d.original_channel,
            isMerma: Boolean(d.is_merma),
            newStock: Number(d.new_stock),
            actorName: d.actor_name,
            actorRole: d.actor_role
        };
    }
};

export default saleRepository;

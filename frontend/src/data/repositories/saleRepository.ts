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

import { Sale, SaleItem } from '../../types';
import { Database } from '../../types/database.types';
import { Decimal } from 'decimal.js';
import { createSupabaseRepository, EntityRepository, RepositoryMappers } from './supabaseAdapter';
import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { logger } from '../../utils/logger';
import { addToSyncQueue } from '../syncQueue';

// Constants
const TABLE_NAME = 'sales';
const STORAGE_KEY = 'tienda-sales';

// Type definitions
type SaleDB = Database['public']['Tables']['sales']['Row'];
type SaleInsert = Database['public']['Tables']['sales']['Insert'];

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
            employeeId: row.employee_id,
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
            payment_method: entity.paymentMethod,
            total: entity.total.toNumber(),
            employee_id: entity.employeeId || '',
            client_id: entity.clientId || null,
            amount_received: entity.amountReceived ? entity.amountReceived.toNumber() : null,
            change_given: entity.change ? entity.change.toNumber() : null,
            rounding_difference: entity.roundingDifference ? entity.roundingDifference.toNumber() : null,
            is_voided: false,
            void_reason: null,
            voided_by: null,
            local_id: null,
            sync_status: entity.syncStatus || 'synced',
            store_id: storeId // NO FALLBACK - validated above
        };
    }
};

/**
 * Interface extending base repository with sale-specific methods
 */
interface SalePayload {
    items: {
        productId: string;
        productName: string;
        quantity: number;
        price: any; // Decimal or number
        subtotal: any; // Decimal or number
    }[];
    total: any; // Decimal or number
    paymentMethod: 'cash' | 'nequi' | 'fiado' | 'mixed';
    payments?: { method: 'cash' | 'nequi' | 'fiado', amount: number, reference?: string }[];
    amountReceived?: any; // Decimal or number
    clientId?: string;
    employeeId?: string;
}

export interface SaleRepository extends EntityRepository<Sale> {
    processSale(saleData: SalePayload, storeId: string): Promise<{ success: boolean; id?: string; ticketNumber?: number; error?: string }>;
    getByDateRange(startDate: string, endDate: string, storeId?: string): Promise<Sale[]>;
    getLastTicketNumber(storeId: string): Promise<number>;
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
    async processSale(saleData: SalePayload, storeId: string): Promise<{ success: boolean; id?: string; ticketNumber?: number; error?: string }> {
        const isOnline = navigator.onLine && isSupabaseConfigured();

        // 1. Try Online (RPC)
        if (isOnline) {
            const supabase = getSupabaseClient();
            if (supabase) {
                try {
                    // Refactoring: Ensure Strict Types for RPC & Validate Inputs
                    // Decimal -> number conversion is critical here
                    const p_items = saleData.items.map(item => {
                        const q = Number(item.quantity);
                        const p = new Decimal(item.price).toNumber();
                        const s = new Decimal(item.subtotal).toNumber();

                        // Guard against NaN or "N/A" logic slippage
                        if (!Number.isFinite(q) || !Number.isFinite(p)) {
                            throw new Error(`Invalid item data: Quantity=${q}, Price=${p}`);
                        }

                        return {
                            product_id: item.productId,
                            quantity: q,
                            unit_price: p,
                            subtotal: s
                        };
                    });

                    const p_amount_received = saleData.amountReceived ? new Decimal(saleData.amountReceived).toNumber() : null;

                    // Validate Employee ID if present
                    if (saleData.employeeId && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(saleData.employeeId)) {
                        console.warn('[SaleRepo] Invalid Employee UUID, sending NULL to avoid RPC error:', saleData.employeeId);
                        saleData.employeeId = undefined; // Fallback to null (DB allows null for employee_id usually, or RLS handles it)
                    }

                    // FIX: Match DB Schema for payment method ('efectivo' per Constraint)
                    // FIX: Match DB Schema for item price key ('unit_price' per RPC definition)

                    // Remap items to strict schema structure
                    const rpcItems = p_items.map(i => ({
                        product_id: i.product_id,
                        quantity: i.quantity,
                        unit_price: i.unit_price, // RPC expects 'unit_price'
                        subtotal: i.subtotal
                    }));

                    const rpcPayload = {
                        p_store_id: storeId,
                        p_employee_id: saleData.employeeId || null,
                        p_items: rpcItems,
                        p_total: new Decimal(saleData.total).toNumber(),
                        p_payment_method: (saleData.paymentMethod === 'mixed' || saleData.paymentMethod === 'cash') ? 'efectivo' : saleData.paymentMethod,
                        p_amount_received: p_amount_received,
                        p_client_id: saleData.clientId || null
                    };
                    // console.log('[SaleRepo] DEBUG RPC Payload:', JSON.stringify(rpcPayload, null, 2));

                    const { data, error } = await supabase.rpc('procesar_venta', rpcPayload);

                    if (error) {
                        logger.error('[SaleRepo] RPC error:', error);
                        // If network error, fall through to offline handling
                        if (error.message && (error.message.includes('FetchError') || error.message.includes('Network request failed'))) {
                            // Fallthrough
                        } else {
                            return { success: false, error: error.message };
                        }
                    } else {
                        if (data && data.success) {
                            // FIX: RPC returns 'sale_id' not 'id'
                            return { success: true, id: data.sale_id || data.id, ticketNumber: data.ticket_number };
                        } else {
                            return { success: false, error: data?.error || 'Unknown RPC error' };
                        }
                    }

                } catch (e) {
                    logger.error('[SaleRepo] RPC exception:', e);
                    // Fallthrough to offline
                }
            }
        }

        // 2. Offline Mode (Sync Queue)
        // Add to IndexedDB queue for later processing
        try {
            // Generate ID client-side for UI consistency
            const newId = crypto.randomUUID();

            // Normalize Payload for Queue
            // Ensure numbers for storage to match RPC expectations later
            const enrichedPayload = {
                ...saleData,
                // Ensure primitives for storage
                total: new Decimal(saleData.total).toNumber(),
                amountReceived: saleData.amountReceived ? new Decimal(saleData.amountReceived).toNumber() : undefined,
                items: saleData.items.map(item => ({
                    ...item,
                    price: new Decimal(item.price).toNumber(),
                    subtotal: new Decimal(item.subtotal).toNumber()
                })),
                storeId,
                id: newId
            };

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
    }
};

export default saleRepository;

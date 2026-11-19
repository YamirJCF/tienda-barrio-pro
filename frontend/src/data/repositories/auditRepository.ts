import { getSupabaseClient } from '../supabaseClient';
import { logger } from '../../utils/logger';

export type SecurityEventType =
    | 'login_success'
    | 'login_failed'
    | 'pin_change'
    | 'unauthorized_access'
    | 'unauthorized_shift_close'
    | 'cash_discrepancy_alert'
    | 'cash_discrepancy'
    | 'forced_close_24h'
    | 'forced_close_no_count'
    | 'admin_forced_close_no_count'
    | 'force_sale'
    | 'session_expired'
    | 'role_change'
    | 'employee_deactivated'
    | 'device_access_approve'
    | 'device_access_reject'
    | 'device_access_revoke'
    | 'concurrent_mutation_blocked'
    | 'inventory_count_adjustment'
    | 'business_consumption'
    | 'personal_withdrawal'
    | 'refund_merma'
    | 'sale_voided'
    | 'correction'
    | 'transaction_correction';

export type AuditSeverity = 'info' | 'warning' | 'critical';
export type EvidenceHubDomain =
    | 'todos'
    | 'caja'
    | 'ventas'
    | 'inventario'
    | 'seguridad'
    | 'precios'
    | 'creditos';

export interface AuditLog {
    id: string;
    created_at: string;
    store_id: string;
    event_type: string;
    user_name?: string;
    actor_name?: string;
    actor_role?: string;
    details?: Record<string, any>;
    severity: AuditSeverity;
}

export interface EvidenceHubEvent {
    id: string;
    domain: Exclude<EvidenceHubDomain, 'todos'>;
    event_type: string;
    severity: AuditSeverity;
    resource_id: string | null;
    actor_id: string | null;
    actor_name: string;
    actor_role: string;
    ip_address: string | null;
    created_at: string;
    metadata: Record<string, any>;
}

export interface EvidenceHubParams {
    storeId: string;
    domain?: EvidenceHubDomain;
    eventType?: string | null;
    severity?: AuditSeverity | null;
    startDate?: string;
    endDate?: string;
    limit?: number;
    offset?: number;
}

export const AUDIT_EVENT_CATALOG: Record<string, { label: string; severity: AuditSeverity }> = {
    LOGIN_SUCCESS: { label: 'Inicio de Sesión', severity: 'info' },
    LOGIN_FAILED: { label: 'Intento de Login Fallido', severity: 'warning' },
    PIN_CHANGE: { label: 'Cambio de PIN', severity: 'info' },
    UNAUTHORIZED_ACCESS: { label: 'Acceso Denegado', severity: 'critical' },
    UNAUTHORIZED_SHIFT_CLOSE: { label: 'Intento de Cierre de Turno Ajeno', severity: 'critical' },
    CASH_DISCREPANCY_ALERT: { label: 'Alerta Crítica de Descuadre de Caja', severity: 'critical' },
    CASH_DISCREPANCY: { label: 'Diferencia en Arqueo de Caja', severity: 'warning' },
    FORCED_CLOSE_24H: { label: 'Cierre Forzado por Caducidad (24h)', severity: 'warning' },
    FORCED_CLOSE_NO_COUNT: { label: 'Cierre Forzado sin Conteo Físico', severity: 'critical' },
    ADMIN_FORCED_CLOSE_NO_COUNT: { label: 'Cierre Administrativo sin Conteo', severity: 'critical' },
    FORCE_SALE: { label: 'Venta Fiada Forzada (Sobregiro)', severity: 'warning' },
    SESSION_EXPIRED: { label: 'Sesión Expirada', severity: 'info' },
    ROLE_CHANGE: { label: 'Cambio de Permisos / Rol', severity: 'warning' },
    EMPLOYEE_DEACTIVATED: { label: 'Colaborador Desactivado', severity: 'warning' },
    DEVICE_ACCESS_APPROVE: { label: 'Dispositivo Autorizado', severity: 'info' },
    DEVICE_ACCESS_REJECT: { label: 'Dispositivo Rechazado', severity: 'warning' },
    DEVICE_ACCESS_REVOKE: { label: 'Acceso de Dispositivo Revocado', severity: 'warning' },
    CONCURRENT_MUTATION_BLOCKED: { label: 'Mutación Concurrente Bloqueada', severity: 'critical' },
    INVENTORY_COUNT_ADJUSTMENT: { label: 'Ajuste por Conteo Físico', severity: 'warning' },
    BUSINESS_CONSUMPTION: { label: 'Consumo Interno del Negocio', severity: 'info' },
    PERSONAL_WITHDRAWAL: { label: 'Retiro Personal ($0 Caja)', severity: 'info' },
    REFUND_MERMA: { label: 'Devolución Registrada como Merma', severity: 'warning' },
    SALE_VOIDED: { label: 'Venta Anulada', severity: 'warning' },
    CORRECTION: { label: 'Asiento Correctivo', severity: 'warning' },
    TRANSACTION_CORRECTION: { label: 'Corrección Transaccional', severity: 'warning' },
    APERTURA: { label: 'Apertura de Caja', severity: 'info' },
    CIERRE: { label: 'Cierre de Caja', severity: 'info' },
    CREACION: { label: 'Venta Registrada', severity: 'info' },
    ANULACION: { label: 'Anulación de Venta', severity: 'warning' },
    PRICE_CHANGE: { label: 'Cambio de Precio / Costo', severity: 'info' },
};

function normalizeAuditError(error: any, fallback: string): Error {
    const raw = String(error?.message || error || '');
    if (raw.includes('ADMIN_ONLY_ACTION') || error?.code === '42501') {
        return new Error('ADMIN_ONLY_ACTION: Acceso exclusivo del Administrador.');
    }
    if (raw.includes('STORE_ACCESS_DENIED')) {
        return new Error('STORE_ACCESS_DENIED: No tienes acceso a esta tienda.');
    }
    if (raw.includes('INVALID_DATE_RANGE')) {
        return new Error('INVALID_DATE_RANGE: La fecha inicial no puede ser posterior a la fecha final.');
    }
    return new Error(raw || fallback);
}

function getClientOrThrow() {
    const supabase = getSupabaseClient();
    if (!supabase) {
        throw new Error('Sin conexión con el servidor de auditoría.');
    }
    return supabase;
}

export const auditRepository = {
    /**
     * Log a security/audit event via SECURITY DEFINER RPC.
     */
    async logEvent(
        storeId: string,
        eventType: SecurityEventType | string,
        severity: AuditSeverity = 'info',
        details: Record<string, any> = {},
        userId?: string
    ): Promise<void> {
        try {
            const supabase = getSupabaseClient();
            if (!supabase) return;

            const metadata = {
                ...details,
                severity,
                ...(userId ? { actor_id: userId } : {}),
            };

            const { error } = await supabase.rpc('rpc_log_security_event', {
                p_event_type: eventType,
                p_store_id: storeId,
                p_metadata: metadata,
            });

            if (error) {
                logger.warn('[AuditRepository] Failed to log event via RPC:', error.message);
            }
        } catch (err) {
            logger.warn('[AuditRepository] Error logging security event:', err);
        }
    },

    /**
     * Unified Federated Evidence Hub (100% Admin-only via RPC, { data, count })
     */
    async getEvidenceHub(params: EvidenceHubParams): Promise<{ data: EvidenceHubEvent[]; count: number }> {
        const supabase = getClientOrThrow();
        const { data, error } = await supabase.rpc('rpc_obtener_auditoria_evidence_hub', {
            p_store_id: params.storeId,
            p_domain: params.domain || 'todos',
            p_event_type: params.eventType || undefined,
            p_severity: params.severity || undefined,
            p_start_date: params.startDate || undefined,
            p_end_date: params.endDate || undefined,
            p_limit: params.limit ?? 50,
            p_offset: params.offset ?? 0,
        });

        if (error) {
            logger.error('[AuditRepository] Evidence Hub RPC failed:', error);
            throw normalizeAuditError(error, 'Error cargando Centro de Evidencias');
        }

        const payload = (data || {}) as { data?: EvidenceHubEvent[]; count?: number };
        return {
            data: Array.isArray(payload.data) ? payload.data : [],
            count: Number(payload.count ?? 0),
        };
    },

    /**
     * Mark an operational alert / audit log entry as reviewed by Admin
     */
    async markAsReviewed(auditId: string, notes?: string): Promise<void> {
        const supabase = getClientOrThrow();
        const { data, error } = await supabase.rpc('rpc_marcar_auditoria_revisada', {
            p_audit_id: auditId,
            p_notes: notes || undefined,
        });
        if (error) {
            throw normalizeAuditError(error, 'No se pudo visar el registro de auditoría');
        }
        if (!(data as any)?.success) {
            throw new Error('No se pudo confirmar la revisión de auditoría');
        }
    },

    /**
     * Fetch security logs (Regla 3: nunca silenciar errores retornando [])
     */
    async getLogs(storeId: string, limit = 50, offset = 0): Promise<AuditLog[]> {
        const supabase = getClientOrThrow();
        const { data, error } = await supabase
            .from('audit_seguridad')
            .select('*, employees:actor_id(name)')
            .eq('store_id', storeId)
            .order('created_at', { ascending: false })
            .range(offset, offset + limit - 1);

        if (error) {
            logger.error('[AuditRepository] Error fetching logs:', error);
            throw normalizeAuditError(error, 'Error al consultar bitácora de seguridad');
        }

        return (data || []).map((row: any) => {
            const snapshotName = row.actor_name || row.employees?.name || 'Sistema';
            const upperType = String(row.event_type || '').toUpperCase();
            const catalogSeverity = AUDIT_EVENT_CATALOG[upperType]?.severity || 'info';
            return {
                id: row.id,
                created_at: row.created_at,
                store_id: row.store_id,
                event_type: row.event_type,
                user_name: snapshotName,
                actor_name: snapshotName,
                actor_role: row.actor_role || (row.employees ? 'employee' : 'owner'),
                details: row.metadata || {},
                severity: (row.metadata?.severity as AuditSeverity) || catalogSeverity,
            };
        });
    },

    /**
     * Fetch price change audit logs (FRD-010, Regla 3: nunca silenciar errores retornando [])
     */
    async getPriceChangeLogs(storeId: string, limit = 50): Promise<any[]> {
        const supabase = getClientOrThrow();
        const { data, error } = await supabase
            .from('audit_precios')
            .select('*, products(name), employees(name)')
            .eq('store_id', storeId)
            .order('created_at', { ascending: false })
            .limit(limit);

        if (error) {
            logger.error('[AuditRepository] Error fetching price change logs:', error);
            throw normalizeAuditError(error, 'Error al consultar auditoría de precios');
        }

        return (data || []).map((row: any) => ({
            id: row.id,
            productId: row.product_id,
            productName: row.products?.name || 'Producto',
            oldCost: Number(row.old_cost),
            newCost: Number(row.new_cost),
            oldPrice: Number(row.old_price),
            newPrice: Number(row.new_price),
            employeeName: row.actor_name || row.employees?.name || 'Administrador',
            actor_name: row.actor_name || row.employees?.name || 'Administrador',
            actor_role: row.actor_role || (row.employees ? 'employee' : 'owner'),
            date: row.created_at,
        }));
    },
};

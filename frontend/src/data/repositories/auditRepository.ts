import { supabase } from '../../lib/supabase';
import { logger } from '../../utils/logger';

export interface AuditLog {
    id: string;
    created_at: string;
    store_id: string;
    user_id?: string;
    event_type: 'login_success' | 'login_failed' | 'pin_change' | 'unauthorized_access' | 'price_change' | 'stock_adjustment' | 'shift_modified' | 'SALE_CREATED';
    severity: 'info' | 'warning' | 'critical';
    details: Record<string, any>;
    ip_address?: string;
    user_name?: string; // Joined field
}

export const auditRepository = {
    /**
     * Registrar un evento de auditoría (Client-side)
     * Nota: Eventos críticos como 'login_failed' se registran mejor desde RPC/Backend,
     * pero esto permite reportar eventos de UI (ej: navegación no autorizada).
     */
    async logEvent(
        storeId: string,
        eventType: AuditLog['event_type'],
        severity: AuditLog['severity'] = 'info',
        details: Record<string, any> = {},
        userId?: string
    ): Promise<boolean> {
        try {
            // Guardamos la severidad dentro del metadata ya que la nueva tabla no tiene columna explícita
            const metadata = { ...details, severity, client_user_id: userId };
            
            const { error } = await supabase.rpc('rpc_log_security_event', {
                p_event_type: eventType,
                p_store_id: storeId,
                p_metadata: metadata
            });

            if (error) {
                logger.error('[AuditRepo] Failed to log event via RPC', error);
                return false;
            }
            return true;
        } catch (e) {
            logger.error('[AuditRepo] Exception logging event', e);
            return false;
        }
    },

    /**
     * Obtener historial de auditoría con filtros
     */
    async getLogs(
        storeId: string,
        limit = 50,
        offset = 0,
        filters?: { severity?: string; eventType?: string; userId?: string }
    ): Promise<AuditLog[]> {
        try {
            let query = supabase
                .from('audit_seguridad')
                .select(`
          *,
          employees:actor_id (name)
        `)
                .eq('store_id', storeId)
                .order('created_at', { ascending: false })
                .range(offset, offset + limit - 1);

            if (filters?.eventType) query = query.eq('event_type', filters.eventType);
            if (filters?.userId) query = query.eq('actor_id', filters.userId);

            const { data, error } = await (query as any);

            if (error) throw error;

            return (data || []).map((log: any) => ({
                ...log,
                severity: log.metadata?.severity || 'info',
                details: log.metadata, // Correctly map DB metadata to Domain details
                user_name: log.employees?.name || 'Sistema/Desconocido'
            }));
        } catch (e) {
            logger.error('[AuditRepo] Failed to fetch logs', e);
            return [];
        }
    },

    /**
     * Obtener historial de cambios de precios (para módulo de Precios)
     */
    async getPriceChangeLogs(storeId: string, limit = 20): Promise<any[]> {
        try {
            const { data, error } = await (supabase
                .from('audit_precios')
                .select(`
          *,
          employees:changed_by (name),
          products:product_id (name, plu)
        `)
                .eq('store_id', storeId)
                .order('created_at', { ascending: false })
                .limit(limit) as any);

            if (error) throw error;

            return (data || []).map((log: any) => ({
                id: log.id,
                date: log.created_at,
                productName: log.products?.name,
                productPlu: log.products?.plu,
                employeeName: log.employees?.name,
                oldPrice: log.old_price,
                newPrice: log.new_price,
                reason: log.metadata?.reason
            }));
        } catch (e) {
            logger.error('[AuditRepo] Failed to fetch price logs', e);
            return [];
        }
    }
};

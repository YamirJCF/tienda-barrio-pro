import { supabase } from '../../lib/supabase';
import { logger } from '../../utils/logger';
import type { CurrentUser } from '../../stores/auth';

export interface LoginResponse {
    success: boolean;
    employee?: CurrentUser;
    store_state?: { is_open: boolean };
    error_code?: string;
    error?: string;
}

export const authRepository = {
    /**
     * SPEC-005: Login unificado de empleado (Gatekeeper de 3 capas)
     */
    async loginEmpleado(
        username: string,
        pin: string,
        fingerprint: string,
        userAgent: string
    ): Promise<LoginResponse> {
        try {
            const { data, error } = await supabase.rpc('login_empleado_unificado', {
                p_username: username.toLowerCase(),
                p_pin: pin,
                p_device_fingerprint: fingerprint,
                p_user_agent: userAgent
            });

            if (error) {
                logger.error('[AuthRepository] Error in login_empleado_unificado:', error);
                return {
                    success: false,
                    error: error.message
                };
            }

            const response = data as any;

            if (!response.success) {
                return {
                    success: false,
                    error_code: response.error_code,
                    error: response.error
                };
            }

            // Transform response to CurrentUser format
            const employee: CurrentUser = {
                id: response.employee.id,
                name: response.employee.name,
                email: response.employee.username,
                type: 'employee',
                storeId: response.employee.store_id,
                employeeId: response.employee.id,
                permissions: response.employee.permissions
            };

            return {
                success: true,
                employee,
                store_state: response.store_state
            };
        } catch (err) {
            logger.error('[AuthRepository] Unexpected error:', err);
            return {
                success: false,
                error: 'Error inesperado en el servidor'
            };
        }
    },

    /**
     * Obtener solicitudes de acceso pendientes para el admin
     */
    async getPendingAccessRequests(storeId: string) {
        const { data, error } = await supabase
            .from('access_requests')
            .select('*, employees!inner(name, store_id)')
            .eq('status', 'pending')
            .eq('employees.store_id', storeId)
            .order('created_at', { ascending: false });

        if (error) {
            logger.error('[AuthRepository] Error fetching pending requests:', error);
            throw error;
        }

        return data.map(r => ({
            id: r.id,
            employeeId: r.employee_id,
            employeeName: r.employees.name,
            deviceFingerprint: r.device_fingerprint,
            userAgent: r.user_agent,
            status: r.status,
            requestedAt: r.created_at
        }));
    },

    /**
     * Obtener dispositivos autorizados
     */
    async getAuthorizedDevices(storeId: string) {
        const { data, error } = await supabase
            .from('access_requests')
            .select('*, employees!inner(name, store_id)')
            .eq('status', 'approved')
            .eq('employees.store_id', storeId)
            .order('reviewed_at', { ascending: false });

        if (error) {
            logger.error('[AuthRepository] Error fetching authorized devices:', error);
            throw error;
        }

        return data.map(r => ({
            id: r.id,
            employeeId: r.employee_id,
            employeeName: r.employees.name,
            deviceFingerprint: r.device_fingerprint,
            userAgent: r.user_agent,
            status: r.status,
            requestedAt: r.created_at
        }));
    },

    /**
     * Aprobar o rechazar solicitud de acceso
     */
    async updateAccessRequestStatus(requestId: string, status: 'approved' | 'rejected', reviewedBy: string) {
        const { data, error } = await supabase
            .from('access_requests')
            .update({
                status,
                reviewed_by: reviewedBy,
                reviewed_at: new Date().toISOString()
            })
            .eq('id', requestId);

        if (error) {
            logger.error('[AuthRepository] Error updating access request:', error);
            throw error;
        }

        return data;
    }
};

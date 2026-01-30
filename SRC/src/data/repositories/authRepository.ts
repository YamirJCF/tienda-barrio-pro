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

import { isAuditMode } from '../../data/supabaseClient';

export const authRepository = {
    /**
     * SPEC-005: Login unificado de empleado (Gatekeeper de 3 capas)
     * Updated for Schema v2: Uses 'validar_pin_empleado' RPC
     */
    async loginEmpleado(
        username: string,
        pin: string,
        fingerprint: string,
        userAgent: string
    ): Promise<LoginResponse> {
        // 🛡️ AUDIT MODE MOCK
        if (isAuditMode()) {
            logger.log('[AuthRepo] 🛡️ Audit Mode: Mocking login success');
            return {
                success: true,
                employee: {
                    id: 'mock-emp-001',
                    name: 'Empleado Demo (Auditoría)',
                    email: username || 'demo@audit.com',
                    type: 'employee',
                    storeId: 'audit-store-001',
                    employeeId: 'mock-emp-001',
                    permissions: {
                        canSell: true,
                        canViewInventory: true,
                        canViewReports: true,
                        canFiar: true,
                        canOpenCloseCash: true,
                        canManageInventory: true,
                        canManageClients: true
                    }
                },
                store_state: { is_open: true }
            };
        }

        try {
            // Updated to use 'validar_pin_empleado' which exists in Schema v2
            const { data, error } = await supabase.rpc('validar_pin_empleado', {
                p_username: username.toLowerCase(),
                p_pin: pin
            });

            if (error) {
                logger.error('[AuthRepository] Error in validar_pin_empleado:', error);
                return {
                    success: false,
                    error: error.message
                };
            }

            const response = data as any;

            if (!response.success) {
                return {
                    success: false,
                    error_code: response.error_code || 'AUTH_FAILED',
                    error: response.message || response.error || 'Credenciales inválidas'
                };
            }

            // Note: validar_pin_empleado returns employee info but maybe not store_state?
            // Schema v2 validates PIN. We might need to fetch store state separately or logic resides in middleware.
            // Assuming response structure contains necessary info based on "Json" return type.

            const employee: CurrentUser = {
                id: response.employee.id,
                name: response.employee.name,
                email: response.employee.username,
                type: 'employee',
                storeId: response.employee.store_id,
                employeeId: response.employee.id,
                permissions: response.employee.permissions || {}
            };

            return {
                success: true,
                employee,
                store_state: response.store_state || { is_open: false } // Fallback if not provided
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
     * Updated: 'access_requests' -> 'daily_passes'
     */
    async getPendingAccessRequests(storeId: string) {
        const { data, error } = await supabase
            .from('daily_passes')
            .select('*, employees!inner(name, store_id)')
            .eq('status', 'pending')
            .eq('employees.store_id', storeId)
            .order('requested_at', { ascending: false });

        if (error) {
            logger.error('[AuthRepository] Error fetching pending requests:', error);
            throw error;
        }

        return data.map((r: any) => ({
            id: r.id,
            employeeId: r.employee_id,
            employeeName: r.employees.name,
            deviceFingerprint: r.device_fingerprint,
            userAgent: 'N/A', // Not stored in daily_passes? Table def says 'device_fingerprint'. Row 306 'requested_at'. User agent might be missing.
            status: r.status,
            requestedAt: r.requested_at
        }));
    },

    /**
     * Obtener dispositivos autorizados
     * Updated: 'access_requests' -> 'daily_passes'
     */
    async getAuthorizedDevices(storeId: string) {
        const { data, error } = await supabase
            .from('daily_passes')
            .select('*, employees!inner(name, store_id)')
            .eq('status', 'approved')
            .eq('employees.store_id', storeId)
            .order('resolved_at', { ascending: false });

        if (error) {
            logger.error('[AuthRepository] Error fetching authorized devices:', error);
            throw error;
        }

        return data.map((r: any) => ({
            id: r.id,
            employeeId: r.employee_id,
            employeeName: r.employees.name,
            deviceFingerprint: r.device_fingerprint,
            userAgent: 'N/A',
            status: r.status,
            requestedAt: r.requested_at // pass_date?
        }));
    },

    /**
     * Aprobar o rechazar solicitud de acceso
     * Updated: Use RPC 'aprobar_pase_diario' for approval
     */
    async updateAccessRequestStatus(requestId: string, status: 'approved' | 'rejected', reviewedBy: string) {
        if (status === 'approved') {
            const { data, error } = await supabase.rpc('aprobar_pase_diario', {
                p_pass_id: requestId,
                p_admin_id: reviewedBy
            });
            if (error) throw error;
            return data;
        } else {
            // Reject: Update status directly
            const { data, error } = await supabase
                .from('daily_passes')
                .update({
                    status: 'rejected',
                    resolved_by: reviewedBy,
                    resolved_at: new Date().toISOString()
                })
                .eq('id', requestId);
            if (error) throw error;
            return data;
        }
    }
};

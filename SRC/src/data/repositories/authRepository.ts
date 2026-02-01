import { supabase } from '../../lib/supabase';
import { logger } from '../../utils/logger';
import type { CurrentUser } from '../../stores/auth';

export interface LoginResponse {
    success: boolean;
    employee?: CurrentUser;
    store_state?: { is_open: boolean };
    store_details?: {
        id: string;
        name: string;
        owner: string;
        email: string;
    };
    error_code?: string;
    error?: string;
}

import { isAuditMode } from '../../data/supabaseClient';

export interface RegisterResponse {
    success: boolean;
    user?: any;
    session?: any;
    error_code?: string;
    error?: string;
}

export const authRepository = {
    /**
     * Registra una nueva tienda (Admin) usando Supabase Auth Nativo
     */
    async registerStore(data: {
        storeName: string;
        ownerName: string;
        email: string;
        password: string;
    }): Promise<RegisterResponse> {
        try {
            const { data: authData, error } = await supabase.auth.signUp({
                email: data.email,
                password: data.password,
                options: {
                    data: {
                        store_name: data.storeName,
                        owner_name: data.ownerName,
                    },
                    emailRedirectTo: `${window.location.origin}/` // Redirect to root so Hash Router picks up #access_token
                }
            });

            if (error) {
                logger.error('[AuthRepository] Signup Error:', error);
                return {
                    success: false,
                    error_code: error.code, // e.g. 'user_already_exists'
                    error: error.message
                };
            }

            // Supabase returns user even if email confirmation is required (session is null)
            if (authData.user && !authData.session) {
                return {
                    success: true,
                    user: authData.user,
                    session: null // Indicates email verification needed
                };
            }

            return {
                success: true,
                user: authData.user,
                session: authData.session
            };

        } catch (err) {
            logger.error('[AuthRepository] Unexpected signup error:', err);
            return {
                success: false,
                error: 'Error inesperado durante el registro'
            };
        }
    },

    /**
     * Inicia sesión como Admin (Dueño) usando Supabase Auth
     */
    async loginStore(email: string, password: string): Promise<LoginResponse> {
        try {
            // Force clean state to prevent "Multiple GoTrueClient" or zombie session issues
            await supabase.auth.signOut();

            const { data, error } = await supabase.auth.signInWithPassword({
                email,
                password
            });

            if (error) {
                logger.error('[AuthRepository] Login Error:', error);
                return {
                    success: false,
                    error: error.message
                };
            }

            if (!data.user) {
                return {
                    success: false,
                    error: 'Usuario no encontrado'
                };
            }

            // Fetch additional store info if valid session
            // For now, we construct the user object from metadata
            const metadata = data.user.user_metadata;

            // We need the Store ID. It's not in metadata by default unless we put it there.
            // But we can fetch it via the linked employee record or stores table.

            // Let's fetch the store linked to this user (Owner) via admin_profiles
            const { data: profileData, error: profileError } = await supabase
                .from('admin_profiles')
                .select('store_id, role, stores(id, name, slug)')
                .eq('id', data.user.id)
                .single();

            if (profileError || !profileData || !profileData.stores) {
                logger.error('[AuthRepository] Store Check Error:', profileError);
                return {
                    success: false,
                    error: 'No se encontró la tienda asociada a este usuario.'
                };
            }

            const storeData = profileData.stores as any;

            return {
                success: true,
                employee: {
                    id: data.user.id,
                    name: metadata.owner_name || 'Admin',
                    email: data.user.email!,
                    type: 'admin',
                    storeId: storeData.id,
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
                store_state: { is_open: true },
                store_details: {
                    id: storeData.id,
                    name: storeData.name,
                    owner: metadata.owner_name || 'Admin',
                    email: data.user.email!
                }
            };

        } catch (err) {
            logger.error('[AuthRepository] Unexpected login error:', err);
            return {
                success: false,
                error: 'Error inesperado al iniciar sesión'
            };
        }
    },

    /**
     * Envia correo de recuperación de contraseña
     */
    async recoverPassword(email: string): Promise<{ success: boolean; error?: string }> {
        try {
            const { error } = await supabase.auth.resetPasswordForEmail(email, {
                redirectTo: `${window.location.origin}/#/reset-password` // Specific route for reset
            });

            if (error) {
                logger.error('[AuthRepository] Recovery Error:', error);
                return { success: false, error: error.message };
            }

            return { success: true };
        } catch (err) {
            logger.error('[AuthRepository] Unexpected recovery error:', err);
            return { success: false, error: 'Error inesperado.' };
        }
    },

    async logout() {
        await supabase.auth.signOut();
    },

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
                    employeeId: '101', // Converted to string
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
            .select('*, employees!daily_passes_employee_id_fkey!inner(name, store_id)')
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
            userAgent: 'N/A',
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
            .select('*, employees!daily_passes_employee_id_fkey!inner(name, store_id)')
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

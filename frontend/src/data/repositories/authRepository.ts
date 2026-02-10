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

export interface EmployeePublicInfo {
    employee_id: string;
    name: string;
    store_id: string;
    store_name: string;
}

export interface AccessRequestResponse {
    success: boolean;
    status?: 'pending' | 'approved' | 'rejected' | 'expired';
    message?: string;
    pass_id?: string;
    employee?: any;
    error_code?: string;
}



/**
 * Helper to ensure an anonymous session exists for RLS.
 */
async function ensureAnonymousSession() {
    const { data: sessionData } = await supabase.auth.getSession();
    if (!sessionData.session) {
        const { error: anonError } = await supabase.auth.signInAnonymously();
        if (anonError) {
            logger.error('[AuthRepo] Anonymous Auth Failed:', anonError);
            throw new Error(`Error de Configuración Supabase: ${anonError.message} (Habilita Auth Anónimo)`);
        }
    }
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
                // Use root path - AuthCallbackView will detect PASSWORD_RECOVERY event
                // and redirect to /update-password. Avoids double hash fragment conflict.
                redirectTo: `${window.location.origin}/`
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
     * ZER0-AUTH: Paso 1 - Resolver Alias Global a Tienda/Empleado
     */
    async getEmployeePublicInfo(alias: string): Promise<{ success: boolean; data?: EmployeePublicInfo; error?: string }> {
        try {
            const { data, error } = await supabase.rpc('get_employee_public_info' as any, {
                p_alias: alias
            });

            if (error) throw error;
            const result = data as any;

            if (!result.success) {
                return { success: false, error: result.error };
            }

            return { success: true, data: result as EmployeePublicInfo };
        } catch (err: any) {
            logger.error('[AuthRepo] Public Info Error:', err);
            return { success: false, error: err.message };
        }
    },

    /**
     * ZERO-AUTH: Paso 2 - Solicitar Acceso (Login + Daily Pass Request)
     * Reemplaza a loginEmpleado anterior.
     */
    async requestEmployeeAccess(
        alias: string,
        pin: string,
        fingerprint: string
    ): Promise<AccessRequestResponse> {
        try {
            // ZERO-AUTH FIX: Ensure we have an anonymous session so RLS works
            await ensureAnonymousSession();

            const { data, error } = await supabase.rpc('request_employee_access' as any, {
                p_alias: alias,
                p_pin: pin,
                p_device_fingerprint: fingerprint
            });

            if (error) throw error;

            return data as AccessRequestResponse;
        } catch (err: any) {
            logger.error('[AuthRepo] Request Access Error:', err);
            return {
                success: false,
                error_code: 'RPC_ERROR',
                message: err.message
            };
        }
    },

    /**
     * DEPRECATED: Old Login Method (Kept for compatibility if needed temporarily)
     */
    async loginEmpleado(
        username: string,
        pin: string,
        fingerprint: string,
        userAgent: string
    ): Promise<LoginResponse> {
        logger.warn('[AuthRepo] Deprecated loginEmpleado called. Use requestEmployeeAccess instead.');
        return { success: false, error: 'Método obsoleto. Actualice la aplicación.' };
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
     * Updated: Utiliza la nueva RPC 'approve_daily_pass'
     */
    async updateAccessRequestStatus(requestId: string, status: 'approved' | 'rejected', reviewedBy: string) {
        try {
            if (status === 'approved') {
                const { data, error } = await supabase.rpc('approve_daily_pass' as any, {
                    p_pass_id: requestId
                });
                if (error) throw error;
                return data;
            } else {
                // Reject: Update status directly (if RLS allows) or use a RPC if needed.
                // Assuming RLS allows update if Admin.
                const { data, error } = await supabase
                    .from('daily_passes')
                    .update({
                        status: 'rejected',
                        resolved_by: reviewedBy, // If column exists
                        // resolved_at: new Date().toISOString() // handled by trigger usually or manual
                    })
                    .eq('id', requestId);

                if (error) throw error;
                return data;
            }
        } catch (err) {
            logger.error('[AuthRepo] Approval Error', err);
            throw err;
        }
    },

    /**
     * Polling para el Frontend: Check status de mi pase específico
     */
    async checkMyPassStatus(passId: string): Promise<{ status: string; employee?: any }> {
        try {
            const { data, error } = await supabase.rpc('check_my_pass_status' as any, {
                p_pass_id: passId
            });
            if (error) throw error;
            return data as any;
        } catch (err) {
            return { status: 'error' };
        }
    },

    /**
     * FRD-001: Solicitar Pase Diario (Real Backend)
     */
    async requestDailyPass(employeeId: string, fingerprint: string): Promise<{ success: boolean; status?: string; error?: string; retry_count?: number }> {
        try {
            // FIX: Strip 'emp-' prefix if present, as backend expects raw UUID
            const cleanId = employeeId.startsWith('emp-') ? employeeId.replace('emp-', '') : employeeId;

            // ARCHITECT FIX: Ensure Session Exists before RPC
            // If the initial login didn't establish the session (race condition or failure), do it now.
            const { data: sessionData } = await supabase.auth.getSession();
            if (!sessionData.session) {
                logger.log('[AuthRepo] No session found during Request Pass. Attempting Anon Sign-in...');
                await supabase.auth.signInAnonymously();
            }

            const { data, error } = await supabase.rpc('solicitar_pase_diario', {
                p_employee_id: cleanId,
                p_device_fingerprint: fingerprint
            });

            if (error) {
                logger.error('[AuthRepo] Request Pass Error:', error);
                return { success: false, error: error.message };
            }

            const result = data as any;
            if (!result.success) {
                return { success: false, error: result.error, status: 'error' };
            }

            return {
                success: true,
                status: result.status,
                retry_count: result.retry_count
            };
        } catch (err: any) {
            return { success: false, error: err.message };
        }
    },

    /**
     * FRD-001: Verificar estado (Real Backend)
     */
    async checkDailyPassStatus(employeeId: string, fingerprint: string): Promise<{ status: 'none' | 'pending' | 'approved' | 'rejected' | 'expired'; retry_count?: number }> {
        try {
            // FIX: Strip 'emp-' prefix
            const cleanId = employeeId.startsWith('emp-') ? employeeId.replace('emp-', '') : employeeId;

            const { data, error } = await supabase.rpc('check_daily_pass_status', {
                p_employee_id: cleanId,
                p_device_fingerprint: fingerprint
            });

            if (error) {
                logger.error('[AuthRepo] Check Status Error:', error);
                return { status: 'none' };
            }

            const result = data as any;
            return {
                status: result.status || 'none',
                retry_count: result.retry_count
            };
        } catch (err) {
            logger.error('[AuthRepo] Check Status Exception:', err);
            return { status: 'none' };
        }
    }
};

/**
 * Employee Repository
 * WO-REM-001: Implementing repository pattern for Employees
 * Secures PIN creation via RPC 'crear_empleado'
 * 
 * @module data/repositories/employeeRepository
 */

import { Employee, EmployeePermissions } from '../../types';
import { Database } from '../../types/database.types';
import { createSupabaseRepository, EntityRepository, RepositoryMappers } from './supabaseAdapter';
import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { logger } from '../../utils/logger';

// Constants
const TABLE_NAME = 'employees';
const STORAGE_KEY = 'tienda-employees';

// Type definitions
type EmployeeDB = Database['public']['Tables']['employees']['Row'];

/**
 * Mapper Implementation for Employee
 */
export const employeeMapper: RepositoryMappers<EmployeeDB, Employee> = {
    toDomain: (row: EmployeeDB): Employee => {
        // Safe casting of permissions JSON to Interface
        // Default permissions if null
        const defaultPermissions: EmployeePermissions = {
            canSell: false,
            canViewInventory: false,
            canViewReports: false,
            canFiar: false,
            canOpenCloseCash: false
        };

        const perms = (row.permissions as unknown as EmployeePermissions) || defaultPermissions;

        return {
            id: row.id,
            storeId: row.store_id,
            name: row.name,
            username: (row as any).alias, // DB column renamed to 'alias', mapping to domain 'username'
            pin: '', // SECURITY: Never expose hash to UI. PIN is write-only field.
            // When creating: plain PIN → hashed by RPC
            // When reading: hash → masked as empty string
            // When updating: only update if new PIN provided
            permissions: perms,
            isActive: row.is_active || false,
            createdAt: row.created_at,
            updatedAt: row.updated_at
        };
    },
    toPersistence: (entity: Employee): EmployeeDB => {
        // VALIDATION
        if (!entity.storeId || entity.storeId.trim() === '') {
            throw new Error('Cannot persist Employee without valid storeId.');
        }

        // Map to actual DB schema (no display_name or role in real DB)
        return {
            id: entity.id,
            store_id: entity.storeId,
            name: entity.name,
            username: entity.username,
            pin_hash: entity.pin, // CAUTION: If updating, this might be hash or plain. 
            // Update method should handle PIN separately usually.
            // But if standard update, we trust domain has hash.
            permissions: entity.permissions as unknown as any, // JSONB
            is_active: entity.isActive,
            created_at: entity.createdAt,
            updated_at: new Date().toISOString()
        } as any; // Cast to any to bypass TS mismatch with generated types
    }
};

/**
 * Interface extending base repository
 */
export interface EmployeeRepository extends EntityRepository<Employee> {
    // Custom create signature that matches RPC needs (plain PIN)
    // Overrides base create to be safer
    create(data: Omit<Employee, 'id' | 'createdAt' | 'updatedAt'>): Promise<Employee | null>;
    validatePin(username: string, pin: string): Promise<Employee | null>;
    updatePin(employeeId: string, newPin: string): Promise<{ success: boolean; error?: string }>;
    toggleActiveSecure(employeeId: string, newStatus: boolean): Promise<{ success: boolean; error?: string }>;
}

// Create base repository
const baseRepository = createSupabaseRepository<Employee, EmployeeDB>(
    TABLE_NAME,
    STORAGE_KEY,
    employeeMapper
);

/**
 * Extended Employee Repository implementation
 */
export const employeeRepository: EmployeeRepository = {
    getAll: (storeId: string) => baseRepository.getAll(storeId),

    getById: baseRepository.getById,

    /**
     * Custom UPDATE method to handle PIN correctly
     */
    async update(id: string, data: Partial<Employee>): Promise<Employee | null> {
        // If PIN is empty or not provided, use standard update without PIN
        if (!data.pin || data.pin.trim() === '') {
            const { pin, ...dataWithoutPin } = data;
            return baseRepository.update(id, dataWithoutPin as any);
        }

        throw new Error('No se puede cambiar el PIN durante la edición. Usa la función "Cambiar PIN" específica.');
    },

    delete: (id: string) => baseRepository.delete(id),

    /**
     * Create Employee via RPC (SECURE)
     */
    async create(data: Omit<Employee, 'id' | 'createdAt' | 'updatedAt'>): Promise<Employee | null> {
        // ... (existing code for create) ...
        // 1. Validation
        if (!data.storeId) throw new Error('Store ID required');

        // 2. Try Online (RPC)
        if (isSupabaseConfigured() && navigator.onLine) {
            const supabase = getSupabaseClient()!;

            try {
                const { data: result, error } = await supabase.rpc('crear_empleado', {
                    p_store_id: data.storeId,
                    p_name: data.name,
                    p_username: data.username,
                    p_pin: data.pin,
                    p_permissions: data.permissions
                });

                if (error) {
                    logger.error('[EmployeeRepo] RPC create error:', error);
                    throw new Error(error.message);
                }

                if (result && result.success) {
                    const newId = result.employee_id;
                    const newEmployee: Employee = {
                        id: newId,
                        storeId: data.storeId,
                        name: data.name,
                        username: data.username,
                        pin: '****',
                        permissions: data.permissions,
                        isActive: data.isActive !== undefined ? data.isActive : true,
                        createdAt: new Date().toISOString(),
                        updatedAt: new Date().toISOString()
                    };
                    return newEmployee;
                } else {
                    throw new Error(result?.error || 'Unknown RPC error');
                }

            } catch (e: any) {
                logger.error('[EmployeeRepo] Create Exception:', e);
                throw e;
            }
        } else {
            throw new Error('Se requiere conexión a internet para crear empleados (Seguridad de PIN).');
        }
    },

    /**
     * Update PIN via RPC
     */
    async updatePin(employeeId: string, newPin: string): Promise<{ success: boolean; error?: string }> {
        if (isSupabaseConfigured() && navigator.onLine) {
            const supabase = getSupabaseClient()!;
            try {
                const { data, error } = await supabase.rpc('actualizar_pin_empleado', {
                    p_employee_id: employeeId,
                    p_new_pin: newPin
                });

                if (error) {
                    logger.error('[EmployeeRepo] RPC updatePin error:', error);
                    return { success: false, error: error.message };
                }

                if (data && data.success) {
                    return { success: true };
                }

                return { success: false, error: data?.error || 'Unknown RPC error' };
            } catch (e: any) {
                logger.error('[EmployeeRepo] Update PIN Exception:', e);
                return { success: false, error: e.message };
            }
        }
        return { success: false, error: 'Offline PIN update not supported' };
    },

    /**
     * Toggle Active Status via RPC (SECURE)
     */
    async toggleActiveSecure(employeeId: string, newStatus: boolean): Promise<{ success: boolean; error?: string }> {
        if (isSupabaseConfigured() && navigator.onLine) {
            const supabase = getSupabaseClient()!;
            try {
                const { data, error } = await supabase.rpc('toggle_empleado_activo', {
                    p_employee_id: employeeId,
                    p_new_status: newStatus
                });

                if (error) {
                    logger.error('[EmployeeRepo] RPC toggleActive error:', error);
                    return { success: false, error: error.message };
                }

                if (data && data.success) {
                    return { success: true };
                }

                return { success: false, error: data?.error || 'Unknown RPC error' };
            } catch (e: any) {
                logger.error('[EmployeeRepo] Toggle Active Exception:', e);
                return { success: false, error: e.message };
            }
        }
        return { success: false, error: 'Cambio de estado requiere conexión a internet.' };
    },

    /**
     * Validate PIN via RPC
     */
    async validatePin(username: string, pin: string): Promise<Employee | null> {
        // ... (existing validate pin) ...
        if (isSupabaseConfigured() && navigator.onLine) {
            const supabase = getSupabaseClient()!;
            const { data, error } = await supabase.rpc('validar_pin_empleado', {
                p_username: username,
                p_pin: pin
            });

            if (error || !data || !data.success) {
                return null;
            }

            const raw = data.employee;
            return {
                id: raw.id,
                storeId: raw.store_id,
                name: raw.name,
                username: raw.username,
                pin: '***',
                permissions: raw.permissions,
                isActive: true,
                createdAt: new Date().toISOString(),
                updatedAt: new Date().toISOString()
            } as Employee;
        }
        return null;
    }
};

export default employeeRepository;

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
            username: row.username,
            pin: row.pin_hash, // In domain we store the hash if fetched, or empty? Domain interface says 'pin'. 
            // For security we might not want to expose hash, but type requires string.
            // Use hash as value.
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

        // TS requires 'role' and 'display_name' per database.types.ts
        // We provide defaults mapped from existing data to satisfy TS.
        // If DB rejects them, we will need to update DB or Types.
        return {
            id: entity.id,
            store_id: entity.storeId,
            name: entity.name,
            display_name: entity.name, // Mapping name to display_name
            username: entity.username,
            pin_hash: entity.pin, // CAUTION: If updating, this might be hash or plain. 
            // Update method should handle PIN separately usually.
            // But if standard update, we trust domain has hash.
            role: 'employee', // Default role
            permissions: entity.permissions as unknown as any, // JSONB
            is_active: entity.isActive,
            created_at: entity.createdAt,
            updated_at: new Date().toISOString()
        };
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
    ...baseRepository,

    /**
     * Create Employee via RPC (SECURE)
     * Hashes PIN on server side
     */
    async create(data: Omit<Employee, 'id' | 'createdAt' | 'updatedAt'>): Promise<Employee | null> {
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
                    p_pin: data.pin, // Plain text PIN, RPC will hash it
                    p_permissions: data.permissions
                });

                if (error) {
                    logger.error('[EmployeeRepo] RPC create error:', error);
                    throw new Error(error.message);
                }

                if (result && result.success) {
                    // Success! RPC returns ID.
                    // We need to return the full object.
                    // Ideally we fetch it back or construct it.
                    // RPC returns: { success: true, employee_id: uuid }
                    const newId = result.employee_id;

                    // Fetch full object to be safe and get canonical data
                    const created = await baseRepository.getById(newId);
                    return created;
                } else {
                    throw new Error(result?.error || 'Unknown RPC error');
                }

            } catch (e: any) {
                logger.error('[EmployeeRepo] Create Exception:', e);
                throw e; // Re-throw to UI
            }
        } else {
            throw new Error('Se requiere conexión a internet para crear empleados (Seguridad de PIN).');
        }
    },

    /**
     * Validate PIN via RPC
     */
    async validatePin(username: string, pin: string): Promise<Employee | null> {
        if (isSupabaseConfigured() && navigator.onLine) {
            const supabase = getSupabaseClient()!;
            const { data, error } = await supabase.rpc('validar_pin_empleado', {
                p_username: username,
                p_pin: pin
            });

            if (error || !data || !data.success) {
                return null;
            }

            // Map result.employee to Domain
            // Result shape: { success: true, employee: { id, name... } }
            // Note: RPC returns snake_case or camel? SQL says:
            // json_build_object('id', v_employee.id ...) -> keys are what we defined.
            // In SQL v2: 'id', 'name', 'username', 'permissions', 'store_id'
            const raw = data.employee;

            // Manual mapping from RPC result
            return {
                id: raw.id,
                storeId: raw.store_id, // RPC returned store_id
                name: raw.name,
                username: raw.username,
                pin: '***', // Masked, we don't need hash here
                permissions: raw.permissions,
                isActive: true, // If validated, it is active
                createdAt: new Date().toISOString(),
                updatedAt: new Date().toISOString()
            } as Employee;
        }
        return null; // TODO: Local offline login?
    }
};

export default employeeRepository;

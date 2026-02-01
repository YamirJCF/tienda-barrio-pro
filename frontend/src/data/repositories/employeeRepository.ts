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
     * If PIN is empty, don't update it (keep existing hash)
     * If PIN is provided, it's a plain PIN that needs hashing via RPC
     */
    async update(id: string, data: Partial<Employee>): Promise<Employee | null> {
        // If PIN is empty or not provided, use standard update without PIN
        if (!data.pin || data.pin.trim() === '') {
            // Remove PIN from data to avoid overwriting hash
            const { pin, ...dataWithoutPin } = data;
            return baseRepository.update(id, dataWithoutPin as any);
        }

        // If PIN is provided, we need to hash it
        // For now, throw error because we don't have an RPC for updating PIN during employee edit
        // The proper way is to use the "Change PIN" functionality separately
        throw new Error('No se puede cambiar el PIN durante la edición. Usa la función "Cambiar PIN" específica.');
    },

    delete: (id: string) => baseRepository.delete(id),

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
                    // Construct Employee object directly from data we have
                    // instead of fetching (which can fail due to RLS/timing issues)
                    const newId = result.employee_id;

                    const newEmployee: Employee = {
                        id: newId,
                        storeId: data.storeId,
                        name: data.name,
                        username: data.username,
                        pin: '****', // Masked, we don't store plain PIN
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

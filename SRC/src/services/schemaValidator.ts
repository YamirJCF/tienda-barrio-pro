/**
 * Schema Validator Service
 * Contract Validation Middleware - Schema Validation & Sanitization
 * 
 * Purpose: Validate payloads against Supabase schema before persistence.
 * Detects CamelCase mismatches and Schema Drift (obsolete fields).
 * 
 * @module services/schemaValidator
 */

import { logger } from '../utils/logger';

// ============================================
// TYPES
// ============================================

export interface ValidationResult {
    valid: boolean;
    errors: string[];
    sanitizedPayload?: Record<string, any>;
}

export interface SchemaDriftResult {
    drifted: boolean;
    obsoleteFields: string[];
    missingRequired: string[];
}

// ============================================
// SCHEMA DEFINITIONS (from database.types.ts)
// ============================================

/**
 * Schema definitions for each table.
 * - requiredFields: Must be present for Insert
 * - optionalFields: Can be omitted (have defaults or nullable)
 * - allFields: Union of required + optional (the contract)
 */
const TABLE_SCHEMAS: Record<string, {
    requiredFields: string[];
    optionalFields: string[];
    allFields: string[];
}> = {
    products: {
        requiredFields: ['name', 'price', 'store_id'],
        optionalFields: [
            'id', 'plu', 'brand', 'category', 'cost_price', 'created_at',
            'current_stock', 'is_weighable', 'low_stock_alerted',
            'measurement_unit', 'min_stock', 'updated_at'
        ],
        get allFields() { return [...this.requiredFields, ...this.optionalFields]; }
    },
    clients: {
        requiredFields: ['name', 'id_number', 'store_id'],
        optionalFields: [
            'id', 'balance', 'credit_limit', 'phone', 'created_at',
            'updated_at', 'is_deleted', 'deleted_at'
        ],
        get allFields() { return [...this.requiredFields, ...this.optionalFields]; }
    },
    sales: {
        requiredFields: ['store_id', 'employee_id', 'payment_method', 'ticket_number', 'total'],
        optionalFields: [
            'id', 'amount_received', 'change_given', 'client_id', 'created_at',
            'is_voided', 'local_id', 'rounding_difference', 'sync_status',
            'void_reason', 'voided_by'
        ],
        get allFields() { return [...this.requiredFields, ...this.optionalFields]; }
    },
    employees: {
        requiredFields: ['name', 'username', 'pin_hash', 'store_id'],
        optionalFields: [
            'id', 'display_name', 'is_active', 'permissions', 'role',
            'created_at', 'updated_at'
        ],
        get allFields() { return [...this.requiredFields, ...this.optionalFields]; }
    },
    inventory_movements: {
        requiredFields: ['product_id', 'movement_type', 'quantity'],
        optionalFields: ['id', 'created_at', 'created_by', 'reason'],
        get allFields() { return [...this.requiredFields, ...this.optionalFields]; }
    },
    cash_sessions: {
        requiredFields: ['store_id', 'opened_by', 'opening_balance'],
        optionalFields: [
            'id', 'opened_at', 'closed_at', 'closed_by', 'actual_balance',
            'expected_balance', 'difference', 'status'
        ],
        get allFields() { return [...this.requiredFields, ...this.optionalFields]; }
    },
    cash_movements: {
        requiredFields: ['session_id', 'amount', 'movement_type', 'description'],
        optionalFields: ['id', 'created_at', 'sale_id'],
        get allFields() { return [...this.requiredFields, ...this.optionalFields]; }
    }
};

// ============================================
// CAMELCASE TO SNAKE_CASE MAPPING
// ============================================

/**
 * Common CamelCase -> snake_case mappings used in the application
 */
const CAMEL_TO_SNAKE_MAP: Record<string, string> = {
    // Common fields
    storeId: 'store_id',
    productId: 'product_id',
    employeeId: 'employee_id',
    clientId: 'client_id',
    sessionId: 'session_id',
    saleId: 'sale_id',

    // Product fields
    costPrice: 'cost_price',
    currentStock: 'current_stock',
    minStock: 'min_stock',
    measurementUnit: 'measurement_unit',
    isWeighable: 'is_weighable',
    lowStockAlerted: 'low_stock_alerted',

    // Timestamp fields
    createdAt: 'created_at',
    updatedAt: 'updated_at',
    closedAt: 'closed_at',
    openedAt: 'opened_at',
    deletedAt: 'deleted_at',
    syncedAt: 'synced_at',
    requestedAt: 'requested_at',
    resolvedAt: 'resolved_at',

    // Other fields
    idNumber: 'id_number',
    creditLimit: 'credit_limit',
    isDeleted: 'is_deleted',
    isActive: 'is_active',
    isVoided: 'is_voided',
    localId: 'local_id',
    pinHash: 'pin_hash',
    displayName: 'display_name',
    movementType: 'movement_type',
    paymentMethod: 'payment_method',
    ticketNumber: 'ticket_number',
    amountReceived: 'amount_received',
    changeGiven: 'change_given',
    roundingDifference: 'rounding_difference',
    syncStatus: 'sync_status',
    voidReason: 'void_reason',
    voidedBy: 'voided_by',
    openedBy: 'opened_by',
    closedBy: 'closed_by',
    createdBy: 'created_by',
    resolvedBy: 'resolved_by',
    openingBalance: 'opening_balance',
    closingBalance: 'closing_balance',
    actualBalance: 'actual_balance',
    expectedBalance: 'expected_balance',
    unitPrice: 'unit_price',
    entityId: 'entity_id',
    entityType: 'entity_type',
    lastError: 'last_error',
    retryCount: 'retry_count',
    deviceFingerprint: 'device_fingerprint',
    passDate: 'pass_date'
};

// ============================================
// SANITIZATION
// ============================================

/**
 * Converts a CamelCase payload to snake_case for database compatibility.
 * Only converts known mappings to avoid breaking unknown fields.
 */
export function sanitizeCamelToSnake(payload: Record<string, any>): Record<string, any> {
    const sanitized: Record<string, any> = {};

    for (const [key, value] of Object.entries(payload)) {
        // Check if this is a known CamelCase field
        const snakeKey = CAMEL_TO_SNAKE_MAP[key] || key;

        // Recursively sanitize nested objects (but not arrays)
        if (value && typeof value === 'object' && !Array.isArray(value)) {
            sanitized[snakeKey] = sanitizeCamelToSnake(value);
        } else if (Array.isArray(value)) {
            // Sanitize each item in array if they are objects
            sanitized[snakeKey] = value.map(item =>
                typeof item === 'object' && item !== null
                    ? sanitizeCamelToSnake(item)
                    : item
            );
        } else {
            sanitized[snakeKey] = value;
        }
    }

    return sanitized;
}

/**
 * Detects if a payload has any CamelCase fields that need conversion.
 * Returns the list of fields that need sanitization.
 */
export function detectCamelCaseFields(payload: Record<string, any>): string[] {
    const camelFields: string[] = [];

    for (const key of Object.keys(payload)) {
        if (CAMEL_TO_SNAKE_MAP[key]) {
            camelFields.push(key);
        }
    }

    return camelFields;
}

// ============================================
// SCHEMA VALIDATION
// ============================================

/**
 * Validates a payload against the schema for a specific table.
 * Checks for:
 * 1. Missing required fields
 * 2. CamelCase fields (should be snake_case)
 * 3. Auto-sanitizes if needed
 */
export function validateAgainstSchema(
    payload: Record<string, any>,
    tableName: string
): ValidationResult {
    const result: ValidationResult = {
        valid: true,
        errors: [],
    };

    const schema = TABLE_SCHEMAS[tableName];
    if (!schema) {
        // Unknown table - skip validation but log warning
        logger.warn(`[SchemaValidator] Unknown table: ${tableName}. Skipping validation.`);
        result.sanitizedPayload = payload;
        return result;
    }

    // Step 1: Detect and log CamelCase fields
    const camelFields = detectCamelCaseFields(payload);
    if (camelFields.length > 0) {
        logger.warn(`[SchemaValidator] CamelCase fields detected in ${tableName}:`, camelFields.join(', '));
        // Auto-sanitize
        payload = sanitizeCamelToSnake(payload);
    }

    // Step 2: Check required fields
    for (const field of schema.requiredFields) {
        if (!(field in payload) || payload[field] === undefined || payload[field] === null || payload[field] === '') {
            result.valid = false;
            result.errors.push(`Missing required field: ${field}`);
        }
    }

    // Store sanitized payload
    result.sanitizedPayload = payload;

    return result;
}

// ============================================
// SCHEMA DRIFT DETECTION
// ============================================

/**
 * Detects if a payload contains fields that don't exist in the current schema.
 * This indicates "Schema Drift" - the local data structure has diverged from DB.
 */
export function detectSchemaDrift(
    payload: Record<string, any>,
    tableName: string
): SchemaDriftResult {
    const result: SchemaDriftResult = {
        drifted: false,
        obsoleteFields: [],
        missingRequired: [],
    };

    const schema = TABLE_SCHEMAS[tableName];
    if (!schema) {
        // Unknown table - can't detect drift
        return result;
    }

    // First, sanitize to snake_case to compare apples to apples
    const sanitizedPayload = sanitizeCamelToSnake(payload);

    // Check for obsolete fields (in payload but not in schema)
    for (const key of Object.keys(sanitizedPayload)) {
        if (!schema.allFields.includes(key)) {
            result.drifted = true;
            result.obsoleteFields.push(key);
        }
    }

    // Check for missing required fields
    for (const field of schema.requiredFields) {
        const value = sanitizedPayload[field];
        if (value === undefined || value === null || value === '') {
            result.missingRequired.push(field);
            // Missing required is also drift (incomplete data)
            result.drifted = true;
        }
    }

    if (result.drifted) {
        logger.warn(`[SchemaValidator] Schema Drift detected for ${tableName}:`, {
            obsoleteFields: result.obsoleteFields,
            missingRequired: result.missingRequired
        });
    }

    return result;
}

// ============================================
// HELPER: Map TransactionType to TableName
// ============================================

/**
 * Maps SyncQueue TransactionType to the corresponding table name
 */
export function getTableFromTransactionType(type: string): string {
    const mapping: Record<string, string> = {
        'CREATE_SALE': 'sales',
        'UPDATE_STOCK': 'products',
        'CREATE_CLIENT': 'clients',
        'UPDATE_DEBT': 'clients',
        'CREATE_MOVEMENT': 'inventory_movements',
        'CREATE_EXPENSE': 'cash_movements',
        'CASH_EVENT': 'cash_sessions',
    };

    return mapping[type] || 'unknown';
}

export default {
    sanitizeCamelToSnake,
    detectCamelCaseFields,
    validateAgainstSchema,
    detectSchemaDrift,
    getTableFromTransactionType,
    TABLE_SCHEMAS,
};

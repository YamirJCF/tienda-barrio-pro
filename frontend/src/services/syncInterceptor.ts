/**
 * Sync Interceptor Service
 * FRD-006 Implementation: Health Interceptor Middleware
 * 
 * Purpose: Centralized validation layer between Pinia Stores and Supabase.
 * Prevents 401 errors by validating session, schema, and RLS requirements
 * BEFORE any network request is made.
 * 
 * @module services/syncInterceptor
 */

import { getSupabaseClient, isSupabaseConfigured } from '../data/supabaseClient';
import { addToSyncQueue, TransactionType } from '../data/syncQueue';
import { logger } from '../utils/logger';

// ============================================
// TYPES
// ============================================

export type SyncErrorType = 'auth' | 'schema' | 'rls' | 'network' | null;

export interface SyncResult<T> {
  success: boolean;
  errorType: SyncErrorType;
  errorMessage?: string;
  data: T | null;
  queued?: boolean; // True if operation was queued for later
}

interface ValidationResult {
  valid: boolean;
  missingFields: string[];
  invalidMappings: { field: string; expected: string; received: string }[];
}

// ============================================
// CONSTANTS
// ============================================

/**
 * Required fields for RLS policies by table
 * These fields MUST be present and non-empty for inserts to succeed
 */
const RLS_REQUIRED_FIELDS: Record<string, string[]> = {
  products: ['store_id'],
  clients: ['store_id'],
  sales: ['store_id', 'employee_id'],
  employees: ['store_id'],
  inventory_movements: ['product_id'],
  cash_sessions: ['store_id', 'opened_by'],
};

/**
 * CamelCase to snake_case mapping for common fields
 * Used to validate that payloads are correctly mapped before sending
 */
const SCHEMA_MAPPINGS: Record<string, string> = {
  storeId: 'store_id',
  productId: 'product_id',
  employeeId: 'employee_id',
  clientId: 'client_id',
  createdAt: 'created_at',
  updatedAt: 'updated_at',
  currentStock: 'current_stock',
  costPrice: 'cost_price',
  minStock: 'min_stock',
  measurementUnit: 'measurement_unit',
  isWeighable: 'is_weighable',
  lowStockAlerted: 'low_stock_alerted',
};

// ============================================
// SESSION VALIDATION (Gatekeeper)
// ============================================

/**
 * Validates that the current session has a valid JWT.
 * Returns false if session is expired or missing.
 */
export async function validateSession(): Promise<{ valid: boolean; userId: string | null; storeId: string | null }> {
  if (!isSupabaseConfigured()) {
    // Audit mode - session is "valid" locally
    return { valid: true, userId: 'audit-user', storeId: 'audit-store' };
  }

  const supabase = getSupabaseClient();
  if (!supabase) {
    return { valid: false, userId: null, storeId: null };
  }

  try {
    const { data: { session }, error } = await supabase.auth.getSession();

    if (error || !session) {
      logger.warn('[SyncInterceptor] Session validation failed:', error?.message || 'No session');
      return { valid: false, userId: null, storeId: null };
    }

    // Check if JWT is about to expire (within 60 seconds)
    const expiresAt = session.expires_at;
    if (expiresAt && Date.now() / 1000 > expiresAt - 60) {
      logger.warn('[SyncInterceptor] Session expired or about to expire');
      // Try to refresh
      const { error: refreshError } = await supabase.auth.refreshSession();
      if (refreshError) {
        return { valid: false, userId: null, storeId: null };
      }
    }

    // Fetch store_id from admin_profiles OR employees for complete context
    let storeId: string | null = null;

    // 1. Try Admin Profile
    const { data: adminProfile } = await supabase
      .from('admin_profiles')
      .select('store_id')
      .eq('id', session.user.id)
      .single();

    if (adminProfile) {
      storeId = adminProfile.store_id;
    } else {
      // 2. Try Employee Profile (Unified Arch)
      const { data: employeeProfile } = await supabase
        .from('employees')
        .select('store_id')
        .eq('id', session.user.id)
        .single();

      if (employeeProfile) {
        storeId = employeeProfile.store_id;
      }
    }

    return {
      valid: true,
      userId: session.user.id,
      storeId: storeId
    };
  } catch (err) {
    logger.error('[SyncInterceptor] Session check exception:', err);
    return { valid: false, userId: null, storeId: null };
  }
}

// ============================================
// PAYLOAD VALIDATION (Schema Guard)
// ============================================

/**
 * Validates that the payload uses snake_case field names (DB format)
 * and doesn't contain unmapped camelCase fields.
 */
export function validatePayloadSchema(payload: Record<string, any>, tableName: string): ValidationResult {
  const result: ValidationResult = {
    valid: true,
    missingFields: [],
    invalidMappings: [],
  };

  // Check for camelCase fields that should be snake_case
  const camelCaseFields = Object.keys(SCHEMA_MAPPINGS);

  for (const camelField of camelCaseFields) {
    if (camelField in payload) {
      result.valid = false;
      result.invalidMappings.push({
        field: camelField,
        expected: SCHEMA_MAPPINGS[camelField],
        received: camelField,
      });
    }
  }

  // Check required RLS fields
  const requiredFields = RLS_REQUIRED_FIELDS[tableName] || [];
  for (const field of requiredFields) {
    if (!(field in payload) || payload[field] === null || payload[field] === undefined || payload[field] === '') {
      result.valid = false;
      result.missingFields.push(field);
    }
  }

  return result;
}

// ============================================
// RLS VALIDATION (Pre-Check)
// ============================================

/**
 * Validates that the payload contains the necessary ownership fields
 * to satisfy RLS policies before sending to DB.
 */
export function validateRLSRequirements(
  payload: Record<string, any>,
  tableName: string,
  sessionContext: { userId: string | null; storeId: string | null }
): { valid: boolean; message?: string } {
  const requiredFields = RLS_REQUIRED_FIELDS[tableName] || [];

  // Check store_id specifically
  if (requiredFields.includes('store_id')) {
    const payloadStoreId = payload.store_id;
    const sessionStoreId = sessionContext.storeId;

    if (!payloadStoreId) {
      return { valid: false, message: `RLS Error: store_id is required for ${tableName}` };
    }

    // Warn if mismatch (potential 401 scenario)
    if (sessionStoreId && payloadStoreId !== sessionStoreId) {
      logger.warn(`[SyncInterceptor] RLS Warning: Payload store_id (${payloadStoreId}) differs from session store_id (${sessionStoreId})`);
      // This will likely fail RLS. Return false to prevent the request.
      return {
        valid: false,
        message: `RLS Mismatch: Payload store_id does not match authenticated user's store`
      };
    }
  }

  return { valid: true };
}

// ============================================
// MAIN INTERCEPTOR
// ============================================

/**
 * Execute a Supabase operation with full validation.
 * 
 * @param tableName - Target table for context
 * @param operationType - 'insert' | 'update' | 'delete'
 * @param payload - Data to send (should be in snake_case DB format)
 * @param operation - The actual Supabase operation function
 * @param queueType - TransactionType for offline queue (optional)
 */
export async function executeSync<T>(
  tableName: string,
  operationType: 'insert' | 'update' | 'delete',
  payload: Record<string, any>,
  operation: () => Promise<{ data: T | null; error: any }>,
  queueType?: TransactionType
): Promise<SyncResult<T>> {

  // ===== STEP 1: Session Validation =====
  const sessionResult = await validateSession();
  if (!sessionResult.valid) {
    logger.error('[SyncInterceptor] AUTH_EXPIRED: Session invalid');

    // Queue for later if offline queue type provided
    if (queueType) {
      const queued = await addToSyncQueue(queueType, payload);
      return {
        success: false,
        errorType: 'auth',
        errorMessage: 'Session expired. Operation queued for retry.',
        data: null,
        queued,
      };
    }

    return {
      success: false,
      errorType: 'auth',
      errorMessage: 'Session expired or invalid. Please login again.',
      data: null,
    };
  }

  // ===== STEP 2: Schema Validation =====
  const schemaResult = validatePayloadSchema(payload, tableName);
  if (!schemaResult.valid) {
    const mappingErrors = schemaResult.invalidMappings.map(
      m => `${m.field} should be ${m.expected}`
    ).join(', ');
    const missingErrors = schemaResult.missingFields.join(', ');

    logger.error('[SyncInterceptor] SCHEMA_ERROR:', { mappingErrors, missingErrors });

    return {
      success: false,
      errorType: 'schema',
      errorMessage: `Schema validation failed. ${mappingErrors ? 'Invalid fields: ' + mappingErrors + '. ' : ''}${missingErrors ? 'Missing fields: ' + missingErrors : ''}`,
      data: null,
    };
  }

  // ===== STEP 3: RLS Pre-Check =====
  const rlsResult = validateRLSRequirements(payload, tableName, sessionResult);
  if (!rlsResult.valid) {
    logger.error('[SyncInterceptor] RLS_ERROR:', rlsResult.message);

    return {
      success: false,
      errorType: 'rls',
      errorMessage: rlsResult.message || 'RLS validation failed',
      data: null,
    };
  }

  // ===== STEP 4: Execute Operation =====
  try {
    const { data, error } = await operation();

    if (error) {
      logger.error(`[SyncInterceptor] NETWORK_ERROR on ${tableName}:`, error);

      // Check if it's actually an RLS error from the server
      if (error.code === '42501' || error.message?.includes('row-level security')) {
        return {
          success: false,
          errorType: 'rls',
          errorMessage: `Server RLS rejection: ${error.message}`,
          data: null,
        };
      }

      // Queue if offline and queueType provided
      if (!navigator.onLine && queueType) {
        const queued = await addToSyncQueue(queueType, payload);
        return {
          success: false,
          errorType: 'network',
          errorMessage: 'Network unavailable. Operation queued.',
          data: null,
          queued,
        };
      }

      return {
        success: false,
        errorType: 'network',
        errorMessage: error.message || 'Database operation failed',
        data: null,
      };
    }

    return {
      success: true,
      errorType: null,
      data,
    };

  } catch (err: any) {
    logger.error('[SyncInterceptor] Exception during operation:', err);

    return {
      success: false,
      errorType: 'network',
      errorMessage: err.message || 'Unexpected error during sync',
      data: null,
    };
  }
}

// ============================================
// HELPER: Auto-Inject Store ID
// ============================================

/**
 * Ensures the payload has the correct store_id from the current session.
 * This is the AUTO-HEALING mechanism that prevents stale store_id issues.
 */
export async function enrichPayloadWithContext(
  payload: Record<string, any>,
  tableName: string
): Promise<Record<string, any>> {
  const requiredFields = RLS_REQUIRED_FIELDS[tableName] || [];

  if (requiredFields.includes('store_id')) {
    const sessionResult = await validateSession();
    if (sessionResult.valid && sessionResult.storeId) {
      // Override or set store_id from session
      const enriched = { ...payload, store_id: sessionResult.storeId };

      if (payload.store_id && payload.store_id !== sessionResult.storeId) {
        logger.warn('[SyncInterceptor] AUTO-HEAL: Corrected stale store_id in payload');
      }

      return enriched;
    }
  }

  return payload;
}

// ============================================
// EVENTS (for UI consumption)
// ============================================

/**
 * Event bus for sync events that UI components can listen to
 */
export const SyncEvents = {
  AUTH_EXPIRED: 'sync:auth_expired',
  SCHEMA_ERROR: 'sync:schema_error',
  RLS_ERROR: 'sync:rls_error',
  QUEUED: 'sync:queued',
};

export function emitSyncEvent(eventType: string, detail?: any): void {
  window.dispatchEvent(new CustomEvent(eventType, { detail }));
}

export default {
  validateSession,
  validatePayloadSchema,
  validateRLSRequirements,
  executeSync,
  enrichPayloadWithContext,
  SyncEvents,
  emitSyncEvent,
};

/**
 * Sync Queue
 * WO-003 T3.1: Offline transaction queue using IndexedDB
 * 
 * Features:
 * - Stores mutations when offline
 * - Replays them when online
 * - FIFO order
 * - Dead Letter Queue (DLQ) for failed items
 * - Max 50 pending transactions
 * 
 * @module data/syncQueue
 */

import { openDB, DBSchema, IDBPDatabase } from 'idb';
import { logger } from '../utils/logger';
import { getSupabaseClient } from './supabaseClient';
import { detectSchemaDrift, sanitizeCamelToSnake, getTableFromTransactionType } from '../services/schemaValidator';

const DB_NAME = 'tienda-sync-db';
const DB_VERSION = 2; // Incremented for corrupted_items store
const QUEUE_STORE = 'sync_queue';
const DLQ_STORE = 'dead_letter_queue';
const CORRUPTED_STORE = 'corrupted_items';
const MAX_QUEUE_SIZE = 50;

/**
 * Transaction Types
 */
export type TransactionType = 'CREATE_SALE' | 'CREATE_MOVEMENT' | 'CREATE_CLIENT';



/**
 * Queue Item Structure
 */
export interface QueueItem {
    id: string;
    type: TransactionType;
    payload: any;
    timestamp: number;
    retryCount: number;
    isAudit?: boolean; // 🛡️ Safety Flag
}

/**
 * IndexedDB Schema
 */
interface SyncDB extends DBSchema {
    sync_queue: {
        key: string;
        value: QueueItem;
        indexes: { 'by-timestamp': number };
    };
    dead_letter_queue: {
        key: string;
        value: QueueItem & { error: string; failedAt: number };
    };
    corrupted_items: {
        key: string;
        value: QueueItem & {
            corruptedAt: number;
            reason: string;
            obsoleteFields: string[];
            missingRequired: string[];
        };
    };
}

let dbPromise: Promise<IDBPDatabase<SyncDB>> | null = null;

/**
 * Get DB Connection
 */
const getDB = async () => {
    if (!dbPromise) {
        dbPromise = openDB<SyncDB>(DB_NAME, DB_VERSION, {
            upgrade(db, oldVersion) {
                // Queue Store
                if (!db.objectStoreNames.contains(QUEUE_STORE)) {
                    const store = db.createObjectStore(QUEUE_STORE, { keyPath: 'id' });
                    store.createIndex('by-timestamp', 'timestamp');
                }
                // DLQ Store
                if (!db.objectStoreNames.contains(DLQ_STORE)) {
                    db.createObjectStore(DLQ_STORE, { keyPath: 'id' });
                }
                // Corrupted Items Store (v2)
                if (oldVersion < 2 && !db.objectStoreNames.contains(CORRUPTED_STORE)) {
                    db.createObjectStore(CORRUPTED_STORE, { keyPath: 'id' });
                }
            },
        });
    }
    return dbPromise;
};

/**
 * Add item to sync queue
 */
import { isAuditMode } from './supabaseClient';

/**
 * Add item to sync queue
 * BLINDAJE: Only accepts validated, snake_case payloads
 */
export const addToSyncQueue = async (type: TransactionType, payload: any): Promise<boolean> => {
    // 🛡️ MODIFIED FLOW: Store locally but flag as Audit
    const auditMode = isAuditMode();
    if (auditMode) {
        logger.log(`[SyncQueue] 🛡️ Audit Mode: Storing ${type} locally with isAudit flag`);
    }

    // ===== GATEWAY CHECKPOINT: Sanitize & Validate BEFORE IndexedDB =====
    const tableName = getTableFromTransactionType(type);
    const sanitizedPayload = sanitizeCamelToSnake(payload);

    // Validate against schema
    const driftResult = detectSchemaDrift(sanitizedPayload, tableName);
    if (driftResult.drifted) {
        logger.error(`[SyncQueue] 🚫 Schema validation failed for ${type}:`, {
            obsoleteFields: driftResult.obsoleteFields,
            missingRequired: driftResult.missingRequired
        });
        // Emit event for UI notification
        window.dispatchEvent(new CustomEvent('sync:validation_failed', {
            detail: { type, tableName, ...driftResult }
        }));
        return false; // Reject - don't pollute IndexedDB with dirty data
    }

    const db = await getDB();

    // Check limit
    const count = await db.count(QUEUE_STORE);
    if (count >= MAX_QUEUE_SIZE) {
        logger.error('[SyncQueue] Queue full, rejecting transaction');
        return false;
    }

    const item: QueueItem = {
        id: crypto.randomUUID(),
        type,
        payload: sanitizedPayload, // Store SANITIZED payload (snake_case)
        timestamp: Date.now(),
        retryCount: 0,
        isAudit: auditMode
    };

    await db.put(QUEUE_STORE, item);
    logger.log(`[SyncQueue] Added ${type} to queue (sanitized)`);

    // Try to process immediately if online AND not in audit mode
    if (navigator.onLine && !isAuditMode()) {
        processSyncQueue(); // Fire and forget
    }

    return true;
};

/**
 * Process the queue
 * Contract Validation Middleware: Anti-401 Protocol & Schema Drift Detection
 */
export const processSyncQueue = async (): Promise<void> => {
    if (!navigator.onLine || isAuditMode()) return; // 🛡️ Prevent syncing in Audit Mode

    const supabase = getSupabaseClient();
    if (!supabase) {
        logger.warn('[SyncQueue] Supabase client not available');
        return;
    }

    // ===== ANTI-401 PROTOCOL: Session Auto-Recovery (Fase Final Blindaje) =====
    // Step 1: Check current session
    let { data: { session }, error: sessionError } = await supabase.auth.getSession();

    // Step 2: If no session or error, attempt refresh
    if (sessionError || !session) {
        // Step 2a: Check if user was ever authenticated
        // If no auth tokens exist in storage, user hasn't logged in yet - silently skip
        const hasStoredSession = Object.keys(localStorage).some(key =>
            key.includes('supabase') && key.includes('auth')
        );
        if (!hasStoredSession) {
            logger.log('[SyncQueue] No stored session found - user not authenticated, skipping.');
            return;
        }

        logger.warn('[SyncQueue] 🔄 Session missing - attempting auto-refresh...');

        const { data: refreshData, error: refreshError } = await supabase.auth.refreshSession();

        if (refreshError || !refreshData.session) {
            // Step 3: Refresh failed - HARD STOP + AUTH_REQUIRED
            logger.error('[SyncQueue] 🔒 AUTH_REQUIRED: Session refresh failed - cannot proceed');

            window.dispatchEvent(new CustomEvent('sync:auth_required', {
                detail: {
                    reason: 'Session expired and auto-refresh failed',
                    originalError: refreshError?.message || 'No session available',
                    timestamp: new Date().toISOString()
                }
            }));

            return; // PAUSE QUEUE - Don't burn through items with 401s
        }

        // Refresh succeeded!
        session = refreshData.session;
        logger.log('[SyncQueue] ✅ Session auto-refreshed successfully');
    }

    // Step 4: Validate session has a valid access token
    if (!session?.access_token) {
        logger.error('[SyncQueue] 🔒 Invalid session - missing access_token');
        window.dispatchEvent(new CustomEvent('sync:auth_required', {
            detail: { reason: 'Session lacks access token' }
        }));
        return;
    }

    logger.log('[SyncQueue] ✅ Session validated - proceeding with queue processing');

    const db = await getDB();

    // PHASE 1: Read all queue items (single read transaction)
    const queueItems: QueueItem[] = [];
    const readTx = db.transaction(QUEUE_STORE, 'readonly');
    const readStore = readTx.objectStore(QUEUE_STORE);
    const readIndex = readStore.index('by-timestamp');
    let readCursor = await readIndex.openCursor();

    while (readCursor) {
        queueItems.push(readCursor.value);
        readCursor = await readCursor.continue();
    }

    await readTx.done;

    if (queueItems.length === 0) {
        logger.log('[SyncQueue] Queue is empty');
        return;
    }

    logger.log(`[SyncQueue] Processing ${queueItems.length} items`);

    // PHASE 2: Process each item with separate transactions
    for (const item of queueItems) {
        // 🛡️ SECURITY CHECK: Discard Audit Items
        if (item.isAudit) {
            logger.warn(`[SyncQueue] 🛡️ Discarding Audit Item: ${item.id}`);
            const deleteTx = db.transaction(QUEUE_STORE, 'readwrite');
            await deleteTx.objectStore(QUEUE_STORE).delete(item.id);
            await deleteTx.done;
            continue;
        }

        // ===== SCHEMA DRIFT DETECTION =====
        const tableName = getTableFromTransactionType(item.type);
        const sanitizedPayload = sanitizeCamelToSnake(item.payload);
        const driftResult = detectSchemaDrift(sanitizedPayload, tableName);

        if (driftResult.drifted) {
            logger.error(`[SyncQueue] 🚨 SCHEMA_DRIFT detected for ${item.id}:`, {
                obsoleteFields: driftResult.obsoleteFields,
                missingRequired: driftResult.missingRequired
            });

            // Move to corrupted_items
            const corruptTx = db.transaction([QUEUE_STORE, CORRUPTED_STORE], 'readwrite');
            await corruptTx.objectStore(CORRUPTED_STORE).put({
                ...item,
                corruptedAt: Date.now(),
                reason: 'Schema Drift',
                obsoleteFields: driftResult.obsoleteFields,
                missingRequired: driftResult.missingRequired
            });
            await corruptTx.objectStore(QUEUE_STORE).delete(item.id);
            await corruptTx.done;

            window.dispatchEvent(new CustomEvent('sync:schema_drift', {
                detail: { itemId: item.id, type: item.type, ...driftResult }
            }));
            continue;
        }

        // Process the item
        try {
            const success = await processItem({ ...item, payload: sanitizedPayload });

            if (success) {
                // Remove from queue
                const deleteTx = db.transaction(QUEUE_STORE, 'readwrite');
                await deleteTx.objectStore(QUEUE_STORE).delete(item.id);
                await deleteTx.done;
                logger.log(`[SyncQueue] ✅ Processed ${item.type} (${item.id})`);
            } else {
                throw new Error('Processing failed');
            }
        } catch (error: any) {
            logger.error(`[SyncQueue] ❌ Failed to process ${item.id}`, error);

            // Move to DLQ if max retries exceeded
            if (item.retryCount >= 3) {
                const dlqTx = db.transaction([QUEUE_STORE, DLQ_STORE], 'readwrite');
                await dlqTx.objectStore(DLQ_STORE).put({
                    ...item,
                    error: error.message || 'Unknown error',
                    failedAt: Date.now()
                });
                await dlqTx.objectStore(QUEUE_STORE).delete(item.id);
                await dlqTx.done;
                logger.log(`[SyncQueue] Moved ${item.id} to DLQ after 3 retries`);
            } else {
                // Increment retry count
                const updateTx = db.transaction(QUEUE_STORE, 'readwrite');
                const updated = { ...item, retryCount: item.retryCount + 1 };
                await updateTx.objectStore(QUEUE_STORE).put(updated);
                await updateTx.done;
                logger.log(`[SyncQueue] Retry count for ${item.id}: ${updated.retryCount}`);
            }
        }
    }
};

/**
 * Process individual item
 */
async function processItem(item: QueueItem): Promise<boolean> {
    const supabase = getSupabaseClient();
    if (!supabase) throw new Error('Supabase client not available');

    switch (item.type) {
        case 'CREATE_SALE': {
            // FRD-012-R / RN-R03: Use RPC V2 (Financial Core)
            // V2 does NOT accept prices - server calculates from DB
            const p_items_v2 = item.payload.items.map((i: any) => ({
                product_id: i.productId || i.product_id,
                quantity: Number(i.quantity)
            }));

            // ARCH-005: RPC-Based Sync (Restored)
            // DIAGNOSTIC RESULT 2026-02-07: RPC is healthy, Table does not exist.
            // Reverting to RPC strategy to restore immediate functionality.

            // FIX 2026-02-07: Convert Decimal objects to numbers for JSON serialization
            // Decimal objects from IndexedDB cause "t.NN.unidad" serialization errors
            const rawAmountReceived = item.payload.amountReceived || item.payload.amount_received;
            const numericAmountReceived = rawAmountReceived
                ? (typeof rawAmountReceived === 'object' && rawAmountReceived.toNumber
                    ? rawAmountReceived.toNumber()
                    : Number(rawAmountReceived))
                : null;

            const rpcPayload = {
                p_store_id: item.payload.storeId || item.payload.store_id,
                p_client_id: item.payload.clientId || item.payload.client_id || null,
                p_payment_method: ['cash', 'mixed', 'efectivo'].includes(item.payload.paymentMethod)
                    ? 'efectivo'
                    : (item.payload.paymentMethod || 'efectivo'),
                p_amount_received: numericAmountReceived,
                p_items: p_items_v2
            };

            const { data, error } = await supabase.rpc('rpc_procesar_venta_v2', rpcPayload);

            if (error) {
                // If RPC not found (404), throw specific error to handle differently if needed
                if (error.code === 'PGRST202') {
                    throw new Error('RPC_NOT_FOUND: Server function missing');
                }
                throw error;
            }

            if (!data || !data.success) {
                throw new Error(data?.error || 'RPC processing failed without specific error');
            }

            // Success!
            logger.log(`[SyncQueue] ✅ RPC processed sale ${item.id} -> SaleID: ${data.sale_id}`);
            // Success!
            logger.log(`[SyncQueue] ✅ RPC processed sale ${item.id} -> SaleID: ${data.sale_id}`);
            return true;
        }

        case 'CREATE_CLIENT':
            // Direct Insert
            const { error: clientError } = await supabase.from('clients').insert(item.payload);
            if (clientError) throw clientError;
            return true;

        case 'CREATE_MOVEMENT':
            // Direct Insert to inventory_movements
            // Trigger trg_inventory_movement will update stock automatically
            const { error: moveError } = await supabase.from('inventory_movements').insert(item.payload);
            if (moveError) throw moveError;
            return true;

        default:
            // FRD-012: Only sales-related types are supported offline
            logger.error(`[SyncQueue] ❌ Unsupported transaction type: ${item.type}`);
            throw new Error(`Unsupported offline transaction: ${item.type}`);
    }
}

/**
 * Move to Dead Letter Queue
 */
async function addToDLQ(item: QueueItem, error: string): Promise<void> {
    const db = await getDB();
    await db.put(DLQ_STORE, {
        ...item,
        error,
        failedAt: Date.now(),
    });
    logger.log(`[SyncQueue] Moved ${item.id} to DLQ`);
}

/**
 * Get pending count
 */
export const getQueueSize = async (): Promise<number> => {
    const db = await getDB();
    return db.count(QUEUE_STORE);
};


/**
 * Get pending movements for a product
 */
export const getPendingMovements = async (productId?: string): Promise<any[]> => {
    const db = await getDB();
    const all = await db.getAll(QUEUE_STORE);

    // Filter for MOVEMENT type
    const movements: any[] = [];

    all.forEach(item => {
        if (item.type === 'CREATE_MOVEMENT' && (!productId || item.payload.product_id === productId)) {
            movements.push({
                id: item.id,
                movement_type: item.payload.movement_type,
                quantity: item.payload.quantity,
                reason: item.payload.reason,
                created_at: new Date(item.timestamp).toISOString(),
                employees: { name: 'Pendiente (Offline)' }
            });
        }
        else if (item.type === 'CREATE_SALE') {
            const saleItems = item.payload.items || [];
            saleItems.forEach((si: any) => {
                if (!productId || si.productId === productId) {
                    movements.push({
                        id: item.id + '_' + si.productId,
                        movement_type: 'venta',
                        quantity: si.quantity,
                        reason: `Venta (Pendiente)`,
                        created_at: new Date(item.timestamp).toISOString(),
                        employees: { name: 'Sistema (Offline)' }
                    });
                }
            });
        }
    });

    return movements.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
};

export const getPendingSales = async (): Promise<any[]> => {
    const db = await getDB();
    const all = await db.getAll(QUEUE_STORE);

    // Filter for SALE type and return payload
    return all
        .filter(item => item.type === 'CREATE_SALE')
        .map(item => ({
            ...item.payload,
            timestamp: item.timestamp
        }))
        .sort((a, b) => b.timestamp - a.timestamp);
};

export default {
    addToSyncQueue,
    processSyncQueue,
    getQueueSize,
    getPendingMovements,
    getPendingSales,

    // Conflict Resolution Exports
    getDLQItems: async (): Promise<QueueItem[]> => {
        const db = await getDB();
        return db.getAll(DLQ_STORE);
    },

    getDLQSize: async (): Promise<number> => {
        const db = await getDB();
        return db.count(DLQ_STORE);
    },

    retryDLQItem: async (id: string): Promise<void> => {
        const db = await getDB();
        const tx = db.transaction([DLQ_STORE, QUEUE_STORE], 'readwrite');
        const item = await tx.objectStore(DLQ_STORE).get(id);

        if (item) {
            // Reset retry count and timestamp to process immediately
            const retriedItem = {
                ...item,
                retryCount: 0,
                error: undefined,
                failedAt: undefined
            };
            await tx.objectStore(QUEUE_STORE).put(retriedItem);
            await tx.objectStore(DLQ_STORE).delete(id);
            logger.log(`[SyncQueue] Retrying item from DLQ: ${id}`);
        }
        await tx.done;
    },

    deleteDLQItem: async (id: string): Promise<void> => {
        const db = await getDB();
        await db.delete(DLQ_STORE, id);
        logger.log(`[SyncQueue] Deleted item from DLQ: ${id}`);
    }
};

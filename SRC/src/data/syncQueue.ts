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

const DB_NAME = 'tienda-sync-db';
const DB_VERSION = 1;
const QUEUE_STORE = 'sync_queue';
const DLQ_STORE = 'dead_letter_queue';
const MAX_QUEUE_SIZE = 50;

/**
 * Transaction Types
 */
export type TransactionType = 'CREATE_SALE' | 'UPDATE_STOCK' | 'CREATE_CLIENT' | 'UPDATE_DEBT' | 'CREATE_MOVEMENT';



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
}

let dbPromise: Promise<IDBPDatabase<SyncDB>> | null = null;

/**
 * Get DB Connection
 */
const getDB = async () => {
    if (!dbPromise) {
        dbPromise = openDB<SyncDB>(DB_NAME, DB_VERSION, {
            upgrade(db) {
                // Queue Store
                if (!db.objectStoreNames.contains(QUEUE_STORE)) {
                    const store = db.createObjectStore(QUEUE_STORE, { keyPath: 'id' });
                    store.createIndex('by-timestamp', 'timestamp');
                }
                // DLQ Store
                if (!db.objectStoreNames.contains(DLQ_STORE)) {
                    db.createObjectStore(DLQ_STORE, { keyPath: 'id' });
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
 */
export const addToSyncQueue = async (type: TransactionType, payload: any): Promise<boolean> => {
    // 🛡️ MODIFIED FLOW: Store locally but flag as Audit
    const auditMode = isAuditMode();
    if (auditMode) {
        logger.log(`[SyncQueue] 🛡️ Audit Mode: Storing ${type} locally with isAudit flag`);
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
        payload,
        timestamp: Date.now(),
        retryCount: 0,
        isAudit: auditMode
    };

    await db.put(QUEUE_STORE, item);
    logger.log(`[SyncQueue] Added ${type} to queue`);

    // Try to process immediately if online AND not in audit mode
    if (navigator.onLine && !isAuditMode()) {
        processSyncQueue(); // Fire and forget
    }

    return true;
};

/**
 * Process the queue
 */
export const processSyncQueue = async (): Promise<void> => {
    if (!navigator.onLine || isAuditMode()) return; // 🛡️ Prevent syncing in Audit Mode

    const db = await getDB();
    const tx = db.transaction(QUEUE_STORE, 'readwrite');
    const store = tx.objectStore(QUEUE_STORE);
    const index = store.index('by-timestamp');

    let cursor = await index.openCursor();

    while (cursor) {
        const item = cursor.value;

        // 🛡️ SECURITY CHECK: Discard Audit Items encountered in Production
        if (item.isAudit) {
            logger.warn(`[SyncQueue] 🛡️ Discarding Audit Item found in Production Queue: ${item.id}`);
            await cursor.delete();
            cursor = await cursor.continue();
            continue;
        }

        try {
            const success = await processItem(item);

            if (success) {
                await cursor.delete();
                logger.log(`[SyncQueue] Processed ${item.type} (${item.id})`);
            } else {
                throw new Error('Processing failed');
            }
        } catch (error: any) {
            logger.error(`[SyncQueue] Failed to process ${item.id}`, error);

            // Move to DLQ if max retries exceeded
            if (item.retryCount >= 3) {
                await addToDLQ(item, error.message || 'Unknown error');
                await cursor.delete(); // Remove from main queue
            } else {
                // Increment retry count
                const updated = { ...item, retryCount: item.retryCount + 1 };
                await cursor.update(updated);
            }
        }

        cursor = await cursor.continue();
    }

    await tx.done;
};

/**
 * Process individual item
 */
async function processItem(item: QueueItem): Promise<boolean> {
    const supabase = getSupabaseClient();
    if (!supabase) throw new Error('Supabase client not available');

    switch (item.type) {
        case 'CREATE_SALE':
            // Call RPC
            const { data, error } = await supabase.rpc('procesar_venta', {
                p_store_id: item.payload.storeId,
                // Offline Mapper: CamelCase -> SnakeCase
                // This is needed because addToSyncQueue saves raw payload (Camel)
                p_items: item.payload.items.map((i: any) => ({
                    product_id: i.productId,
                    quantity: i.quantity,
                    unit_price: i.price,
                    subtotal: i.subtotal
                })),
                p_payment_method: item.payload.paymentMethod === 'mixed' ? 'efectivo' : item.payload.paymentMethod,
                p_amount_received: item.payload.amountReceived,
                p_client_id: item.payload.clientId,
                p_employee_id: item.payload.employeeId
            });
            if (error) throw error;
            return data.success;

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
            return true; // Skip unknown
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
    let movements: any[] = [];

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
    getPendingSales
};

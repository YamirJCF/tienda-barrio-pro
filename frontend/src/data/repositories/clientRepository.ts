/**
 * Client Repository
 * SDD-030: All writes & statement reads enforce Backend Authority via SECURITY DEFINER RPCs.
 * Direct PostgREST INSERT/UPDATE/DELETE on public.clients is closed by RLS & privileges.
 *
 * @module data/repositories/clientRepository
 */

import { Client, ClientTransaction } from '../../types';
import { Database } from '../../types/database.types';
import { Decimal } from 'decimal.js';
import { createSupabaseRepository, EntityRepository, RepositoryMappers } from './supabaseAdapter';
import { getSupabaseClient, isSupabaseConfigured } from '../supabaseClient';
import { localStorageAdapter } from './localStorageAdapter';
import { logger } from '../../utils/logger';

const TABLE_NAME = 'clients';
const STORAGE_KEY = 'tienda-clients-db-cache';

type ClientDB = Database['public']['Tables']['clients']['Row'];

export interface ClientStatementMovement extends ClientTransaction {
    transactionType: string;
    previousBalance: Decimal;
    newBalance: Decimal;
    ticketNumber?: number | null;
    referenceId?: string | null;
}

export interface ClientStatement {
    client: Client & { creditAvailable: Decimal };
    movements: ClientStatementMovement[];
    count: number;
    generatedAt: string;
}

export class ClientRepositoryError extends Error {
    code: string;
    constructor(message: string, code: string = 'CLIENT_ERROR') {
        super(message);
        this.name = 'ClientRepositoryError';
        this.code = code;
    }
}

function mapClientRpcError(err: any, fallback: string): ClientRepositoryError {
    const raw = String(err?.message || err || '');
    if (raw.includes('DUPLICATE_CLIENT_ID_NUMBER') || err?.code === '23505') {
        return new ClientRepositoryError(
            'Ya existe un cliente registrado con esta cédula en la tienda.',
            'DUPLICATE_CLIENT_ID_NUMBER'
        );
    }
    if (raw.includes('CLIENT_HAS_DEBT')) {
        return new ClientRepositoryError(
            'No se puede eliminar al cliente porque mantiene un saldo pendiente de pago.',
            'CLIENT_HAS_DEBT'
        );
    }
    if (raw.includes('CLIENT_NOT_FOUND') || err?.code === 'P0002') {
        return new ClientRepositoryError(
            'El cliente no existe o no se encuentra activo en la cartera.',
            'CLIENT_NOT_FOUND'
        );
    }
    if (raw.includes('INVALID_CLIENT_NAME')) {
        return new ClientRepositoryError(
            'El nombre del cliente debe tener al menos 3 caracteres.',
            'INVALID_CLIENT_NAME'
        );
    }
    if (raw.includes('INVALID_ID_NUMBER')) {
        return new ClientRepositoryError(
            'El número de identificación (cédula) es obligatorio.',
            'INVALID_ID_NUMBER'
        );
    }
    if (raw.includes('INVALID_CREDIT_LIMIT')) {
        return new ClientRepositoryError(
            'El límite de crédito debe ser mayor o igual a cero.',
            'INVALID_CREDIT_LIMIT'
        );
    }
    if (raw.includes('UNAUTHORIZED') || err?.code === '42501') {
        return new ClientRepositoryError(
            'No tienes permisos autorizados para realizar esta acción sobre la cartera.',
            'UNAUTHORIZED'
        );
    }
    if (raw.includes('STORE_ACCESS_DENIED')) {
        return new ClientRepositoryError(
            'Sesión sin acceso válido a la tienda activa. Recarga o inicia sesión nuevamente.',
            'STORE_ACCESS_DENIED'
        );
    }
    return new ClientRepositoryError(raw || fallback, err?.code || 'CLIENT_ERROR');
}

function ensureOnlineForClientRpc(actionLabel: string) {
    if (typeof navigator !== 'undefined' && !navigator.onLine) {
        throw new ClientRepositoryError(
            `Sin conexión a internet. ${actionLabel} requiere conexión en línea.`,
            'OFFLINE'
        );
    }
    const client = getSupabaseClient();
    if (!client) {
        throw new ClientRepositoryError(
            'No hay conexión activa con el servidor.',
            'SUPABASE_UNAVAILABLE'
        );
    }
    return client;
}

function upsertCachedClientRow(row: ClientDB) {
    const existing = localStorageAdapter.get<ClientDB[]>(STORAGE_KEY) || [];
    const idx = existing.findIndex((c) => c.id === row.id);
    if (idx >= 0) {
        existing[idx] = row;
    } else {
        existing.push(row);
    }
    localStorageAdapter.set(STORAGE_KEY, existing);
}

function removeCachedClientRow(id: string) {
    const existing = localStorageAdapter.get<ClientDB[]>(STORAGE_KEY) || [];
    localStorageAdapter.set(
        STORAGE_KEY,
        existing.filter((c) => c.id !== id)
    );
}

function mapRawClientToDomain(raw: any): Client {
    return {
        id: raw.id,
        name: raw.name,
        cc: raw.id_number,
        phone: raw.phone || undefined,
        email: undefined,
        totalDebt: new Decimal(raw.balance || 0),
        notes: undefined,
        creditLimit: new Decimal(raw.credit_limit || 0),
        createdAt: raw.created_at,
        updatedAt: raw.updated_at,
        storeId: raw.store_id,
    };
}

export const clientMapper: RepositoryMappers<ClientDB, Client> = {
    toDomain: (row: ClientDB): Client => ({
        id: row.id,
        name: row.name,
        cc: row.id_number,
        phone: row.phone || undefined,
        email: undefined,
        totalDebt: new Decimal(row.balance || 0),
        notes: undefined,
        creditLimit: new Decimal(row.credit_limit || 0),
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        storeId: row.store_id,
    }),
    toPersistence: (entity: Client): ClientDB => {
        if (!entity.storeId || entity.storeId.trim() === '') {
            throw new Error('Cannot persist Client without valid storeId. This would fail RLS policies.');
        }

        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        if (!uuidRegex.test(entity.storeId)) {
            throw new Error(`Invalid UUID format for storeId: "${entity.storeId}"`);
        }

        return {
            id: entity.id,
            name: entity.name,
            id_number: entity.cc,
            phone: entity.phone || null,
            balance: entity.totalDebt.toNumber(),
            credit_limit: entity.creditLimit ? entity.creditLimit.toNumber() : 0,
            created_at: entity.createdAt || new Date().toISOString(),
            updated_at: new Date().toISOString(),
            store_id: entity.storeId,
            deleted_at: null,
            is_deleted: false,
        };
    },
};

export type ClientDebtFilter = 'all' | 'with_debt' | 'up_to_date';

export interface ClientPageParams {
    storeId: string;
    limit?: number;
    offset?: number;
    search?: string;
    debtFilter?: ClientDebtFilter;
}

export interface PaginatedClientsResult {
    data: Client[];
    count: number;
}

export interface ClientRepository extends EntityRepository<Client> {
    getPaginated(params: ClientPageParams): Promise<PaginatedClientsResult>;
    getByCedula(cedula: string, storeId?: string): Promise<Client | null>;
    searchByName(query: string, storeId?: string): Promise<Client[]>;
    updateDebt(id: string, amount: number): Promise<boolean>;
    getTransactions(clientId: string): Promise<ClientTransaction[]>;
    getStatement(clientId: string, limit?: number, offset?: number): Promise<ClientStatement>;
    addTransaction(tx: any): Promise<boolean>;
    updatePendingTransactionSaleId(description: string, saleId: string): Promise<boolean>;
}

const baseRepository = createSupabaseRepository<Client, ClientDB>(
    TABLE_NAME,
    STORAGE_KEY,
    clientMapper
);

function mapMovementDescription(txType: string, ticketNumber?: number | null): string {
    const ticketSuffix = ticketNumber ? ` #${ticketNumber}` : '';
    switch (txType) {
        case 'venta_fiado':
        case 'compra':
            return `Venta Fiado${ticketSuffix}`;
        case 'anulacion_fiado':
            return `Anulación Fiado${ticketSuffix}`;
        case 'abono':
        case 'pago':
            return 'Abono a cuenta';
        default:
            return txType || 'Movimiento';
    }
}

export const clientRepository: ClientRepository = {
    ...baseRepository,

    async getPaginated(params: ClientPageParams): Promise<PaginatedClientsResult> {
        const limit = Math.max(1, params.limit ?? 5);
        const offset = Math.max(0, params.offset ?? 0);
        const isOnline = typeof navigator === 'undefined' ? true : navigator.onLine;

        if (isSupabaseConfigured() && isOnline) {
            const supabase = getSupabaseClient();
            if (!supabase) {
                throw new ClientRepositoryError(
                    'No hay conexión activa con el servidor.',
                    'SUPABASE_UNAVAILABLE'
                );
            }

            let query = supabase
                .from(TABLE_NAME)
                .select('*', { count: 'exact' })
                .eq('store_id', params.storeId)
                .eq('is_deleted', false);

            const cleanSearch = (params.search || '').trim().replace(/[%_,()]/g, '');
            if (cleanSearch) {
                query = query.or(
                    `name.ilike.%${cleanSearch}%,id_number.ilike.%${cleanSearch}%,phone.ilike.%${cleanSearch}%`
                );
            }

            if (params.debtFilter === 'with_debt') {
                query = query.gt('balance', 0);
            } else if (params.debtFilter === 'up_to_date') {
                query = query.lte('balance', 0);
            }

            const { data, error, count } = await query
                .order('name', { ascending: true })
                .range(offset, offset + limit - 1);

            if (error) {
                throw mapClientRpcError(error, 'Error al cargar la lista paginada de clientes.');
            }

            const rows = (data || []) as ClientDB[];
            rows.forEach((r) => upsertCachedClientRow(r));
            const mapped = rows.map((r) => clientMapper.toDomain(r));
            return {
                data: mapped,
                count: typeof count === 'number' ? count : mapped.length,
            };
        }

        // Offline / local fallback: filter localStorage cache without scanning network
        const cached = (localStorageAdapter.get<ClientDB[]>(STORAGE_KEY) || []).filter(
            (c) => c.store_id === params.storeId && !c.is_deleted
        );
        const q = (params.search || '').trim().toLowerCase();
        const filtered = cached
            .filter((c) => {
                if (q) {
                    const matchName = (c.name || '').toLowerCase().includes(q);
                    const matchCc = (c.id_number || '').toLowerCase().includes(q);
                    const matchPhone = (c.phone || '').toLowerCase().includes(q);
                    if (!matchName && !matchCc && !matchPhone) return false;
                }
                if (params.debtFilter === 'with_debt') return Number(c.balance || 0) > 0;
                if (params.debtFilter === 'up_to_date') return Number(c.balance || 0) <= 0;
                return true;
            })
            .sort((a, b) => (a.name || '').localeCompare(b.name || ''));

        return {
            data: filtered.slice(offset, offset + limit).map(clientMapper.toDomain),
            count: filtered.length,
        };
    },

    async create(data: Omit<Client, 'id'>): Promise<Client | null> {
        if (!isSupabaseConfigured()) {
            return baseRepository.create(data);
        }

        const supabase = ensureOnlineForClientRpc('Registrar o reactivar clientes');
        if (!data.storeId) {
            throw new ClientRepositoryError(
                'No se identificó la tienda activa para registrar al cliente.',
                'STORE_ACCESS_DENIED'
            );
        }

        const creditLimitNum =
            data.creditLimit instanceof Decimal
                ? data.creditLimit.toNumber()
                : Number(data.creditLimit || 0);

        const { data: rpcData, error } = await (supabase as any).rpc('rpc_crear_cliente_fiado', {
            p_store_id: data.storeId,
            p_name: data.name,
            p_id_number: data.cc,
            p_phone: data.phone || null,
            p_credit_limit: creditLimitNum,
        });

        if (error) {
            throw mapClientRpcError(error, 'Error al guardar el cliente.');
        }

        const payload = rpcData as any;
        if (!payload?.success || !payload?.data?.client) {
            throw new ClientRepositoryError(
                'Respuesta inválida del servidor al registrar el cliente.',
                'INVALID_RESPONSE'
            );
        }

        const rawClient = payload.data.client;
        const domainClient = mapRawClientToDomain(rawClient);
        upsertCachedClientRow({
            id: rawClient.id,
            store_id: rawClient.store_id,
            name: rawClient.name,
            id_number: rawClient.id_number,
            phone: rawClient.phone ?? null,
            credit_limit: Number(rawClient.credit_limit || 0),
            balance: Number(rawClient.balance || 0),
            created_at: rawClient.created_at,
            updated_at: rawClient.updated_at,
            deleted_at: null,
            is_deleted: false,
        });

        return domainClient;
    },

    async update(id: string, data: Partial<Client>): Promise<Client | null> {
        if (!isSupabaseConfigured()) {
            return baseRepository.update(id, data);
        }

        const supabase = ensureOnlineForClientRpc('Actualizar datos del cliente');
        const existingLocal = await baseRepository.getById(id);

        const name = data.name ?? existingLocal?.name ?? '';
        const idNumber = data.cc ?? existingLocal?.cc ?? '';
        const phone = data.phone !== undefined ? data.phone : existingLocal?.phone;
        const creditLimitSource =
            data.creditLimit !== undefined ? data.creditLimit : existingLocal?.creditLimit;
        const creditLimitNum =
            creditLimitSource instanceof Decimal
                ? creditLimitSource.toNumber()
                : Number(creditLimitSource ?? 0);

        const { data: rpcData, error } = await (supabase as any).rpc('rpc_actualizar_cliente', {
            p_client_id: id,
            p_name: name,
            p_id_number: idNumber,
            p_phone: phone || null,
            p_credit_limit: creditLimitNum,
        });

        if (error) {
            throw mapClientRpcError(error, 'Error al actualizar datos del cliente.');
        }

        const payload = rpcData as any;
        if (!payload?.success || !payload?.data?.client) {
            throw new ClientRepositoryError(
                'Respuesta inválida del servidor al actualizar el cliente.',
                'INVALID_RESPONSE'
            );
        }

        const rawClient = payload.data.client;
        const domainClient = mapRawClientToDomain({
            ...rawClient,
            created_at: existingLocal?.createdAt,
        });

        upsertCachedClientRow({
            id: rawClient.id,
            store_id: rawClient.store_id,
            name: rawClient.name,
            id_number: rawClient.id_number,
            phone: rawClient.phone ?? null,
            credit_limit: Number(rawClient.credit_limit || 0),
            balance: Number(rawClient.balance || 0),
            created_at: existingLocal?.createdAt || rawClient.updated_at,
            updated_at: rawClient.updated_at,
            deleted_at: null,
            is_deleted: false,
        });

        return domainClient;
    },

    async delete(id: string): Promise<boolean> {
        if (!isSupabaseConfigured()) {
            return baseRepository.delete(id);
        }

        const supabase = ensureOnlineForClientRpc('Eliminar clientes');
        const { data: rpcData, error } = await (supabase as any).rpc('rpc_eliminar_cliente', {
            p_client_id: id,
        });

        if (error) {
            throw mapClientRpcError(error, 'No se pudo eliminar al cliente.');
        }

        const payload = rpcData as any;
        if (!payload?.success || !payload?.data?.deleted) {
            throw new ClientRepositoryError('No se recibió confirmación de eliminación.', 'DELETE_FAILED');
        }

        removeCachedClientRow(id);
        return true;
    },

    async getByCedula(cedula: string, storeId?: string): Promise<Client | null> {
        const all = await baseRepository.getAll(storeId);
        return all.find((c) => c.cc === cedula) || null;
    },

    async searchByName(query: string, storeId?: string): Promise<Client[]> {
        const all = await baseRepository.getAll(storeId);
        const lowerQuery = query.toLowerCase();
        return all.filter((c) => c.name.toLowerCase().includes(lowerQuery));
    },

    async updateDebt(id: string, amount: number): Promise<boolean> {
        if (isSupabaseConfigured() && navigator.onLine) {
            return true;
        }

        const client = await baseRepository.getById(id);
        if (!client) return false;

        const newDebt = client.totalDebt.plus(amount);
        const updated = await baseRepository.update(id, {
            totalDebt: newDebt,
        } as Partial<Client>);

        return updated !== null;
    },

    async getStatement(clientId: string, limit: number = 100, offset: number = 0): Promise<ClientStatement> {
        const supabase = ensureOnlineForClientRpc('Consultar el estado de cuenta');
        const { data: rpcData, error } = await (supabase as any).rpc('rpc_obtener_estado_cuenta_cliente', {
            p_client_id: clientId,
            p_limit: limit,
            p_offset: offset,
        });

        if (error) {
            throw mapClientRpcError(error, 'No se pudo consultar el estado de cuenta del cliente.');
        }

        const payload = rpcData as any;
        if (!payload?.success || !payload?.data?.client) {
            throw new ClientRepositoryError('Respuesta inválida del servidor.', 'INVALID_RESPONSE');
        }

        const rawClient = payload.data.client;
        const existingLocal = await baseRepository.getById(clientId);
        const movements: ClientStatementMovement[] = (payload.data.movements || []).map((m: any) => {
            const txType = String(m.transaction_type || '');
            const uiType: 'purchase' | 'payment' =
                txType === 'venta_fiado' || txType === 'compra' ? 'purchase' : 'payment';
            return {
                id: m.id,
                clientId,
                type: uiType,
                transactionType: txType,
                amount: new Decimal(Math.abs(Number(m.amount || 0))),
                previousBalance: new Decimal(Number(m.previous_balance || 0)),
                newBalance: new Decimal(Number(m.new_balance || 0)),
                description: mapMovementDescription(txType, m.ticket_number),
                date: m.created_at,
                saleId: m.reference_id || undefined,
                ticketNumber: m.ticket_number ?? null,
                referenceId: m.reference_id ?? null,
            };
        });

        return {
            client: {
                ...mapRawClientToDomain({
                    ...rawClient,
                    store_id: rawClient.store_id ?? existingLocal?.storeId ?? '',
                    created_at: rawClient.created_at ?? existingLocal?.createdAt,
                    updated_at: rawClient.updated_at ?? existingLocal?.updatedAt,
                }),
                creditAvailable: new Decimal(Number(rawClient.credit_available || 0)),
            },
            movements,
            count: Number(payload.count ?? movements.length),
            generatedAt: payload.data.generated_at || new Date().toISOString(),
        };
    },

    async getTransactions(clientId: string): Promise<ClientTransaction[]> {
        if (isSupabaseConfigured()) {
            if (typeof navigator !== 'undefined' && !navigator.onLine) {
                throw new ClientRepositoryError(
                    'Sin conexión a internet. Consulta el estado de cuenta en línea.',
                    'OFFLINE'
                );
            }
            const statement = await clientRepository.getStatement(clientId, 100, 0);
            return statement.movements;
        }
        return [];
    },

    async addTransaction(_tx: {
        id: string;
        clientId: string;
        type: 'purchase' | 'payment';
        amount: number;
        description: string;
        date: string;
        saleId?: string;
    }): Promise<boolean> {
        if (isSupabaseConfigured() && navigator.onLine) {
            return true;
        }
        console.warn('[ClientRepo] Offline - transaction not persisted, will sync with sale');
        return false;
    },

    async updatePendingTransactionSaleId(description: string, saleId: string): Promise<boolean> {
        logger.log('[ClientRepo] updatePendingTransactionSaleId is a no-op (view-based reconciliation).', {
            description,
            saleId,
        });
        return true;
    },
};

export default clientRepository;

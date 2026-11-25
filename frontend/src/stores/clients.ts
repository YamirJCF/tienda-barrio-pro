import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';
import { type Client, type ClientTransaction } from '../types';
import {
  clientRepository,
  type ClientStatement,
  type ClientPageParams,
  type PaginatedClientsResult,
} from '../data/repositories/clientRepository';
import { generateUUID } from '../utils/uuid';
import { logger } from '../utils/logger';
import { clientsSerializer } from '../data/serializers/clientsSerializer';
import { systemCacheManager, CacheLevel } from '../services/systemCacheManager';
import { getSupabaseClient, isSupabaseConfigured } from '../data/supabaseClient';

export const useClientsStore = defineStore(
  'clients',
  () => {
    const clients = ref<Client[]>([]);
    const transactions = ref<ClientTransaction[]>([]);
    const isLoading = ref(false);
    const error = ref<string | null>(null);

    // Computed
    const totalDebt = computed(() => {
      return clients.value.reduce(
        (sum, c) => sum.plus(c.totalDebt && c.totalDebt.gt(0) ? c.totalDebt : new Decimal(0)),
        new Decimal(0),
      );
    });

    const clientsWithDebt = computed(() => {
      return clients.value.filter((c) => c.totalDebt && c.totalDebt.gt(0));
    });

    // Actions
    const initialize = async (storeId: string, forceReload: boolean = false) => {
      if (!storeId) return;

      // OFFLINE-FIRST: If we already have clients loaded (from persist), skip network call when offline
      const isOnline = navigator.onLine;
      if (!isOnline && clients.value.length > 0 && !forceReload) {
        logger.log('[ClientsStore] Offline mode: using persisted clients');
        return;
      }

      isLoading.value = true;
      try {
        const cacheKey = `clients:${storeId}`;
        const { data } = await systemCacheManager.fetchSWR(
          cacheKey,
          () => clientRepository.getAll(storeId),
          { level: CacheLevel.LEVEL_2_CATALOG, forceFresh: forceReload }
        );
        if (data) {
          clients.value = data;
        }
      } catch (e: any) {
        logger.error('[ClientsStore] Init failed', e);
        error.value = 'Error al cargar clientes';
        if (clients.value.length > 0) {
          logger.warn('[ClientsStore] Network failed, but keeping persisted clients');
        }
      } finally {
        isLoading.value = false;
      }
    };

    const fetchClientsPage = async (params: ClientPageParams): Promise<PaginatedClientsResult> => {
      const limit = params.limit ?? 5;
      const offset = params.offset ?? 0;
      const result = await clientRepository.getPaginated({
        ...params,
        limit,
        offset,
      });
      // Sincronizar en memoria únicamente los clientes recibidos en esta página (sin cargar toda la tabla)
      for (const client of result.data) {
        const idx = clients.value.findIndex((c) => c.id === client.id);
        if (idx !== -1) {
          clients.value[idx] = client;
        } else {
          clients.value.push(client);
        }
      }
      return result;
    };

    const addClient = async (data: { name: string; cc: string; phone?: string; creditLimit?: Decimal; storeId: string }) => {
      const now = new Date().toISOString();

      const newClient: Client = {
        id: generateUUID(),
        name: data.name,
        cc: data.cc,
        phone: data.phone,
        totalDebt: new Decimal(0),
        creditLimit: data.creditLimit || new Decimal(0),
        storeId: data.storeId,
        createdAt: now,
        updatedAt: now
      };

      try {
        const created = await clientRepository.create(newClient);
        if (created) {
          const existingIndex = clients.value.findIndex((c) => c.id === created.id);
          if (existingIndex !== -1) {
            clients.value[existingIndex] = created;
          } else {
            clients.value.push(created);
          }
          systemCacheManager.invalidate(`clients:${data.storeId}`);
          return created;
        }
      } catch (e) {
        logger.error('Failed to create client', e);
        throw e;
      }
      return null;
    };

    const updateClient = async (id: string, data: Partial<Client>) => {
      try {
        // Inject storeId from cached state - required by supabaseAdapter for RLS compliance.
        // The form only sends editable fields (name, cc, phone, creditLimit), not storeId.
        const existingClient = getClientById(id);
        const dataWithStore: Partial<Client> = existingClient?.storeId
          ? { ...data, storeId: existingClient.storeId }
          : data;

        const updated = await clientRepository.update(id, dataWithStore);
        if (updated) {
          const index = clients.value.findIndex(c => c.id === id);
          if (index !== -1) {
            clients.value[index] = updated;
          }
          if (dataWithStore.storeId) {
            systemCacheManager.invalidate(`clients:${dataWithStore.storeId}`);
          }
          return updated;
        }
      } catch (e) {
        logger.error('Update client failed', e);
        throw e;

      }
      return null;
    };

    const deleteClient = async (id: string): Promise<{ success: boolean; error?: string; code?: string }> => {
      const client = getClientById(id);
      if (client && client.totalDebt.gt(0)) {
        return {
          success: false,
          code: 'CLIENT_HAS_DEBT',
          error: 'No se puede eliminar al cliente porque mantiene un saldo pendiente de pago.',
        };
      }
      try {
        const deleted = await clientRepository.delete(id);
        if (!deleted) {
          return { success: false, code: 'DELETE_FAILED', error: 'No se pudo eliminar al cliente.' };
        }
        const index = clients.value.findIndex((c) => c.id === id);
        if (index !== -1) {
          const storeId = clients.value[index].storeId;
          clients.value.splice(index, 1);
          if (storeId) {
            systemCacheManager.invalidate(`clients:${storeId}`);
          }
        }
        transactions.value = transactions.value.filter((t) => t.clientId !== id);
        return { success: true };
      } catch (e: any) {
        logger.error('[ClientsStore] Delete client failed:', e);
        return {
          success: false,
          code: e?.code || 'DELETE_FAILED',
          error: e?.message || 'Error al eliminar el cliente en el servidor.',
        };
      }
    };

    const getClientById = (id: string) => {
      return clients.value.find((c) => c.id === id);
    };

    const getClientByCedula = (cedula: string) => {
      // Map cedula (UI/Input) to cc (Domain)
      return clients.value.find((c) => c.cc === cedula);
    };

    const searchClients = (query: string) => {
      const q = query.toLowerCase().trim();
      if (!q) return clients.value;
      return clients.value.filter(
        (c) => c.name.toLowerCase().includes(q) || c.cc.includes(q) || (c.phone && c.phone.includes(q)),
      );
    };

    const addPurchaseDebt = async (
      clientId: string,
      amount: Decimal,
      description: string,
      saleId?: string,
    ) => {
      // 1. Update Debt
      const success = await clientRepository.updateDebt(clientId, amount.toNumber());
      if (!success) throw new Error('Failed to update debt');

      // 2. Add Transaction
      const txStub: ClientTransaction = {
        id: generateUUID(),
        clientId,
        type: 'purchase',
        amount: amount,
        description,
        date: new Date().toISOString(),
        saleId
      };

      // Persist transaction
      await clientRepository.addTransaction({
        ...txStub,
        amount: amount.toNumber()
      });

      // 3. Update Local State
      const client = getClientById(clientId);
      if (client) {
        client.totalDebt = client.totalDebt.plus(amount);
        client.updatedAt = new Date().toISOString();
      }
      transactions.value.push(txStub);
      return txStub;
    };

    const registerPayment = async (clientId: string, amount: Decimal, description = 'Abono', paymentMethod: string = 'efectivo') => {
      if (typeof navigator !== 'undefined' && !navigator.onLine) {
        throw new Error('Sin conexión a internet. Registrar abonos requiere conexión en línea.');
      }
      if (!isSupabaseConfigured()) {
        throw new Error('No hay conexión activa con el servidor.');
      }

      const supabase = getSupabaseClient();
      if (!supabase) {
        throw new Error('No hay conexión activa con el servidor.');
      }

      const { data, error } = await supabase.rpc('rpc_registrar_abono', {
        p_client_id: clientId,
        p_amount: amount.toNumber(),
        p_payment_method: paymentMethod,
        p_notes: description
      });

      if (error || !data?.success) {
        const rawMsg = String(data?.error || error?.message || 'Error al registrar el abono');
        if (rawMsg.includes('PERMISSION_DENIED')) {
          throw new Error('No tienes permiso autorizado (canFiar) o tu pase diario expiró para cobrar abonos.');
        }
        if (rawMsg.includes('CLIENT_NOT_FOUND')) {
          throw new Error('El cliente no existe o fue archivado de la cartera.');
        }
        throw new Error(rawMsg);
      }

      const txStub: ClientTransaction = {
        id: generateUUID(),
        clientId,
        type: 'payment',
        amount,
        description,
        date: new Date().toISOString()
      };
      const client = getClientById(clientId);
      if (client) {
        if (data.data?.new_balance !== undefined) {
          client.totalDebt = new Decimal(data.data.new_balance);
        } else {
          client.totalDebt = client.totalDebt.minus(amount);
        }
        client.updatedAt = new Date().toISOString();
      }
      transactions.value.push(txStub);
      return txStub;
    };

    const getClientTransactions = async (clientId: string) => {
      const remoteTxs = await clientRepository.getTransactions(clientId);
      return remoteTxs as ClientTransaction[];
    };

    const getClientStatement = async (
      clientId: string,
      limit: number = 200,
      offset: number = 0
    ): Promise<ClientStatement> => {
      const statement = await clientRepository.getStatement(clientId, limit, offset);
      const idx = clients.value.findIndex((c) => c.id === clientId);
      if (idx !== -1) {
        clients.value[idx] = {
          ...clients.value[idx],
          name: statement.client.name,
          cc: statement.client.cc,
          phone: statement.client.phone,
          creditLimit: statement.client.creditLimit,
          totalDebt: statement.client.totalDebt,
        };
      } else {
        clients.value.push(statement.client);
      }
      return statement;
    };

    const getAvailableCredit = (clientId: string) => {
      const client = getClientById(clientId);
      if (!client || !client.creditLimit) return new Decimal(0);
      return client.creditLimit.minus(client.totalDebt);
    };

    const getDefaultCreditLimit = async (storeId: string): Promise<number> => {
      return clientRepository.getDefaultCreditLimit(storeId);
    };

    const updateGlobalCreditLimit = async (storeId: string, limit: number): Promise<number> => {
      return clientRepository.updateGlobalCreditLimit(storeId, limit);
    };

    return {
      clients,
      transactions,
      isLoading,
      error,
      totalDebt,
      clientsWithDebt,
      initialize,
      fetchClientsPage,
      addClient,
      updateClient,
      deleteClient,
      getClientById,
      getClientByCedula,
      searchClients,
      addPurchaseDebt,
      registerPayment,
      getClientTransactions,
      getClientStatement,
      getAvailableCredit,
      getDefaultCreditLimit,
      updateGlobalCreditLimit,
    };
  },
  {
    persist: {
      key: 'tienda-clients',
      serializer: clientsSerializer,
    },
  },
);

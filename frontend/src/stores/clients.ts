import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';
import { type Client, type ClientTransaction } from '../types';
import { clientRepository } from '../data/repositories/clientRepository';
import { generateUUID } from '../utils/uuid';
import { logger } from '../utils/logger';
import { clientsSerializer } from '../data/serializers/clientsSerializer';

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
    const initialize = async (storeId: string) => {
      if (!storeId) return;

      // OFFLINE-FIRST: If we already have clients loaded (from persist), skip network call when offline
      const isOnline = navigator.onLine;
      if (!isOnline && clients.value.length > 0) {
        logger.log('[ClientsStore] Offline mode: using persisted clients');
        return;
      }

      isLoading.value = true;
      try {
        const data = await clientRepository.getAll(storeId);
        clients.value = data;
        // Transactions are loaded on demand usually, but we keep the array valid
      } catch (e: any) {
        logger.error('[ClientsStore] Init failed', e);
        error.value = 'Error al cargar clientes';
        // FRD-012: Don't clear existing clients on network error
        // If we have persisted data, keep it
        if (clients.value.length > 0) {
          logger.warn('[ClientsStore] Network failed, but keeping persisted clients');
        }
      } finally {
        isLoading.value = false;
      }
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
          clients.value.push(created);
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
        const updated = await clientRepository.update(id, data);
        if (updated) {
          const index = clients.value.findIndex(c => c.id === id);
          if (index !== -1) {
            clients.value[index] = updated;
          }
          return updated;
        }
      } catch (e) {
        logger.error('Update client failed', e);
        throw e;
      }
      return null;
    };

    const deleteClient = async (id: string) => {
      const client = getClientById(id);
      if (client && client.totalDebt.gt(0)) {
        return { success: false, error: 'DEBT_PENDING' };
      }
      try {
        await clientRepository.delete(id);
        const index = clients.value.findIndex((c) => c.id === id);
        if (index !== -1) {
          clients.value.splice(index, 1);
        }
        return { success: true };
      } catch (e) {
        return { success: false, error: 'DELETE_FAILED' };
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

    const registerPayment = async (clientId: string, amount: Decimal, description = 'Abono') => {
      // 1. Update Debt (Negative amount to reduce)
      const success = await clientRepository.updateDebt(clientId, -amount.toNumber());
      if (!success) throw new Error('Failed to register payment');

      // 2. Add Transaction
      const txStub: ClientTransaction = {
        id: generateUUID(),
        clientId,
        type: 'payment',
        amount: amount,
        description,
        date: new Date().toISOString()
      };

      await clientRepository.addTransaction({
        ...txStub,
        amount: amount.toNumber()
      });

      // 3. Local Update
      const client = getClientById(clientId);
      if (client) {
        client.totalDebt = client.totalDebt.minus(amount);
        client.updatedAt = new Date().toISOString();
      }
      transactions.value.push(txStub);
      return txStub;
    };

    const getClientTransactions = async (clientId: string) => {
      // Fetch from Repo for source of truth
      try {
        const remoteTxs = await clientRepository.getTransactions(clientId);
        return remoteTxs as ClientTransaction[];
      } catch (e) {
        // Fallback to local
        return transactions.value
          .filter(t => t.clientId === clientId)
          .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
      }
    };

    const getAvailableCredit = (clientId: string) => {
      const client = getClientById(clientId);
      if (!client || !client.creditLimit) return new Decimal(0);
      return client.creditLimit.minus(client.totalDebt);
    };

    return {
      clients,
      transactions,
      isLoading,
      error,
      totalDebt,
      clientsWithDebt,
      initialize,
      addClient,
      updateClient,
      deleteClient,
      getClientById,
      getClientByCedula,
      searchClients,
      addPurchaseDebt,
      registerPayment,
      getClientTransactions,
      getAvailableCredit,
    };
  },
  {
    persist: {
      key: 'tienda-clients',
      serializer: clientsSerializer,
    },
  },
);

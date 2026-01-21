import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';
import { clientsSerializer } from '../data/serializers';
import { generateUUID } from '../utils/uuid';

// WO-001: Changed all IDs from number to string (UUID)
export interface ClientTransaction {
  id: string; // UUID
  clientId: string; // UUID - references Client.id
  type: 'purchase' | 'payment';
  amount: Decimal;
  description: string;
  date: string;
  saleId?: string; // UUID - references Sale.id
}

// WO-001: Changed id from number to string (UUID)
export interface Client {
  id: string; // UUID
  name: string;
  cedula: string;
  phone?: string;
  creditLimit: Decimal;
  balance: Decimal; // Positive = owes money, Negative = credit
  createdAt: string;
  updatedAt: string;
}

export const useClientsStore = defineStore(
  'clients',
  () => {
    const clients = ref<Client[]>([]);
    const transactions = ref<ClientTransaction[]>([]);

    // Computed
    const totalDebt = computed(() => {
      return clients.value.reduce(
        (sum, c) => sum.plus(c.balance.gt(0) ? c.balance : new Decimal(0)),
        new Decimal(0),
      );
    });

    const clientsWithDebt = computed(() => {
      return clients.value.filter((c) => c.balance.gt(0));
    });

    // Methods
    // WO-001: Changed to use UUID instead of numeric ID
    const addClient = (data: Omit<Client, 'id' | 'balance' | 'createdAt' | 'updatedAt'>) => {
      const now = new Date().toISOString();
      const client: Client = {
        id: generateUUID(), // WO-001: Use UUID
        ...data,
        balance: new Decimal(0),
        createdAt: now,
        updatedAt: now,
      };
      clients.value.push(client);
      return client;
    };

    // WO-001: Changed parameter type from number to string
    const updateClient = (id: string, data: Partial<Omit<Client, 'id' | 'createdAt'>>) => {
      const index = clients.value.findIndex((c) => c.id === id);
      if (index !== -1) {
        clients.value[index] = {
          ...clients.value[index],
          ...data,
          updatedAt: new Date().toISOString(),
        };
        return clients.value[index];
      }
      return null;
    };

    // WO-001: Changed parameter type from number to string
    const deleteClient = (id: string) => {
      const index = clients.value.findIndex((c) => c.id === id);
      if (index !== -1) {
        clients.value.splice(index, 1);
        // Also remove transactions
        transactions.value = transactions.value.filter((t) => t.clientId !== id);
      }
    };

    // WO-001: Changed parameter type from number to string
    const getClientById = (id: string) => {
      return clients.value.find((c) => c.id === id);
    };

    const getClientByCedula = (cedula: string) => {
      return clients.value.find((c) => c.cedula === cedula);
    };

    const searchClients = (query: string) => {
      const q = query.toLowerCase().trim();
      if (!q) return clients.value;
      return clients.value.filter(
        (c) => c.name.toLowerCase().includes(q) || c.cedula.includes(q) || c.phone?.includes(q),
      );
    };

    // WO-001: Changed parameter type from number to string
    const addPurchaseDebt = (
      clientId: string,
      amount: Decimal,
      description: string,
      saleId?: string,
    ) => {
      const client = getClientById(clientId);
      if (!client) return null;

      const tx: ClientTransaction = {
        id: generateUUID(), // WO-001: Use UUID
        clientId,
        type: 'purchase',
        amount,
        description,
        date: new Date().toISOString(),
        saleId,
      };
      transactions.value.push(tx);

      // Increase balance (debt)
      client.balance = client.balance.plus(amount);
      client.updatedAt = new Date().toISOString();

      return tx;
    };

    // WO-001: Changed parameter type from number to string
    const registerPayment = (clientId: string, amount: Decimal, description = 'Abono') => {
      const client = getClientById(clientId);
      if (!client) return null;

      const tx: ClientTransaction = {
        id: generateUUID(), // WO-001: Use UUID
        clientId,
        type: 'payment',
        amount,
        description,
        date: new Date().toISOString(),
      };
      transactions.value.push(tx);

      // Decrease balance
      client.balance = client.balance.minus(amount);
      client.updatedAt = new Date().toISOString();

      return tx;
    };

    // WO-001: Changed parameter type from number to string
    const getClientTransactions = (clientId: string) => {
      return transactions.value
        .filter((t) => t.clientId === clientId)
        .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
    };

    // WO-001: Changed parameter type from number to string
    const getAvailableCredit = (clientId: string) => {
      const client = getClientById(clientId);
      if (!client) return new Decimal(0);
      return client.creditLimit.minus(client.balance);
    };

    // WO-001: Initialize with sample data using UUID
    const initializeSampleData = () => {
      if (clients.value.length > 0) return;

      const sampleClients = [
        {
          name: 'María Pérez',
          cedula: '1020304050',
          phone: '3001234567',
          creditLimit: new Decimal(200000),
        },
        {
          name: 'Jorge Villamizar',
          cedula: '98765432',
          phone: '3109876543',
          creditLimit: new Decimal(150000),
        },
        { name: 'Luisa Mendoza', cedula: '52190876', creditLimit: new Decimal(100000) },
        {
          name: 'Carlos Rodriguez',
          cedula: '79444111',
          phone: '3205551234',
          creditLimit: new Decimal(300000),
        },
      ];

      // WO-001: Store generated client IDs for sample transactions
      const generatedClients: Client[] = [];

      sampleClients.forEach((c) => {
        const now = new Date().toISOString();
        const newClient: Client = {
          id: generateUUID(), // WO-001: Use UUID
          ...c,
          balance: new Decimal(0),
          createdAt: now,
          updatedAt: now,
        };
        clients.value.push(newClient);
        generatedClients.push(newClient);
      });

      // Add some sample transactions using the generated client IDs
      if (generatedClients.length >= 4) {
        addPurchaseDebt(generatedClients[0].id, new Decimal(120000), 'Compra inicial');
        addPurchaseDebt(generatedClients[1].id, new Decimal(45000), 'Mercado semanal');
        addPurchaseDebt(generatedClients[3].id, new Decimal(35500), 'Productos varios');
        registerPayment(generatedClients[3].id, new Decimal(20000), 'Abono efectivo');
      }
    };

    return {
      clients,
      transactions,
      totalDebt,
      clientsWithDebt,
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
      initializeSampleData,
    };
  },
  {
    persist: {
      key: 'tienda-clients',
      serializer: clientsSerializer,
    },
  },
);

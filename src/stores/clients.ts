import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';

export interface ClientTransaction {
    id: number;
    clientId: number;
    type: 'purchase' | 'payment';
    amount: Decimal;
    description: string;
    date: string;
    saleId?: number;
}

export interface Client {
    id: number;
    name: string;
    cedula: string;
    phone?: string;
    creditLimit: Decimal;
    balance: Decimal; // Positive = owes money, Negative = credit
    createdAt: string;
    updatedAt: string;
}

// Serialization helpers
function serializeClient(client: Client) {
    return {
        ...client,
        creditLimit: client.creditLimit.toString(),
        balance: client.balance.toString(),
    };
}

function deserializeClient(data: any): Client {
    return {
        ...data,
        creditLimit: new Decimal(data.creditLimit || 0),
        balance: new Decimal(data.balance || 0),
    };
}

function serializeTransaction(tx: ClientTransaction) {
    return {
        ...tx,
        amount: tx.amount.toString(),
    };
}

function deserializeTransaction(data: any): ClientTransaction {
    return {
        ...data,
        amount: new Decimal(data.amount || 0),
    };
}

export const useClientsStore = defineStore('clients', () => {
    const clients = ref<Client[]>([]);
    const transactions = ref<ClientTransaction[]>([]);
    const nextClientId = ref(1);
    const nextTransactionId = ref(1);

    // Computed
    const totalDebt = computed(() => {
        return clients.value.reduce((sum, c) => sum.plus(c.balance.gt(0) ? c.balance : new Decimal(0)), new Decimal(0));
    });

    const clientsWithDebt = computed(() => {
        return clients.value.filter(c => c.balance.gt(0));
    });

    // Methods
    const addClient = (data: Omit<Client, 'id' | 'balance' | 'createdAt' | 'updatedAt'>) => {
        const now = new Date().toISOString();
        const client: Client = {
            id: nextClientId.value++,
            ...data,
            balance: new Decimal(0),
            createdAt: now,
            updatedAt: now,
        };
        clients.value.push(client);
        return client;
    };

    const updateClient = (id: number, data: Partial<Omit<Client, 'id' | 'createdAt'>>) => {
        const index = clients.value.findIndex(c => c.id === id);
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

    const deleteClient = (id: number) => {
        const index = clients.value.findIndex(c => c.id === id);
        if (index !== -1) {
            clients.value.splice(index, 1);
            // Also remove transactions
            transactions.value = transactions.value.filter(t => t.clientId !== id);
        }
    };

    const getClientById = (id: number) => {
        return clients.value.find(c => c.id === id);
    };

    const getClientByCedula = (cedula: string) => {
        return clients.value.find(c => c.cedula === cedula);
    };

    const searchClients = (query: string) => {
        const q = query.toLowerCase().trim();
        if (!q) return clients.value;
        return clients.value.filter(c =>
            c.name.toLowerCase().includes(q) ||
            c.cedula.includes(q) ||
            c.phone?.includes(q)
        );
    };

    const addPurchaseDebt = (clientId: number, amount: Decimal, description: string, saleId?: number) => {
        const client = getClientById(clientId);
        if (!client) return null;

        const tx: ClientTransaction = {
            id: nextTransactionId.value++,
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

    const registerPayment = (clientId: number, amount: Decimal, description = 'Abono') => {
        const client = getClientById(clientId);
        if (!client) return null;

        const tx: ClientTransaction = {
            id: nextTransactionId.value++,
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

    const getClientTransactions = (clientId: number) => {
        return transactions.value
            .filter(t => t.clientId === clientId)
            .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
    };

    const getAvailableCredit = (clientId: number) => {
        const client = getClientById(clientId);
        if (!client) return new Decimal(0);
        return client.creditLimit.minus(client.balance);
    };

    // Initialize with sample data
    const initializeSampleData = () => {
        if (clients.value.length > 0) return;

        const sampleClients = [
            { name: 'María Pérez', cedula: '1020304050', phone: '3001234567', creditLimit: new Decimal(200000) },
            { name: 'Jorge Villamizar', cedula: '98765432', phone: '3109876543', creditLimit: new Decimal(150000) },
            { name: 'Luisa Mendoza', cedula: '52190876', creditLimit: new Decimal(100000) },
            { name: 'Carlos Rodriguez', cedula: '79444111', phone: '3205551234', creditLimit: new Decimal(300000) },
        ];

        sampleClients.forEach(c => {
            const now = new Date().toISOString();
            clients.value.push({
                id: nextClientId.value++,
                ...c,
                balance: new Decimal(0),
                createdAt: now,
                updatedAt: now,
            });
        });

        // Add some sample transactions
        addPurchaseDebt(1, new Decimal(120000), 'Compra inicial');
        addPurchaseDebt(2, new Decimal(45000), 'Mercado semanal');
        addPurchaseDebt(4, new Decimal(35500), 'Productos varios');
        registerPayment(4, new Decimal(20000), 'Abono efectivo');
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
}, {
    persist: {
        key: 'tienda-clients',
        serializer: {
            serialize: (state: any) => {
                return JSON.stringify({
                    clients: state.clients.map(serializeClient),
                    transactions: state.transactions.map(serializeTransaction),
                    nextClientId: state.nextClientId,
                    nextTransactionId: state.nextTransactionId,
                });
            },
            deserialize: (value: string) => {
                const data = JSON.parse(value);
                return {
                    clients: data.clients?.map(deserializeClient) || [],
                    transactions: data.transactions?.map(deserializeTransaction) || [],
                    nextClientId: data.nextClientId || 1,
                    nextTransactionId: data.nextTransactionId || 1,
                };
            },
        },
    },
});

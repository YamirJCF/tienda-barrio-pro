import type { Client, ClientTransaction } from '../../stores/clients';
import { toDecimal } from './decimalSerializer';
import { Decimal } from 'decimal.js';

interface SerializedClient {
  id: number;
  name: string;
  cedula: string;
  phone?: string;
  creditLimit: string;
  balance: string;
  createdAt: string;
  updatedAt: string;
}

interface SerializedTransaction {
  id: number;
  clientId: number;
  type: 'purchase' | 'payment';
  amount: string;
  description: string;
  date: string;
  saleId?: number;
}

export interface ClientsState {
  clients: Client[];
  transactions: ClientTransaction[];
  nextClientId: number;
  nextTransactionId: number;
}

interface SerializedClientsState {
  clients: SerializedClient[];
  transactions: SerializedTransaction[];
  nextClientId: number;
  nextTransactionId: number;
}

export const serializeClient = (client: Client): SerializedClient => ({
  id: client.id,
  name: client.name,
  cedula: client.cedula,
  phone: client.phone,
  creditLimit: client.creditLimit.toString(),
  balance: client.balance.toString(),
  createdAt: client.createdAt,
  updatedAt: client.updatedAt,
});

export const deserializeClient = (data: SerializedClient): Client => ({
  id: data.id,
  name: data.name,
  cedula: data.cedula,
  phone: data.phone,
  creditLimit: toDecimal(data.creditLimit),
  balance: toDecimal(data.balance),
  createdAt: data.createdAt,
  updatedAt: data.updatedAt,
});

export const serializeTransaction = (tx: ClientTransaction): SerializedTransaction => ({
  id: tx.id,
  clientId: tx.clientId,
  type: tx.type,
  amount: tx.amount.toString(),
  description: tx.description,
  date: tx.date,
  saleId: tx.saleId,
});

export const deserializeTransaction = (data: SerializedTransaction): ClientTransaction => ({
  id: data.id,
  clientId: data.clientId,
  type: data.type,
  amount: toDecimal(data.amount),
  description: data.description,
  date: data.date,
  saleId: data.saleId,
});

export const clientsSerializer = {
  serialize: (state: ClientsState): string => {
    const serialized: SerializedClientsState = {
      clients: state.clients.map(serializeClient),
      transactions: state.transactions.map(serializeTransaction),
      nextClientId: state.nextClientId,
      nextTransactionId: state.nextTransactionId,
    };
    return JSON.stringify(serialized);
  },

  deserialize: (value: string): ClientsState => {
    const data: SerializedClientsState = JSON.parse(value);
    return {
      clients: data.clients?.map(deserializeClient) || [],
      transactions: data.transactions?.map(deserializeTransaction) || [],
      nextClientId: data.nextClientId || 1,
      nextTransactionId: data.nextTransactionId || 1,
    };
  },
};

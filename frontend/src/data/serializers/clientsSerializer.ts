import type { Client, ClientTransaction } from '../../types'; // Corrected import
import { toDecimal } from './decimalSerializer';
import { Decimal } from 'decimal.js';

interface SerializedClient {
  id: string; // Updated to string (UUID)
  name: string;
  cc: string; // Renamed from cedula
  phone?: string;
  creditLimit: string;
  totalDebt: string; // Renamed from balance
  createdAt: string;
  updatedAt: string;
  // Legacy fields for migration
  cedula?: string;
  balance?: string;
}

interface SerializedTransaction {
  id: string; // Updated to string (UUID)
  clientId: string; // Updated to string
  type: 'purchase' | 'payment';
  amount: string;
  description: string;
  date: string;
  saleId?: string; // Updated to string
}

export interface ClientsState {
  clients: Client[];
  transactions: ClientTransaction[];
  // nextClientId: number; // Deprecated, we use UUIDs
  // nextTransactionId: number; // Deprecated
  // We keep them for type safety if serializer references them, 
  // but better to make them optional or ignore?
  // Existing code in lines 88/98 used 'nextClientId'.
  // I will keep them optional to avoid breaking existing state shape if validation is strict.
  nextClientId?: number;
  nextTransactionId?: number;
}

interface SerializedClientsState {
  clients: SerializedClient[];
  transactions: SerializedTransaction[];
  nextClientId?: number;
  nextTransactionId?: number;
}

export const serializeClient = (client: Client): SerializedClient => ({
  id: client.id,
  name: client.name,
  cc: client.cc,
  phone: client.phone,
  creditLimit: client.creditLimit.toString(),
  totalDebt: client.totalDebt.toString(),
  createdAt: client.createdAt || new Date().toISOString(),
  updatedAt: client.updatedAt || new Date().toISOString(),
});

export const deserializeClient = (data: SerializedClient): Client => ({
  id: data.id.toString(), // Ensure string
  name: data.name,
  cc: data.cc || data.cedula || '', // Migration
  phone: data.phone,
  creditLimit: toDecimal(data.creditLimit),
  totalDebt: toDecimal(data.totalDebt || data.balance || 0), // Migration
  createdAt: data.createdAt,
  updatedAt: data.updatedAt,
  storeId: (data as any).storeId || '', // Handle missing storeId? (should be there for persistence validation)
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
  serialize: (state: any): string => {
    // Only serialize data arrays, not UI state
    const serialized: SerializedClientsState = {
      clients: (state.clients || []).map(serializeClient),
      transactions: (state.transactions || []).map(serializeTransaction),
      nextClientId: state.nextClientId,
      nextTransactionId: state.nextTransactionId,
    };
    return JSON.stringify(serialized);
  },

  deserialize: (value: string): any => {
    const data: SerializedClientsState = JSON.parse(value);
    return {
      clients: data.clients?.map(deserializeClient) || [],
      transactions: data.transactions?.map(deserializeTransaction) || [],
      nextClientId: data.nextClientId || 1,
      nextTransactionId: data.nextTransactionId || 1,
      // Restore default UI state
      isLoading: false,
      error: null,
    };
  },
};

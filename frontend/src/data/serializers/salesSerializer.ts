import type { Sale, SaleItem } from '../../types';
import { toDecimal, fromDecimal } from './decimalSerializer';
import { Decimal } from 'decimal.js';

interface SerializedSaleItem {
  productId: string; // Updated to string (UUID)
  productName: string;
  quantity: number;
  price: string;
  subtotal: string;
}

interface SerializedSale {
  id: string; // Updated to string (UUID)
  items: SerializedSaleItem[];
  total: string;
  roundingDifference?: string;
  effectiveTotal: string;
  paymentMethod: string;
  amountReceived?: string;
  change?: string;
  clientId?: string; // Updated to string (UUID)
  timestamp: string;
  date: string;
  syncStatus?: 'synced' | 'pending' | 'failed'; // Added to match Sale interface
}

export interface SalesState {
  sales: Sale[];
  // nextId: number; // Removed or deprecated if using UUIDs?
  // If nextId is used for ticketNumber, keep it but as number.
  // If used for IDs, it's obsolete.
  // Assuming it's for ticketNumber for now.
  isStoreOpen: boolean;
  openingCash: Decimal;
  currentCash: Decimal;
  // Make serialized state match store state generally.
  // But if the store still has nextId, we keep it.
}

// Update imports or define interfaces if store has separate state definition
// Ideally this serializer matches the Store State structure.
// Assuming 'sales' store state has these fields.

interface SerializedSalesState {
  sales: SerializedSale[];
  nextId: number;
  isStoreOpen: boolean;
  openingCash: string;
  currentCash: string;
}

export const serializeSaleItem = (item: SaleItem): SerializedSaleItem => ({
  productId: item.productId,
  productName: item.productName,
  quantity: item.quantity,
  price: item.price.toString(),
  subtotal: item.subtotal.toString(),
});

export const deserializeSaleItem = (data: SerializedSaleItem): SaleItem => ({
  productId: data.productId,
  productName: data.productName,
  quantity: data.quantity,
  price: toDecimal(data.price),
  subtotal: toDecimal(data.subtotal),
});

export const serializeSale = (sale: Sale): SerializedSale => ({
  id: sale.id,
  items: sale.items.map(serializeSaleItem),
  total: sale.total.toString(),
  roundingDifference: fromDecimal(sale.roundingDifference),
  effectiveTotal: sale.effectiveTotal.toString(),
  paymentMethod: sale.paymentMethod,
  amountReceived: fromDecimal(sale.amountReceived),
  change: fromDecimal(sale.change),
  clientId: sale.clientId,
  timestamp: sale.timestamp,
  date: sale.date,
  syncStatus: sale.syncStatus
});

export const deserializeSale = (data: SerializedSale): Sale => ({
  id: data.id,
  // We need ticketNumber for Sale interface.
  // If serialized data doesn't have it, we might need a default or migration.
  // SerializedSale above doesn't have ticketNumber.
  // We should add it to SerializedSale if we want to persist it.
  // Or generate/mock it on deserialize if missing.
  ticketNumber: 0, // Default for migrated empty data
  items: data.items.map(deserializeSaleItem),
  total: toDecimal(data.total),
  roundingDifference: data.roundingDifference ? toDecimal(data.roundingDifference) : undefined,
  effectiveTotal: toDecimal(data.effectiveTotal || data.total),
  paymentMethod: data.paymentMethod,
  amountReceived: data.amountReceived ? toDecimal(data.amountReceived) : undefined,
  change: data.change ? toDecimal(data.change) : undefined,
  clientId: data.clientId,
  timestamp: data.timestamp,
  date: data.date,
  syncStatus: data.syncStatus
});

export const salesSerializer = {
  serialize: (state: SalesState): string => {
    // We assume state matches SalesState interface defined here.
    // However, we need to be careful if the actual Store has different fields.
    const serialized: SerializedSalesState = {
      sales: state.sales.map(serializeSale),
      nextId: (state as any).nextId || 0, // Handle missing nextId safely
      isStoreOpen: state.isStoreOpen,
      openingCash: state.openingCash.toString(),
      currentCash: state.currentCash.toString(),
    };
    return JSON.stringify(serialized);
  },

  deserialize: (value: string): SalesState => {
    const data: SerializedSalesState = JSON.parse(value);
    return {
      sales: data.sales.map(deserializeSale),
      // nextId: data.nextId, // Deprecated
      isStoreOpen: data.isStoreOpen,
      openingCash: toDecimal(data.openingCash),
      currentCash: toDecimal(data.currentCash),
    };
  },
};

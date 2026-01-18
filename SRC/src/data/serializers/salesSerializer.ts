import type { Sale, SaleItem } from '../../stores/sales';
import { toDecimal, fromDecimal } from './decimalSerializer';
import { Decimal } from 'decimal.js';

interface SerializedSaleItem {
    productId: number;
    productName: string;
    quantity: number;
    price: string;
    subtotal: string;
}

interface SerializedSale {
    id: number;
    items: SerializedSaleItem[];
    total: string;
    paymentMethod: 'cash' | 'nequi' | 'fiado';
    amountReceived?: string;
    change?: string;
    clientId?: number;
    timestamp: string;
    date: string;
}

export interface SalesState {
    sales: Sale[];
    nextId: number;
    isStoreOpen: boolean;
    openingCash: Decimal;
    currentCash: Decimal;
}

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
    paymentMethod: sale.paymentMethod,
    amountReceived: fromDecimal(sale.amountReceived),
    change: fromDecimal(sale.change),
    clientId: sale.clientId,
    timestamp: sale.timestamp,
    date: sale.date,
});

export const deserializeSale = (data: SerializedSale): Sale => ({
    id: data.id,
    items: data.items.map(deserializeSaleItem),
    total: toDecimal(data.total),
    paymentMethod: data.paymentMethod,
    amountReceived: data.amountReceived ? toDecimal(data.amountReceived) : undefined,
    change: data.change ? toDecimal(data.change) : undefined,
    clientId: data.clientId,
    timestamp: data.timestamp,
    date: data.date,
});

export const salesSerializer = {
    serialize: (state: SalesState): string => {
        const serialized: SerializedSalesState = {
            sales: state.sales.map(serializeSale),
            nextId: state.nextId,
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
            nextId: data.nextId,
            isStoreOpen: data.isStoreOpen,
            openingCash: toDecimal(data.openingCash),
            currentCash: toDecimal(data.currentCash),
        };
    },
};

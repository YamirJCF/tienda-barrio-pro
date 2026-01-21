import { Decimal } from 'decimal.js';

export type MeasurementUnit = 'un' | 'kg' | 'lb' | 'g';

export interface Product {
    id: number;
    name: string;
    price: Decimal;
    stock: Decimal;
    measurementUnit: MeasurementUnit;
    category?: string;
    brand?: string;
    minStock: number;
    cost?: Decimal;
    plu?: string;
    isWeighable?: boolean;
    createdAt?: string;
    updatedAt?: string;
    notifiedLowStock?: boolean;
}

export interface CartItem {
    id: number;
    name: string;
    price: Decimal;
    quantity: number | Decimal;
    measurementUnit: MeasurementUnit;
    isWeighable?: boolean;
    subtotal?: Decimal;
    // Optional metadata from product if needed
    plu?: string;
    brand?: string;
    category?: string;
}

export interface SaleItem {
    productId: number;
    productName: string;
    quantity: number;
    price: Decimal;
    subtotal: Decimal;
}

export interface Sale {
    id: number;
    date: string; // YYYY-MM-DD
    timestamp: string; // ISO Full
    items: SaleItem[];
    total: Decimal;
    paymentMethod: 'cash' | 'nequi' | 'fiado';
    roundingDifference?: Decimal;
    effectiveTotal: Decimal;
    amountReceived?: Decimal;
    change?: Decimal;
    clientId?: number;
}

export interface Client {
    id: number;
    name: string;
    cc: string;
    phone?: string;
    email?: string;
    totalDebt: Decimal;
    notes?: string;
}

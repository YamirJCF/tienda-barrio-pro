import type { Product, MeasurementUnit } from '../../stores/inventory';
import { toDecimal, fromDecimal } from './decimalSerializer';
import { Decimal } from 'decimal.js';

interface SerializedProduct {
    id: number;
    name: string;
    brand?: string;
    category?: string;
    plu?: string;
    price: string;
    cost?: string;
    isWeighable: boolean;
    measurementUnit: MeasurementUnit;
    stock: string;
    minStock: number;
    createdAt: string;
    updatedAt: string;
}

export interface InventoryState {
    products: Product[];
    nextId: number;
}

interface SerializedInventoryState {
    products: SerializedProduct[];
    nextId: number;
}

export const serializeProduct = (product: Product): SerializedProduct => ({
    id: product.id,
    name: product.name,
    brand: product.brand,
    category: product.category,
    plu: product.plu,
    price: product.price.toString(),
    cost: fromDecimal(product.cost),
    isWeighable: product.isWeighable,
    measurementUnit: product.measurementUnit,
    stock: product.stock.toString(),
    minStock: product.minStock,
    createdAt: product.createdAt,
    updatedAt: product.updatedAt,
});

export const deserializeProduct = (data: SerializedProduct): Product => ({
    id: data.id,
    name: data.name,
    brand: data.brand,
    category: data.category,
    plu: data.plu,
    price: toDecimal(data.price),
    cost: data.cost ? toDecimal(data.cost) : undefined,
    isWeighable: data.isWeighable,
    measurementUnit: data.measurementUnit,
    stock: toDecimal(data.stock),
    minStock: data.minStock,
    createdAt: data.createdAt,
    updatedAt: data.updatedAt,
});

export const inventorySerializer = {
    serialize: (state: InventoryState): string => {
        const serialized: SerializedInventoryState = {
            products: state.products.map(serializeProduct),
            nextId: state.nextId,
        };
        return JSON.stringify(serialized);
    },

    deserialize: (value: string): InventoryState => {
        const data: SerializedInventoryState = JSON.parse(value);
        return {
            products: data.products.map(deserializeProduct),
            nextId: data.nextId,
        };
    },
};

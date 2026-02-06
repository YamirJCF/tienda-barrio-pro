import type { Product } from '../../types';
import { toDecimal } from './decimalSerializer';
import { Decimal } from 'decimal.js';

interface SerializedProduct {
  id: string; // UUID
  name: string;
  price: string;
  stock: string;
  measurementUnit: string;
  category?: string;
  brand?: string;
  minStock: number;
  cost?: string;
  plu?: string;
  isWeighable?: boolean;
  createdAt?: string;
  updatedAt?: string;
  storeId: string;
}

export interface InventoryState {
  products: Product[];
  isLoading: boolean;
  error: string | null;
  initialized: boolean;
  loadedStoreId: string | null;
}

interface SerializedInventoryState {
  products: SerializedProduct[];
}

export const serializeProduct = (product: Product): SerializedProduct => ({
  id: product.id,
  name: product.name,
  price: product.price.toString(),
  stock: product.stock.toString(),
  measurementUnit: product.measurementUnit,
  category: product.category,
  brand: product.brand,
  minStock: product.minStock,
  cost: product.cost?.toString(),
  plu: product.plu,
  isWeighable: product.isWeighable,
  createdAt: product.createdAt,
  updatedAt: product.updatedAt,
  storeId: product.storeId,
});

export const deserializeProduct = (data: SerializedProduct): Product => ({
  id: data.id,
  name: data.name,
  price: toDecimal(data.price),
  stock: toDecimal(data.stock),
  measurementUnit: data.measurementUnit as any,
  category: data.category,
  brand: data.brand,
  minStock: data.minStock,
  cost: data.cost ? toDecimal(data.cost) : undefined,
  plu: data.plu,
  isWeighable: data.isWeighable,
  createdAt: data.createdAt,
  updatedAt: data.updatedAt,
  notifiedLowStock: false, // Reset on load
  storeId: data.storeId,
});

export const inventorySerializer = {
  serialize: (state: any): string => {
    const serialized: SerializedInventoryState = {
      products: (state.products || []).map(serializeProduct),
    };
    return JSON.stringify(serialized);
  },

  deserialize: (value: string): any => {
    const data: SerializedInventoryState = JSON.parse(value);
    return {
      products: data.products?.map(deserializeProduct) || [],
      isLoading: false,
      error: null,
      initialized: false, // Force re-init on mount
      loadedStoreId: null,
    };
  },
};

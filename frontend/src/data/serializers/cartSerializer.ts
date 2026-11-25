import type { CartItem, MeasurementUnit } from '../../types';
import { toDecimal, fromDecimal } from './decimalSerializer';
import { Decimal } from 'decimal.js';

interface SerializedCartItem {
  id: string;
  name: string;
  price: string;
  quantity: string;
  unit: MeasurementUnit;
  isWeighable: boolean;
  subtotal?: string;
}

export interface CartState {
  items: CartItem[];
}

interface SerializedCartState {
  items: SerializedCartItem[];
}

export const serializeCartItem = (item: CartItem): SerializedCartItem => ({
  id: item.id,
  name: item.name,
  price: item.price.toString(),
  quantity: item.quantity.toString(),
  unit: item.measurementUnit,
  isWeighable: item.isWeighable,
  subtotal: fromDecimal(item.subtotal),
});

export const deserializeCartItem = (data: SerializedCartItem): CartItem => {
  const price = toDecimal(data.price);
  const quantity = toDecimal(data.quantity);
  return {
    id: data.id,
    name: data.name,
    price,
    quantity,
    measurementUnit: data.unit,
    isWeighable: data.isWeighable,
    subtotal: data.subtotal ? toDecimal(data.subtotal) : price.times(quantity),
  };
};

export const cartSerializer = {
  serialize: (state: CartState): string => {
    const serialized: SerializedCartState = {
      items: state.items.map(serializeCartItem),
    };
    return JSON.stringify(serialized);
  },

  deserialize: (value: string): CartState => {
    const data: SerializedCartState = JSON.parse(value);
    return {
      items: data.items.map(deserializeCartItem),
    };
  },
};

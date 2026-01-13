import type { CartItem } from '../../stores/cart';
import type { MeasurementUnit } from '../../stores/inventory';
import { toDecimal, fromDecimal } from './decimalSerializer';
import { Decimal } from 'decimal.js';

interface SerializedCartItem {
    id: number;
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
    unit: item.unit,
    isWeighable: item.isWeighable,
    subtotal: fromDecimal(item.subtotal),
});

export const deserializeCartItem = (data: SerializedCartItem): CartItem => ({
    id: data.id,
    name: data.name,
    price: toDecimal(data.price),
    quantity: toDecimal(data.quantity),
    unit: data.unit,
    isWeighable: data.isWeighable,
    subtotal: data.subtotal ? toDecimal(data.subtotal) : undefined,
});

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

import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';
import type { MeasurementUnit } from './inventory';
import { cartSerializer } from '../data/serializers';

export interface CartItem {
  id: number;
  name: string;
  price: Decimal;
  quantity: Decimal;           // Decimal to support fractional quantities (0.5 lb)
  unit: MeasurementUnit;       // 'kg', 'lb', 'g', 'un'
  isWeighable: boolean;        // true for weight-based products
  subtotal?: Decimal;          // Pre-calculated subtotal for weighable items
}

export const useCartStore = defineStore('cart', () => {
  const items = ref<CartItem[]>([]);

  const total = computed(() => {
    return items.value.reduce((acc, item) => {
      // Use subtotal if available (for weighable items), otherwise calculate
      const itemTotal = item.subtotal || item.price.times(item.quantity);
      return acc.plus(itemTotal);
    }, new Decimal(0));
  });

  const formattedTotal = computed(() => {
    return `$ ${total.value.toDecimalPlaces(0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".")}`;
  });

  // Add regular item (integer quantity) with defensive validation
  const addItem = (product: {
    id: number;
    name: string;
    price: Decimal;
    quantity: number;
    measurementUnit?: MeasurementUnit;
    isWeighable?: boolean;
  }) => {
    // ============================================
    // DEFENSIVE VALIDATION: Prevent NaN/Infinity
    // ============================================
    const qty = product.quantity;

    // Check if quantity is a valid finite number greater than 0
    if (typeof qty !== 'number' || !Number.isFinite(qty) || qty <= 0) {
      console.warn('[Cart] ⚠️ addItem rejected: Invalid quantity', {
        productId: product.id,
        productName: product.name,
        receivedQuantity: qty,
        type: typeof qty
      });
      return; // Silently ignore corrupt data
    }

    const existing = items.value.find(i => i.id === product.id);
    if (existing) {
      // Add the quantity from the product
      existing.quantity = existing.quantity.plus(qty);
      // Recalculate subtotal if weighable
      if (existing.isWeighable) {
        existing.subtotal = existing.price.times(existing.quantity);
      }
    } else {
      items.value.push({
        id: product.id,
        name: product.name,
        price: product.price,
        quantity: new Decimal(qty),
        unit: product.measurementUnit || 'un',
        isWeighable: product.isWeighable || false,
      });
    }
  };

  // Add weighable item with Decimal quantity and pre-calculated subtotal
  // Includes defensive validation for Decimal values
  const addWeighableItem = (item: {
    id: number;
    name: string;
    price: Decimal;
    quantity: Decimal;
    unit: MeasurementUnit;
    subtotal: Decimal;
  }) => {
    // ============================================
    // DEFENSIVE VALIDATION: Prevent NaN/Infinity in Decimals
    // ============================================
    const isValidDecimal = (val: unknown): val is Decimal => {
      if (!(val instanceof Decimal)) return false;
      const num = val.toNumber();
      return Number.isFinite(num) && num > 0;
    };

    if (!isValidDecimal(item.quantity) || !isValidDecimal(item.subtotal)) {
      console.warn('[Cart] ⚠️ addWeighableItem rejected: Invalid Decimal values', {
        productId: item.id,
        productName: item.name,
        quantity: item.quantity?.toString?.() ?? 'undefined',
        subtotal: item.subtotal?.toString?.() ?? 'undefined'
      });
      return; // Silently ignore corrupt data
    }

    // 🛡️ SPEC-010: Redondeo híbrido a múltiplos de $50 (defensivo)
    const roundHybrid50 = (val: Decimal): Decimal => {
      const value = val.toNumber();
      const remainder = value % 50;
      return remainder <= 25
        ? new Decimal(Math.floor(value / 50) * 50)
        : new Decimal(Math.ceil(value / 50) * 50);
    };
    const roundedSubtotal = roundHybrid50(item.subtotal);

    const existing = items.value.find(i => i.id === item.id);
    if (existing) {
      // For weighable items, add quantity and subtotal
      existing.quantity = existing.quantity.plus(item.quantity);
      existing.subtotal = (existing.subtotal || new Decimal(0)).plus(roundedSubtotal);
    } else {
      items.value.push({
        id: item.id,
        name: item.name,
        price: item.price,
        quantity: item.quantity,
        unit: item.unit,
        isWeighable: true,
        subtotal: roundedSubtotal,
      });
    }
  };

  const removeItem = (id: number) => {
    const index = items.value.findIndex(i => i.id === id);
    if (index !== -1) {
      items.value.splice(index, 1);
    }
  };

  const clearCart = () => {
    items.value = [];
  };

  return {
    items,
    total,
    formattedTotal,
    addItem,
    addWeighableItem,
    removeItem,
    clearCart
  };
}, {
  persist: {
    key: 'tienda-cart',
    storage: localStorage,
    serializer: cartSerializer,
  },
});
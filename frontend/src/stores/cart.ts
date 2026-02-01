import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';
import { cartSerializer } from '../data/serializers';
import { getStorageKey } from '../utils/storage';
import { getLegalCashPayable, roundToNearest50 } from '../utils/currency';
import { useInventoryStore } from './inventory';
import type { CartItem, MeasurementUnit } from '../types';

export const useCartStore = defineStore(
  'cart',
  () => {
    const items = ref<CartItem[]>([]);
    const inventoryStore = useInventoryStore();

    // BR-03: Fiscal Calculation (Exact Math)
    const total = computed(() => {
      // ... existing logic
      return items.value.reduce((acc, item) => {
        const itemTotal = item.subtotal || item.price.times(item.quantity);
        return acc.plus(itemTotal);
      }, new Decimal(0));
    });

    // BR-04: Cash Payable (Floored to nearest 50)
    const totalCashPayable = computed(() => {
      return getLegalCashPayable(total.value);
    });

    // BR-06: Rounding Adjustment for Cash
    const roundingDifference = computed(() => {
      return totalCashPayable.value.minus(total.value);
    });

    const formattedTotal = computed(() => {
      return `$ ${total.value
        .toDecimalPlaces(0)
        .toString()
        .replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`;
    });

    // Helper: Validar stock disponible
    const checkStockAvailability = (productId: string, quantityToAdd: Decimal | number): boolean => {
      const product = inventoryStore.products.find(p => p.id === productId);
      if (!product) return false; // Producto no encontrado en inventario local

      const currentInCart = items.value.find(i => i.id === productId);
      const cartQty = currentInCart
        ? (currentInCart.quantity instanceof Decimal ? currentInCart.quantity : new Decimal(currentInCart.quantity))
        : new Decimal(0);

      const totalRequested = cartQty.plus(quantityToAdd);

      // Stock actual en repositorio
      const currentStock = product.stock instanceof Decimal ? product.stock : new Decimal(product.stock);

      // Si el stock es infinito (servicio?) o configuración permite negativos:
      // Por ahora, asumimos bloqueo estricto si stock < solicitado
      return totalRequested.lte(currentStock);
    };

    // Add regular item (integer quantity) with defensive validation
    const addItem = (product: {
      id: string; // UUID
      name: string;
      price: Decimal;
      quantity: number;
      measurementUnit?: MeasurementUnit;
      isWeighable?: boolean;
    }): boolean => {
      // ============================================
      // DEFENSIVE VALIDATION: Prevent NaN/Infinity
      // ============================================
      const qty = product.quantity;

      if (typeof qty !== 'number' || !Number.isFinite(qty) || qty <= 0) {
        console.warn('[Cart] ⚠️ addItem rejected: Invalid quantity');
        return false;
      }

      // 🛑 Validar Stock
      if (!checkStockAvailability(product.id, qty)) {
        console.warn('[Cart] ⚠️ addItem rejected: Insufficient stock');
        return false;
      }

      const existing = items.value.find((i) => i.id === product.id);
      if (existing) {
        const currentQty = existing.quantity instanceof Decimal ? existing.quantity : new Decimal(existing.quantity);
        existing.quantity = currentQty.plus(qty);
        if (existing.isWeighable) {
          existing.subtotal = existing.price.times(existing.quantity);
        }
      } else {
        items.value.push({
          id: product.id,
          name: product.name,
          price: product.price,
          quantity: new Decimal(qty),
          measurementUnit: product.measurementUnit || 'un',
          isWeighable: product.isWeighable || false,
        });
      }
      return true;
    };

    // Add weighable item
    const addWeighableItem = (item: {
      id: string;
      name: string;
      price: Decimal;
      quantity: Decimal;
      unit: MeasurementUnit;
      subtotal: Decimal;
    }): boolean => {
      // Validation helpers...
      const isValidDecimal = (val: unknown): val is Decimal => {
        if (!(val instanceof Decimal)) return false;
        const num = val.toNumber();
        return Number.isFinite(num) && num > 0;
      };

      if (!isValidDecimal(item.quantity) || !isValidDecimal(item.subtotal)) {
        console.warn('[Cart] ⚠️ addWeighableItem rejected: Invalid Decimal values');
        return false;
      }

      // 🛑 Validar Stock
      if (!checkStockAvailability(item.id, item.quantity)) {
        console.warn('[Cart] ⚠️ addWeighableItem rejected: Insufficient stock');
        return false;
      }

      // 🛡️ SPEC-010: Redondeo híbrido
      const roundedSubtotal = roundToNearest50(item.subtotal);

      const existing = items.value.find((i) => i.id === item.id);
      // ... same logic
      if (existing) {
        const currentQty = existing.quantity instanceof Decimal ? existing.quantity : new Decimal(existing.quantity);
        existing.quantity = currentQty.plus(item.quantity);
        existing.subtotal = (existing.subtotal || new Decimal(0)).plus(roundedSubtotal);
      } else {
        items.value.push({
          id: item.id,
          name: item.name,
          price: item.price,
          quantity: item.quantity,
          measurementUnit: item.unit,
          isWeighable: true,
          subtotal: roundedSubtotal,
        });
      }
      return true;
    };

    const removeItem = (id: string) => {
      const index = items.value.findIndex((i) => i.id === id);
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
      totalCashPayable,
      roundingDifference,
      formattedTotal,
      addItem,
      addWeighableItem,
      removeItem,
      clearCart,
    };
  },
  {

    persist: {
      key: getStorageKey('tienda-cart'),
      storage: localStorage,
      serializer: cartSerializer,
    },
  },
);

import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';
import { cartSerializer } from '../data/serializers';
import { getStorageKey } from '../utils/storage';
import { getLegalCashPayable, roundToNearest50 } from '../utils/currency';
import { useInventoryStore } from './inventory';
import { useAuthStore } from './auth';
import { useBatchStore } from './batches';
import type { CartItem, MeasurementUnit } from '../types';

// ============================================
// PUBLIC TYPES
// ============================================
export type AddItemResult = {
  success: boolean;
  warning?: string;    // Non-blocking: item entered cart but exceeds stock
  stockError?: string; // Blocking: item rejected
};

type StockCheckResult = {
  status: 'ok' | 'blocked' | 'force_allowed';
  availableStock?: string; // Formatted for UI display
  unit?: string;
};

export const useCartStore = defineStore(
  'cart',
  () => {
    const items = ref<CartItem[]>([]);
    const inventoryStore = useInventoryStore();
    const authStore = useAuthStore();
    const batchStore = useBatchStore();

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

    // ============================================
    // DOUBLE-INTENT TRACKING (Force Sale Pattern)
    // ============================================
    // Tracks productIds where admin was blocked once (1st attempt)
    // On 2nd attempt with SAME productId, allow with Force Sale warning
    const forcedProducts = ref<Set<string>>(new Set());

    // Format stock for human display (inline helper, no composable dependency)
    const formatAvailable = (stock: Decimal, unit: string = 'un'): string => {
      const num = stock.toNumber();
      switch (unit) {
        case 'un':
        case 'g':
          return Math.round(num).toString();
        case 'kg':
        case 'lb': {
          const rounded = Math.round(num * 100) / 100;
          return Number.isInteger(rounded) ? rounded.toString() : rounded.toFixed(2);
        }
        default:
          return Number.isInteger(num) ? num.toString() : num.toFixed(2);
      }
    };

    // Helper: Validar stock disponible (IGUALITARIO — sin bypass de rol)
    const checkStockAvailability = (productId: string, quantityToAdd: Decimal | number): StockCheckResult => {
      const product = inventoryStore.products.find(p => p.id === productId);
      // Items sin inventario (notas rápidas con UUID generado) → siempre OK
      if (!product) return { status: 'ok' };

      const currentInCart = items.value.find(i => i.id === productId);
      const cartQty = currentInCart
        ? (currentInCart.quantity instanceof Decimal ? currentInCart.quantity : new Decimal(currentInCart.quantity))
        : new Decimal(0);

      const totalRequested = cartQty.plus(quantityToAdd);
      const currentStock = product.stock instanceof Decimal ? product.stock : new Decimal(product.stock);
      const unit = product.measurementUnit || 'un';
      const availableFormatted = formatAvailable(currentStock, unit);

      // Stock suficiente → OK
      if (totalRequested.lte(currentStock)) {
        return { status: 'ok' };
      }

      // Stock excedido — ¿Admin ya intentó con ESTE producto? (2do intento)
      if (authStore.isAdmin && navigator.onLine && forcedProducts.value.has(productId)) {
        return { status: 'force_allowed', availableStock: availableFormatted, unit };
      }

      // Bloqueado (1er intento para todos, o empleado siempre)
      return { status: 'blocked', availableStock: availableFormatted, unit };
    };

    // Add regular item (integer quantity) with defensive validation
    const addItem = async (product: {
      id: string; // UUID
      name: string;
      price: Decimal;
      quantity: number;
      measurementUnit?: MeasurementUnit;
      isWeighable?: boolean;
    }): Promise<AddItemResult> => {
      // ============================================
      // DEFENSIVE VALIDATION: Prevent NaN/Infinity
      // ============================================
      const qty = product.quantity;

      if (typeof qty !== 'number' || !Number.isFinite(qty) || qty <= 0) {
        console.warn('[Cart] ⚠️ addItem rejected: Invalid quantity');
        return { success: false, stockError: 'Cantidad inválida' };
      }

      // SPEC-011: Reject decimals for integer-only units (un, g)
      const unit = product.measurementUnit || 'un';
      if ((unit === 'un' || unit === 'g') && !Number.isInteger(qty)) {
        console.warn(`[Cart] ⚠️ addItem rejected: Decimal quantity for unit '${unit}'`);
        return { success: false, stockError: 'No admite decimales' };
      }
      const check = checkStockAvailability(product.id, qty);

      if (check.status === 'blocked') {
        // Register attempt for admin double-intent tracking
        if (authStore.isAdmin && navigator.onLine) {
          forcedProducts.value.add(product.id);
        }
        console.warn('[Cart] ⚠️ addItem rejected: Insufficient stock');
        return {
          success: false,
          stockError: `Stock insuficiente. Disponible: ${check.availableStock} ${check.unit || ''}`.trim()
        };
      }

      // 🛑 WO-FIFO-004: Read active batches to split items with different prices
      let batches = await batchStore.fetchBatchesByProduct(product.id);
      batches = batches.filter(b => b.quantity_remaining > 0);

      let remainingQtyToAllocate = new Decimal(qty);
      let wasSplit = false;

      // Ensure we have batches. If offline or no batches, fallback to global price
      if (batches.length > 0) {
        for (const batch of batches) {
          if (remainingQtyToAllocate.lte(0)) break;
          
          const batchQtyRemaining = new Decimal(batch.quantity_remaining);
          const qtyToTake = Decimal.min(remainingQtyToAllocate, batchQtyRemaining);
          
          // Add to cart with batch-specific price
          const existing = items.value.find((i) => i.id === product.id && i.price.equals(new Decimal(batch.sale_price)));
          if (existing) {
            const currentQty = existing.quantity instanceof Decimal ? existing.quantity : new Decimal(existing.quantity);
            existing.quantity = currentQty.plus(qtyToTake);
          } else {
            items.value.push({
              id: product.id,
              name: product.name,
              price: new Decimal(batch.sale_price),
              quantity: qtyToTake,
              measurementUnit: product.measurementUnit || 'un',
              isWeighable: product.isWeighable || false,
            });
            // If we push a new item and it's not the first batch loop, it means we split
            if (qtyToTake.lt(new Decimal(qty))) {
                wasSplit = true;
            }
          }
          
          remainingQtyToAllocate = remainingQtyToAllocate.minus(qtyToTake);
        }
      }

      // If there's still quantity left (e.g., local overrides, offline, missing batch data), use default global price
      if (remainingQtyToAllocate.gt(0)) {
          const existing = items.value.find((i) => i.id === product.id && i.price.equals(product.price));
          if (existing) {
            const currentQty = existing.quantity instanceof Decimal ? existing.quantity : new Decimal(existing.quantity);
            existing.quantity = currentQty.plus(remainingQtyToAllocate);
          } else {
            items.value.push({
              id: product.id,
              name: product.name,
              price: product.price,
              quantity: remainingQtyToAllocate,
              measurementUnit: product.measurementUnit || 'un',
              isWeighable: product.isWeighable || false,
            });
            if (remainingQtyToAllocate.lt(new Decimal(qty))) {
                wasSplit = true;
            }
          }
      }

      // Determine return warnings
      if (check.status === 'force_allowed') {
        return {
          success: true,
          warning: `⚠️ Excede stock (disponible: ${check.availableStock} ${check.unit || ''}). Se requerirá Venta Forzada al cobrar.`.trim()
        };
      }

      if (wasSplit) {
          return {
              success: true,
              warning: `El producto se ha dividido en el carrito porque toma unidades de lotes con precios distintos.`
          };
      }

      return { success: true };
    };

    // Add weighable item
    const addWeighableItem = (item: {
      id: string;
      name: string;
      price: Decimal;
      quantity: Decimal;
      unit: MeasurementUnit;
      subtotal: Decimal;
    }): AddItemResult => {
      // Validation helpers...
      const isValidDecimal = (val: unknown): val is Decimal => {
        if (!(val instanceof Decimal)) return false;
        const num = val.toNumber();
        return Number.isFinite(num) && num > 0;
      };

      if (!isValidDecimal(item.quantity) || !isValidDecimal(item.subtotal)) {
        console.warn('[Cart] ⚠️ addWeighableItem rejected: Invalid Decimal values');
        return { success: false, stockError: 'Valores de peso inválidos' };
      }

      // 🛑 Validar Stock (IGUALITARIO)
      const check = checkStockAvailability(item.id, item.quantity);

      if (check.status === 'blocked') {
        if (authStore.isAdmin && navigator.onLine) {
          forcedProducts.value.add(item.id);
        }
        console.warn('[Cart] ⚠️ addWeighableItem rejected: Insufficient stock');
        return {
          success: false,
          stockError: `Stock insuficiente. Disponible: ${check.availableStock} ${check.unit || ''}`.trim()
        };
      }

      // 🛡️ SPEC-010: Redondeo híbrido
      const roundedSubtotal = roundToNearest50(item.subtotal);

      const existing = items.value.find((i) => i.id === item.id);
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

      // Return with warning if force-allowed
      if (check.status === 'force_allowed') {
        return {
          success: true,
          warning: `⚠️ Excede stock (disponible: ${check.availableStock} ${check.unit || ''}). Se requerirá Venta Forzada al cobrar.`.trim()
        };
      }

      return { success: true };
    };

    const removeItem = (id: string) => {
      const index = items.value.findIndex((i) => i.id === id);
      if (index !== -1) {
        items.value.splice(index, 1);
      }
    };

    const clearCart = () => {
      items.value = [];
      forcedProducts.value.clear(); // Reset double-intent tracking
    };

    // ============================================
    // FORCE SALE HELPERS
    // ============================================
    /** True if cart contains items that were added via Force Sale override */
    const hasForcedItems = computed(() => {
      return items.value.some(item => forcedProducts.value.has(item.id));
    });

    /** Check if a specific item in cart was force-added */
    const isForcedItem = (productId: string): boolean => {
      return forcedProducts.value.has(productId);
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
      hasForcedItems,
      isForcedItem,
      forcedProducts,
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

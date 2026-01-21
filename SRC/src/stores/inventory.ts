import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';
import { inventorySerializer } from '../data/serializers';
import { useNotificationsStore } from './notificationsStore';
import { generateUUID } from '../utils/uuid';
import type { Product } from '../types';

export const useInventoryStore = defineStore(
  'inventory',
  () => {
    const products = ref<Product[]>([]);

    // Computed
    const totalProducts = computed(() => products.value.length);

    const lowStockProducts = computed(() => products.value.filter((p) => p.stock.lte(p.minStock)));

    const productsByCategory = computed(() => {
      const grouped: Record<string, Product[]> = {};
      products.value.forEach((product) => {
        const category = product.category || 'Sin categoría';
        if (!grouped[category]) {
          grouped[category] = [];
        }
        grouped[category].push(product);
      });
      return grouped;
    });

    // 🛡️ SPEC-010: Redondeo híbrido a múltiplos de $50 (defensivo)
    const roundHybrid50 = (val: Decimal): Decimal => {
      const value = val.toNumber();
      const remainder = value % 50;
      return remainder <= 25
        ? new Decimal(Math.floor(value / 50) * 50)
        : new Decimal(Math.ceil(value / 50) * 50);
    };

    // Methods
    // WO-001: Changed to use UUID instead of numeric ID
    const addProduct = (productData: Omit<Product, 'id' | 'createdAt' | 'updatedAt'>) => {
      const now = new Date().toISOString();
      const newProduct: Product = {
        ...productData,
        price: roundHybrid50(productData.price), // SPEC-010: Forzar redondeo
        id: generateUUID(), // WO-001: Use UUID
        createdAt: now,
        updatedAt: now,
      };
      products.value.push(newProduct);
      return newProduct;
    };

    // WO-001: Changed parameter type from number to string
    const updateProduct = (id: string, updates: Partial<Omit<Product, 'id' | 'createdAt'>>) => {
      const index = products.value.findIndex((p) => p.id === id);
      if (index !== -1) {
        // SPEC-010: Si se actualiza el precio, forzar redondeo
        const processedUpdates = updates.price
          ? { ...updates, price: roundHybrid50(updates.price) }
          : updates;
        products.value[index] = {
          ...products.value[index],
          ...processedUpdates,
          updatedAt: new Date().toISOString(),
        };
        return products.value[index];
      }
      return null;
    };

    // WO-001: Changed parameter type from number to string
    const deleteProduct = (id: string) => {
      const index = products.value.findIndex((p) => p.id === id);
      if (index !== -1) {
        products.value.splice(index, 1);
        return true;
      }
      return false;
    };

    // WO-001: Changed parameter type from number to string
    const getProductById = (id: string) => {
      return products.value.find((p) => p.id === id);
    };

    const getProductByPLU = (plu: string) => {
      return products.value.find((p) => p.plu === plu);
    };

    const searchProducts = (query: string) => {
      const lowerQuery = query.toLowerCase();
      return products.value.filter((p) => {
        const nameMatch = p.name ? p.name.toLowerCase().includes(lowerQuery) : false;
        const brandMatch = p.brand ? p.brand.toLowerCase().includes(lowerQuery) : false;
        const catMatch = p.category ? p.category.toLowerCase().includes(lowerQuery) : false;
        const pluMatch = p.plu ? p.plu.includes(query) : false;

        return nameMatch || brandMatch || catMatch || pluMatch;
      });
    };

    // WO-001: Changed parameter type from number to string
    const updateStock = (
      id: string,
      quantity: number | Decimal,
    ): { success: boolean; product?: Product; error?: string } => {
      const product = products.value.find((p) => p.id === id);
      if (!product) {
        return { success: false, error: 'Producto no encontrado' };
      }

      const delta = quantity instanceof Decimal ? quantity : new Decimal(quantity);
      const newStock = product.stock.plus(delta);

      // 🛡️ T-001: Validación crítica - Rechazar si resultaría en stock negativo
      if (newStock.lt(0)) {
        return {
          success: false,
          error: `Stock insuficiente. Disponible: ${product.stock.toFixed(product.measurementUnit === 'un' ? 0 : 2)} ${product.measurementUnit}`,
        };
      }

      product.stock = newStock;
      product.updatedAt = new Date().toISOString();

      // Check for low stock notification
      if (product.stock.lt(product.minStock) && !product.notifiedLowStock) {
        const notificationsStore = useNotificationsStore();
        notificationsStore.addNotification({
          type: 'inventory',
          icon: 'inventory_2',
          title: `Stock Bajo: ${product.name}`,
          message: `Quedan ${product.stock.toFixed(product.measurementUnit === 'un' ? 0 : 2)} ${product.measurementUnit}`,
          isRead: false,
          metadata: {
            productId: String(product.id),
          },
        });
        product.notifiedLowStock = true;
      }

      // Reset flag if stock is restored above min
      if (product.stock.gte(product.minStock) && product.notifiedLowStock) {
        product.notifiedLowStock = false;
      }

      return { success: true, product };
    };

    // WO-001: initializeSampleData ELIMINADA - SPEC-007

    return {
      products,
      totalProducts,
      lowStockProducts,
      productsByCategory,
      addProduct,
      updateProduct,
      deleteProduct,
      getProductById,
      getProductByPLU,
      searchProducts,
      updateStock,
      // initializeSampleData ELIMINADA
    };
  },
  {
    persist: {
      key: 'tienda-inventory',
      storage: localStorage,
      serializer: inventorySerializer,
    },
  },
);

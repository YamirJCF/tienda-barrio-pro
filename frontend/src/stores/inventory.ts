import { defineStore } from 'pinia';
import { ref, computed, onUnmounted } from 'vue';
import { Decimal } from 'decimal.js';
import { useNotificationsStore } from './notificationsStore';
import { useAuthStore } from './auth';
import type { Product } from '../types';
import { productRepository, productMapper } from '../data/repositories/productRepository';
import { logger } from '../utils/logger';
import { getSupabaseClient, isSupabaseConfigured } from '../data/supabaseClient';
import { RealtimeChannel } from '@supabase/supabase-js';

export const useInventoryStore = defineStore(
  'inventory',
  () => {
    const products = ref<Product[]>([]);
    const isLoading = ref(false);
    const error = ref<string | null>(null);
    const initialized = ref(false);
    // WO-006: Track loaded store to prevent data cross-contamination between sessions
    const loadedStoreId = ref<string | null>(null);
    let realtimeSubscription: RealtimeChannel | null = null;

    // Computed
    const totalProducts = computed(() => products.value.length);
    const lowStockProducts = computed(() => products.value.filter((p) => p.stock.lte(p.minStock)));

    // Helper to ensure Decimal types after loading from raw JSON/Repo
    const ensureDecimals = (product: Partial<Product> & Record<string, any>): Product => {
      return {
        ...product as Product,
        price: new Decimal(product.price || 0),
        stock: new Decimal(product.stock || 0),
        cost: product.cost ? new Decimal(product.cost) : undefined,
      };
    };

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

    // T2.4: Realtime Subscriptions
    const setupRealtimeSubscription = (storeId?: string) => {
      if (!isSupabaseConfigured() || realtimeSubscription) return;

      const supabase = getSupabaseClient();
      if (!supabase) return;

      logger.log('[InventoryStore] Setting up realtime subscription');

      realtimeSubscription = supabase
        .channel('public:products')
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'products' }, // Add filter if storeId available
          (payload) => {
            logger.log('[InventoryStore] Realtime update:', payload);
            handleRealtimeEvent(payload);
          }
        )
        .subscribe((status) => {
          if (status === 'SUBSCRIBED') {
            logger.log('[InventoryStore] Connected to realtime changes');
          }
        });
    };

    const handleRealtimeEvent = (payload: any) => {
      const { eventType, new: newRecord, old: oldRecord } = payload;

      // Map DB fields (current_stock, measurement_unit) to domain fields (stock, measurementUnit)
      const mapRecord = (record: any): Product => {
        try {
          return ensureDecimals(productMapper.toDomain(record));
        } catch (e) {
          // Fallback if mapper fails (e.g., missing fields in realtime payload)
          logger.warn('[InventoryStore] Realtime mapper fallback', e);
          return ensureDecimals(record);
        }
      };

      if (eventType === 'INSERT') {
        const exists = products.value.find(p => p.id === newRecord.id);
        if (!exists) {
          products.value.push(mapRecord(newRecord));
        }
      } else if (eventType === 'UPDATE') {
        const index = products.value.findIndex(p => p.id === newRecord.id);
        if (index !== -1) {
          products.value[index] = mapRecord(newRecord);
        }
      } else if (eventType === 'DELETE') {
        const index = products.value.findIndex(p => p.id === oldRecord.id);
        if (index !== -1) {
          products.value.splice(index, 1);
        }
      }
    };

    const unsubscribeRealtime = () => {
      if (realtimeSubscription) {
        realtimeSubscription.unsubscribe();
        realtimeSubscription = null;
      }
    };

    /**
     * Initialize store by fetching from repository
     */
    const initialize = async (storeId?: string) => {
      const authStore = useAuthStore();
      const effectiveStoreId = storeId || authStore.currentUser?.storeId;

      if (!effectiveStoreId) return;

      // Only return early if initialized AND the data belongs to the SAME store
      if (initialized.value &&
        products.value.length > 0 &&
        loadedStoreId.value === effectiveStoreId) {
        return;
      }

      isLoading.value = true;
      try {
        const rawProducts = await productRepository.getAll(effectiveStoreId);
        products.value = rawProducts.map(ensureDecimals);

        // Setup realtime if available
        if (isSupabaseConfigured()) {
          setupRealtimeSubscription(effectiveStoreId);
        }

        initialized.value = true;
        loadedStoreId.value = effectiveStoreId;
      } catch (e: any) {
        error.value = e.message || 'Error loading products';
        logger.error('[InventoryStore] Init failed', e);
      } finally {
        isLoading.value = false;
      }
    };

    const addProduct = async (productData: Omit<Product, 'id' | 'createdAt' | 'updatedAt'>) => {
      const now = new Date().toISOString();
      const priceRounded = roundHybrid50(productData.price);

      const authStore = useAuthStore();
      const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;

      if (!storeId) {
        logger.error('[InventoryStore] Cannot create product: No store ID found in auth context');
        error.value = 'Error de sesión: No se identificó la tienda. Recargue la página.';
        return null;
      }

      // Save initial stock — product will be created with stock=0
      // then an 'entrada' movement registers the real stock via DB trigger
      const initialStock = new Decimal(productData.stock || 0);

      const newProductData = {
        ...productData,
        stock: new Decimal(0), // Start at 0, movement will set real stock
        price: priceRounded,
        createdAt: now,
        updatedAt: now,
        store_id: storeId, // For DB Compat
        storeId: storeId   // For Domain Compat
      };

      try {
        const created = await productRepository.create(newProductData);
        if (created) {
          const withDecimals = ensureDecimals(created);
          const exists = products.value.find(p => p.id === withDecimals.id);
          if (!exists) {
            products.value.push(withDecimals);
          }

          // Register initial stock as 'entrada' movement
          // The DB trigger will set current_stock to the correct value
          if (initialStock.gt(0)) {
            try {
              await productRepository.registerMovement({
                productId: withDecimals.id,
                type: 'entrada',
                quantity: initialStock.toNumber(),
                reason: 'Stock inicial al crear producto',
                storeId: storeId
              });
              // Update local state to reflect the movement
              withDecimals.stock = initialStock;
              const idx = products.value.findIndex(p => p.id === withDecimals.id);
              if (idx !== -1) {
                products.value[idx] = withDecimals;
              }
              logger.log(`[InventoryStore] Initial stock movement registered: ${initialStock} for ${withDecimals.name}`);
            } catch (movErr) {
              // Non-critical: product was created, movement is for history only
              logger.warn('[InventoryStore] Failed to register initial stock movement', movErr);
            }
          }

          return withDecimals;
        }
      } catch (e: any) {
        const errorMsg = e.message || 'Error al agregar producto';
        error.value = errorMsg;
        logger.error('[InventoryStore] Add failed', e);

        // Surface error to the user via notification
        const notificationsStore = useNotificationsStore();
        notificationsStore.addNotification({
          type: 'general',
          icon: 'error',
          title: 'Error al crear producto',
          message: errorMsg,
          isRead: false
        });
      }
      return null;
    };

    const updateProduct = async (id: string, updates: Partial<Omit<Product, 'id' | 'createdAt'>>) => {
      const index = products.value.findIndex((p) => p.id === id);
      if (index === -1) return null;

      const processedUpdates = updates.price
        ? { ...updates, price: roundHybrid50(updates.price) }
        : updates;

      const updatePayload = {
        ...processedUpdates,
        updatedAt: new Date().toISOString()
      };

      try {
        const updated = await productRepository.update(id, updatePayload as any);
        if (updated) {
          const merged = ensureDecimals({
            ...products.value[index],
            ...updated
          });
          products.value[index] = merged;
          return merged;
        }
      } catch (e: any) {
        const errorMsg = e.message || 'Error al actualizar producto';
        error.value = errorMsg;
        logger.error('[InventoryStore] Update failed', e);

        // Surface error to the user via notification
        const notificationsStore = useNotificationsStore();
        notificationsStore.addNotification({
          type: 'general',
          icon: 'error',
          title: 'Error al actualizar producto',
          message: errorMsg,
          isRead: false
        });
      }
      return null;
    };

    const deleteProduct = async (id: string) => {
      try {
        const success = await productRepository.delete(id);
        if (success) {
          const index = products.value.findIndex((p) => p.id === id);
          if (index !== -1) {
            products.value.splice(index, 1);
          }
          return true;
        }
      } catch (e) {
        logger.error('[InventoryStore] Delete failed', e);
      }
      return false;
    };

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

    const registerStockMovement = async (
      movement: {
        productId: string;
        type: 'entrada' | 'salida' | 'ajuste' | 'venta' | 'devolucion';
        quantity: number | Decimal;
        reason?: string;
        expirationDate?: string;
        unitCost?: number;
        supplierId?: string;
        invoiceRef?: string;
        paymentType?: 'contado' | 'credito';
      }
    ): Promise<{ success: boolean; product?: Product; error?: string }> => {
      const product = products.value.find((p) => p.id === movement.productId);
      if (!product) {
        return { success: false, error: 'Producto no encontrado' };
      }

      const qty = movement.quantity instanceof Decimal ? movement.quantity : new Decimal(movement.quantity);
      let newStock = product.stock;

      if (['entrada', 'devolucion', 'ajuste'].includes(movement.type)) {
        if (movement.type === 'ajuste') {
          newStock = newStock.plus(qty);
        } else {
          newStock = newStock.plus(qty);
        }
      } else if (['salida', 'venta'].includes(movement.type)) {
        newStock = newStock.minus(qty);
      }

      if (newStock.lt(0)) {
        return {
          success: false,
          error: `Stock insuficiente. Disponible: ${product.stock.toFixed(product.measurementUnit === 'un' ? 0 : 2)} ${product.measurementUnit}`,
        };
      }

      const oldStock = product.stock;
      product.stock = newStock;
      product.updatedAt = new Date().toISOString();

      try {
        let finalReason = movement.reason;
        if (movement.expirationDate) {
          finalReason = `${finalReason || ''} [Vence: ${movement.expirationDate}]`.trim();
        }

        const success = await productRepository.registerMovement({
          productId: movement.productId,
          type: movement.type,
          quantity: qty.toNumber(),
          reason: finalReason,
          supplierId: movement.supplierId,
          invoiceRef: movement.invoiceRef,
          paymentType: movement.paymentType
        });

        if (!success) {
          product.stock = oldStock;
          return { success: false, error: 'Error al registrar movimiento en repositorio' };
        }

        if (movement.type === 'entrada' && movement.unitCost !== undefined && movement.unitCost > 0) {
          const incomingCost = new Decimal(movement.unitCost);

          if (oldStock.lte(0)) {
            product.cost = incomingCost.toDecimalPlaces(2);
            try {
              logger.log(`[Inventory] FIFO: Zero stock detected. Updating Active Cost to: ${product.cost}`);
              await productRepository.update(product.id, { cost: product.cost });
            } catch (e) {
              logger.warn('Failed to update product active cost', e);
            }
          } else {
            logger.log(`[Inventory] FIFO: Stock exists (${oldStock}). New batch goes to queue. Cost remains: ${product.cost}`);
          }
        }
      } catch (e) {
        product.stock = oldStock;
        return { success: false, error: 'Excepción al registrar movimiento' };
      }

      if (!isSupabaseConfigured() && movement.type === 'entrada' && movement.unitCost !== undefined) {
        try {
          const { useBatchStore } = await import('./batches');
          const batchStore = useBatchStore();

          batchStore.addLocalBatch({
            product_id: movement.productId,
            quantity_initial: qty.toNumber(),
            cost_unit: movement.unitCost
          });
          logger.log('[Inventory] Simulated Local Batch creation in Audit Mode');
        } catch (err) {
          logger.warn('[Inventory] Failed to simulate local batch', err);
        }
      }

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

      if (product.stock.gte(product.minStock) && product.notifiedLowStock) {
        product.notifiedLowStock = false;
      }

      return { success: true, product };
    };

    onUnmounted(() => {
      unsubscribeRealtime();
    });

    const adjustStockLocal = (productId: string, delta: number | Decimal) => {
      const product = products.value.find((p) => p.id === productId);
      if (!product) return;

      const deltaDecimal = delta instanceof Decimal ? delta : new Decimal(delta);
      product.stock = product.stock.plus(deltaDecimal);
      product.updatedAt = new Date().toISOString();
    };

    return {
      products,
      isLoading,
      error,
      initialized,
      totalProducts,
      lowStockProducts,
      productsByCategory,
      initialize,
      addProduct,
      updateProduct,
      deleteProduct,
      getProductById,
      getProductByPLU,
      searchProducts,
      registerStockMovement,
      adjustStockLocal,
    };
  },
  {
    persist: {
      key: 'tienda-inventory',
      serializer: {
        serialize: (state: any) => {
          const { inventorySerializer } = require('../data/serializers/inventorySerializer');
          return inventorySerializer.serialize(state);
        },
        deserialize: (value: string) => {
          const { inventorySerializer } = require('../data/serializers/inventorySerializer');
          return inventorySerializer.deserialize(value);
        },
      },
    },
  },
);

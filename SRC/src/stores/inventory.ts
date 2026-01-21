import { defineStore } from 'pinia';
import { ref, computed, onUnmounted } from 'vue';
import { Decimal } from 'decimal.js';
import { useNotificationsStore } from './notificationsStore';
import type { Product } from '../types';
import { productRepository } from '../data/repositories/productRepository';
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
    let realtimeSubscription: RealtimeChannel | null = null;

    // Computed
    const totalProducts = computed(() => products.value.length);
    const lowStockProducts = computed(() => products.value.filter((p) => p.stock.lte(p.minStock)));

    // Helper to ensure Decimal types after loading from raw JSON/Repo
    const ensureDecimals = (product: any): Product => {
      return {
        ...product,
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

      // let filter = `store_id=eq.${storeId}`; // This filter would need to be applied to the channel or the payload
      // If storeId is not provided, we might want to be careful or subscribe to everything logic permits
      // For now assuming storeId is available or we subscribe to global changes if RLS allows

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

      if (eventType === 'INSERT') {
        const exists = products.value.find(p => p.id === newRecord.id);
        if (!exists) {
          products.value.push(ensureDecimals(newRecord));
        }
      } else if (eventType === 'UPDATE') {
        const index = products.value.findIndex(p => p.id === newRecord.id);
        if (index !== -1) {
          // Merge to preserve optimistic updates or local state if conflicts
          // For "Server Wins" strategy (WO-003), we blindly accept server state
          products.value[index] = ensureDecimals(newRecord);
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
      if (initialized.value && products.value.length > 0) return;

      isLoading.value = true;
      try {
        const rawProducts = await productRepository.getAll(storeId);
        products.value = rawProducts.map(ensureDecimals);

        // Setup realtime if available
        if (isSupabaseConfigured()) {
          setupRealtimeSubscription(storeId);
        }

        initialized.value = true;
      } catch (e: any) {
        error.value = e.message || 'Error loading products';
        logger.error('[InventoryStore] Init failed', e);
      } finally {
        isLoading.value = false;
      }
    };

    const addProduct = async (productData: Omit<Product, 'id' | 'createdAt' | 'updatedAt'>) => {
      const now = new Date().toISOString();
      // Generate ID client-side even for Supabase to ensure optimistic UI
      // But let repository handle actual creation logic if needed
      // Actually repository generic create expects Omit<T,'id'> but we are using string UUIDs
      // The generic adapter handles ID generation if missing for localStorage

      const priceRounded = roundHybrid50(productData.price);

      const newProductData = {
        ...productData,
        price: priceRounded,
        createdAt: now,
        updatedAt: now,
      };

      try {
        // Optimistic UI update could happen here, but for creation we wait for repo in WO-002
        const created = await productRepository.create(newProductData);
        if (created) {
          const withDecimals = ensureDecimals(created);
          // Check if already added by realtime (race condition)
          const exists = products.value.find(p => p.id === withDecimals.id);
          if (!exists) {
            products.value.push(withDecimals);
          }
          return withDecimals;
        }
      } catch (e: any) {
        error.value = 'Failed to add product';
        logger.error('[InventoryStore] Add failed', e);
      }
      return null;
    };

    const updateProduct = async (id: string, updates: Partial<Omit<Product, 'id' | 'createdAt'>>) => {
      const index = products.value.findIndex((p) => p.id === id);
      if (index === -1) return null;

      // SPEC-010: Si se actualiza el precio, forzar redondeo
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
          // Realtime might update it too, but we update local state immediately
          const merged = ensureDecimals({
            ...products.value[index],
            ...updated
          });
          products.value[index] = merged;
          return merged;
        }
      } catch (e) {
        logger.error('[InventoryStore] Update failed', e);
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

    const updateStock = async (
      id: string,
      quantity: number | Decimal,
    ): Promise<{ success: boolean; product?: Product; error?: string }> => {
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

      // Optimistic Update
      const oldStock = product.stock;
      product.stock = newStock;
      product.updatedAt = new Date().toISOString();

      try {
        // Send update to repo (async)
        // Note: repository updateStock logic might vary, here we send the absolute value usually?
        // Repository generic update expects the partial object.
        // ProductRepository has a specific `updateStock` but let's stick to standard update for now
        // unless we want to use the specific one which might use RPC.
        // For now, simple update is enough for WO-002
        const success = await productRepository.update(id, {
          stock: newStock, // Decimal will be serialized by adapter/supabase
          updatedAt: product.updatedAt
        } as any);

        if (!success) {
          // Rollback on failure
          product.stock = oldStock;
          return { success: false, error: 'Error al guardar stock' };
        }
      } catch (e) {
        product.stock = oldStock;
        return { success: false, error: 'Excepción al guardar stock' };
      }

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

    // Cleanup on unmount (if component context)
    onUnmounted(() => {
      unsubscribeRealtime();
    });

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
      updateStock,
    };
  },
);

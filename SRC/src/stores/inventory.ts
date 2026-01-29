import { defineStore } from 'pinia';
import { ref, computed, onUnmounted } from 'vue';
import { Decimal } from 'decimal.js';
import { useNotificationsStore } from './notificationsStore';
import { useAuthStore } from './auth';
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

      const authStore = useAuthStore();
      const effectiveStoreId = storeId || authStore.currentUser?.storeId;

      isLoading.value = true;
      try {
        const rawProducts = await productRepository.getAll(effectiveStoreId);
        products.value = rawProducts.map(ensureDecimals);

        // Setup realtime if available
        if (isSupabaseConfigured()) {
          setupRealtimeSubscription(effectiveStoreId);
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

      const authStore = useAuthStore();
      const newProductData = {
        ...productData,
        price: priceRounded,
        createdAt: now,
        updatedAt: now,
        store_id: authStore.currentUser?.storeId,
        storeId: authStore.currentUser?.storeId
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

    const registerStockMovement = async (
      movement: {
        productId: string;
        type: 'entrada' | 'salida' | 'ajuste' | 'venta' | 'devolucion';
        quantity: number | Decimal;
        reason?: string;
        expirationDate?: string;
        unitCost?: number; // New param
      }
    ): Promise<{ success: boolean; product?: Product; error?: string }> => {
      const product = products.value.find((p) => p.id === movement.productId);
      if (!product) {
        return { success: false, error: 'Producto no encontrado' };
      }

      const qty = movement.quantity instanceof Decimal ? movement.quantity : new Decimal(movement.quantity);
      let newStock = product.stock;

      // Calculate new stock based on type
      if (['entrada', 'devolucion', 'ajuste'].includes(movement.type)) {
        // Ajuste logic matches DB trigger: addition (signed logic if needed, but here usually positive for entry)
        // IF type is adjustment, user should provide signed value OR type handled differently?
        // For simplicity and matching trigger: Ajuste is ADDED. If user wants to reduce, they use AJUSTE NEGATIVO?
        // No, usually "Quantity" is absolute.
        // DB Trigger: ELSIF NEW.movement_type = 'ajuste' THEN UPDATE SET current_stock = current_stock + NEW.quantity;
        // IF UI provides 'Ajuste Negativo' (via reason), type is still 'ajuste'? 
        // WO-201 says: StockEntryView handles Entradas/Salidas/Ajustes.
        // T1.2: "Lógica de movimientos".

        // Let's assume quantity is absolute.
        // If type is 'salida' or 'venta', we subtract.
        // If type is 'entrada', 'devolucion', 'ajuste', we add? 
        // Wait, 'ajuste' usually implies setting to a value or adding a delta. 
        // If kardex stores movement, it stores the DELTA usually.
        // Let's assume input quantity is always POSITIVE in UI usually.

        if (movement.type === 'ajuste') {
          // For safety, let's treat 'ajuste' as a delta.
          // If from UI "Ajuste" usually implies Correction.
          // If logic is "Set to X", we calculate delta.
          // But here we receive "quantity".
          // Let's assume it's a delta.
          newStock = newStock.plus(qty);
        } else {
          newStock = newStock.plus(qty);
        }
      } else if (['salida', 'venta'].includes(movement.type)) {
        newStock = newStock.minus(qty);
      }

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
        let finalReason = movement.reason;
        if (movement.expirationDate) {
          finalReason = `${finalReason || ''} [Vence: ${movement.expirationDate}]`.trim();
        }

        const success = await productRepository.registerMovement({
          productId: movement.productId,
          type: movement.type,
          quantity: qty.toNumber(), // Convert to number for DB/JSON
          reason: finalReason
        });

        if (!success) {
          product.stock = oldStock;
          return { success: false, error: 'Error al registrar movimiento en repositorio' };
        }

        // T-002: FIFO Active Cost Update (Replacing WAC)
        // Logic: We only update the product 'cost' if this new batch becomes the ACTIVE batch.
        // This happens if the product was previously out of stock (or negative).
        // If we already have stock (oldStock > 0), this new batch goes to the back of the queue,
        // so the 'Reference Cost' (Next to Sell) remains the OLD cost.

        // We already have 'oldStock' calculated above.
        // Note: 'oldStock' here is the stock BEFORE this movement.

        if (movement.type === 'entrada' && movement.unitCost !== undefined && movement.unitCost > 0) {
          const incomingCost = new Decimal(movement.unitCost);

          // If we had no stock before, this new batch is now the "Active" one.
          // Update the display cost to match this batch.
          if (oldStock.lte(0)) { // Less than or Equal to 0
            product.cost = incomingCost.toDecimalPlaces(2);

            // Persist cost update (if offline, this helps UI. If online, Trigger handles it too but no harm sending it)
            // Actually, if online, the Trigger in DB will authoritative update it.
            // Sending it here ensures Optimistic UI is correct immediately.
            try {
              // Only send update if we are purely local or want to force it. 
              // Repository 'registerMovement' just records movement. 
              // We might need to explicitly update product cost if repo doesn't do it automatically via trigger return?
              // Realtime subscription will handle the Trigger update coming back from DB.
              // So this local update is primarily for Optimistic UI and Offline mode.
              logger.log(`[Inventory] FIFO: Zero stock detected. Updating Active Cost to: ${product.cost}`);
              await productRepository.update(product.id, { cost: product.cost });
            } catch (e) {
              logger.warn('Failed to update product active cost', e);
            }
          } else {
            logger.log(`[Inventory] FIFO: Stock exists (${oldStock}). New batch goes to queue. Cost remains: ${product.cost}`);
            // Do NOT update cost. It remains the cost of the older active batch.
          }
        }
      } catch (e) {
        product.stock = oldStock;
        return { success: false, error: 'Excepción al registrar movimiento' };
      }

      // 🛡️ Audit Mode / Offline Simulation: Create Local Batch
      // SPEC-010: If we are offline, we simulate the batch creation so user sees "traceability"
      if (!isSupabaseConfigured() && movement.type === 'entrada' && movement.unitCost !== undefined) {
        try {
          // Dynamic import to avoid circular dependency at top level if any
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

      if (product.stock.gte(product.minStock) && product.notifiedLowStock) {
        product.notifiedLowStock = false;
      }

      return { success: true, product };
    };

    // Cleanup on unmount (if component context)
    onUnmounted(() => {
      unsubscribeRealtime();
    });

    // OPTIMISTIC ONLY: Update stock locally without DB calls
    // Used when another process (like Sale RPC) handles the DB persistence
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
);

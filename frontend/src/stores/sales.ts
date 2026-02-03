import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';
import { salesSerializer } from '../data/serializers';
import { getStorageKey } from '../utils/storage';
import { generateUUID } from '../utils/uuid';
import type { Sale } from '../types';
import { useCashRegisterStore } from './cashRegister';
import { useAuthStore } from './auth';

export interface DailyStats {
  date: string;
  totalSales: Decimal;
  salesCount: number;
  cashSales: Decimal;
  nequiSales: Decimal;
  fiadoSales: Decimal;
}

export const useSalesStore = defineStore(
  'sales',
  () => {
    const sales = ref<Sale[]>([]);
    const nextTicketNumber = ref(1); // WO-001: Changed from nextId to nextTicketNumber
    // WO-006: Track loaded store to prevent data cross-contamination
    const loadedStoreId = ref<string | null>(null);

    // const isStoreOpen = ref(false); // REMOVED: Managed by storeStatus
    // const openingCash = ref<Decimal>(new Decimal(0)); // REMOVED: Managed by storeStatus

    // Dependencies
    const cashRegisterStore = useCashRegisterStore();
    const authStore = useAuthStore();

    // Computed Properties delegating to CashRegister
    const isStoreOpen = computed(() => cashRegisterStore.isOpen);

    // Convert openingAmount (number) to Decimal for consistency
    const openingCash = computed(() => {
      return cashRegisterStore.currentSession
        ? new Decimal(cashRegisterStore.currentSession.openingBalance)
        : new Decimal(0);
    });

    const todayDate = computed(() => {
      const now = new Date();
      return now.toISOString().split('T')[0];
    });

    const todaySales = computed(() => {
      return sales.value.filter((sale) => sale.date === todayDate.value);
    });

    // Moved todayCash definition UP so currentCash can use it
    const todayCash = computed(() => {
      return todaySales.value
        .filter((sale) => sale.paymentMethod === 'cash')
        .reduce((acc, sale) => acc.plus(sale.effectiveTotal), new Decimal(0));
    });

    // Current Cash = Opening + Today Cash Sales
    // Note: This does not subtract expenses. Expenses are handled in CashControl for audit.
    // If we want "Current Drawer Balance", we might want to subtract expenses here.
    // But logically "Sales Store" tracks Sales. Expenses store tracks Expenses.
    // "CashControl" aggregates them.
    // However, for POS display "Caja Real", usually we want (Base + Ven - Gas).
    // Let's import expensesStore too?
    // Or just (Base + Ven) as "Gross Cash". 
    // The previous implementation was accumulating.
    // Let's stick to (Base + Ven) here to avoid circular dep with expenses if possible.
    const currentCash = computed(() => {
      return openingCash.value.plus(todayCash.value);
    });

    const todayTotal = computed(() => {
      return todaySales.value.reduce((acc, sale) => acc.plus(sale.total), new Decimal(0));
    });

    const todayCount = computed(() => todaySales.value.length);

    // todayCash REMOVED from here as it was moved up


    const todayNequi = computed(() => {
      return todaySales.value
        .filter((sale) => sale.paymentMethod === 'nequi')
        .reduce((acc, sale) => acc.plus(sale.effectiveTotal), new Decimal(0));
    });

    const todayFiado = computed(() => {
      return todaySales.value
        .filter((sale) => sale.paymentMethod === 'fiado')
        .reduce((acc, sale) => acc.plus(sale.effectiveTotal), new Decimal(0));
    });

    const todayFiadoCount = computed(() => {
      return todaySales.value.filter((sale) => sale.paymentMethod === 'fiado').length;
    });

    const totalFiado = computed(() => {
      return sales.value
        .filter((sale) => sale.paymentMethod === 'fiado')
        .reduce((acc, sale) => acc.plus(sale.effectiveTotal), new Decimal(0));
    });

    // Get sales by date range
    const getSalesByDateRange = (startDate: string, endDate: string) => {
      return sales.value.filter((sale) => sale.date >= startDate && sale.date <= endDate);
    };

    // Get daily stats for a date range
    const getDailyStats = (startDate: string, endDate: string): DailyStats[] => {
      const salesInRange = getSalesByDateRange(startDate, endDate);
      const statsByDate: Record<string, DailyStats> = {};

      salesInRange.forEach((sale) => {
        if (!statsByDate[sale.date]) {
          statsByDate[sale.date] = {
            date: sale.date,
            totalSales: new Decimal(0),
            salesCount: 0,
            cashSales: new Decimal(0),
            nequiSales: new Decimal(0),
            fiadoSales: new Decimal(0),
          };
        }

        const stats = statsByDate[sale.date];
        stats.totalSales = stats.totalSales.plus(sale.total);
        stats.salesCount++;

        // Helper to add to stats
        const addToStats = (method: string, amount: Decimal) => {
          if (method === 'cash') stats.cashSales = stats.cashSales.plus(amount);
          else if (method === 'nequi') stats.nequiSales = stats.nequiSales.plus(amount);
          else if (method === 'fiado') stats.fiadoSales = stats.fiadoSales.plus(amount);
        };

        if (sale.paymentMethod === 'mixed' && sale.payments) {
          sale.payments.forEach(p => addToStats(p.method, p.amount));
        } else {
          addToStats(sale.paymentMethod, sale.effectiveTotal);
        }
      });

      return Object.values(statsByDate).sort((a, b) => b.date.localeCompare(a.date));
    };

    // Methods
    const initialize = async () => {
      const storeId = authStore.currentUser?.storeId;
      if (!storeId) return;

      // WO-006: Reset state if switching stores
      if (loadedStoreId.value && loadedStoreId.value !== storeId) {
        sales.value = [];
        nextTicketNumber.value = 1;
      }
      loadedStoreId.value = storeId;

      // 1. Fetch Last Ticket Number (Online/Offline resilient)
      const { saleRepository } = await import('../data/repositories/saleRepository');
      const lastTicket = await saleRepository.getLastTicketNumber(storeId);
      if (lastTicket > 0) {
        nextTicketNumber.value = lastTicket + 1;
      }

      // 2. Fetch Today's Sales (Hydrate UI)
      try {
        const today = new Date().toISOString().split('T')[0];
        // Fetch sales for today (UTC date string, handled by repo)
        // Ideally should match local time date string if repo supports it
        // For now, assume repo mapper handles it or we filter client side
        const remoteSales = await saleRepository.getByDateRange(today, today, storeId);

        // Merge with existing (if any) to avoid overwrite if persisted
        const existingIds = new Set(sales.value.map(s => s.id));
        remoteSales.forEach(s => {
          if (!existingIds.has(s.id)) {
            sales.value.push(s);
          }
        });

        // Re-sort
        sales.value.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());

      } catch (e) {
        console.warn('Failed to load today sales', e);
      }

      // 3. Load Pending Sales
      try {
        const { getPendingSales } = await import('../data/syncQueue');
        const pendingPayloads = await getPendingSales();
        // ... (existing pending logic) ... 
        if (pendingPayloads.length > 0) {
          const mappedPending = pendingPayloads.map((p, index) => {
            const tempId = `audit-pending-${p.timestamp}`;
            return {
              id: tempId,
              ticketNumber: nextTicketNumber.value + index, // Estimate ticket for pending
              timestamp: new Date(p.timestamp).toISOString(),
              date: new Date(p.timestamp).toISOString().split('T')[0],
              items: p.items.map((i: any) => ({ ...i, price: new Decimal(i.price), subtotal: new Decimal(i.subtotal) })),
              total: new Decimal(p.total),
              effectiveTotal: new Decimal(p.total),
              paymentMethod: p.paymentMethod,
              payments: p.payments ? p.payments.map((pay: any) => ({ ...pay, amount: new Decimal(pay.amount) })) : [],
              syncStatus: 'pending',
              client: undefined
            } as Sale;
          });

          const currentIds = new Set(sales.value.map(s => s.timestamp));
          mappedPending.forEach(pendingSale => {
            const isDupe = sales.value.some(s => Math.abs(new Date(s.timestamp).getTime() - new Date(pendingSale.timestamp).getTime()) < 100);
            if (!isDupe) sales.value.push(pendingSale);
          });
          sales.value.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());
        }
      } catch (e) {
        console.warn('Failed to load pending sales', e);
      }
    };

    // WO-001: Changed to use UUID and ticketNumber
    // T2.1/T2.2: Use SaleRepository and update inventory
    const addSale = async (saleData: Omit<Sale, 'id' | 'ticketNumber' | 'timestamp' | 'date'>) => {
      const now = new Date();
      // Generate ID client-side for UI even if repo generates one
      const tempId = generateUUID();
      const ticketNum = nextTicketNumber.value; // Store current expectation

      const newSale: Sale = {
        ...saleData,
        id: tempId,
        ticketNumber: ticketNum,
        timestamp: now.toISOString(),
        date: now.toISOString().split('T')[0],
        syncStatus: 'synced', // Optimistic, will rely on repo response or sync queue
      };

      // 1. Process via Repository (Online RPC or Offline Queue)
      // Import dynamically to avoid circular dependencies if any, or static import better
      const { saleRepository } = await import('../data/repositories/saleRepository');
      // Construct payload expected by repository (simplified structure usually)
      const repoPayload = {
        items: saleData.items.map(item => {
          // STRICT VALIDATION: Reject "N/A" or invalid numbers at the source
          const q = Number(item.quantity);
          const p = item.price instanceof Decimal ? item.price.toNumber() : Number(item.price);
          const s = item.subtotal instanceof Decimal ? item.subtotal.toNumber() : Number(item.subtotal);

          if (!Number.isFinite(q) || q <= 0) {
            throw new Error(`Data Corruption Detected: Item "${item.productName}" has invalid quantity: ${item.quantity}`);
          }
          if (!Number.isFinite(p)) {
            throw new Error(`Data Corruption Detected: Item "${item.productName}" has invalid price: ${item.price}`);
          }

          return {
            productId: item.productId,
            productName: item.productName,
            quantity: q,
            price: p,
            subtotal: s,
          };
        }),
        total: saleData.total instanceof Decimal ? saleData.total.toNumber() : Number(saleData.total),
        paymentMethod: saleData.paymentMethod,
        payments: saleData.payments?.map(p => ({
          method: p.method,
          amount: p.amount.toNumber(),
          reference: p.reference
        })),
        amountReceived: saleData.amountReceived ? (saleData.amountReceived instanceof Decimal ? saleData.amountReceived.toNumber() : Number(saleData.amountReceived)) : undefined,
        // FIX: Explicitly handle "N/A" string which defaults to "N/A" with || operator
        clientId: (saleData.clientId && saleData.clientId !== 'N/A') ? saleData.clientId : null,
        // FIX: Prioritize employeeId (UUID) or fallback to id (UUID from admin), ensuring no "emp-" or "N/A" junk
        employeeId: (saleData.employeeId && saleData.employeeId.length > 10 && saleData.employeeId !== 'N/A') ? saleData.employeeId : null
      };

      const storeId = authStore.currentUser?.storeId;
      if (!storeId) throw new Error("Store ID not found in session");
      const result = await saleRepository.processSale(repoPayload, storeId);

      if (!result.success) {
        console.error('Sale processing failed:', result.error);
        // Depending on requirements, we might throw or add 'failed' status
        // For now, consistent with "Offline First", we assume queueing counts as success if result.success is true
        // If result.success is false here it means HARD failure (e.g. queue full)
        throw new Error(result.error);
      }

      // If repo returned success:
      // 1. If backend gave authoritative ticket number, use it.
      if (result.ticketNumber) {
        newSale.ticketNumber = result.ticketNumber;
        nextTicketNumber.value = result.ticketNumber + 1; // Update counter for next one
      } else {
        // Offline or legacy, use optimistic and increment
        nextTicketNumber.value++;
      }

      // 2. If backend gave authoritative ID, use it!
      // CRITICAL FIX: We MUST use the ID generated by the DB for FK relations (like Debt)
      if (result.id) {
        newSale.id = result.id;
      }

      sales.value.push(newSale);

      // 2. Update Cash Drawer (Local State)
      // No longer needed to manually update currentCash as it is computed from sales


      // 3. Update Inventory (Local Optimistic)
      const { useInventoryStore } = await import('./inventory');
      const inventoryStore = useInventoryStore();

      newSale.items.forEach(item => {
        // Decrease stock locally
        inventoryStore.adjustStockLocal(item.productId, new Decimal(item.quantity).neg());
      });

      // 4. Update Client Debt (Fiado)
      // FRD-011: Error handling - show warning if transaction record fails but don't block sale
      if (newSale.paymentMethod === 'fiado' && newSale.clientId) {
        try {
          const { useClientsStore } = await import('./clients');
          const clientsStore = useClientsStore();

          // Add debt to client
          await clientsStore.addPurchaseDebt(
            newSale.clientId,
            newSale.total instanceof Decimal ? newSale.total : new Decimal(newSale.total),
            `Compra Ticket #${newSale.ticketNumber}`,
            newSale.id
          );
        } catch (debtError: any) {
          console.warn('[SalesStore] Error registering client debt transaction:', debtError);
          // FRD-011: Show comprehensible message to user
          // The sale was processed, debt was updated, but transaction history may be incomplete
          const { useNotifications } = await import('../composables/useNotifications');
          const { showWarning } = useNotifications();
          showWarning('Deuda registrada. El historial se sincronizará cuando haya conexión.');
          // Don't throw - the sale itself was successful
        }
      }

      return newSale;
    };

    // WO-001: Changed parameter type from number to string
    const getSaleById = (id: string) => {
      return sales.value.find((sale) => sale.id === id);
    };

    // WO-001: New function to find by ticket number (for UI)
    const getSaleByTicketNumber = (ticketNumber: number) => {
      return sales.value.find((sale) => sale.ticketNumber === ticketNumber);
    };

    return {
      sales,
      nextTicketNumber, // WO-001: Renamed from nextId
      isStoreOpen,
      openingCash,
      currentCash,
      todayDate,
      todaySales,
      todayTotal,
      todayCount,
      todayCash,
      todayNequi,
      todayFiado,
      todayFiadoCount,
      totalFiado,
      getSalesByDateRange,
      getDailyStats,
      initialize,
      // openStore, // REMOVED
      // closeStore, // REMOVED
      addSale,
      getSaleById,
      getSaleByTicketNumber, // WO-001: New function
    };
  },
  {

    persist: {
      key: getStorageKey('tienda-sales'),
      storage: localStorage,
      serializer: salesSerializer,
    },
  },
);

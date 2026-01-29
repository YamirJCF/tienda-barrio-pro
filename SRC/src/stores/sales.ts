import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';
import { salesSerializer } from '../data/serializers';
import { getStorageKey } from '../utils/storage';
import { generateUUID } from '../utils/uuid';
import type { Sale } from '../types';
import { useCashRegisterStore } from './cashRegister';

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
    // const isStoreOpen = ref(false); // REMOVED: Managed by storeStatus
    // const openingCash = ref<Decimal>(new Decimal(0)); // REMOVED: Managed by storeStatus

    // Dependencies
    const cashRegisterStore = useCashRegisterStore();

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
    // openStore and closeStore REMOVED - Managed by StoreStatus / CashControlView


    // WO-001: Changed to use UUID and ticketNumber
    // T2.1/T2.2: Use SaleRepository and update inventory
    const addSale = async (saleData: Omit<Sale, 'id' | 'ticketNumber' | 'timestamp' | 'date'>) => {
      const now = new Date();
      // Generate ID client-side for UI even if repo generates one
      const tempId = generateUUID();
      const ticketNum = nextTicketNumber.value++;

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
      // Construct payload expected by repository (simplified structure usually)
      const repoPayload = {
        items: saleData.items.map(item => ({
          productId: item.productId,
          productName: item.productName,
          quantity: typeof item.quantity === 'number' ? item.quantity : Number(item.quantity),
          price: item.price instanceof Decimal ? item.price.toNumber() : Number(item.price),
          subtotal: item.subtotal instanceof Decimal ? item.subtotal.toNumber() : Number(item.subtotal),
        })),
        total: saleData.total instanceof Decimal ? saleData.total.toNumber() : Number(saleData.total),
        paymentMethod: saleData.paymentMethod,
        payments: saleData.payments?.map(p => ({
          method: p.method,
          amount: p.amount.toNumber(),
          reference: p.reference
        })),
        amountReceived: saleData.amountReceived ? (saleData.amountReceived instanceof Decimal ? saleData.amountReceived.toNumber() : Number(saleData.amountReceived)) : undefined,
        clientId: saleData.clientId,
        employeeId: saleData.employeeId
      };

      const result = await saleRepository.processSale(repoPayload, 'default-store'); // Store ID hardcoded for now

      if (!result.success) {
        console.error('Sale processing failed:', result.error);
        // Depending on requirements, we might throw or add 'failed' status
        // For now, consistent with "Offline First", we assume queueing counts as success if result.success is true
        // If result.success is false here it means HARD failure (e.g. queue full)
        throw new Error(result.error);
      }

      // If repo returned a real ID (online), update it? 
      // Usually keep the UUID we generated to assume consistency, unless repo enforces ID.
      // With our UUID policy, we are safe.

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

import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { Decimal } from 'decimal.js';
import { salesSerializer } from '../data/serializers';

export interface Sale {
    id: number;
    items: SaleItem[];
    total: Decimal;
    paymentMethod: 'cash' | 'nequi' | 'fiado';
    amountReceived?: Decimal;
    change?: Decimal;
    clientId?: number; // For fiado payments
    timestamp: string;
    date: string; // YYYY-MM-DD for grouping
}

export interface SaleItem {
    productId: number;
    productName: string;
    quantity: number;
    price: Decimal;
    subtotal: Decimal;
}

export interface DailyStats {
    date: string;
    totalSales: Decimal;
    salesCount: number;
    cashSales: Decimal;
    nequiSales: Decimal;
    fiadoSales: Decimal;
}

export const useSalesStore = defineStore('sales', () => {
    const sales = ref<Sale[]>([]);
    const nextId = ref(1);
    const isStoreOpen = ref(false);
    const openingCash = ref<Decimal>(new Decimal(0));
    const currentCash = ref<Decimal>(new Decimal(0));

    // Computed
    const todayDate = computed(() => {
        const now = new Date();
        return now.toISOString().split('T')[0];
    });

    const todaySales = computed(() => {
        return sales.value.filter(sale => sale.date === todayDate.value);
    });

    const todayTotal = computed(() => {
        return todaySales.value.reduce((acc, sale) => acc.plus(sale.total), new Decimal(0));
    });

    const todayCount = computed(() => todaySales.value.length);

    const todayCash = computed(() => {
        return todaySales.value
            .filter(sale => sale.paymentMethod === 'cash')
            .reduce((acc, sale) => acc.plus(sale.total), new Decimal(0));
    });

    const todayNequi = computed(() => {
        return todaySales.value
            .filter(sale => sale.paymentMethod === 'nequi')
            .reduce((acc, sale) => acc.plus(sale.total), new Decimal(0));
    });

    const todayFiado = computed(() => {
        return todaySales.value
            .filter(sale => sale.paymentMethod === 'fiado')
            .reduce((acc, sale) => acc.plus(sale.total), new Decimal(0));
    });

    const totalFiado = computed(() => {
        return sales.value
            .filter(sale => sale.paymentMethod === 'fiado')
            .reduce((acc, sale) => acc.plus(sale.total), new Decimal(0));
    });

    // Get sales by date range
    const getSalesByDateRange = (startDate: string, endDate: string) => {
        return sales.value.filter(sale =>
            sale.date >= startDate && sale.date <= endDate
        );
    };

    // Get daily stats for a date range
    const getDailyStats = (startDate: string, endDate: string): DailyStats[] => {
        const salesInRange = getSalesByDateRange(startDate, endDate);
        const statsByDate: Record<string, DailyStats> = {};

        salesInRange.forEach(sale => {
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

            if (sale.paymentMethod === 'cash') {
                stats.cashSales = stats.cashSales.plus(sale.total);
            } else if (sale.paymentMethod === 'nequi') {
                stats.nequiSales = stats.nequiSales.plus(sale.total);
            } else if (sale.paymentMethod === 'fiado') {
                stats.fiadoSales = stats.fiadoSales.plus(sale.total);
            }
        });

        return Object.values(statsByDate).sort((a, b) => b.date.localeCompare(a.date));
    };

    // Methods
    const openStore = (cashAmount: Decimal) => {
        isStoreOpen.value = true;
        openingCash.value = cashAmount;
        currentCash.value = cashAmount;
    };

    const closeStore = () => {
        isStoreOpen.value = false;
        openingCash.value = new Decimal(0);
        currentCash.value = new Decimal(0);
    };

    const addSale = (saleData: Omit<Sale, 'id' | 'timestamp' | 'date'>) => {
        const now = new Date();
        const newSale: Sale = {
            ...saleData,
            id: nextId.value++,
            timestamp: now.toISOString(),
            date: now.toISOString().split('T')[0],
        };

        sales.value.push(newSale);

        // Update current cash if cash payment
        if (newSale.paymentMethod === 'cash') {
            currentCash.value = currentCash.value.plus(newSale.total);
        }

        return newSale;
    };

    const getSaleById = (id: number) => {
        return sales.value.find(sale => sale.id === id);
    };

    return {
        sales,
        nextId,
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
        totalFiado,
        getSalesByDateRange,
        getDailyStats,
        openStore,
        closeStore,
        addSale,
        getSaleById,
    };
}, {
    persist: {
        key: 'tienda-sales',
        storage: localStorage,
        serializer: salesSerializer,
    },
});


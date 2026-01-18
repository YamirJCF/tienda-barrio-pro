<script setup lang="ts">
/**
 * SPEC-009: Vista de Historiales
 * Muestra el historial de entradas de stock y cierres de caja
 */
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useStockEntriesStore, type StockEntry } from '../stores/stockEntries';
import { useCashClosesStore, type CashClose } from '../stores/cashCloses';
import { formatRelativeTime } from '../composables/useRelativeTime';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import BottomNav from '../components/BottomNav.vue';

const router = useRouter();
const stockEntriesStore = useStockEntriesStore();
const cashClosesStore = useCashClosesStore();
const { formatCurrency } = useCurrencyFormat();

// State
const activeTab = ref<'stock' | 'cash'>('stock');

// Computed
const stockEntries = computed(() => stockEntriesStore.entriesByDate);
const cashCloses = computed(() => cashClosesStore.closesByDate);
const hasStockEntries = computed(() => stockEntries.value.length > 0);
const hasCashCloses = computed(() => cashCloses.value.length > 0);

// Methods
const goBack = () => {
    router.back();
};

const getEntryTypeLabel = (type: StockEntry['type']) => {
    const labels = {
        purchase: 'Compra',
        sale: 'Venta',
        adjustment: 'Ajuste',
        return: 'Devolución',
        loss: 'Pérdida',
    };
    return labels[type] || type;
};

const getEntryTypeColor = (type: StockEntry['type']) => {
    const colors = {
        purchase: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
        sale: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400',
        adjustment: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400',
        return: 'bg-purple-100 text-purple-700 dark:bg-purple-900/30 dark:text-purple-400',
        loss: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400',
    };
    return colors[type] || 'bg-gray-100 text-gray-700';
};

const getDifferenceClass = (difference: number) => {
    if (difference > 0) return 'text-green-600';
    if (difference < 0) return 'text-red-600';
    return 'text-slate-500';
};
</script>

<template>
    <div class="flex flex-col min-h-screen bg-background-light dark:bg-background-dark pb-24">
        <!-- Header -->
        <header
            class="sticky top-0 z-30 flex items-center justify-between px-4 py-3 bg-white dark:bg-background-dark border-b border-slate-100 dark:border-slate-800 shadow-sm">
            <button @click="goBack" aria-label="Volver"
                class="flex items-center justify-center p-2 -ml-2 rounded-full hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors text-slate-800 dark:text-white">
                <span class="material-symbols-outlined">arrow_back</span>
            </button>
            <h1 class="text-lg font-bold text-slate-900 dark:text-white">Historiales</h1>
            <div class="w-10"></div>
        </header>

        <!-- Tabs -->
        <div class="sticky top-[57px] z-20 bg-background-light dark:bg-background-dark px-4 py-3">
            <div class="flex h-11 w-full items-center justify-center rounded-xl bg-slate-200 dark:bg-slate-800 p-1">
                <button @click="activeTab = 'stock'"
                    class="flex-1 h-full rounded-lg flex items-center justify-center gap-2 text-sm font-semibold transition-all"
                    :class="activeTab === 'stock'
                        ? 'bg-white dark:bg-slate-700 shadow-sm text-primary'
                        : 'text-slate-500 dark:text-slate-400'">
                    <span class="material-symbols-outlined text-lg">inventory</span>
                    Inventario
                </button>
                <button @click="activeTab = 'cash'"
                    class="flex-1 h-full rounded-lg flex items-center justify-center gap-2 text-sm font-semibold transition-all"
                    :class="activeTab === 'cash'
                        ? 'bg-white dark:bg-slate-700 shadow-sm text-primary'
                        : 'text-slate-500 dark:text-slate-400'">
                    <span class="material-symbols-outlined text-lg">payments</span>
                    Arqueos
                </button>
            </div>
        </div>

        <!-- Content -->
        <main class="flex-1 overflow-y-auto p-4">
            <!-- Stock Entries Tab -->
            <div v-if="activeTab === 'stock'" class="space-y-3">
                <!-- Empty State -->
                <div v-if="!hasStockEntries"
                    class="flex flex-col items-center justify-center h-64 text-center opacity-60">
                    <span class="material-symbols-outlined text-6xl text-slate-300 mb-4">inventory_2</span>
                    <p class="text-lg font-bold text-slate-600 dark:text-slate-400">Sin movimientos</p>
                    <p class="text-sm text-slate-400">Los movimientos de inventario aparecerán aquí</p>
                </div>

                <!-- Stock Entry Cards -->
                <article v-for="entry in stockEntries" :key="entry.id"
                    class="bg-white dark:bg-slate-800 rounded-xl p-4 shadow-sm border border-slate-100 dark:border-slate-700">
                    <div class="flex items-start justify-between gap-3">
                        <div class="flex-1 min-w-0">
                            <div class="flex items-center gap-2 mb-1">
                                <span class="text-sm font-bold text-slate-900 dark:text-white truncate">
                                    {{ entry.productName }}
                                </span>
                                <span class="px-2 py-0.5 rounded-full text-[10px] font-semibold"
                                    :class="getEntryTypeColor(entry.type)">
                                    {{ getEntryTypeLabel(entry.type) }}
                                </span>
                            </div>
                            <p v-if="entry.reason" class="text-xs text-slate-500 dark:text-slate-400">
                                {{ entry.reason }}
                            </p>
                        </div>
                        <div class="text-right shrink-0">
                            <span class="font-bold" :class="entry.quantity > 0 ? 'text-green-600' : 'text-red-500'">
                                {{ entry.quantity > 0 ? '+' : '' }}{{ entry.quantity }}
                            </span>
                            <p class="text-xs text-slate-400">
                                {{ formatRelativeTime(entry.createdAt) }}
                            </p>
                        </div>
                    </div>
                </article>
            </div>

            <!-- Cash Closes Tab -->
            <div v-if="activeTab === 'cash'" class="space-y-3">
                <!-- Empty State -->
                <div v-if="!hasCashCloses"
                    class="flex flex-col items-center justify-center h-64 text-center opacity-60">
                    <span class="material-symbols-outlined text-6xl text-slate-300 mb-4">payments</span>
                    <p class="text-lg font-bold text-slate-600 dark:text-slate-400">Sin arqueos</p>
                    <p class="text-sm text-slate-400">Los cierres de caja aparecerán aquí</p>
                </div>

                <!-- Cash Close Cards -->
                <article v-for="close in cashCloses" :key="close.id"
                    class="bg-white dark:bg-slate-800 rounded-xl p-4 shadow-sm border border-slate-100 dark:border-slate-700">
                    <div class="flex items-center justify-between mb-3">
                        <span class="text-xs font-medium text-slate-400">
                            {{ formatRelativeTime(close.closedAt) }}
                        </span>
                        <span class="px-2 py-0.5 rounded-full text-xs font-semibold" :class="close.difference === 0
                            ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400'
                            : 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400'">
                            {{ close.difference === 0 ? 'Cuadrado' : 'Diferencia' }}
                        </span>
                    </div>
                    <div class="grid grid-cols-2 gap-3">
                        <div>
                            <p class="text-xs text-slate-400">Total Ventas</p>
                            <p class="font-bold text-slate-900 dark:text-white">
                                ${{ formatCurrency(close.totalSales) }}
                            </p>
                        </div>
                        <div>
                            <p class="text-xs text-slate-400">Diferencia</p>
                            <p class="font-bold" :class="getDifferenceClass(close.difference)">
                                {{ close.difference >= 0 ? '+' : '' }}${{ formatCurrency(close.difference) }}
                            </p>
                        </div>
                    </div>
                    <div class="mt-3 pt-3 border-t border-slate-100 dark:border-slate-700 text-xs text-slate-500">
                        {{ close.salesCount }} ventas • {{ close.closedBy || 'Admin' }}
                    </div>
                </article>
            </div>
        </main>

        <BottomNav />
    </div>
</template>

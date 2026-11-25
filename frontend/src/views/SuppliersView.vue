<template>
  <div class="flex flex-col min-h-screen bg-background-light dark:bg-background-dark pb-24">
    <header
      class="sticky top-0 z-30 bg-surface-light/95 dark:bg-surface-dark/95 backdrop-blur-sm border-b border-slate-200 dark:border-slate-800"
    >
      <div class="flex items-center px-4 pt-4 pb-3 justify-between gap-2">
        <div class="flex items-center gap-2 min-w-0">
          <button
            type="button"
            @click="goBack"
            aria-label="Volver al Panel"
            class="flex items-center justify-center -ml-2 p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer"
          >
            <ArrowLeft :size="24" :stroke-width="1.5" />
          </button>
          <div class="min-w-0">
            <h1 class="text-slate-900 dark:text-white text-lg sm:text-xl font-bold truncate">
              Proveedores y Cuentas por Pagar
            </h1>
            <p class="text-[11px] text-slate-500 dark:text-slate-400 truncate">
              Abastecimiento, facturas y abonos
            </p>
          </div>
        </div>
      </div>

      <!-- Segmented Tabs (ORCA: Proveedores | Cuentas por Pagar) -->
      <div class="px-4 pb-3">
        <div class="grid grid-cols-2 gap-1.5 p-1 rounded-xl bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-800">
          <button
            type="button"
            data-testid="tab-suppliers"
            @click="switchTab('suppliers')"
            class="py-2 px-3 rounded-lg text-xs sm:text-sm font-bold transition-colors cursor-pointer"
            :class="activeTab === 'suppliers'
              ? 'bg-primary text-white shadow-sm'
              : 'text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800'"
          >
            Proveedores
          </button>
          <button
            type="button"
            data-testid="tab-payables"
            @click="switchTab('payables')"
            class="py-2 px-3 rounded-lg text-xs sm:text-sm font-bold transition-colors cursor-pointer"
            :class="activeTab === 'payables'
              ? 'bg-primary text-white shadow-sm'
              : 'text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800'"
          >
            Cuentas por Pagar
          </button>
        </div>
      </div>
    </header>

    <main class="flex-1 px-4 py-4 max-w-4xl w-full mx-auto">
      <SupplierDirectoryTab
        v-if="activeTab === 'suppliers'"
        @view-payables="handleViewSupplierPayables"
        @retry="loadSuppliersForStore"
        @suppliers-mutated="loadSuppliersForStore"
      />

      <SupplierPayablesTab
        v-else
        :initialSupplierId="selectedSupplierFilter"
        :highlightedInvoiceId="highlightedInvoiceId"
        @supplier-filter-change="handleSupplierFilterChange"
        @invoices-mutated="loadSuppliersForStore"
      />
    </main>

    <BottomNav />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useSuppliersStore } from '@/stores/suppliers';
import { useAuthStore } from '@/stores/auth';
import BottomNav from '@/components/BottomNav.vue';
import SupplierDirectoryTab from '@/components/suppliers/SupplierDirectoryTab.vue';
import SupplierPayablesTab from '@/components/suppliers/SupplierPayablesTab.vue';
import { ArrowLeft } from 'lucide-vue-next';

type SuppliersTab = 'suppliers' | 'payables';

const route = useRoute();
const router = useRouter();
const suppliersStore = useSuppliersStore();
const authStore = useAuthStore();

const storeId = computed(() => authStore.currentUser?.storeId || authStore.currentStore?.id || '');

const resolveTabFromRoute = (): SuppliersTab => {
  if (route.path === '/payables' || route.query.tab === 'payables') {
    return 'payables';
  }
  return 'suppliers';
};

const activeTab = ref<SuppliersTab>(resolveTabFromRoute());
const selectedSupplierFilter = ref<string>(typeof route.query.supplier === 'string' ? route.query.supplier : '');
const highlightedInvoiceId = ref<string>(typeof route.query.invoice === 'string' ? route.query.invoice : '');

const normalizeAliasRoute = async () => {
  if (route.path === '/payables') {
    activeTab.value = 'payables';
    await router.replace({
      path: '/suppliers',
      query: { ...route.query, tab: 'payables' },
    });
  }
};

const loadSuppliersForStore = async () => {
  if (!storeId.value) return;
  await suppliersStore.fetchSuppliersWithPayables(storeId.value);
};

onMounted(async () => {
  await normalizeAliasRoute();
  await loadSuppliersForStore();
});

watch(
  () => [route.path, route.query.tab, route.query.supplier, route.query.invoice],
  async ([newPath, newTab, newSup, newInv]) => {
    if (newPath === '/payables') {
      await normalizeAliasRoute();
      return;
    }
    activeTab.value = newTab === 'payables' ? 'payables' : 'suppliers';
    selectedSupplierFilter.value = typeof newSup === 'string' ? newSup : '';
    highlightedInvoiceId.value = typeof newInv === 'string' ? newInv : '';
  }
);

watch(storeId, async (newId) => {
  if (newId) {
    await loadSuppliersForStore();
  }
});

const switchTab = async (tab: SuppliersTab) => {
  activeTab.value = tab;
  const nextQuery: Record<string, any> = { ...route.query, tab };
  if (tab === 'suppliers') {
    delete nextQuery.invoice;
  }
  await router.replace({ path: '/suppliers', query: nextQuery });
};

const handleViewSupplierPayables = async (supplierId: string) => {
  selectedSupplierFilter.value = supplierId;
  activeTab.value = 'payables';
  await router.replace({
    path: '/suppliers',
    query: { tab: 'payables', supplier: supplierId },
  });
};

const handleSupplierFilterChange = async (supplierId: string) => {
  selectedSupplierFilter.value = supplierId;
  if (activeTab.value !== 'payables') return;
  const nextQuery: Record<string, any> = { ...route.query, tab: 'payables' };
  if (supplierId) {
    nextQuery.supplier = supplierId;
  } else {
    delete nextQuery.supplier;
  }
  await router.replace({ path: '/suppliers', query: nextQuery });
};

const goBack = () => {
  router.push('/');
};
</script>

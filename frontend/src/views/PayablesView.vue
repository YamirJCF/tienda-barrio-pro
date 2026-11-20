<template>
  <div class="flex flex-col min-h-screen bg-background-light dark:bg-background-dark pb-24">
    <!-- Header -->
    <header class="sticky top-0 z-40 bg-background-light/95 dark:bg-background-dark/95 backdrop-blur-sm border-b border-gray-200 dark:border-gray-800 pb-2">
      <div class="flex items-center px-4 pt-4 pb-2 justify-between">
        <div class="flex items-center gap-2">
          <button
            @click="goBack"
            aria-label="Volver a Proveedores"
            class="flex items-center justify-center -ml-2 p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          >
            <ArrowLeft :size="24" :stroke-width="1.5" />
          </button>
          <h2 class="text-slate-900 dark:text-white text-xl font-bold">Cuentas por Pagar</h2>
        </div>
        <BaseButton
          v-if="authStore.isAdmin"
          size="sm"
          data-testid="open-create-invoice-btn"
          @click="openCreateModal"
        >
          <Plus :size="16" class="mr-1" />
          Nueva Factura
        </BaseButton>
      </div>
      
      <!-- Filters (Barra Pegajosa) -->
      <div class="px-4 py-2 flex flex-col gap-3">
        <!-- Supplier Select -->
        <div class="w-full">
          <select
            v-model="selectedSupplierId"
            class="block w-full rounded-xl border-gray-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-900 dark:text-white focus:ring-primary focus:border-primary sm:text-sm h-11 px-3 appearance-none"
          >
            <option value="">Todos los proveedores</option>
            <option v-for="supplier in suppliersStore.suppliers" :key="supplier.id" :value="supplier.id">
              {{ supplier.name }}
            </option>
          </select>
        </div>
        
        <!-- Status Chips -->
        <div class="flex gap-2 overflow-x-auto pb-1 hide-scrollbar">
          <button 
            @click="selectedStatus = ''"
            class="whitespace-nowrap px-4 py-1.5 rounded-full text-sm font-medium transition-colors"
            :class="selectedStatus === '' ? 'bg-slate-800 dark:bg-slate-200 text-white dark:text-slate-900' : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300'"
          >
            Todas
          </button>
          <button 
            @click="selectedStatus = 'pendiente'"
            class="whitespace-nowrap px-4 py-1.5 rounded-full text-sm font-medium transition-colors"
            :class="selectedStatus === 'pendiente' ? 'bg-amber-500 text-white' : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300'"
          >
            Pendientes
          </button>
          <button 
            @click="selectedStatus = 'vencida'"
            class="whitespace-nowrap px-4 py-1.5 rounded-full text-sm font-medium transition-colors"
            :class="selectedStatus === 'vencida' ? 'bg-red-500 text-white' : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300'"
          >
            Vencidas
          </button>
          <button 
            @click="selectedStatus = 'pagada'"
            class="whitespace-nowrap px-4 py-1.5 rounded-full text-sm font-medium transition-colors"
            :class="selectedStatus === 'pagada' ? 'bg-emerald-500 text-white' : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300'"
          >
            Pagadas
          </button>
        </div>
      </div>
    </header>

    <!-- KPI Cards -->
    <div class="px-4 py-4 grid grid-cols-2 gap-3 shrink-0">
      <div class="bg-slate-50 dark:bg-slate-800 p-4 rounded-2xl border border-slate-100 dark:border-slate-700 shadow-sm text-center flex flex-col items-center justify-center">
        <div class="flex h-10 w-10 items-center justify-center rounded-full bg-slate-200 dark:bg-slate-700 mb-2">
          <Banknote :size="20" class="text-slate-600 dark:text-slate-300" />
        </div>
        <p class="text-[10px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-1">Deuda Total</p>
        <div class="text-lg font-black text-slate-900 dark:text-white">
          <Skeleton v-if="payablesStore.isLoading" width="80px" height="24px" class="mx-auto" />
          <span v-else>{{ formatCurrency(totalDebt) }}</span>
        </div>
      </div>
      
      <div class="bg-red-50 dark:bg-red-900/20 p-4 rounded-2xl border border-red-100 dark:border-red-800/40 shadow-sm text-center flex flex-col items-center justify-center">
        <div class="flex h-10 w-10 items-center justify-center rounded-full bg-red-100 dark:bg-red-900/40 mb-2">
          <AlertTriangle :size="20" class="text-red-600 dark:text-red-400" />
        </div>
        <p class="text-[10px] font-bold text-red-600 dark:text-red-400 uppercase tracking-wider mb-1">Total Vencido</p>
        <div class="text-lg font-black text-red-700 dark:text-red-300">
          <Skeleton v-if="payablesStore.isLoading" width="80px" height="24px" class="mx-auto" />
          <span v-else>{{ formatCurrency(totalOverdue) }}</span>
        </div>
      </div>
    </div>

    <!-- Main Content -->
    <main class="flex-1 px-4 flex flex-col gap-3">
      <!-- Explicit Error State (Regla 3) -->
      <div
        v-if="payablesStore.error"
        role="alert"
        class="p-4 rounded-2xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 space-y-2"
      >
        <p class="text-sm font-semibold text-red-700 dark:text-red-300">{{ payablesStore.error }}</p>
        <BaseButton size="sm" variant="danger" @click="loadInvoicesPage(true)">Reintentar</BaseButton>
      </div>

      <!-- Loading State -->
      <template v-else-if="payablesStore.isLoading">
        <div v-for="i in 3" :key="i" class="bg-white dark:bg-slate-800 rounded-2xl shadow-sm p-4 border-l-[6px] border-slate-200 dark:border-slate-700">
          <div class="flex justify-between mb-3">
            <Skeleton width="120px" height="16px" />
            <Skeleton width="80px" height="16px" />
          </div>
          <div class="mb-4">
            <Skeleton width="60%" height="24px" />
          </div>
          <div class="flex justify-between items-center">
            <Skeleton width="60px" height="20px" border-radius="999px" />
            <Skeleton width="80px" height="32px" border-radius="8px" />
          </div>
        </div>
      </template>

      <!-- Invoices List -->
      <template v-else-if="filteredInvoices.length > 0">
        <div
          v-for="invoice in filteredInvoices"
          :key="invoice.id"
          class="bg-white dark:bg-slate-800 rounded-2xl shadow-sm p-4 border-l-[6px] flex flex-col gap-3"
          :class="{
            'border-red-500': invoice.status === 'vencida',
            'border-amber-500': invoice.status === 'pendiente',
            'border-emerald-500': invoice.status === 'pagada'
          }"
        >
          <!-- Header Card -->
          <div class="flex justify-between items-start text-xs text-slate-500 dark:text-slate-400">
            <div class="flex items-center gap-1.5 font-medium truncate">
              <Truck :size="14" />
              <span class="truncate">{{ invoice.supplier?.name || 'Desconocido' }}</span>
            </div>
            <span>F-{{ invoice.invoice_number || 'N/A' }}</span>
          </div>

          <!-- Body Card -->
          <div>
            <div class="flex justify-between items-end mb-1">
              <span class="text-xs text-slate-500 dark:text-slate-400">Monto Original</span>
              <span class="text-sm font-medium text-slate-700 dark:text-slate-300">{{ formatCurrency(invoice.total_amount) }}</span>
            </div>
            <div class="flex justify-between items-end">
              <span class="text-sm font-bold text-slate-700 dark:text-slate-300">Saldo Pendiente</span>
              <span class="text-xl font-black" :class="invoice.amount_paid < invoice.total_amount ? (invoice.status === 'vencida' ? 'text-red-600 dark:text-red-400' : 'text-slate-900 dark:text-white') : 'text-emerald-600 dark:text-emerald-400'">
                {{ formatCurrency(invoice.total_amount - invoice.amount_paid) }}
              </span>
            </div>
          </div>

          <!-- Footer Card -->
          <div class="flex justify-between items-center pt-3 mt-1 border-t border-slate-100 dark:border-slate-700/50">
            <div>
              <span class="px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider rounded-full"
                :class="{
                  'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400': invoice.status === 'vencida',
                  'bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400': invoice.status === 'pendiente',
                  'bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400': invoice.status === 'pagada'
                }"
              >
                {{ invoice.status === 'vencida' && invoice.due_date ? 'Vence: ' + invoice.due_date : (invoice.due_date && invoice.status === 'pendiente' ? 'Vence: ' + invoice.due_date : invoice.status) }}
              </span>
            </div>
            <BaseButton
              v-if="invoice.status !== 'pagada' && authStore.isAdmin"
              @click="openPaymentModal(invoice)"
              size="sm"
            >
              Abonar
            </BaseButton>
          </div>
        </div>

        <button
          v-if="payablesStore.invoices.length < payablesStore.totalCount"
          type="button"
          data-testid="load-more-invoices-btn"
          @click="loadMoreInvoices"
          class="w-full py-2.5 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-xs font-bold text-primary hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors"
        >
          Cargar más facturas ({{ payablesStore.totalCount - payablesStore.invoices.length }} restantes)
        </button>
      </template>

      <!-- Empty State -->
      <div v-else class="flex-1 flex flex-col items-center justify-center py-12 text-center">
        <Receipt :size="64" :stroke-width="1" class="text-slate-300 dark:text-slate-600 mb-4" />
        <h3 class="text-lg font-bold text-slate-900 dark:text-white mb-2">
          Todo al día
        </h3>
        <p class="text-sm text-slate-500 dark:text-slate-400 max-w-xs">
          {{ emptyStateMessage }}
        </p>
      </div>
    </main>

    <BottomNav />

    <!-- Payment Modal (Bottom Sheet) -->
    <PayInvoiceModal
      :show="isPaymentModalOpen"
      :invoice="selectedInvoice"
      @close="closePaymentModal"
      @success="handlePaymentSuccess"
    />

    <!-- Nueva Factura Proveedor Modal (CHK-410: Admin-only) -->
    <BaseModal
      v-model="showCreateModal"
      title="Nueva Factura de Proveedor"
      maxHeight="560px"
    >
      <div class="p-4 space-y-4">
        <div v-if="createError" role="alert" class="p-3 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-xs font-semibold text-red-700 dark:text-red-300">
          {{ createError }}
        </div>

        <div>
          <label class="block text-xs font-semibold text-slate-600 dark:text-slate-300 mb-1">
            Nombre del proveedor (Obligatorio)
          </label>
          <input
            v-model="newInvoiceForm.supplierName"
            data-testid="create-invoice-supplier-input"
            type="text"
            placeholder="Ej. Distribuidora Central"
            class="w-full h-11 px-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-primary"
          />
        </div>

        <div>
          <label class="block text-xs font-semibold text-slate-600 dark:text-slate-300 mb-1">
            Valor total factura (Obligatorio)
          </label>
          <input
            v-model.number="newInvoiceForm.totalAmount"
            data-testid="create-invoice-amount-input"
            type="number"
            min="1"
            step="100"
            placeholder="0"
            class="w-full h-11 px-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-primary"
          />
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-xs font-semibold text-slate-600 dark:text-slate-300 mb-1">
              Fecha vencimiento (Opcional)
            </label>
            <input
              v-model="newInvoiceForm.dueDate"
              data-testid="create-invoice-duedate-input"
              type="date"
              class="w-full h-11 px-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-primary"
            />
          </div>
          <div>
            <label class="block text-xs font-semibold text-slate-600 dark:text-slate-300 mb-1">
              N° Referencia (Opcional)
            </label>
            <input
              v-model="newInvoiceForm.invoiceNumber"
              data-testid="create-invoice-ref-input"
              type="text"
              placeholder="Ej. FAC-001"
              class="w-full h-11 px-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-primary"
            />
          </div>
        </div>

        <div class="flex gap-2 pt-2">
          <BaseButton variant="secondary" class="flex-1" :disabled="isCreatingInvoice" @click="showCreateModal = false">
            Cancelar
          </BaseButton>
          <BaseButton class="flex-1" data-testid="submit-create-invoice-btn" :loading="isCreatingInvoice" :disabled="isCreatingInvoice" @click="submitCreateInvoice">
            Guardar Factura
          </BaseButton>
        </div>
      </div>
    </BaseModal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { usePayablesStore, type SupplierInvoice } from '@/stores/payables';
import { useSuppliersStore } from '@/stores/suppliers';
import { useCurrencyFormat } from '@/composables/useCurrencyFormat';
import { useNotifications } from '@/composables/useNotifications';
import PayInvoiceModal from '@/components/suppliers/PayInvoiceModal.vue';
import BottomNav from '@/components/BottomNav.vue';
import Skeleton from '@/components/ui/Skeleton.vue';
import BaseButton from '@/components/ui/BaseButton.vue';
import BaseModal from '@/components/ui/BaseModal.vue';
import { ArrowLeft, Banknote, AlertTriangle, Truck, Receipt, Plus } from 'lucide-vue-next';

const INVOICES_PAGE_SIZE = 50;

const { formatCurrency } = useCurrencyFormat();
const { showSuccess, showError } = useNotifications();
const router = useRouter();
const authStore = useAuthStore();
const payablesStore = usePayablesStore();
const suppliersStore = useSuppliersStore();

const selectedSupplierId = ref('');
const selectedStatus = ref('');

const isPaymentModalOpen = ref(false);
const selectedInvoice = ref<SupplierInvoice | null>(null);

const showCreateModal = ref(false);
const isCreatingInvoice = ref(false);
const createError = ref<string | null>(null);
const newInvoiceForm = ref({
  supplierName: '',
  totalAmount: '' as number | '',
  dueDate: '',
  invoiceNumber: '',
});

const goBack = () => {
  router.push('/suppliers');
};

const filteredInvoices = computed(() => payablesStore.invoices);

const totalDebt = computed(() => {
  return filteredInvoices.value
    .filter(inv => inv.status !== 'pagada')
    .reduce((sum, inv) => sum + (inv.total_amount - inv.amount_paid), 0);
});

const totalOverdue = computed(() => {
  return filteredInvoices.value
    .filter(inv => inv.status === 'vencida')
    .reduce((sum, inv) => sum + (inv.total_amount - inv.amount_paid), 0);
});

const emptyStateMessage = computed(() => {
  if (selectedStatus.value === 'vencida') return 'No tienes facturas vencidas registradas.';
  if (selectedStatus.value === 'pendiente') return 'No tienes facturas pendientes de pago.';
  if (selectedStatus.value === 'pagada') return 'Aún no tienes facturas pagadas.';
  return 'No hay deudas con proveedores actualmente.';
});

const loadInvoicesPage = async (reset: boolean = true) => {
  const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
  if (!storeId) return;
  await payablesStore.fetchInvoices({
    storeId,
    supplierId: selectedSupplierId.value || undefined,
    status: selectedStatus.value || undefined,
    limit: INVOICES_PAGE_SIZE,
    offset: reset ? 0 : payablesStore.invoices.length,
    append: !reset,
  });
};

const loadMoreInvoices = async () => {
  await loadInvoicesPage(false);
};

const loadData = async () => {
  const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
  if (!storeId) return;
  await Promise.all([
    suppliersStore.fetchSuppliers(storeId),
    loadInvoicesPage(true),
  ]);
};

onMounted(() => {
  loadData();
});

watch(() => authStore.currentUser?.storeId || authStore.currentStore?.id, (newStoreId) => {
  if (newStoreId) {
    loadData();
  }
});

watch([selectedSupplierId, selectedStatus], () => {
  loadInvoicesPage(true);
});

const openPaymentModal = (invoice: SupplierInvoice) => {
  selectedInvoice.value = invoice;
  isPaymentModalOpen.value = true;
};

const closePaymentModal = () => {
  isPaymentModalOpen.value = false;
  selectedInvoice.value = null;
};

const handlePaymentSuccess = () => {
  loadInvoicesPage(true);
};

const openCreateModal = () => {
  createError.value = null;
  newInvoiceForm.value = { supplierName: '', totalAmount: '', dueDate: '', invoiceNumber: '' };
  showCreateModal.value = true;
};

const submitCreateInvoice = async () => {
  const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
  if (!storeId || isCreatingInvoice.value) return;
  const cleanSupplier = newInvoiceForm.value.supplierName.trim();
  const amount = Number(newInvoiceForm.value.totalAmount);
  if (cleanSupplier.length < 2) {
    createError.value = 'Ingresa el nombre del proveedor (mínimo 2 caracteres).';
    return;
  }
  if (!Number.isFinite(amount) || amount <= 0) {
    createError.value = 'Ingresa un valor total válido mayor a cero.';
    return;
  }

  isCreatingInvoice.value = true;
  createError.value = null;
  const res = await payablesStore.createInvoice({
    storeId,
    supplierName: cleanSupplier,
    totalAmount: amount,
    dueDate: newInvoiceForm.value.dueDate || null,
    invoiceNumber: newInvoiceForm.value.invoiceNumber.trim() || null,
  });
  isCreatingInvoice.value = false;

  if (res.success) {
    showSuccess('Factura de proveedor registrada');
    showCreateModal.value = false;
    await loadData();
  } else {
    createError.value = res.error || 'No se pudo crear la factura';
    showError(createError.value);
  }
};
</script>

<style scoped>
.hide-scrollbar::-webkit-scrollbar {
  display: none;
}
.hide-scrollbar {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
</style>

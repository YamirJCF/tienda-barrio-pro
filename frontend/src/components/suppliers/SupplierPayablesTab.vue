<template>
  <div class="space-y-4">
    <!-- Top Bar + CTA Nueva Factura -->
    <div class="flex items-center justify-between gap-3">
      <div>
        <h3 class="text-sm font-bold text-slate-900 dark:text-white">Obligaciones con Proveedores</h3>
        <p class="text-xs text-slate-500 dark:text-slate-400">
          Saldos y vencimientos calculados por el servidor
        </p>
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

    <!-- Filters -->
    <div class="flex flex-col gap-3">
      <select
        v-model="selectedSupplierId"
        data-testid="payables-supplier-filter"
        class="block w-full rounded-xl border border-slate-200 dark:border-slate-700 bg-surface-light dark:bg-surface-dark text-slate-900 dark:text-white focus:ring-2 focus:ring-primary focus:border-primary text-sm h-11 px-3 outline-none"
      >
        <option value="">Todos los proveedores</option>
        <option v-for="supplier in suppliersStore.suppliers" :key="supplier.id" :value="supplier.id">
          {{ supplier.name }}
        </option>
      </select>

      <div class="flex gap-2 overflow-x-auto pb-1 hide-scrollbar">
        <button
          type="button"
          data-testid="filter-status-all"
          @click="selectedStatus = ''"
          class="whitespace-nowrap px-4 py-1.5 rounded-full text-sm font-medium transition-colors cursor-pointer"
          :class="selectedStatus === '' ? 'bg-slate-800 dark:bg-slate-200 text-white dark:text-slate-900' : 'bg-surface-light dark:bg-surface-dark border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300'"
        >
          Todas
        </button>
        <button
          type="button"
          data-testid="filter-status-pendiente"
          @click="selectedStatus = 'pendiente'"
          class="whitespace-nowrap px-4 py-1.5 rounded-full text-sm font-medium transition-colors cursor-pointer"
          :class="selectedStatus === 'pendiente' ? 'bg-amber-500 text-white' : 'bg-surface-light dark:bg-surface-dark border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300'"
        >
          Pendientes
        </button>
        <button
          type="button"
          data-testid="filter-status-vencida"
          @click="selectedStatus = 'vencida'"
          class="whitespace-nowrap px-4 py-1.5 rounded-full text-sm font-medium transition-colors cursor-pointer"
          :class="selectedStatus === 'vencida' ? 'bg-red-500 text-white' : 'bg-surface-light dark:bg-surface-dark border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300'"
        >
          Vencidas
        </button>
        <button
          type="button"
          data-testid="filter-status-pagada"
          @click="selectedStatus = 'pagada'"
          class="whitespace-nowrap px-4 py-1.5 rounded-full text-sm font-medium transition-colors cursor-pointer"
          :class="selectedStatus === 'pagada' ? 'bg-emerald-500 text-white' : 'bg-surface-light dark:bg-surface-dark border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300'"
        >
          Pagadas
        </button>
      </div>
    </div>

    <!-- KPI Cards (100% Backend Summary Authority) -->
    <div class="grid grid-cols-2 gap-3">
      <div
        data-testid="kpi-total-debt"
        class="bg-surface-light dark:bg-surface-dark p-4 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm text-center flex flex-col items-center justify-center"
      >
        <div class="flex h-10 w-10 items-center justify-center rounded-full bg-slate-100 dark:bg-slate-800 mb-2">
          <Banknote :size="20" class="text-slate-600 dark:text-slate-300" />
        </div>
        <p class="text-[10px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-1">
          Deuda Total
        </p>
        <div class="text-lg font-black text-slate-900 dark:text-white font-mono tabular-nums">
          <Skeleton v-if="payablesStore.isLoading" width="80px" height="24px" class="mx-auto" />
          <span v-else>{{ formatCurrency(payablesStore.summary.totalDebt) }}</span>
        </div>
      </div>

      <div
        data-testid="kpi-total-overdue"
        class="bg-red-50/80 dark:bg-red-950/30 p-4 rounded-2xl border border-red-200 dark:border-red-900/50 shadow-sm text-center flex flex-col items-center justify-center"
      >
        <div class="flex h-10 w-10 items-center justify-center rounded-full bg-red-100 dark:bg-red-900/40 mb-2">
          <AlertTriangle :size="20" class="text-red-600 dark:text-red-400" />
        </div>
        <p class="text-[10px] font-bold text-red-600 dark:text-red-400 uppercase tracking-wider mb-1">
          Total Vencido
        </p>
        <div class="text-lg font-black text-red-700 dark:text-red-300 font-mono tabular-nums">
          <Skeleton v-if="payablesStore.isLoading" width="80px" height="24px" class="mx-auto" />
          <span v-else>{{ formatCurrency(payablesStore.summary.totalOverdue) }}</span>
        </div>
      </div>
    </div>

    <!-- Error State N3 Persistente (Regla 3: nunca mostrar vacío en error) -->
    <div
      v-if="payablesStore.error"
      role="alert"
      data-testid="payables-error-banner"
      class="p-4 rounded-2xl bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800 space-y-2"
    >
      <p class="text-sm font-semibold text-red-700 dark:text-red-300">{{ payablesStore.error }}</p>
      <BaseButton size="sm" variant="danger" data-testid="payables-retry-btn" @click="loadInvoicesPage(true)">
        Reintentar
      </BaseButton>
    </div>

    <!-- Loading Skeleton -->
    <BaseListSkeleton v-else-if="payablesStore.isLoading" :count="3" type="card" />

    <!-- Invoices List -->
    <template v-else-if="filteredInvoices.length > 0">
      <div class="flex flex-col gap-3">
        <div
          v-for="invoice in filteredInvoices"
          :key="invoice.id"
          :data-testid="`invoice-card-${invoice.id}`"
          class="bg-surface-light dark:bg-surface-dark rounded-2xl shadow-sm p-4 border flex flex-col gap-3 transition-colors"
          :class="[
            highlightedInvoiceId === invoice.id
              ? 'border-primary ring-2 ring-primary/25'
              : invoice.status === 'vencida'
                ? 'border-red-300 dark:border-red-800/70'
                : invoice.status === 'pendiente'
                  ? 'border-amber-300 dark:border-amber-800/70'
                  : 'border-emerald-300 dark:border-emerald-800/70'
          ]"
        >
          <div class="flex justify-between items-start text-xs text-slate-500 dark:text-slate-400">
            <div class="flex items-center gap-1.5 font-medium truncate">
              <Truck :size="14" />
              <span class="truncate">{{ invoice.supplier?.name || 'Desconocido' }}</span>
            </div>
            <span class="font-mono tabular-nums">F-{{ invoice.invoice_number || 'N/A' }}</span>
          </div>

          <div class="space-y-1">
            <div class="flex justify-between items-end">
              <span class="text-xs text-slate-500 dark:text-slate-400">Monto Original</span>
              <span class="text-sm font-medium text-slate-700 dark:text-slate-300 font-mono tabular-nums">
                {{ formatCurrency(invoice.total_amount) }}
              </span>
            </div>
            <div class="flex justify-between items-end">
              <span class="text-sm font-bold text-slate-700 dark:text-slate-300">Saldo Pendiente</span>
              <span
                class="text-xl font-black font-mono tabular-nums"
                :class="Number(invoice.pending_balance ?? 0) > 0
                  ? (invoice.status === 'vencida' ? 'text-red-600 dark:text-red-400' : 'text-slate-900 dark:text-white')
                  : 'text-emerald-600 dark:text-emerald-400'"
              >
                {{ formatCurrency(Number(invoice.pending_balance ?? 0)) }}
              </span>
            </div>
          </div>

          <div class="flex justify-between items-center pt-3 mt-1 border-t border-slate-100 dark:border-slate-800">
            <span
              class="px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider rounded-full font-mono tabular-nums"
              :class="{
                'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400': invoice.status === 'vencida',
                'bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400': invoice.status === 'pendiente',
                'bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400': invoice.status === 'pagada'
              }"
            >
              {{
                invoice.due_date && invoice.status !== 'pagada'
                  ? 'Vence: ' + invoice.due_date
                  : invoice.status
              }}
            </span>

            <BaseButton
              v-if="invoice.status !== 'pagada' && authStore.isAdmin"
              :data-testid="`pay-invoice-btn-${invoice.id}`"
              @click="openPaymentModal(invoice)"
              size="sm"
            >
              Abonar
            </BaseButton>
          </div>
        </div>
      </div>

      <button
        v-if="payablesStore.invoices.length < payablesStore.totalCount"
        type="button"
        data-testid="load-more-invoices-btn"
        @click="loadMoreInvoices"
        class="w-full py-2.5 rounded-xl border border-slate-200 dark:border-slate-700 bg-surface-light dark:bg-surface-dark text-xs font-bold text-primary hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors cursor-pointer"
      >
        Cargar más facturas ({{ payablesStore.totalCount - payablesStore.invoices.length }} restantes)
      </button>
    </template>

    <!-- Empty State -->
    <div v-else class="flex flex-col items-center justify-center py-12 text-center">
      <Receipt :size="64" :stroke-width="1" class="text-slate-300 dark:text-slate-600 mb-4" />
      <h3 class="text-lg font-bold text-slate-900 dark:text-white mb-2">Todo al día</h3>
      <p class="text-sm text-slate-500 dark:text-slate-400 max-w-xs">
        {{ emptyStateMessage }}
      </p>
    </div>

    <!-- Payment Modal (Arquetipo D) -->
    <PayInvoiceModal
      :show="isPaymentModalOpen"
      :invoice="selectedInvoice"
      @close="closePaymentModal"
      @success="handlePaymentSuccess"
    />

    <!-- Nueva Factura Proveedor Modal -->
    <BaseModal
      v-model="showCreateModal"
      title="Nueva Factura de Proveedor"
      :showCloseButton="true"
      maxHeight="90vh"
    >
      <div class="p-4 space-y-4">
        <div
          v-if="createError"
          role="alert"
          data-testid="create-invoice-error"
          class="p-3 rounded-xl bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800 text-xs font-semibold text-red-700 dark:text-red-300"
        >
          {{ createError }}
        </div>

        <div class="space-y-2">
          <div class="flex items-center justify-between gap-2">
            <label class="block text-xs font-semibold text-slate-600 dark:text-slate-300">
              Proveedor (Obligatorio)
            </label>
            <button
              type="button"
              data-testid="toggle-new-supplier-mode"
              @click="toggleSupplierInputMode"
              class="text-xs font-semibold text-primary hover:underline cursor-pointer"
            >
              {{ useNewSupplierName ? 'Elegir proveedor existente' : '+ Crear proveedor nuevo' }}
            </button>
          </div>

          <select
            v-if="!useNewSupplierName"
            v-model="newInvoiceForm.supplierId"
            data-testid="create-invoice-supplier-select"
            class="w-full h-11 px-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-background-light dark:bg-background-dark text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-primary"
          >
            <option value="">-- Selecciona un proveedor --</option>
            <option v-for="sup in suppliersStore.suppliers" :key="sup.id" :value="sup.id">
              {{ sup.name }}
            </option>
          </select>

          <input
            v-else
            v-model="newInvoiceForm.supplierName"
            data-testid="create-invoice-supplier-input"
            type="text"
            placeholder="Ej. Distribuidora Central"
            class="w-full h-11 px-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-background-light dark:bg-background-dark text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-primary"
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
            class="w-full h-11 px-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-background-light dark:bg-background-dark text-sm font-mono tabular-nums text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-primary"
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
              class="w-full h-11 px-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-background-light dark:bg-background-dark text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-primary"
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
              class="w-full h-11 px-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-background-light dark:bg-background-dark text-sm text-slate-900 dark:text-white outline-none focus:ring-2 focus:ring-primary"
            />
          </div>
        </div>
      </div>

      <template #footer>
        <div class="p-4 pt-2 border-t border-slate-100 dark:border-slate-800 flex gap-2">
          <BaseButton variant="secondary" class="flex-1" :disabled="isCreatingInvoice" @click="showCreateModal = false">
            Cancelar
          </BaseButton>
          <BaseButton
            class="flex-1"
            data-testid="submit-create-invoice-btn"
            :loading="isCreatingInvoice"
            :disabled="isCreatingInvoice"
            @click="submitCreateInvoice"
          >
            Guardar Factura
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { usePayablesStore, type SupplierInvoice } from '@/stores/payables';
import { useSuppliersStore } from '@/stores/suppliers';
import { useCurrencyFormat } from '@/composables/useCurrencyFormat';
import { useNotifications } from '@/composables/useNotifications';
import PayInvoiceModal from '@/components/suppliers/PayInvoiceModal.vue';
import Skeleton from '@/components/ui/Skeleton.vue';
import BaseListSkeleton from '@/components/ui/BaseListSkeleton.vue';
import BaseButton from '@/components/ui/BaseButton.vue';
import BaseModal from '@/components/ui/BaseModal.vue';
import { Banknote, AlertTriangle, Truck, Receipt, Plus } from 'lucide-vue-next';

const INVOICES_PAGE_SIZE = 50;

const props = defineProps<{
  initialSupplierId?: string;
  highlightedInvoiceId?: string;
}>();

const emit = defineEmits<{
  (e: 'supplier-filter-change', supplierId: string): void;
  (e: 'invoices-mutated'): void;
}>();

const { formatCurrency } = useCurrencyFormat();
const { showSuccess, showError } = useNotifications();
const authStore = useAuthStore();
const payablesStore = usePayablesStore();
const suppliersStore = useSuppliersStore();

const selectedSupplierId = ref<string>(props.initialSupplierId || '');
const selectedStatus = ref<string>('');
const isPaymentModalOpen = ref(false);
const selectedInvoice = ref<SupplierInvoice | null>(null);
const showCreateModal = ref(false);
const useNewSupplierName = ref(false);
const isCreatingInvoice = ref(false);
const createError = ref<string | null>(null);

const newInvoiceForm = ref({
  supplierId: '',
  supplierName: '',
  totalAmount: null as number | null,
  dueDate: '',
  invoiceNumber: '',
});

const storeId = computed(() => authStore.currentUser?.storeId || authStore.currentStore?.id || '');

const loadInvoicesPage = async (reset = true) => {
  if (!storeId.value) return;
  const offset = reset ? 0 : payablesStore.invoices.length;
  await payablesStore.fetchInvoices({
    storeId: storeId.value,
    supplierId: selectedSupplierId.value || undefined,
    status: selectedStatus.value || undefined,
    limit: INVOICES_PAGE_SIZE,
    offset,
    append: !reset,
  });
};

const loadMoreInvoices = async () => {
  await loadInvoicesPage(false);
};

watch(
  () => props.initialSupplierId,
  (nextId) => {
    const normalized = nextId || '';
    if (normalized !== selectedSupplierId.value) {
      selectedSupplierId.value = normalized;
    }
  }
);

watch([selectedSupplierId, selectedStatus], async ([newSup]) => {
  emit('supplier-filter-change', newSup);
  await loadInvoicesPage(true);
});

watch(storeId, async (newId) => {
  if (newId) {
    await loadInvoicesPage(true);
  }
});

onMounted(async () => {
  await loadInvoicesPage(true);
});

const filteredInvoices = computed(() => payablesStore.invoices);

const emptyStateMessage = computed(() => {
  if (selectedStatus.value === 'vencida') return 'No tienes facturas vencidas.';
  if (selectedStatus.value === 'pendiente') return 'No tienes facturas pendientes por pagar.';
  if (selectedStatus.value === 'pagada') return 'No hay facturas pagadas registradas aún.';
  return 'No hay facturas registradas en Cuentas por Pagar.';
});

const openPaymentModal = (invoice: SupplierInvoice) => {
  selectedInvoice.value = invoice;
  isPaymentModalOpen.value = true;
};

const closePaymentModal = () => {
  isPaymentModalOpen.value = false;
  selectedInvoice.value = null;
};

const handlePaymentSuccess = async () => {
  await loadInvoicesPage(true);
  emit('invoices-mutated');
};

const openCreateModal = () => {
  createError.value = null;
  useNewSupplierName.value = suppliersStore.suppliers.length === 0;
  newInvoiceForm.value = {
    supplierId: selectedSupplierId.value || '',
    supplierName: '',
    totalAmount: null,
    dueDate: '',
    invoiceNumber: '',
  };
  showCreateModal.value = true;
};

const toggleSupplierInputMode = () => {
  createError.value = null;
  useNewSupplierName.value = !useNewSupplierName.value;
};

const submitCreateInvoice = async () => {
  if (isCreatingInvoice.value) return;
  if (!storeId.value) {
    createError.value = 'No hay tienda activa.';
    return;
  }

  const amount = Number(newInvoiceForm.value.totalAmount);
  if (!Number.isFinite(amount) || amount <= 0) {
    createError.value = 'El valor total de la factura debe ser mayor a cero.';
    return;
  }

  if (!useNewSupplierName.value) {
    if (!newInvoiceForm.value.supplierId) {
      createError.value = 'Selecciona un proveedor del catálogo o crea uno nuevo.';
      return;
    }
  } else if (newInvoiceForm.value.supplierName.trim().length < 2) {
    createError.value = 'El nombre del proveedor es obligatorio (mínimo 2 caracteres).';
    return;
  }

  isCreatingInvoice.value = true;
  createError.value = null;

  const result = await payablesStore.createInvoice({
    storeId: storeId.value,
    supplierId: useNewSupplierName.value ? null : newInvoiceForm.value.supplierId,
    supplierName: useNewSupplierName.value ? newInvoiceForm.value.supplierName.trim() : null,
    totalAmount: amount,
    dueDate: newInvoiceForm.value.dueDate || null,
    invoiceNumber: newInvoiceForm.value.invoiceNumber.trim() || null,
  });

  isCreatingInvoice.value = false;

  if (!result.success) {
    createError.value = result.error || 'No se pudo crear la factura.';
    showError(createError.value);
    return;
  }

  showSuccess('Factura registrada en Cuentas por Pagar');
  showCreateModal.value = false;
  await loadInvoicesPage(true);
  emit('invoices-mutated');
};
</script>

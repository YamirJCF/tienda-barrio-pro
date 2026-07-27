<template>
  <div class="px-4 py-6 sm:px-6 lg:px-8 max-w-7xl mx-auto">
    <div class="sm:flex sm:items-center">
      <div class="sm:flex-auto">
        <h1 class="text-2xl font-semibold text-gray-900">Cuentas por Pagar</h1>
        <p class="mt-2 text-sm text-gray-700">Gestión de facturas y deudas a proveedores.</p>
      </div>
    </div>

    <!-- Metrics -->
    <div class="mt-6 grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <span class="text-gray-500 text-2xl">💰</span>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Deuda Total</dt>
                <dd>
                  <div class="text-lg font-medium text-gray-900">
                    <span v-if="payablesStore.isLoading" class="animate-pulse bg-gray-200 h-6 w-24 rounded inline-block"></span>
                    <span v-else>{{ formatCurrency(totalDebt) }}</span>
                  </div>
                </dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
      <div class="bg-white overflow-hidden shadow rounded-lg">
        <div class="p-5">
          <div class="flex items-center">
            <div class="flex-shrink-0">
              <span class="text-red-500 text-2xl">⚠️</span>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Total Vencido</dt>
                <dd>
                  <div class="text-lg font-medium text-red-600">
                    <span v-if="payablesStore.isLoading" class="animate-pulse bg-gray-200 h-6 w-24 rounded inline-block"></span>
                    <span v-else>{{ formatCurrency(totalOverdue) }}</span>
                  </div>
                </dd>
              </dl>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Filters -->
    <div class="mt-8 flex flex-col sm:flex-row gap-4 items-center">
      <div class="w-full sm:w-64">
        <label for="supplier" class="block text-sm font-medium text-gray-700">Proveedor</label>
        <select
          id="supplier"
          v-model="selectedSupplierId"
          class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
        >
          <option value="">Todos los proveedores</option>
          <option v-for="supplier in suppliersStore.suppliers" :key="supplier.id" :value="supplier.id">
            {{ supplier.name }}
          </option>
        </select>
      </div>

      <div class="w-full sm:w-64">
        <label for="status" class="block text-sm font-medium text-gray-700">Estado</label>
        <select
          id="status"
          v-model="selectedStatus"
          class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
        >
          <option value="">Todos los estados</option>
          <option value="pendiente">Pendiente</option>
          <option value="vencida">Vencida</option>
          <option value="pagada">Pagada</option>
        </select>
      </div>
    </div>

    <!-- Invoices List -->
    <div class="mt-8 flex flex-col">
      <div class="-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
        <div class="inline-block min-w-full py-2 align-middle md:px-6 lg:px-8">
          <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
            
            <!-- Skeleton Loading -->
            <div v-if="payablesStore.isLoading" class="bg-white p-4 space-y-4">
              <div v-for="i in 3" :key="i" class="animate-pulse flex space-x-4">
                <div class="flex-1 space-y-4 py-1">
                  <div class="h-4 bg-gray-200 rounded w-3/4"></div>
                  <div class="space-y-2">
                    <div class="h-4 bg-gray-200 rounded"></div>
                    <div class="h-4 bg-gray-200 rounded w-5/6"></div>
                  </div>
                </div>
              </div>
            </div>

            <!-- Invoices Table -->
            <table v-else class="min-w-full divide-y divide-gray-300">
              <thead class="bg-gray-50">
                <tr>
                  <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6">Factura</th>
                  <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Proveedor</th>
                  <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Monto Total</th>
                  <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Saldo Pendiente</th>
                  <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Vencimiento</th>
                  <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Estado</th>
                  <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                    <span class="sr-only">Acciones</span>
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200 bg-white">
                <tr v-for="invoice in filteredInvoices" :key="invoice.id">
                  <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                    {{ invoice.invoice_number }}
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                    {{ invoice.supplier?.name || 'Desconocido' }}
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                    {{ formatCurrency(invoice.total_amount) }}
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm font-semibold" :class="invoice.total_amount > invoice.amount_paid ? 'text-red-600' : 'text-gray-900'">
                    {{ formatCurrency(invoice.total_amount - invoice.amount_paid) }}
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                    {{ invoice.due_date || 'N/A' }}
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm">
                    <span :class="{
                      'inline-flex rounded-full px-2 text-xs font-semibold leading-5': true,
                      'bg-green-100 text-green-800': invoice.status === 'pagada',
                      'bg-yellow-100 text-yellow-800': invoice.status === 'pendiente',
                      'bg-red-100 text-red-800': invoice.status === 'vencida'
                    }">
                      {{ invoice.status.toUpperCase() }}
                    </span>
                  </td>
                  <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                    <button
                      v-if="invoice.status !== 'pagada' && authStore.isAdmin"
                      @click="openPaymentModal(invoice)"
                      class="text-indigo-600 hover:text-indigo-900"
                    >
                      Pagar<span class="sr-only">, {{ invoice.invoice_number }}</span>
                    </button>
                  </td>
                </tr>
                <tr v-if="filteredInvoices.length === 0">
                  <td colspan="7" class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 text-center">
                    No se encontraron facturas.
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>

    <!-- Payment Modal -->
    <PayInvoiceModal
      :show="isPaymentModalOpen"
      :invoice="selectedInvoice"
      @close="closePaymentModal"
      @success="handlePaymentSuccess"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { usePayablesStore, type SupplierInvoice } from '@/stores/payables';
import { useSuppliersStore } from '@/stores/suppliers';
import { formatCurrency } from '@/utils/currency';
import PayInvoiceModal from '@/components/suppliers/PayInvoiceModal.vue';

const authStore = useAuthStore();
const payablesStore = usePayablesStore();
const suppliersStore = useSuppliersStore();

const selectedSupplierId = ref('');
const selectedStatus = ref('');

const isPaymentModalOpen = ref(false);
const selectedInvoice = ref<SupplierInvoice | null>(null);

const filteredInvoices = computed(() => {
  return payablesStore.invoices.filter(inv => {
    const matchSupplier = selectedSupplierId.value ? inv.supplier_id === selectedSupplierId.value : true;
    const matchStatus = selectedStatus.value ? inv.status === selectedStatus.value : true;
    return matchSupplier && matchStatus;
  });
});

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

const loadData = async () => {
  if (authStore.currentStore?.id) {
    await Promise.all([
      suppliersStore.fetchSuppliers(authStore.currentStore.id),
      payablesStore.fetchInvoices()
    ]);
  }
};

onMounted(() => {
  loadData();
});

watch(() => authStore.currentStore?.id, (newStoreId) => {
  if (newStoreId) {
    loadData();
  }
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
  payablesStore.fetchInvoices();
};
</script>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useClientsStore } from '../stores/clients';
import { useAuthStore } from '../stores/auth';
import type { Client } from '../types';
import type { ClientDebtFilter, ClientOrderBy } from '../data/repositories/clientRepository';
import BottomNav from '../components/BottomNav.vue';
import ClientFormModal from '../components/ClientFormModal.vue';
import { Decimal } from 'decimal.js';
import BaseInput from '@/components/ui/BaseInput.vue';
import BaseButton from '@/components/ui/BaseButton.vue';
import BaseModal from '@/components/ui/BaseModal.vue';
import BaseListSkeleton from '@/components/ui/BaseListSkeleton.vue';
import BaseEmptyState from '@/components/ui/BaseEmptyState.vue';
import {
  ArrowLeft,
  Search,
  AlertTriangle,
  Users,
  ChevronRight,
  Plus,
  RefreshCw,
  Loader2,
  SlidersHorizontal
} from 'lucide-vue-next';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useNotifications } from '../composables/useNotifications';

const PAGE_SIZE = 20;

const router = useRouter();
const clientsStore = useClientsStore();
const authStore = useAuthStore();
const { formatCurrency: rawFormatCurrency } = useCurrencyFormat();
const { showSuccess } = useNotifications();

// State
const searchQuery = ref('');
const debtFilter = ref<ClientDebtFilter>('all');
const orderBy = ref<ClientOrderBy>('name_asc');
const pagedClients = ref<Client[]>([]);
const totalClientsCount = ref(0);
const totalPortfolioDebt = ref<Decimal>(new Decimal(0));
const debtorsCount = ref(0);
const isLoadingPage = ref(false);
const isLoadingMore = ref(false);
const fetchError = ref<string | null>(null);
const showClientModal = ref(false);
const editingClientId = ref<string | undefined>(undefined);
const newlyCreatedId = ref<string | null>(null);

// Política de Cupo Global (Admin-only, migrado desde C7 AdminHubView)
const showGlobalCreditModal = ref(false);
const globalCreditLimit = ref<number>(0);
const isLoadingCreditLimit = ref(false);
const isSavingCreditLimit = ref(false);
const creditLimitError = ref<string | null>(null);

let fetchSeq = 0;

const storeId = computed(() => authStore.currentUser?.storeId || authStore.currentStore?.id || '');

const loadClients = async (reset: boolean = true) => {
  if (!storeId.value) return;

  const offset = reset ? 0 : pagedClients.value.length;
  const seq = ++fetchSeq;
  if (reset) {
    isLoadingPage.value = true;
    fetchError.value = null;
  } else {
    isLoadingMore.value = true;
  }

  try {
    const result = await clientsStore.fetchClientsPage({
      storeId: storeId.value,
      limit: PAGE_SIZE,
      offset,
      search: searchQuery.value.trim(),
      debtFilter: debtFilter.value,
      orderBy: orderBy.value,
    });
    if (seq !== fetchSeq) return;

    if (reset) {
      pagedClients.value = result.data;
    } else {
      const seen = new Set(pagedClients.value.map((c) => c.id));
      pagedClients.value = [...pagedClients.value, ...result.data.filter((c) => !seen.has(c.id))];
    }
    totalClientsCount.value = result.count;
    totalPortfolioDebt.value = result.totalPortfolioDebt ?? new Decimal(0);
    debtorsCount.value = result.debtorsCount ?? 0;
  } catch (err: any) {
    if (seq !== fetchSeq) return;
    fetchError.value = err?.message || 'No se pudo cargar la cartera de clientes.';
  } finally {
    if (seq === fetchSeq) {
      isLoadingPage.value = false;
      isLoadingMore.value = false;
    }
  }
};

onMounted(async () => {
  await loadClients(true);
});

watch([searchQuery, debtFilter, orderBy], () => {
  loadClients(true);
});

// Computed
const filteredClients = computed(() => pagedClients.value);
const hasMore = computed(() => pagedClients.value.length < totalClientsCount.value);
const canManageClients = computed(() => authStore.isAdmin);

const openGlobalCreditModal = async () => {
  if (!canManageClients.value || !storeId.value) return;
  showGlobalCreditModal.value = true;
  isLoadingCreditLimit.value = true;
  creditLimitError.value = null;
  try {
    globalCreditLimit.value = await clientsStore.getDefaultCreditLimit(storeId.value);
  } catch (e: any) {
    creditLimitError.value = e?.message || 'No se pudo cargar el cupo por defecto.';
  } finally {
    isLoadingCreditLimit.value = false;
  }
};

const saveGlobalCreditLimit = async () => {
  if (!storeId.value || isSavingCreditLimit.value) return;
  const numericLimit = Number(globalCreditLimit.value);
  if (!Number.isFinite(numericLimit) || numericLimit < 0) {
    creditLimitError.value = 'El cupo por defecto debe ser mayor o igual a cero.';
    return;
  }

  isSavingCreditLimit.value = true;
  creditLimitError.value = null;
  try {
    const updated = await clientsStore.updateGlobalCreditLimit(storeId.value, numericLimit);
    globalCreditLimit.value = updated;
    showGlobalCreditModal.value = false;
    showSuccess('Cupo global por defecto actualizado (aplica a clientes nuevos)');
  } catch (e: any) {
    creditLimitError.value = e?.message || 'No se pudo guardar el cupo por defecto.';
  } finally {
    isSavingCreditLimit.value = false;
  }
};

const getInitials = (name: string) => {
  const parts = name.split(' ');
  if (parts.length >= 2) {
    return parts[0][0] + parts[1][0];
  }
  return name.substring(0, 2).toUpperCase();
};

const getColor = (name: string) => {
  const colors = [
    'bg-blue-100 text-blue-600 dark:bg-blue-900/30 dark:text-blue-400',
    'bg-purple-100 text-purple-600 dark:bg-purple-900/30 dark:text-purple-400',
    'bg-emerald-100 text-emerald-600 dark:bg-emerald-900/30 dark:text-emerald-400',
    'bg-orange-100 text-orange-600 dark:bg-orange-900/30 dark:text-orange-400',
    'bg-pink-100 text-pink-600 dark:bg-pink-900/30 dark:text-pink-400',
    'bg-cyan-100 text-cyan-600 dark:bg-cyan-900/30 dark:text-cyan-400',
  ];
  const index = name.charCodeAt(0) % colors.length;
  return colors[index];
};

const formatCurrency = (val: Decimal | number) => {
  return rawFormatCurrency(val instanceof Decimal ? val.toNumber() : val);
};

const formatCedula = (cedula: string) => {
  return cedula.replace(/\B(?=(\d{3})+(?!\d))/g, '.');
};

const goToDashboard = () => {
  router.push('/');
};

const openNewClient = () => {
  editingClientId.value = undefined;
  showClientModal.value = true;
};

const openClientDetail = (clientId: string) => {
  router.push(`/clients/${clientId}`);
};

const handleClientSaved = async (client: { id: string }, action: 'create' | 'update') => {
  showClientModal.value = false;
  await loadClients(true);
  if (action === 'create') {
    newlyCreatedId.value = client.id;
    setTimeout(() => {
      if (newlyCreatedId.value === client.id) {
        newlyCreatedId.value = null;
      }
    }, 3000);
  }
};
</script>

<template>
  <div class="flex flex-col h-screen bg-background-light dark:bg-background-dark pb-24">
    <header
      class="sticky top-0 z-30 bg-surface-light/95 dark:bg-surface-dark/95 backdrop-blur-sm border-b border-slate-200 dark:border-slate-800 pb-2"
    >
      <div class="flex items-center px-4 pt-4 pb-2 justify-between gap-2">
        <div class="flex items-center gap-2 min-w-0">
          <button
            type="button"
            @click="goToDashboard"
            aria-label="Volver al Dashboard"
            class="flex items-center justify-center -ml-2 p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer"
          >
            <ArrowLeft :size="24" :stroke-width="1.5" />
          </button>
          <h2 class="text-slate-900 dark:text-white text-xl font-bold truncate">Cartera de Clientes</h2>
        </div>

        <div class="flex items-center gap-2 shrink-0">
          <button
            v-if="canManageClients"
            type="button"
            data-testid="open-global-credit-modal-btn"
            @click="openGlobalCreditModal"
            class="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg border border-indigo-200 dark:border-indigo-800 bg-indigo-50 dark:bg-indigo-950/40 text-indigo-700 dark:text-indigo-300 text-xs font-bold hover:bg-indigo-100 dark:hover:bg-indigo-900/40 transition-colors cursor-pointer whitespace-nowrap"
          >
            <SlidersHorizontal :size="14" />
            Cupo Global
          </button>

          <div
            v-if="totalPortfolioDebt.gt(0)"
            data-testid="portfolio-total-debt-badge"
            class="bg-red-50 dark:bg-red-950/30 px-3 py-1.5 rounded-lg flex items-center gap-1.5 border border-red-200 dark:border-red-900/40"
          >
            <AlertTriangle :size="16" :stroke-width="1.5" class="text-red-500" />
            <span class="text-red-700 dark:text-red-300 text-xs font-bold whitespace-nowrap font-mono tabular-nums">
              Total: {{ formatCurrency(totalPortfolioDebt) }}
            </span>
          </div>
        </div>
      </div>

      <div class="px-4 py-2 space-y-2.5">
        <BaseInput
          v-model="searchQuery"
          placeholder="Buscar por nombre o cédula..."
        >
          <template #prefix>
            <Search :size="18" :stroke-width="1.5" class="text-slate-400" />
          </template>
        </BaseInput>

        <div class="flex flex-wrap items-center justify-between gap-2">
          <div class="flex items-center gap-1.5" role="group" aria-label="Filtro de estado de deuda">
            <button
              v-for="tab in [
                { value: 'all', label: 'Todos' },
                { value: 'with_debt', label: 'Con Deuda' },
                { value: 'up_to_date', label: 'Al Día' }
              ]"
              :key="tab.value"
              type="button"
              :data-testid="`filter-debt-${tab.value}`"
              @click="debtFilter = tab.value as ClientDebtFilter"
              class="px-3 py-1.5 rounded-full text-xs font-bold transition-colors cursor-pointer"
              :class="debtFilter === tab.value
                ? 'bg-primary text-white shadow-sm'
                : 'bg-background-light dark:bg-background-dark text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800'"
            >
              {{ tab.label }}
            </button>
          </div>

          <select
            v-model="orderBy"
            aria-label="Ordenar clientes"
            data-testid="client-order-select"
            class="h-8 px-2.5 rounded-xl border border-slate-200 dark:border-slate-700 bg-background-light dark:bg-background-dark text-xs font-semibold text-slate-700 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-primary"
          >
            <option value="name_asc">Nombre A-Z</option>
            <option value="name_desc">Nombre Z-A</option>
            <option value="balance_desc">Mayor Deuda</option>
            <option value="balance_asc">Menor Deuda</option>
          </select>
        </div>
      </div>
    </header>

    <!-- Loading State -->
    <div v-if="isLoadingPage" class="flex-1 overflow-y-auto px-4 py-4">
      <BaseListSkeleton :count="6" type="detail" />
    </div>

    <!-- Explicit Error State (Regla 3) -->
    <div
      v-else-if="fetchError"
      role="alert"
      data-testid="clients-error-banner"
      class="m-4 p-4 rounded-2xl bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800 space-y-3"
    >
      <p class="text-sm font-semibold text-red-700 dark:text-red-300">{{ fetchError }}</p>
      <BaseButton size="sm" variant="danger" @click="loadClients(true)">
        <RefreshCw :size="14" class="mr-1.5" />
        Reintentar
      </BaseButton>
    </div>

    <!-- Client List -->
    <main v-else-if="filteredClients.length > 0" class="flex-1 overflow-y-auto px-4 py-4 flex flex-col gap-3">
      <div class="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400 px-1 font-mono tabular-nums">
        <span>Mostrando {{ filteredClients.length }} de {{ totalClientsCount }} clientes</span>
        <span v-if="debtorsCount > 0">{{ debtorsCount }} con saldo</span>
      </div>

      <div
        v-for="client in filteredClients"
        :key="client.id"
        :data-testid="`client-card-${client.id}`"
        class="relative flex items-center gap-3 bg-surface-light dark:bg-surface-dark rounded-2xl shadow-sm p-3.5 border overflow-hidden cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-800/70 transition-colors active:scale-[0.99]"
        :class="[
          client.totalDebt.gt(0)
            ? 'border-red-200 dark:border-red-900/50'
            : 'border-slate-200 dark:border-slate-800',
          client.id === newlyCreatedId ? 'ring-2 ring-primary/40' : ''
        ]"
        @click="openClientDetail(client.id)"
      >
        <div
          class="h-12 w-12 shrink-0 rounded-2xl flex items-center justify-center font-bold text-lg"
          :class="getColor(client.name)"
        >
          {{ getInitials(client.name) }}
        </div>
        <div class="flex flex-1 flex-col justify-center min-w-0">
          <p class="text-slate-900 dark:text-white text-base font-bold truncate">
            {{ client.name }}
          </p>
          <p class="text-slate-500 dark:text-slate-400 text-xs font-medium truncate font-mono tabular-nums">
            CC: {{ formatCedula(client.cc) }}
          </p>
          <p class="text-[11px] text-slate-500 dark:text-slate-400 font-medium mt-0.5 font-mono tabular-nums" v-if="client.creditLimit">
            Cupo: {{ formatCurrency(new Decimal(client.creditLimit)) }}
          </p>
        </div>
        <div class="flex flex-col items-end gap-1">
          <p
            class="text-base font-bold leading-tight font-mono tabular-nums"
            :class="client.totalDebt.gt(0) ? 'text-red-600 dark:text-red-400' : 'text-emerald-600 dark:text-emerald-400'"
          >
            {{ client.totalDebt.gt(0) ? '-' : '' }}{{ formatCurrency(client.totalDebt.abs()) }}
          </p>
          <span v-if="client.totalDebt.gt(0)" class="text-[10px] text-red-500 font-bold uppercase tracking-wider">
            Debe
          </span>
          <span v-else class="text-[10px] text-emerald-600 font-bold uppercase tracking-wider"> Al día </span>
        </div>
        <ChevronRight :size="20" class="text-slate-300 dark:text-slate-600 shrink-0" />
      </div>

      <button
        v-if="hasMore"
        type="button"
        data-testid="load-more-clients-list-btn"
        :disabled="isLoadingMore"
        @click="loadClients(false)"
        class="w-full py-2.5 rounded-xl border border-slate-200 dark:border-slate-700 bg-surface-light dark:bg-surface-dark text-xs font-bold text-primary hover:bg-slate-50 dark:hover:bg-slate-800 flex items-center justify-center gap-2 transition-colors disabled:opacity-60 cursor-pointer"
      >
        <Loader2 v-if="isLoadingMore" :size="14" class="animate-spin" />
        <span>{{ isLoadingMore ? 'Cargando más...' : `Cargar más (${totalClientsCount - filteredClients.length} restantes)` }}</span>
      </button>
    </main>

    <!-- Empty State -->
    <BaseEmptyState
      v-else
      :title="searchQuery ? 'No se encontraron clientes' : 'Sin clientes registrados'"
      :description="searchQuery ? 'Intenta con otro término de búsqueda' : 'Agrega tu primer cliente para comenzar'"
      :icon="Users"
      :action-label="!searchQuery && canManageClients ? 'Agregar Cliente' : undefined"
      @action="openNewClient"
    />

    <!-- FAB -->
    <div class="absolute bottom-24 right-4 z-40">
      <button
        v-if="canManageClients"
        type="button"
        aria-label="Nuevo cliente"
        @click="openNewClient"
        class="flex h-14 w-14 items-center justify-center rounded-2xl bg-primary text-white shadow-lg hover:bg-blue-600 transition-all active:scale-90 cursor-pointer"
      >
        <Plus :size="32" :stroke-width="1.5" />
      </button>
    </div>

    <BottomNav />

    <!-- Client Form Modal -->
    <ClientFormModal
      v-model="showClientModal"
      :client-id="editingClientId"
      @saved="handleClientSaved"
    />

    <!-- Política de Cupo Global Modal (Admin-only, C4) -->
    <BaseModal
      v-model="showGlobalCreditModal"
      title="Cupo de Crédito Global por Defecto"
      :showCloseButton="true"
      maxHeight="70vh"
    >
      <div class="p-4 space-y-4">
        <p class="text-xs text-slate-600 dark:text-slate-300">
          Se precarga únicamente al registrar clientes nuevos. No altera el cupo individual de clientes existentes.
        </p>

        <div
          v-if="creditLimitError"
          role="alert"
          data-testid="global-credit-limit-error"
          class="p-3 rounded-xl bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800 text-xs font-semibold text-red-700 dark:text-red-300"
        >
          {{ creditLimitError }}
        </div>

        <div>
          <label class="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
            Cupo por defecto (COP)
          </label>
          <div class="relative">
            <span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 font-bold">$</span>
            <input
              v-model.number="globalCreditLimit"
              data-testid="global-credit-limit-input"
              type="number"
              min="0"
              step="1000"
              :disabled="isLoadingCreditLimit || isSavingCreditLimit"
              class="w-full h-11 pl-7 pr-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-background-light dark:bg-background-dark text-sm font-bold font-mono tabular-nums text-slate-900 dark:text-white focus:ring-2 focus:ring-primary outline-none"
            />
          </div>
        </div>
      </div>

      <template #footer>
        <div class="p-4 pt-2 border-t border-slate-100 dark:border-slate-800 flex gap-3">
          <BaseButton
            type="button"
            variant="secondary"
            class="flex-1"
            :disabled="isSavingCreditLimit"
            @click="showGlobalCreditModal = false"
          >
            Cancelar
          </BaseButton>
          <BaseButton
            type="button"
            variant="primary"
            class="flex-1"
            data-testid="save-global-credit-limit-btn"
            :loading="isSavingCreditLimit"
            :disabled="isLoadingCreditLimit || isSavingCreditLimit"
            @click="saveGlobalCreditLimit"
          >
            {{ isSavingCreditLimit ? 'Guardando...' : 'Guardar Cupo' }}
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>

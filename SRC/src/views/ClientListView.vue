<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useClientsStore } from '../stores/clients';
import { useAuthStore } from '../stores/auth';
import BottomNav from '../components/BottomNav.vue';
import ClientFormModal from '../components/ClientFormModal.vue';
import { Decimal } from 'decimal.js';
import BaseInput from '@/components/ui/BaseInput.vue';
import BaseButton from '@/components/ui/BaseButton.vue';
import Skeleton from '@/components/ui/Skeleton.vue';
import { 
  ArrowLeft, 
  Search, 
  AlertTriangle, 
  Users, 
  UserPlus, 
  ChevronRight, 
  Plus 
} from 'lucide-vue-next';

const router = useRouter();
const clientsStore = useClientsStore();
const authStore = useAuthStore();

// State
const searchQuery = ref('');
const showClientModal = ref(false);
// WO-001: Changed from number to string for UUID
const editingClientId = ref<string | undefined>(undefined);

// Computed
const filteredClients = computed(() => {
  return clientsStore.searchClients(searchQuery.value);
});

const totalDebt = computed(() => {
  return clientsStore.totalDebt;
});

const canManageClients = computed(
  () => authStore.isAdmin || authStore.currentUser?.permissions?.canManageClients,
);

// Generate initials and color from name
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

// Methods
const formatCurrency = (val: Decimal) => {
  return `$${val
    .toDecimalPlaces(0)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`;
};

const formatCedula = (cedula: string) => {
  // Format as 1.020.304
  return cedula.replace(/\B(?=(\d{3})+(?!\d))/g, '.');
};

const goToDashboard = () => {
  router.push('/');
};

const openNewClient = () => {
  editingClientId.value = undefined;
  showClientModal.value = true;
};

// WO-001: Changed parameter type from number to string
const openClientDetail = (clientId: string) => {
  router.push(`/clients/${clientId}`);
};

const handleClientSaved = () => {
  showClientModal.value = false;
};

// WO: initializeSampleData eliminada - SPEC-007
</script>

<template>
  <div class="flex flex-col h-screen bg-background-light dark:bg-background-dark pb-24">
    <header
      class="sticky top-0 z-30 bg-background-light/95 dark:bg-background-dark/95 backdrop-blur-sm border-b border-gray-200 dark:border-gray-800 pb-2"
    >
      <div class="flex items-center px-4 pt-4 pb-2 justify-between">
        <div class="flex items-center gap-2">
          <button
            @click="goToDashboard"
            aria-label="Volver al Dashboard"
            class="flex items-center justify-center -ml-2 p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          >
            <ArrowLeft :size="24" :stroke-width="1.5" />
          </button>
          <h2 class="text-slate-900 dark:text-white text-xl font-bold">Cartera de Clientes</h2>
        </div>
        <div
          v-if="totalDebt.gt(0)"
          class="bg-red-50 dark:bg-red-900/20 px-3 py-1.5 rounded-lg flex items-center gap-1.5 border border-red-100 dark:border-red-900/30"
        >
          <AlertTriangle :size="16" :stroke-width="1.5" class="text-red-500" />
          <span class="text-red-700 dark:text-red-300 text-xs font-bold whitespace-nowrap">
            Total: {{ formatCurrency(totalDebt) }}
          </span>
        </div>
      </div>
      <div class="px-4 py-2">
           <BaseInput
             v-model="searchQuery"
             placeholder="Buscar por nombre o cédula..."
           >
             <template #prefix>
                <Search :size="18" :stroke-width="1.5" class="text-slate-400" />
             </template>
           </BaseInput>
      </div>
    </header>



    <!-- Loading State -->
    <div v-if="clientsStore.isLoading" class="flex-1 overflow-y-auto px-4 py-4 flex flex-col gap-3">
        <div v-for="i in 6" :key="i" class="flex items-center gap-3 bg-white dark:bg-slate-800 rounded-2xl shadow-sm p-3 border-l-[6px] border-slate-200 dark:border-slate-700">
             <Skeleton width="48px" height="48px" border-radius="18px" />
             <div class="flex flex-1 flex-col justify-center min-w-0 gap-2">
                <Skeleton width="60%" height="1rem" />
                <Skeleton width="40%" height="0.75rem" />
             </div>
             <div class="flex flex-col items-end gap-1">
                <Skeleton width="80px" height="1.25rem" />
                <Skeleton width="40px" height="0.75rem" />
             </div>
        </div>
    </div>

    <!-- Client List -->
    <main v-else-if="filteredClients.length > 0" class="flex-1 overflow-y-auto px-4 py-4 flex flex-col gap-3">
      <div
        v-for="client in filteredClients"
        :key="client.id"
        class="relative flex items-center gap-3 bg-white dark:bg-slate-800 rounded-2xl shadow-sm p-3 border-l-[6px] overflow-hidden cursor-pointer hover:bg-gray-50 dark:hover:bg-slate-700/50 transition-colors active:scale-[0.99]"
        :class="client.balance.gt(0) ? 'border-red-500' : 'border-emerald-500'"
        @click="openClientDetail(client.id)"
      >
        <div
          class="h-12 w-12 shrink-0 rounded-[18px] flex items-center justify-center font-bold text-lg"
          :class="getColor(client.name)"
        >
          {{ getInitials(client.name) }}
        </div>
        <div class="flex flex-1 flex-col justify-center min-w-0">
          <p class="text-slate-900 dark:text-white text-base font-bold truncate">
            {{ client.name }}
          </p>
          <p class="text-slate-500 text-xs font-medium truncate">
            CC: {{ formatCedula(client.cedula) }}
          </p>
          <!-- CL-01: Show Cupo -->
           <p class="text-[10px] text-slate-400 font-medium mt-0.5" v-if="client.creditLimit">
            Cupo: {{ formatCurrency(new Decimal(client.creditLimit)) }}
          </p>
        </div>
        <div class="flex flex-col items-end gap-1">
          <p
            class="text-base font-bold leading-tight"
            :class="client.balance.gt(0) ? 'text-red-600' : 'text-emerald-600'"
          >
            {{ client.balance.gt(0) ? '-' : '' }}{{ formatCurrency(client.balance.abs()) }}
          </p>
          <span v-if="client.balance.gt(0)" class="text-[10px] text-red-500 font-bold uppercase tracking-wider">
            Debe
          </span>
          <span v-else class="text-[10px] text-emerald-600 font-bold uppercase tracking-wider"> Al día </span>
        </div>
        <ChevronRight :size="20" class="text-slate-300" />
      </div>
    </main>

    <!-- Empty State -->
    <div
      v-else
      class="flex-1 flex flex-col items-center justify-center px-4 text-center"
    >
      <Users :size="64" :stroke-width="1" class="text-slate-300 mb-4" />
      <h3 class="text-lg font-bold text-slate-900 dark:text-white mb-2">
        {{ searchQuery ? 'No se encontraron clientes' : 'Sin clientes registrados' }}
      </h3>
      <p class="text-sm text-slate-500 dark:text-slate-400 max-w-xs">
        {{
          searchQuery
            ? 'Intenta con otro término de búsqueda'
            : 'Agrega tu primer cliente para comenzar'
        }}
      </p>
      <BaseButton
        v-if="!searchQuery && canManageClients"
        @click="openNewClient"
        class="mt-6"
      >
        <UserPlus :size="18" class="mr-2" />
        Agregar Cliente
      </BaseButton>
    </div>

    <!-- FAB -->
    <div class="absolute bottom-24 right-4 z-40">
      <button
        v-if="canManageClients"
        @click="openNewClient"
        class="flex h-14 w-14 items-center justify-center rounded-2xl bg-primary text-white shadow-lg hover:bg-blue-600 transition-all active:scale-90"
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
  </div>
</template>

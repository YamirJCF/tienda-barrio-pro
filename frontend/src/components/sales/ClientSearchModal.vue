<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue';
import { useClientsStore } from '../../stores/clients';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import type { Client } from '../../types';
import Decimal from 'decimal.js';
import BaseModal from '../ui/BaseModal.vue';
import { 
  Search, 
  X, 
  UserCheck, 
  UserX, 
  Loader2, 
  AlertTriangle,
  CheckCircle2,
  Phone,
  CreditCard
} from 'lucide-vue-next';

interface Props {
  modelValue: boolean;
  selectedClientId?: string | null;
  saleTotal?: Decimal;
}

const props = withDefaults(defineProps<Props>(), {
  selectedClientId: null,
  saleTotal: () => new Decimal(0)
});

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'select': [client: Client];
}>();

const clientsStore = useClientsStore();
const { formatCurrency: rawFormatCurrency } = useCurrencyFormat();

const searchQuery = ref('');
const searchInputRef = ref<HTMLInputElement | null>(null);
const activeFilter = ref<'all' | 'with_debt' | 'up_to_date'>('all');

const formatCurrency = (val: Decimal | number | undefined) => {
  if (val === undefined) return '$0';
  return rawFormatCurrency(val instanceof Decimal ? val.toNumber() : val);
};

const formatCedula = (cedula: string) => {
  if (!cedula) return '';
  return cedula.replace(/\B(?=(\d{3})+(?!\d))/g, '.');
};

const getInitials = (name: string) => {
  if (!name) return '??';
  const parts = name.trim().split(' ');
  if (parts.length >= 2) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return name.substring(0, 2).toUpperCase();
};

const getAvatarColor = (name: string) => {
  const colors = [
    'bg-blue-100 text-blue-700 dark:bg-blue-900/40 dark:text-blue-300 border-blue-200 dark:border-blue-700',
    'bg-indigo-100 text-indigo-700 dark:bg-indigo-900/40 dark:text-indigo-300 border-indigo-200 dark:border-indigo-700',
    'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/40 dark:text-emerald-300 border-emerald-200 dark:border-emerald-700',
    'bg-purple-100 text-purple-700 dark:bg-purple-900/40 dark:text-purple-300 border-purple-200 dark:border-purple-700',
    'bg-amber-100 text-amber-700 dark:bg-amber-900/40 dark:text-amber-300 border-amber-200 dark:border-amber-700',
  ];
  const charCode = (name || 'A').charCodeAt(0);
  return colors[charCode % colors.length];
};

const filteredClients = computed(() => {
  const searched = clientsStore.searchClients(searchQuery.value);
  if (activeFilter.value === 'with_debt') {
    return searched.filter(c => c.totalDebt && c.totalDebt.gt(0));
  }
  if (activeFilter.value === 'up_to_date') {
    return searched.filter(c => !c.totalDebt || c.totalDebt.lte(0));
  }
  return searched;
});

const selectClient = (client: Client) => {
  emit('select', client);
  emit('update:modelValue', false);
};

const close = () => {
  emit('update:modelValue', false);
};

watch(() => props.modelValue, (isOpen) => {
  if (isOpen) {
    searchQuery.value = '';
    activeFilter.value = 'all';
    nextTick(() => {
      setTimeout(() => {
        searchInputRef.value?.focus();
      }, 100);
    });
  }
});
</script>

<template>
  <BaseModal
    :modelValue="modelValue"
    title="Seleccionar Cliente para Fiado"
    maxHeight="85vh"
    :showCloseButton="true"
    @update:modelValue="close"
  >
    <div class="flex flex-col h-[70vh] max-h-[680px]">
      
      <!-- 1. Search Box & Filter Chips -->
      <div class="p-4 border-b border-gray-100 dark:border-gray-800 bg-gray-50/50 dark:bg-surface-dark/50 space-y-3 shrink-0">
        <!-- Search Input -->
        <div class="relative flex items-center w-full">
          <Search :size="20" class="absolute left-3.5 text-gray-400 pointer-events-none" />
          <input
            ref="searchInputRef"
            v-model="searchQuery"
            type="text"
            placeholder="Buscar por nombre, cédula o teléfono..."
            class="w-full h-12 pl-11 pr-10 rounded-xl bg-white dark:bg-background-dark border border-gray-200 dark:border-gray-700 text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 transition-all text-sm font-medium"
          />
          <button
            v-if="searchQuery"
            @click="searchQuery = ''"
            class="absolute right-3 p-1 text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 rounded-full"
            aria-label="Limpiar búsqueda"
          >
            <X :size="16" />
          </button>
        </div>

        <!-- Filter Chips -->
        <div class="flex items-center gap-2 overflow-x-auto pb-1 text-xs font-semibold">
          <button
            @click="activeFilter = 'all'"
            class="px-3 py-1.5 rounded-full transition-all shrink-0"
            :class="activeFilter === 'all'
              ? 'bg-indigo-600 text-white shadow-sm'
              : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 border border-gray-200 dark:border-gray-700 hover:border-indigo-300'"
          >
            Todos ({{ clientsStore.clients.length }})
          </button>
          <button
            @click="activeFilter = 'with_debt'"
            class="px-3 py-1.5 rounded-full transition-all shrink-0 flex items-center gap-1"
            :class="activeFilter === 'with_debt'
              ? 'bg-red-600 text-white shadow-sm'
              : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 border border-gray-200 dark:border-gray-700 hover:border-red-300'"
          >
            <span>Con Deuda</span>
            <span class="text-[10px] px-1.5 py-0.2 bg-red-100 dark:bg-red-900/50 text-red-600 dark:text-red-300 rounded-full">
              {{ clientsStore.clientsWithDebt.length }}
            </span>
          </button>
          <button
            @click="activeFilter = 'up_to_date'"
            class="px-3 py-1.5 rounded-full transition-all shrink-0"
            :class="activeFilter === 'up_to_date'
              ? 'bg-emerald-600 text-white shadow-sm'
              : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 border border-gray-200 dark:border-gray-700 hover:border-emerald-300'"
          >
            Al Día
          </button>
        </div>
      </div>

      <!-- 2. Body List Area (Dedicated Scroll) -->
      <div class="flex-1 overflow-y-auto p-4 space-y-2.5 min-h-0">
        
        <!-- Loading State -->
        <div v-if="clientsStore.isLoading" class="flex flex-col items-center justify-center py-16 gap-3 text-gray-400">
          <Loader2 :size="36" class="animate-spin text-indigo-500" />
          <p class="text-sm font-medium">Cargando cartera de clientes...</p>
        </div>

        <!-- Empty State -->
        <div v-else-if="filteredClients.length === 0" class="flex flex-col items-center justify-center py-12 px-4 text-center">
          <div class="w-16 h-16 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center text-gray-400 mb-3">
            <UserX :size="32" />
          </div>
          <p class="text-base font-bold text-gray-800 dark:text-gray-200 mb-1">
            {{ searchQuery ? `Sin resultados para "${searchQuery}"` : 'No hay clientes registrados' }}
          </p>
          <p class="text-xs text-gray-500 max-w-xs leading-relaxed">
            {{ searchQuery ? 'Intenta buscar por otro término o cédula.' : 'Agrega clientes desde la sección de Cartera para habilitar el fiado.' }}
          </p>
        </div>

        <!-- Client Cards -->
        <div
          v-else
          v-for="client in filteredClients"
          :key="client.id"
          @click="selectClient(client)"
          class="p-3.5 rounded-xl border transition-all cursor-pointer text-left relative flex flex-col gap-2.5 active:scale-[0.99]"
          :class="[
            selectedClientId === client.id
              ? 'bg-indigo-50 dark:bg-indigo-950/40 border-indigo-500 ring-2 ring-indigo-500/20'
              : 'bg-white dark:bg-surface-dark border-gray-200 dark:border-gray-700 hover:border-indigo-300 hover:shadow-sm'
          ]"
        >
          <!-- Top Row: Avatar + Name + CC + Check -->
          <div class="flex items-center justify-between gap-3">
            <div class="flex items-center gap-3 min-w-0">
              <!-- Avatar -->
              <div
                class="w-11 h-11 rounded-full border-2 flex items-center justify-center font-bold text-sm shrink-0"
                :class="getAvatarColor(client.name)"
              >
                {{ getInitials(client.name) }}
              </div>

              <!-- Info -->
              <div class="min-w-0">
                <div class="flex items-center gap-2">
                  <h4 class="font-bold text-gray-900 dark:text-white text-base truncate">
                    {{ client.name }}
                  </h4>
                  <span
                    v-if="selectedClientId === client.id"
                    class="px-2 py-0.5 rounded-full bg-indigo-600 text-white text-[10px] font-bold shrink-0 flex items-center gap-1"
                  >
                    <CheckCircle2 :size="10" />
                    Actual
                  </span>
                </div>
                <div class="flex items-center gap-3 text-xs text-gray-500 mt-0.5">
                  <span v-if="client.cc">CC: {{ formatCedula(client.cc) }}</span>
                  <span v-if="client.phone" class="flex items-center gap-1 truncate">
                    <Phone :size="12" class="text-gray-400" />
                    {{ client.phone }}
                  </span>
                </div>
              </div>
            </div>

            <!-- Action Tag -->
            <div class="shrink-0">
              <span class="text-xs font-bold text-indigo-600 dark:text-indigo-400 flex items-center gap-1">
                Elegir &rarr;
              </span>
            </div>
          </div>

          <!-- Bottom Row: Financial Status Strip -->
          <div class="grid grid-cols-2 gap-2 pt-2 border-t border-gray-100 dark:border-gray-800 text-xs">
            <!-- Cupo Disponible -->
            <div class="flex flex-col">
              <span class="text-[10px] font-bold text-gray-400 uppercase tracking-wide">Cupo Límite</span>
              <span class="font-bold text-emerald-600 dark:text-emerald-400">
                {{ formatCurrency(client.creditLimit) }}
              </span>
            </div>

            <!-- Deuda Actual -->
            <div class="flex flex-col text-right">
              <span class="text-[10px] font-bold text-gray-400 uppercase tracking-wide">Deuda Actual</span>
              <span
                class="font-bold"
                :class="client.totalDebt && client.totalDebt.gt(0) ? 'text-red-600 dark:text-red-400' : 'text-gray-600 dark:text-gray-300'"
              >
                {{ client.totalDebt && client.totalDebt.gt(0) ? formatCurrency(client.totalDebt) : '$0 (Al día)' }}
              </span>
            </div>
          </div>
        </div>

      </div>

    </div>
  </BaseModal>
</template>

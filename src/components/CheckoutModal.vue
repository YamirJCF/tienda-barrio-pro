<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useCartStore } from '../stores/cart';
import { useClientsStore, type Client } from '../stores/clients';
import Decimal from 'decimal.js';

// Props
interface Props {
  modelValue: boolean;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'complete': [paymentMethod: string, amountReceived?: Decimal, clientId?: number];
}>();

// Store
const cartStore = useCartStore();
const clientsStore = useClientsStore();

// State
type PaymentMethod = 'cash' | 'nequi' | 'fiado';
const activeMethod = ref<PaymentMethod>('cash');
const amountReceived = ref('');
const nequiReference = ref('');
const selectedClient = ref<Client | null>(null);
const clientSearch = ref('');

// Initialize clients
onMounted(() => {
  clientsStore.initializeSampleData();
});

// Computed
const total = computed(() => cartStore.total);
const formattedTotal = computed(() => cartStore.formattedTotal);

const change = computed(() => {
  if (!amountReceived.value || activeMethod.value !== 'cash') {
    return new Decimal(0);
  }
  const received = new Decimal(amountReceived.value);
  return received.minus(total.value);
});

const formattedChange = computed(() => {
  return `$ ${change.value.toDecimalPlaces(0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".")}`;
});

const formattedAmountReceived = computed(() => {
  if (!amountReceived.value) return '$ 0';
  return `$ ${new Decimal(amountReceived.value).toDecimalPlaces(0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".")}`;
});

const canComplete = computed(() => {
  if (activeMethod.value === 'cash') {
    return amountReceived.value && change.value.greaterThanOrEqualTo(0);
  }
  if (activeMethod.value === 'fiado') {
    return selectedClient.value !== null;
  }
  return true;
});

// Filtered clients for fiado
const filteredClients = computed(() => {
  return clientsStore.searchClients(clientSearch.value);
});

// Get available credit for selected client
const selectedClientCredit = computed(() => {
  if (!selectedClient.value) return new Decimal(0);
  return clientsStore.getAvailableCredit(selectedClient.value.id);
});

const hasEnoughCredit = computed(() => {
  return selectedClientCredit.value.gte(total.value);
});

// Methods
const close = () => {
  emit('update:modelValue', false);
};

const handleNumpad = (value: string) => {
  if (value === 'backspace') {
    amountReceived.value = amountReceived.value.slice(0, -1);
  } else if (value === '000') {
    amountReceived.value += '000';
  } else {
    amountReceived.value += value;
  }
};

const useExactAmount = () => {
  amountReceived.value = total.value.toString();
};

const selectMethod = (method: PaymentMethod) => {
  activeMethod.value = method;
  if (method !== 'cash') {
    amountReceived.value = '';
  }
  if (method !== 'fiado') {
    selectedClient.value = null;
    clientSearch.value = '';
  }
};

const selectClient = (client: Client) => {
  selectedClient.value = client;
  clientSearch.value = '';
};

const clearSelectedClient = () => {
  selectedClient.value = null;
};

const completeSale = () => {
  if (!canComplete.value) return;
  
  const receivedAmount = activeMethod.value === 'cash' 
    ? new Decimal(amountReceived.value) 
    : undefined;
  
  const clientId = activeMethod.value === 'fiado' && selectedClient.value
    ? selectedClient.value.id
    : undefined;
  
  emit('complete', activeMethod.value, receivedAmount, clientId);
  
  // Reset
  amountReceived.value = '';
  nequiReference.value = '';
  selectedClient.value = null;
  clientSearch.value = '';
  activeMethod.value = 'cash';
  close();
};
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div
        v-if="modelValue"
        class="fixed inset-0 z-50 flex flex-col justify-end bg-gray-900/40"
        @click.self="close"
      >
        <!-- Modal Container -->
        <div class="relative w-full bg-surface-light dark:bg-surface-dark rounded-t-2xl shadow-2xl flex flex-col h-[85vh] md:h-[75vh] max-h-[800px] overflow-hidden animate-slide-up">
          <!-- Drag Handle -->
          <div class="w-full flex justify-center pt-3 pb-1 cursor-grab active:cursor-grabbing" @click="close">
            <div class="h-1.5 w-12 rounded-full bg-gray-300 dark:bg-gray-600"></div>
          </div>

          <!-- Header (Total Summary) -->
          <header class="flex flex-col items-center justify-center py-4 bg-gray-50 dark:bg-background-dark border-b border-gray-100 dark:border-gray-800">
            <h3 class="text-gray-500 dark:text-gray-400 text-sm font-semibold tracking-wide uppercase mb-1">
              Total a Pagar
            </h3>
            <div class="flex items-baseline gap-1">
              <span class="text-3xl font-bold text-gray-800 dark:text-white">$</span>
              <span class="text-4xl font-black text-gray-900 dark:text-accent-green tracking-tight">
                {{ total.toDecimalPlaces(0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".") }}
              </span>
            </div>
          </header>

          <!-- Payment Method Tabs -->
          <div class="grid grid-cols-3 w-full border-b border-gray-200 dark:border-gray-700 bg-white dark:bg-surface-dark">
            <!-- Efectivo Tab -->
            <button
              class="relative flex flex-col items-center justify-center py-3 gap-1 group"
              :class="activeMethod === 'cash' ? '' : 'opacity-60 hover:opacity-100 transition-opacity'"
              @click="selectMethod('cash')"
            >
              <span
                class="material-symbols-outlined text-[28px]"
                :class="activeMethod === 'cash' ? 'text-emerald-600 dark:text-accent-green' : 'text-gray-400 dark:text-gray-500'"
              >
                payments
              </span>
              <span
                class="text-xs font-bold tracking-wide"
                :class="activeMethod === 'cash' ? 'text-emerald-800 dark:text-emerald-100' : 'text-gray-500 dark:text-gray-400'"
              >
                Efectivo
              </span>
              <!-- Active Indicator -->
              <div v-if="activeMethod === 'cash'" class="absolute bottom-0 w-full h-[4px] bg-emerald-500 dark:bg-accent-green rounded-t-full"></div>
              <div v-if="activeMethod === 'cash'" class="absolute inset-0 bg-emerald-50/50 dark:bg-accent-green/5 opacity-100"></div>
            </button>

            <!-- Nequi Tab -->
            <button
              class="relative flex flex-col items-center justify-center py-3 gap-1 group"
              :class="activeMethod === 'nequi' ? '' : 'opacity-60 hover:opacity-100 transition-opacity'"
              @click="selectMethod('nequi')"
            >
              <span
                class="material-symbols-outlined text-[28px]"
                :class="activeMethod === 'nequi' ? 'text-pink-600 dark:text-pink-400' : 'text-gray-400 dark:text-gray-500'"
              >
                smartphone
              </span>
              <span
                class="text-xs font-bold tracking-wide"
                :class="activeMethod === 'nequi' ? 'text-pink-800 dark:text-pink-100' : 'text-gray-500 dark:text-gray-400'"
              >
                Nequi
              </span>
              <div v-if="activeMethod === 'nequi'" class="absolute bottom-0 w-full h-[4px] bg-pink-500 rounded-t-full"></div>
              <div v-if="activeMethod === 'nequi'" class="absolute inset-0 bg-pink-50/50 dark:bg-pink-900/5 opacity-100"></div>
            </button>

            <!-- Fiado Tab -->
            <button
              class="relative flex flex-col items-center justify-center py-3 gap-1 group"
              :class="activeMethod === 'fiado' ? '' : 'opacity-60 hover:opacity-100 transition-opacity'"
              @click="selectMethod('fiado')"
            >
              <span
                class="material-symbols-outlined text-[28px]"
                :class="activeMethod === 'fiado' ? 'text-amber-600 dark:text-amber-400' : 'text-gray-400 dark:text-gray-500'"
              >
                menu_book
              </span>
              <span
                class="text-xs font-bold tracking-wide"
                :class="activeMethod === 'fiado' ? 'text-amber-800 dark:text-amber-100' : 'text-gray-500 dark:text-gray-400'"
              >
                Fiado
              </span>
              <div v-if="activeMethod === 'fiado'" class="absolute bottom-0 w-full h-[4px] bg-amber-500 rounded-t-full"></div>
              <div v-if="activeMethod === 'fiado'" class="absolute inset-0 bg-amber-50/50 dark:bg-amber-900/5 opacity-100"></div>
            </button>
          </div>

          <!-- Dynamic Body Content -->
          <main class="flex-1 overflow-y-auto p-4 flex flex-col">
            <!-- Cash Payment View -->
            <div v-if="activeMethod === 'cash'" class="flex flex-1 flex-col gap-4 h-full">
              <div class="grid grid-cols-12 gap-4 flex-1">
                <!-- Left Column: Input & Feedback -->
                <div class="col-span-5 flex flex-col gap-3 justify-center">
                  <label class="block">
                    <span class="text-gray-600 dark:text-gray-300 text-sm font-medium mb-1.5 block ml-1">
                      Dinero Recibido
                    </span>
                    <!-- Input Display Box -->
                    <div class="relative flex items-center w-full h-16 px-3 bg-white dark:bg-background-dark border-[3px] border-sky-500 rounded-xl shadow-sm ring-4 ring-sky-100 dark:ring-sky-900/20">
                      <span class="text-gray-400 text-xl font-bold mr-1">$</span>
                      <span class="text-2xl font-bold text-gray-900 dark:text-white truncate">
                        {{ amountReceived || '0' }}
                      </span>
                      <span class="absolute right-3 w-2 h-6 bg-sky-500 animate-pulse"></span>
                    </div>
                  </label>

                  <!-- Feedback Box (Calculated Change) -->
                  <div
                    v-if="amountReceived"
                    class="w-full border rounded-lg p-3 flex flex-col items-start justify-center"
                    :class="change.greaterThanOrEqualTo(0) 
                      ? 'bg-emerald-100 dark:bg-emerald-900/30 border-emerald-200 dark:border-emerald-800' 
                      : 'bg-red-100 dark:bg-red-900/30 border-red-200 dark:border-red-800'"
                  >
                    <span
                      class="text-xs font-bold uppercase tracking-wider"
                      :class="change.greaterThanOrEqualTo(0) 
                        ? 'text-emerald-700 dark:text-emerald-400' 
                        : 'text-red-700 dark:text-red-400'"
                    >
                      {{ change.greaterThanOrEqualTo(0) ? 'Vueltos a dar' : 'Falta' }}
                    </span>
                    <div
                      class="text-xl font-black mt-0.5"
                      :class="change.greaterThanOrEqualTo(0) 
                        ? 'text-emerald-800 dark:text-emerald-300' 
                        : 'text-red-800 dark:text-red-300'"
                    >
                      {{ formattedChange }}
                    </div>
                  </div>

                  <!-- Quick Action for exact cash -->
                  <button
                    class="mt-auto py-2 px-3 rounded-lg border border-dashed border-gray-300 dark:border-gray-600 text-gray-500 dark:text-gray-400 text-xs font-medium hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors text-center"
                    @click="useExactAmount"
                  >
                    Usar monto exacto
                  </button>
                </div>

                <!-- Right Column: Numpad -->
                <div class="col-span-7 pl-2">
                  <div class="grid grid-cols-3 gap-2.5 h-full max-h-[320px]">
                    <!-- Numbers 1-9 -->
                    <button
                      v-for="num in [1, 2, 3, 4, 5, 6, 7, 8, 9]"
                      :key="num"
                      class="flex items-center justify-center rounded-lg bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white text-xl font-bold shadow-sm active:translate-y-0.5 active:shadow-none transition-all touch-manipulation"
                      @click="handleNumpad(num.toString())"
                    >
                      {{ num }}
                    </button>

                    <!-- Bottom row: 000, 0, Backspace -->
                    <button
                      class="flex items-center justify-center rounded-lg bg-gray-200 dark:bg-gray-700 text-gray-900 dark:text-white text-lg font-bold shadow-sm active:translate-y-0.5 active:shadow-none transition-all touch-manipulation tracking-tighter"
                      @click="handleNumpad('000')"
                    >
                      000
                    </button>
                    <button
                      class="flex items-center justify-center rounded-lg bg-gray-100 dark:bg-gray-800 text-gray-900 dark:text-white text-xl font-bold shadow-sm active:translate-y-0.5 active:shadow-none transition-all touch-manipulation"
                      @click="handleNumpad('0')"
                    >
                      0
                    </button>
                    <button
                      class="flex items-center justify-center rounded-lg bg-rose-100 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400 text-xl font-bold shadow-sm active:translate-y-0.5 active:shadow-none transition-all touch-manipulation"
                      @click="handleNumpad('backspace')"
                    >
                      <span class="material-symbols-outlined">backspace</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <!-- Nequi Payment View -->
            <div v-else-if="activeMethod === 'nequi'" class="flex flex-col items-center justify-center gap-6 h-full py-8 text-center">
              <div class="w-24 h-24 bg-pink-100 dark:bg-pink-900/20 rounded-full flex items-center justify-center mb-2">
                <span class="material-symbols-outlined text-pink-600 dark:text-pink-400 text-[48px]">qr_code_2</span>
              </div>
              <div>
                <h4 class="text-lg font-bold text-gray-900 dark:text-white mb-2">Pago con Nequi / Daviplata</h4>
                <p class="text-gray-500 dark:text-gray-400 max-w-[260px] mx-auto text-sm leading-relaxed">
                  Solicita al cliente el pago exacto de <strong class="text-gray-900 dark:text-white">{{ formattedTotal }}</strong>.
                </p>
              </div>
              <div class="w-full max-w-xs mt-4">
                <label class="block text-left mb-1 text-xs font-semibold text-gray-500 uppercase">
                  Referencia (Opcional)
                </label>
                <input
                  v-model="nequiReference"
                  class="w-full h-12 rounded-lg border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 text-center text-lg font-medium focus:ring-pink-500 focus:border-pink-500"
                  placeholder="Últimos 4 dígitos"
                  type="number"
                  maxlength="4"
                />
              </div>
            </div>

            <!-- Fiado Payment View -->
            <div v-else-if="activeMethod === 'fiado'" class="flex flex-col gap-4 h-full">
              <!-- Selected Client Card -->
              <div v-if="selectedClient" class="bg-amber-50 dark:bg-amber-900/20 rounded-xl p-4 border border-amber-200 dark:border-amber-800">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-3">
                    <div class="w-12 h-12 rounded-full bg-amber-200 dark:bg-amber-800 flex items-center justify-center text-amber-800 dark:text-amber-200 font-bold text-lg">
                      {{ selectedClient.name.split(' ').map(n => n[0]).join('').substring(0, 2) }}
                    </div>
                    <div>
                      <p class="font-bold text-gray-900 dark:text-white">{{ selectedClient.name }}</p>
                      <p class="text-xs text-gray-500">C.C. {{ selectedClient.cedula }}</p>
                    </div>
                  </div>
                  <button 
                    @click="clearSelectedClient"
                    class="p-2 text-gray-400 hover:text-red-500 transition-colors"
                  >
                    <span class="material-symbols-outlined">close</span>
                  </button>
                </div>
                <!-- Credit Info -->
                <div class="mt-3 pt-3 border-t border-amber-200 dark:border-amber-700 flex justify-between text-sm">
                  <span class="text-gray-600 dark:text-gray-400">Crédito disponible:</span>
                  <span 
                    class="font-bold"
                    :class="hasEnoughCredit ? 'text-emerald-600' : 'text-red-500'"
                  >
                    ${{ selectedClientCredit.toDecimalPlaces(0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".") }}
                  </span>
                </div>
                <p v-if="!hasEnoughCredit" class="mt-2 text-xs text-red-500 flex items-center gap-1">
                  <span class="material-symbols-outlined text-sm">warning</span>
                  El cliente excederá su límite de crédito
                </p>
              </div>

              <!-- Client Search -->
              <div v-if="!selectedClient">
                <label class="block text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2">
                  Seleccionar Cliente
                </label>
                <div class="relative">
                  <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400">
                    <span class="material-symbols-outlined text-[20px]">search</span>
                  </span>
                  <input
                    v-model="clientSearch"
                    type="text"
                    class="w-full h-12 pl-10 pr-4 rounded-xl border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-amber-500 focus:border-amber-500"
                    placeholder="Buscar por nombre o cédula..."
                  />
                </div>
              </div>

              <!-- Client List -->
              <div v-if="!selectedClient" class="flex-1 overflow-y-auto -mx-4 px-4">
                <div v-if="filteredClients.length === 0" class="text-center py-8 text-gray-400">
                  <span class="material-symbols-outlined text-4xl mb-2">person_search</span>
                  <p class="text-sm">No se encontraron clientes</p>
                </div>
                <div v-else class="flex flex-col gap-2">
                  <button
                    v-for="client in filteredClients"
                    :key="client.id"
                    class="flex items-center gap-3 p-3 rounded-xl bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 hover:border-amber-400 dark:hover:border-amber-500 hover:bg-amber-50 dark:hover:bg-amber-900/10 transition-colors text-left"
                    @click="selectClient(client)"
                  >
                    <div class="w-10 h-10 rounded-full bg-gray-100 dark:bg-gray-700 flex items-center justify-center text-gray-600 dark:text-gray-300 font-bold text-sm">
                      {{ client.name.split(' ').map(n => n[0]).join('').substring(0, 2) }}
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="font-semibold text-gray-900 dark:text-white truncate">{{ client.name }}</p>
                      <p class="text-xs text-gray-500 truncate">C.C. {{ client.cedula }}</p>
                    </div>
                    <div class="text-right">
                      <p 
                        class="text-sm font-bold"
                        :class="client.balance.gt(0) ? 'text-red-500' : 'text-emerald-600'"
                      >
                        ${{ client.balance.toDecimalPlaces(0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".") }}
                      </p>
                      <p class="text-[10px] text-gray-400 uppercase">{{ client.balance.gt(0) ? 'Debe' : 'Al día' }}</p>
                    </div>
                  </button>
                </div>
              </div>
            </div>
          </main>

          <!-- Footer (Action) -->
          <footer class="p-4 bg-white dark:bg-surface-dark border-t border-gray-100 dark:border-gray-800">
            <button
              class="w-full h-14 rounded-xl shadow-lg flex items-center justify-between px-6 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed"
              :class="activeMethod === 'cash' 
                ? 'bg-emerald-600 hover:bg-emerald-700 active:bg-emerald-800 shadow-emerald-200 dark:shadow-none' 
                : activeMethod === 'nequi'
                ? 'bg-pink-600 hover:bg-pink-700 active:bg-pink-800'
                : 'bg-amber-600 hover:bg-amber-700 active:bg-amber-800'"
              :disabled="!canComplete"
              @click="completeSale"
            >
              <span class="text-white/80 text-sm font-medium">Completar Venta</span>
              <div class="flex flex-col items-end leading-none">
                <span class="text-white text-lg font-bold tracking-wide">CONFIRMAR</span>
                <span v-if="activeMethod === 'cash' && amountReceived" class="text-white/80 text-xs font-medium">
                  Vueltos: {{ formattedChange }}
                </span>
              </div>
              <span class="material-symbols-outlined text-white">check_circle</span>
            </button>
          </footer>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.3s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.modal-enter-active .animate-slide-up {
  animation: slideUp 0.3s ease-out;
}

.modal-leave-active .animate-slide-up {
  animation: slideDown 0.3s ease-in;
}

@keyframes slideDown {
  from {
    transform: translateY(0);
  }
  to {
    transform: translateY(100%);
  }
}
</style>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useClientsStore, type ClientTransaction } from '../stores/clients';
import { Decimal } from 'decimal.js';

const router = useRouter();
const route = useRoute();
const clientsStore = useClientsStore();

// State
const paymentAmount = ref('');
const showPaymentModal = ref(false);
const showOptionsMenu = ref(false);
const showDeleteConfirm = ref(false);

// Get client ID from route
const clientId = computed(() => Number(route.params.id));

const client = computed(() => clientsStore.getClientById(clientId.value));

const transactions = computed(() => clientsStore.getClientTransactions(clientId.value));

const availableCredit = computed(() => clientsStore.getAvailableCredit(clientId.value));

const creditUsagePercent = computed(() => {
  if (!client.value || client.value.creditLimit.isZero()) return 0;
  return client.value.balance.div(client.value.creditLimit).times(100).toNumber();
});

// Methods
const formatCurrency = (val: Decimal) => {
  return `$${val
    .toDecimalPlaces(0)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`;
};

const formatCedula = (cedula: string) => {
  return cedula.replace(/\B(?=(\d{3})+(?!\d))/g, '.');
};

const formatDate = (dateStr: string) => {
  const date = new Date(dateStr);
  const day = date.getDate();
  const months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];
  const month = months[date.getMonth()];
  const hours = date.getHours();
  const minutes = date.getMinutes().toString().padStart(2, '0');
  const ampm = hours >= 12 ? 'PM' : 'AM';
  const hour12 = hours % 12 || 12;
  return `${day} ${month}, ${hour12}:${minutes} ${ampm}`;
};

const goBack = () => {
  router.push('/clients');
};

const toggleOptionsMenu = () => {
  showOptionsMenu.value = !showOptionsMenu.value;
};

const closeOptionsMenu = () => {
  showOptionsMenu.value = false;
};

const confirmDelete = () => {
  showOptionsMenu.value = false;
  showDeleteConfirm.value = true;
};

const deleteClient = () => {
  clientsStore.deleteClient(clientId.value);
  showDeleteConfirm.value = false;
  router.push('/clients');
};

const registerPayment = () => {
  if (!paymentAmount.value || !client.value) return;

  const amount = new Decimal(paymentAmount.value);
  if (amount.lte(0)) return;

  clientsStore.registerPayment(clientId.value, amount, 'Abono Efectivo');
  paymentAmount.value = '';
  showPaymentModal.value = false;
};

// WO: initializeSampleData eliminada - SPEC-007
</script>

<template>
  <div class="min-h-screen bg-background-light dark:bg-background-dark pb-24">
    <!-- Hero Header Section -->
    <div
      v-if="client"
      class="relative bg-slate-800 rounded-b-[2rem] shadow-xl overflow-hidden z-10"
    >
      <!-- Abstract Pattern Background -->
      <div
        class="absolute inset-0 opacity-10 pointer-events-none"
        style="
          background-image: radial-gradient(#ffffff 1px, transparent 1px);
          background-size: 24px 24px;
        "
      ></div>

      <div class="relative flex flex-col p-6 pb-8">
        <!-- Navigation -->
        <div class="flex items-center justify-between mb-6">
          <button
            @click="goBack"
            aria-label="Volver"
            class="flex items-center justify-center size-12 -ml-3 text-white rounded-full hover:bg-white/10 active:bg-white/20 transition-colors"
          >
            <span class="material-symbols-outlined text-[28px]">arrow_back_ios_new</span>
          </button>
          <div class="flex gap-4 relative">
            <button
              @click="toggleOptionsMenu"
              aria-label="Opciones"
              class="flex items-center justify-center size-10 text-slate-300 rounded-full hover:bg-white/10 active:bg-white/20 transition-colors"
            >
              <span class="material-symbols-outlined">more_vert</span>
            </button>

            <!-- Dropdown Menu -->
            <Transition name="dropdown">
              <div
                v-if="showOptionsMenu"
                class="absolute right-0 top-12 bg-white dark:bg-slate-800 rounded-xl shadow-xl border border-slate-200 dark:border-slate-700 overflow-hidden min-w-[180px] z-50"
              >
                <button
                  @click="confirmDelete"
                  class="w-full px-4 py-3 flex items-center gap-3 text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors text-left"
                >
                  <span class="material-symbols-outlined text-[20px]">delete</span>
                  <span class="font-medium">Eliminar cliente</span>
                </button>
              </div>
            </Transition>
          </div>

          <!-- Click outside to close -->
          <div v-if="showOptionsMenu" class="fixed inset-0 z-40" @click="closeOptionsMenu"></div>
        </div>

        <!-- Client Info -->
        <div class="flex flex-col items-center text-center">
          <h2 class="text-white text-xl font-semibold tracking-wide mb-1">{{ client.name }}</h2>
          <p class="text-slate-400 text-sm font-medium tracking-wide">
            C.C. {{ formatCedula(client.cedula) }}
          </p>
        </div>

        <!-- Gigantic Balance -->
        <div class="flex flex-col items-center mt-6 mb-8">
          <span class="text-emerald-400 text-sm font-bold uppercase tracking-widest mb-2"
            >Saldo Pendiente</span
          >
          <h1 class="text-white text-[56px] leading-none font-bold tracking-tight drop-shadow-sm">
            {{ formatCurrency(client.balance) }}
          </h1>
        </div>

        <!-- Credit Limit Progress Bar -->
        <div class="bg-slate-700/50 rounded-xl p-4 border border-white/5 backdrop-blur-sm">
          <div class="flex justify-between items-end mb-2">
            <p class="text-slate-200 text-sm font-medium">Cupo de Crédito</p>
            <p class="text-emerald-400 text-xs font-bold">
              Disponibles: {{ formatCurrency(availableCredit) }}
            </p>
          </div>
          <!-- Progress Track -->
          <div class="relative h-3 w-full bg-slate-900/50 rounded-full overflow-hidden">
            <!-- Progress Fill -->
            <div
              class="absolute top-0 left-0 h-full bg-gradient-to-r from-emerald-500 to-emerald-400 rounded-full transition-all"
              :style="{ width: `${Math.min(creditUsagePercent, 100)}%` }"
            ></div>
          </div>
          <div class="flex justify-between mt-2">
            <p class="text-slate-400 text-xs">Uso: {{ formatCurrency(client.balance) }}</p>
            <p class="text-slate-400 text-xs">Total: {{ formatCurrency(client.creditLimit) }}</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Main Content: Transaction History -->
    <main class="relative z-0 px-4 pt-6 pb-32 flex flex-col gap-4">
      <div class="flex items-center justify-between px-2">
        <h3 class="text-slate-800 dark:text-white text-lg font-bold">Movimientos Recientes</h3>
        <button class="text-primary text-sm font-semibold hover:underline">Ver todo</button>
      </div>

      <!-- Empty State -->
      <div v-if="transactions.length === 0" class="flex flex-col items-center py-12 text-center">
        <div
          class="flex h-16 w-16 items-center justify-center rounded-full bg-slate-100 dark:bg-slate-800 text-slate-400 mb-4"
        >
          <span class="material-symbols-outlined text-[32px]">receipt_long</span>
        </div>
        <p class="text-slate-500 text-sm">Sin movimientos registrados</p>
      </div>

      <!-- Transaction List -->
      <div v-else class="flex flex-col gap-3">
        <article
          v-for="tx in transactions"
          :key="tx.id"
          class="group flex items-center gap-4 bg-white dark:bg-slate-800 p-4 rounded-xl shadow-sm border border-slate-100 dark:border-slate-700 active:scale-[0.98] transition-transform duration-150"
        >
          <div
            class="shrink-0 flex items-center justify-center size-12 rounded-full"
            :class="
              tx.type === 'payment'
                ? 'bg-emerald-50 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400'
                : 'bg-red-50 dark:bg-red-900/30 text-red-600 dark:text-red-400'
            "
          >
            <span class="material-symbols-outlined">
              {{ tx.type === 'payment' ? 'payments' : 'shopping_cart' }}
            </span>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-slate-900 dark:text-white text-base font-bold truncate">
              {{ tx.description }}
            </p>
            <p class="text-slate-500 dark:text-slate-400 text-xs font-medium mt-0.5">
              {{ formatDate(tx.date) }}
            </p>
          </div>
          <div class="shrink-0 text-right">
            <p
              class="text-lg font-bold"
              :class="
                tx.type === 'payment'
                  ? 'text-emerald-600 dark:text-emerald-400'
                  : 'text-red-600 dark:text-red-400'
              "
            >
              {{ tx.type === 'payment' ? '-' : '+' }}{{ formatCurrency(tx.amount) }}
            </p>
            <p class="text-slate-400 text-[10px] uppercase font-bold tracking-wider">
              {{ tx.type === 'payment' ? 'Pago' : 'Deuda' }}
            </p>
          </div>
        </article>
      </div>
    </main>

    <!-- Sticky Footer Action -->
    <div
      class="fixed bottom-0 left-0 w-full bg-white dark:bg-slate-900 border-t border-slate-100 dark:border-slate-800 p-4 z-50 shadow-[0_-4px_6px_-1px_rgba(0,0,0,0.05)]"
    >
      <button
        @click="showPaymentModal = true"
        class="w-full h-14 bg-emerald-600 hover:bg-emerald-700 active:bg-emerald-800 text-white text-lg font-bold rounded-lg shadow-lg shadow-emerald-200 dark:shadow-none flex items-center justify-center gap-2 transition-all active:scale-[0.99]"
      >
        <span class="material-symbols-outlined">add_circle</span>
        REGISTRAR ABONO
      </button>
    </div>

    <!-- Payment Modal -->
    <Teleport to="body">
      <Transition name="modal">
        <div
          v-if="showPaymentModal"
          class="fixed inset-0 z-[100] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4"
          @click.self="showPaymentModal = false"
        >
          <div
            class="bg-white dark:bg-slate-800 rounded-2xl shadow-2xl w-full max-w-sm p-6 animate-scale-in"
          >
            <h3 class="text-xl font-bold text-slate-900 dark:text-white mb-4">Registrar Abono</h3>
            <div class="mb-4">
              <label class="text-sm font-medium text-slate-600 dark:text-slate-400 mb-2 block"
                >Monto del abono</label
              >
              <div class="relative">
                <span
                  class="absolute left-4 top-1/2 -translate-y-1/2 text-emerald-600 font-bold text-xl"
                  >$</span
                >
                <input
                  v-model="paymentAmount"
                  type="number"
                  inputmode="numeric"
                  class="w-full h-14 pl-10 pr-4 text-2xl font-bold text-slate-900 dark:text-white bg-slate-50 dark:bg-slate-700 border-2 border-slate-200 dark:border-slate-600 rounded-xl focus:border-emerald-500 focus:ring-0"
                  placeholder="0"
                  autofocus
                />
              </div>
            </div>
            <div class="flex gap-3">
              <button
                @click="showPaymentModal = false"
                class="flex-1 h-12 rounded-xl border border-slate-300 dark:border-slate-600 text-slate-600 dark:text-slate-300 font-semibold hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors"
              >
                Cancelar
              </button>
              <button
                @click="registerPayment"
                :disabled="!paymentAmount"
                class="flex-1 h-12 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-semibold disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center gap-2"
              >
                <span class="material-symbols-outlined">check</span>
                Confirmar
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- Delete Confirmation Modal -->
    <Teleport to="body">
      <Transition name="modal">
        <div
          v-if="showDeleteConfirm"
          class="fixed inset-0 z-[100] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4"
          @click.self="showDeleteConfirm = false"
        >
          <div
            class="bg-white dark:bg-slate-800 rounded-2xl shadow-2xl w-full max-w-sm p-6 animate-scale-in"
          >
            <div
              class="flex items-center justify-center w-14 h-14 rounded-full bg-red-100 dark:bg-red-900/30 mx-auto mb-4"
            >
              <span class="material-symbols-outlined text-red-600 text-[28px]">warning</span>
            </div>
            <h3 class="text-xl font-bold text-slate-900 dark:text-white text-center mb-2">
              ¿Eliminar cliente?
            </h3>
            <p class="text-slate-500 dark:text-slate-400 text-sm text-center mb-6">
              Esta acción eliminará al cliente y todo su historial de transacciones. No se puede
              deshacer.
            </p>
            <div class="flex gap-3">
              <button
                @click="showDeleteConfirm = false"
                class="flex-1 h-12 rounded-xl border border-slate-300 dark:border-slate-600 text-slate-600 dark:text-slate-300 font-semibold hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors"
              >
                Cancelar
              </button>
              <button
                @click="deleteClient"
                class="flex-1 h-12 rounded-xl bg-red-600 hover:bg-red-700 text-white font-semibold transition-colors flex items-center justify-center gap-2"
              >
                <span class="material-symbols-outlined text-[20px]">delete</span>
                Eliminar
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<style scoped>
.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.2s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.dropdown-enter-active,
.dropdown-leave-active {
  transition: all 0.15s ease;
}

.dropdown-enter-from,
.dropdown-leave-to {
  opacity: 0;
  transform: translateY(-8px);
}

.animate-scale-in {
  animation: scaleIn 0.2s ease-out;
}

@keyframes scaleIn {
  from {
    transform: scale(0.95);
    opacity: 0;
  }

  to {
    transform: scale(1);
    opacity: 1;
  }
}
</style>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useCashRegisterStore } from '../stores/cashRegister';
import BottomNav from '../components/BottomNav.vue';
import Decimal from 'decimal.js';

const router = useRouter();
const cashRegisterStore = useCashRegisterStore();

// State
const showAddModal = ref(false);
const newExpenseAmount = ref('');
const newExpenseDesc = ref('');
const newExpenseCategory = ref('General');

// Categories
const categories = ['General', 'Proveedores', 'Servicios', 'Mantenimiento', 'Nómina', 'Otros'];

// Computed
const currentExpenses = computed(() => {
  return cashRegisterStore.currentSession?.transactions
    .filter(t => t.type === 'expense')
    .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()) || [];
});

const totalExpenses = computed(() => cashRegisterStore.totalExpenses);
const isSessionOpen = computed(() => cashRegisterStore.isOpen);

// Methods
const goBack = () => router.push('/admin');

const formatCurrency = (val: Decimal | number) => {
  const num = typeof val === 'number' ? val : val.toNumber();
  return new Intl.NumberFormat('es-CO', {
    style: 'currency',
    currency: 'COP',
    minimumFractionDigits: 0
  }).format(num);
};

const formatDate = (isoString: string) => {
  return new Date(isoString).toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit' });
};

const addExpense = () => {
  if (!newExpenseAmount.value || !newExpenseDesc.value) return;
  
  try {
    cashRegisterStore.registerExpense(
      new Decimal(newExpenseAmount.value),
      newExpenseDesc.value,
      newExpenseCategory.value
    );
    showAddModal.value = false;
    newExpenseAmount.value = '';
    newExpenseDesc.value = '';
    newExpenseCategory.value = 'General';
  } catch (e) {
    alert(e);
  }
};
</script>

<template>
  <div class="flex flex-col h-screen bg-background-light dark:bg-background-dark pb-24">
    <!-- Header -->
    <header class="flex items-center justify-between px-4 py-4 bg-white dark:bg-slate-800 border-b border-gray-100 dark:border-gray-700 shrink-0">
      <button 
        @click="goBack"
        class="flex size-10 items-center justify-center rounded-full active:bg-gray-100 dark:active:bg-gray-700 transition-colors"
      >
        <span class="material-symbols-outlined text-gray-900 dark:text-white text-2xl">arrow_back</span>
      </button>
      <h1 class="flex-1 text-center text-lg font-bold tracking-tight text-gray-900 dark:text-white">Gastos de Caja</h1>
      <div class="size-10"></div>
    </header>

    <!-- Content -->
    <main class="flex-1 overflow-y-auto p-4 space-y-4">
      
      <!-- Session Status Warning -->
      <div v-if="!isSessionOpen" class="bg-amber-50 dark:bg-amber-900/20 text-amber-800 dark:text-amber-200 p-4 rounded-xl flex items-center gap-3">
        <span class="material-symbols-outlined text-2xl">lock</span>
        <div>
          <p class="font-bold">Caja Cerrada</p>
          <p class="text-sm opacity-80">No se pueden registrar gastos sin abrir caja.</p>
        </div>
      </div>

      <!-- Summary Card -->
      <div class="bg-red-50 dark:bg-red-900/10 p-6 rounded-2xl border border-red-100 dark:border-red-800/30 flex items-center justify-between">
        <div>
          <p class="text-sm font-medium text-red-600 dark:text-red-400 mb-1">Total Gastos (Sesión Actual)</p>
          <p class="text-3xl font-bold text-gray-900 dark:text-white">{{ formatCurrency(totalExpenses) }}</p>
        </div>
        <div class="size-12 rounded-full bg-white dark:bg-red-900/30 flex items-center justify-center text-red-500">
          <span class="material-symbols-outlined text-2xl">trending_down</span>
        </div>
      </div>

      <!-- List -->
      <div class="space-y-3">
        <h3 class="font-bold text-gray-900 dark:text-white ml-1">Movimientos Recientes</h3>
        
        <div v-if="currentExpenses.length === 0" class="text-center py-10 text-gray-500">
          <span class="material-symbols-outlined text-4xl mb-2 opacity-50">receipt_long</span>
          <p>No hay gastos registrados en esta sesión</p>
        </div>

        <div 
          v-for="expense in currentExpenses" 
          :key="expense.id"
          class="bg-white dark:bg-slate-800 p-4 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700 flex justify-between items-center"
        >
          <div class="flex items-center gap-3">
            <div class="size-10 rounded-full bg-gray-100 dark:bg-gray-700 flex items-center justify-center text-gray-500">
              <span class="material-symbols-outlined">payments</span>
            </div>
            <div>
              <p class="font-semibold text-gray-900 dark:text-white">{{ expense.description }}</p>
              <div class="flex gap-2 text-xs text-gray-500">
                <span>{{ formatDate(expense.timestamp) }}</span>
                <span>•</span>
                <span class="bg-gray-100 dark:bg-gray-700 px-1.5 rounded">{{ expense.category }}</span>
              </div>
            </div>
          </div>
          <p class="font-bold text-red-600 dark:text-red-400">-{{ formatCurrency(expense.amount) }}</p>
        </div>
      </div>
    </main>

    <!-- FAB -->
    <div class="absolute bottom-24 right-4 z-40" v-if="isSessionOpen">
      <button 
        @click="showAddModal = true"
        class="flex items-center justify-center size-14 rounded-2xl bg-red-600 text-white shadow-lg hover:bg-red-700 transition-transform active:scale-95"
      >
        <span class="material-symbols-outlined text-[28px]">add</span>
      </button>
    </div>

    <BottomNav />

    <!-- Add Expense Modal -->
    <Teleport to="body">
      <div v-if="showAddModal" class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm p-4" @click.self="showAddModal = false">
        <div class="bg-white dark:bg-slate-800 w-full max-w-sm rounded-2xl shadow-xl overflow-hidden animate-slide-up sm:animate-scale-in">
          <div class="p-4 border-b border-gray-100 dark:border-gray-700 flex justify-between items-center">
            <h3 class="font-bold text-lg">Registrar Gasto</h3>
            <button @click="showAddModal = false" class="text-gray-400 hover:text-gray-600"><span class="material-symbols-outlined">close</span></button>
          </div>
          <div class="p-4 space-y-4">
            <div>
              <label class="block text-sm font-medium mb-1">Monto</label>
              <input v-model="newExpenseAmount" type="number" class="w-full p-3 rounded-lg border border-gray-200 dark:bg-slate-700 dark:border-gray-600 text-lg font-bold" placeholder="0" autofocus />
            </div>
            <div>
              <label class="block text-sm font-medium mb-1">Concepto</label>
              <input v-model="newExpenseDesc" type="text" class="w-full p-3 rounded-lg border border-gray-200 dark:bg-slate-700 dark:border-gray-600" placeholder="Ej: Pago hielo" />
            </div>
            <div>
              <label class="block text-sm font-medium mb-1">Categoría</label>
              <select v-model="newExpenseCategory" class="w-full p-3 rounded-lg border border-gray-200 dark:bg-slate-700 dark:border-gray-600">
                <option v-for="cat in categories" :key="cat" :value="cat">{{ cat }}</option>
              </select>
            </div>
            <button @click="addExpense" class="w-full py-3 bg-red-600 text-white font-bold rounded-xl mt-2">Registrar Salida</button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.animate-slide-up { animation: slideUp 0.2s ease-out; }
@keyframes slideUp { from { transform: translateY(100%); } to { transform: translateY(0); } }
</style>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useExpensesStore } from '../stores/expenses';
import { Decimal } from 'decimal.js';

const router = useRouter();
const expensesStore = useExpensesStore();

// State
const amount = ref('0');
const selectedCategory = ref('proveedor');
const note = ref('');

// Categories
const categories = [
  { value: 'proveedor', label: 'Pago Proveedor', icon: 'local_shipping' },
  { value: 'servicios', label: 'Servicios', icon: 'electric_bolt' },
  { value: 'retiro', label: 'Retiro Personal', icon: 'person' },
  { value: 'varios', label: 'Gastos Varios', icon: 'inventory_2' },
];

// Computed
const displayAmount = computed(() => {
  return amount.value === '0' ? '0' : amount.value;
});

const canSubmit = computed(() => {
  return amount.value !== '0' && selectedCategory.value;
});

// Methods
const goBack = () => {
  router.push('/admin');
};

const handleNumpadClick = (key: string) => {
  if (key === 'C') {
    amount.value = '0';
  } else if (key === 'backspace') {
    if (amount.value.length > 1) {
      amount.value = amount.value.slice(0, -1);
    } else {
      amount.value = '0';
    }
  } else {
    if (amount.value === '0') {
      amount.value = key;
    } else if (amount.value.length < 10) {
      amount.value += key;
    }
  }
};

const selectCategory = (value: string) => {
  selectedCategory.value = value;
};

const getCategoryLabel = (value: string) => {
  return categories.find((c) => c.value === value)?.label || 'General';
};

const registerExpense = () => {
  if (!canSubmit.value) {
    alert('Ingresa un monto válido');
    return;
  }

  const amountValue = parseInt(amount.value);

  // Guardar en el store
  expensesStore.addExpense({
    description: getCategoryLabel(selectedCategory.value),
    amount: new Decimal(amountValue),
    category: selectedCategory.value,
    note: note.value.trim(),
  });

  alert(`✅ Salida registrada: $${amountValue.toLocaleString('es-CO')}`);
  router.push('/admin');
};
</script>

<template>
  <div class="flex flex-col h-screen bg-background-light dark:bg-background-dark overflow-hidden">
    <!-- 1. Header -->
    <header
      class="flex items-center bg-white dark:bg-surface-dark px-4 py-3 justify-between border-b border-gray-100 dark:border-gray-800 shrink-0 z-30"
    >
      <button
        @click="goBack"
        class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full active:bg-gray-100 dark:active:bg-gray-800 text-gray-800 dark:text-white transition-colors"
      >
        <span class="material-symbols-outlined text-[24px]">arrow_back</span>
      </button>
      <h2
        class="text-gray-900 dark:text-white text-lg font-bold leading-tight tracking-[-0.015em] flex-1 text-center pr-10"
      >
        Registrar Salida
      </h2>
    </header>

    <!-- Scrollable Main Content -->
    <main
      class="flex-1 overflow-y-auto no-scrollbar flex flex-col bg-background-light dark:bg-background-dark"
    >
      <!-- 2. Amount Display (Hero) -->
      <div
        class="bg-orange-50 dark:bg-orange-950/20 py-8 flex flex-col items-center justify-center shrink-0 border-b border-orange-100 dark:border-orange-900/30"
      >
        <label
          class="text-orange-900/60 dark:text-orange-200/60 text-sm font-bold tracking-wide uppercase mb-1"
          >Monto a retirar de caja</label
        >
        <div class="flex items-baseline justify-center gap-1 w-full px-4 text-center cursor-text">
          <span
            class="text-red-600 dark:text-red-400 text-5xl font-black tracking-tighter leading-none"
            >$</span
          >
          <span
            class="text-red-600 dark:text-red-400 text-[64px] font-black tracking-tighter leading-none"
            >{{ displayAmount }}</span
          >
        </div>
      </div>

      <!-- 3. Category Selection (Grid) -->
      <div class="px-4 pt-6 pb-2">
        <h2 class="text-lg font-bold leading-tight text-gray-900 dark:text-white mb-4 px-1">
          ¿En qué se gastó?
        </h2>
        <div class="grid grid-cols-2 gap-3">
          <button
            v-for="cat in categories"
            :key="cat.value"
            @click="selectCategory(cat.value)"
            :class="[
              'group relative flex flex-col items-center justify-center gap-3 p-4 aspect-[4/3] rounded-2xl transition-all shadow-sm active:scale-95',
              selectedCategory === cat.value
                ? 'border-[3px] border-primary bg-orange-50/50 dark:bg-primary/10'
                : 'border border-gray-200 dark:border-gray-700 bg-white dark:bg-surface-dark hover:bg-gray-50 dark:hover:bg-gray-800',
            ]"
          >
            <div
              :class="[
                'h-10 w-10 rounded-full flex items-center justify-center shadow-sm group-hover:scale-110 transition-transform',
                selectedCategory === cat.value
                  ? 'bg-white dark:bg-background-dark text-primary'
                  : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300',
              ]"
            >
              <span class="material-symbols-outlined text-[24px]">{{ cat.icon }}</span>
            </div>
            <span
              :class="[
                'font-bold text-sm leading-tight text-center',
                selectedCategory === cat.value
                  ? 'text-primary-dark dark:text-primary'
                  : 'text-gray-600 dark:text-gray-300',
              ]"
              >{{ cat.label }}</span
            >
            <!-- Active Indicator -->
            <div
              v-if="selectedCategory === cat.value"
              class="absolute top-2 right-2 bg-primary text-white rounded-full p-0.5 shadow-sm"
            >
              <span class="material-symbols-outlined text-[16px]">check</span>
            </div>
          </button>
        </div>
      </div>

      <!-- 4. Optional Note -->
      <div class="px-5 pt-2 pb-6">
        <div class="relative group/input">
          <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <span
              class="material-symbols-outlined text-gray-400 group-focus-within/input:text-primary transition-colors"
              >edit_note</span
            >
          </div>
          <input
            v-model="note"
            type="text"
            class="block w-full pl-10 pr-3 py-4 border border-gray-200 dark:border-gray-700 rounded-xl bg-white dark:bg-surface-dark text-gray-900 dark:text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary transition-all shadow-sm text-base"
            placeholder="Nota (Opcional) - Ej: Factura #123"
          />
        </div>
      </div>
    </main>

    <!-- Bottom Section: Numpad + Action Button -->
    <div
      class="bg-white dark:bg-surface-dark border-t border-gray-100 dark:border-gray-800 shadow-[0_-4px_20px_-5px_rgba(0,0,0,0.1)] z-40 shrink-0"
    >
      <!-- 5. Visual Numpad -->
      <div
        class="grid grid-cols-3 bg-gray-50 dark:bg-gray-800/50 gap-px border-b border-gray-100 dark:border-gray-800"
      >
        <!-- Row 1 -->
        <button
          @click="handleNumpadClick('1')"
          class="h-14 bg-white dark:bg-surface-dark active:bg-gray-50 dark:active:bg-gray-800 flex items-center justify-center text-2xl font-medium text-gray-900 dark:text-white transition-colors"
        >
          1
        </button>
        <button
          @click="handleNumpadClick('2')"
          class="h-14 bg-white dark:bg-surface-dark active:bg-gray-50 dark:active:bg-gray-800 flex items-center justify-center text-2xl font-medium text-gray-900 dark:text-white transition-colors"
        >
          2
        </button>
        <button
          @click="handleNumpadClick('3')"
          class="h-14 bg-white dark:bg-surface-dark active:bg-gray-50 dark:active:bg-gray-800 flex items-center justify-center text-2xl font-medium text-gray-900 dark:text-white transition-colors"
        >
          3
        </button>
        <!-- Row 2 -->
        <button
          @click="handleNumpadClick('4')"
          class="h-14 bg-white dark:bg-surface-dark active:bg-gray-50 dark:active:bg-gray-800 flex items-center justify-center text-2xl font-medium text-gray-900 dark:text-white transition-colors"
        >
          4
        </button>
        <button
          @click="handleNumpadClick('5')"
          class="h-14 bg-white dark:bg-surface-dark active:bg-gray-50 dark:active:bg-gray-800 flex items-center justify-center text-2xl font-medium text-gray-900 dark:text-white transition-colors"
        >
          5
        </button>
        <button
          @click="handleNumpadClick('6')"
          class="h-14 bg-white dark:bg-surface-dark active:bg-gray-50 dark:active:bg-gray-800 flex items-center justify-center text-2xl font-medium text-gray-900 dark:text-white transition-colors"
        >
          6
        </button>
        <!-- Row 3 -->
        <button
          @click="handleNumpadClick('7')"
          class="h-14 bg-white dark:bg-surface-dark active:bg-gray-50 dark:active:bg-gray-800 flex items-center justify-center text-2xl font-medium text-gray-900 dark:text-white transition-colors"
        >
          7
        </button>
        <button
          @click="handleNumpadClick('8')"
          class="h-14 bg-white dark:bg-surface-dark active:bg-gray-50 dark:active:bg-gray-800 flex items-center justify-center text-2xl font-medium text-gray-900 dark:text-white transition-colors"
        >
          8
        </button>
        <button
          @click="handleNumpadClick('9')"
          class="h-14 bg-white dark:bg-surface-dark active:bg-gray-50 dark:active:bg-gray-800 flex items-center justify-center text-2xl font-medium text-gray-900 dark:text-white transition-colors"
        >
          9
        </button>
        <!-- Row 4 -->
        <button
          @click="handleNumpadClick('C')"
          class="h-14 bg-gray-50 dark:bg-[#261f18] active:bg-gray-100 dark:active:bg-gray-800 flex items-center justify-center text-lg font-semibold text-gray-400 dark:text-gray-500 transition-colors"
        >
          C
        </button>
        <button
          @click="handleNumpadClick('0')"
          class="h-14 bg-white dark:bg-surface-dark active:bg-gray-50 dark:active:bg-gray-800 flex items-center justify-center text-2xl font-medium text-gray-900 dark:text-white transition-colors"
        >
          0
        </button>
        <button
          @click="handleNumpadClick('backspace')"
          class="h-14 bg-gray-50 dark:bg-[#261f18] active:bg-gray-100 dark:active:bg-gray-800 flex items-center justify-center text-gray-900 dark:text-white transition-colors"
        >
          <span class="material-symbols-outlined text-gray-600 dark:text-gray-400">backspace</span>
        </button>
      </div>

      <!-- 6. Action Button -->
      <div class="p-4 pt-4 pb-6 bg-white dark:bg-surface-dark">
        <button
          @click="registerExpense"
          :disabled="!canSubmit"
          class="w-full h-14 bg-orange-600 hover:bg-orange-700 active:bg-orange-800 disabled:bg-gray-300 disabled:cursor-not-allowed text-white font-bold text-lg rounded-2xl shadow-lg shadow-orange-600/20 dark:shadow-none flex items-center justify-center gap-3 transition-transform active:scale-[0.98]"
        >
          <span>REGISTRAR SALIDA</span>
          <span class="material-symbols-outlined">output</span>
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.no-scrollbar::-webkit-scrollbar {
  display: none;
}

.no-scrollbar {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
</style>

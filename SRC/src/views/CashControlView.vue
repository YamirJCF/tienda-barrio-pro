<script setup lang="ts">
import { ref, computed, onMounted, nextTick } from 'vue';
import { useRouter } from 'vue-router';
import { useSalesStore } from '../stores/sales';
import { useExpensesStore } from '../stores/expenses';
import { useCashControlStore } from '../stores/cashControl';
import { useAuthStore } from '../stores/auth';
import { Decimal } from 'decimal.js';
import PinKeypad from '../components/PinKeypad.vue';
import PinSetupModal from '../components/PinSetupModal.vue';

const router = useRouter();
const salesStore = useSalesStore();
const expensesStore = useExpensesStore();
const cashControlStore = useCashControlStore();
const authStore = useAuthStore();

// Refs for inputs
const openingInput = ref<HTMLInputElement | null>(null);
const closingInput = ref<HTMLInputElement | null>(null);

// State
const openingAmount = ref('');
const closingAmount = ref('');
const currentStep = ref<'amount' | 'pin' | 'success'>('amount');
const pinError = ref<string | null>(null);
const isLoading = ref(false);
const showPinSetupModal = ref(false); // WO-005

// Computed
const isStoreOpen = computed(() => salesStore.isStoreOpen);
const hasPinConfigured = computed(() => cashControlStore.hasPinConfigured);
const isLocked = computed(() => cashControlStore.isLocked);
const lockRemainingSeconds = computed(() => cashControlStore.lockRemainingSeconds);
const authorizedName = computed(() => authStore.currentUser?.name || 'Usuario');

// Gastos del día
const todayExpenses = computed(() => expensesStore.todayTotal);

// Efectivo esperado = Base + Ventas Efectivo - Gastos
const expectedCash = computed(() => {
  return salesStore.openingCash.plus(salesStore.todayCash).minus(todayExpenses.value);
});

const difference = computed(() => {
  const counted = parseFloat(closingAmount.value) || 0;
  return new Decimal(counted).minus(expectedCash.value);
});

const hasDifference = computed(() => {
  return closingAmount.value && !difference.value.eq(0);
});

const isPositiveDifference = computed(() => {
  return difference.value.gt(0);
});

// Check PIN on mount
onMounted(async () => {
  await cashControlStore.checkPinConfigured();

  nextTick(() => {
    if (!isStoreOpen.value && openingInput.value) {
      openingInput.value.focus();
    } else if (isStoreOpen.value && closingInput.value) {
      closingInput.value.focus();
    }

    // WO-005: Si entra a abrir caja y no tiene PIN, abrir modal automáticamente
    if (!isStoreOpen.value && !hasPinConfigured.value) {
      showPinSetupModal.value = true;
    }
  });
});

// Methods
const goBack = () => {
  if (currentStep.value !== 'amount') {
    currentStep.value = 'amount';
    pinError.value = null;
  } else {
    router.push('/admin');
  }
};

const formatCurrency = (val: Decimal | number) => {
  const num = val instanceof Decimal ? val.toNumber() : val;
  return num.toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
};

// ============================================
// CRITICAL: PIN VALIDATION REQUIRED
// ============================================

// WO-005: Handlers para el modal de PIN
const handlePinSetupClose = () => {
  // Si cancela la configuración, lo sacamos de la vista para evitar estados inconsistentes
  router.push('/admin');
};

const handlePinSetupSuccess = async () => {
  showPinSetupModal.value = false;
  await cashControlStore.checkPinConfigured();
  // Volver a checkear si ya podemos continuar (opcional)
};

const goToPinStep = () => {
  // Validate amount first
  const amount = isStoreOpen.value
    ? parseFloat(closingAmount.value) || 0
    : parseFloat(openingAmount.value) || 0;

  if (!isStoreOpen.value && amount < 0) {
    return; // Invalid opening amount
  }

  // Check if PIN is configured
  if (!hasPinConfigured.value) {
    // WO-005: Redirect to setup instead of error
    showPinSetupModal.value = true;
    return;
  }

  // Go to PIN entry step
  pinError.value = null;
  currentStep.value = 'pin';
};

const handlePinComplete = async (pin: string) => {
  isLoading.value = true;
  pinError.value = null;

  try {
    if (!isStoreOpen.value) {
      // OPEN CASH REGISTER
      const amount = parseFloat(openingAmount.value) || 0;
      const result = await cashControlStore.openCash(amount, pin, authorizedName.value);

      if (result.success) {
        // Also update salesStore for compatibility
        salesStore.openStore(new Decimal(amount));
        currentStep.value = 'success';
        setTimeout(() => {
          router.push('/admin');
        }, 1500);
      } else {
        pinError.value = result.error || 'PIN incorrecto';
      }
    } else {
      // CLOSE CASH REGISTER
      const amount = parseFloat(closingAmount.value) || 0;
      const result = await cashControlStore.closeCash(amount, pin, authorizedName.value);

      if (result.success) {
        // Also update salesStore for compatibility
        salesStore.closeStore();
        expensesStore.clearTodayExpenses();
        currentStep.value = 'success';
        setTimeout(() => {
          router.push('/admin');
        }, 1500);
      } else {
        pinError.value = result.error || 'PIN incorrecto';
      }
    }
  } catch (err) {
    pinError.value = 'Error al procesar. Intenta de nuevo.';
  } finally {
    isLoading.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-screen bg-background-light dark:bg-background-dark overflow-hidden">
    <!-- ========================================== -->
    <!-- ESTADO 1: APERTURA DE CAJA (OPENING)       -->
    <!-- ========================================== -->
    <template v-if="!isStoreOpen">
      <!-- Header -->
      <header
        class="flex items-center bg-background-light dark:bg-background-dark p-4 pt-4 justify-between sticky top-0 z-10"
      >
        <button
          @click="goBack"
          aria-label="Volver"
          class="text-slate-900 dark:text-white flex h-12 w-12 shrink-0 items-center justify-center rounded-full hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <span class="material-symbols-outlined text-[24px]">arrow_back</span>
        </button>
        <h2
          class="text-slate-900 dark:text-white text-lg font-bold leading-tight tracking-[-0.015em] flex-1 text-center pr-12"
        >
          Control de Caja
        </h2>
      </header>

      <!-- STEP: Amount Entry -->
      <template v-if="currentStep === 'amount'">
        <div class="flex-1 flex flex-col items-center justify-center px-6 gap-8 pb-20">
          <!-- Hero Icon -->
          <div class="flex flex-col items-center gap-6">
            <div
              class="h-24 w-24 rounded-full bg-yellow-100 dark:bg-yellow-900/30 flex items-center justify-center shadow-sm"
            >
              <span class="material-symbols-outlined text-yellow-500 text-[64px]">wb_sunny</span>
            </div>
            <div class="text-center space-y-2">
              <h1
                class="text-slate-900 dark:text-white tracking-tight text-3xl font-black leading-tight"
              >
                Iniciar Jornada
              </h1>
              <p
                class="text-slate-500 dark:text-slate-400 text-base font-normal leading-relaxed max-w-[280px]"
              >
                ¡Buenos días! Ingresa el dinero base para comenzar las ventas.
              </p>
            </div>
          </div>

          <!-- Input Field -->
          <div class="w-full max-w-xs space-y-3">
            <label
              class="text-slate-700 dark:text-slate-300 text-sm font-semibold pl-1 block"
              for="initial-base"
            >
              Base / Sencillo Inicial ($)
            </label>
            <div class="relative group">
              <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                <span class="text-slate-400 dark:text-slate-500 font-bold text-xl">$</span>
              </div>
              <input
                v-model="openingAmount"
                ref="openingInput"
                class="block w-full rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 py-4 pl-10 pr-4 text-slate-900 dark:text-white placeholder:text-slate-400 dark:placeholder:text-slate-600 focus:border-primary focus:ring-2 focus:ring-primary/20 text-2xl font-bold tracking-wide shadow-sm transition-all"
                id="initial-base"
                inputmode="decimal"
                placeholder="0"
                type="number"
              />
            </div>

            <!-- PIN Not Configured Warning -->
            <div
              v-if="!hasPinConfigured"
              class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg p-3 text-sm"
            >
              <p class="text-amber-700 dark:text-amber-300 flex items-center gap-2">
                <span class="material-symbols-outlined text-lg">warning</span>
                Debes configurar un PIN primero en Admin > Seguridad
              </p>
            </div>
          </div>
        </div>

        <!-- Bottom Action -->
        <div
          class="p-4 pb-8 bg-background-light dark:bg-background-dark border-t border-slate-100 dark:border-slate-800"
        >
          <button
            @click="goToPinStep"
            :disabled="!hasPinConfigured"
            class="flex w-full cursor-pointer items-center justify-center rounded-xl h-14 px-6 bg-primary hover:bg-blue-700 disabled:bg-slate-400 disabled:cursor-not-allowed text-white text-lg font-bold leading-normal tracking-[0.015em] shadow-lg shadow-primary/30 transition-all active:scale-[0.98]"
          >
            Continuar con PIN
            <span class="material-symbols-outlined ml-2">lock</span>
          </button>
        </div>
      </template>

      <!-- STEP: PIN Entry -->
      <template v-if="currentStep === 'pin'">
        <div class="flex-1 flex flex-col items-center justify-center px-6 gap-6">
          <div class="text-center">
            <p class="text-slate-500 dark:text-slate-400 text-sm mb-2">Monto inicial:</p>
            <p class="text-2xl font-bold text-slate-900 dark:text-white">
              ${{ formatCurrency(parseFloat(openingAmount) || 0) }}
            </p>
          </div>

          <div class="h-px w-20 bg-slate-200 dark:bg-slate-700"></div>

          <p class="text-slate-700 dark:text-slate-300 font-semibold">Ingresa tu PIN:</p>

          <!-- Lockout Warning -->
          <div v-if="isLocked" class="bg-red-50 dark:bg-red-900/30 rounded-xl p-4 text-center">
            <p class="text-red-600 font-bold">⏳ Cuenta bloqueada</p>
            <p class="text-red-500 text-sm">Espera {{ lockRemainingSeconds }} segundos</p>
          </div>

          <PinKeypad
            v-else
            :length="6"
            :error="pinError"
            :disabled="isLoading"
            @complete="handlePinComplete"
          />

          <button
            @click="currentStep = 'amount'"
            class="text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-300 text-sm mt-4"
          >
            ← Volver
          </button>
        </div>
      </template>

      <!-- STEP: Success -->
      <template v-if="currentStep === 'success'">
        <div class="flex-1 flex flex-col items-center justify-center px-6 gap-6">
          <div
            class="h-24 w-24 rounded-full bg-green-100 dark:bg-green-900/30 flex items-center justify-center"
          >
            <span class="material-symbols-outlined text-green-600 text-[64px]">check_circle</span>
          </div>
          <h2 class="text-2xl font-bold text-slate-900 dark:text-white">¡Caja Abierta!</h2>
          <p class="text-slate-500 dark:text-slate-400">Redirigiendo...</p>
        </div>
      </template>
    </template>

    <!-- ========================================== -->
    <!-- ESTADO 2: CIERRE / ARQUEO (CLOSING)        -->
    <!-- ========================================== -->
    <template v-else>
      <!-- Header -->
      <header
        class="flex items-center bg-background-light dark:bg-background-dark p-4 pt-4 justify-between sticky top-0 z-10 shadow-sm border-b border-slate-100 dark:border-slate-800/50"
      >
        <button
          @click="goBack"
          aria-label="Volver"
          class="text-slate-900 dark:text-white flex h-12 w-12 shrink-0 items-center justify-center rounded-full hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <span class="material-symbols-outlined text-[24px]">arrow_back</span>
        </button>
        <h2
          class="text-slate-900 dark:text-white text-lg font-bold leading-tight flex-1 text-center pr-12"
        >
          Arqueo de Caja
        </h2>
      </header>

      <!-- STEP: Amount Entry for Closing -->
      <template v-if="currentStep === 'amount'">
        <!-- Scrollable Content -->
        <div class="flex-1 overflow-y-auto px-4 py-6 flex flex-col gap-6">
          <!-- Title Section -->
          <div class="flex items-center gap-3 px-1">
            <div
              class="h-10 w-10 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center"
            >
              <span class="material-symbols-outlined text-slate-600 dark:text-slate-400"
                >inventory_2</span
              >
            </div>
            <h1 class="text-slate-900 dark:text-white text-2xl font-black">Cierre de Turno</h1>
          </div>

          <!-- Summary Card (Read Only) -->
          <div
            class="bg-white dark:bg-slate-800 rounded-2xl p-5 shadow-sm border border-slate-100 dark:border-slate-700/50 flex flex-col gap-3"
          >
            <h3 class="text-xs font-bold text-slate-400 uppercase tracking-wider mb-1">
              Resumen del Sistema
            </h3>
            <div class="flex justify-between items-center text-sm">
              <span class="text-slate-600 dark:text-slate-300">Base Inicial</span>
              <span class="text-green-600 font-semibold font-mono"
                >+ ${{ formatCurrency(salesStore.openingCash) }}</span
              >
            </div>
            <div class="flex justify-between items-center text-sm">
              <span class="text-slate-600 dark:text-slate-300">Ventas Efectivo</span>
              <span class="text-green-600 font-semibold font-mono"
                >+ ${{ formatCurrency(salesStore.todayCash) }}</span
              >
            </div>
            <div class="flex justify-between items-center text-sm">
              <span class="text-slate-600 dark:text-slate-300">Salidas / Gastos</span>
              <span class="text-red-600 font-semibold font-mono"
                >- ${{ formatCurrency(todayExpenses) }}</span
              >
            </div>
            <div class="my-2 h-px bg-slate-100 dark:bg-slate-700 border-dashed"></div>
            <div class="flex justify-between items-end">
              <span class="text-slate-900 dark:text-white font-bold text-base pb-1"
                >Debe haber en Cajón</span
              >
              <span class="text-slate-900 dark:text-white font-black text-xl font-mono"
                >${{ formatCurrency(expectedCash) }}</span
              >
            </div>
          </div>

          <!-- Real Count Input -->
          <div class="flex flex-col gap-4">
            <label class="text-slate-900 dark:text-white text-lg font-bold px-1" for="real-count">
              ¿Cuánto contaste?
            </label>
            <div class="relative">
              <div class="absolute inset-y-0 left-0 pl-5 flex items-center pointer-events-none">
                <span class="text-slate-400 dark:text-slate-500 font-bold text-2xl">$</span>
              </div>
              <input
                v-model="closingAmount"
                ref="closingInput"
                :class="[
                  'block w-full rounded-2xl border-2 bg-white dark:bg-slate-800 py-5 pl-12 pr-14 text-slate-900 dark:text-white placeholder:text-slate-300 focus:outline-none text-3xl font-black tracking-wide shadow-sm transition-all',
                  hasDifference && !isPositiveDifference
                    ? 'border-red-500/30 focus:border-red-500 focus:ring-4 focus:ring-red-500/10'
                    : hasDifference && isPositiveDifference
                      ? 'border-blue-500/30 focus:border-blue-500 focus:ring-4 focus:ring-blue-500/10'
                      : 'border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-4 focus:ring-primary/10',
                ]"
                id="real-count"
                inputmode="decimal"
                placeholder="0"
                type="number"
              />
              <!-- Status Icon inside input -->
              <div
                v-if="closingAmount && difference.eq(0)"
                class="absolute inset-y-0 right-0 pr-5 flex items-center pointer-events-none"
              >
                <span class="material-symbols-outlined text-green-600 text-[28px]"
                  >check_circle</span
                >
              </div>
              <div
                v-else-if="hasDifference"
                class="absolute inset-y-0 right-0 pr-5 flex items-center pointer-events-none"
              >
                <span class="material-symbols-outlined text-red-600 text-[28px] animate-pulse"
                  >error</span
                >
              </div>
            </div>
          </div>

          <!-- Feedback Messages -->
          <div
            v-if="hasDifference && !isPositiveDifference"
            class="bg-red-50 dark:bg-red-900/20 border border-red-100 dark:border-red-900/50 rounded-xl p-4 flex items-start gap-3"
          >
            <div class="mt-0.5 text-red-600 bg-red-100 dark:bg-red-900/40 rounded-full p-1">
              <span class="material-symbols-outlined text-[20px] block">warning</span>
            </div>
            <div class="flex-1">
              <p class="text-red-600 font-bold text-base">Hay una diferencia</p>
              <p class="text-red-700 dark:text-red-300 text-sm">
                Faltante:
                <span class="font-mono font-bold text-base"
                  >-${{ formatCurrency(difference.abs()) }}</span
                >
              </p>
            </div>
          </div>

          <div
            v-if="hasDifference && isPositiveDifference"
            class="bg-blue-50 dark:bg-blue-900/20 border border-blue-100 dark:border-blue-900/50 rounded-xl p-4 flex items-start gap-3"
          >
            <div class="mt-0.5 text-blue-600 bg-blue-100 dark:bg-blue-900/40 rounded-full p-1">
              <span class="material-symbols-outlined text-[20px] block">info</span>
            </div>
            <div class="flex-1">
              <p class="text-blue-600 font-bold text-base">Hay un sobrante</p>
              <p class="text-blue-700 dark:text-blue-300 text-sm">
                Excedente:
                <span class="font-mono font-bold text-base"
                  >+${{ formatCurrency(difference) }}</span
                >
              </p>
            </div>
          </div>

          <div
            v-if="closingAmount && difference.eq(0)"
            class="bg-green-50 dark:bg-green-900/20 border border-green-100 dark:border-green-900/50 rounded-xl p-4 flex items-center gap-3"
          >
            <div class="text-green-600 bg-green-100 dark:bg-green-900/40 rounded-full p-1">
              <span class="material-symbols-outlined text-[20px] block">check</span>
            </div>
            <div class="flex-1">
              <p class="text-green-600 font-bold text-base">¡Caja Cuadrada! Perfecto</p>
            </div>
          </div>

          <!-- PIN Not Configured Warning -->
          <div
            v-if="!hasPinConfigured"
            class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg p-3 text-sm"
          >
            <p class="text-amber-700 dark:text-amber-300 flex items-center gap-2">
              <span class="material-symbols-outlined text-lg">warning</span>
              Debes configurar un PIN primero en Admin > Seguridad
            </p>
          </div>
        </div>

        <!-- Bottom Action -->
        <div
          class="p-4 pb-8 bg-background-light dark:bg-background-dark border-t border-slate-100 dark:border-slate-800 z-20"
        >
          <button
            @click="goToPinStep"
            :disabled="!hasPinConfigured || !closingAmount"
            class="flex w-full cursor-pointer items-center justify-center rounded-xl h-14 px-6 bg-primary hover:bg-blue-700 disabled:bg-slate-400 disabled:cursor-not-allowed text-white text-lg font-bold leading-normal tracking-[0.015em] shadow-lg shadow-primary/30 transition-all active:scale-[0.98]"
          >
            <span class="material-symbols-outlined mr-2 text-[20px]">lock</span>
            Confirmar con PIN
          </button>
        </div>
      </template>

      <!-- STEP: PIN Entry for Closing -->
      <template v-if="currentStep === 'pin'">
        <div class="flex-1 flex flex-col items-center justify-center px-6 gap-6">
          <div class="text-center space-y-2">
            <p class="text-slate-500 dark:text-slate-400 text-sm">Monto en caja:</p>
            <p class="text-2xl font-bold text-slate-900 dark:text-white">
              ${{ formatCurrency(parseFloat(closingAmount) || 0) }}
            </p>
            <p
              v-if="hasDifference"
              :class="isPositiveDifference ? 'text-blue-600' : 'text-red-600'"
              class="text-sm font-semibold"
            >
              Diferencia: {{ isPositiveDifference ? '+' : '' }}${{ formatCurrency(difference) }}
            </p>
          </div>

          <div class="h-px w-20 bg-slate-200 dark:bg-slate-700"></div>

          <p class="text-slate-700 dark:text-slate-300 font-semibold">
            Ingresa tu PIN para confirmar:
          </p>

          <!-- Lockout Warning -->
          <div v-if="isLocked" class="bg-red-50 dark:bg-red-900/30 rounded-xl p-4 text-center">
            <p class="text-red-600 font-bold">⏳ Cuenta bloqueada</p>
            <p class="text-red-500 text-sm">Espera {{ lockRemainingSeconds }} segundos</p>
          </div>

          <PinKeypad
            v-else
            :length="6"
            :error="pinError"
            :disabled="isLoading"
            @complete="handlePinComplete"
          />

          <button
            @click="currentStep = 'amount'"
            class="text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-300 text-sm mt-4"
          >
            ← Volver
          </button>
        </div>
      </template>

      <!-- STEP: Success -->
      <template v-if="currentStep === 'success'">
        <div class="flex-1 flex flex-col items-center justify-center px-6 gap-6">
          <div
            class="h-24 w-24 rounded-full bg-green-100 dark:bg-green-900/30 flex items-center justify-center"
          >
            <span class="material-symbols-outlined text-green-600 text-[64px]">check_circle</span>
          </div>
          <h2 class="text-2xl font-bold text-slate-900 dark:text-white">¡Caja Cerrada!</h2>
          <p class="text-slate-500 dark:text-slate-400">Turno finalizado correctamente</p>
        </div>
      </template>
    </template>

    <!-- WO-005: Modal de Configuración de PIN -->
    <PinSetupModal
      :isVisible="showPinSetupModal"
      mode="setup"
      @close="handlePinSetupClose"
      @success="handlePinSetupSuccess"
    />
  </div>
</template>

<style scoped>
.tap-highlight-transparent {
  -webkit-tap-highlight-color: transparent;
}
</style>

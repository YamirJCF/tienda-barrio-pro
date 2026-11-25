<script setup lang="ts">
import { ref, watch, onMounted, onUnmounted } from 'vue';
import Decimal from 'decimal.js';
import UIBaseModal from '@/components/ui/BaseModal.vue';
import { useAuthStore } from '../../stores/auth';
import { useEmployeesStore } from '../../stores/employees';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import type { PaymentTransaction } from '../../types';
import { Users, WifiOff, AlertTriangle } from 'lucide-vue-next';

interface Props {
  modelValue: boolean;
  total: Decimal;
  itemCount?: number;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'complete': [payments: PaymentTransaction[], totalPaid: Decimal, clientId?: string, beneficiaryEmployeeId?: string];
}>();

const authStore = useAuthStore();
const employeesStore = useEmployeesStore();
const { formatCurrency } = useCurrencyFormat();

const selectedBeneficiaryEmployeeId = ref<string>('');
const withdrawalError = ref<string | null>(null);
const employeesLoadError = ref<string | null>(null);
const isOnline = ref<boolean>(typeof navigator !== 'undefined' ? navigator.onLine : true);

const syncOnlineStatus = () => {
  isOnline.value = typeof navigator !== 'undefined' ? navigator.onLine : true;
};

onMounted(() => {
  syncOnlineStatus();
  window.addEventListener('online', syncOnlineStatus);
  window.addEventListener('offline', syncOnlineStatus);
});

onUnmounted(() => {
  window.removeEventListener('online', syncOnlineStatus);
  window.removeEventListener('offline', syncOnlineStatus);
});

watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return;
    syncOnlineStatus();
    selectedBeneficiaryEmployeeId.value = '';
    withdrawalError.value = null;
    employeesLoadError.value = null;

    const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
    if (
      authStore.isAdmin &&
      storeId &&
      employeesStore.employees.length === 0 &&
      typeof employeesStore.initialize === 'function'
    ) {
      try {
        await employeesStore.initialize(storeId);
      } catch (err: any) {
        employeesLoadError.value = err?.message || 'No se pudo cargar la lista de colaboradores.';
      }
    }
  },
  { immediate: true }
);

const close = () => {
  emit('update:modelValue', false);
};

const confirmWithdrawal = () => {
  syncOnlineStatus();
  withdrawalError.value = null;

  if (!isOnline.value) {
    withdrawalError.value = 'Los retiros personales requieren conexión en línea para acreditar el costo FIFO en servidor.';
    return;
  }

  const beneficiaryId =
    authStore.isAdmin && selectedBeneficiaryEmployeeId.value
      ? selectedBeneficiaryEmployeeId.value
      : undefined;

  // CHK-403: Consumo personal nunca envía client_id y siempre liquida $0 en caja
  emit(
    'complete',
    [{ method: 'consumo_personal', amount: new Decimal(0) }],
    new Decimal(0),
    undefined,
    beneficiaryId
  );
};
</script>

<template>
  <UIBaseModal
    :modelValue="modelValue"
    title="Consumo / Retiro Personal ($0)"
    @update:modelValue="close"
  >
    <div class="p-4 space-y-4">
      <!-- Read Model Header ($0 en Caja + referencia comercial) -->
      <div class="rounded-2xl bg-slate-50 dark:bg-slate-800/80 border border-slate-200 dark:border-slate-700 p-4 text-center space-y-1">
        <p class="text-[11px] font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400">
          Consumo / Retiro Personal ($0 en Caja)
        </p>
        <p class="text-3xl font-black font-mono tabular-nums text-slate-900 dark:text-white">
          $0
        </p>
        <p class="text-xs text-slate-500 dark:text-slate-400 font-mono tabular-nums">
          Valor venta ref.: ${{ formatCurrency(total) }}
          <span v-if="typeof itemCount === 'number'"> · {{ itemCount }} ítems</span>
          · Costeado FIFO en inventario
        </p>
      </div>

      <!-- Offline Blocking Alert (N1 Inline) -->
      <div
        v-if="!isOnline"
        role="alert"
        data-testid="personal-withdrawal-offline-alert"
        class="p-3 rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800 flex items-start gap-2.5 text-rose-700 dark:text-rose-300 text-xs font-medium"
      >
        <WifiOff :size="16" class="shrink-0 mt-0.5" />
        <span>Los retiros personales requieren conexión en línea. Reconecta para registrar este retiro.</span>
      </div>

      <!-- Descripción contable FIFO -->
      <div
        data-testid="personal-withdrawal-panel"
        class="p-4 rounded-2xl bg-indigo-50 dark:bg-indigo-950/30 border border-indigo-200 dark:border-indigo-800 space-y-2"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="inline-flex items-center gap-1.5 text-xs font-bold uppercase tracking-wide text-indigo-700 dark:text-indigo-300">
            <Users :size="15" />
            Consumo / Retiro Personal
          </span>
          <span class="px-2 py-0.5 rounded-full bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300 text-xs font-bold font-mono tabular-nums">
            $0 en Caja
          </span>
        </div>
        <p class="text-xs text-slate-600 dark:text-slate-300 leading-relaxed">
          Los productos se descuentan del inventario al costo FIFO sin sumar ingresos en la gaveta POS ni generar ventas comerciales.
        </p>
      </div>

      <!-- Error al cargar empleados (Regla 3) -->
      <div
        v-if="employeesLoadError"
        role="alert"
        class="p-2.5 rounded-xl bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-800 flex items-center gap-2 text-amber-800 dark:text-amber-300 text-xs"
      >
        <AlertTriangle :size="15" class="shrink-0" />
        <span>{{ employeesLoadError }}</span>
      </div>

      <!-- Selector de beneficiario (Solo Admin) vs Asignación fija (Empleado) -->
      <div v-if="authStore.isAdmin" class="space-y-1.5">
        <label class="block text-xs font-bold uppercase tracking-wide text-slate-600 dark:text-slate-300">
          Beneficiario del Retiro (Admin)
        </label>
        <select
          v-model="selectedBeneficiaryEmployeeId"
          data-testid="beneficiary-employee-select"
          class="w-full h-11 px-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-sm text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 outline-none"
        >
          <option value="">Administrador ({{ authStore.currentUser?.name || 'Propio' }})</option>
          <option
            v-for="emp in employeesStore.activeOperationalEmployees"
            :key="emp.id"
            :value="emp.id"
          >
            {{ emp.name }} (@{{ emp.username }})
          </option>
        </select>
      </div>

      <div
        v-else
        class="p-3 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 text-xs text-slate-600 dark:text-slate-300"
      >
        Asignado automáticamente a: <strong class="text-slate-900 dark:text-white">{{ authStore.currentUser?.name || 'Colaborador actual' }}</strong>
      </div>

      <!-- Error Inline de confirmación (N1) -->
      <div
        v-if="withdrawalError"
        role="alert"
        data-testid="personal-withdrawal-error"
        class="p-3 rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800 flex items-start gap-2 text-rose-700 dark:text-rose-300 text-xs font-semibold"
      >
        <AlertTriangle :size="15" class="shrink-0 mt-0.5" />
        <span>{{ withdrawalError }}</span>
      </div>

      <!-- Acciones -->
      <div class="flex items-center gap-2 pt-1">
        <button
          type="button"
          @click="close"
          class="h-12 px-4 rounded-xl border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-900 text-sm font-semibold text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors cursor-pointer"
        >
          Cancelar
        </button>
        <button
          type="button"
          data-testid="personal-withdrawal-confirm-btn"
          :disabled="!isOnline"
          @click="confirmWithdrawal"
          class="flex-1 h-12 rounded-xl bg-indigo-600 hover:bg-indigo-700 active:bg-indigo-800 disabled:bg-slate-200 disabled:text-slate-400 disabled:dark:bg-slate-800 disabled:dark:text-slate-600 text-white font-bold text-sm shadow-sm transition-colors cursor-pointer disabled:cursor-not-allowed flex flex-col items-center justify-center leading-tight"
        >
          <span class="text-[10px] uppercase tracking-wider opacity-90">Registrar Retiro Personal ($0)</span>
          <span class="text-base font-black tracking-wide">CONFIRMAR</span>
        </button>
      </div>
    </div>
  </UIBaseModal>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useSalesStore } from '../stores/sales';
import BottomNav from '../components/BottomNav.vue';

const router = useRouter();
const salesStore = useSalesStore();

// State
const activeTab = ref<'reportes' | 'gestion'>('gestion');
const isStoreClosed = ref(false);

// Methods
const goBack = () => {
  router.push('/');
};

const toggleStoreStatus = () => {
  isStoreClosed.value = !isStoreClosed.value;
  if (isStoreClosed.value) {
    salesStore.closeStore();
  }
};

const navigateTo = (route: string) => {
  router.push(route);
};
</script>

<template>
  <div class="relative flex min-h-screen w-full flex-col overflow-x-hidden pb-20 bg-background-light dark:bg-background-dark">
    <!-- Header -->
    <header class="sticky top-0 z-40 bg-background-light/95 dark:bg-background-dark/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-800">
      <div class="flex items-center justify-between px-4 py-3 gap-3">
        <button 
          @click="goBack"
          aria-label="Volver atrás" 
          class="flex items-center justify-center -ml-2 p-2 rounded-full text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <span class="material-symbols-outlined">arrow_back</span>
        </button>
        <h2 class="text-xl font-bold leading-tight tracking-tight flex-1 dark:text-white">Administración</h2>
        <div class="flex items-center justify-end">
          <button 
            aria-label="Perfil de usuario" 
            class="relative flex items-center justify-center overflow-hidden rounded-full h-10 w-10 bg-slate-200 dark:bg-slate-700 ring-2 ring-white dark:ring-slate-800 shadow-sm"
          >
            <div class="h-full w-full bg-gradient-to-br from-blue-400 to-purple-500"></div>
          </button>
        </div>
      </div>
    </header>

    <!-- Tabs -->
    <div class="sticky top-[65px] z-30 w-full bg-background-light dark:bg-background-dark px-4 pb-4 pt-2 shadow-[0_4px_10px_-10px_rgba(0,0,0,0.1)]">
      <div class="flex h-12 w-full items-center justify-center rounded-xl bg-slate-200 dark:bg-slate-800 p-1">
        <label 
          class="flex cursor-pointer h-full flex-1 items-center justify-center overflow-hidden rounded-lg px-2 transition-all"
          :class="activeTab === 'reportes' 
            ? 'bg-white dark:bg-slate-700 shadow-sm text-primary dark:text-primary font-bold ring-1 ring-black/5 dark:ring-white/10' 
            : 'text-slate-500 dark:text-slate-400 font-semibold hover:bg-white/50 dark:hover:bg-slate-700/50'"
          @click="activeTab = 'reportes'"
        >
          <span class="flex items-center gap-2 truncate text-sm">
            <span class="material-symbols-outlined text-[20px]">bar_chart</span>
            Reportes
          </span>
        </label>
        <label 
          class="flex cursor-pointer h-full flex-1 items-center justify-center overflow-hidden rounded-lg px-2 transition-all"
          :class="activeTab === 'gestion' 
            ? 'bg-white dark:bg-slate-700 shadow-sm text-primary dark:text-primary font-bold ring-1 ring-black/5 dark:ring-white/10' 
            : 'text-slate-500 dark:text-slate-400 font-semibold hover:bg-white/50 dark:hover:bg-slate-700/50'"
          @click="activeTab = 'gestion'"
        >
          <span class="flex items-center gap-2 truncate text-sm">
            <span class="material-symbols-outlined text-[20px]">settings</span>
            Gestión
          </span>
        </label>
      </div>
    </div>

    <!-- Main Content -->
    <main class="flex flex-col gap-6 px-4 pt-4">
      <!-- Control de Dinero -->
      <section v-if="activeTab === 'gestion'">
        <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-3 px-1">Control de Dinero</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <!-- Caja Abierta -->
          <div class="relative flex flex-col justify-between rounded-xl bg-white dark:bg-slate-800 p-5 shadow-sm border border-slate-100 dark:border-slate-700">
            <div class="flex items-start justify-between mb-4">
              <div class="flex h-12 w-12 items-center justify-center rounded-full bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400">
                <span class="material-symbols-outlined text-[28px]">point_of_sale</span>
              </div>
              <span 
                class="px-2 py-1 rounded-md text-xs font-bold"
                :class="salesStore.isStoreOpen 
                  ? 'bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-300' 
                  : 'bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-400'"
              >
                {{ salesStore.isStoreOpen ? 'ACTIVA' : 'CERRADA' }}
              </span>
            </div>
            <div class="mb-5">
              <h4 class="text-lg font-bold text-slate-900 dark:text-white leading-tight">
                {{ salesStore.isStoreOpen ? 'Caja Abierta' : 'Caja Cerrada' }}
              </h4>
              <p class="text-sm text-slate-500 dark:text-slate-400 mt-1 font-medium">
                Base inicial: <span class="text-slate-900 dark:text-slate-200 font-bold">$ {{ salesStore.openingCash.toDecimalPlaces(0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".") }}</span>
              </p>
            </div>
            <button 
              class="flex w-full items-center justify-center gap-2 rounded-lg bg-primary py-3 px-4 text-sm font-bold text-white shadow-md shadow-primary/20 transition-transform active:scale-[0.98] hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 dark:focus:ring-offset-slate-900"
            >
              <span class="material-symbols-outlined text-[20px]">receipt_long</span>
              Cerrar Caja / Arqueo
            </button>
          </div>

          <!-- Gastos del Día -->
          <div class="relative flex flex-col justify-between rounded-xl bg-white dark:bg-slate-800 p-5 shadow-sm border border-slate-100 dark:border-slate-700">
            <div class="flex items-start justify-between mb-4">
              <div class="flex h-12 w-12 items-center justify-center rounded-full bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400">
                <span class="material-symbols-outlined text-[28px]">account_balance_wallet</span>
              </div>
            </div>
            <div class="mb-5">
              <h4 class="text-lg font-bold text-slate-900 dark:text-white leading-tight">Gastos del Día</h4>
              <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">Registrar Salida/Gasto</p>
            </div>
            <button 
              class="flex w-full items-center justify-center gap-2 rounded-lg bg-slate-100 dark:bg-slate-700 py-3 px-4 text-sm font-bold text-slate-700 dark:text-slate-200 transition-colors hover:bg-slate-200 dark:hover:bg-slate-600 active:bg-slate-300"
            >
              <span class="material-symbols-outlined text-[20px]">add</span>
              Nuevo Gasto
            </button>
          </div>
        </div>
      </section>

      <!-- Equipo y Tienda -->
      <section v-if="activeTab === 'gestion'">
        <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-3 px-1">Equipo y Tienda</h3>
        <div class="flex flex-col overflow-hidden rounded-xl bg-white dark:bg-slate-800 shadow-sm border border-slate-100 dark:border-slate-700 divide-y divide-slate-100 dark:divide-slate-700">
          <!-- Empleados y Permisos -->
          <button class="flex w-full items-center justify-between p-4 transition-colors hover:bg-slate-50 dark:hover:bg-slate-700/50 text-left group">
            <div class="flex items-center gap-4">
              <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-blue-50 dark:bg-blue-900/20 text-primary">
                <span class="material-symbols-outlined">group</span>
              </div>
              <div>
                <p class="text-base font-semibold text-slate-900 dark:text-slate-100">Empleados y Permisos</p>
                <p class="text-xs text-slate-500 dark:text-slate-400">Administrar accesos</p>
              </div>
            </div>
            <span class="material-symbols-outlined text-slate-400 group-hover:text-primary transition-colors">chevron_right</span>
          </button>

          <!-- Configuración del Negocio -->
          <button class="flex w-full items-center justify-between p-4 transition-colors hover:bg-slate-50 dark:hover:bg-slate-700/50 text-left group">
            <div class="flex items-center gap-4">
              <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-purple-50 dark:bg-purple-900/20 text-purple-600 dark:text-purple-400">
                <span class="material-symbols-outlined">storefront</span>
              </div>
              <div>
                <p class="text-base font-semibold text-slate-900 dark:text-slate-100">Configuración del Negocio</p>
                <p class="text-xs text-slate-500 dark:text-slate-400">Horarios e info general</p>
              </div>
            </div>
            <span class="material-symbols-outlined text-slate-400 group-hover:text-primary transition-colors">chevron_right</span>
          </button>

          <!-- Dispositivos Autorizados -->
          <button class="flex w-full items-center justify-between p-4 transition-colors hover:bg-slate-50 dark:hover:bg-slate-700/50 text-left group">
            <div class="flex items-center gap-4">
              <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300">
                <span class="material-symbols-outlined">smartphone</span>
              </div>
              <div>
                <p class="text-base font-semibold text-slate-900 dark:text-slate-100">Dispositivos Autorizados</p>
                <p class="text-xs text-slate-500 dark:text-slate-400">Seguridad de la cuenta</p>
              </div>
            </div>
            <span class="material-symbols-outlined text-slate-400 group-hover:text-primary transition-colors">chevron_right</span>
          </button>

          <!-- Historial de Ventas -->
          <button 
            class="flex w-full items-center justify-between p-4 transition-colors hover:bg-slate-50 dark:hover:bg-slate-700/50 text-left group"
          >
            <div class="flex items-center gap-4">
              <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-emerald-50 dark:bg-emerald-900/20 text-emerald-600 dark:text-emerald-400">
                <span class="material-symbols-outlined">history</span>
              </div>
              <div>
                <p class="text-base font-semibold text-slate-900 dark:text-slate-100">Historial de Ventas</p>
                <p class="text-xs text-slate-500 dark:text-slate-400">Ver transacciones pasadas</p>
              </div>
            </div>
            <span class="material-symbols-outlined text-slate-400 group-hover:text-primary transition-colors">chevron_right</span>
          </button>
        </div>
      </section>

      <!-- Cerrar Tienda Toggle -->
      <section v-if="activeTab === 'gestion'">
        <div class="mt-4 overflow-hidden rounded-xl bg-red-50 dark:bg-red-900/10 border border-red-100 dark:border-red-900/30 p-4">
          <div class="flex items-center justify-between gap-4">
            <div class="flex items-center gap-3">
              <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-white dark:bg-red-900/20 text-red-500 shadow-sm">
                <span class="material-symbols-outlined">storefront</span>
              </div>
              <div>
                <h4 class="text-base font-bold text-red-700 dark:text-red-400">Cerrar Tienda</h4>
                <p class="text-xs font-medium text-red-600/80 dark:text-red-400/70">Temporalmente fuera de servicio</p>
              </div>
            </div>
            <button 
              @click="toggleStoreStatus"
              class="relative inline-flex h-6 w-12 items-center rounded-full transition-colors duration-300"
              :class="isStoreClosed ? 'bg-red-500' : 'bg-slate-300'"
            >
              <span 
                class="inline-block h-5 w-5 transform rounded-full bg-white shadow-sm transition-transform duration-300"
                :class="isStoreClosed ? 'translate-x-6' : 'translate-x-1'"
              ></span>
            </button>
          </div>
        </div>
      </section>

      <!-- Reportes Tab Content -->
      <section v-if="activeTab === 'reportes'" class="flex flex-col items-center justify-center py-12 text-center">
        <div class="flex h-16 w-16 items-center justify-center rounded-full bg-slate-100 dark:bg-slate-800 text-slate-400 mb-4">
          <span class="material-symbols-outlined text-[32px]">bar_chart</span>
        </div>
        <h3 class="text-lg font-bold text-slate-900 dark:text-white mb-2">Reportes</h3>
        <p class="text-sm text-slate-500 dark:text-slate-400 max-w-xs">
          Los reportes de ventas, inventario y más estarán disponibles próximamente.
        </p>
      </section>

      <div class="h-10"></div>
    </main>

    <BottomNav />
  </div>
</template>

<style scoped>
.material-symbols-outlined {
  font-variation-settings: 'FILL' 0, 'wght' 400, 'GRAD' 0, 'opsz' 24;
}
</style>

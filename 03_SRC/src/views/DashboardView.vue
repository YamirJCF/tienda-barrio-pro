<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useSalesStore } from '../stores/sales';
import { useInventoryStore } from '../stores/inventory';
import { useAuthStore } from '../stores/auth';
import { useNotificationsStore } from '../stores/notificationsStore';
import { Decimal } from 'decimal.js';
import BottomNav from '../components/BottomNav.vue';
import UserProfileSidebar from '../components/UserProfileSidebar.vue';
import StatCard from '../components/ui/StatCard.vue';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';

const router = useRouter();
const salesStore = useSalesStore();
const inventoryStore = useInventoryStore();
const authStore = useAuthStore();
const notificationsStore = useNotificationsStore();
const { formatWithSign } = useCurrencyFormat();

// State
const openingModalOpen = ref(false);
const baseMoney = ref('');
const profileSidebarOpen = ref(false);

// Initialize
onMounted(() => {
  inventoryStore.initializeSampleData();
});

// Computed
const isStoreOpen = computed(() => salesStore.isStoreOpen);

// Formatted values using composable
const formattedCash = computed(() => formatWithSign(salesStore.currentCash));
const formattedTodayTotal = computed(() => formatWithSign(salesStore.todayTotal));
const formattedTodayFiado = computed(() => formatWithSign(salesStore.todayFiado));

const totalProducts = computed(() => inventoryStore.totalProducts);

// Auth computed
const isAdmin = computed(() => authStore.isAdmin);
const isEmployee = computed(() => authStore.isEmployee);
const currentUser = computed(() => authStore.currentUser);
const currentStore = computed(() => authStore.currentStore);
const storeName = computed(() => currentStore.value?.storeName || 'Mi Tiendita');

// Methods
const toggleStore = () => {
  if (!isStoreOpen.value) {
    openingModalOpen.value = true;
  } else {
    // Redirigir a CashControlView para hacer el arqueo antes de cerrar
    router.push('/cash-control');
  }
};

const confirmOpen = () => {
  const amount = baseMoney.value ? new Decimal(baseMoney.value) : new Decimal(0);
  salesStore.openStore(amount);
  openingModalOpen.value = false;
  baseMoney.value = '';
};

const navigateTo = (route: string) => {
  router.push(route);
};

const openProfileSidebar = () => {
  profileSidebarOpen.value = true;
};

const closeProfileSidebar = () => {
  profileSidebarOpen.value = false;
};

const handleLogout = () => {
  profileSidebarOpen.value = false;
  authStore.logout();
  router.push('/login');
};

const navigateToNotifications = () => {
  router.push('/notifications');
};
</script>

<template>
  <div class="pb-24 bg-gray-50 dark:bg-background-dark min-h-screen">
    <!-- Header -->
    <header
      class="sticky top-0 z-30 bg-white dark:bg-surface-dark px-4 py-3 border-b border-gray-200 dark:border-gray-800 shadow-sm flex items-center justify-between">
      <h1 class="text-xl font-bold tracking-tight text-slate-900 dark:text-white font-display">{{ storeName }}</h1>
      <div class="flex items-center gap-4">
        <button @click="navigateToNotifications"
          class="relative text-slate-600 dark:text-slate-300 hover:text-slate-800 dark:hover:text-white transition-colors">
          <span class="material-symbols-outlined text-[26px]">notifications</span>
          <span v-if="notificationsStore.hasUnread"
            class="absolute -top-1 -right-1 min-w-[18px] h-[18px] flex items-center justify-center text-[10px] font-bold rounded-full bg-red-500 text-white ring-2 ring-white dark:ring-surface-dark">
            {{ notificationsStore.unreadCount > 9 ? '9+' : notificationsStore.unreadCount }}
          </span>
        </button>
        <button @click="openProfileSidebar"
          class="h-8 w-8 overflow-hidden rounded-full border border-gray-200 dark:border-gray-700 bg-gray-100 hover:ring-2 hover:ring-primary/50 transition-all">
          <div class="h-full w-full bg-gradient-to-br from-blue-400 to-purple-500"></div>
        </button>
      </div>
    </header>

    <main class="p-4 flex flex-col gap-6 max-w-md mx-auto">
      <!-- Status Card -->
      <div class="w-full rounded-2xl bg-slate-800 p-6 text-white shadow-lg flex flex-col items-center gap-6">
        <div class="flex flex-col items-center gap-2">
          <h2 class="text-3xl font-bold tracking-tight font-display">
            Estado: {{ isStoreOpen ? 'ABIERTO' : 'CERRADO' }}
          </h2>
          <div class="h-1.5 w-24 rounded-full" :class="isStoreOpen ? 'bg-green-500' : 'bg-slate-600'"></div>
        </div>

        <button @click="toggleStore"
          class="group relative flex h-16 w-full cursor-pointer items-center rounded-full p-1.5 ring-1 ring-white/10 transition-all active:scale-[0.98]"
          :class="isStoreOpen ? 'bg-green-500' : 'bg-slate-900/50'">
          <div class="absolute inset-0 flex items-center justify-center z-10 pointer-events-none">
            <span v-if="!isStoreOpen" class="ml-12 text-sm font-semibold text-slate-300">Desliza para ABRIR</span>
            <span v-else class="text-sm font-bold text-white uppercase tracking-widest">ABIERTO</span>
          </div>
          <div
            class="h-12 w-12 rounded-full bg-white shadow-md z-20 flex items-center justify-center transition-all duration-300"
            :class="isStoreOpen ? 'translate-x-[calc(100%-3rem)] text-green-600' : 'text-slate-800'">
            <span class="material-symbols-outlined text-[24px]">
              {{ isStoreOpen ? 'lock_open' : 'arrow_forward' }}
            </span>
          </div>
        </button>
      </div>

      <!-- SPEC-005: Banner Tienda Cerrada (Para Empleados) -->
      <div v-if="isEmployee && !authStore.storeOpenStatus"
        class="relative overflow-hidden rounded-xl border border-amber-200 dark:border-amber-800 bg-amber-50 dark:bg-amber-900/20 p-4 shadow-sm">
        <div class="flex items-center gap-3">
          <div
            class="flex h-10 w-10 items-center justify-center rounded-full bg-amber-100 dark:bg-amber-800/50 text-amber-600 dark:text-amber-400">
            <span class="material-symbols-outlined">storefront</span>
          </div>
          <div class="flex flex-col">
            <h3 class="text-amber-900 dark:text-amber-100 font-bold text-sm">Tienda Cerrada</h3>
            <p class="text-amber-700 dark:text-amber-300 text-xs">Inicie jornada para vender. Contacta al administrador.
            </p>
          </div>
        </div>
      </div>

      <!-- Info Banner -->
      <div v-if="!isStoreOpen && totalProducts === 0"
        class="relative overflow-hidden rounded-xl border border-blue-200 dark:border-blue-800 bg-blue-50 dark:bg-blue-900/20 p-4 shadow-sm">
        <div class="flex flex-col gap-3">
          <div class="flex flex-col gap-1">
            <h3 class="text-blue-900 dark:text-blue-100 font-bold text-sm flex items-center gap-2">
              <span class="material-symbols-outlined text-blue-600 dark:text-blue-400 text-[20px]">verified</span>
              ¡Bienvenido! Tu tienda está lista.
            </h3>
            <p class="text-blue-700 dark:text-blue-300 text-xs leading-relaxed">
              Paso 1: Agrega tu primer producto para empezar a vender.
            </p>
          </div>
          <button @click="navigateTo('/inventory')"
            class="self-start rounded-lg bg-blue-600 hover:bg-blue-700 px-4 py-2 text-xs font-semibold text-white shadow-sm flex items-center gap-1 transition-colors">
            Ir al Inventario
            <span class="material-symbols-outlined text-[16px]">arrow_forward</span>
          </button>
        </div>
      </div>

      <!-- Quick Stats Grid -->
      <div class="grid grid-cols-2 gap-3">
        <StatCard icon="payments" icon-color="green" title="Caja Real" :value="formattedCash" />
        <StatCard icon="show_chart" icon-color="blue" title="Ventas Hoy" :value="formattedTodayTotal"
          :subtitle="`${salesStore.todayCount} ventas`" />
        <StatCard icon="person" icon-color="orange" title="Por Cobrar" :value="formattedTodayFiado" />
        <StatCard icon="inventory_2" icon-color="purple" title="Inventario" :value="`${totalProducts} Prod.`"
          :subtitle="inventoryStore.lowStockProducts.length > 0 ? `${inventoryStore.lowStockProducts.length} con stock bajo` : undefined"
          :subtitle-color="inventoryStore.lowStockProducts.length > 0 ? 'red' : undefined" />
      </div>

      <!-- Quick Actions - Admin Only -->
      <section v-if="isAdmin">
        <h3 class="ml-1 text-sm font-bold text-slate-900 dark:text-white mb-3">Gestión de Tienda</h3>
        <div
          class="flex flex-col overflow-hidden rounded-xl bg-white dark:bg-surface-dark shadow-sm border border-slate-100 dark:border-slate-800 divide-y divide-slate-100 dark:divide-slate-800">
          <button @click="navigateTo('/admin')"
            class="flex w-full items-center justify-between p-4 hover:bg-gray-50 dark:hover:bg-slate-800/50 text-left transition-colors">
            <div class="flex items-center gap-3">
              <div
                class="flex h-10 w-10 items-center justify-center rounded-full bg-indigo-50 dark:bg-indigo-900/20 text-indigo-600 dark:text-indigo-400">
                <span class="material-symbols-outlined">group</span>
              </div>
              <span class="text-sm font-medium text-slate-700 dark:text-slate-200">Gestionar Empleados</span>
            </div>
            <span class="material-symbols-outlined text-slate-400">chevron_right</span>
          </button>

          <button @click="navigateTo('/admin')"
            class="flex w-full items-center justify-between p-4 hover:bg-gray-50 dark:hover:bg-slate-800/50 text-left transition-colors">
            <div class="flex items-center gap-3">
              <div
                class="flex h-10 w-10 items-center justify-center rounded-full bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300">
                <span class="material-symbols-outlined">settings</span>
              </div>
              <span class="text-sm font-medium text-slate-700 dark:text-slate-200">Configuración de Tienda</span>
            </div>
            <span class="material-symbols-outlined text-slate-400">chevron_right</span>
          </button>
        </div>
      </section>
    </main>

    <!-- Opening Modal -->
    <Teleport to="body">
      <Transition name="modal">
        <div v-if="openingModalOpen" class="fixed inset-0 z-50 flex items-end justify-center">
          <div class="absolute inset-0 bg-slate-900/60 backdrop-blur-[2px]" @click="openingModalOpen = false"></div>
          <div
            class="relative w-full max-w-md bg-white dark:bg-surface-dark rounded-t-3xl p-6 shadow-2xl animate-slide-up">
            <div class="mx-auto mb-6 h-1.5 w-12 rounded-full bg-slate-200 dark:bg-slate-700 cursor-pointer"
              @click="openingModalOpen = false"></div>
            <div class="flex flex-col gap-6">
              <div class="text-center">
                <div
                  class="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-green-50 dark:bg-green-900/20 text-green-600 dark:text-green-400 ring-1 ring-green-100 dark:ring-green-900">
                  <span class="material-symbols-outlined text-[32px]">storefront</span>
                </div>
                <h3 class="text-xl font-bold text-slate-900 dark:text-white">Iniciar Jornada</h3>
                <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">Confirma el valor base en caja.</p>
              </div>

              <div class="space-y-2">
                <label class="text-xs font-semibold uppercase tracking-wide text-slate-500 ml-1">Base / Sencillo</label>
                <div class="relative">
                  <span class="absolute left-4 top-1/2 -translate-y-1/2 text-slate-400 font-bold text-lg">$</span>
                  <input v-model="baseMoney" type="number" placeholder="0"
                    class="w-full rounded-xl border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-slate-800 py-4 pl-9 pr-4 text-xl font-bold text-slate-900 dark:text-white focus:border-primary focus:bg-white dark:focus:bg-slate-900 focus:ring-primary transition-all outline-none" />
                </div>
              </div>

              <button @click="confirmOpen"
                class="w-full rounded-xl bg-emerald-600 hover:bg-emerald-700 py-4 text-base font-bold text-white shadow-lg shadow-emerald-600/30 active:scale-[0.98] transition-all flex items-center justify-center gap-2">
                CONFIRMAR APERTURA
                <span class="material-symbols-outlined text-[22px]">lock_open_right</span>
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- User Profile Sidebar -->
    <UserProfileSidebar :isOpen="profileSidebarOpen" :userType="isEmployee ? 'employee' : 'admin'"
      :userName="currentUser?.name || 'Usuario'" :userEmail="currentUser?.email || ''" @close="closeProfileSidebar"
      @logout="handleLogout" />

    <BottomNav />
  </div>
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

@keyframes slideUp {
  from {
    transform: translateY(100%);
  }

  to {
    transform: translateY(0);
  }
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
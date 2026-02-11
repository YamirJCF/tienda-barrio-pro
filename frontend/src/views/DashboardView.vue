<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { useSalesStore } from '../stores/sales';
import { useInventoryStore } from '../stores/inventory';
import { useCashRegisterStore } from '../stores/cashRegister';
import { useAuthStore } from '../stores/auth';
import { useNotificationsStore } from '../stores/notificationsStore';
import { useDevicesStore } from '../stores/devices'; // [NEW]
import { Decimal } from 'decimal.js';
import { 
  Bell, 
  User as UserIcon, 
  LockOpen, 
  ArrowRight, 
  LockKeyhole, 
  Verified, 
  MoveRight,
  ChevronRight,
  Settings,
  Users,
  Calculator,
  Package
} from 'lucide-vue-next';
import BottomNav from '../components/BottomNav.vue';
import UserProfileSidebar from '../components/UserProfileSidebar.vue';
import SyncIndicator from '../components/common/SyncIndicator.vue';
import StatCard from '../components/ui/StatCard.vue';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';

const router = useRouter();
const salesStore = useSalesStore();
const inventoryStore = useInventoryStore();
const cashRegisterStore = useCashRegisterStore(); // Added for sync
const authStore = useAuthStore();
const notificationsStore = useNotificationsStore();
const devicesStore = useDevicesStore(); // [NEW]
const { formatWithSign } = useCurrencyFormat();

// State
let pollInterval: ReturnType<typeof setInterval> | null = null;
const profileSidebarOpen = ref(false);

onMounted(async () => {
  salesStore.initialize();
  inventoryStore.initialize();
  
  // FIX: Admin users might not have storeId in currentUser, but have selected currentStore
  const activeStoreId = authStore.currentStore?.id || authStore.currentUser?.storeId;

  if (activeStoreId) {
      // WO-006: Sync cash session state to avoid showing previous user's session
      await cashRegisterStore.syncFromBackend(activeStoreId);
  } else {
      console.warn('⚠️ [Dashboard] No active store ID found for sync');
  }

  // ACCESS REQUEST POLLING (replaces deleted AccessRequestsWidget)
  if (authStore.isAdmin) {
    devicesStore.fetchPendingRequests(); // [UPDATED]
    pollInterval = setInterval(() => {
      devicesStore.fetchPendingRequests(); // [UPDATED]
    }, 30_000); // Every 30 seconds
  }
});

onUnmounted(() => {
  if (pollInterval) {
    clearInterval(pollInterval);
    pollInterval = null;
  }
});

// WO: initializeSampleData eliminada - SPEC-007

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
  // CRITICAL: Always redirect to CashControlView which requires PIN
  // Do NOT allow opening/closing without PIN validation
  router.push('/cash-control');
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

const handleLogout = async () => {
  profileSidebarOpen.value = false;
  await authStore.logout();
  router.push('/login');
};

const navigateToNotifications = () => {
  router.push('/notifications');
};
</script>

<template>
  <div class="pb-24 bg-gray-50 dark:bg-background-dark min-h-screen">
    <header
      class="sticky top-0 z-30 bg-white dark:bg-surface-dark px-4 py-3 border-b border-gray-200 dark:border-gray-800 shadow-sm flex items-center justify-between"
    >
      <h1 class="text-xl font-bold tracking-tight text-slate-900 dark:text-white font-display">
        {{ storeName }}
      </h1>
      <div class="flex items-center gap-4">
        <SyncIndicator />
        <button
          @click="navigateToNotifications"
          class="relative text-slate-600 dark:text-slate-300 hover:text-slate-800 dark:hover:text-white transition-colors"
        >
          <Bell :size="24" :stroke-width="1.5" />
          <span
            v-if="notificationsStore.hasUnread"
            class="absolute -top-1 -right-1 min-w-[18px] h-[18px] flex items-center justify-center text-[10px] font-bold rounded-full bg-red-500 text-white ring-2 ring-white dark:ring-surface-dark"
          >
            {{ notificationsStore.unreadCount > 9 ? '9+' : notificationsStore.unreadCount }}
          </span>
        </button>
        <button
          @click="openProfileSidebar"
          class="h-9 w-9 overflow-hidden rounded-[10px] border border-gray-200 dark:border-gray-700 bg-slate-100 dark:bg-slate-800 hover:ring-2 hover:ring-primary/50 transition-all flex items-center justify-center"
        >
          <span class="text-xs font-bold text-slate-600 dark:text-slate-300">{{ currentUser?.name?.substring(0,2).toUpperCase() || '??' }}</span>
        </button>
      </div>
    </header>

    <main class="p-4 flex flex-col gap-6 max-w-md mx-auto">
      <!-- Status Card -->
      <div
        class="w-full rounded-2xl bg-slate-800 p-6 text-white shadow-lg flex flex-col items-center gap-6"
      >
        <div class="flex flex-col items-center gap-2">
          <h2 class="text-3xl font-bold tracking-tight font-display">
            Estado: {{ isStoreOpen ? 'ABIERTO' : 'CERRADO' }}
          </h2>
          <div
            class="h-1.5 w-24 rounded-full"
            :class="isStoreOpen ? 'bg-green-500' : 'bg-slate-600'"
          ></div>
        </div>

        <button
          @click="toggleStore"
          class="group relative flex h-16 w-full cursor-pointer items-center rounded-full p-1.5 ring-1 ring-white/10 transition-all active:scale-[0.98]"
          :class="isStoreOpen ? 'bg-green-500' : 'bg-slate-900/50'"
        >
          <div class="absolute inset-0 flex items-center justify-center z-10 pointer-events-none">
            <span v-if="!isStoreOpen" class="ml-12 text-sm font-semibold text-slate-300"
              >Desliza para ABRIR</span
            >
            <span v-else class="text-sm font-bold text-white uppercase tracking-widest"
              >ABIERTO</span
            >
          </div>
          <div
            class="h-12 w-12 rounded-full bg-white shadow-md z-20 flex items-center justify-center transition-all duration-300"
            :class="isStoreOpen ? 'translate-x-[calc(100%-3rem)] text-green-600' : 'text-slate-800'"
          >
             <component :is="isStoreOpen ? LockOpen : ArrowRight" :size="24" :stroke-width="2" />
          </div>
        </button>
      </div>

      <!-- SPEC-005: Banner Jornada no Aprobada (Para Empleados) -->
      <div
        v-if="isEmployee && authStore.deviceApproved !== 'approved'"
        class="relative overflow-hidden rounded-xl border border-amber-200 dark:border-amber-800 bg-amber-50 dark:bg-amber-900/20 p-4 shadow-sm"
      >
        <div class="flex items-center gap-3">
          <div
            class="flex h-10 w-10 items-center justify-center rounded-full bg-amber-100 dark:bg-amber-800/50 text-amber-600 dark:text-amber-400"
          >
            <LockKeyhole :size="20" />
          </div>
          <div class="flex flex-col">
            <h3 class="text-amber-900 dark:text-amber-100 font-bold text-sm">Acceso Pendiente</h3>
            <p class="text-amber-700 dark:text-amber-300 text-xs">
              Tu dispositivo requiere aprobación del administrador para iniciar ventas.
            </p>
          </div>
        </div>
      </div>

      <!-- Info Banner -->
      <div
        v-if="!isStoreOpen && totalProducts === 0"
        class="relative overflow-hidden rounded-xl border border-blue-200 dark:border-blue-800 bg-blue-50 dark:bg-blue-900/20 p-4 shadow-sm"
      >
        <div class="flex flex-col gap-3">
          <div class="flex flex-col gap-1">
            <h3 class="text-blue-900 dark:text-blue-100 font-bold text-sm flex items-center gap-2">
              <Verified :size="20" class="text-blue-600 dark:text-blue-400" />
              ¡Bienvenido! Tu tienda está lista.
            </h3>
            <p class="text-blue-700 dark:text-blue-300 text-xs leading-relaxed">
              Paso 1: Agrega tu primer producto para empezar a vender.
            </p>
          </div>
          <button
            @click="navigateTo('/inventory')"
            class="self-start rounded-lg bg-blue-600 hover:bg-blue-700 px-4 py-2 text-xs font-semibold text-white shadow-sm flex items-center gap-1 transition-colors"
          >
            Ir al Inventario
            <MoveRight :size="16" />
          </button>
        </div>
      </div>

      <!-- Quick Stats Grid -->
      <div class="grid grid-cols-2 gap-3">
        <StatCard icon="payments" icon-color="green" title="Caja Real" :value="formattedCash" />
        <StatCard
          icon="show_chart"
          icon-color="blue"
          title="Ventas Hoy"
          :value="formattedTodayTotal"
          :subtitle="`${salesStore.todayCount} ventas`"
        />
        <StatCard
          icon="person"
          icon-color="orange"
          title="Por Cobrar"
          :value="formattedTodayFiado"
          :subtitle="`${salesStore.todayFiadoCount} fiados`"
        />
        <StatCard
          icon="inventory_2"
          icon-color="purple"
          title="Inventario"
          :value="`${totalProducts} Prod.`"
          :subtitle="
            inventoryStore.lowStockProducts.length > 0
              ? `${inventoryStore.lowStockProducts.length} con stock bajo`
              : undefined
          "
          :subtitle-color="inventoryStore.lowStockProducts.length > 0 ? 'red' : undefined"
        />
      </div>

      <!-- Quick Actions - Admin Only -->
      <section v-if="isAdmin">
        <h3 class="ml-1 text-sm font-bold text-slate-900 dark:text-white mb-3">
          Gestión de Tienda
        </h3>
        <div
          class="flex flex-col overflow-hidden rounded-xl bg-white dark:bg-surface-dark shadow-sm border border-slate-100 dark:border-slate-800 divide-y divide-slate-100 dark:divide-slate-800"
        >
          <button
            @click="navigateTo('/employees')"
            class="flex w-full items-center justify-between p-4 hover:bg-gray-50 dark:hover:bg-slate-800/50 text-left transition-colors"
          >
            <div class="flex items-center gap-3">
              <div
                class="flex h-10 w-10 items-center justify-center rounded-full bg-indigo-50 dark:bg-indigo-900/20 text-indigo-600 dark:text-indigo-400"
              >
                <Users :size="20" />
              </div>
              <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >Gestionar Empleados</span
              >
            </div>
            <ChevronRight :size="20" class="text-slate-400" />
          </button>

          <button
            @click="navigateTo('/admin?tab=gestion')"
            class="flex w-full items-center justify-between p-4 hover:bg-gray-50 dark:hover:bg-slate-800/50 text-left transition-colors"
          >
            <div class="flex items-center gap-3">
              <div
                class="flex h-10 w-10 items-center justify-center rounded-full bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300"
              >
                <Settings :size="20" />
              </div>
              <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >Configuración de Tienda</span
              >
            </div>
             <ChevronRight :size="20" class="text-slate-400" />
          </button>
        </div>
      </section>

      <!-- Quick Actions - Employee Only -->
      <section v-else>
        <h3 class="ml-1 text-sm font-bold text-slate-900 dark:text-white mb-3">
          Acciones Rápidas
        </h3>
        <div
          class="flex flex-col overflow-hidden rounded-xl bg-white dark:bg-surface-dark shadow-sm border border-slate-100 dark:border-slate-800 divide-y divide-slate-100 dark:divide-slate-800"
        >
          <!-- Vender -->
          <button
            @click="navigateTo('/pos')"
            class="flex w-full items-center justify-between p-4 hover:bg-gray-50 dark:hover:bg-slate-800/50 text-left transition-colors"
          >
            <div class="flex items-center gap-3">
              <div
                class="flex h-10 w-10 items-center justify-center rounded-full bg-emerald-50 dark:bg-emerald-900/20 text-emerald-600 dark:text-emerald-400"
              >
                <Calculator :size="20" />
              </div>
              <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >Realizar Venta</span
              >
            </div>
            <ChevronRight :size="20" class="text-slate-400" />
          </button>

          <!-- Productos -->
          <button
            @click="navigateTo('/inventory')"
            class="flex w-full items-center justify-between p-4 hover:bg-gray-50 dark:hover:bg-slate-800/50 text-left transition-colors"
          >
            <div class="flex items-center gap-3">
              <div
                class="flex h-10 w-10 items-center justify-center rounded-full bg-blue-50 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400"
              >
                <Package :size="20" />
              </div>
              <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >Gestionar Productos</span
              >
            </div>
            <ChevronRight :size="20" class="text-slate-400" />
          </button>
             
          <!-- Clientes -->
          <button
            @click="navigateTo('/clients')"
            class="flex w-full items-center justify-between p-4 hover:bg-gray-50 dark:hover:bg-slate-800/50 text-left transition-colors"
          >
            <div class="flex items-center gap-3">
              <div
                class="flex h-10 w-10 items-center justify-center rounded-full bg-purple-50 dark:bg-purple-900/20 text-purple-600 dark:text-purple-400"
              >
                <Users :size="20" />
              </div>
              <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >Ver Clientes</span
              >
            </div>
            <ChevronRight :size="20" class="text-slate-400" />
          </button>
        </div>
      </section>
    </main>

    <!-- User Profile Sidebar -->
    <UserProfileSidebar
      :isOpen="profileSidebarOpen"
      @close="closeProfileSidebar"
      @logout="handleLogout"
    />

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

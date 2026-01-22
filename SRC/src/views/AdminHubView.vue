<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useSalesStore } from '../stores/sales';
import { useCashRegisterStore } from '../stores/cashRegister';
import { useCashControlStore } from '../stores/cashControl';
import { useAuthStore } from '../stores/auth'; // Import auth store
import BottomNav from '../components/BottomNav.vue';
import ReportsContent from '../components/ReportsContent.vue';
import DeviceApprovalModal from '../components/DeviceApprovalModal.vue';
// WO-004: Modal de PIN para SPEC-006 (consolidado)
// T-008: Modal de PIN para SPEC-006 (consolidado)
import PinSetupModal from '../components/PinSetupModal.vue';
// A-02: UserProfileSidebar para icono de perfil
import UserProfileSidebar from '../components/UserProfileSidebar.vue';
// WO-PHASE4-001: Store Configuration Form
import StoreConfigForm from '../components/admin/StoreConfigForm.vue';

const router = useRouter();
const route = useRoute();
const salesStore = useSalesStore();
const cashRegisterStore = useCashRegisterStore();
const cashControlStore = useCashControlStore();
const authStore = useAuthStore(); // Use auth store

// State
const activeTab = ref<'reportes' | 'gestion' | 'config'>('gestion');
const showDeviceModal = ref(false);
// WO-004: State para modal de PIN (consolidado)
const showPinSetupModal = ref(false);
// T-008: State para confirmación de cierre de tienda
const showCloseStoreConfirm = ref(false);
// A-02: State para sidebar de perfil
const showProfileSidebar = ref(false);

// Computed: detectar si ya hay PIN configurado para determinar modo
const hasPinConfigured = computed(() => cashControlStore.hasPinConfigured);
const pinSetupMode = computed(() => (hasPinConfigured.value ? 'change' : 'setup'));

const isAdmin = computed(() => authStore.isAdmin);
const canViewReports = computed(() => authStore.canViewReports);

// Check PIN status on mount & Permission Check
onMounted(() => {
  // Security Check: If not admin and can't view reports, kick out
  if (!isAdmin.value && !canViewReports.value) {
    router.replace('/');
    return;
  }

  cashControlStore.checkPinConfigured();

  // A-02: Leer query param para seleccionar tab automáticamente
  if (route.query.tab === 'gestion' && isAdmin.value) {
    activeTab.value = 'gestion';
  } else if (route.query.tab === 'reportes') {
    activeTab.value = 'reportes';
  } else if (!isAdmin.value) {
    // Force reports for non-admins
    activeTab.value = 'reportes';
  }
});

// Watch for unauthorized tab switches
watch(activeTab, (newTab) => {
  if (newTab === 'gestion' && !isAdmin.value) {
    activeTab.value = 'reportes';
  }
});

// Computed - Estado operativo de la tienda (diferente de la caja)
// const isStoreClosed = computed(() => storeStatusStore.isClosed); // Replacing with cash register status
const isStoreClosed = computed(() => !cashRegisterStore.isOpen);

// Methods
const goBack = () => {
  router.push('/');
};

const toggleStoreStatus = () => {
  // Solo cambiar estado operativo, NO afecta la caja
  // storeStatusStore.toggleStatus(); // Deprecated
  // If we want to toggle status we should likely act on auth or just redirect to cash control
  // For now let's just log or no-op as status is derived from session
};

// T-008: Confirmar antes de cerrar tienda
const confirmCloseStore = () => {
  // Si la tienda está cerrada, abrir directamente (sin confirmación)
  if (isStoreClosed.value) {
    toggleStoreStatus();
  } else {
    // Si está abierta, pedir confirmación antes de cerrar
    showCloseStoreConfirm.value = true;
  }
};

const executeCloseStore = () => {
  showCloseStoreConfirm.value = false;
  toggleStoreStatus();
};

const navigateTo = (route: string) => {
  router.push(route);
};
</script>

<template>
  <div
    class="relative flex min-h-screen w-full flex-col overflow-x-hidden pb-20 bg-background-light dark:bg-background-dark"
  >
    <!-- Header -->
    <header
      class="sticky top-0 z-40 bg-background-light/95 dark:bg-background-dark/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-800"
    >
      <div class="flex items-center justify-between px-4 py-3 gap-3">
        <button
          @click="goBack"
          aria-label="Volver atrás"
          class="flex items-center justify-center -ml-2 p-2 rounded-full text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <span class="material-symbols-outlined">arrow_back</span>
        </button>
        <h2 class="text-xl font-bold leading-tight tracking-tight flex-1 dark:text-white">
          Administración
        </h2>
        <div class="flex items-center justify-end">
          <button
            @click="showProfileSidebar = true"
            aria-label="Perfil de usuario"
            class="relative flex items-center justify-center overflow-hidden rounded-full h-10 w-10 bg-slate-200 dark:bg-slate-700 ring-2 ring-white dark:ring-slate-800 shadow-sm cursor-pointer hover:ring-primary transition-all"
          >
            <div class="h-full w-full bg-gradient-to-br from-blue-400 to-purple-500"></div>
          </button>
        </div>
      </div>
    </header>

    <!-- Tabs -->
    <div
      class="sticky top-[65px] z-30 w-full bg-background-light dark:bg-background-dark px-4 pb-4 pt-2 shadow-[0_4px_10px_-10px_rgba(0,0,0,0.1)]"
    >
      <div
        class="flex h-12 w-full items-center justify-center rounded-xl bg-slate-200 dark:bg-slate-800 p-1"
      >
        <label
          v-if="isAdmin || canViewReports"
          class="flex cursor-pointer h-full flex-1 items-center justify-center overflow-hidden rounded-lg px-2 transition-all"
          :class="
            activeTab === 'reportes'
              ? 'bg-white dark:bg-slate-700 shadow-sm text-primary dark:text-primary font-bold ring-1 ring-black/5 dark:ring-white/10'
              : 'text-slate-500 dark:text-slate-400 font-semibold hover:bg-white/50 dark:hover:bg-slate-700/50'
          "
          @click="activeTab = 'reportes'"
        >
          <span class="flex items-center gap-2 truncate text-sm">
            <span class="material-symbols-outlined text-[20px]">bar_chart</span>
            Reportes
          </span>
        </label>
        <label
          v-if="isAdmin"
          class="flex cursor-pointer h-full flex-1 items-center justify-center overflow-hidden rounded-lg px-2 transition-all"
          :class="
            activeTab === 'gestion'
              ? 'bg-white dark:bg-slate-700 shadow-sm text-primary dark:text-primary font-bold ring-1 ring-black/5 dark:ring-white/10'
              : 'text-slate-500 dark:text-slate-400 font-semibold hover:bg-white/50 dark:hover:bg-slate-700/50'
          "
          @click="activeTab = 'gestion'"
        >
          <span class="flex items-center gap-2 truncate text-sm">
            <span class="material-symbols-outlined text-[20px]">settings</span>
            Gestión
          </span>
        </label>
        <label
          v-if="isAdmin"
          class="flex cursor-pointer h-full flex-1 items-center justify-center overflow-hidden rounded-lg px-2 transition-all"
          :class="
            activeTab === 'config'
              ? 'bg-white dark:bg-slate-700 shadow-sm text-primary dark:text-primary font-bold ring-1 ring-black/5 dark:ring-white/10'
              : 'text-slate-500 dark:text-slate-400 font-semibold hover:bg-white/50 dark:hover:bg-slate-700/50'
          "
          @click="activeTab = 'config'"
        >
          <span class="flex items-center gap-2 truncate text-sm">
            <span class="material-symbols-outlined text-[20px]">tune</span>
            Config
          </span>
        </label>
      </div>
    </div>

    <!-- Main Content -->
    <main class="flex flex-col gap-6 px-4 pt-4">
      <!-- Control de Dinero -->
      <section v-if="activeTab === 'gestion'">
        <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-3 px-1">
          Control de Dinero
        </h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <!-- Caja Abierta -->
          <div
            class="relative flex flex-col justify-between rounded-xl bg-white dark:bg-slate-800 p-5 shadow-sm border border-slate-100 dark:border-slate-700"
          >
            <div class="flex items-start justify-between mb-4">
              <div
                class="flex h-12 w-12 items-center justify-center rounded-full bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400"
              >
                <span class="material-symbols-outlined text-[28px]">point_of_sale</span>
              </div>
              <span
                class="px-2 py-1 rounded-md text-xs font-bold"
                :class="
                  cashRegisterStore.isOpen
                    ? 'bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-300'
                    : 'bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-400'
                "
              >
                {{ cashRegisterStore.isOpen ? 'ACTIVA' : 'CERRADA' }}
              </span>
            </div>
            <div class="mb-5">
              <h4 class="text-lg font-bold text-slate-900 dark:text-white leading-tight">
                {{ cashRegisterStore.isOpen ? 'Caja Abierta' : 'Caja Cerrada' }}
              </h4>
              <p class="text-sm text-slate-500 dark:text-slate-400 mt-1 font-medium">
                Base inicial:
                <span class="text-slate-900 dark:text-slate-200 font-bold"
                  >$
                  {{
                    (cashRegisterStore.currentSession?.openingBalance.toNumber() || 0)
                      .toString()
                      .replace(/\B(?=(\d{3})+(?!\d))/g, '.')
                  }}</span
                >
              </p>
            </div>
            <button
              @click="navigateTo('/cash-control')"
              class="flex w-full items-center justify-center gap-2 rounded-lg bg-primary py-3 px-4 text-sm font-bold text-white shadow-md shadow-primary/20 transition-transform active:scale-[0.98] hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 dark:focus:ring-offset-slate-900"
            >
              <span class="material-symbols-outlined text-[20px]">receipt_long</span>
              Ver Control de Caja
            </button>
          </div>

          <!-- Gastos del Día -->
          <div
            class="relative flex flex-col justify-between rounded-xl bg-white dark:bg-slate-800 p-5 shadow-sm border border-slate-100 dark:border-slate-700"
          >
            <div class="flex items-start justify-between mb-4">
              <div
                class="flex h-12 w-12 items-center justify-center rounded-full bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400"
              >
                <span class="material-symbols-outlined text-[28px]">account_balance_wallet</span>
              </div>
            </div>
            <div class="mb-5">
              <h4 class="text-lg font-bold text-slate-900 dark:text-white leading-tight">
                Gastos del Día
              </h4>
              <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">Registrar Salida/Gasto</p>
            </div>
            <button
              @click="navigateTo('/expenses')"
              class="flex w-full items-center justify-center gap-2 rounded-lg bg-slate-100 dark:bg-slate-700 py-3 px-4 text-sm font-bold text-slate-700 dark:text-slate-200 transition-colors hover:bg-slate-200 dark:hover:bg-slate-600 active:bg-slate-300"
            >
              <span class="material-symbols-outlined text-[20px]">visibility</span>
              Ver Gastos
            </button>
          </div>
        </div>
      </section>

      <!-- Equipo -->
      <section v-if="activeTab === 'gestion'">
        <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-3 px-1">👥 Equipo</h3>
        <div
          class="flex flex-col overflow-hidden rounded-xl bg-white dark:bg-slate-800 shadow-sm border border-slate-100 dark:border-slate-700 divide-y divide-slate-100 dark:divide-slate-700"
        >
          <!-- Empleados y Permisos -->
          <button
            @click="navigateTo('/employees')"
            class="flex w-full items-center justify-between p-4 transition-colors hover:bg-slate-50 dark:hover:bg-slate-700/50 text-left group"
          >
            <div class="flex items-center gap-4">
              <div
                class="flex h-10 w-10 items-center justify-center rounded-lg bg-blue-50 dark:bg-blue-900/20 text-primary"
              >
                <span class="material-symbols-outlined">group</span>
              </div>
              <div>
                <p class="text-base font-semibold text-slate-900 dark:text-slate-100">
                  Empleados y Permisos
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400">
                  Administrar accesos del equipo
                </p>
              </div>
            </div>
            <span
              class="material-symbols-outlined text-slate-400 group-hover:text-primary transition-colors"
              >chevron_right</span
            >
          </button>
        </div>
      </section>

      <!-- WO-004: Sección Seguridad (PIN) -->
      <section v-if="activeTab === 'gestion'">
        <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-3 px-1">🔐 Seguridad</h3>
        <div
          class="flex flex-col overflow-hidden rounded-xl bg-white dark:bg-slate-800 shadow-sm border border-slate-100 dark:border-slate-700 divide-y divide-slate-100 dark:divide-slate-700"
        >
          <!-- Configurar/Cambiar PIN de Caja (inteligente) -->
          <button
            @click="showPinSetupModal = true"
            class="flex w-full items-center justify-between p-4 transition-colors hover:bg-slate-50 dark:hover:bg-slate-700/50 text-left group"
          >
            <div class="flex items-center gap-4">
              <div
                class="flex h-10 w-10 items-center justify-center rounded-lg bg-emerald-50 dark:bg-emerald-900/20 text-emerald-600 dark:text-emerald-400"
              >
                <span class="material-symbols-outlined">pin</span>
              </div>
              <div>
                <p class="text-base font-semibold text-slate-900 dark:text-slate-100">
                  {{ hasPinConfigured ? 'Cambiar PIN de Caja' : 'Configurar PIN de Caja' }}
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400">
                  {{
                    hasPinConfigured
                      ? 'Modificar tu PIN actual'
                      : 'Establecer PIN para apertura y cierre'
                  }}
                </p>
              </div>
            </div>
            <span
              class="material-symbols-outlined text-slate-400 group-hover:text-emerald-500 transition-colors"
              >chevron_right</span
            >
          </button>
        </div>
      </section>

      <!-- Cerrar Tienda Toggle -->
      <section v-if="activeTab === 'gestion'">
        <div
          class="mt-4 overflow-hidden rounded-xl bg-red-50 dark:bg-red-900/10 border border-red-100 dark:border-red-900/30 p-4"
        >
          <div class="flex items-center justify-between gap-4">
            <div class="flex items-center gap-3">
              <div
                class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-white dark:bg-red-900/20 text-red-500 shadow-sm"
              >
                <span class="material-symbols-outlined">storefront</span>
              </div>
              <div>
                <h4 class="text-base font-bold text-red-700 dark:text-red-400">Cerrar Tienda</h4>
                <p class="text-xs font-medium text-red-600/80 dark:text-red-400/70">
                  Temporalmente fuera de servicio
                </p>
              </div>
            </div>
            <button
              @click="confirmCloseStore"
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
      <section v-if="activeTab === 'reportes'">
        <ReportsContent />
      </section>

      <!-- Store Configuration Tab Content -->
      <section v-if="activeTab === 'config'">
        <StoreConfigForm />
      </section>

      <div class="h-10"></div>
    </main>

    <!-- Device Approval Modal -->
    <DeviceApprovalModal v-model="showDeviceModal" />

    <!-- WO-004: Modal de PIN (consolidado con detección automática de modo) -->
    <PinSetupModal
      :isVisible="showPinSetupModal"
      :mode="pinSetupMode"
      @close="showPinSetupModal = false"
      @success="
        showPinSetupModal = false;
        cashControlStore.checkPinConfigured();
      "
    />

    <!-- T-008: Modal de Confirmación para Cerrar Tienda -->
    <Teleport to="body">
      <Transition name="modal">
        <div
          v-if="showCloseStoreConfirm"
          class="fixed inset-0 z-[100] flex items-center justify-center p-4"
        >
          <div
            class="absolute inset-0 bg-black/60 backdrop-blur-sm"
            @click="showCloseStoreConfirm = false"
          ></div>
          <div
            class="relative w-full max-w-sm bg-white dark:bg-slate-800 rounded-2xl shadow-2xl p-6 animate-scale-in"
          >
            <div class="flex flex-col items-center text-center gap-4">
              <div
                class="flex h-16 w-16 items-center justify-center rounded-full bg-red-100 dark:bg-red-900/30"
              >
                <span class="material-symbols-outlined text-3xl text-red-500">warning</span>
              </div>
              <h3 class="text-xl font-bold text-slate-900 dark:text-white">¿Cerrar Tienda?</h3>
              <p class="text-sm text-slate-600 dark:text-slate-300">
                Esta acción bloqueará las ventas para todo el equipo hasta que vuelvas a abrir.
              </p>
              <div class="flex gap-3 w-full mt-2">
                <button
                  @click="showCloseStoreConfirm = false"
                  class="flex-1 h-12 rounded-xl border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300 font-semibold hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors"
                >
                  Cancelar
                </button>
                <button
                  @click="executeCloseStore"
                  class="flex-1 h-12 rounded-xl bg-red-500 hover:bg-red-600 text-white font-semibold shadow-lg shadow-red-500/20 transition-colors"
                >
                  Cerrar Tienda
                </button>
              </div>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- A-02: UserProfileSidebar para icono de perfil -->
    <UserProfileSidebar
      :isOpen="showProfileSidebar"
      @close="showProfileSidebar = false"
      @logout="router.push('/login')"
    />

    <BottomNav />
  </div>
</template>

<style scoped>
.material-symbols-outlined {
  font-variation-settings:
    'FILL' 0,
    'wght' 400,
    'GRAD' 0,
    'opsz' 24;
}
</style>

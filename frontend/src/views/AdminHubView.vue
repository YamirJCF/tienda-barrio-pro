<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useSalesStore } from '../stores/sales';
import { useCashRegisterStore } from '../stores/cashRegister';
import { useAuthStore } from '../stores/auth'; // Import auth store
import { usePresenceStore } from '../stores/presence'; // New Presence Store import
import { useClientsStore } from '../stores/clients';
import { useNotifications } from '../composables/useNotifications';
import { 
  ArrowLeft, 
  Store, 
  Receipt, 
  Wallet, 
  Eye, 
  WifiOff, 
  Clock, 
  Users, 
  ChevronRight, 
  KeyRound,
  AlertTriangle,
  Truck,
  CreditCard,
  ClipboardCheck
} from 'lucide-vue-next';
import BottomNav from '../components/BottomNav.vue';

// A-02: UserProfileSidebar para icono de perfil
import UserProfileSidebar from '../components/UserProfileSidebar.vue';

const router = useRouter();
const salesStore = useSalesStore();
const cashRegisterStore = useCashRegisterStore();
const authStore = useAuthStore(); // Use auth store
const presenceStore = usePresenceStore(); // Initialize
const clientsStore = useClientsStore();
const { showSuccess, showError } = useNotifications();




// Methods
const goBack = () => {
    router.push('/');
};


const navigateTo = (route: string) => {
    router.push(route);
};

// Computed Properties & Refs (Fixing missing definitions)
const isAdmin = computed(() => authStore.isAdmin);
const showProfileSidebar = ref(false);

// CHK-406: Cupo global por defecto (solo aplica a nuevos clientes)
const globalCreditLimit = ref<number>(0);
const isLoadingCreditLimit = ref(false);
const isSavingCreditLimit = ref(false);
const creditLimitError = ref<string | null>(null);

const loadGlobalCreditLimit = async () => {
    const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
    if (!storeId || !authStore.isAdmin) return;
    isLoadingCreditLimit.value = true;
    creditLimitError.value = null;
    try {
        globalCreditLimit.value = await clientsStore.getDefaultCreditLimit(storeId);
    } catch (e: any) {
        creditLimitError.value = e?.message || 'No se pudo cargar el cupo por defecto.';
    } finally {
        isLoadingCreditLimit.value = false;
    }
};

const saveGlobalCreditLimit = async () => {
    const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
    if (!storeId || isSavingCreditLimit.value) return;
    const numericLimit = Number(globalCreditLimit.value);
    if (!Number.isFinite(numericLimit) || numericLimit < 0) {
        creditLimitError.value = 'El cupo por defecto debe ser mayor o igual a cero.';
        showError(creditLimitError.value);
        return;
    }
    isSavingCreditLimit.value = true;
    creditLimitError.value = null;
    try {
        const updated = await clientsStore.updateGlobalCreditLimit(storeId, numericLimit);
        globalCreditLimit.value = updated;
        showSuccess('Cupo global por defecto actualizado (aplica a clientes nuevos)');
    } catch (e: any) {
        creditLimitError.value = e?.message || 'No se pudo guardar el cupo por defecto.';
        showError(creditLimitError.value || 'Error guardando cupo global');
    } finally {
        isSavingCreditLimit.value = false;
    }
};

onMounted(() => {
    loadGlobalCreditLimit();
});

watch(() => authStore.currentUser?.storeId, (newId) => {
    if (newId) loadGlobalCreditLimit();
});


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
          class="flex items-center justify-center -ml-2 p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <ArrowLeft :size="24" :stroke-width="1.5" />
        </button>
        <h2 class="text-xl font-bold leading-tight tracking-tight flex-1 dark:text-white">
          Administración
        </h2>
        <div class="flex items-center justify-end gap-2">
          <button
            @click="showProfileSidebar = true"
            aria-label="Perfil de usuario"
            class="relative flex items-center justify-center overflow-hidden rounded-[10px] h-9 w-9 bg-slate-100 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 cursor-pointer hover:ring-2 hover:ring-primary/50 transition-all"
          >
             <span class="text-xs font-bold text-slate-600 dark:text-slate-300">{{ authStore.currentUser?.name?.substring(0,2).toUpperCase() || '??' }}</span>
          </button>
        </div>
      </div>
    </header>

    <!-- No Tabs anymore -->

    <!-- Main Content -->
    <main class="flex flex-col gap-6 px-4 pt-4">
      <!-- Control de Dinero -->
      <section>
        <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-3 px-1">
          Control de Dinero
        </h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <!-- Caja Abierta -->
          <div
            class="relative flex flex-col justify-between rounded-2xl bg-white dark:bg-slate-800 p-5 shadow-sm border border-slate-100 dark:border-slate-700"
          >
            <div class="flex items-start justify-between mb-4">
              <div
                class="flex h-12 w-12 items-center justify-center rounded-2xl bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400"
              >
                <Store :size="24" />
              </div>
              <span
                class="px-2 py-1 rounded-lg text-xs font-bold uppercase tracking-wide"
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
              class="flex w-full items-center justify-center gap-2 rounded-xl bg-primary py-3 px-4 text-sm font-bold text-white shadow-md shadow-primary/20 transition-transform active:scale-[0.98] hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2 dark:focus:ring-offset-slate-900"
            >
              <Receipt :size="18" :stroke-width="1.5" />
              Ver Control de Caja
            </button>
          </div>

          <!-- Gastos del Día -->
          <div
            class="relative flex flex-col justify-between rounded-2xl bg-white dark:bg-slate-800 p-5 shadow-sm border border-slate-100 dark:border-slate-700"
          >
            <div class="flex items-start justify-between mb-4">
              <div
                class="flex h-12 w-12 items-center justify-center rounded-2xl bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400"
              >
                <Wallet :size="24" />
              </div>
            </div>
            <div class="mb-5">
              <h4 class="text-lg font-bold text-slate-900 dark:text-white leading-tight">
                Gastos del Día
              </h4>
              <p class="text-sm text-slate-500 dark:text-slate-400 mt-1">Registrar Salida/Gasto</p>
            </div>
            <button
              @click="navigateTo('/cash-control?tab=expenses')"
              class="flex w-full items-center justify-center gap-2 rounded-xl bg-slate-100 dark:bg-slate-700 py-3 px-4 text-sm font-bold text-slate-700 dark:text-slate-200 transition-colors hover:bg-slate-200 dark:hover:bg-slate-600 active:bg-slate-300"
            >
              <Eye :size="18" :stroke-width="1.5" />
              Ver Gastos
            </button>
          </div>

        </div>
      </section>

      <!-- Widget: Personal en Vivo (Presence Monitor) -->
      <section>
        <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-3 px-1 flex items-center gap-2">
          <span>📡 Supervisión en Vivo</span>
          <span 
            class="px-2 py-0.5 rounded-full bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400 text-[10px] font-bold uppercase tracking-wider"
          >
            Beta
          </span>
        </h3>
        
        <div class="bg-white dark:bg-slate-800 rounded-2xl shadow-sm border border-slate-100 dark:border-slate-700 overflow-hidden mb-6">
          <div class="p-4 border-b border-slate-50 dark:border-slate-700/50 flex justify-between items-center">
            <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-300">Estado de Conexión</h4>
            <div class="flex gap-2">
              <span class="flex items-center gap-1 text-[10px] text-slate-500">
                <span class="w-2 h-2 rounded-full bg-green-500"></span> Online
              </span>
              <span class="flex items-center gap-1 text-[10px] text-slate-500">
                <span class="w-2 h-2 rounded-full bg-slate-300"></span> Offline
              </span>
              <span class="flex items-center gap-1 text-[10px] text-slate-500">
                 <span class="w-2 h-2 rounded-full bg-blue-400"></span> Pausa
              </span>
            </div>
          </div>
          
          <div class="divide-y divide-slate-50 dark:divide-slate-700/50">
            <!-- Empty State -->
            <div v-if="presenceStore.activeSessions.size === 0" class="p-8 text-center flex flex-col items-center">
               <WifiOff :size="32" class="text-slate-300 mb-2" />
               <p class="text-xs text-slate-400">No hay empleados reportando actividad reciente.</p>
            </div>

            <!-- Listado de Empleados Detectados -->
            <div 
              v-for="[id, session] in presenceStore.activeSessions" 
              :key="id"
              class="p-4 flex items-center justify-between hover:bg-slate-50 dark:hover:bg-slate-700/30 transition-colors"
            >
               <div class="flex items-center gap-3">
                 <div class="relative">
                    <div class="w-10 h-10 rounded-xl bg-slate-100 dark:bg-slate-700 flex items-center justify-center text-slate-600 dark:text-slate-300 font-bold text-sm">
                      {{ session.name.substring(0,2).toUpperCase() }}
                    </div>
                    <!-- Status Indicator -->
                    <div 
                      class="absolute -bottom-1 -right-1 w-4 h-4 rounded-full border-2 border-white dark:border-slate-800 flex items-center justify-center"
                      :class="{
                        'bg-green-500': presenceStore.getEmployeeStatus(session.employeeId) === 'online',
                        'bg-blue-400': presenceStore.getEmployeeStatus(session.employeeId) === 'paused',
                        'bg-slate-300': presenceStore.getEmployeeStatus(session.employeeId) === 'offline',
                        'bg-red-500 animate-pulse': presenceStore.getEmployeeStatus(session.employeeId) === 'ghost'
                      }"
                    >
                      <!-- Ghost Icon -->
                      <span 
                        v-if="presenceStore.getEmployeeStatus(session.employeeId) === 'ghost'"
                      >
                         <AlertTriangle :size="10" class="text-white" />
                      </span>
                    </div>
                 </div>
                 
                 <div>
                   <p class="text-sm font-bold text-slate-800 dark:text-slate-200">{{ session.name }}</p>
                   <p class="text-[10px] text-slate-500 flex items-center gap-1">
                     <Clock :size="10" />
                     {{ new Date(session.lastSeen).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) }}
                     
                     <span v-if="presenceStore.getEmployeeStatus(session.employeeId) === 'ghost'" class="text-red-500 font-bold ml-1">
                        ⚠️ CAJA ABIERTA SIN SEÑAL
                     </span>
                   </p>
                 </div>
               </div>

               <!-- Actions -->
               <div class="text-right">
                 <span 
                    class="text-xs font-mono font-medium"
                    :class="session.isRegisterOpen ? 'text-emerald-600 dark:text-emerald-400' : 'text-slate-400'"
                 >
                    {{ session.isRegisterOpen ? 'CAJA ABIERTA' : 'Caja Cerrada' }}
                 </span>
               </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Equipo -->
      <section>
        <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-3 px-1">👥 Equipo</h3>
        <div
          class="flex flex-col overflow-hidden rounded-2xl bg-white dark:bg-slate-800 shadow-sm border border-slate-100 dark:border-slate-700 divide-y divide-slate-100 dark:divide-slate-700"
        >
          <!-- Empleados y Permisos -->
          <button
            @click="navigateTo('/employees')"
            class="flex w-full items-center justify-between p-4 transition-colors hover:bg-slate-50 dark:hover:bg-slate-700/50 text-left group"
          >
            <div class="flex items-center gap-4">
              <div
                class="flex h-10 w-10 items-center justify-center rounded-xl bg-blue-50 dark:bg-blue-900/20 text-primary"
              >
                <Users :size="20" />
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
            <ChevronRight :size="20" class="text-slate-300 group-hover:text-primary transition-colors" />
          </button>
        </div>
      </section>

      <!-- Cartera y Fiados (CHK-406: Cupo Global por Defecto) -->
      <section v-if="isAdmin">
        <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-3 px-1">💳 Cartera y Fiados</h3>
        <div class="rounded-2xl bg-white dark:bg-slate-800 p-5 shadow-sm border border-slate-100 dark:border-slate-700 space-y-3">
          <div class="flex items-start justify-between gap-3">
            <div class="flex items-center gap-3">
              <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400">
                <CreditCard :size="20" />
              </div>
              <div>
                <p class="text-base font-semibold text-slate-900 dark:text-slate-100">
                  Cupo de Crédito Global por Defecto
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400">
                  Se precarga solo al crear clientes nuevos. No altera cupos de clientes existentes.
                </p>
              </div>
            </div>
          </div>

          <div v-if="creditLimitError" role="alert" class="p-2.5 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-xs font-medium text-red-700 dark:text-red-300">
            {{ creditLimitError }}
          </div>

          <div class="flex items-center gap-2">
            <div class="relative flex-1">
              <span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 font-bold">$</span>
              <input
                v-model.number="globalCreditLimit"
                data-testid="global-credit-limit-input"
                type="number"
                min="0"
                step="1000"
                :disabled="isLoadingCreditLimit || isSavingCreditLimit"
                class="w-full h-11 pl-7 pr-3 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-sm font-bold text-slate-900 dark:text-white focus:ring-2 focus:ring-primary outline-none"
              />
            </div>
            <button
              type="button"
              data-testid="save-global-credit-limit-btn"
              @click="saveGlobalCreditLimit"
              :disabled="isLoadingCreditLimit || isSavingCreditLimit"
              class="h-11 px-4 rounded-xl bg-primary text-white text-xs font-bold hover:bg-blue-600 active:scale-[0.98] disabled:opacity-50 transition-all cursor-pointer"
            >
              {{ isSavingCreditLimit ? 'Guardando...' : 'Guardar Cupo' }}
            </button>
          </div>
        </div>
      </section>

      <!-- Inventario -->
      <section>
        <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-3 px-1">📦 Inventario</h3>
        <div
          class="flex flex-col overflow-hidden rounded-2xl bg-white dark:bg-slate-800 shadow-sm border border-slate-100 dark:border-slate-700 divide-y divide-slate-100 dark:divide-slate-700"
        >
          <!-- Proveedores -->
          <button
            @click="navigateTo('/suppliers')"
            class="flex w-full items-center justify-between p-4 transition-colors hover:bg-slate-50 dark:hover:bg-slate-700/50 text-left group"
          >
            <div class="flex items-center gap-4">
              <div
                class="flex h-10 w-10 items-center justify-center rounded-xl bg-emerald-50 dark:bg-emerald-900/20 text-emerald-600 dark:text-emerald-400"
              >
                <Truck :size="20" />
              </div>
              <div>
                <p class="text-base font-semibold text-slate-900 dark:text-slate-100">
                  Proveedores y Cuentas por Pagar
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400">
                  Directorio, facturas pendientes y abonos
                </p>
              </div>
            </div>
            <ChevronRight :size="20" class="text-slate-300 group-hover:text-primary transition-colors" />
          </button>

          <!-- Inventariado Físico -->
          <button
            @click="navigateTo('/inventory-count')"
            class="flex w-full items-center justify-between p-4 transition-colors hover:bg-slate-50 dark:hover:bg-slate-700/50 text-left group"
          >
            <div class="flex items-center gap-4">
              <div
                class="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-50 dark:bg-amber-900/20 text-amber-600 dark:text-amber-400"
              >
                <ClipboardCheck :size="20" />
              </div>
              <div>
                <p class="text-base font-semibold text-slate-900 dark:text-slate-100">
                  Inventariado Físico
                </p>
                <p class="text-xs text-slate-500 dark:text-slate-400">
                  Conteo físico de estantería con caja cerrada
                </p>
              </div>
            </div>
            <ChevronRight :size="20" class="text-slate-300 group-hover:text-primary transition-colors" />
          </button>
        </div>
      </section>



      <div class="h-10"></div>
    </main>



    <UserProfileSidebar
      :isOpen="showProfileSidebar"
      @close="showProfileSidebar = false"
      @logout="router.push('/login')"
    />

    <BottomNav />
  </div>
</template>

<style scoped>
</style>

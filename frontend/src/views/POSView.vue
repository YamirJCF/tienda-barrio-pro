<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useCartStore } from '../stores/cart';
import { useInventoryStore } from '../stores/inventory';
import type { Product, Client } from '../types';
import { useSalesStore } from '../stores/sales';
import { useCashRegisterStore } from '../stores/cashRegister';
import { useAuthStore } from '../stores/auth';
import { useClientsStore } from '../stores/clients';
import { clientRepository } from '../data/repositories/clientRepository';
import { useNotifications } from '../composables/useNotifications';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useQuantityFormat } from '../composables/useQuantityFormat';
import { useNumpad } from '../composables/useNumpad';
import { usePOS } from '../composables/usePOS';
import { useSaleProcessor } from '../composables/useSaleProcessor';
import { useHeartbeat } from '../composables/useHeartbeat'; // Presence & Pause logic
import { logger } from '../utils/logger';
import { Decimal } from 'decimal.js';
import CheckoutModal from '../components/sales/CheckoutModal.vue';
import PersonalWithdrawalModal from '../components/sales/PersonalWithdrawalModal.vue';
import RefundModal from '../components/sales/RefundModal.vue';
import ProductSearchModal from '../components/ProductSearchModal.vue';
import WeightCalculatorModal from '../components/WeightCalculatorModal.vue';
import ForceSaleModal from '../components/ForceSaleModal.vue';
import NoPermissionOverlay from '../components/ui/NoPermissionOverlay.vue';
import BaseButton from '../components/ui/BaseButton.vue';
import SyncIndicator from '../components/common/SyncIndicator.vue';
import POSNumpad from '../components/pos/POSNumpad.vue';
import { 
  ArrowLeft, 
  PauseCircle, 
  Trash2, 
  XCircle, 
  ShoppingCart, 
  Search, 
  Banknote,
  Timer,
  Check,
  ChevronDown,
  ChevronUp,
  RotateCcw,
  AlertTriangle,
  UserMinus
} from 'lucide-vue-next';

const router = useRouter();
const route = useRoute();
const cartStore = useCartStore();
const inventoryStore = useInventoryStore();
const salesStore = useSalesStore();
const cashRegisterStore = useCashRegisterStore();
const authStore = useAuthStore();
const clientsStore = useClientsStore();
const { showSuccess, showError, showWarning } = useNotifications();
const { formatWithSign: formatCurrency } = useCurrencyFormat();
const { isPaused, setPause } = useHeartbeat();

const { formatStock, formatQuantity } = useQuantityFormat();

// ============================================
// UI STATE
// ============================================
// isProcessing handled by useSaleProcessor

// Estado operativo de la tienda (Regla 3: fallo de carga NUNCA se disfraza como inventario vacío)
const hasInventoryLoadError = computed(
  () => Boolean(inventoryStore.error) && inventoryStore.totalProducts === 0
);
const isInventoryEmpty = computed(
  () =>
    Boolean(inventoryStore.initialized) &&
    !inventoryStore.isLoading &&
    !inventoryStore.error &&
    inventoryStore.totalProducts === 0
);

const retryLoadInventory = () => {
  inventoryStore.initialize(undefined, true);
};

// Permisos del usuario
const canSell = computed(() => authStore.canSell);
const canFiar = computed(() => authStore.canFiar);
const canManageRefunds = computed(() => authStore.canManageRefunds || authStore.isAdmin);
const showRefundModal = ref(false);

// WO-005: Estado de bloqueo consolidado
const blockingState = computed(() => {
  if (!canSell.value) {
    return {
      title: 'Sin Permiso',
      message: 'No tienes permiso para realizar ventas. Contacta a tu administrador.',
      buttonText: 'Volver',
      action: goToDashboard,
    };
  }
  if (!cashRegisterStore.isOpen) {
    return {
      title: 'Caja Cerrada',
      message: 'Para realizar ventas, primero debes iniciar el turno y abrir la caja.',
      buttonText: 'Abrir Caja',
      action: () => router.push('/cash-control'),
    };
  }
  if (isInventoryEmpty.value) {
    return {
      title: 'Sin Inventario',
      message: 'Tu inventario está vacío. Agrega tus primeros productos para comenzar.',
      buttonText: 'Crear Producto',
      action: () => router.push('/inventory'),
    };
  }
  return null;
});

// State
const showCheckout = ref(false);
const showPersonalWithdrawal = ref(false);
const showSearch = ref(false);
const showWeightCalculator = ref(false);
const selectedWeighableProduct = ref<Product | null>(null);
const preselectedClient = ref<Client | null>(null);
const isKeypadCollapsed = ref(false);
const swipeStartY = ref<number | null>(null);
const didSwipeGesture = ref(false);

// C1-H4: Undo temporal al limpiar ticket
const clearedSnapshot = ref<{ items: typeof cartStore.items; forcedIds: string[] } | null>(null);
let clearUndoTimer: ReturnType<typeof setTimeout> | null = null;

const stopClearUndoTimer = () => {
  if (clearUndoTimer !== null) {
    clearTimeout(clearUndoTimer);
    clearUndoTimer = null;
  }
};

const handleClearTicket = () => {
  if (cartStore.items.length === 0) return;
  stopClearUndoTimer();
  const snapshotItems = cartStore.items.map((item) => ({ ...item }));
  const forcedIds = cartStore.forcedProducts ? Array.from(cartStore.forcedProducts) : [];
  clearedSnapshot.value = { items: snapshotItems, forcedIds };
  cartStore.clearCart();
  clearUndoTimer = setTimeout(() => {
    clearedSnapshot.value = null;
    clearUndoTimer = null;
  }, 6000);
};

const undoClearTicket = () => {
  if (!clearedSnapshot.value) return;
  stopClearUndoTimer();
  cartStore.restoreSnapshot(clearedSnapshot.value.items, clearedSnapshot.value.forcedIds);
  clearedSnapshot.value = null;
};

watch(
  () => cartStore.items.length,
  (len) => {
    if (len > 0 && clearedSnapshot.value) {
      stopClearUndoTimer();
      clearedSnapshot.value = null;
    }
  }
);

const onHandleTouchStart = (e: TouchEvent) => {
  swipeStartY.value = e.touches[0]?.clientY ?? null;
  didSwipeGesture.value = false;
};

const onHandleTouchEnd = (e: TouchEvent) => {
  if (swipeStartY.value === null) return;
  const endY = e.changedTouches[0]?.clientY ?? swipeStartY.value;
  const deltaY = endY - swipeStartY.value;
  if (deltaY > 25 && !isKeypadCollapsed.value) {
    isKeypadCollapsed.value = true;
    didSwipeGesture.value = true;
  } else if (deltaY < -25 && isKeypadCollapsed.value) {
    isKeypadCollapsed.value = false;
    didSwipeGesture.value = true;
  }
  swipeStartY.value = null;
};

const onHandlePointerDown = (e: PointerEvent) => {
  if (e.pointerType === 'touch') return;
  swipeStartY.value = e.clientY;
  didSwipeGesture.value = false;
};

const onHandlePointerUp = (e: PointerEvent) => {
  if (e.pointerType === 'touch' || swipeStartY.value === null) return;
  const deltaY = e.clientY - swipeStartY.value;
  if (deltaY > 25 && !isKeypadCollapsed.value) {
    isKeypadCollapsed.value = true;
    didSwipeGesture.value = true;
  } else if (deltaY < -25 && isKeypadCollapsed.value) {
    isKeypadCollapsed.value = false;
    didSwipeGesture.value = true;
  }
  swipeStartY.value = null;
};

const toggleKeypad = () => {
  if (didSwipeGesture.value) {
    didSwipeGesture.value = false;
    return;
  }
  isKeypadCollapsed.value = !isKeypadCollapsed.value;
};

watch(showCheckout, (isOpen) => {
  if (!isOpen) {
    preselectedClient.value = null;
  }
});

// Composable: Sale Processor (completeSale, forceSale, state)
const {
  isSuccess,
  isProcessing,
  showForceSaleModal,
  forceSaleItems,
  completeSale,
  handleForceSale,
  handleForceSaleCancel,
} = useSaleProcessor({
  getTicketLabel: () => ticketNumber.value,
  clearInput: () => clearPluInput(),
  closeCheckout: () => {
    showCheckout.value = false;
    showPersonalWithdrawal.value = false;
  },
});

// Composable: Numpad logic
const { input: pluInput, handleNumpad, clear: clearPluInput } = useNumpad({
  onReset: () => resetModes()
});

// Helper for weight calc - hoisted to be passed to usePOS
const openWeightCalculator = (product: Product) => {
  selectedWeighableProduct.value = product;
  showWeightCalculator.value = true;
};

// Composable: POS Logic
const {
  pendingQuantity,
  pendingProduct,
  isQuantityMode,
  isProductMode,
  resetModes,
  handleQuantity,
  addProductByPLU
} = usePOS({
  pluInput,
  clearPluInput,
  openWeightCalculator
});

// Wrapper to log Numpad interactions
const onNumpadClick = async (value: string) => {
  await handleNumpad(value, isQuantityMode.value || isProductMode.value);
  logger.log('[Numpad] pluInput:', pluInput.value, '| mode:', isQuantityMode.value ? 'QTY' : isProductMode.value ? 'PROD' : 'NORMAL');
};

const goToDashboard = () => {
  router.push('/');
};

// Add product from search modal
const addProductFromSearch = async (product: Product) => {
  if (product.isWeighable) {
    openWeightCalculator(product);
    resetModes();
    return;
  }
  const quantity = pendingQuantity.value;
  const result = await cartStore.addItem({ ...product, quantity });
  if (!result.success) {
    showError(result.stockError || `No se pudo agregar ${product.name}`);
  } else if (result.warning) {
    showWarning(result.warning);
  }
  resetModes();
};

// Computed
const formattedTotal = computed(() => cartStore.formattedTotal);

// Current ticket number (next sale ticket number)
const ticketNumber = computed(() => {
  return `#${salesStore.nextTicketNumber.toString().padStart(3, '0')}`;
});

// Handle weight calculator confirmation
const handleWeightCalculatorConfirm = (data: {
  product: Product;
  quantity: Decimal;
  subtotal: Decimal;
}) => {
  const result = cartStore.addWeighableItem({
    id: data.product.id,
    name: data.product.name,
    price: data.product.price,
    quantity: data.quantity,
    unit: data.product.measurementUnit,
    subtotal: data.subtotal,
  });
  if (!result.success) {
    showError(result.stockError || `Stock insuficiente para ${data.product.name}`);
  } else if (result.warning) {
    showWarning(result.warning);
  }
};

const handleCheckout = () => {
  if (cartStore.items.length === 0) return;
  showCheckout.value = true;
};

const handlePOSKeydown = (e: KeyboardEvent) => {
  if (e.key === 'F12') {
    e.preventDefault();
    handleCheckout();
  }
};

onMounted(async () => {
  window.addEventListener('keydown', handlePOSKeydown);
  
  // Ensure inventory is loaded
  inventoryStore.initialize();

  // FIX: Force sync of Cash Register status.
  const storeId = authStore.currentStore?.id || authStore.currentUser?.storeId;
  if (storeId) {
    cashRegisterStore.syncFromBackend(storeId);
  }

  // Restauración puntual de cliente si regresa desde ClientDetailView (?checkoutClientId=...), sin cargar toda la cartera
  const restoreClientId = route?.query?.checkoutClientId ? String(route.query.checkoutClientId) : '';
  if (restoreClientId) {
    let found = clientsStore.getClientById(restoreClientId) || null;
    if (!found) {
      try {
        found = await clientRepository.getById(restoreClientId);
        if (found && !clientsStore.clients.some((c) => c.id === found!.id)) {
          clientsStore.clients.push(found);
        }
      } catch (err) {
        logger.warn('[POSView] No se pudo recuperar el cliente puntual al volver:', err);
      }
    }
    if (found) {
      preselectedClient.value = found;
      if (cartStore.items.length > 0) {
        showCheckout.value = true;
      }
    }
    router.replace({ path: '/pos' });
  }
});

onUnmounted(() => {
  stopClearUndoTimer();
  window.removeEventListener('keydown', handlePOSKeydown);
});

</script>

<template>
  <div class="bg-background-light dark:bg-background-dark h-screen w-full flex flex-col overflow-hidden relative">
    <!-- WO-005: Consolidated Blocking Overlay -->
    <NoPermissionOverlay v-if="blockingState" :title="blockingState.title" :message="blockingState.message"
      :buttonText="blockingState.buttonText" @go-back="blockingState.action" />

    <!-- Pause Overlay (Heartbeat) -->
    <div 
      v-if="isPaused" 
      class="absolute inset-0 z-50 bg-slate-900/80 backdrop-blur-sm flex flex-col items-center justify-center text-white"
    >
      <div class="bg-white dark:bg-slate-800 p-8 rounded-2xl shadow-2xl max-w-sm w-full text-center">
        <div class="w-20 h-20 bg-blue-100 dark:bg-blue-900/30 rounded-full flex items-center justify-center mx-auto mb-6">
          <Timer :size="48" :stroke-width="1.5" class="text-blue-600 dark:text-blue-400" />
        </div>
        <h2 class="text-2xl font-bold text-slate-900 dark:text-white mb-2">Sesión en Pausa</h2>
        <p class="text-slate-600 dark:text-slate-300 mb-8">
          Tu actividad está detenida. El administrador verá tu estado como "En Pausa".
        </p>
        <button 
          @click="setPause(false)"
          class="w-full py-4 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-bold text-lg shadow-lg shadow-blue-600/30 transition-all active:scale-95"
        >
          REANUDAR TURNO
        </button>
      </div>
    </div>

    <!-- ZONA SUPERIOR: TICKET (Flex Grow) -->
    <section class="flex flex-col flex-1 min-h-0 relative">
      <!-- Header -->
      <div
        class="flex items-center bg-background-light dark:bg-background-dark p-4 pb-2 justify-between shrink-0 border-b border-gray-200/50"
      >
        <div class="flex items-center gap-2">
          <BaseButton 
            @click="goToDashboard" 
            variant="ghost" 
            size="icon"
            class="-ml-2"
          >
            <ArrowLeft :size="24" :stroke-width="1.5" />
          </BaseButton>
          <h2 class="text-gray-900 dark:text-white text-lg font-bold leading-tight tracking-tight">
            Ticket {{ ticketNumber }}
          </h2>
        </div>
        
        <div class="flex items-center gap-2">
          <!-- Sync Indicator -->
          <SyncIndicator />
          
          <!-- Botón de Pausa (Heartbeat) -->
          <BaseButton 
            aria-label="Pause Session"
            variant="ghost"
            size="icon"
            class="text-gray-500 hover:text-blue-500 hover:bg-blue-50 dark:hover:bg-blue-900/20"
            @click="setPause(true)"
          >
            <PauseCircle :size="24" :stroke-width="1.5" />
          </BaseButton>

          <BaseButton 
            aria-label="Clear Ticket"
            data-testid="pos-clear-ticket-btn"
            variant="ghost"
            size="icon"
            :disabled="cartStore.items.length === 0"
            class="text-gray-500 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 disabled:opacity-40"
            @click="handleClearTicket"
          >
            <Trash2 :size="24" :stroke-width="1.5" />
          </BaseButton>
        </div>
      </div>

      <!-- C1-H3 (Regla 3): Banner N3 Persistente de Error al Cargar Catálogo -->
      <div
        v-if="hasInventoryLoadError"
        role="alert"
        data-testid="pos-inventory-error-banner"
        class="mx-2.5 mt-2 p-3 rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800 flex items-center justify-between gap-3 text-rose-800 dark:text-rose-200 text-xs shrink-0"
      >
        <div class="flex items-center gap-2 min-w-0">
          <AlertTriangle :size="16" class="shrink-0 text-rose-600 dark:text-rose-400" />
          <span class="font-medium truncate">{{ inventoryStore.error }}</span>
        </div>
        <button
          type="button"
          data-testid="pos-inventory-retry-btn"
          @click="retryLoadInventory"
          class="px-3 py-1 rounded-lg bg-rose-600 hover:bg-rose-700 text-white font-bold shrink-0 cursor-pointer transition-colors"
        >
          Reintentar
        </button>
      </div>

      <!-- C1-H4: Barra compacta N2 Undo tras limpiar ticket -->
      <div
        v-if="clearedSnapshot"
        role="status"
        data-testid="pos-clear-undo-banner"
        class="mx-2.5 mt-2 px-3 py-2 rounded-xl bg-slate-900 dark:bg-slate-800 text-white border border-slate-700 flex items-center justify-between gap-3 text-xs shrink-0 shadow-sm"
      >
        <span class="font-medium">
          Ticket limpiado ({{ clearedSnapshot.items.length }} {{ clearedSnapshot.items.length === 1 ? 'ítem' : 'ítems' }}).
        </span>
        <button
          type="button"
          data-testid="pos-undo-clear-btn"
          @click="undoClearTicket"
          class="px-2.5 py-1 rounded-lg bg-emerald-500 hover:bg-emerald-600 text-slate-950 font-bold shrink-0 cursor-pointer transition-colors"
        >
          Deshacer
        </button>
      </div>

      <!-- Ticket List (Scrollable) -->
      <div class="flex-1 overflow-y-auto scrollbar-thin scrollbar-thumb-gray-200 dark:scrollbar-thumb-gray-700 bg-background-light dark:bg-background-dark px-2.5 py-2">
        <!-- Cart Items -->
        <div v-for="item in cartStore.items" :key="item.id"
          data-testid="pos-cart-item"
          class="flex items-center gap-2 bg-white dark:bg-gray-800 px-2.5 py-1.5 rounded-lg mb-1.5 shadow-sm border border-gray-100 dark:border-gray-700 animate-fade-in cursor-pointer"
          @click="isKeypadCollapsed = true">
          <div class="flex items-center justify-center bg-gray-100 dark:bg-gray-700 rounded h-6 min-w-6 px-1.5 shrink-0">
            <span class="text-[11px] font-bold text-gray-600 dark:text-gray-300">x{{ formatStock(item.quantity, item.measurementUnit) }}</span>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-gray-900 dark:text-white text-xs font-semibold leading-tight truncate">
              {{ item.name }}
            </p>
            <p class="text-gray-500 dark:text-gray-400 text-[11px] leading-tight">
              {{ formatCurrency(item.price) }} {{ item.measurementUnit }}.
            </p>
          </div>
          <div class="flex items-center gap-1.5 shrink-0">
            <p class="text-gray-900 dark:text-white font-bold font-mono text-sm tabular-nums">
              {{ formatCurrency(cartStore.getLineSubtotal(item)) }}
            </p>
            <button aria-label="Remove item"
              class="text-gray-400 hover:text-red-500 p-1 -mr-1 rounded-full active:bg-gray-100 dark:active:bg-gray-700 transition-colors"
              @click.stop="cartStore.removeItem(item.id)">
              <XCircle :size="17" :stroke-width="1.5" />
            </button>
          </div>
        </div>

        <!-- Empty State -->
        <div v-if="cartStore.items.length === 0" class="flex flex-col items-center justify-center h-40 text-gray-400">
          <ShoppingCart :size="48" :stroke-width="1" class="mb-2 opacity-30" />
          <p class="text-sm">Usa el teclado para agregar productos</p>
        </div>
      </div>

      <!-- Total Summary Bar (Flow Layout - No Overlap) -->
      <div
        data-testid="pos-total-bar"
        class="shrink-0 bg-white/95 dark:bg-gray-900/95 backdrop-blur-sm border-t border-gray-200 dark:border-gray-700 px-4 py-2 shadow-[0_-4px_6px_-1px_rgba(0,0,0,0.05)] z-10 flex items-center justify-between">
        <span class="text-gray-500 dark:text-gray-400 text-xs font-bold tracking-widest uppercase">Total a Pagar</span>
        <div class="text-2xl font-black text-blue-900 dark:text-accent-green tracking-tight tabular-nums">
          {{ formattedTotal }}
        </div>
      </div>
    </section>

    <!-- ZONA INFERIOR: COMANDOS (Collapsible Keypad) -->
    <section
      class="bg-surface-light dark:bg-gray-900 shadow-[0_-5px_15px_rgba(0,0,0,0.08)] z-20 rounded-t-3xl relative pb-safe shrink-0">
      <!-- Interactive Handle / PLU Display -->
      <button
        type="button"
        data-testid="pos-keypad-handle"
        :aria-expanded="!isKeypadCollapsed"
        :aria-label="isKeypadCollapsed ? 'Mostrar teclado numérico' : 'Ocultar teclado numérico'"
        class="w-full bg-gray-100 dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 px-4 pt-1.5 pb-1.5 flex flex-col items-center rounded-t-3xl select-none cursor-pointer touch-pan-y active:bg-gray-200/70 dark:active:bg-gray-700/70 transition-colors"
        @click="toggleKeypad"
        @touchstart.passive="onHandleTouchStart"
        @touchend="onHandleTouchEnd"
        @pointerdown="onHandlePointerDown"
        @pointerup="onHandlePointerUp"
      >
        <div class="w-8 h-1 rounded-full bg-gray-300 dark:bg-gray-600 mb-1"></div>
        <div class="w-full flex items-center justify-between gap-2">
          <div class="flex items-center gap-2 min-w-0">
            <!-- Flow A Badge: Quantity mode (amber) -->
            <span v-if="isQuantityMode"
              class="inline-flex items-center px-2 py-0.5 rounded-full bg-amber-100 dark:bg-amber-900/50 text-amber-700 dark:text-amber-300 text-xs font-bold">
              {{ pendingQuantity }}×
            </span>
            <!-- Flow B Badge: Product mode (blue/green) -->
            <span v-if="isProductMode && pendingProduct"
              class="inline-flex items-center px-2 py-0.5 rounded-full bg-blue-100 dark:bg-blue-900/50 text-blue-700 dark:text-blue-300 text-xs font-bold">
              {{ pendingProduct.plu || pendingProduct.name?.slice(0, 8) }}
            </span>
            <p class="text-gray-600 dark:text-gray-300 text-xs font-mono font-medium tracking-wide">
              <span v-if="isProductMode">CANT:</span>
              <span v-else>PLU:</span>
              <span class="text-blue-600 dark:text-accent-green font-bold">{{ pluInput || '___' }}</span><span
                class="animate-pulse">|</span>
            </p>
          </div>
          <span class="inline-flex items-center text-gray-500 dark:text-gray-400 shrink-0">
            <ChevronUp v-if="isKeypadCollapsed" :size="16" />
            <ChevronDown v-else :size="16" />
          </span>
        </div>
      </button>

      <div class="px-3 pt-2 pb-3 flex flex-col gap-1.5">
        <div v-show="!isKeypadCollapsed" data-testid="pos-keypad-panel" class="flex flex-col gap-1.5">
          <!-- Extra Toolbar: Buscar + Retiro $0 + Reembolsos (CHK-509 / UX-ADR-007) -->
          <div class="flex gap-1.5">
            <BaseButton
              variant="secondary"
              class="h-9 text-sm font-medium border border-gray-200 dark:border-gray-700 active:scale-95 flex-1"
              @click="showSearch = true"
            >
              <div class="flex items-center gap-2">
                <Search :size="16" :stroke-width="1.5" />
                Buscar
              </div>
            </BaseButton>
            <BaseButton
              data-testid="pos-personal-withdrawal-btn"
              variant="secondary"
              :disabled="cartStore.items.length === 0 || isProcessing || isSuccess"
              class="h-9 px-2.5 text-xs sm:text-sm font-semibold border border-indigo-200 dark:border-indigo-800/60 text-indigo-700 dark:text-indigo-300 active:scale-95 shrink-0 disabled:opacity-45"
              @click="showPersonalWithdrawal = true"
            >
              <div class="flex items-center gap-1.5">
                <UserMinus :size="15" :stroke-width="1.75" />
                Retiro $0
              </div>
            </BaseButton>
            <BaseButton
              v-if="canManageRefunds"
              data-testid="pos-refunds-btn"
              variant="secondary"
              class="h-9 px-3 text-sm font-semibold border border-rose-200 dark:border-rose-800/60 text-rose-600 dark:text-rose-400 active:scale-95 shrink-0"
              @click="showRefundModal = true"
            >
              <div class="flex items-center gap-1.5">
                <RotateCcw :size="15" :stroke-width="1.75" />
                Reembolsos
              </div>
            </BaseButton>
          </div>

          <!-- Numpad Grid -->
          <POSNumpad 
            :is-quantity-mode="isQuantityMode"
            @click="onNumpadClick"
            @backspace="onNumpadClick('backspace')"
            @quantity="handleQuantity"
            @add="addProductByPLU"
          />
        </div>

        <!-- Master Action Button (COBRAR) -->
        <BaseButton
          class="w-full h-12 mt-1 text-lg font-black rounded-xl shadow-lg border-b-4 disabled:opacity-50 transition-all duration-300"
          :class="[
             isProcessing ? 'cursor-not-allowed scale-[0.98] brightness-95' : '',
             isSuccess ? '!bg-emerald-600 !border-emerald-700 !shadow-none scale-95' : ''
          ]"
          :variant="isSuccess ? 'success' : 'success'"
          :disabled="cartStore.items.length === 0 || isProcessing || isSuccess"
          :loading="isProcessing"
          @click="handleCheckout"
        >
             <div class="flex items-center justify-center gap-3 transition-all duration-300" :class="{ 'opacity-0 absolute': isProcessing }">
                 <template v-if="!isSuccess">
                     <Banknote :size="22" :stroke-width="1.5" />
                     COBRAR {{ formattedTotal }}
                 </template>
                 <template v-else>
                     <Check :size="26" :stroke-width="3" class="animate-bounce" />
                     <span class="tracking-widest">¡LISTO!</span>
                 </template>
             </div>
             
             <!-- Custom Loading Text override if BaseButton doesn't support slot while loading -->
             <!-- BaseButton shows loader but hides slot content when loading. We want specific text? -->
             <!-- Actually BaseButton implementation: <Loader2 v-if="loading"/> <slot />. 
                  So slot IS rendered but icon is hidden. 
                  We can put a condition in slot. -->
             <div v-if="isProcessing" class="ml-2 text-base font-bold tracking-wide animate-pulse">
                PROCESANDO...
             </div>
        </BaseButton>
      </div>
    </section>

    <!-- Modals -->
    <CheckoutModal
      v-model="showCheckout"
      :total="cartStore.total"
      :selected-client="preselectedClient"
      :initial-method="preselectedClient ? 'fiado' : undefined"
      @complete="completeSale"
    />

    <PersonalWithdrawalModal
      v-model="showPersonalWithdrawal"
      :total="cartStore.total"
      :item-count="cartStore.items.length"
      @complete="completeSale"
    />

    <ProductSearchModal v-model="showSearch" @select="addProductFromSearch" />

    <RefundModal v-model="showRefundModal" />

    <WeightCalculatorModal v-model="showWeightCalculator" :product="selectedWeighableProduct"
      @confirm="handleWeightCalculatorConfirm" />

    <!-- Force Sale Modal (FRD-014) -->
    <ForceSaleModal 
      :is-open="showForceSaleModal"
      :items="forceSaleItems"
      @confirm="handleForceSale"
      @cancel="handleForceSaleCancel"
    />
  </div>
</template>



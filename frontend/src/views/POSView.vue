<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { useCartStore } from '../stores/cart';
import { useInventoryStore } from '../stores/inventory';
import type { Product, PaymentTransaction } from '../types';
import { useSalesStore } from '../stores/sales';
import { useClientsStore } from '../stores/clients';
import { useCashRegisterStore } from '../stores/cashRegister';
import { useAuthStore } from '../stores/auth';
import { useNotificationsStore } from '../stores/notificationsStore';
import { useNotifications } from '../composables/useNotifications';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useNumpad } from '../composables/useNumpad';
import { usePOS } from '../composables/usePOS';
import { useAsyncAction } from '../composables/useAsyncAction'; // Request Management
import { useHeartbeat } from '../composables/useHeartbeat'; // Presence & Pause logic
import { logger } from '../utils/logger';
import { Decimal } from 'decimal.js';
import CheckoutModal from '../components/sales/CheckoutModal.vue';
import ProductSearchModal from '../components/ProductSearchModal.vue';
import QuickNoteModal from '../components/QuickNoteModal.vue';
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
  StickyNote, 
  Banknote,
  Timer
} from 'lucide-vue-next';

const router = useRouter();
const cartStore = useCartStore();
const inventoryStore = useInventoryStore();
const salesStore = useSalesStore();
const clientsStore = useClientsStore();
const cashRegisterStore = useCashRegisterStore();
const authStore = useAuthStore();
const { showSaleSuccess, showSaleOffline, showSuccess, showError } = useNotifications();
const { formatWithSign: formatCurrency } = useCurrencyFormat();
const { isPaused, setPause } = useHeartbeat(); // Heartbeat control

// Composable: Request Management
const { execute: executeSale, isLoading: isProcessing } = useAsyncAction();

// OBS-02: Formatear cantidad a máximo 2 decimales
const formatQuantity = (qty: number | Decimal): string => {
  const num = qty instanceof Decimal ? qty.toNumber() : Number(qty);
  return Number.isInteger(num) ? num.toString() : num.toFixed(2);
};

// ============================================
// UI STATE
// ============================================
// isProcessing handled by useAsyncAction

// Estado operativo de la tienda
// (Legacy: isAdminLocked Removed - Now relies on Offline Accountability)
// const isCashRegisterClosed = computed(() => !cashRegisterStore.isOpen); // Handled directly in blockingState
const isInventoryEmpty = computed(() => inventoryStore.totalProducts === 0);

// Permisos del usuario
const canSell = computed(() => authStore.canSell);
const canFiar = computed(() => authStore.canFiar);

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
  // isAdminLocked check REMOVED
  if (!cashRegisterStore.isOpen) {
    // Bloqueo por Caja (CashControl)
    return {
      title: 'Caja Cerrada',
      message: 'Para realizar ventas, primero debes iniciar el turno y abrir la caja.',
      buttonText: 'Abrir Caja',
      action: () => router.push('/cash-control'),
    };
  }
  if (isInventoryEmpty.value) {
    // Bloqueo por Inventario
    return {
      title: 'Sin Inventario',
      message: 'Tu inventario está vacío. Agrega tus primeros productos para comenzar.',
      buttonText: 'Crear Producto',
      action: () => router.push('/inventory'),
    };
  }
  return null;
});

// WO: initializeSampleData eliminada - SPEC-007

// State
const showCheckout = ref(false);
const showSearch = ref(false);
const showNote = ref(false);
const showWeightCalculator = ref(false);
const selectedWeighableProduct = ref<Product | null>(null);

// Force Sale State (FRD-014)
const showForceSaleModal = ref(false);
const forceSaleItems = ref<any[]>([]);
const pendingSaleData = ref<{ payments: PaymentTransaction[], totalPaid: Decimal, clientId?: string } | null>(null);

// Composable: Numpad logic
const { input: pluInput, handleNumpad, clear: clearPluInput } = useNumpad({
  onReset: () => resetModes() // Will be hoisted or we define usePOS first
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
const onNumpadClick = (value: string) => {
  handleNumpad(value, isQuantityMode.value || isProductMode.value);
  logger.log('[Numpad] pluInput:', pluInput.value, '| mode:', isQuantityMode.value ? 'QTY' : isProductMode.value ? 'PROD' : 'NORMAL');
};

const goToDashboard = () => {
  router.push('/');
};

// Add product from search modal
const addProductFromSearch = (product: Product) => {
  const quantity = pendingQuantity.value;
  cartStore.addItem({ ...product, quantity });
// inventoryStore.updateStock(product.id, -quantity); // REMOVED: Stock deduction happens at Sale Complete
  resetModes();
};

// Computed
const formattedTotal = computed(() => cartStore.formattedTotal);

// Current ticket number (next sale ticket number)
const ticketNumber = computed(() => {
  return `#${salesStore.nextTicketNumber.toString().padStart(3, '0')}`;
});

// Add note/custom item
// WO-001: Using generateUUID for custom items
import { generateUUID } from '../utils/uuid';

const addNoteItem = (item: { name: string; price: number }) => {
  const quantity = pendingQuantity.value;
  cartStore.addItem({
    id: generateUUID(), // WO-001: Use UUID
    name: item.name,
    price: new Decimal(item.price),
    quantity,
    measurementUnit: 'un',
    isWeighable: false,
  });
  resetModes();
};

// Handle weight calculator confirmation
const handleWeightCalculatorConfirm = (data: {
  product: Product;
  quantity: Decimal;
  subtotal: Decimal;
}) => {
  cartStore.addWeighableItem({
    id: data.product.id,
    name: data.product.name,
    price: data.product.price,
    quantity: data.quantity,
    unit: data.product.measurementUnit,
    subtotal: data.subtotal,
  });
// inventoryStore.updateStock(data.product.id, data.quantity.neg()); // REMOVED
};

// formatCurrency now provided by useCurrencyFormat composable

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

onMounted(() => {
  window.addEventListener('keydown', handlePOSKeydown);
  
  // Ensure inventory is loaded
  inventoryStore.initialize();

  // FIX: Force sync of Cash Register status. 
  // RLS fix allows reading, but we must fetch to see 'isOpen'.
  if (authStore.currentStore?.id) {
    cashRegisterStore.syncFromBackend(authStore.currentStore.id);
  }
});

onUnmounted(() => {
  window.removeEventListener('keydown', handlePOSKeydown);
});

// WO-001: Changed clientId from number to string

// ... (other imports remain)

// WO-001: Changed clientId from number to string
const completeSale = async (payments: PaymentTransaction[], totalPaid: Decimal, clientId?: string) => {
  const currentTicket = ticketNumber.value;
  // Determine dominant method for the sale record (simplification)
  // FIX: Audit detected that multiple chunks of same method (e.g. 2 cash bills) were treated as 'mixed'
  const uniqueMethods = new Set(payments.map(p => p.method));
  const isMixed = uniqueMethods.size > 1;
  const primaryMethod = isMixed ? 'mixed' : payments[0].method;
  
  // Calculate total cash received for change calculation (only relevant if cash is involved)
  const cashPayment = payments.find(p => p.method === 'cash');
  const amountReceived = cashPayment ? cashPayment.amount : undefined;

  const success = await executeSale(async () => {
    // ============================================
    // SAFEGUARD: Check Register Status (JIT)
    // ============================================
    if (!cashRegisterStore.isOpen) {
        throw new Error('La caja está cerrada. No se puede procesar la venta.');
    }

    // ============================================
    // SIMULATED PROCESSING DELAY
    // ============================================
    await new Promise((resolve) => setTimeout(resolve, 600));

    const saleItems = cartStore.items.map((item) => {
      const qty =
        typeof item.quantity === 'object' && 'toNumber' in item.quantity
          ? (item.quantity as Decimal).toNumber()
          : Number(item.quantity);

      return {
        productId: item.id,
        productName: item.name,
        quantity: qty,
        price: item.price,
        subtotal: item.subtotal || item.price.times(item.quantity),
      };
    });

    // Register Sale Record (Source of Truth for Inventory & Business Logic)
    await salesStore.addSale({
      items: saleItems,
      total: cartStore.total,
      roundingDifference: new Decimal(0), // Simplified for mixed
      effectiveTotal: cartStore.total,
      paymentMethod: primaryMethod, // 'mixed' or single
      payments: payments, // Pass full details
      amountReceived,
      change: undefined, // Change is visual, logic is in balances
      clientId: clientId, // Passed from CheckoutModal
      employeeId: authStore.currentUser?.employeeId || authStore.currentUser?.id // Resilient: Valid for both Employees (UUID in employeeId) and Admins (UUID in id)
    });

    const saleId = salesStore.sales[salesStore.sales.length - 1]?.id;

    // Distribute Payments to Registers / Ledgers
    for (const payment of payments) {
        if (payment.method === 'cash') {
            // ⚠️ CRITICAL: DO NOT MANUALLY ADD CASH MOVEMENT FOR SALES HERE.
            // The DB Trigger 'sync_sale_to_cash' handles the financial record.
            // This call only updates the local UI state.
            cashRegisterStore.addIncome(payment.amount, `Venta ${currentTicket} (Efectivo)`, saleId);
        } 
        // Other methods handled by backend/RPC usually, or separate stores if needed
    }

    return true; 
  }, {
    checkConnectivity: false,
    errorMessage: 'Error al procesar la venta.',
    showSuccessToast: false,
  });

  // Handle Failure: Check if Stock Error + Admin -> Force Sale Flow
  if (!success) {
    // Note: salesStore doesn't expose lastError, so we check the service error or re-try parsing
    // For now, we'll re-validate stock locally to determine if Force Sale is applicable
    let hasStockIssue = false;
    forceSaleItems.value = cartStore.items.map((item) => {
      const product = inventoryStore.getProductById(item.id);
      const requested = typeof item.quantity === 'object' ? (item.quantity as Decimal).toNumber() : Number(item.quantity);
      const available = product?.stock.toNumber() || 0;
      const deficit = Math.max(0, requested - available);
      
      if (deficit > 0) hasStockIssue = true;
      
      return {
        product_id: item.id,
        name: item.name,
        quantity: requested,
        deficit: deficit
      };
    }).filter(item => item.deficit > 0);

    // ARCH DECISION: Force Sale only allowed ONLINE
    if (authStore.isAdmin && hasStockIssue && forceSaleItems.value.length > 0 && navigator.onLine) {
      pendingSaleData.value = { payments, totalPaid, clientId };
      showForceSaleModal.value = true;
      return; // Don't clear cart yet
    }
  }

  if (success) {
    cartStore.clearCart();
    showCheckout.value = false;
    if (navigator.onLine) {
      showSaleSuccess(currentTicket);
    } else {
      showSaleOffline(currentTicket);
    }
  }
};

// Force Sale Handlers (FRD-014)
const handleForceSale = async (justification: string) => {
  if (!pendingSaleData.value) return;

  const { payments, totalPaid, clientId } = pendingSaleData.value;
  const currentTicket = ticketNumber.value;
  let saleId: string | null = null; // Capture for notification

  // Call Force Sale RPC
  const success = await executeSale(async () => {
    if (!cashRegisterStore.isOpen) {
      throw new Error('La caja está cerrada. No se puede procesar la venta.');
    }

    await new Promise((resolve) => setTimeout(resolve, 600));

    const saleItems = cartStore.items.map((item) => {
      const qty =
        typeof item.quantity === 'object' && 'toNumber' in item.quantity
          ? (item.quantity as Decimal).toNumber()
          : Number(item.quantity);

      return {
        productId: item.id,
        productName: item.name,
        quantity: qty,
        price: item.price,
        subtotal: item.subtotal || item.price.times(item.quantity),
      };
    });

    // Call the Force Sale repository method
    const result = await salesStore.forceSale({
      items: saleItems,
      total: cartStore.total,
      paymentMethod: payments.length > 1 ? 'mixed' : payments[0].method,
      clientId,
    }, authStore.currentStore!.id, justification);

    if (!result.success) {
      throw new Error(result.error || 'Force sale failed');
    }

    // Update cash register for cash payments
    const cashPayment = payments.find(p => p.method === 'cash');
    if (cashPayment) {
      cashRegisterStore.addIncome(cashPayment.amount, `Venta Forzada ${currentTicket}`, result.id);
    }
    
    saleId = result.id; // Correctly capturing ID

    return true;
  }, {
    checkConnectivity: false,
    errorMessage: 'Error al procesar la venta forzada.',
    showSuccessToast: false,
  });

  if (success) {
    cartStore.clearCart();
    showCheckout.value = false;
    showForceSaleModal.value = false;
    pendingSaleData.value = null;
    forceSaleItems.value = [];
    showSaleSuccess(currentTicket);
    
    // NOTIFICATION INTEGRATION (Level 2: Force Sale Audit)
    if (saleId) {
      const notifStore = useNotificationsStore();
      notifStore.addNotification({
        type: 'finance', // Audit event
        title: 'Venta Forzada',
        message: `Venta forzada autorizada. Justificación: ${justification}`,
        icon: 'alert-triangle',
        isRead: false,
        metadata: { saleId: saleId }
      });
    }
  }
};

const handleForceSaleCancel = () => {
  showForceSaleModal.value = false;
  pendingSaleData.value = null;
  forceSaleItems.value = [];
};
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
            variant="ghost"
            size="icon"
            class="text-gray-500 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20"
            @click="cartStore.clearCart"
          >
            <Trash2 :size="24" :stroke-width="1.5" />
          </BaseButton>
        </div>
      </div>

      <!-- Ticket List (Scrollable) -->
      <div class="flex-1 overflow-y-auto scrollbar-thin scrollbar-thumb-gray-200 dark:scrollbar-thumb-gray-700 bg-background-light dark:bg-background-dark px-2 pb-20">
        <!-- Cart Items -->
        <div v-for="item in cartStore.items" :key="item.id"
          class="flex items-center gap-3 bg-white dark:bg-gray-800 p-3 rounded-lg mb-2 shadow-sm border border-gray-100 dark:border-gray-700 animate-fade-in">
          <div class="flex items-center justify-center bg-gray-100 dark:bg-gray-700 rounded h-8 min-w-8 px-1 shrink-0">
            <!-- OBS-02: Cantidad formateada -->
            <span class="text-xs font-bold text-gray-600 dark:text-gray-300">x{{ formatQuantity(item.quantity) }}</span>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-gray-900 dark:text-white text-sm font-medium leading-tight truncate">
              {{ item.name }}
            </p>
            <p class="text-gray-500 dark:text-gray-400 text-xs">
              {{ formatCurrency(item.price) }} {{ item.measurementUnit }}.
            </p>
          </div>
          <div class="flex items-center gap-3">
            <p class="text-gray-900 dark:text-white font-bold text-base">
              {{ formatCurrency(item.price.times(item.quantity)) }}
            </p>
            <button aria-label="Remove item"
              class="text-gray-400 hover:text-red-500 p-2 -mr-2 rounded-full active:bg-gray-100 dark:active:bg-gray-700 transition-colors"
              @click="cartStore.removeItem(item.id)">
              <XCircle :size="20" :stroke-width="1.5" />
            </button>
          </div>
        </div>

        <!-- Empty State -->
        <div v-if="cartStore.items.length === 0" class="flex flex-col items-center justify-center h-40 text-gray-400">
          <ShoppingCart :size="48" :stroke-width="1" class="mb-2 opacity-30" />
          <p class="text-sm">Usa el teclado para agregar productos</p>
        </div>
      </div>

      <!-- Sticky Total Summary (Floating in Top Zone) -->
      <div
        class="absolute bottom-0 left-0 right-0 bg-white/95 dark:bg-gray-900/95 backdrop-blur-sm border-t border-gray-200 dark:border-gray-700 px-6 py-4 shadow-[0_-4px_6px_-1px_rgba(0,0,0,0.05)] z-10 flex flex-col items-end">
        <span class="text-gray-500 dark:text-gray-400 text-xs font-bold tracking-widest uppercase mb-1">Total a
          Pagar</span>
        <div class="text-4xl font-black text-blue-900 dark:text-accent-green tracking-tight">
          {{ formattedTotal }}
        </div>
      </div>
    </section>

    <!-- ZONA INFERIOR: COMANDOS (Fixed Height) -->
    <section
      class="bg-surface-light dark:bg-gray-900 shadow-[0_-5px_15px_rgba(0,0,0,0.08)] z-20 rounded-t-3xl relative pb-safe">
      <!-- PLU Display (Input Feedback) -->
      <div
        class="w-full bg-gray-100 dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 py-1.5 flex justify-center items-center rounded-t-3xl gap-3">
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
          <!-- Different label based on mode -->
          <span v-if="isProductMode">CANT:</span>
          <span v-else>PLU:</span>
          <span class="text-blue-600 dark:text-accent-green font-bold">{{ pluInput || '___' }}</span><span
            class="animate-pulse">|</span>
        </p>
      </div>

      <div class="px-3 pt-3 pb-4 flex flex-col gap-2">
        <!-- Extra Toolbar -->
        <div class="grid grid-cols-2 gap-2 mb-1">
          <BaseButton
            variant="secondary"
            class="h-10 text-sm font-medium border border-gray-200 dark:border-gray-700 active:scale-95"
            @click="showSearch = true"
          >
            <div class="flex items-center gap-2">
              <Search :size="18" :stroke-width="1.5" />
              Buscar
            </div>
          </BaseButton>
          <BaseButton
            variant="secondary"
            class="h-10 text-sm font-medium border border-gray-200 dark:border-gray-700 active:scale-95"
            @click="showNote = true"
          >
             <div class="flex items-center gap-2">
               <StickyNote :size="18" :stroke-width="1.5" />
               Nota
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

        <!-- Master Action Button (COBRAR) -->
        <BaseButton
          class="w-full h-14 mt-2 text-xl font-black rounded-xl shadow-lg border-b-4 disabled:opacity-50"
          :class="isProcessing ? 'cursor-not-allowed' : ''"
          variant="success"
          :disabled="cartStore.items.length === 0 || isProcessing"
          :loading="isProcessing"
          @click="handleCheckout"
        >
             <div class="flex items-center justify-center gap-3">
                 <Banknote :size="24" :stroke-width="1.5" />
                 COBRAR {{ formattedTotal }}
             </div>
        </BaseButton>
      </div>
    </section>

    <!-- Modals -->
    <CheckoutModal v-model="showCheckout" :total="cartStore.total" @complete="completeSale" />

    <ProductSearchModal v-model="showSearch" @select="addProductFromSearch" />

    <QuickNoteModal v-model="showNote" @add="addNoteItem" />

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



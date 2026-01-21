<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { useCartStore } from '../stores/cart';
import { useInventoryStore } from '../stores/inventory';
import type { Product } from '../types';
import { useSalesStore } from '../stores/sales';
import { useClientsStore } from '../stores/clients';
import { useCashRegisterStore } from '../stores/cashRegister';
import { useAuthStore } from '../stores/auth';
import { useNotifications } from '../composables/useNotifications';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useNumpad } from '../composables/useNumpad';
import { usePOS } from '../composables/usePOS';
import { logger } from '../utils/logger';
import { Decimal } from 'decimal.js';
import CheckoutModal from '../components/sales/CheckoutModal.vue';
import ProductSearchModal from '../components/ProductSearchModal.vue';
import QuickNoteModal from '../components/QuickNoteModal.vue';
import WeightCalculatorModal from '../components/WeightCalculatorModal.vue';
import NoPermissionOverlay from '../components/ui/NoPermissionOverlay.vue';

const router = useRouter();
const cartStore = useCartStore();
const inventoryStore = useInventoryStore();
const salesStore = useSalesStore();
const clientsStore = useClientsStore();
const cashRegisterStore = useCashRegisterStore();
const authStore = useAuthStore();
const { showSaleSuccess, showSaleOffline, showSuccess, showError } = useNotifications();
const { formatWithSign: formatCurrency } = useCurrencyFormat();

// OBS-02: Formatear cantidad a máximo 2 decimales
const formatQuantity = (qty: number | Decimal): string => {
  const num = qty instanceof Decimal ? qty.toNumber() : Number(qty);
  return Number.isInteger(num) ? num.toString() : num.toFixed(2);
};

// ============================================
// UI STATE
// ============================================
const isProcessing = ref(false); // Loading state for COBRAR button

// Estado operativo de la tienda
const isAdminLocked = computed(() => !authStore.storeOpenStatus);
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
  if (isAdminLocked.value) {
    // Bloqueo por Switch Global (AdminHub/Auth)
    return {
      title: 'Tienda Cerrada',
      message: 'La tienda está marcada como "Cerrada" en el panel de administración.',
      buttonText: 'Volver',
      action: goToDashboard,
    };
  }
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
});

onUnmounted(() => {
  window.removeEventListener('keydown', handlePOSKeydown);
});

// WO-001: Changed clientId from number to string
const completeSale = async (paymentMethod: string, amountReceived?: Decimal, clientId?: string) => {
  // Prevent double-click
  if (isProcessing.value) return;

  isProcessing.value = true;
  const currentTicket = ticketNumber.value;

  try {
    // ============================================
    // SIMULATED PROCESSING DELAY
    // Gives user visual feedback that transaction is being processed
    // Also ensures localStorage writes complete before navigation
    // ============================================
    await new Promise((resolve) => setTimeout(resolve, 600));

    const saleItems = cartStore.items.map((item) => {
      // Ensure quantity is always a number
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

    // Determine totals based on payment method (SPEC-010-REV5)
    let effectiveTotal = cartStore.total;
    let roundingDifference = new Decimal(0);

    if (paymentMethod === 'cash') {
      effectiveTotal = cartStore.totalCashPayable;
      roundingDifference = cartStore.roundingDifference;
    }

    const change = amountReceived ? amountReceived.minus(effectiveTotal) : undefined;

    await salesStore.addSale({
      items: saleItems,
      total: cartStore.total,
      roundingDifference,
      effectiveTotal,
      paymentMethod: paymentMethod as 'cash' | 'nequi' | 'fiado',
      amountReceived,
      change,
      clientId,
    });

    // Register income in cash register
    cashRegisterStore.addIncome(cartStore.total, `Venta ${currentTicket}`, salesStore.sales[salesStore.sales.length - 1]?.id);

    // If fiado, register the debt
    if (paymentMethod === 'fiado' && clientId) {
      clientsStore.addPurchaseDebt(
        clientId,
        cartStore.total,
        `Compra ${currentTicket}`,
        salesStore.sales[salesStore.sales.length - 1]?.id,
      );
    }

    // Clear cart
    cartStore.clearCart();
    showCheckout.value = false;

    // Show confirmation notification
    if (navigator.onLine) {
      showSaleSuccess(currentTicket);
    } else {
      showSaleOffline(currentTicket);
    }
  } catch (error) {
    console.error('Error processing sale:', error);
    showError('Error al procesar la venta. Intenta nuevamente.');
  } finally {
    isProcessing.value = false;
  }
};
</script>

<template>
  <div class="bg-background-light dark:bg-background-dark h-screen w-full flex flex-col overflow-hidden relative">
    <!-- WO-005: Consolidated Blocking Overlay -->
    <NoPermissionOverlay v-if="blockingState" :title="blockingState.title" :message="blockingState.message"
      :buttonText="blockingState.buttonText" @go-back="blockingState.action" />

    <!-- ZONA SUPERIOR: TICKET (Flex Grow) -->
    <section class="flex flex-col flex-1 min-h-0 relative">
      <!-- Header -->
      <div
        class="flex items-center bg-background-light dark:bg-background-dark p-4 pb-2 justify-between shrink-0 border-b border-gray-200/50">
        <div class="flex items-center gap-2">
          <button @click="goToDashboard" aria-label="Volver al Dashboard"
            class="flex items-center justify-center -ml-2 p-2 rounded-full text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors">
            <span class="material-symbols-outlined">arrow_back</span>
          </button>
          <h2 class="text-gray-900 dark:text-white text-lg font-bold leading-tight tracking-tight">
            Ticket {{ ticketNumber }}
          </h2>
        </div>
        <button aria-label="Clear Ticket"
          class="flex items-center justify-center rounded-xl size-10 text-gray-500 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
          @click="cartStore.clearCart">
          <span class="material-symbols-outlined">delete</span>
        </button>
      </div>

      <!-- Ticket List (Scrollable) -->
      <div class="flex-1 overflow-y-auto ticket-scroll bg-background-light dark:bg-background-dark px-2 pb-20">
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
              <span class="material-symbols-outlined text-xl">cancel</span>
            </button>
          </div>
        </div>

        <!-- Empty State -->
        <div v-if="cartStore.items.length === 0" class="flex flex-col items-center justify-center h-40 text-gray-400">
          <span class="material-symbols-outlined text-5xl mb-2 opacity-30">shopping_cart</span>
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
          <button
            class="flex items-center justify-center gap-2 bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-200 h-10 rounded-lg text-sm font-medium border border-gray-200 dark:border-gray-700 active:scale-95 transition-transform"
            @click="showSearch = true">
            <span class="material-symbols-outlined text-lg">search</span>
            Buscar
          </button>
          <button
            class="flex items-center justify-center gap-2 bg-gray-50 dark:bg-gray-800 hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-200 h-10 rounded-lg text-sm font-medium border border-gray-200 dark:border-gray-700 active:scale-95 transition-transform"
            @click="showNote = true">
            <span class="material-symbols-outlined text-lg">edit_note</span>
            Nota
          </button>
        </div>

        <!-- Numpad Grid -->
        <div class="grid grid-cols-4 gap-2 h-auto">
          <!-- Row 1 -->
          <button v-for="num in [7, 8, 9]" :key="num"
            class="h-14 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-lg text-2xl font-medium text-gray-800 dark:text-white shadow-sm active:bg-gray-100 dark:active:bg-gray-700 touch-manipulation"
            @click="onNumpadClick(num.toString())">
            {{ num }}
          </button>
          <!-- CANT. × Button -->
          <button
            class="h-14 border rounded-lg flex items-center justify-center active:scale-95 touch-manipulation transition-all"
            :class="isQuantityMode
              ? 'bg-amber-500 border-amber-600 text-white'
              : 'bg-amber-50 dark:bg-amber-900/30 border-amber-200 dark:border-amber-800 text-amber-700 dark:text-amber-400'
              " @click="handleQuantity">
            <span class="text-xs font-bold uppercase block w-full text-center leading-none">
              Cant.<br /><span class="text-xl">×</span>
            </span>
          </button>

          <!-- Row 2 -->
          <button v-for="num in [4, 5, 6]" :key="num"
            class="h-14 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-lg text-2xl font-medium text-gray-800 dark:text-white shadow-sm active:bg-gray-100 dark:active:bg-gray-700 touch-manipulation"
            @click="onNumpadClick(num.toString())">
            {{ num }}
          </button>
          <button
            class="h-14 bg-red-50 dark:bg-red-900/30 border border-red-200 dark:border-red-800 rounded-lg flex items-center justify-center text-red-600 dark:text-red-400 active:bg-red-100 dark:active:bg-red-900/50 touch-manipulation"
            @click="onNumpadClick('backspace')">
            <span class="material-symbols-outlined">backspace</span>
          </button>

          <!-- Row 3 & 4 (Special Layout) -->
          <!-- Column 1-3 Wrapper -->
          <div class="col-span-3 grid grid-cols-3 gap-2">
            <button v-for="num in [1, 2, 3]" :key="num"
              class="h-14 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-lg text-2xl font-medium text-gray-800 dark:text-white shadow-sm active:bg-gray-100 dark:active:bg-gray-700 touch-manipulation"
              @click="onNumpadClick(num.toString())">
              {{ num }}
            </button>
            <button
              class="h-14 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-lg text-2xl font-medium text-gray-800 dark:text-white shadow-sm active:bg-gray-100 dark:active:bg-gray-700 touch-manipulation"
              @click="onNumpadClick('0')">
              0
            </button>
            <button
              class="h-14 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-lg text-2xl font-medium text-gray-800 dark:text-white shadow-sm active:bg-gray-100 dark:active:bg-gray-700 touch-manipulation"
              @click="onNumpadClick('00')">
              00
            </button>
            <button
              class="h-14 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded-lg text-2xl font-medium text-gray-800 dark:text-white shadow-sm active:bg-gray-100 dark:active:bg-gray-700 touch-manipulation"
              @click="onNumpadClick('.')">
              .
            </button>
          </div>

          <!-- Add Button (Row Span 2) -->
          <button
            class="col-span-1 row-span-2 bg-blue-600 dark:bg-blue-700 hover:bg-blue-700 text-white rounded-lg shadow-md active:scale-95 active:shadow-inner transition-all flex flex-col items-center justify-center gap-1 border-b-4 border-blue-800 touch-manipulation"
            @click="addProductByPLU">
            <span class="material-symbols-outlined text-3xl font-bold">add</span>
            <span class="text-[10px] font-bold uppercase tracking-wider">Agregar</span>
          </button>
        </div>

        <!-- Master Action Button (COBRAR) -->
        <button
          class="w-full h-14 bg-accent-green hover:bg-emerald-600 text-black font-black text-xl tracking-wide rounded-xl shadow-lg shadow-emerald-500/30 active:scale-[0.98] active:translate-y-0.5 transition-all mt-2 flex items-center justify-center gap-3 border-b-4 border-emerald-600 disabled:opacity-50 disabled:cursor-not-allowed touch-manipulation"
          :disabled="cartStore.items.length === 0 || isProcessing" @click="handleCheckout">
          <!-- Spinner when processing -->
          <span v-if="isProcessing" class="material-symbols-outlined text-2xl animate-spin">progress_activity</span>
          <span v-else class="material-symbols-outlined text-2xl">payments</span>
          {{ isProcessing ? 'Procesando...' : `COBRAR ${formattedTotal}` }}
        </button>
      </div>
    </section>

    <!-- Modals -->
    <CheckoutModal v-model="showCheckout" @complete="completeSale" />

    <ProductSearchModal v-model="showSearch" @select="addProductFromSearch" />

    <QuickNoteModal v-model="showNote" @add="addNoteItem" />

    <WeightCalculatorModal v-model="showWeightCalculator" :product="selectedWeighableProduct"
      @confirm="handleWeightCalculatorConfirm" />
  </div>
</template>

<style scoped>
/* Custom Scrollbar for the ticket list */
.ticket-scroll::-webkit-scrollbar {
  width: 4px;
}

.ticket-scroll::-webkit-scrollbar-track {
  background: transparent;
}

.ticket-scroll::-webkit-scrollbar-thumb {
  background-color: rgba(0, 0, 0, 0.1);
  border-radius: 4px;
}

/* animate-fade-in is now global in index.css */
</style>

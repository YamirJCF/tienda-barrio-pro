<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { useCartStore } from '../stores/cart';
import { useInventoryStore } from '../stores/inventory';
import type { Product } from '../types';
import { useSalesStore } from '../stores/sales';
import { useCashRegisterStore } from '../stores/cashRegister';
import { useAuthStore } from '../stores/auth';
import { useNotifications } from '../composables/useNotifications';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useQuantityFormat } from '../composables/useQuantityFormat';
import { useNumpad } from '../composables/useNumpad';
import { usePOS } from '../composables/usePOS';
import { useSaleProcessor } from '../composables/useSaleProcessor';
import { useHeartbeat } from '../composables/useHeartbeat'; // Presence & Pause logic
import { logger } from '../utils/logger';
import { generateUUID } from '../utils/uuid';
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
  Timer,
  Check
} from 'lucide-vue-next';

const router = useRouter();
const cartStore = useCartStore();
const inventoryStore = useInventoryStore();
const salesStore = useSalesStore();
const cashRegisterStore = useCashRegisterStore();
const authStore = useAuthStore();
const { showSuccess, showError, showWarning } = useNotifications();
const { formatWithSign: formatCurrency } = useCurrencyFormat();
const { isPaused, setPause } = useHeartbeat();

const { formatStock, formatQuantity } = useQuantityFormat();

// ============================================
// UI STATE
// ============================================
// isProcessing handled by useSaleProcessor

// Estado operativo de la tienda
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
const showSearch = ref(false);
const showNote = ref(false);
const showWeightCalculator = ref(false);
const selectedWeighableProduct = ref<Product | null>(null);

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
  closeCheckout: () => { showCheckout.value = false; },
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
  const result = cartStore.addItem({ ...product, quantity });
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

const addNoteItem = (item: { name: string; price: number }) => {
  const quantity = pendingQuantity.value;
  cartStore.addItem({
    id: generateUUID(),
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

onMounted(() => {
  window.addEventListener('keydown', handlePOSKeydown);
  
  // Ensure inventory is loaded
  inventoryStore.initialize();

  // FIX: Force sync of Cash Register status.
  if (authStore.currentStore?.id) {
    cashRegisterStore.syncFromBackend(authStore.currentStore.id);
  }
});

onUnmounted(() => {
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
            <span class="text-xs font-bold text-gray-600 dark:text-gray-300">x{{ formatStock(item.quantity, item.measurementUnit) }}</span>
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
          class="w-full h-14 mt-2 text-xl font-black rounded-xl shadow-lg border-b-4 disabled:opacity-50 transition-all duration-300"
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
                     <Banknote :size="24" :stroke-width="1.5" />
                     COBRAR {{ formattedTotal }}
                 </template>
                 <template v-else>
                     <Check :size="28" :stroke-width="3" class="animate-bounce" />
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



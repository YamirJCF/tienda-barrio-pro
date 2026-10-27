<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useInventoryStore } from '../stores/inventory';
import { useAuthStore } from '../stores/auth';
import { useInventoryFilter } from '../composables/useInventoryFilter';
import ProductFormModal from '../components/ProductFormModal.vue';
import BottomNav from '../components/BottomNav.vue';
import NoPermissionOverlay from '../components/ui/NoPermissionOverlay.vue';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useQuantityFormat } from '../composables/useQuantityFormat';
import { Decimal } from 'decimal.js';
import KardexModal from '../components/inventory/KardexModal.vue';
import BatchHistoryModal from '../components/inventory/BatchHistoryModal.vue';
import { useToast } from 'vue-toastification';
import BaseInput from '../components/ui/BaseInput.vue';
import BaseButton from '../components/ui/BaseButton.vue';
import BaseModal from '../components/ui/BaseModal.vue';
import BaseListSkeleton from '../components/ui/BaseListSkeleton.vue';
import BaseEmptyState from '../components/ui/BaseEmptyState.vue';
import { 
  ArrowLeft, 
  Search, 
  SlidersHorizontal,
  AlertCircle, 
  AlertTriangle,
  Package, 
  Plus, 
  History, 
  Trash2, 
  Archive, 
  Layers,
  RotateCcw,
  Clock,
  ArrowDownAZ,
  Tag,
  EyeOff,
  Check
} from 'lucide-vue-next';

const router = useRouter();
const inventoryStore = useInventoryStore();
const authStore = useAuthStore();
const { formatCurrency } = useCurrencyFormat();
const { formatStock } = useQuantityFormat();
const toast = useToast();

// Permisos del usuario
const canViewInventory = computed(() => authStore.canViewInventory);
const canManageInventory = computed(() => authStore.canManageInventory);

// Admin role check
const isAdmin = computed(() => authStore.isAdmin);

// State
// Composable: Inventory Filter (Gobernanza SWR Nivel 2 y Reactividad 100% en Memoria)
const {
  searchQuery,
  selectedCategory,
  onlyLowStock,
  includeInactive,
  sortBy,
  activeFiltersCount,
  resetFilters,
  categories,
  filteredProducts,
  getCategoryLabel
} = useInventoryFilter();

// Alerta de stock bajo verificada contra la regla de negocio (stock <= minStock && isActive !== false)
const realLowStockCount = computed(() => {
  return inventoryStore.products.filter(p => {
    const isAct = p.isActive !== false;
    const s = p.stock instanceof Decimal ? p.stock.toNumber() : Number(p.stock || 0);
    const m = typeof p.minStock === 'number' ? p.minStock : Number(p.minStock || 0);
    return isAct && s <= m;
  }).length;
});

// Modal de Filtros Avanzados
const showFilterModal = ref(false);

// State
const showProductModal = ref(false);
// WO-001: Changed from number to string for UUID
const editingProductId = ref<string | undefined>(undefined);
const showDeleteModal = ref(false);
const productToDelete = ref<{ id: string; name: string } | null>(null);

// T1.4: Kardex State
const showKardexModal = ref(false);
const kardexProduct = ref<{ id: string; name: string } | null>(null);

// T1.5: Batch History State
const showBatchModal = ref(false);
const batchProduct = ref<{ id: string; name: string } | null>(null);

// Tarea 3: UX Destello (Creación)
const newlyCreatedId = ref<string | null>(null);

// Lifecycle
onMounted(() => {
  inventoryStore.initialize();
});

// Methods
const goToDashboard = () => {
  router.push('/');
};

const openNewProduct = () => {
  editingProductId.value = undefined;
  showProductModal.value = true;
};

const openEditProduct = (id: string) => {
  editingProductId.value = id;
  showProductModal.value = true;
};

const openKardex = (product: { id: string; name: string }) => {
  kardexProduct.value = product;
  showKardexModal.value = true;
};

const openBatchHistory = (product: { id: string; name: string }) => {
  batchProduct.value = product;
  showBatchModal.value = true;
};

const deleteProduct = (id: string) => {
// ...
  const product = inventoryStore.products.find((p) => p.id === id);
  if (product) {
    productToDelete.value = { id, name: product.name };
    showDeleteModal.value = true;
  }
};

const confirmDelete = async () => {
  if (productToDelete.value) {
    try {
      const success = await inventoryStore.deleteProduct(productToDelete.value.id);
      if (success) {
        toast.success('Producto eliminado correctamente');
      }
    } catch (e: any) {
      toast.error(e.message || 'Error desconocido al eliminar');
    }
  }
  showDeleteModal.value = false;
  productToDelete.value = null;
};

const cancelDelete = () => {
  showDeleteModal.value = false;
  productToDelete.value = null;
};

const handleProductSaved = (product: { id: string }, action: 'create' | 'update') => {
  showProductModal.value = false;
  if (action === 'create') {
    newlyCreatedId.value = product.id;
    setTimeout(() => {
      if (newlyCreatedId.value === product.id) {
        newlyCreatedId.value = null;
      }
    }, 3000);
  }
};
</script>

<template>
  <div class="flex flex-col h-screen bg-background-light dark:bg-background-dark pb-24 relative">
    <!-- No Permission Overlay -->
    <NoPermissionOverlay v-if="!canViewInventory"
      message="No tienes permiso para ver el inventario. Contacta a tu administrador si necesitas acceso."
      @go-back="goToDashboard" />

    <!-- Header with Search and Tactile Controls (Stitch Mobile Pattern) -->
    <header
      class="sticky top-0 z-30 bg-white dark:bg-surface-dark border-b border-gray-200 dark:border-gray-800 shadow-sm">
      <div class="px-4 py-3 flex items-center gap-2.5">
        <button @click="goToDashboard" aria-label="Volver al Dashboard"
          class="flex items-center justify-center -ml-2 p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors">
          <ArrowLeft :size="24" :stroke-width="1.5" />
        </button>
        <div class="flex-1">
          <BaseInput
            v-model="searchQuery"
            placeholder="Buscar producto o PLU..."
            class="w-full"
          >
            <template #prefix>
               <Search :size="18" :stroke-width="1.5" class="text-slate-400" />
            </template>
          </BaseInput>
        </div>

        <!-- Stitch Pill Filter Button with Active Count -->
        <button 
          @click="showFilterModal = true"
          aria-label="Abrir filtros de inventario"
          class="flex items-center gap-1.5 px-3 py-2 rounded-full font-semibold text-xs transition-all shrink-0 active:scale-95"
          :class="activeFiltersCount > 0 
            ? 'bg-primary text-white shadow-md shadow-primary/25 border border-primary' 
            : 'bg-gray-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 border border-gray-200 dark:border-gray-700/60 hover:bg-gray-200 dark:hover:bg-slate-700'">
          <SlidersHorizontal :size="15" :stroke-width="2" />
          <span>Filtros</span>
          <span 
            v-if="activeFiltersCount > 0" 
            class="w-4.5 h-4.5 rounded-full bg-white text-primary text-[10px] font-extrabold flex items-center justify-center">
            {{ activeFiltersCount }}
          </span>
        </button>
      </div>

      <!-- Clean Category Carousel (Horizontal Scroll) -->
      <div class="flex gap-2 overflow-x-auto px-4 pb-3 [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]">
        <button 
          v-for="cat in categories" 
          :key="cat"
          @click="selectedCategory = cat"
          class="px-4 py-1.5 rounded-full text-xs font-semibold whitespace-nowrap transition-all shrink-0 active:scale-95 cursor-pointer"
          :class="selectedCategory === cat 
            ? 'bg-primary text-white shadow-sm shadow-primary/20 font-bold' 
            : 'bg-gray-100 dark:bg-slate-800/80 text-slate-600 dark:text-slate-300 border border-gray-200 dark:border-gray-700/60 hover:border-slate-400'"
        >
          {{ getCategoryLabel(cat) }}
        </button>
      </div>
    </header>

    <!-- Products List -->
    <main class="flex-1 overflow-y-auto p-4 flex flex-col gap-3 [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]">
      <div class="flex justify-between items-center px-1">
        <span class="text-xs font-bold text-slate-500 uppercase tracking-widest">
          Productos ({{ filteredProducts.length }})
        </span>

        <!-- Subtle Low Stock Indicator Pill -->
        <button 
          v-if="realLowStockCount > 0" 
          @click="onlyLowStock = !onlyLowStock"
          class="flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium transition-all cursor-pointer active:scale-95"
          :class="onlyLowStock 
            ? 'bg-amber-500 text-white font-bold shadow-sm shadow-amber-500/25' 
            : 'bg-amber-50 dark:bg-amber-950/30 text-amber-600 dark:text-amber-400 border border-amber-200 dark:border-amber-800/50 hover:bg-amber-100 dark:hover:bg-amber-900/40'"
        >
          <span class="w-1.5 h-1.5 rounded-full bg-amber-500" :class="{ 'animate-pulse': !onlyLowStock, 'bg-white': onlyLowStock }"></span>
          <span>{{ realLowStockCount }} con stock bajo</span>
        </button>
      </div>



      <!-- Loading State -->
      <BaseListSkeleton v-if="inventoryStore.isLoading" :count="6" type="card" class="px-1" />

      <!-- Empty State -->
      <BaseEmptyState
        v-else-if="filteredProducts.length === 0"
        :title="activeFiltersCount > 0 || searchQuery ? 'No se encontraron productos' : 'No hay productos aún'"
        :description="activeFiltersCount > 0 || searchQuery ? 'Intenta modificar o restablecer los filtros aplicados' : 'Agrega tu primer producto para comenzar'"
        :icon="Package"
        :action-label="activeFiltersCount > 0 || searchQuery ? 'Restablecer filtros' : 'Crear primer producto'"
        @action="activeFiltersCount > 0 || searchQuery ? resetFilters() : openNewProduct()"
      />

      <!-- Product Cards with Virtual Scrolling -->
      <RecycleScroller v-else class="flex-1" :items="filteredProducts" :item-size="140"
        key-field="id" v-slot="{ item: product }">
        <article
          class="bg-white dark:bg-surface-dark rounded-2xl px-4 py-3 shadow-soft hover:shadow-soft-md border border-gray-200 dark:border-gray-700 flex flex-col transition-all duration-200 mx-4 mb-2 h-[128px] overflow-hidden"
          :class="{
            'active:scale-[0.99] cursor-pointer': canManageInventory,
            'cursor-default': !canManageInventory,
            'highlight-new': product.id === newlyCreatedId
          }" @click="canManageInventory ? openEditProduct(product.id) : null">
          <!-- Row 1: Product Info + Price -->
          <div class="flex justify-between items-start gap-3 min-h-0">
            <div class="flex-1 min-w-0">
              <h3 class="text-slate-900 dark:text-white text-sm font-bold leading-tight truncate">
                {{ product.name }}
              </h3>
              <div class="flex items-center gap-1.5 mt-1 flex-wrap">
                <span v-if="product.brand" class="text-slate-500 text-[11px] font-medium truncate max-w-[100px]">{{
                  product.brand
                }}</span>
                <span v-if="product.brand && product.plu" class="text-slate-300 text-[10px]">|</span>
                <span v-if="product.plu" class="text-slate-400 text-[11px] font-mono tracking-tight">
                  {{ product.plu }}
                </span>
                <span v-if="product.category"
                  class="px-1.5 py-0.5 bg-gray-100 dark:bg-gray-800 text-slate-500 dark:text-slate-400 text-[9px] font-bold rounded uppercase tracking-wide">
                  {{ product.category }}
                </span>
              </div>
            </div>
            <div class="shrink-0">
              <span
                class="text-slate-900 dark:text-white font-mono font-bold text-base bg-gray-50 dark:bg-slate-700/50 px-2.5 py-1 rounded-xl border border-gray-100 dark:border-gray-600 block">
                ${{ formatCurrency(product.price) }}
              </span>
            </div>
          </div>
          <!-- Row 2: Stock + Actions (pinned to bottom) -->
          <div class="flex items-center justify-between pt-2 mt-auto border-t border-gray-100 dark:border-gray-700/50">
            <span :class="product.stock.lte
              ? product.stock.lte(product.minStock)
                ? 'text-red-500'
                : 'text-emerald-600'
              : product.stock <= product.minStock
                ? 'text-red-500'
                : 'text-emerald-600'
              " class="font-mono font-bold text-base leading-none tracking-tight flex items-baseline gap-1">
              {{ formatStock(product.stock, product.measurementUnit) }}
              <span class="text-[10px] font-sans font-medium text-slate-400 uppercase">{{
                product.measurementUnit || 'un'
              }}</span>
            </span>
            <div class="flex gap-1">
              <button
                class="text-slate-400 hover:text-indigo-600 p-1.5 rounded-lg hover:bg-indigo-50 dark:hover:bg-indigo-900/20 transition-colors"
                @click.stop="openKardex(product)"
                title="Ver historial">
                <History :size="16" :stroke-width="2" />
              </button>
              <button
                class="text-slate-400 hover:text-emerald-600 p-1.5 rounded-lg hover:bg-emerald-50 dark:hover:bg-emerald-900/20 transition-colors"
                @click.stop="openBatchHistory(product)"
                title="Ver Lotes (FIFO)">
                <Layers :size="16" :stroke-width="2" />
              </button>
              <button v-if="canManageInventory"
                class="text-slate-400 hover:text-red-500 p-1.5 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
                @click.stop="deleteProduct(product.id)">
                <Trash2 :size="16" :stroke-width="2" />
              </button>
            </div>
          </div>
        </article>
      </RecycleScroller>
    </main>

    <!-- FAB (Floating Action Buttons) -->
    <div class="fixed bottom-24 right-4 z-40 flex flex-col gap-3">
      <!-- Stock Entry FAB - Only if canManageInventory -->
      <BaseButton 
        v-if="canManageInventory"
        @click="router.push('/stock-entry')"
        variant="success"
        class="size-12 !rounded-2xl shadow-lg shadow-emerald-500/40 flex items-center justify-center p-0"
      >
        <Archive :size="24" :stroke-width="1.5" />
      </BaseButton>
      
      <!-- Add Product FAB - Only if canManageInventory -->
      <BaseButton 
        v-if="canManageInventory"
        @click="openNewProduct"
        variant="primary"
        class="size-14 !rounded-2xl shadow-lg shadow-blue-500/40 flex items-center justify-center p-0"
      >
        <Plus :size="28" :stroke-width="1.5" />
      </BaseButton>
    </div>

    <!-- Bottom Navigation -->
    <BottomNav />

    <!-- Product Form Modal -->
    <ProductFormModal v-model="showProductModal" :product-id="editingProductId" @saved="handleProductSaved" />
    
    <!-- T1.4: Kardex Modal -->
    <KardexModal 
      v-model="showKardexModal"
      :product-id="kardexProduct?.id || null"
      :product-name="kardexProduct?.name || null"
    />

    <!-- T1.5: Batch History Modal -->
    <BatchHistoryModal 
      v-model="showBatchModal"
      :product-id="batchProduct?.id || null"
      :product-name="batchProduct?.name || null"
    />

    <!-- Bottom Sheet de Filtros y Orden (Stitch Mobile Design System) -->
    <BaseModal
      v-model="showFilterModal"
      max-height="85vh"
    >
      <template #header>
        <div class="flex items-center justify-between w-full pr-1">
          <div class="flex items-center gap-2">
            <h2 class="text-base font-bold text-slate-900 dark:text-white">Filtros y Orden</h2>
            <span 
              v-if="activeFiltersCount > 0" 
              class="px-2 py-0.5 rounded-full bg-primary/10 text-primary border border-primary/20 text-[10px] font-bold">
              {{ activeFiltersCount }} activos
            </span>
          </div>
          <button 
            @click="resetFilters" 
            class="flex items-center gap-1 text-xs font-semibold text-slate-400 hover:text-primary active:scale-95 transition-all p-1"
          >
            <RotateCcw :size="13" />
            <span>Restablecer</span>
          </button>
        </div>
      </template>

      <div class="p-4 space-y-5 overflow-y-auto max-h-[calc(85vh-130px)]">
        <!-- 1. Criterio de Ordenamiento (Segmented Pills 2x2) -->
        <div class="space-y-2">
          <label class="block text-[11px] font-bold uppercase tracking-wider text-slate-400">
            Ordenar por
          </label>
          <div class="grid grid-cols-2 gap-2 p-1 bg-gray-100 dark:bg-slate-900/90 rounded-2xl border border-gray-200 dark:border-slate-800">
            <button
              type="button"
              @click="sortBy = 'created_desc'"
              class="flex items-center justify-center gap-1.5 py-2 px-3 rounded-xl text-xs transition-all cursor-pointer"
              :class="sortBy === 'created_desc'
                ? 'bg-primary text-white font-bold shadow-md shadow-primary/25'
                : 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white font-medium'"
            >
              <Clock :size="13" />
              <span>Recientes</span>
            </button>
            <button
              type="button"
              @click="sortBy = 'name_asc'"
              class="flex items-center justify-center gap-1.5 py-2 px-3 rounded-xl text-xs transition-all cursor-pointer"
              :class="sortBy === 'name_asc'
                ? 'bg-primary text-white font-bold shadow-md shadow-primary/25'
                : 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white font-medium'"
            >
              <ArrowDownAZ :size="13" />
              <span>Nombre A-Z</span>
            </button>
            <button
              type="button"
              @click="sortBy = 'stock_asc'"
              class="flex items-center justify-center gap-1.5 py-2 px-3 rounded-xl text-xs transition-all cursor-pointer"
              :class="sortBy === 'stock_asc'
                ? 'bg-primary text-white font-bold shadow-md shadow-primary/25'
                : 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white font-medium'"
            >
              <Package :size="13" />
              <span>Menor Stock</span>
            </button>
            <button
              type="button"
              @click="sortBy = 'price_asc'"
              class="flex items-center justify-center gap-1.5 py-2 px-3 rounded-xl text-xs transition-all cursor-pointer"
              :class="sortBy === 'price_asc'
                ? 'bg-primary text-white font-bold shadow-md shadow-primary/25'
                : 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white font-medium'"
            >
              <Tag :size="13" />
              <span>Menor Precio</span>
            </button>
          </div>
        </div>

        <!-- 2. Condiciones de Stock y Estado (Interactive Touch Cards con Switches) -->
        <div class="space-y-2">
          <label class="block text-[11px] font-bold uppercase tracking-wider text-slate-400">
            Condiciones de Inventario
          </label>
          <div class="space-y-2.5">
            <!-- Card 1: Stock Crítico -->
            <div 
              @click="onlyLowStock = !onlyLowStock"
              class="p-3.5 rounded-2xl bg-white dark:bg-slate-800/70 border flex items-center justify-between cursor-pointer transition-all active:scale-[0.99]"
              :class="onlyLowStock 
                ? 'border-amber-500/50 shadow-sm shadow-amber-500/10' 
                : 'border-gray-200 dark:border-slate-700/60 hover:border-gray-300 dark:hover:border-slate-600'"
            >
              <div class="flex items-center gap-3">
                <div class="w-9 h-9 rounded-xl bg-amber-500/15 text-amber-500 flex items-center justify-center shrink-0">
                  <AlertTriangle :size="18" />
                </div>
                <div>
                  <div class="flex items-center gap-2">
                    <span class="text-sm font-semibold text-slate-900 dark:text-white">Solo Stock Crítico</span>
                    <span v-if="realLowStockCount > 0" class="px-2 py-0.5 rounded-full bg-amber-500/15 text-amber-600 dark:text-amber-300 text-[10px] font-bold">
                      {{ realLowStockCount }} alertas
                    </span>
                  </div>
                  <p class="text-xs text-slate-400">Existencias menores o iguales al stock mínimo</p>
                </div>
              </div>

              <!-- Modern Touch Pill Switch -->
              <div 
                class="w-11 h-6 rounded-full p-0.5 transition-colors relative flex items-center shrink-0"
                :class="onlyLowStock ? 'bg-amber-500' : 'bg-gray-300 dark:bg-slate-700'"
              >
                <div 
                  class="w-5 h-5 rounded-full bg-white shadow-md transform transition-transform flex items-center justify-center"
                  :class="onlyLowStock ? 'translate-x-5' : 'translate-x-0'"
                >
                  <Check v-if="onlyLowStock" :size="11" class="text-amber-600 stroke-[3]" />
                </div>
              </div>
            </div>

            <!-- Card 2: Inactivos (Admin Only) -->
            <div 
              v-if="isAdmin"
              @click="includeInactive = !includeInactive"
              class="p-3.5 rounded-2xl bg-white dark:bg-slate-800/70 border flex items-center justify-between cursor-pointer transition-all active:scale-[0.99]"
              :class="includeInactive 
                ? 'border-indigo-500/50 shadow-sm shadow-indigo-500/10' 
                : 'border-gray-200 dark:border-slate-700/60 hover:border-gray-300 dark:hover:border-slate-600'"
            >
              <div class="flex items-center gap-3">
                <div class="w-9 h-9 rounded-xl bg-indigo-500/15 text-indigo-500 flex items-center justify-center shrink-0">
                  <EyeOff :size="18" />
                </div>
                <div>
                  <div class="flex items-center gap-2">
                    <span class="text-sm font-semibold text-slate-900 dark:text-white">Ver Inactivos</span>
                    <span class="px-1.5 py-0.2 rounded-full bg-indigo-500/15 text-indigo-600 dark:text-indigo-300 text-[9px] font-extrabold uppercase">
                      Admin
                    </span>
                  </div>
                  <p class="text-xs text-slate-400">Artículos dados de baja lógica en mostrador</p>
                </div>
              </div>

              <!-- Modern Touch Pill Switch -->
              <div 
                class="w-11 h-6 rounded-full p-0.5 transition-colors relative flex items-center shrink-0"
                :class="includeInactive ? 'bg-indigo-600' : 'bg-gray-300 dark:bg-slate-700'"
              >
                <div 
                  class="w-5 h-5 rounded-full bg-white shadow-md transform transition-transform flex items-center justify-center"
                  :class="includeInactive ? 'translate-x-5' : 'translate-x-0'"
                >
                  <Check v-if="includeInactive" :size="11" class="text-indigo-600 stroke-[3]" />
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 3. Categorías (Wrapping Chips) -->
        <div class="space-y-2">
          <div class="flex justify-between items-center">
            <label class="block text-[11px] font-bold uppercase tracking-wider text-slate-400">
              Categorías
            </label>
            <span v-if="selectedCategory !== 'all'" class="text-xs text-primary font-medium">1 seleccionada</span>
          </div>
          <div class="flex flex-wrap gap-2 pt-1">
            <button
              v-for="cat in categories"
              :key="cat"
              type="button"
              @click="selectedCategory = cat"
              class="px-3.5 py-2 rounded-full text-xs font-semibold transition-all flex items-center gap-1.5 active:scale-95 cursor-pointer"
              :class="selectedCategory === cat
                ? 'bg-primary text-white shadow-sm shadow-primary/20 font-bold'
                : 'bg-gray-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 border border-gray-200 dark:border-gray-700/60 hover:border-slate-400'"
            >
              <span>{{ getCategoryLabel(cat) }}</span>
              <Check v-if="selectedCategory === cat" :size="12" class="stroke-[3]" />
            </button>
          </div>
        </div>
      </div>

      <template #footer>
        <div class="p-4 pt-2 bg-surface-light dark:bg-surface-dark border-t border-gray-100 dark:border-gray-800">
          <button
            @click="showFilterModal = false"
            class="w-full py-3.5 rounded-full bg-primary hover:bg-blue-600 active:scale-[0.99] text-white font-bold text-sm shadow-lg shadow-primary/25 flex items-center justify-center gap-2 transition-all cursor-pointer"
          >
            <span>Mostrar {{ filteredProducts.length }} Productos</span>
          </button>
        </div>
      </template>
    </BaseModal>

    <!-- T-010: Modal de Confirmación de Eliminación -->
    <BaseModal
      v-model="showDeleteModal"
      title="¿Eliminar producto?"
    >
        <div class="p-6 text-center">
            <div class="flex h-14 w-14 items-center justify-center rounded-full bg-red-100 dark:bg-red-900/30 mx-auto mb-4">
               <Trash2 :size="24" :stroke-width="1.5" class="text-red-500" />
            </div>
            <p class="text-sm text-slate-600 dark:text-slate-300">
               <span class="font-semibold">{{ productToDelete?.name }}</span> será eliminado
               permanentemente.
            </p>
        </div>

        <template #footer>
            <div class="p-6 pt-0 flex gap-3">
                <BaseButton
                    @click="cancelDelete"
                    variant="secondary"
                    class="flex-1"
                >
                    Cancelar
                </BaseButton>
                <BaseButton
                    @click="confirmDelete"
                    variant="danger"
                    class="flex-1"
                >
                    Eliminar
                </BaseButton>
            </div>
        </template>
    </BaseModal>
  </div>
</template>



<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { useInventoryStore } from '../stores/inventory';
import { useAuthStore } from '../stores/auth';
import type { Product } from '../types';
import { Decimal } from 'decimal.js';
import { useNotifications } from '../composables/useNotifications';
import { logger } from '../utils/logger';
import { getMarginLoss } from '../utils/currency';
import BaseModal from './ui/BaseModal.vue';
import BaseInput from './ui/BaseInput.vue';
import BaseButton from './ui/BaseButton.vue';
import ProductBatchesTab from './inventory/ProductBatchesTab.vue';
import ProductKardexTab from './inventory/ProductKardexTab.vue';
import {
  Search,
  LayoutGrid,
  Package2,
  Scale,
  DollarSign,
  Banknote,
  AlertTriangle,
  TrendingUp,
  Save,
  Trash2,
  Layers,
  History,
  FileText,
} from 'lucide-vue-next';

export type ProductFichaTab = 'data' | 'batches' | 'kardex';

interface Props {
  modelValue: boolean;
  productId?: string;
  initialTab?: ProductFichaTab;
}

const props = withDefaults(defineProps<Props>(), {
  initialTab: 'data',
});

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  saved: [product: Product, action: 'create' | 'update'];
  deleted: [productId: string];
}>();

const inventoryStore = useInventoryStore();
const authStore = useAuthStore();
const { showSuccess, showError, showWarning } = useNotifications();

const activeTab = ref<ProductFichaTab>('data');
const isSubmitting = ref(false);
const showDeleteConfirm = ref(false);
const isDeleting = ref(false);
const deleteError = ref<string | null>(null);

// Preservar stock original para evitar pérdida de precisión
const originalStock = ref<Decimal | null>(null);
const stockWasModified = ref(false);

// Sello de Estado Base (Escudo 2 - SDD-028 §4.8)
const originalPrice = ref<number | null>(null);
const originalName = ref<string | null>(null);
const originalCost = ref<number | null>(null);

const editingProduct = computed<Product | undefined>(() =>
  props.productId ? inventoryStore.getProductById(props.productId) : undefined
);

const canManageInventory = computed(() => authStore.canManageInventory || authStore.isAdmin);

const formatQuantity = (qty: number | Decimal): string => {
  const num = qty instanceof Decimal ? qty.toNumber() : Number(qty);
  return Number.isInteger(num) ? num.toString() : num.toFixed(2);
};

const convertStock = (
  value: number,
  fromUnit: 'kg' | 'lb' | 'g',
  toUnit: 'kg' | 'lb' | 'g',
): number => {
  if (fromUnit === toUnit) return value;
  let grams: number;
  switch (fromUnit) {
    case 'kg':
      grams = value * 1000;
      break;
    case 'lb':
      grams = value * 453.592;
      break;
    case 'g':
      grams = value;
      break;
  }
  switch (toUnit) {
    case 'kg':
      return grams / 1000;
    case 'lb':
      return grams / 453.592;
    case 'g':
      return grams;
  }
};

const formData = ref({
  name: '',
  brand: '',
  category: '',
  plu: '',
  saleMode: 'unit' as 'unit' | 'weight',
  measurementUnit: 'lb' as 'kg' | 'lb' | 'g',
  cost: '',
  price: '',
  stock: '',
  minStock: '5',
});

const margin = computed(() => {
  if (!formData.value.cost || !formData.value.price) return 0;
  const cost = parseFloat(formData.value.cost);
  const price = parseFloat(formData.value.price);
  if (cost === 0) return 0;
  return ((price - cost) / cost) * 100;
});

const marginLoss = computed(() => {
  if (!formData.value.price) return 0;
  const price = parseFloat(formData.value.price);
  if (isNaN(price) || price <= 0) return 0;
  return getMarginLoss(price).toNumber();
});

const isPriceBelowCost = computed(() => {
  if (!formData.value.cost || !formData.value.price) return false;
  const cost = parseFloat(formData.value.cost);
  const price = parseFloat(formData.value.price);
  return price > 0 && cost > 0 && price < cost;
});

const isPluDuplicate = computed(() => {
  const plu = String(formData.value.plu || '').trim();
  if (!plu) return false;
  return inventoryStore.products.some((p) => p.plu === plu && p.id !== props.productId);
});

const isValid = computed(() => {
  const name = String(formData.value.name || '').trim();
  const price = formData.value.price;
  const priceNum = parseFloat(String(price));
  const plu = String(formData.value.plu || '').trim();
  const isPluValid = plu === '' || /^\d{1,10}$/.test(plu);
  const isDuplicate = isPluDuplicate.value;
  return name !== '' && isPluValid && !isDuplicate && price !== '' && price !== null && !isNaN(priceNum) && priceNum > 0;
});

const existingCategories = computed(() => {
  const cats = new Set(
    inventoryStore.products.map((p) => p.category).filter((c): c is string => Boolean(c)),
  );
  return Array.from(cats).sort();
});

const blockNonNumeric = (e: KeyboardEvent) => {
  if (
    [
      'Backspace',
      'Delete',
      'Tab',
      'Escape',
      'Enter',
      'ArrowLeft',
      'ArrowRight',
      'ArrowUp',
      'ArrowDown',
      'Home',
      'End',
    ].includes(e.key)
  ) {
    return;
  }
  if (!/^\d$/.test(e.key)) {
    e.preventDefault();
  }
};

const close = () => {
  showDeleteConfirm.value = false;
  deleteError.value = null;
  emit('update:modelValue', false);
  setTimeout(resetForm, 300);
};

const resetForm = () => {
  formData.value = {
    name: '',
    brand: '',
    category: '',
    plu: '',
    saleMode: 'unit',
    measurementUnit: 'lb',
    cost: '',
    price: '',
    stock: '',
    minStock: '5',
  };
  originalStock.value = null;
  originalPrice.value = null;
  originalName.value = null;
  originalCost.value = null;
  stockWasModified.value = false;
  activeTab.value = 'data';
};

const syncFormFromProduct = (product: Product) => {
  originalStock.value = product.stock;
  originalPrice.value = product.price.toNumber();
  originalName.value = product.name;
  originalCost.value = product.cost ? product.cost.toNumber() : null;
  stockWasModified.value = false;

  formData.value = {
    name: product.name,
    brand: product.brand || '',
    category: product.category || '',
    plu: product.plu || '',
    saleMode: product.isWeighable ? 'weight' : 'unit',
    measurementUnit:
      product.measurementUnit !== 'un'
        ? (product.measurementUnit as 'kg' | 'lb' | 'g')
        : 'lb',
    cost: product.cost ? Number(product.cost).toFixed(2) : '',
    price: product.price.toString(),
    stock: formatQuantity(product.stock),
    minStock: product.minStock.toString(),
  };
};

const save = async () => {
  if (!isValid.value) return;

  isSubmitting.value = true;
  let savedProduct: Product | undefined;

  try {
    if (props.productId) {
      const snapshot = {
        expectedOldPrice: originalPrice.value ?? new Decimal(formData.value.price).toNumber(),
        expectedName: originalName.value ?? formData.value.name.trim(),
        expectedOldCost: originalCost.value ?? (formData.value.cost ? Number(formData.value.cost) : undefined),
      };

      const updateData = {
        name: formData.value.name.trim(),
        brand: formData.value.brand.trim() || undefined,
        category: formData.value.category.trim() || undefined,
        plu: formData.value.plu.trim() || undefined,
        isWeighable: formData.value.saleMode === 'weight',
        measurementUnit:
          formData.value.saleMode === 'weight' ? formData.value.measurementUnit : ('un' as const),
        price: new Decimal(formData.value.price),
        cost: formData.value.cost ? new Decimal(formData.value.cost) : undefined,
        minStock: parseInt(formData.value.minStock) || 5,
        storeId: authStore.currentUser?.storeId || authStore.currentStore?.id || '',
      };

      savedProduct = (await inventoryStore.updateProduct(props.productId, updateData, snapshot)) || undefined;
    } else {
      const createData = {
        name: formData.value.name.trim(),
        brand: formData.value.brand.trim() || undefined,
        category: formData.value.category.trim() || undefined,
        plu: formData.value.plu.trim() || undefined,
        isWeighable: formData.value.saleMode === 'weight',
        measurementUnit:
          formData.value.saleMode === 'weight' ? formData.value.measurementUnit : ('un' as const),
        price: new Decimal(formData.value.price),
        cost: formData.value.cost ? new Decimal(formData.value.cost) : undefined,
        stock: new Decimal(formData.value.stock || 0),
        minStock: parseInt(formData.value.minStock) || 5,
        storeId: authStore.currentUser?.storeId || authStore.currentStore?.id || '',
      };
      savedProduct = (await inventoryStore.addProduct(createData)) || undefined;
    }

    if (savedProduct) {
      showSuccess(props.productId ? 'Cambios guardados' : 'Producto creado exitosamente');
      emit('saved', savedProduct, props.productId ? 'update' : 'create');
      close();
    } else {
      showError('Error al guardar el producto');
    }
  } catch (err: any) {
    if (err?.code === 'CONCURRENT_MUTATION_BLOCKED') {
      showError('Operación bloqueada. El producto fue modificado concurrentemente desde otro terminal.');
      close();
      inventoryStore.initialize(authStore.currentStore?.id, true);
    } else if (err?.code === 'MUTATION_COOLDOWN_ACTIVE') {
      showWarning('Operación bloqueada temporalmente por cooldown de seguridad (3 segundos). Espere un momento e intente de nuevo.');
    } else {
      showError(err?.message || 'Error al guardar el producto');
      logger.error('[ProductForm] Error saving product:', err);
    }
  } finally {
    isSubmitting.value = false;
  }
};

const openDeleteModal = () => {
  deleteError.value = null;
  showDeleteConfirm.value = true;
};

const confirmDeleteProduct = async () => {
  if (!props.productId) return;
  isDeleting.value = true;
  deleteError.value = null;
  try {
    const ok = await inventoryStore.deleteProduct(props.productId);
    if (ok) {
      const deletedId = props.productId;
      showDeleteConfirm.value = false;
      showSuccess('Producto eliminado correctamente');
      emit('deleted', deletedId);
      close();
    } else {
      deleteError.value = 'No se pudo eliminar el producto.';
    }
  } catch (e: any) {
    deleteError.value = e?.message || 'Error al eliminar el producto.';
  } finally {
    isDeleting.value = false;
  }
};

const handleStockSynced = () => {
  if (editingProduct.value) {
    formData.value.stock = formatQuantity(editingProduct.value.stock);
  }
};

const handlePriceSynced = async () => {
  const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
  if (storeId) {
    await inventoryStore.fetchProducts(storeId);
  }
  if (editingProduct.value) {
    syncFormFromProduct(editingProduct.value);
  }
};

const toggleSaleMode = (mode: 'unit' | 'weight') => {
  formData.value.saleMode = mode;
};

watch(
  [() => props.modelValue, () => props.productId, () => props.initialTab],
  ([isOpen, id, initial]) => {
    if (!isOpen) return;
    activeTab.value = id ? (initial || 'data') : 'data';
    if (id) {
      const product = inventoryStore.getProductById(id);
      if (product) {
        syncFormFromProduct(product);
      }
    } else {
      resetForm();
    }
  },
  { immediate: true },
);

watch(
  () => formData.value.stock,
  (newVal, oldVal) => {
    if (oldVal !== undefined && newVal !== oldVal) {
      stockWasModified.value = true;
    }
  },
);

watch(
  () => formData.value.measurementUnit,
  (newUnit, oldUnit) => {
    if (formData.value.saleMode !== 'weight') return;
    if (!formData.value.stock || formData.value.stock === '0') return;
    if (oldUnit === newUnit) return;

    const currentValue = parseFloat(formData.value.stock.replace(',', '.'));
    if (isNaN(currentValue)) return;

    const convertedValue = convertStock(currentValue, oldUnit, newUnit);
    formData.value.stock = formatQuantity(convertedValue);
  },
);
</script>

<template>
  <BaseModal
    :model-value="modelValue"
    @update:model-value="close"
    :title="productId ? (editingProduct?.name || 'Ficha del Producto') : 'Nuevo Producto'"
    max-height="90vh"
  >
    <div class="p-4 space-y-4">
      <!-- Barra de 3 Pestañas (solo en modo edición / Ficha Producto) -->
      <div
        v-if="productId"
        class="grid grid-cols-3 gap-1 p-1 rounded-xl bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-800"
        role="tablist"
        aria-label="Ficha de producto"
      >
        <button
          type="button"
          role="tab"
          :aria-selected="activeTab === 'data'"
          @click="activeTab = 'data'"
          data-testid="ficha-tab-data"
          class="flex items-center justify-center gap-1.5 py-2 px-2 rounded-lg text-xs font-bold transition-all cursor-pointer"
          :class="activeTab === 'data'
            ? 'bg-surface-light dark:bg-surface-dark text-primary shadow-sm border border-slate-200 dark:border-slate-700'
            : 'text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-white'"
        >
          <FileText :size="14" />
          <span>Datos</span>
        </button>

        <button
          type="button"
          role="tab"
          :aria-selected="activeTab === 'batches'"
          @click="activeTab = 'batches'"
          data-testid="ficha-tab-batches"
          class="flex items-center justify-center gap-1.5 py-2 px-2 rounded-lg text-xs font-bold transition-all cursor-pointer"
          :class="activeTab === 'batches'
            ? 'bg-surface-light dark:bg-surface-dark text-primary shadow-sm border border-slate-200 dark:border-slate-700'
            : 'text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-white'"
        >
          <Layers :size="14" />
          <span>Lotes</span>
        </button>

        <button
          type="button"
          role="tab"
          :aria-selected="activeTab === 'kardex'"
          @click="activeTab = 'kardex'"
          data-testid="ficha-tab-kardex"
          class="flex items-center justify-center gap-1.5 py-2 px-2 rounded-lg text-xs font-bold transition-all cursor-pointer"
          :class="activeTab === 'kardex'
            ? 'bg-surface-light dark:bg-surface-dark text-primary shadow-sm border border-slate-200 dark:border-slate-700'
            : 'text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-white'"
        >
          <History :size="14" />
          <span>Historial</span>
        </button>
      </div>

      <!-- TAB 1: DATOS DE CATÁLOGO (o creación directa) -->
      <div v-if="!productId || activeTab === 'data'" class="grid grid-cols-12 gap-3 pb-2">
        <div class="col-span-12">
          <BaseInput
            v-model="formData.name"
            label="Nombre del Producto"
            placeholder="Ej. Coca Cola 3L Original"
            required
          />
        </div>

        <div class="col-span-8">
          <BaseInput
            v-model="formData.brand"
            label="Marca"
            placeholder="Buscar..."
            :icon="Search"
          />
        </div>
        <div class="col-span-4">
          <BaseInput
            :model-value="formData.plu"
            @update:model-value="val => formData.plu = String(val).replace(/[^0-9]/g, '').slice(0, 10)"
            @keydown="blockNonNumeric"
            :error="isPluDuplicate ? 'Código en uso' : undefined"
            label="Cód. Rápido"
            placeholder="Auto"
            class="text-center font-medium"
            maxlength="10"
            inputmode="numeric"
          />
        </div>

        <div class="col-span-12">
          <BaseInput
            v-model="formData.category"
            label="Categoría"
            placeholder="Ej. Bebidas, Despensa, Lácteos..."
            list="categories"
            :icon="LayoutGrid"
          />
          <datalist id="categories">
            <option v-for="cat in existingCategories" :key="cat" :value="cat" />
          </datalist>
        </div>

        <div class="col-span-12 pt-1">
          <div class="bg-slate-100 dark:bg-slate-800 p-1 rounded-lg flex h-10 shadow-inner">
            <button
              type="button"
              class="flex-1 flex items-center justify-center gap-2 rounded-md text-xs font-bold transition-all"
              :class="
                formData.saleMode === 'unit'
                  ? 'bg-white dark:bg-slate-700 text-primary shadow-sm border border-slate-200 dark:border-slate-600'
                  : 'text-slate-500 dark:text-slate-400 hover:bg-slate-50 dark:hover:bg-slate-700/50'
              "
              @click="toggleSaleMode('unit')"
            >
              <Package2 :size="16" />
              Unidad
            </button>
            <button
              type="button"
              class="flex-1 flex items-center justify-center gap-2 rounded-md text-xs font-medium transition-all"
              :class="
                formData.saleMode === 'weight'
                  ? 'bg-white dark:bg-slate-700 text-primary shadow-sm border border-slate-200 dark:border-slate-600'
                  : 'text-slate-500 dark:text-slate-400 hover:bg-slate-50 dark:hover:bg-slate-700/50'
              "
              @click="toggleSaleMode('weight')"
            >
              <Scale :size="16" />
              Valor/Peso
            </button>
          </div>
        </div>

        <div v-if="formData.saleMode === 'weight'" class="col-span-12">
          <label class="block text-[10px] uppercase font-bold text-primary tracking-wider mb-1">
            Unidad de Medida
          </label>
          <div class="flex gap-2">
            <button
              type="button"
              class="flex-1 h-10 rounded-lg flex items-center justify-center gap-1 text-xs font-bold transition-all border"
              :class="formData.measurementUnit === 'kg'
                ? 'bg-primary text-white border-primary'
                : 'bg-background-light dark:bg-background-dark text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700'"
              @click="formData.measurementUnit = 'kg'"
            >
              kg
            </button>
            <button
              type="button"
              class="flex-1 h-10 rounded-lg flex items-center justify-center gap-1 text-xs font-bold transition-all border"
              :class="formData.measurementUnit === 'lb'
                ? 'bg-primary text-white border-primary'
                : 'bg-background-light dark:bg-background-dark text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700'"
              @click="formData.measurementUnit = 'lb'"
            >
              Libras
            </button>
            <button
              type="button"
              class="flex-1 h-10 rounded-lg flex items-center justify-center gap-1 text-xs font-bold transition-all border"
              :class="formData.measurementUnit === 'g'
                ? 'bg-primary text-white border-primary'
                : 'bg-background-light dark:bg-background-dark text-slate-600 dark:text-slate-300 border-slate-200 dark:border-slate-700'"
              @click="formData.measurementUnit = 'g'"
            >
              Gramos
            </button>
          </div>
          <p class="text-[10px] text-slate-500 mt-1">
            El precio y stock se manejarán en la unidad seleccionada
          </p>
        </div>

        <div v-if="canManageInventory" class="col-span-6">
          <BaseInput
            v-model="formData.cost"
            label="Costo ($)"
            placeholder="0"
            type="number"
            step="0.01"
            :icon="DollarSign"
          />
        </div>
        <div :class="canManageInventory ? 'col-span-6' : 'col-span-12'">
          <BaseInput
            v-model="formData.price"
            label="Precio Venta ($)"
            placeholder="0"
            type="number"
            step="0.01"
            required
            :icon="DollarSign"
            class="font-bold text-emerald-600"
          />
        </div>

        <div v-if="marginLoss > 0" class="col-span-12 -mt-1">
          <div class="flex items-center gap-2 p-2.5 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700/50 rounded-lg">
            <Banknote class="text-amber-600 dark:text-amber-400 shrink-0" :size="18" />
            <div class="flex flex-col">
              <span class="text-xs font-bold text-amber-800 dark:text-amber-300">
                Alerta de Eficiencia
              </span>
              <span class="text-[10px] font-medium text-amber-700 dark:text-amber-300 leading-tight">
                Perderás <b>${{ marginLoss }}</b> por unidad en ventas en efectivo debido al redondeo obligatorio.
              </span>
            </div>
          </div>
        </div>

        <div v-if="isPriceBelowCost" class="col-span-12 -mt-1">
          <div class="flex items-center gap-2 p-2.5 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700/50 rounded-lg">
            <AlertTriangle class="text-amber-600 dark:text-amber-400 shrink-0" :size="18" />
            <span class="text-xs font-medium text-amber-700 dark:text-amber-300">
              El precio de venta es menor al costo
            </span>
          </div>
        </div>

        <div class="col-span-12 flex justify-end -mt-1">
          <span
            v-if="margin > 0"
            class="text-[11px] font-mono tabular-nums font-medium text-emerald-600 dark:text-emerald-400 flex items-center gap-1"
          >
            <TrendingUp :size="12" />
            Margen estimado: {{ margin.toFixed(1) }}%
          </span>
        </div>

        <div class="col-span-12 border-t border-slate-200 dark:border-slate-800 my-1"></div>

        <div class="col-span-6">
          <BaseInput
            v-model="formData.stock"
            :label="formData.saleMode === 'weight' ? `Stock Actual (${formData.measurementUnit})` : 'Stock Actual (un)'"
            placeholder="0"
            type="number"
            step="any"
            min="0"
            :disabled="!!props.productId"
            :title="props.productId ? 'El stock de un producto existente solo puede modificarse mediante Lotes o Entradas.' : undefined"
          />
          <p v-if="props.productId" class="text-[10px] text-slate-500 mt-1">
            Solo modificable vía Lotes / Entradas
          </p>
        </div>
        <div class="col-span-6">
          <BaseInput
            v-model="formData.minStock"
            label="Stock Mínimo"
            placeholder="5"
            type="number"
            min="0"
          />
        </div>

        <!-- Acción segura de archivo/eliminación en zona secundaria (solo edición) -->
        <div
          v-if="props.productId && canManageInventory"
          class="col-span-12 mt-2 pt-3 border-t border-slate-200 dark:border-slate-800 flex items-center justify-between gap-3"
        >
          <span class="text-xs text-slate-500 dark:text-slate-400">
            Archivar producto del catálogo activo
          </span>
          <BaseButton
            type="button"
            variant="danger"
            size="sm"
            @click="openDeleteModal"
            data-testid="ficha-delete-product-btn"
          >
            <span class="flex items-center gap-1.5">
              <Trash2 :size="14" />
              Eliminar
            </span>
          </BaseButton>
        </div>
      </div>

      <!-- TAB 2: LOTES FIFO + MERMA/SALIDA POR LOTE -->
      <ProductBatchesTab
        v-else-if="productId && activeTab === 'batches' && editingProduct"
        :product="editingProduct"
        @stock-updated="handleStockSynced"
        @price-updated="handlePriceSynced"
      />

      <!-- TAB 3: HISTORIAL KARDEX -->
      <ProductKardexTab
        v-else-if="productId && activeTab === 'kardex'"
        :product-id="productId"
        @stock-updated="handleStockSynced"
      />
    </div>

    <template #footer>
      <div
        v-if="!productId || activeTab === 'data'"
        class="p-6 pt-2 flex gap-3 bg-surface-light dark:bg-surface-dark"
      >
        <BaseButton
          type="button"
          @click="close"
          variant="secondary"
          class="flex-1"
        >
          Cancelar
        </BaseButton>
        <BaseButton
          type="button"
          @click="save"
          :disabled="!isValid || isSubmitting"
          :loading="isSubmitting"
          variant="primary"
          class="flex-1"
          :icon="Save"
        >
          Guardar
        </BaseButton>
      </div>
      <div v-else class="p-6 pt-2 flex justify-end bg-surface-light dark:bg-surface-dark">
        <BaseButton type="button" variant="secondary" @click="close">
          Cerrar
        </BaseButton>
      </div>
    </template>

    <!-- Confirmación de eliminación segura (N5 BaseModal) -->
    <BaseModal v-model="showDeleteConfirm" title="¿Eliminar producto?">
      <div class="p-6 text-center space-y-3">
        <div class="flex h-14 w-14 items-center justify-center rounded-full bg-red-100 dark:bg-red-900/30 mx-auto">
          <Trash2 :size="24" :stroke-width="1.5" class="text-red-500" />
        </div>
        <p class="text-sm text-slate-600 dark:text-slate-300">
          <span class="font-semibold">{{ editingProduct?.name }}</span> será archivado del catálogo activo. Solo es posible si su stock total es cero.
        </p>
        <div
          v-if="deleteError"
          class="rounded-xl p-3 bg-red-50 dark:bg-red-950/40 border border-red-200 dark:border-red-800 text-xs text-red-700 dark:text-red-300 text-left"
        >
          {{ deleteError }}
        </div>
      </div>

      <template #footer>
        <div class="p-6 pt-0 flex gap-3">
          <BaseButton
            type="button"
            variant="secondary"
            class="flex-1"
            :disabled="isDeleting"
            @click="showDeleteConfirm = false"
          >
            Cancelar
          </BaseButton>
          <BaseButton
            type="button"
            variant="danger"
            class="flex-1"
            :disabled="isDeleting"
            :loading="isDeleting"
            @click="confirmDeleteProduct"
          >
            Confirmar Eliminación
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </BaseModal>
</template>

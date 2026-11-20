<template>
  <div class="min-h-screen flex flex-col bg-gray-900 text-gray-100 pb-24">
    <!-- Header -->
    <header class="sticky top-0 z-30 bg-gray-900/95 backdrop-blur border-b border-gray-800 px-4 py-4 flex items-center justify-between">
      <div class="flex items-center gap-3">
        <button @click="router.back()" class="p-2 hover:bg-gray-800 rounded-lg transition-colors cursor-pointer">
          <ArrowLeft class="text-gray-400" :size="22" />
        </button>
        <div>
          <h1 class="text-lg font-bold text-white">Salidas Logísticas ($0)</h1>
          <p class="text-[11px] text-gray-400">Sin movimiento de caja ni cuentas por pagar</p>
        </div>
      </div>
      <span class="px-2.5 py-1 rounded-full text-[11px] font-bold uppercase tracking-wider bg-amber-500/15 text-amber-300 border border-amber-500/30">
        No Caja
      </span>
    </header>

    <main class="flex-1 max-w-2xl w-full mx-auto p-4 space-y-5">
      <!-- 1. Selector de Tipo de Salida -->
      <section class="bg-gray-800 rounded-2xl p-4 border border-gray-700/70 space-y-3">
        <div class="flex items-center justify-between gap-2">
          <label class="text-xs font-bold uppercase tracking-wider text-gray-400">Operación Logística</label>
          <span class="text-[11px] text-gray-400">
            {{ hasFullInventoryAccess ? 'Acceso completo inventario' : 'Operativo estándar' }}
          </span>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
          <!-- Abierto a todo usuario activo -->
          <button
            type="button"
            @click="selectMode('merma')"
            class="p-3 rounded-xl border text-left transition-all cursor-pointer"
            :class="movementType === 'merma'
              ? 'bg-orange-600/20 border-orange-500 text-white shadow-sm'
              : 'bg-gray-900/70 border-gray-700 text-gray-300 hover:border-gray-500'"
          >
            <div class="flex items-center gap-2 font-bold text-sm">
              <Trash2 :size="16" class="text-orange-400" />
              Merma / Daño
            </div>
            <p class="text-[11px] text-gray-400 mt-0.5">Vencido, roto o averiado</p>
          </button>

          <button
            type="button"
            @click="selectMode('consumo_negocio')"
            class="p-3 rounded-xl border text-left transition-all cursor-pointer"
            :class="movementType === 'consumo_negocio'
              ? 'bg-sky-600/20 border-sky-500 text-white shadow-sm'
              : 'bg-gray-900/70 border-gray-700 text-gray-300 hover:border-gray-500'"
          >
            <div class="flex items-center gap-2 font-bold text-sm">
              <Coffee :size="16" class="text-sky-400" />
              Consumo del Negocio
            </div>
            <p class="text-[11px] text-gray-400 mt-0.5">Aseo, bolsas o uso interno tienda</p>
          </button>

          <!-- Restringido a canManageInventory / Admin -->
          <button
            v-if="hasFullInventoryAccess"
            type="button"
            @click="selectMode('ajuste_conteo')"
            class="p-3 rounded-xl border text-left transition-all cursor-pointer"
            :class="movementType === 'ajuste_conteo'
              ? 'bg-amber-600/20 border-amber-500 text-white shadow-sm'
              : 'bg-gray-900/70 border-gray-700 text-gray-300 hover:border-gray-500'"
          >
            <div class="flex items-center gap-2 font-bold text-sm">
              <Sliders :size="16" class="text-amber-400" />
              Ajuste por Conteo (+/-)
            </div>
            <p class="text-[11px] text-gray-400 mt-0.5">Cuadre de inventario físico</p>
          </button>

          <button
            v-if="hasFullInventoryAccess"
            type="button"
            @click="selectMode('devolucion_proveedor')"
            class="p-3 rounded-xl border text-left transition-all cursor-pointer"
            :class="movementType === 'devolucion_proveedor'
              ? 'bg-rose-600/20 border-rose-500 text-white shadow-sm'
              : 'bg-gray-900/70 border-gray-700 text-gray-300 hover:border-gray-500'"
          >
            <div class="flex items-center gap-2 font-bold text-sm">
              <Truck :size="16" class="text-rose-400" />
              Devolución a Proveedor ($0)
            </div>
            <p class="text-[11px] text-gray-400 mt-0.5">Salida física sin tocar CxP</p>
          </button>
        </div>

        <!-- Dirección solo para Ajuste Conteo -->
        <div v-if="movementType === 'ajuste_conteo' && hasFullInventoryAccess" class="pt-2 border-t border-gray-700/70">
          <label class="text-xs text-gray-400 block mb-1.5">Dirección del Conteo Físico</label>
          <div class="grid grid-cols-2 gap-2">
            <button
              type="button"
              @click="direction = 'negative'"
              class="py-2 px-3 rounded-lg text-xs font-bold border transition-all cursor-pointer"
              :class="direction === 'negative'
                ? 'bg-rose-600 text-white border-rose-500'
                : 'bg-gray-900 text-gray-300 border-gray-700'"
            >
              Faltante (- Salida FIFO)
            </button>
            <button
              type="button"
              @click="direction = 'positive'"
              class="py-2 px-3 rounded-lg text-xs font-bold border transition-all cursor-pointer"
              :class="direction === 'positive'
                ? 'bg-emerald-600 text-white border-emerald-500'
                : 'bg-gray-900 text-gray-300 border-gray-700'"
            >
              Sobrante (+ Entrada FIFO)
            </button>
          </div>
        </div>

        <!-- Proveedor opcional ($0) solo para Devolución a Proveedor -->
        <div v-if="movementType === 'devolucion_proveedor' && hasFullInventoryAccess" class="pt-2 border-t border-gray-700/70 space-y-1">
          <label class="text-xs text-gray-400 block">Proveedor destinatario (Opcional · $0 en CxP)</label>
          <select
            v-model="selectedSupplierId"
            class="w-full bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-sm text-white outline-none focus:ring-2 focus:ring-rose-500"
          >
            <option value="">-- Sin asignar --</option>
            <option v-for="s in suppliers" :key="s.id" :value="s.id">{{ s.name }}</option>
          </select>
        </div>
      </section>

      <!-- 2. Buscador de Producto (sin revelar costos) -->
      <section class="bg-gray-800 rounded-2xl p-4 border border-gray-700/70 space-y-3">
        <label class="text-xs font-bold uppercase tracking-wider text-gray-400 block">Buscar Producto</label>
        <div class="relative">
          <Search class="absolute left-3 top-2.5 text-gray-400" :size="18" />
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Nombre o PLU del producto..."
            class="w-full bg-gray-900 border border-gray-700 rounded-xl pl-10 pr-4 py-2 text-sm text-white focus:ring-2 focus:ring-primary outline-none"
          />
        </div>

        <div v-if="isSearching" class="text-xs text-gray-400 py-2">Buscando productos...</div>

        <div v-else-if="searchResults.length > 0 && !selectedProduct" class="divide-y divide-gray-700/70 bg-gray-900/90 rounded-xl border border-gray-700 max-h-56 overflow-y-auto">
          <button
            v-for="prod in searchResults"
            :key="prod.id"
            type="button"
            @click="selectProduct(prod)"
            class="w-full px-3.5 py-2.5 flex items-center justify-between text-left hover:bg-gray-800 transition-colors cursor-pointer"
          >
            <div>
              <p class="text-sm font-semibold text-white">{{ prod.name }}</p>
              <p class="text-[11px] text-gray-400">
                <span v-if="prod.plu">PLU {{ prod.plu }} · </span>
                Stock actual: <strong class="text-emerald-400">{{ prod.stock.toString() }} {{ prod.measurementUnit }}</strong>
              </p>
            </div>
            <span class="text-xs font-bold text-primary">Seleccionar</span>
          </button>
        </div>

        <!-- Producto Seleccionado -->
        <div v-if="selectedProduct" class="bg-gray-900 rounded-xl p-3.5 border border-primary/40 flex items-center justify-between gap-3">
          <div>
            <p class="text-sm font-bold text-white">{{ selectedProduct.name }}</p>
            <p class="text-xs text-gray-400">
              Existencia actual: <strong class="text-emerald-400">{{ selectedProduct.stock.toString() }} {{ selectedProduct.measurementUnit }}</strong>
            </p>
          </div>
          <button
            type="button"
            @click="clearProduct"
            class="p-1.5 text-gray-400 hover:text-white rounded-lg hover:bg-gray-800 cursor-pointer"
          >
            <X :size="16" />
          </button>
        </div>
      </section>

      <!-- 3. Cantidad y Motivo -->
      <section v-if="selectedProduct" class="bg-gray-800 rounded-2xl p-4 border border-gray-700/70 space-y-4">
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="text-xs font-bold uppercase tracking-wider text-gray-400 block mb-1">
              Cantidad ({{ selectedProduct.measurementUnit }})
            </label>
            <input
              v-model.number="quantity"
              type="number"
              min="0.01"
              :step="selectedProduct.isWeighable ? '0.01' : '1'"
              class="w-full bg-gray-900 border border-gray-700 rounded-xl px-3 py-2 text-white font-mono text-base focus:ring-2 focus:ring-primary outline-none"
            />
          </div>

          <div>
            <label class="text-xs font-bold uppercase tracking-wider text-gray-400 block mb-1">
              Motivo Obligatorio (mín. 3 car.)
            </label>
            <input
              v-model="reason"
              type="text"
              placeholder="Ej: Empaque averiado, café personal tienda..."
              class="w-full bg-gray-900 border border-gray-700 rounded-xl px-3 py-2 text-sm text-white focus:ring-2 focus:ring-primary outline-none"
            />
          </div>
        </div>

        <BaseButton
          variant="primary"
          class="w-full h-11 font-bold"
          :loading="isSubmitting"
          :disabled="!canSubmit || isSubmitting"
          @click="submitOutput"
        >
          Confirmar Registro Logístico ($0)
        </BaseButton>
      </section>
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { useInventoryStore } from '../stores/inventory';
import { useSuppliersStore } from '../stores/suppliers';
import { productRepository, type LogisticExitType } from '../data/repositories/productRepository';
import type { Product } from '../types';
import BaseButton from '../components/ui/BaseButton.vue';
import { useNotifications } from '../composables/useNotifications';
import { ArrowLeft, Trash2, Coffee, Sliders, Truck, Search, X } from 'lucide-vue-next';

const router = useRouter();
const authStore = useAuthStore();
const inventoryStore = useInventoryStore();
const suppliersStore = useSuppliersStore();
const { showSuccess, showError } = useNotifications();

const hasFullInventoryAccess = computed(() => authStore.canManageInventory || authStore.isAdmin);
const suppliers = computed(() => suppliersStore.suppliers);

const movementType = ref<LogisticExitType>('merma');
const direction = ref<'positive' | 'negative'>('negative');
const selectedSupplierId = ref('');
const searchQuery = ref('');
const searchResults = ref<Product[]>([]);
const isSearching = ref(false);
const selectedProduct = ref<Product | null>(null);
const quantity = ref<number>(1);
const reason = ref('');
const isSubmitting = ref(false);

onMounted(async () => {
  const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
  if (storeId && hasFullInventoryAccess.value) {
    await suppliersStore.fetchSuppliers(storeId);
  }
});

const selectMode = (mode: LogisticExitType) => {
  movementType.value = mode;
  if (mode !== 'ajuste_conteo') {
    direction.value = 'negative';
  }
};

watch(searchQuery, async (val) => {
  const q = val.trim();
  const storeId = authStore.currentUser?.storeId || authStore.currentStore?.id;
  if (!storeId || q.length < 2) {
    searchResults.value = [];
    return;
  }
  isSearching.value = true;
  try {
    const res = await productRepository.getPaginatedPOS({
      storeId,
      search: q,
      limit: 12,
      includeZeroStock: movementType.value === 'ajuste_conteo' && direction.value === 'positive'
    });
    searchResults.value = res.data;
  } catch (e) {
    searchResults.value = [];
  } finally {
    isSearching.value = false;
  }
});

const selectProduct = (prod: Product) => {
  selectedProduct.value = prod;
  searchResults.value = [];
  quantity.value = 1;
};

const clearProduct = () => {
  selectedProduct.value = null;
  searchQuery.value = '';
};

const canSubmit = computed(() => {
  return (
    selectedProduct.value !== null &&
    Number(quantity.value) > 0 &&
    reason.value.trim().length >= 3
  );
});

const submitOutput = async () => {
  if (!selectedProduct.value || !canSubmit.value || isSubmitting.value) return;
  isSubmitting.value = true;
  try {
    const res = await inventoryStore.registerLogisticExit({
      productId: selectedProduct.value.id,
      movementType: movementType.value,
      quantity: Number(quantity.value),
      reason: reason.value.trim(),
      direction: direction.value,
      supplierId: movementType.value === 'devolucion_proveedor' && selectedSupplierId.value
        ? selectedSupplierId.value
        : undefined
    });

    showSuccess(`Registro guardado (${res.quantity} unid.). Nuevo stock: ${res.newStock}`);
    selectedProduct.value = null;
    searchQuery.value = '';
    reason.value = '';
    quantity.value = 1;
  } catch (err: any) {
    showError(err?.message || 'Error al registrar salida logística');
  } finally {
    isSubmitting.value = false;
  }
};
</script>

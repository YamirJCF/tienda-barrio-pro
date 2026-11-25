<template>
  <div class="h-screen flex flex-col overflow-hidden bg-background-light dark:bg-background-dark text-slate-900 dark:text-white">
    <!-- Header -->
    <header class="z-30 bg-surface-light/95 dark:bg-surface-dark/95 backdrop-blur border-b border-slate-200 dark:border-slate-800 px-4 py-3.5 flex items-center justify-between gap-3 shrink-0">
      <div class="flex items-center gap-3 min-w-0">
        <button
          type="button"
          @click="router.push('/inventory')"
          aria-label="Volver al inventario"
          class="p-2 -ml-1.5 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        >
          <ArrowLeft :size="22" :stroke-width="1.5" />
        </button>
        <div class="min-w-0">
          <h1 class="text-lg font-bold leading-tight truncate">Inventariado Físico</h1>
          <p class="text-[11px] text-slate-500 dark:text-slate-400">
            Conteo de estantería · Caja cerrada · Impacto $0 en Caja
          </p>
        </div>
      </div>

      <button
        v-if="!confirmedReceipt && countedCount > 0 && canOperateCount"
        type="button"
        @click="clearDraft"
        data-testid="clear-draft-btn"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 border border-slate-200 dark:border-slate-700 shrink-0 cursor-pointer"
      >
        <Trash2 :size="14" />
        <span>Limpiar borrador</span>
      </button>
    </header>

    <!-- Main Body -->
    <main class="flex-1 overflow-y-auto p-4 pb-32">
      <div class="max-w-3xl mx-auto space-y-4">
        <!-- 1. Loading Preconditions -->
        <BaseListSkeleton v-if="isCheckingPreconditions" :count="5" type="card" />

        <!-- 2. Recibo Autoritativo tras confirmación exitosa -->
        <section
          v-else-if="confirmedReceipt"
          data-testid="inventory-count-receipt"
          class="bg-surface-light dark:bg-surface-dark rounded-2xl p-6 border border-emerald-200 dark:border-emerald-800/70 shadow-sm space-y-4 text-center"
        >
          <div class="w-14 h-14 rounded-2xl bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 flex items-center justify-center mx-auto">
            <CheckCircle2 :size="28" />
          </div>
          <div>
            <h2 class="text-lg font-bold text-slate-900 dark:text-white">Inventariado Físico Aplicado</h2>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
              Los saldos FIFO fueron conciliados en servidor con impacto $0 en Caja y CxP.
            </p>
          </div>
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 pt-2">
            <div class="p-3 rounded-xl bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-800">
              <p class="text-[10px] font-bold uppercase text-slate-400">Verificados</p>
              <p class="font-mono tabular-nums font-bold text-lg text-slate-900 dark:text-white">
                {{ confirmedReceipt.verifiedTotal }}
              </p>
            </div>
            <div class="p-3 rounded-xl bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-800">
              <p class="text-[10px] font-bold uppercase text-slate-400">Sin cambio</p>
              <p class="font-mono tabular-nums font-bold text-lg text-slate-600 dark:text-slate-300">
                {{ confirmedReceipt.unchangedCount }}
              </p>
            </div>
            <div class="p-3 rounded-xl bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-800">
              <p class="text-[10px] font-bold uppercase text-slate-400">Faltantes</p>
              <p class="font-mono tabular-nums font-bold text-lg text-rose-600 dark:text-rose-400">
                {{ confirmedReceipt.shortagesCount }}
              </p>
            </div>
            <div class="p-3 rounded-xl bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-800">
              <p class="text-[10px] font-bold uppercase text-slate-400">Sobrantes</p>
              <p class="font-mono tabular-nums font-bold text-lg text-emerald-600 dark:text-emerald-400">
                {{ confirmedReceipt.surplusesCount }}
              </p>
            </div>
          </div>
          <div class="flex flex-wrap gap-3 justify-center pt-2">
            <BaseButton type="button" variant="primary" @click="router.push('/inventory')">
              Volver al Inventario
            </BaseButton>
            <BaseButton type="button" variant="secondary" @click="startAnotherCount">
              Nuevo Conteo
            </BaseButton>
          </div>
        </section>

        <!-- 3. Error N3 Fail-Closed al verificar precondiciones -->
        <section
          v-else-if="preconditionError"
          data-testid="count-precondition-error"
          class="bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800 rounded-2xl p-5 text-center space-y-3"
        >
          <AlertCircle :size="28" class="mx-auto text-red-600 dark:text-red-400" />
          <div>
            <h2 class="text-sm font-bold text-red-700 dark:text-red-300">
              No se pudieron verificar las precondiciones de inventariado
            </h2>
            <p class="text-xs text-red-600 dark:text-red-200 mt-1">{{ preconditionError }}</p>
          </div>
          <BaseButton type="button" variant="danger" size="sm" @click="verifyPreconditions">
            Reintentar
          </BaseButton>
        </section>

        <!-- 4. Compuerta F: Offline -->
        <section
          v-else-if="isOfflineGate"
          data-testid="gate-offline"
          class="bg-surface-light dark:bg-surface-dark border border-amber-300 dark:border-amber-800 rounded-2xl p-6 text-center space-y-3"
        >
          <WifiOff :size="32" class="mx-auto text-amber-600 dark:text-amber-400" />
          <h2 class="text-base font-bold">Conexión a Internet Requerida</h2>
          <p class="text-xs text-slate-600 dark:text-slate-300 max-w-md mx-auto">
            El inventariado físico valida el estado de caja y ajusta capas FIFO directamente en el servidor. Conéctate a internet para continuar.
          </p>
          <BaseButton type="button" variant="primary" size="sm" @click="verifyPreconditions">
            Reintentar
          </BaseButton>
        </section>

        <!-- 5. Compuerta F: Cola Offline Pendiente (syncQueue > 0) -->
        <section
          v-else-if="pendingSyncCount > 0"
          data-testid="gate-pending-sync"
          class="bg-surface-light dark:bg-surface-dark border border-amber-300 dark:border-amber-800 rounded-2xl p-6 text-center space-y-3"
        >
          <RefreshCw :size="32" class="mx-auto text-amber-600 dark:text-amber-400" />
          <h2 class="text-base font-bold">Sincroniza Ventas Pendientes Primero</h2>
          <p class="text-xs text-slate-600 dark:text-slate-300 max-w-md mx-auto">
            Hay <strong class="font-mono tabular-nums">{{ pendingSyncCount }}</strong> operación(es) offline esperando sincronización. Sincronízalas antes de contar estantería para evitar descuadres de stock.
          </p>
          <div v-if="syncGateError" class="text-xs text-red-600 dark:text-red-400">
            {{ syncGateError }}
          </div>
          <div class="flex gap-2 justify-center">
            <BaseButton
              type="button"
              variant="primary"
              size="sm"
              :loading="isSyncingQueue"
              :disabled="isSyncingQueue"
              @click="handleSyncNow"
              data-testid="sync-now-btn"
            >
              Sincronizar ahora
            </BaseButton>
          </div>
        </section>

        <!-- 6. Compuerta F: Caja Abierta (CASH_REGISTER_MUST_BE_CLOSED) -->
        <section
          v-else-if="hasOpenCashSession"
          data-testid="gate-open-cash"
          class="bg-surface-light dark:bg-surface-dark border border-rose-300 dark:border-rose-800 rounded-2xl p-6 text-center space-y-3"
        >
          <Lock :size="32" class="mx-auto text-rose-600 dark:text-rose-400" />
          <h2 class="text-base font-bold">Cierra la Caja Antes de Inventariar</h2>
          <p class="text-xs text-slate-600 dark:text-slate-300 max-w-md mx-auto">
            Hay un turno de caja abierto en la tienda. El inventariado físico debe realizarse con la caja cerrada para evitar diferencias con ventas en curso.
          </p>
          <div class="flex flex-wrap gap-2 justify-center pt-1">
            <BaseButton
              type="button"
              variant="danger"
              size="sm"
              @click="router.push('/cash-control')"
              data-testid="go-close-cash-btn"
            >
              Ir a Cerrar Caja
            </BaseButton>
            <BaseButton type="button" variant="secondary" size="sm" @click="verifyPreconditions">
              Volver a verificar
            </BaseButton>
          </div>
        </section>

        <!-- 7. Superficie Operativa de Conteo Físico (Arquetipo C) -->
        <template v-else>
          <!-- Guía rápida colapsable -->
          <section class="bg-surface-light dark:bg-surface-dark border border-slate-200 dark:border-slate-800 rounded-2xl overflow-hidden">
            <button
              type="button"
              @click="toggleGuide"
              class="w-full px-4 py-3 flex items-center justify-between gap-2 text-left hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors cursor-pointer"
            >
              <span class="flex items-center gap-2 text-xs font-bold text-slate-700 dark:text-slate-200">
                <BookOpen :size="15" class="text-primary" />
                Cómo hacer inventariado con el sistema
              </span>
              <ChevronDown
                :size="16"
                class="text-slate-400 transition-transform"
                :class="{ 'rotate-180': !isGuideCollapsed }"
              />
            </button>
            <div v-if="!isGuideCollapsed" class="px-4 pb-3.5 pt-1 border-t border-slate-100 dark:border-slate-800 text-xs text-slate-600 dark:text-slate-300 space-y-1.5">
              <p><strong>1.</strong> Recorre la estantería por categoría y toca <strong>✓ Igual</strong> si el stock real coincide con el sistema.</p>
              <p><strong>2.</strong> Si encuentras más o menos unidades, escribe la cantidad exacta que ves en <strong>En estante</strong>.</p>
              <p><strong>3.</strong> Tu avance se guarda automáticamente como borrador local hasta confirmar el envío final.</p>
            </div>
          </section>

          <!-- Buscador + Filtros de Categoría y Progreso -->
          <section class="bg-surface-light dark:bg-surface-dark border border-slate-200 dark:border-slate-800 rounded-2xl p-3.5 space-y-3">
            <div class="relative">
              <BaseInput v-model="searchQuery" placeholder="Buscar por nombre o PLU...">
                <template #prefix>
                  <Search :size="16" class="text-slate-400" />
                </template>
              </BaseInput>
            </div>

            <div class="flex items-center justify-between gap-2 flex-wrap">
              <BaseDropdown
                v-model="selectedCategory"
                :options="categoryOptions"
                prefix-label="Categoría"
              />

              <div class="inline-flex p-1 bg-background-light dark:bg-background-dark rounded-full border border-slate-200 dark:border-slate-800">
                <button
                  v-for="tab in progressFilters"
                  :key="tab.value"
                  type="button"
                  @click="progressFilter = tab.value"
                  class="px-3 py-1 rounded-full text-xs font-semibold transition-all cursor-pointer"
                  :class="progressFilter === tab.value
                    ? 'bg-primary text-white shadow-sm'
                    : 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white'"
                >
                  {{ tab.label }}
                </button>
              </div>
            </div>
          </section>

          <!-- Empty filtered state -->
          <BaseEmptyState
            v-if="visibleProducts.length === 0"
            title="Sin productos para este filtro"
            description="Cambia el criterio de búsqueda o el filtro de progreso para continuar contando."
            :icon="ClipboardCheck"
          />

          <!-- Lista de productos -->
          <div v-else class="space-y-3">
            <article
              v-for="product in visibleProducts"
              :key="product.id"
              :data-testid="`count-card-${product.id}`"
              class="bg-surface-light dark:bg-surface-dark border border-slate-200 dark:border-slate-800 rounded-2xl p-4 space-y-3"
            >
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <h3 class="font-bold text-sm text-slate-900 dark:text-white truncate">{{ product.name }}</h3>
                  <div class="flex items-center gap-2 text-xs text-slate-500 dark:text-slate-400 mt-0.5 flex-wrap">
                    <span v-if="product.plu" class="font-mono tabular-nums">PLU {{ product.plu }}</span>
                    <span class="font-mono tabular-nums font-semibold text-slate-700 dark:text-slate-200">
                      {{ formatWithSign(product.price) }}
                    </span>
                    <span v-if="product.category" class="px-1.5 py-0.5 rounded bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 text-[10px] uppercase font-bold">
                      {{ product.category }}
                    </span>
                  </div>
                </div>

                <div class="text-right shrink-0">
                  <p class="text-[10px] font-bold uppercase text-slate-400">Stock sistema</p>
                  <p class="font-mono tabular-nums font-bold text-sm text-slate-900 dark:text-white">
                    {{ formatQty(getSystemStock(product)) }} {{ product.measurementUnit || 'un' }}
                  </p>
                </div>
              </div>

              <!-- Controles 1 toque + input numérico -->
              <div class="flex flex-wrap items-end gap-2.5">
                <button
                  type="button"
                  :data-testid="`btn-equal-${product.id}`"
                  @click="markEqual(product)"
                  class="h-10 px-3.5 rounded-xl text-xs font-bold border transition-all cursor-pointer shrink-0 flex items-center gap-1.5"
                  :class="isCountedEqual(product)
                    ? 'bg-emerald-600 text-white border-emerald-600 shadow-sm'
                    : 'bg-background-light dark:bg-background-dark text-slate-700 dark:text-slate-200 border-slate-200 dark:border-slate-700 hover:border-emerald-500'"
                >
                  <Check :size="14" />
                  <span>Igual</span>
                </button>

                <div class="flex-1 min-w-[140px]">
                  <label class="text-[10px] font-bold uppercase tracking-wider text-slate-500 block mb-1">
                    En estante ({{ product.measurementUnit || 'un' }})
                  </label>
                  <input
                    :data-testid="`input-counted-${product.id}`"
                    type="number"
                    min="0"
                    step="any"
                    :value="getDraftCountValue(product.id)"
                    @input="onCountInput(product.id, ($event.target as HTMLInputElement).value)"
                    placeholder="Sin contar"
                    class="w-full h-10 px-3 rounded-xl text-right font-mono tabular-nums text-sm bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 text-slate-900 dark:text-white outline-none focus:border-primary"
                  />
                </div>

                <!-- Chip visual de diferencia física -->
                <div v-if="getProductDelta(product) !== null && getProductDelta(product) !== 0" class="shrink-0">
                  <span
                    class="inline-flex items-center px-2.5 py-2 rounded-xl text-xs font-mono tabular-nums font-bold"
                    :class="(getProductDelta(product) ?? 0) < 0
                      ? 'bg-rose-100 text-rose-700 dark:bg-rose-900/30 dark:text-rose-300'
                      : 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-300'"
                  >
                    {{
                      (getProductDelta(product) ?? 0) < 0
                        ? `Faltan ${formatQty(Math.abs(getProductDelta(product) ?? 0))}`
                        : `Sobran +${formatQty(getProductDelta(product) ?? 0)}`
                    }}
                  </span>
                </div>
              </div>

              <!-- Error N1 inline si < 0 -->
              <p v-if="isNegativeCount(product.id)" class="text-xs text-red-600 dark:text-red-400">
                La cantidad en estante no puede ser negativa.
              </p>

              <!-- BatchShelfSelector solo cuando hay diferencia y 2+ lotes activos -->
              <BatchShelfSelector
                v-if="hasNonZeroDiff(product) && getProductActiveBatches(product.id).length >= 2"
                :model-value="getDraftBatchId(product.id)"
                @update:model-value="(val) => onBatchSelect(product.id, val)"
                :batches="getProductActiveBatches(product.id)"
                :unit="product.measurementUnit"
              />

              <!-- Nota N1 cuando stock=0 y hay sobrante -->
              <p
                v-if="hasNonZeroDiff(product) && (getProductDelta(product) ?? 0) > 0 && getSystemStock(product) === 0"
                class="text-xs text-amber-700 dark:text-amber-300 bg-amber-50 dark:bg-amber-950/30 px-3 py-2 rounded-xl border border-amber-200 dark:border-amber-800/50"
              >
                El sobrante creará un nuevo lote FIFO con el precio de venta actual ({{ formatWithSign(product.price) }}).
              </p>
            </article>
          </div>
        </template>
      </div>
    </main>

    <!-- Footer Fijo -->
    <footer
      v-if="canOperateCount && !confirmedReceipt"
      class="bg-surface-light/95 dark:bg-surface-dark/95 backdrop-blur border-t border-slate-200 dark:border-slate-800 p-3.5 pb-5 z-40 shrink-0"
    >
      <div class="max-w-3xl mx-auto flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div class="text-xs font-mono tabular-nums text-slate-600 dark:text-slate-300">
          <strong>{{ countedCount }}</strong> / {{ activeCatalogProducts.length }} contados ·
          <span :class="diffCount > 0 ? 'text-amber-600 dark:text-amber-400 font-bold' : ''">
            {{ diffCount }} con diferencia
          </span>
        </div>

        <BaseButton
          type="button"
          variant="primary"
          :disabled="countedCount === 0 || hasAnyNegativeCount"
          @click="openConfirmModal"
          data-testid="review-count-btn"
        >
          Revisar y Aplicar ({{ countedCount }})
        </BaseButton>
      </div>
    </footer>

    <!-- Modal Confirmación (BaseModal) -->
    <BaseModal v-model="showConfirmModal" title="Confirmar Inventariado Físico">
      <div class="p-4 space-y-4">
        <div class="grid grid-cols-3 gap-2.5 text-center">
          <div class="p-3 rounded-xl bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-800">
            <p class="text-[10px] font-bold uppercase text-slate-400">Contados</p>
            <p class="font-mono tabular-nums font-bold text-base">{{ countedCount }}</p>
          </div>
          <div class="p-3 rounded-xl bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-800">
            <p class="text-[10px] font-bold uppercase text-slate-400">Sin cambio</p>
            <p class="font-mono tabular-nums font-bold text-base text-slate-600 dark:text-slate-300">
              {{ equalCount }}
            </p>
          </div>
          <div class="p-3 rounded-xl bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-800">
            <p class="text-[10px] font-bold uppercase text-slate-400">Con ajuste</p>
            <p class="font-mono tabular-nums font-bold text-base text-amber-600 dark:text-amber-400">
              {{ diffCount }}
            </p>
          </div>
        </div>

        <div class="p-3 rounded-xl bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800/60 text-xs text-amber-800 dark:text-amber-200">
          Los ajustes por conteo impactan las capas FIFO con <strong>$0 en Caja POS y CxP</strong>. El sistema emitirá 1 sola notificación resumen para administración.
        </div>

        <div class="space-y-1">
          <label class="text-xs font-bold uppercase tracking-wider text-slate-600 dark:text-slate-300 block">
            Nota del conteo (Opcional)
          </label>
          <textarea
            v-model="countNotes"
            rows="2"
            placeholder="Ej. Conteo cierre semanal de estantería..."
            class="w-full p-2.5 rounded-xl text-sm bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 text-slate-900 dark:text-white outline-none focus:border-primary resize-none"
          />
        </div>

        <div
          v-if="submitError"
          data-testid="count-submit-error"
          class="p-3 rounded-xl bg-red-50 dark:bg-red-950/40 border border-red-200 dark:border-red-800 text-xs text-red-700 dark:text-red-300"
        >
          {{ submitError }}
        </div>
      </div>

      <template #footer>
        <div class="p-4 pt-0 flex gap-3">
          <BaseButton
            type="button"
            variant="secondary"
            class="flex-1"
            :disabled="isSubmitting"
            @click="showConfirmModal = false"
          >
            Cancelar
          </BaseButton>
          <BaseButton
            type="button"
            variant="primary"
            class="flex-1"
            :loading="isSubmitting"
            :disabled="isSubmitting"
            @click="submitPhysicalCount"
            data-testid="confirm-apply-count-btn"
          >
            Confirmar Inventariado
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import {
  ArrowLeft,
  AlertCircle,
  WifiOff,
  RefreshCw,
  Lock,
  BookOpen,
  ChevronDown,
  Search,
  ClipboardCheck,
  Check,
  CheckCircle2,
  Trash2,
} from 'lucide-vue-next';
import { useInventoryStore } from '../stores/inventory';
import { useAuthStore } from '../stores/auth';
import { useCashRegisterStore } from '../stores/cashRegister';
import type { InventoryBatch } from '../stores/batches';
import {
  productRepository,
  type PhysicalInventoryCountResult,
} from '../data/repositories/productRepository';
import { getQueueSize, processSyncQueue } from '../data/syncQueue';
import type { Product } from '../types';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import { useNotifications } from '../composables/useNotifications';
import { useAsyncAction } from '../composables/useAsyncAction';
import BaseButton from '../components/ui/BaseButton.vue';
import BaseInput from '../components/ui/BaseInput.vue';
import BaseDropdown, { type DropdownOption } from '../components/ui/BaseDropdown.vue';
import BaseListSkeleton from '../components/ui/BaseListSkeleton.vue';
import BaseEmptyState from '../components/ui/BaseEmptyState.vue';
import BaseModal from '../components/ui/BaseModal.vue';
import BatchShelfSelector from '../components/inventory/BatchShelfSelector.vue';

interface DraftEntry {
  counted: number | null;
  batchId: string | null;
}

const GUIDE_STORAGE_KEY = 'tienda-inventory-count-guide-collapsed';

const router = useRouter();
const inventoryStore = useInventoryStore();
const authStore = useAuthStore();
const cashRegisterStore = useCashRegisterStore();
const { formatWithSign } = useCurrencyFormat();
const { showSuccess } = useNotifications();
const { execute: executeSubmit, isLoading: isSubmitting } = useAsyncAction();

const isCheckingPreconditions = ref(true);
const preconditionError = ref<string | null>(null);
const isOfflineGate = ref(false);
const pendingSyncCount = ref(0);
const isSyncingQueue = ref(false);
const syncGateError = ref<string | null>(null);
const hasOpenCashSession = ref(false);

const activeBatches = ref<InventoryBatch[]>([]);
const draft = ref<Record<string, DraftEntry>>({});
const searchQuery = ref('');
const selectedCategory = ref('all');
const progressFilter = ref<'all' | 'uncounted' | 'diff'>('all');

const isGuideCollapsed = ref(localStorage.getItem(GUIDE_STORAGE_KEY) === 'true');
const showConfirmModal = ref(false);
const countNotes = ref('');
const submitError = ref<string | null>(null);
const confirmedReceipt = ref<PhysicalInventoryCountResult | null>(null);

const storeId = computed(() => authStore.currentUser?.storeId || authStore.currentStore?.id || '');

const draftStorageKey = computed(() =>
  storeId.value ? `tienda-inventory-count-draft:${storeId.value}` : ''
);

const loadDraftFromStorage = () => {
  if (!draftStorageKey.value) return;
  try {
    const raw = localStorage.getItem(draftStorageKey.value);
    if (raw) {
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed === 'object') {
        draft.value = parsed;
      }
    }
  } catch {
    draft.value = {};
  }
};

const saveDraftToStorage = () => {
  if (!draftStorageKey.value) return;
  try {
    localStorage.setItem(draftStorageKey.value, JSON.stringify(draft.value));
  } catch {
    // Ignore quota error silently only for optional local draft persistence
  }
};

const clearDraft = () => {
  draft.value = {};
  if (draftStorageKey.value) {
    localStorage.removeItem(draftStorageKey.value);
  }
};

const toggleGuide = () => {
  isGuideCollapsed.value = !isGuideCollapsed.value;
  localStorage.setItem(GUIDE_STORAGE_KEY, String(isGuideCollapsed.value));
};

const verifyPreconditions = async () => {
  isCheckingPreconditions.value = true;
  preconditionError.value = null;
  isOfflineGate.value = false;
  pendingSyncCount.value = 0;
  syncGateError.value = null;
  hasOpenCashSession.value = false;

  try {
    if (!navigator.onLine) {
      isOfflineGate.value = true;
      return;
    }

    const queueCount = await getQueueSize();
    if (queueCount > 0) {
      pendingSyncCount.value = queueCount;
      return;
    }

    if (!storeId.value) {
      preconditionError.value = 'No se detectó una tienda activa para verificar el inventario.';
      return;
    }

    const [status] = await Promise.all([
      productRepository.getStoreActiveBatchesStatus(storeId.value),
      inventoryStore.initialize(storeId.value, true),
    ]);

    activeBatches.value = status.batches;
    hasOpenCashSession.value = Boolean(status.hasOpenCashSession);

    if (!status.hasOpenCashSession && cashRegisterStore.isOpen) {
      void cashRegisterStore.syncFromBackend(storeId.value);
    }

    if (!hasOpenCashSession.value) {
      loadDraftFromStorage();
    }
  } catch (err: any) {
    preconditionError.value =
      err?.message || 'Error inesperado verificando el estado del inventario y la caja.';
  } finally {
    isCheckingPreconditions.value = false;
  }
};

onMounted(() => {
  verifyPreconditions();
});

const handleSyncNow = async () => {
  isSyncingQueue.value = true;
  syncGateError.value = null;
  try {
    await processSyncQueue();
    await verifyPreconditions();
  } catch (err: any) {
    syncGateError.value = err?.message || 'No se pudo completar la sincronización.';
  } finally {
    isSyncingQueue.value = false;
  }
};

const canOperateCount = computed(
  () =>
    !isCheckingPreconditions.value &&
    !preconditionError.value &&
    !isOfflineGate.value &&
    pendingSyncCount.value === 0 &&
    !hasOpenCashSession.value
);

const batchesByProduct = computed<Record<string, InventoryBatch[]>>(() => {
  const map: Record<string, InventoryBatch[]> = {};
  for (const b of activeBatches.value) {
    if (Number(b.quantity_remaining) <= 0) continue;
    if (!map[b.product_id]) map[b.product_id] = [];
    map[b.product_id].push(b);
  }
  return map;
});

const getProductActiveBatches = (productId: string): InventoryBatch[] =>
  batchesByProduct.value[productId] || [];

const activeCatalogProducts = computed(() =>
  inventoryStore.products.filter((p) => p.isActive !== false)
);

const categoryOptions = computed<DropdownOption[]>(() => {
  const cats = Array.from(
    new Set(activeCatalogProducts.value.map((p) => p.category).filter((c): c is string => Boolean(c)))
  ).sort();
  return [
    { value: 'all', label: 'Todas' },
    ...cats.map((c) => ({ value: c, label: c })),
  ];
});

const progressFilters = [
  { value: 'all', label: 'Todos' },
  { value: 'uncounted', label: 'Sin contar' },
  { value: 'diff', label: 'Con diferencia' },
] as const;

const getSystemStock = (product: Product): number =>
  product.stock?.toNumber?.() ?? Number(product.stock ?? 0);

const getDraftCountValue = (productId: string): string => {
  const val = draft.value[productId]?.counted;
  return val === null || val === undefined ? '' : String(val);
};

const getDraftBatchId = (productId: string): string | null =>
  draft.value[productId]?.batchId ?? null;

const getProductDelta = (product: Product): number | null => {
  const entry = draft.value[product.id];
  if (!entry || entry.counted === null || !Number.isFinite(entry.counted)) return null;
  return Number((entry.counted - getSystemStock(product)).toFixed(4));
};

const isCounted = (productId: string): boolean => {
  const entry = draft.value[productId];
  return Boolean(entry && entry.counted !== null && Number.isFinite(entry.counted));
};

const isCountedEqual = (product: Product): boolean =>
  isCounted(product.id) && getProductDelta(product) === 0;

const hasNonZeroDiff = (product: Product): boolean => {
  const delta = getProductDelta(product);
  return delta !== null && delta !== 0 && !isNegativeCount(product.id);
};

const isNegativeCount = (productId: string): boolean => {
  const entry = draft.value[productId];
  return Boolean(entry && entry.counted !== null && entry.counted < 0);
};

const markEqual = (product: Product) => {
  draft.value[product.id] = {
    counted: getSystemStock(product),
    batchId: null,
  };
  saveDraftToStorage();
};

const onCountInput = (productId: string, raw: string) => {
  const trimmed = raw.trim();
  if (trimmed === '') {
    delete draft.value[productId];
    saveDraftToStorage();
    return;
  }
  const num = Number(trimmed);
  if (!Number.isFinite(num)) return;
  const current = draft.value[productId];
  draft.value[productId] = {
    counted: num,
    batchId: current?.batchId ?? null,
  };
  saveDraftToStorage();
};

const onBatchSelect = (productId: string, batchId: string | null) => {
  const current = draft.value[productId];
  if (!current) return;
  draft.value[productId] = {
    ...current,
    batchId,
  };
  saveDraftToStorage();
};

const visibleProducts = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  return activeCatalogProducts.value.filter((p) => {
    if (selectedCategory.value !== 'all' && p.category !== selectedCategory.value) return false;
    if (q) {
      const nameMatch = p.name.toLowerCase().includes(q);
      const pluMatch = (p.plu || '').toLowerCase().includes(q);
      if (!nameMatch && !pluMatch) return false;
    }
    if (progressFilter.value === 'uncounted' && isCounted(p.id)) return false;
    if (progressFilter.value === 'diff' && !hasNonZeroDiff(p)) return false;
    return true;
  });
});

const countedProducts = computed(() =>
  activeCatalogProducts.value.filter((p) => isCounted(p.id))
);

const countedCount = computed(() => countedProducts.value.length);

const equalCount = computed(() =>
  countedProducts.value.filter((p) => getProductDelta(p) === 0).length
);

const diffCount = computed(() =>
  countedProducts.value.filter((p) => hasNonZeroDiff(p)).length
);

const hasAnyNegativeCount = computed(() =>
  Object.keys(draft.value).some((id) => isNegativeCount(id))
);

const openConfirmModal = () => {
  submitError.value = null;
  showConfirmModal.value = true;
};

const submitPhysicalCount = async () => {
  if (countedCount.value === 0 || hasAnyNegativeCount.value) return;
  submitError.value = null;

  if (!navigator.onLine) {
    submitError.value =
      'Sin conexión a internet. El inventariado físico requiere conexión activa.';
    return;
  }

  const itemsPayload = countedProducts.value.map((p) => {
    const entry = draft.value[p.id]!;
    const activeForProd = getProductActiveBatches(p.id);
    const selectedBatch =
      activeForProd.length >= 2 ? entry.batchId ?? activeForProd[0].id : null;
    return {
      productId: p.id,
      countedQuantity: Number(entry.counted),
      batchId: selectedBatch,
    };
  });

  const res = await executeSubmit(
    async () => {
      try {
        return await inventoryStore.applyPhysicalInventoryCount({
          items: itemsPayload,
          notes: countNotes.value.trim() || null,
        });
      } catch (err: any) {
        const msg = err?.message || 'Error al aplicar inventariado físico.';
        if (msg.includes('CASH_REGISTER_MUST_BE_CLOSED')) {
          submitError.value =
            'La caja está abierta. Debes cerrar el turno de caja antes de aplicar el inventariado físico.';
        } else if (msg.includes('OFFLINE_NOT_ALLOWED')) {
          submitError.value =
            'Sin conexión a internet. El inventariado físico requiere conexión activa.';
        } else {
          submitError.value = msg;
        }
        return null;
      }
    },
    { checkConnectivity: true, showSuccessToast: false }
  );

  if (res) {
    clearDraft();
    showConfirmModal.value = false;
    confirmedReceipt.value = res;
    showSuccess(
      `Inventariado aplicado (${res.verifiedTotal} verificados · ${res.adjustedCount} ajustes).`
    );
  }
};

const startAnotherCount = () => {
  confirmedReceipt.value = null;
  countNotes.value = '';
  verifyPreconditions();
};

const formatQty = (qty: number): string => {
  const num = Number(qty);
  return Number.isInteger(num) ? String(num) : num.toFixed(2);
};
</script>

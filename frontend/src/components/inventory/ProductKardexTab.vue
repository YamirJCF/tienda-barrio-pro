<template>
  <div class="space-y-4">
    <!-- Controls Bar -->
    <div class="space-y-3 pb-2 border-b border-slate-200 dark:border-slate-800">
      <div class="flex items-center justify-between gap-2">
        <div class="inline-flex p-1 bg-background-light dark:bg-background-dark rounded-full border border-slate-200 dark:border-slate-800">
          <button
            v-for="preset in datePresets"
            :key="preset.value"
            type="button"
            @click="datePreset = preset.value"
            class="px-3 py-1 rounded-full text-xs font-semibold transition-all cursor-pointer active:scale-95"
            :class="datePreset === preset.value
              ? 'bg-primary text-white shadow-sm font-bold'
              : 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white'"
          >
            {{ preset.label }}
          </button>
        </div>
      </div>

      <!-- Actor Filter -->
      <div class="flex items-center gap-2">
        <label class="text-[11px] font-bold uppercase tracking-wider text-slate-400 shrink-0">Responsable:</label>
        <select
          v-model="selectedActorFilter"
          class="flex-1 h-8 px-2.5 rounded-lg text-xs font-medium bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-200 focus:ring-primary focus:border-primary"
        >
          <option value="all">Todos los responsables</option>
          <option v-for="actor in actorOptions" :key="actor.actorKey" :value="actor.actorKey">
            {{ actor.actorName }} ({{ actor.actorRole === 'owner' || actor.actorRole === 'manager' ? 'Admin' : 'Empleado' }})
          </option>
        </select>
      </div>

      <!-- Movement Type Ribbon -->
      <div class="flex gap-1.5 overflow-x-auto py-1 [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]">
        <button
          v-for="type in movementTypes"
          :key="type.value"
          type="button"
          @click="selectedMovementType = type.value"
          class="px-3 py-1 rounded-full text-xs font-semibold whitespace-nowrap transition-all shrink-0 cursor-pointer active:scale-95"
          :class="selectedMovementType === type.value
            ? 'bg-slate-900 dark:bg-white text-white dark:text-slate-900 shadow-sm font-bold'
            : 'bg-background-light dark:bg-background-dark text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-700/60 hover:border-slate-400'"
        >
          {{ type.label }}
        </button>
      </div>
    </div>

    <!-- Loading State (BaseListSkeleton) -->
    <BaseListSkeleton v-if="loading" :count="4" type="simple" />

    <!-- Error State (N3 persistente) -->
    <div v-else-if="errorMessage" class="bg-red-50 dark:bg-red-950/40 border border-red-200 dark:border-red-800/60 rounded-xl p-4 text-center">
      <p class="text-xs font-semibold text-red-600 dark:text-red-400 mb-1">Error al cargar historial</p>
      <p class="text-xs text-slate-600 dark:text-slate-300 mb-3">{{ errorMessage }}</p>
      <BaseButton type="button" variant="danger" size="sm" @click="loadHistory">
        Reintentar
      </BaseButton>
    </div>

    <!-- Empty State -->
    <div v-else-if="movements.length === 0" class="text-center py-8 bg-background-light dark:bg-background-dark rounded-xl border border-slate-200 dark:border-slate-800">
      <div class="w-12 h-12 rounded-2xl bg-slate-100 dark:bg-slate-800 text-slate-400 flex items-center justify-center mx-auto mb-3">
        <History :size="24" :stroke-width="1.5" />
      </div>
      <p class="text-sm font-semibold text-slate-800 dark:text-white">Sin movimientos</p>
    </div>

    <!-- History List -->
    <div v-else class="space-y-2.5">
      <div class="flex justify-between items-center text-xs text-slate-400 px-1">
        <span class="font-medium font-mono tabular-nums">Mostrando {{ movements.length }} movimientos</span>
      </div>
      <div
        v-for="move in movements"
        :key="move.id"
        class="bg-surface-light dark:bg-surface-dark rounded-xl p-3.5 border border-slate-200 dark:border-slate-800 items-start gap-3 flex transition-all"
      >
        <div class="w-9 h-9 rounded-xl shrink-0 flex items-center justify-center" :class="getTypeBgColor(move.type)">
          <component :is="getTypeLucideIcon(move.type)" :size="16" :stroke-width="2.2" :class="getTypeIconColor(move.type)" />
        </div>

        <div class="flex-1 min-w-0">
          <div class="flex justify-between items-start gap-2">
            <div>
              <div class="flex items-center gap-1.5 flex-wrap">
                <p class="text-sm font-bold text-slate-900 dark:text-white">{{ formatTypeLabel(move.type) }}</p>
                <span
                  v-if="move.reversedMovementId"
                  class="px-1.5 py-0.5 text-[10px] font-bold uppercase rounded bg-indigo-100 text-indigo-700 dark:bg-indigo-900/40 dark:text-indigo-300"
                >
                  Contra-movimiento
                </span>
                <span
                  v-else-if="move.isReversed"
                  class="px-1.5 py-0.5 text-[10px] font-bold uppercase rounded bg-slate-200 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
                >
                  Revertido
                </span>
              </div>
              <p class="text-xs text-slate-400">{{ formatDate(move.date) }}</p>
            </div>
            <div class="text-right shrink-0">
              <span class="font-mono tabular-nums font-bold text-sm block" :class="getQuantityColor(move.type, move.quantity)">
                {{ formatQuantity(move.type, move.quantity) }}
              </span>
              <p class="text-[10px] text-slate-400 dark:text-slate-500 font-mono uppercase tracking-wide">
                {{ move.actorName || move.user }} · {{ move.actorRole === 'owner' || move.actorRole === 'manager' ? 'Admin' : 'Empleado' }}
              </p>
            </div>
          </div>

          <p
            v-if="move.reason"
            class="mt-2 text-xs text-slate-600 dark:text-slate-300 bg-background-light dark:bg-background-dark px-2.5 py-1.5 rounded-lg border border-slate-200 dark:border-slate-800 italic"
          >
            "{{ move.reason }}"
          </p>

          <!-- Action Contra-Movimiento -->
          <div v-if="canCounterMove(move)" class="mt-2 flex items-center justify-end gap-2">
            <div v-if="reversingMovementId === move.id" class="w-full space-y-2 pt-2 border-t border-slate-200 dark:border-slate-800">
              <input
                v-model="reverseReason"
                type="text"
                placeholder="Motivo obligatorio del contra-movimiento (mín. 5 caracteres)..."
                class="w-full h-8 px-2.5 text-xs rounded-lg border border-slate-300 dark:border-slate-700 bg-background-light dark:bg-background-dark text-slate-800 dark:text-white"
              />
              <p v-if="reverseReason.length > 0 && reverseReason.trim().length < 5" class="text-[11px] text-red-600 dark:text-red-400">
                El motivo debe tener al menos 5 caracteres.
              </p>
              <div class="flex justify-end gap-2">
                <button
                  type="button"
                  @click="cancelCounterMove"
                  :disabled="isReversing"
                  class="px-2.5 py-1 text-xs rounded-lg text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800"
                >
                  Cancelar
                </button>
                <button
                  type="button"
                  @click="confirmCounterMove(move.id)"
                  :disabled="isReversing || reverseReason.trim().length < 5"
                  class="px-3 py-1 text-xs font-bold rounded-lg bg-indigo-600 text-white hover:bg-indigo-700 disabled:opacity-50"
                >
                  {{ isReversing ? 'Aplicando...' : 'Confirmar Contra-movimiento' }}
                </button>
              </div>
            </div>
            <button
              v-else
              type="button"
              @click="startCounterMove(move.id)"
              class="inline-flex items-center gap-1 px-2.5 py-1 text-[11px] font-semibold rounded-lg text-indigo-600 dark:text-indigo-400 hover:bg-indigo-50 dark:hover:bg-indigo-900/30 transition-colors cursor-pointer"
            >
              <RotateCcw :size="12" />
              Contra-movimiento
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import { useInventoryStore } from '../../stores/inventory';
import { useAuthStore } from '../../stores/auth';
import { useNotifications } from '../../composables/useNotifications';
import BaseButton from '../ui/BaseButton.vue';
import BaseListSkeleton from '../ui/BaseListSkeleton.vue';
import {
  productRepository,
  type MovementHistoryFilters,
  type InventoryMovementHistory,
  type KardexActorOption,
} from '../../data/repositories/productRepository';
import {
  ArrowDownLeft,
  ArrowUpRight,
  ShoppingCart,
  RotateCcw,
  Trash2,
  Sliders,
  Wrench,
  HelpCircle,
  History,
  Coffee,
  UserCheck,
  Truck,
} from 'lucide-vue-next';

const props = defineProps<{
  productId: string;
}>();

const emit = defineEmits<{
  'stock-updated': [];
}>();

const inventoryStore = useInventoryStore();
const authStore = useAuthStore();
const { showSuccess, showError } = useNotifications();

const loading = ref(false);
const errorMessage = ref<string | null>(null);
const movements = ref<InventoryMovementHistory[]>([]);
const actorOptions = ref<KardexActorOption[]>([]);

const selectedMovementType = ref('all');
const selectedActorFilter = ref('all');
const datePreset = ref<'7d' | '30d' | 'all'>('7d');

const reversingMovementId = ref<string | null>(null);
const reverseReason = ref('');
const isReversing = ref(false);

const datePresets = [
  { value: '7d', label: '7 días' },
  { value: '30d', label: '30 días' },
  { value: 'all', label: 'Histórico' },
] as const;

const movementTypes = [
  { value: 'all', label: 'Todos' },
  { value: 'entrada', label: 'Entradas' },
  { value: 'venta', label: 'Ventas' },
  { value: 'merma', label: 'Mermas' },
  { value: 'consumo_negocio', label: 'Consumo Negocio' },
  { value: 'consumo_personal', label: 'Retiro Personal' },
  { value: 'devolucion_proveedor', label: 'Dev. Proveedor' },
  { value: 'ajuste_conteo', label: 'Ajuste Conteo' },
  { value: 'devolucion', label: 'Reembolso Cliente' },
  { value: 'salida', label: 'Salidas Legacy' },
  { value: 'ajuste', label: 'Ajustes Legacy' },
  { value: 'CORRECCION_SISTEMA', label: 'Correcciones' },
];

const calculateStartDate = (preset: '7d' | '30d' | 'all'): string | undefined => {
  const now = Date.now();
  if (preset === '7d') return new Date(now - 7 * 24 * 60 * 60 * 1000).toISOString();
  if (preset === '30d') return new Date(now - 30 * 24 * 60 * 60 * 1000).toISOString();
  return undefined;
};

const loadHistory = async () => {
  if (!props.productId) return;
  loading.value = true;
  errorMessage.value = null;
  movements.value = [];
  try {
    const filters: MovementHistoryFilters = {
      movementType: selectedMovementType.value !== 'all' ? selectedMovementType.value : undefined,
      createdBy: selectedActorFilter.value !== 'all' ? selectedActorFilter.value : undefined,
      startDate: calculateStartDate(datePreset.value),
      limit: 50,
    };
    const res = await productRepository.getKardexWithActors(props.productId, filters);
    movements.value = res.movements;
    actorOptions.value = res.actors;
  } catch (e: any) {
    errorMessage.value = e?.message || 'Error al recuperar movimientos de Kardex';
  } finally {
    loading.value = false;
  }
};

watch(
  () => props.productId,
  (id) => {
    if (id) {
      reversingMovementId.value = null;
      reverseReason.value = '';
      loadHistory();
    }
  },
  { immediate: true }
);

watch([selectedMovementType, selectedActorFilter, datePreset], () => {
  if (props.productId) {
    loadHistory();
  }
});

const canCounterMove = (move: InventoryMovementHistory): boolean => {
  if (!authStore.canManageInventory && !authStore.isAdmin) return false;
  if (move.isReversed || move.reversedMovementId) return false;
  if (['venta', 'consumo_personal'].includes(move.type)) return false;
  if (move.type === 'merma' && String(move.reason || '').startsWith('[REEMBOLSO-MERMA]')) return false;
  return true;
};

const startCounterMove = (moveId: string) => {
  reversingMovementId.value = moveId;
  reverseReason.value = '';
};

const cancelCounterMove = () => {
  reversingMovementId.value = null;
  reverseReason.value = '';
};

const confirmCounterMove = async (moveId: string) => {
  if (!props.productId || reverseReason.value.trim().length < 5) return;
  isReversing.value = true;
  try {
    await inventoryStore.registerCounterMovement(props.productId, moveId, reverseReason.value.trim());
    showSuccess('Contra-movimiento registrado en Kardex');
    cancelCounterMove();
    emit('stock-updated');
    await loadHistory();
  } catch (err: any) {
    showError(err?.message || 'No se pudo registrar el contra-movimiento');
  } finally {
    isReversing.value = false;
  }
};

const formatTypeLabel = (type: string): string => {
  const labels: Record<string, string> = {
    entrada: 'Entrada de Mercancía',
    venta: 'Venta POS',
    merma: 'Merma / Daño',
    consumo_negocio: 'Consumo del Negocio',
    consumo_personal: 'Retiro Personal',
    devolucion_proveedor: 'Devolución a Proveedor',
    ajuste_conteo: 'Ajuste por Conteo',
    devolucion: 'Reembolso (Vendible)',
    salida: 'Salida Legacy',
    ajuste: 'Ajuste Legacy',
    CORRECCION_SISTEMA: 'Corrección del Sistema',
  };
  return labels[type] || type;
};

const formatDate = (dateStr: string) => {
  return new Date(dateStr).toLocaleString('es-CO', {
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const getTypeLucideIcon = (type: string) => {
  switch (type) {
    case 'entrada': return ArrowDownLeft;
    case 'salida': return ArrowUpRight;
    case 'venta': return ShoppingCart;
    case 'devolucion': return RotateCcw;
    case 'merma': return Trash2;
    case 'consumo_negocio': return Coffee;
    case 'consumo_personal': return UserCheck;
    case 'devolucion_proveedor': return Truck;
    case 'ajuste':
    case 'ajuste_conteo': return Sliders;
    case 'CORRECCION_SISTEMA': return Wrench;
    default: return HelpCircle;
  }
};

const getTypeBgColor = (type: string) => {
  switch (type) {
    case 'entrada': return 'bg-emerald-500/15';
    case 'salida':
    case 'devolucion_proveedor': return 'bg-rose-500/15';
    case 'venta': return 'bg-blue-500/15';
    case 'devolucion': return 'bg-purple-500/15';
    case 'merma':
    case 'consumo_negocio': return 'bg-orange-500/15';
    case 'consumo_personal': return 'bg-indigo-500/15';
    case 'ajuste':
    case 'ajuste_conteo': return 'bg-amber-500/15';
    case 'CORRECCION_SISTEMA': return 'bg-cyan-500/15';
    default: return 'bg-slate-500/15';
  }
};

const getTypeIconColor = (type: string) => {
  switch (type) {
    case 'entrada': return 'text-emerald-500';
    case 'salida':
    case 'devolucion_proveedor': return 'text-rose-500';
    case 'venta': return 'text-blue-500';
    case 'devolucion': return 'text-purple-500';
    case 'merma':
    case 'consumo_negocio': return 'text-orange-500';
    case 'consumo_personal': return 'text-indigo-500';
    case 'ajuste':
    case 'ajuste_conteo': return 'text-amber-500';
    case 'CORRECCION_SISTEMA': return 'text-cyan-500';
    default: return 'text-slate-500';
  }
};

const getQuantityColor = (type: string, qty: number) => {
  if (type === 'entrada' || type === 'devolucion') return 'text-emerald-600 dark:text-emerald-400';
  if (['salida', 'venta', 'merma', 'consumo_negocio', 'consumo_personal', 'devolucion_proveedor'].includes(type)) {
    return 'text-rose-600 dark:text-rose-400';
  }
  return qty >= 0 ? 'text-emerald-600 dark:text-emerald-400' : 'text-rose-600 dark:text-rose-400';
};

const formatQuantity = (type: string, qty: number) => {
  if (type === 'entrada' || type === 'devolucion') return `+${Math.abs(qty)}`;
  if (['salida', 'venta', 'merma', 'consumo_negocio', 'consumo_personal', 'devolucion_proveedor'].includes(type)) {
    return `-${Math.abs(qty)}`;
  }
  return qty > 0 ? `+${qty}` : `${qty}`;
};
</script>

<template>
  <div v-if="activeBatches.length >= 2" class="space-y-2" data-testid="batch-shelf-selector">
    <div class="flex items-center justify-between gap-2">
      <label class="text-xs font-bold uppercase tracking-wider text-slate-600 dark:text-slate-300 flex items-center gap-1.5">
        <Layers :size="14" class="text-primary" />
        Lote en Estantería (FIFO)
      </label>
      <span class="text-[11px] text-slate-400">
        {{ activeBatches.length }} lotes activos
      </span>
    </div>

    <div class="space-y-2 max-h-52 overflow-y-auto pr-0.5">
      <button
        v-for="(batch, idx) in activeBatches"
        :key="batch.id"
        type="button"
        @click="selectBatch(batch.id)"
        :data-testid="`shelf-batch-option-${idx}`"
        class="w-full text-left p-3 rounded-xl border transition-all cursor-pointer flex items-start justify-between gap-3"
        :class="modelValue === batch.id
          ? 'bg-primary/5 dark:bg-primary/15 border-primary ring-1 ring-primary/30'
          : 'bg-surface-light dark:bg-surface-dark border-slate-200 dark:border-slate-800 hover:border-slate-400 dark:hover:border-slate-600'"
      >
        <div class="min-w-0 space-y-1">
          <div class="flex items-center gap-2 flex-wrap">
            <span
              class="px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wide"
              :class="idx === 0
                ? 'bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-300'
                : idx === activeBatches.length - 1
                  ? 'bg-sky-100 text-sky-800 dark:bg-sky-900/40 dark:text-sky-300'
                  : 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300'"
            >
              {{ getShelfLabel(idx, activeBatches.length) }}
            </span>
            <span class="text-[11px] text-slate-400 flex items-center gap-1">
              <Clock :size="11" />
              {{ formatDate(batch.created_at) }}
            </span>
          </div>

          <div class="flex items-center gap-3 flex-wrap text-xs">
            <span class="font-mono tabular-nums font-semibold text-slate-900 dark:text-white">
              Precio: {{ formatWithSign(batch.sale_price) }}
            </span>
            <span class="font-mono tabular-nums text-slate-400">
              Costo: {{ formatWithSign(batch.cost_unit) }}
            </span>
            <span v-if="batch.expiration_date" class="inline-flex items-center gap-1 text-amber-700 dark:text-amber-300 font-mono tabular-nums">
              <Calendar :size="11" />
              Vence: {{ batch.expiration_date }}
            </span>
          </div>
        </div>

        <div class="text-right shrink-0">
          <div class="font-mono tabular-nums font-bold text-sm text-emerald-600 dark:text-emerald-400">
            {{ formatQuantity(batch.quantity_remaining) }} {{ unit || 'un' }}
          </div>
          <div class="text-[10px] text-slate-400">disponible</div>
        </div>
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, watch } from 'vue';
import { Layers, Clock, Calendar } from 'lucide-vue-next';
import type { InventoryBatch } from '../../stores/batches';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';

const props = defineProps<{
  batches: InventoryBatch[];
  modelValue?: string | null;
  unit?: string;
}>();

const emit = defineEmits<{
  'update:modelValue': [value: string | null];
}>();

const { formatWithSign } = useCurrencyFormat();

const activeBatches = computed<InventoryBatch[]>(() =>
  (props.batches || [])
    .filter((b) => Number(b.quantity_remaining) > 0)
    .sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime())
);

const selectBatch = (id: string) => {
  emit('update:modelValue', id);
};

// Auto-selección FIFO transparente: 0 -> null, 1 -> ese lote, 2+ -> primero si no hay selección activa válida
watch(
  activeBatches,
  (list) => {
    if (list.length === 0) {
      if (props.modelValue !== null) emit('update:modelValue', null);
      return;
    }
    if (list.length === 1) {
      if (props.modelValue !== list[0].id) emit('update:modelValue', list[0].id);
      return;
    }
    const stillValid = list.some((b) => b.id === props.modelValue);
    if (!stillValid) {
      emit('update:modelValue', list[0].id);
    }
  },
  { immediate: true }
);

const getShelfLabel = (idx: number, total: number): string => {
  if (idx === 0) return 'Lote anterior (adelante en estantería)';
  if (idx === total - 1) return 'Lote reciente (atrás en estantería)';
  return `Lote intermedio #${idx + 1}`;
};

const formatQuantity = (qty: number): string => {
  const num = Number(qty);
  return Number.isInteger(num) ? String(num) : num.toFixed(2);
};

const formatDate = (dateStr: string): string => {
  if (!dateStr) return '-';
  return new Date(dateStr).toLocaleDateString('es-CO', {
    day: '2-digit',
    month: 'short',
    year: '2-digit',
  });
};
</script>

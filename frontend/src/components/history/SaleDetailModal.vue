<script setup lang="ts">
/**
 * SaleDetailModal — Shows the full ticket detail for a sale.
 * Calls get_sale_detail RPC on open. Uses BaseModal.
 * Ref: FRD F4.3, AC-12
 */
import { ref, watch } from 'vue';
import BaseModal from '../ui/BaseModal.vue';
import { getSupabaseClient } from '../../data/supabaseClient';
import { formatCurrency } from '../../utils/currency';
import { formatRelativeTime } from '../../composables/useRelativeTime';
import { logger } from '../../utils/logger';
import {
  ShoppingCart, User, CreditCard, Clock,
  AlertTriangle, Package
} from 'lucide-vue-next';

interface Props {
  modelValue: boolean;
  saleId: string | null;
}

interface SaleDetail {
  ticket_number: number;
  total: number;
  payment_method: string;
  amount_received: number;
  change_given: number;
  employee_name: string;
  client_name: string | null;
  is_voided: boolean;
  void_reason: string | null;
  created_at: string;
  items: { product_name: string; quantity: number; unit_price: number; subtotal: number }[];
  items_count: number;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
}>();

const isLoading = ref(false);
const detail = ref<SaleDetail | null>(null);
const fetchError = ref<string | null>(null);

const paymentLabels: Record<string, string> = {
  'efectivo': '💵 Efectivo',
  'nequi': '📱 Nequi',
  'daviplata': '📱 Daviplata',
  'fiado': '📋 Fiado'
};

watch(() => props.modelValue, async (open) => {
  if (open && props.saleId) {
    isLoading.value = true;
    fetchError.value = null;
    detail.value = null;

    try {
      const supabase = getSupabaseClient();
      if (!supabase) throw new Error('Sin conexión');

      const { data, error } = await supabase.rpc('get_sale_detail' as any, {
        p_sale_id: props.saleId
      });

      if (error) throw error;

      const payload = data as any;
      if (!payload?.success) {
        fetchError.value = payload?.error || 'Error al cargar detalle';
        return;
      }
      detail.value = payload as SaleDetail;
    } catch (e: any) {
      logger.error('[SaleDetailModal] Error fetching detail', e);
      fetchError.value = 'Error al cargar el detalle de la venta';
    } finally {
      isLoading.value = false;
    }
  }
});
</script>

<template>
  <BaseModal
    :modelValue="modelValue"
    @update:modelValue="emit('update:modelValue', $event)"
    :title="`Venta #${detail?.ticket_number ?? '...'}`"
    showCloseButton
    maxHeight="90vh"
  >
    <!-- Loading -->
    <div v-if="isLoading" class="flex flex-col items-center justify-center py-12">
      <div class="w-10 h-10 border-4 border-primary border-t-transparent rounded-full animate-spin"></div>
      <p class="mt-4 text-sm text-slate-500">Cargando detalle...</p>
    </div>

    <!-- Error -->
    <div v-else-if="fetchError" class="p-6 text-center">
      <AlertTriangle :size="40" class="mx-auto text-red-400 mb-3" />
      <p class="text-red-600 dark:text-red-400 font-medium">{{ fetchError }}</p>
    </div>

    <!-- Detail Content -->
    <div v-else-if="detail" class="px-4 pb-4 space-y-4">
      <!-- Voided Banner -->
      <div
        v-if="detail.is_voided"
        class="flex items-center gap-2 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl p-3"
      >
        <AlertTriangle :size="18" class="text-red-600 dark:text-red-400 shrink-0" />
        <div>
          <p class="text-sm font-bold text-red-700 dark:text-red-300">Venta Anulada</p>
          <p v-if="detail.void_reason" class="text-xs text-red-600 dark:text-red-400">{{ detail.void_reason }}</p>
        </div>
      </div>

      <!-- Meta Info -->
      <div class="grid grid-cols-2 gap-3">
        <div class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-300">
          <Clock :size="16" class="text-slate-400 shrink-0" />
          <span>{{ formatRelativeTime(detail.created_at) }}</span>
        </div>
        <div class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-300">
          <User :size="16" class="text-slate-400 shrink-0" />
          <span class="truncate">{{ detail.employee_name }}</span>
        </div>
        <div class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-300">
          <CreditCard :size="16" class="text-slate-400 shrink-0" />
          <span>{{ paymentLabels[detail.payment_method] || detail.payment_method }}</span>
        </div>
        <div v-if="detail.client_name" class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-300">
          <ShoppingCart :size="16" class="text-slate-400 shrink-0" />
          <span class="truncate">{{ detail.client_name }}</span>
        </div>
      </div>

      <!-- Items Table -->
      <div class="bg-slate-50 dark:bg-slate-800/50 rounded-xl border border-slate-200 dark:border-slate-700 overflow-hidden">
        <table class="w-full text-sm">
          <thead>
            <tr class="border-b border-slate-200 dark:border-slate-700 text-left">
              <th class="px-3 py-2.5 text-xs font-semibold text-slate-500 uppercase tracking-wider">Producto</th>
              <th class="px-3 py-2.5 text-xs font-semibold text-slate-500 uppercase tracking-wider text-center">Cant.</th>
              <th class="px-3 py-2.5 text-xs font-semibold text-slate-500 uppercase tracking-wider text-right">Precio</th>
              <th class="px-3 py-2.5 text-xs font-semibold text-slate-500 uppercase tracking-wider text-right">Subtotal</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(item, idx) in detail.items"
              :key="idx"
              class="border-b last:border-b-0 border-slate-100 dark:border-slate-700/50"
            >
              <td class="px-3 py-2.5 text-slate-800 dark:text-slate-200">
                <div class="flex items-center gap-2">
                  <Package :size="14" class="text-slate-400 shrink-0" />
                  <span class="truncate max-w-[140px]">{{ item.product_name }}</span>
                </div>
              </td>
              <td class="px-3 py-2.5 text-center text-slate-600 dark:text-slate-300">{{ item.quantity }}</td>
              <td class="px-3 py-2.5 text-right text-slate-600 dark:text-slate-300">{{ formatCurrency(item.unit_price) }}</td>
              <td class="px-3 py-2.5 text-right font-semibold text-slate-800 dark:text-slate-200">{{ formatCurrency(item.subtotal) }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Totals -->
      <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-3 space-y-2">
        <div class="flex justify-between text-sm">
          <span class="text-slate-500">Items</span>
          <span class="text-slate-700 dark:text-slate-300">{{ detail.items_count }} producto{{ detail.items_count !== 1 ? 's' : '' }}</span>
        </div>
        <div class="flex justify-between text-sm" v-if="detail.payment_method === 'efectivo' && detail.amount_received">
          <span class="text-slate-500">Recibido</span>
          <span class="text-slate-700 dark:text-slate-300">{{ formatCurrency(detail.amount_received) }}</span>
        </div>
        <div class="flex justify-between text-sm" v-if="detail.payment_method === 'efectivo' && detail.change_given">
          <span class="text-slate-500">Cambio</span>
          <span class="text-slate-700 dark:text-slate-300">{{ formatCurrency(detail.change_given) }}</span>
        </div>
        <div class="h-px bg-slate-200 dark:bg-slate-700"></div>
        <div class="flex justify-between">
          <span class="font-bold text-slate-900 dark:text-white">Total</span>
          <span class="font-bold text-lg text-emerald-600 dark:text-emerald-400">{{ formatCurrency(detail.total) }}</span>
        </div>
      </div>
    </div>
  </BaseModal>
</template>

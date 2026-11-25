<script setup lang="ts">
/**
 * SaleDetailModal — Shows the full ticket detail for a sale.
 * Calls get_sale_detail RPC on open. Uses BaseModal.
 * Ref: FRD F4.3, AC-12, UX-ADR-008
 */
import { ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import BaseModal from '../ui/BaseModal.vue';
import BaseButton from '../ui/BaseButton.vue';
import { useCurrencyFormat } from '../../composables/useCurrencyFormat';
import { useNotifications } from '../../composables/useNotifications';
import { useAuthStore } from '../../stores/auth';
import { saleRepository } from '../../data/repositories/saleRepository';
import { formatRelativeTime } from '../../composables/useRelativeTime';
import { logger } from '../../utils/logger';
import {
  ShoppingCart, User, CreditCard, Clock,
  AlertTriangle, Package, XCircle, ExternalLink
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
  client_id?: string | null;
  client_name: string | null;
  is_voided: boolean;
  void_reason: string | null;
  created_at: string;
  items: { product_id?: string; product_name: string; quantity: number; unit_price: number; subtotal: number }[];
  items_count: number;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  'voided': [saleId: string];
}>();

const router = useRouter();
const authStore = useAuthStore();
const { formatWithSign } = useCurrencyFormat();
const { showSuccess } = useNotifications();

const isLoading = ref(false);
const detail = ref<SaleDetail | null>(null);
const fetchError = ref<string | null>(null);
const isVoiding = ref(false);
const voidReason = ref('');
const voidError = ref<string | null>(null);
const showVoidModal = ref(false);

const goToClient = (clientId?: string | null) => {
  if (!clientId) return;
  emit('update:modelValue', false);
  router?.push(`/clients/${clientId}`);
};

const goToProduct = (productId?: string) => {
  if (!productId) return;
  emit('update:modelValue', false);
  router?.push({ path: '/inventory', query: { productId } });
};

const handleVoidSale = async () => {
  if (isVoiding.value) return;
  voidError.value = null;
  if (voidReason.value.trim().length < 10) {
    voidError.value = 'El motivo de anulación debe tener al menos 10 caracteres.';
    return;
  }
  if (!props.saleId) return;

  isVoiding.value = true;
  try {
    const res = await saleRepository.voidSale(props.saleId, voidReason.value.trim());
    if (res.success) {
      showSuccess('Venta anulada correctamente');
      showVoidModal.value = false;
      if (detail.value) {
        detail.value.is_voided = true;
        detail.value.void_reason = voidReason.value.trim();
      }
      voidReason.value = '';
      emit('voided', props.saleId);
    } else {
      voidError.value = res.error || 'No se pudo anular la venta';
    }
  } catch (err: any) {
    voidError.value = err?.message || 'Error al anular la venta';
  } finally {
    isVoiding.value = false;
  }
};

const paymentLabels: Record<string, string> = {
  'efectivo': 'Efectivo',
  'nequi': 'Nequi',
  'llave_bre': 'Llave Bre-B',
  'fiado': 'Fiado',
  'consumo_personal': 'Retiro Personal'
};

const loadDetail = async () => {
  if (!props.saleId) return;
  isLoading.value = true;
  fetchError.value = null;
  detail.value = null;
  voidError.value = null;

  try {
    const payload = await saleRepository.getSaleDetail(props.saleId);
    if (!payload?.success) {
      fetchError.value = payload?.error || 'Error al cargar detalle';
      return;
    }
    detail.value = payload as SaleDetail;
  } catch (e: any) {
    logger.error('[SaleDetailModal] Error fetching detail', e);
    fetchError.value = e?.message || 'Error al cargar el detalle de la venta';
  } finally {
    isLoading.value = false;
  }
};

watch(
  () => [props.modelValue, props.saleId] as const,
  async ([open, id]) => {
    if (open && id) {
      await loadDetail();
    } else if (!open) {
      detail.value = null;
      fetchError.value = null;
      voidError.value = null;
      voidReason.value = '';
      showVoidModal.value = false;
    }
  },
  { immediate: true }
);

watch(voidReason, () => {
  if (voidError.value) {
    voidError.value = null;
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
    <div v-else-if="fetchError" class="p-6 text-center space-y-3">
      <AlertTriangle :size="40" class="mx-auto text-red-400" />
      <p class="text-red-600 dark:text-red-400 font-medium text-sm">{{ fetchError }}</p>
      <BaseButton variant="outline" size="sm" @click="loadDetail">Reintentar</BaseButton>
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
        <div v-if="detail.client_name" class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-300 min-w-0">
          <ShoppingCart :size="16" class="text-slate-400 shrink-0" />
          <button
            v-if="detail.client_id"
            type="button"
            data-testid="sale-detail-client-link"
            @click="goToClient(detail.client_id)"
            class="inline-flex items-center gap-1 font-semibold text-primary hover:underline truncate cursor-pointer text-left"
            title="Ver estado de cuenta del cliente"
          >
            <span class="truncate">{{ detail.client_name }}</span>
            <ExternalLink :size="13" class="shrink-0" />
          </button>
          <span v-else class="truncate">{{ detail.client_name }}</span>
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
              :key="item.product_id || idx"
              class="border-b last:border-b-0 border-slate-100 dark:border-slate-700/50"
            >
              <td class="px-3 py-2.5 text-slate-800 dark:text-slate-200">
                <div class="flex items-center gap-2 min-w-0">
                  <Package :size="14" class="text-slate-400 shrink-0" />
                  <button
                    v-if="item.product_id"
                    type="button"
                    data-testid="sale-detail-product-link"
                    @click="goToProduct(item.product_id)"
                    class="inline-flex items-center gap-1 font-medium text-primary hover:underline truncate max-w-[140px] cursor-pointer text-left"
                    title="Abrir producto en Inventario"
                  >
                    <span class="truncate">{{ item.product_name }}</span>
                    <ExternalLink :size="12" class="shrink-0" />
                  </button>
                  <span v-else class="truncate max-w-[140px]">{{ item.product_name }}</span>
                </div>
              </td>
              <td class="px-3 py-2.5 text-center font-mono tabular-nums text-slate-600 dark:text-slate-300">{{ item.quantity }}</td>
              <td class="px-3 py-2.5 text-right font-mono tabular-nums text-slate-600 dark:text-slate-300">{{ formatWithSign(item.unit_price) }}</td>
              <td class="px-3 py-2.5 text-right font-mono tabular-nums font-semibold text-slate-800 dark:text-slate-200">{{ formatWithSign(item.subtotal) }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Totals -->
      <div class="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 p-3 space-y-2">
        <div class="flex justify-between text-sm">
          <span class="text-slate-500">Items</span>
          <span class="font-mono tabular-nums text-slate-700 dark:text-slate-300">{{ detail.items_count }} producto{{ detail.items_count !== 1 ? 's' : '' }}</span>
        </div>
        <div class="flex justify-between text-sm" v-if="detail.payment_method === 'efectivo' && detail.amount_received">
          <span class="text-slate-500">Recibido</span>
          <span class="font-mono tabular-nums text-slate-700 dark:text-slate-300">{{ formatWithSign(detail.amount_received) }}</span>
        </div>
        <div class="flex justify-between text-sm" v-if="detail.payment_method === 'efectivo' && detail.change_given">
          <span class="text-slate-500">Cambio</span>
          <span class="font-mono tabular-nums text-slate-700 dark:text-slate-300">{{ formatWithSign(detail.change_given) }}</span>
        </div>
        <div class="h-px bg-slate-200 dark:bg-slate-700"></div>
        <div class="flex justify-between">
          <span class="font-bold text-slate-900 dark:text-white">Total</span>
          <span class="font-bold font-mono tabular-nums text-lg text-emerald-600 dark:text-emerald-400">{{ formatWithSign(detail.total) }}</span>
        </div>
      </div>

      <!-- Actions: Void Sale (Admin Only) -->
      <div v-if="authStore.isAdmin && !detail.is_voided" class="pt-2">
        <BaseButton
          variant="danger"
          data-testid="open-void-panel-btn"
          class="w-full justify-center"
          @click="showVoidModal = true"
        >
          <XCircle :size="16" class="mr-1.5" />
          Anular Venta (Admin)
        </BaseButton>
      </div>
    </div>

    <!-- Modal Confirmación Anulación -->
    <BaseModal
      v-model="showVoidModal"
      title="Anular Venta"
      maxHeight="500px"
    >
      <div class="p-4 space-y-4">
        <!-- Read Model Compensatorio (Arquetipo D) -->
        <div
          v-if="detail"
          data-testid="void-sale-read-model"
          class="rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800/60 p-3 space-y-1.5 text-xs"
        >
          <div class="flex items-center justify-between">
            <span class="font-bold text-slate-900 dark:text-white">Venta #{{ detail.ticket_number }}</span>
            <span class="font-bold font-mono tabular-nums text-sm text-rose-600 dark:text-rose-400">
              {{ formatWithSign(detail.total) }}
            </span>
          </div>
          <div class="flex flex-wrap items-center justify-between gap-2 text-slate-500 dark:text-slate-400">
            <span>Canal: <strong class="text-slate-700 dark:text-slate-200">{{ paymentLabels[detail.payment_method] || detail.payment_method }}</strong></span>
            <span v-if="detail.client_name">Cliente: <strong class="text-slate-700 dark:text-slate-200">{{ detail.client_name }}</strong></span>
          </div>
        </div>

        <div class="flex items-center gap-2 text-red-600 bg-red-50 dark:bg-red-900/20 p-3 rounded-xl border border-red-200 dark:border-red-800 text-sm">
          <AlertTriangle :size="20" class="shrink-0" />
          <span>Esta acción revertirá los fondos en caja/deuda y reingresará los productos al inventario.</span>
        </div>
        <div
          v-if="voidError"
          role="alert"
          data-testid="void-sale-error"
          class="p-3 rounded-xl bg-amber-50 dark:bg-amber-900/30 border border-amber-300 dark:border-amber-700 text-xs sm:text-sm font-semibold text-amber-900 dark:text-amber-200"
        >
          {{ voidError }}
        </div>
        <div>
          <label class="block text-xs font-semibold uppercase text-slate-500 mb-1">
            Motivo de anulación (mínimo 10 caracteres)
          </label>
          <textarea
            v-model="voidReason"
            rows="3"
            class="w-full p-2.5 text-sm border border-slate-200 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-800 dark:text-slate-200 focus:outline-none focus:ring-2 focus:ring-red-500"
            placeholder="Describa el motivo de la anulación..."
          ></textarea>
          <p class="text-[11px] text-slate-400 mt-1">{{ voidReason.length }}/10 caracteres mínimos</p>
        </div>
        <div class="flex justify-end gap-2 pt-2">
          <BaseButton variant="secondary" @click="showVoidModal = false" :disabled="isVoiding">
            Cancelar
          </BaseButton>
          <BaseButton 
            variant="danger" 
            data-testid="confirm-void-sale-btn"
            @click="handleVoidSale" 
            :loading="isVoiding" 
            :disabled="isVoiding || voidReason.trim().length < 10"
          >
            Confirmar Anulación
          </BaseButton>
        </div>
      </div>
    </BaseModal>
  </BaseModal>
</template>

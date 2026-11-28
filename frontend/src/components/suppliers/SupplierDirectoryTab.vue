<template>
  <div class="space-y-4">
    <!-- Search + Add CTA -->
    <div class="flex items-center gap-2">
      <div class="flex-1">
        <BaseInput v-model="searchQuery" placeholder="Buscar proveedor...">
          <template #prefix>
            <Search :size="18" :stroke-width="1.5" class="text-slate-400" />
          </template>
        </BaseInput>
      </div>
      <BaseButton
        v-if="canManageSuppliers"
        size="sm"
        data-testid="open-create-supplier-btn"
        @click="openNewSupplier"
      >
        <Plus :size="16" class="mr-1" />
        Nuevo
      </BaseButton>
    </div>

    <!-- Error State N3 Persistente (Regla 3) -->
    <div
      v-if="suppliersStore.error"
      role="alert"
      data-testid="suppliers-error-banner"
      class="p-4 rounded-2xl bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800 space-y-2"
    >
      <p class="text-sm font-semibold text-red-700 dark:text-red-300">{{ suppliersStore.error }}</p>
      <BaseButton size="sm" variant="danger" data-testid="suppliers-retry-btn" @click="emit('retry')">
        Reintentar
      </BaseButton>
    </div>

    <!-- Loading State -->
    <BaseListSkeleton v-else-if="suppliersStore.isLoading" :count="4" type="simple" />

    <!-- Supplier List -->
    <div v-else-if="filteredSuppliers.length > 0" class="flex flex-col gap-3">
      <div
        v-for="supplier in filteredSuppliers"
        :key="supplier.id"
        :data-testid="`supplier-card-${supplier.id}`"
        class="bg-surface-light dark:bg-surface-dark rounded-2xl shadow-sm p-4 border border-slate-200 dark:border-slate-800 flex flex-col gap-3"
      >
        <div class="flex items-start gap-3">
          <div class="h-11 w-11 shrink-0 rounded-xl flex items-center justify-center bg-blue-50 dark:bg-blue-950/40 border border-blue-200 dark:border-blue-800/50">
            <Truck :size="20" class="text-blue-600 dark:text-blue-400" />
          </div>

          <div class="flex-1 min-w-0">
            <div class="flex flex-wrap items-center gap-2">
              <p class="text-slate-900 dark:text-white text-base font-bold truncate">
                {{ supplier.name }}
              </p>
              <span
                v-if="supplier.is_default"
                class="text-[10px] font-bold uppercase tracking-wider bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400 px-2 py-0.5 rounded-full"
              >
                Por defecto
              </span>
            </div>

            <p class="text-slate-500 dark:text-slate-400 text-xs font-medium mt-0.5">
              Frecuencia: {{ supplier.frequency_days }} días · Lead: {{ supplier.lead_time_days }} días
              <span v-if="supplier.delivery_day"> · Entrega: {{ getDayName(supplier.delivery_day) }}</span>
            </p>
          </div>
        </div>

        <!-- Deuda CxP del Servidor + Acciones -->
        <div class="flex flex-wrap items-center justify-between gap-2 pt-3 border-t border-slate-100 dark:border-slate-800">
          <div>
            <p class="text-[10px] font-bold uppercase tracking-wider text-slate-400">Por Pagar</p>
            <p
              class="text-sm font-black font-mono tabular-nums"
              :class="Number(supplier.pending_debt ?? 0) > 0 ? 'text-amber-600 dark:text-amber-400' : 'text-slate-700 dark:text-slate-300'"
            >
              {{ formatCurrency(Number(supplier.pending_debt ?? 0)) }}
              <span class="text-[11px] font-normal text-slate-400 ml-1">
                ({{ supplier.open_invoices_count ?? 0 }} abiertas)
              </span>
            </p>
          </div>

          <div class="flex items-center gap-1.5">
            <BaseButton
              size="sm"
              variant="secondary"
              :data-testid="`supplier-view-cxp-${supplier.id}`"
              @click="emit('view-payables', supplier.id)"
            >
              <Receipt :size="14" class="mr-1" />
              Facturas
            </BaseButton>

            <button
              v-if="canManageSuppliers"
              type="button"
              :aria-label="`Editar ${supplier.name}`"
              :data-testid="`edit-supplier-btn-${supplier.id}`"
              @click="openEditSupplier(supplier)"
              class="p-2 rounded-lg border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors cursor-pointer"
            >
              <Pencil :size="16" />
            </button>

            <button
              v-if="canManageSuppliers && !supplier.is_default"
              type="button"
              :aria-label="`Eliminar ${supplier.name}`"
              :data-testid="`delete-supplier-btn-${supplier.id}`"
              @click="openDeleteModal(supplier)"
              class="p-2 rounded-lg border border-red-200 dark:border-red-900/60 text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-950/30 transition-colors cursor-pointer"
            >
              <Trash2 :size="16" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div v-else class="flex flex-col items-center justify-center py-12 px-4 text-center">
      <Truck :size="64" :stroke-width="1" class="text-slate-300 dark:text-slate-600 mb-4" />
      <h3 class="text-lg font-bold text-slate-900 dark:text-white mb-2">
        {{ searchQuery ? 'No se encontraron proveedores' : 'Sin proveedores' }}
      </h3>
      <p class="text-sm text-slate-500 dark:text-slate-400 max-w-xs">
        {{
          searchQuery
            ? 'Intenta con otro término de búsqueda'
            : 'Agrega tu primer proveedor para gestionar compras y cuentas por pagar'
        }}
      </p>
      <BaseButton
        v-if="!searchQuery && canManageSuppliers"
        @click="openNewSupplier"
        class="mt-6"
      >
        <Plus :size="18" class="mr-2" />
        Agregar Proveedor
      </BaseButton>
    </div>

    <!-- Create / Edit Supplier Modal (BaseModal) -->
    <BaseModal
      v-model="showSupplierModal"
      :title="editingSupplierId ? 'Editar Proveedor' : 'Nuevo Proveedor'"
      :showCloseButton="true"
      maxHeight="90vh"
    >
      <div class="p-4 space-y-4">
        <div
          v-if="formError"
          role="alert"
          data-testid="supplier-form-error"
          class="p-3 rounded-xl bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800 text-xs font-semibold text-red-700 dark:text-red-300"
        >
          {{ formError }}
        </div>

        <BaseInput
          v-model="supplierForm.name"
          data-testid="supplier-name-input"
          label="Nombre del Proveedor"
          placeholder="Ej: Distribuidora XYZ"
          :disabled="isSaving"
        />

        <BaseInput
          v-model.number="supplierForm.frequencyDays"
          data-testid="supplier-frequency-input"
          label="Frecuencia de entrega (días)"
          type="number"
          min="1"
          :disabled="isSaving"
        />

        <BaseInput
          v-model.number="supplierForm.leadTimeDays"
          data-testid="supplier-leadtime-input"
          label="Tiempo de entrega (días)"
          type="number"
          min="1"
          :disabled="isSaving"
        />

        <BaseInput
          v-model.number="supplierForm.deliveryDay"
          data-testid="supplier-deliveryday-input"
          label="Día de entrega preferido (1=Dom, 7=Sáb)"
          type="number"
          min="1"
          max="7"
          placeholder="Opcional"
          :disabled="isSaving"
        />
      </div>

      <template #footer>
        <div class="p-4 pt-2 border-t border-slate-100 dark:border-slate-800 flex gap-3">
          <BaseButton variant="secondary" @click="showSupplierModal = false" class="flex-1" :disabled="isSaving">
            Cancelar
          </BaseButton>
          <BaseButton
            data-testid="submit-supplier-btn"
            @click="handleSave"
            class="flex-1"
            :loading="isSaving"
            :disabled="isSaving"
          >
            {{ editingSupplierId ? 'Actualizar' : 'Guardar' }}
          </BaseButton>
        </div>
      </template>
    </BaseModal>

    <!-- Delete Confirmation Modal (N5, cero confirm() nativo) -->
    <BaseModal
      v-model="showDeleteModal"
      title="Eliminar Proveedor"
      :showCloseButton="true"
      maxHeight="60vh"
    >
      <div class="p-4 space-y-3">
        <div class="p-3 rounded-xl bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800/60 flex items-start gap-2.5">
          <AlertTriangle :size="18" class="text-amber-600 dark:text-amber-400 shrink-0 mt-0.5" />
          <div class="text-xs text-amber-900 dark:text-amber-200 space-y-1">
            <p>
              ¿Eliminar a <strong>{{ supplierToDelete?.name }}</strong>? No se puede deshacer.
            </p>
            <p v-if="Number(supplierToDelete?.pending_debt ?? 0) > 0" class="font-semibold text-red-700 dark:text-red-300">
              Tiene {{ formatCurrency(Number(supplierToDelete?.pending_debt ?? 0)) }} pendientes por pagar.
            </p>
          </div>
        </div>

        <div
          v-if="deleteError"
          role="alert"
          data-testid="supplier-delete-error"
          class="p-3 rounded-xl bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800 text-xs font-semibold text-red-700 dark:text-red-300"
        >
          {{ deleteError }}
        </div>
      </div>

      <template #footer>
        <div class="p-4 pt-2 border-t border-slate-100 dark:border-slate-800 flex gap-3">
          <BaseButton variant="secondary" class="flex-1" :disabled="isDeleting" @click="showDeleteModal = false">
            Cancelar
          </BaseButton>
          <BaseButton
            variant="danger"
            class="flex-1"
            data-testid="confirm-delete-supplier-btn"
            :loading="isDeleting"
            :disabled="isDeleting"
            @click="confirmDelete"
          >
            Eliminar
          </BaseButton>
        </div>
      </template>
    </BaseModal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useSuppliersStore, type Supplier } from '@/stores/suppliers';
import { useAuthStore } from '@/stores/auth';
import { useCurrencyFormat } from '@/composables/useCurrencyFormat';
import { useNotifications } from '@/composables/useNotifications';
import BaseInput from '@/components/ui/BaseInput.vue';
import BaseButton from '@/components/ui/BaseButton.vue';
import BaseModal from '@/components/ui/BaseModal.vue';
import BaseListSkeleton from '@/components/ui/BaseListSkeleton.vue';
import { Search, Truck, Plus, Pencil, Trash2, Receipt, AlertTriangle } from 'lucide-vue-next';

const emit = defineEmits<{
  (e: 'view-payables', supplierId: string): void;
  (e: 'retry'): void;
  (e: 'suppliers-mutated'): void;
}>();

const suppliersStore = useSuppliersStore();
const authStore = useAuthStore();
const { formatCurrency } = useCurrencyFormat();
const { showSuccess } = useNotifications();

const searchQuery = ref('');
const showSupplierModal = ref(false);
const editingSupplierId = ref<string | undefined>(undefined);
const isSaving = ref(false);
const formError = ref<string | null>(null);

const showDeleteModal = ref(false);
const supplierToDelete = ref<Supplier | null>(null);
const isDeleting = ref(false);
const deleteError = ref<string | null>(null);

const supplierForm = ref({
  name: '',
  deliveryDay: undefined as number | undefined,
  frequencyDays: 7,
  leadTimeDays: 1,
});

const canManageSuppliers = computed(() => authStore.isAdmin);
const storeId = computed(() => authStore.currentUser?.storeId || authStore.currentStore?.id || '');

const filteredSuppliers = computed(() => {
  if (!searchQuery.value) return suppliersStore.suppliers;
  const query = searchQuery.value.toLowerCase();
  return suppliersStore.suppliers.filter((s) => s.name.toLowerCase().includes(query));
});

const getDayName = (day?: number | null) => {
  if (!day) return 'No especificado';
  const days = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
  return days[day - 1] || 'N/A';
};

const openNewSupplier = () => {
  formError.value = null;
  editingSupplierId.value = undefined;
  supplierForm.value = {
    name: '',
    deliveryDay: undefined,
    frequencyDays: 7,
    leadTimeDays: 1,
  };
  showSupplierModal.value = true;
};

const openEditSupplier = (supplier: Supplier) => {
  formError.value = null;
  editingSupplierId.value = supplier.id;
  supplierForm.value = {
    name: supplier.name,
    deliveryDay: supplier.delivery_day ?? undefined,
    frequencyDays: supplier.frequency_days,
    leadTimeDays: supplier.lead_time_days,
  };
  showSupplierModal.value = true;
};

const handleSave = async () => {
  if (isSaving.value) return;
  const trimmedName = supplierForm.value.name.trim();
  if (trimmedName.length < 2) {
    formError.value = 'El nombre del proveedor debe tener al menos 2 caracteres.';
    return;
  }

  const freq = Number(supplierForm.value.frequencyDays);
  const lead = Number(supplierForm.value.leadTimeDays);
  if (!Number.isFinite(freq) || freq < 1 || !Number.isFinite(lead) || lead < 1) {
    formError.value = 'La frecuencia y el tiempo de entrega deben ser al menos 1 día.';
    return;
  }

  const deliveryDayRaw = supplierForm.value.deliveryDay;
  const deliveryDayNormalized =
    deliveryDayRaw !== undefined && deliveryDayRaw !== null && String(deliveryDayRaw) !== ''
      ? Number(deliveryDayRaw)
      : null;

  if (deliveryDayNormalized !== null && (deliveryDayNormalized < 1 || deliveryDayNormalized > 7)) {
    formError.value = 'El día de entrega debe estar entre 1 (Dom) y 7 (Sáb).';
    return;
  }

  isSaving.value = true;
  formError.value = null;

  if (editingSupplierId.value) {
    const res = await suppliersStore.updateSupplier(editingSupplierId.value, {
      name: trimmedName,
      delivery_day: deliveryDayNormalized,
      frequency_days: freq,
      lead_time_days: lead,
    });
    isSaving.value = false;

    if (!res.success) {
      formError.value = res.error || 'Error al actualizar proveedor.';
      return;
    }

    showSuccess('Proveedor actualizado');
    showSupplierModal.value = false;
    emit('suppliers-mutated');
    return;
  }

  if (!storeId.value) {
    isSaving.value = false;
    formError.value = 'No hay tienda activa.';
    return;
  }

  const res = await suppliersStore.createSupplier({
    store_id: storeId.value,
    name: trimmedName,
    delivery_day: deliveryDayNormalized,
    frequency_days: freq,
    lead_time_days: lead,
    is_default: false,
  });

  isSaving.value = false;
  if (!res.success) {
    formError.value = res.error || 'Error al crear proveedor.';
    return;
  }

  showSuccess('Proveedor creado correctamente');
  showSupplierModal.value = false;
  emit('suppliers-mutated');
};

const openDeleteModal = (supplier: Supplier) => {
  deleteError.value = null;
  supplierToDelete.value = supplier;
  showDeleteModal.value = true;
};

const confirmDelete = async () => {
  if (!supplierToDelete.value || isDeleting.value) return;
  isDeleting.value = true;
  deleteError.value = null;

  const res = await suppliersStore.deleteSupplier(supplierToDelete.value.id);
  isDeleting.value = false;

  if (!res.success) {
    deleteError.value = res.error || 'No se pudo eliminar el proveedor.';
    return;
  }

  showSuccess('Proveedor eliminado');
  showDeleteModal.value = false;
  supplierToDelete.value = null;
  emit('suppliers-mutated');
};
</script>

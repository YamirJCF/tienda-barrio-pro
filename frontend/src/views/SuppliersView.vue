<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useSuppliersStore } from '../stores/suppliers';
import { useAuthStore } from '../stores/auth';
import BottomNav from '../components/BottomNav.vue';
import BaseInput from '@/components/ui/BaseInput.vue';
import BaseButton from '@/components/ui/BaseButton.vue';
import Skeleton from '@/components/ui/Skeleton.vue';
import { 
  ArrowLeft, 
  Search, 
  Truck, 
  Plus,
  Pencil,
  Trash2
} from 'lucide-vue-next';

const router = useRouter();
const suppliersStore = useSuppliersStore();
const authStore = useAuthStore();

onMounted(async () => {
  const storeId = authStore.currentStore?.id;
  if (storeId) {
    await suppliersStore.fetchSuppliers(storeId);
  }
});

// State
const searchQuery = ref('');
const showSupplierModal = ref(false);
const editingSupplierId = ref<string | undefined>(undefined);

// New supplier form
const newSupplier = ref({
  name: '',
  deliveryDay: undefined as number | undefined,
  frequencyDays: 7,
  leadTimeDays: 1
});

// Computed
const filteredSuppliers = computed(() => {
  if (!searchQuery.value) return suppliersStore.suppliers;
  const query = searchQuery.value.toLowerCase();
  return suppliersStore.suppliers.filter(s => 
    s.name.toLowerCase().includes(query)
  );
});

const canManageSuppliers = computed(() => authStore.isAdmin);

// Methods
const goToDashboard = () => {
  router.push('/');
};

const openNewSupplier = () => {
  newSupplier.value = {
    name: '',
    deliveryDay: undefined,
    frequencyDays: 7,
    leadTimeDays: 1
  };
  editingSupplierId.value = undefined;
  showSupplierModal.value = true;
};

const handleSave = async () => {
  const storeId = authStore.currentStore?.id;
  if (!storeId || !newSupplier.value.name.trim()) return;

  const result = await suppliersStore.createSupplier({
    store_id: storeId,
    name: newSupplier.value.name.trim(),
    delivery_day: newSupplier.value.deliveryDay,
    frequency_days: newSupplier.value.frequencyDays,
    lead_time_days: newSupplier.value.leadTimeDays,
    is_default: false
  });

  if (result.success) {
    showSupplierModal.value = false;
    newSupplier.value = {
      name: '',
      deliveryDay: undefined,
      frequencyDays: 7,
      leadTimeDays: 1
    };
  }
};

const handleDelete = async (id: string) => {
  if (!confirm('¿Eliminar este proveedor? Esta acción no se puede deshacer.')) return;
  await suppliersStore.deleteSupplier(id);
};

const getDayName = (day?: number) => {
  if (!day) return 'No especificado';
  const days = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
  return days[day - 1] || 'N/A';
};
</script>

<template>
  <div class="flex flex-col h-screen bg-background-light dark:bg-background-dark pb-24">
    <header
      class="sticky top-0 z-30 bg-background-light/95 dark:bg-background-dark/95 backdrop-blur-sm border-b border-gray-200 dark:border-gray-800 pb-2"
    >
      <div class="flex items-center px-4 pt-4 pb-2 justify-between">
        <div class="flex items-center gap-2">
          <button
            @click="goToDashboard"
            aria-label="Volver al Dashboard"
            class="flex items-center justify-center -ml-2 p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          >
            <ArrowLeft :size="24" :stroke-width="1.5" />
          </button>
          <h2 class="text-slate-900 dark:text-white text-xl font-bold">Proveedores</h2>
        </div>
      </div>
      <div class="px-4 py-2">
           <BaseInput
             v-model="searchQuery"
             placeholder="Buscar proveedor..."
           >
             <template #prefix>
                <Search :size="18" :stroke-width="1.5" class="text-slate-400" />
             </template>
           </BaseInput>
      </div>
    </header>

    <!-- Loading State -->
    <div v-if="suppliersStore.isLoading" class="flex-1 overflow-y-auto px-4 py-4 flex flex-col gap-3">
        <div v-for="i in 4" :key="i" class="flex items-center gap-3 bg-white dark:bg-slate-800 rounded-2xl shadow-sm p-4 border-l-[6px] border-slate-200 dark:border-slate-700">
             <Skeleton width="48px" height="48px" border-radius="18px" />
             <div class="flex flex-1 flex-col justify-center min-w-0 gap-2">
                <Skeleton width="60%" height="1rem" />
                <Skeleton width="40%" height="0.75rem" />
             </div>
        </div>
    </div>

    <!-- Supplier List -->
    <main v-else-if="filteredSuppliers.length > 0" class="flex-1 overflow-y-auto px-4 py-4 flex flex-col gap-3">
      <div
        v-for="supplier in filteredSuppliers"
        :key="supplier.id"
        class="relative flex items-center gap-3 bg-white dark:bg-slate-800 rounded-2xl shadow-sm p-4 border-l-[6px] border-blue-500"
      >
        <div
          class="h-12 w-12 shrink-0 rounded-[18px] flex items-center justify-center bg-blue-100 dark:bg-blue-900/30"
        >
          <Truck :size="24" class="text-blue-600 dark:text-blue-400" />
        </div>
        <div class="flex flex-1 flex-col justify-center min-w-0">
          <p class="text-slate-900 dark:text-white text-base font-bold truncate">
            {{ supplier.name }}
            <span v-if="supplier.is_default" class="ml-2 text-xs bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400 px-2 py-0.5 rounded-full">
              Por defecto
            </span>
          </p>
          <p class="text-slate-500 text-xs font-medium">
            Frecuencia: {{ supplier.frequency_days }} días | Lead: {{ supplier.lead_time_days }} días
          </p>
          <p class="text-[10px] text-slate-400 font-medium mt-0.5" v-if="supplier.delivery_day">
            Entrega: {{ getDayName(supplier.delivery_day) }}
          </p>
        </div>
        <div class="flex gap-2" v-if="canManageSuppliers && !supplier.is_default">
          <button
            @click="handleDelete(supplier.id)"
            class="p-2 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
          >
            <Trash2 :size="18" class="text-red-500" />
          </button>
        </div>
      </div>
    </main>

    <!-- Empty State -->
    <div
      v-else
      class="flex-1 flex flex-col items-center justify-center px-4 text-center"
    >
      <Truck :size="64" :stroke-width="1" class="text-slate-300 mb-4" />
      <h3 class="text-lg font-bold text-slate-900 dark:text-white mb-2">
        {{ searchQuery ? 'No se encontraron proveedores' : 'Sin proveedores' }}
      </h3>
      <p class="text-sm text-slate-500 dark:text-slate-400 max-w-xs">
        {{
          searchQuery
            ? 'Intenta con otro término de búsqueda'
            : 'Agrega tu primer proveedor para rastrear entradas'
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

    <!-- FAB -->
    <div class="absolute bottom-24 right-4 z-40">
      <button
        v-if="canManageSuppliers"
        @click="openNewSupplier"
        class="flex h-14 w-14 items-center justify-center rounded-2xl bg-primary text-white shadow-lg hover:bg-blue-600 transition-all active:scale-90"
      >
        <Plus :size="32" :stroke-width="1.5" />
      </button>
    </div>

    <BottomNav />

    <!-- Simple Modal -->
    <div
      v-if="showSupplierModal"
      class="fixed inset-0 bg-black/50 z-50 flex items-end justify-center"
      @click.self="showSupplierModal = false"
    >
      <div class="bg-white dark:bg-slate-800 rounded-t-3xl w-full max-w-lg p-6 animate-slide-up">
        <h3 class="text-xl font-bold text-slate-900 dark:text-white mb-4">Nuevo Proveedor</h3>
        
        <div class="space-y-4">
          <BaseInput
            v-model="newSupplier.name"
            label="Nombre del Proveedor"
            placeholder="Ej: Distribuidora XYZ"
          />

          <BaseInput
            v-model.number="newSupplier.frequencyDays"
            label="Frecuencia de entrega (días)"
            type="number"
            min="1"
          />

          <BaseInput
            v-model.number="newSupplier.leadTimeDays"
            label="Tiempo de entrega (días)"
            type="number"
            min="1"
          />

          <BaseInput
            v-model.number="newSupplier.deliveryDay"
            label="Día de entrega preferido (1=Dom, 7=Sáb)"
            type="number"
            min="1"
            max="7"
            placeholder="Opcional"
          />
        </div>

        <div class="flex gap-3 mt-6">
          <BaseButton
            variant="secondary"
            @click="showSupplierModal = false"
            class="flex-1"
          >
            Cancelar
          </BaseButton>
          <BaseButton
            @click="handleSave"
            class="flex-1"
            :disabled="!newSupplier.name.trim()"
          >
            Guardar
          </BaseButton>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.animate-slide-up {
  animation: slideUp 0.3s ease-out;
}

@keyframes slideUp {
  from {
    transform: translateY(100%);
  }
  to {
    transform: translateY(0);
  }
}
</style>

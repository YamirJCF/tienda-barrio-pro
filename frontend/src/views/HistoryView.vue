<script setup lang="ts">
import { onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useHistory, type HistoryType } from '../composables/useHistory';
import HistoryItemCard from '../components/history/HistoryItemCard.vue';
import BaseButton from '../components/ui/BaseButton.vue';
import { 
  ArrowLeft, 
  ShoppingCart, 
  Landmark, 
  ShieldCheck, 
  Package, 
  Banknote, 
  Tags,
  SearchX
} from 'lucide-vue-next';

const router = useRouter();
const { items, isLoading, error, currentType, fetchHistory } = useHistory();

const filters: { label: string; value: HistoryType; component: any }[] = [
  { label: 'Ventas', value: 'sales', component: ShoppingCart },
  { label: 'Caja', value: 'cash', component: Landmark }, // Note: 'cash' fetch not fully implemented in composable yet, mapped to logic stub?
  { label: 'Auditoría', value: 'audit', component: ShieldCheck },
  { label: 'Inventario', value: 'inventory', component: Package },
  { label: 'Gastos', value: 'expenses', component: Banknote },
  { label: 'Precios', value: 'prices', component: Tags },
];

const goBack = () => {
  router.back();
};

const selectFilter = (type: HistoryType) => {
  fetchHistory(type);
};

onMounted(() => {
  fetchHistory();
});
</script>

<template>
  <div class="min-h-screen bg-slate-50 dark:bg-[#0f172a] flex flex-col">
    <!-- Header -->
    <header
      class="sticky top-0 z-30 bg-white dark:bg-[#1e293b] border-b border-slate-100 dark:border-slate-800 shadow-sm"
    >
      <div class="px-4 py-3 flex items-center gap-3">
        <BaseButton
          @click="goBack"
          variant="ghost"
          size="icon"
          class="-ml-2"
        >
          <ArrowLeft :size="24" :stroke-width="1.5" />
        </BaseButton>
        <h1 class="text-lg font-bold text-slate-900 dark:text-white">
          Historial y Auditoría
        </h1>
      </div>

      <!-- Filters Toolbar -->
      <div class="px-4 pb-3 overflow-x-auto no-scrollbar">
        <div class="flex gap-2">
          <BaseButton
            v-for="filter in filters"
            :key="filter.value"
            @click="selectFilter(filter.value)"
            :variant="currentType === filter.value ? 'primary' : 'outline'"
            size="sm"
            class="!rounded-full whitespace-nowrap"
          >
            <component :is="filter.component" :size="20" :stroke-width="1.5" class="mr-2" />
            {{ filter.label }}
          </BaseButton>
        </div>
      </div>
    </header>

    <!-- Main Content -->
    <main class="flex-1 p-4 overflow-y-auto">
      <!-- Loading State -->
      <div v-if="isLoading" class="flex flex-col items-center justify-center py-20">
        <div
          class="w-10 h-10 border-4 border-primary border-t-transparent rounded-full animate-spin"
        ></div>
        <p class="mt-4 text-sm font-medium text-slate-500">Cargando registros...</p>
      </div>

      <!-- Error State -->
      <div v-else-if="error" class="bg-red-50 dark:bg-red-900/10 p-4 rounded-xl text-center">
        <p class="text-red-600 dark:text-red-400 font-medium pb-2">{{ error }}</p>
        <BaseButton
          @click="fetchHistory(currentType)"
          variant="ghost"
          size="sm"
          class="underline font-bold text-primary"
        >
          Reintentar
        </BaseButton>
      </div>

      <!-- Empty State -->
      <div
        v-else-if="items.length === 0"
        class="flex flex-col items-center justify-center py-20 text-center opacity-60"
      >
        <div class="w-20 h-20 bg-slate-100 dark:bg-slate-800 rounded-full flex items-center justify-center mb-4">
          <SearchX :size="40" :stroke-width="1.5" class="text-slate-400" />
        </div>
        <h3 class="text-lg font-bold text-slate-700 dark:text-slate-300">
          Sin registros
        </h3>
        <p class="text-sm text-slate-500">
          No hay movimientos recientes en esta categoría.
        </p>
      </div>

      <!-- List -->
      <div v-else class="space-y-3 max-w-3xl mx-auto">
        <HistoryItemCard
          v-for="item in items"
          :key="item.id"
          :item="item"
        />
        
        <!-- Pagination / Load More Hint -->
        <div class="pt-4 text-center">
          <p class="text-xs text-slate-400">
            Mostrando {{ items.length }} registros recientes
          </p>
        </div>
      </div>
    </main>
  </div>
</template>

<style scoped>
.no-scrollbar::-webkit-scrollbar {
  display: none;
}
.no-scrollbar {
  -ms-overflow-style: none;
  scrollbar-width: none;
}
</style>

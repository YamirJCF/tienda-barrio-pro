<template>
  <div class="min-h-screen bg-gray-900 text-gray-100 pb-20">
    <!-- Header -->
    <header class="sticky top-0 z-30 bg-gray-900/95 backdrop-blur border-b border-gray-800 px-4 py-4 flex items-center justify-between">
      <div class="flex items-center gap-3">
        <button @click="router.back()" class="p-2 hover:bg-gray-800 rounded-lg transition-colors">
          <span class="material-icons text-gray-400">arrow_back</span>
        </button>
        <h1 class="text-xl font-bold text-white">Nueva Entrada</h1>
      </div>
      <div class="flex items-center gap-2">
        <span class="text-sm text-gray-400">{{ currentDate }}</span>
      </div>
    </header>

    <main class="max-w-3xl mx-auto p-4 space-y-6">
      <!-- Movement Type & Reason -->
      <section class="bg-gray-800 rounded-xl p-4 shadow-lg border border-gray-700/50 flex flex-col md:flex-row gap-4">
        <div class="flex-1 space-y-1">
          <label class="text-xs text-gray-400">Tipo de Movimiento</label>
          <div class="flex bg-gray-900 p-1 rounded-lg">
             <button 
               v-for="type in ['entrada', 'salida', 'ajuste']" 
               :key="type"
               @click="movementType = type"
               class="flex-1 py-1.5 px-3 rounded-md text-sm font-medium transition-all capitalize"
               :class="movementType === type ? getTypeColor(type) : 'text-gray-400 hover:text-white'"
             >
               {{ type }}
             </button>
          </div>
        </div>
        
        <div class="flex-1 space-y-1">
           <label class="text-xs text-gray-400">Motivo</label>
           <select 
             v-model="reason"
             class="w-full bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-white outline-none focus:ring-2 focus:ring-blue-500"
           >
             <option v-for="r in availableReasons" :key="r" :value="r">{{ r }}</option>
           </select>
        </div>
      </section>

      <!-- Supplier Section (Only for Entry) -->
      <section v-if="movementType === 'entrada'" class="bg-gray-800 rounded-xl p-4 shadow-lg border border-gray-700/50">
        <h2 class="text-sm font-semibold text-gray-400 mb-4 uppercase tracking-wider">Datos del Proveedor</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="space-y-1">
            <label class="text-xs text-gray-400">Proveedor</label>
            <input 
              v-model="supplierName"
              type="text" 
              placeholder="Ej: Distribuidora Central"
              class="w-full bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all"
            />
          </div>
          <div class="space-y-1">
            <label class="text-xs text-gray-400">Ref. Factura</label>
            <input 
              v-model="invoiceRef"
              type="text" 
              placeholder="Ej: FAC-2024-001"
              class="w-full bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none transition-all"
            />
          </div>
        </div>

        <!-- Payment Toggle -->
        <div class="mt-4 flex bg-gray-900 p-1 rounded-lg">
          <button 
            v-for="type in ['contado', 'credito']" 
            :key="type"
            @click="paymentType = type"
            class="flex-1 py-1.5 px-3 rounded-md text-sm font-medium transition-all capitalize"
            :class="paymentType === type ? 'bg-blue-600 text-white shadow-sm' : 'text-gray-400 hover:text-white'"
          >
            {{ type }}
          </button>
        </div>
      </section>

      <!-- Items List -->
      <section class="space-y-3">
         <div v-if="entryItems.length === 0" class="text-center py-10 opacity-50">
           <span class="material-icons text-4xl mb-2">playlist_add</span>
           <p>Busca productos abajo para agregarlos</p>
         </div>

         <div 
           v-for="(item, index) in entryItems" 
           :key="item.productId"
           class="bg-gray-800 rounded-xl p-3 shadow-sm border border-gray-700 flex flex-col gap-3 relative overflow-hidden group"
         >
            <div class="flex justify-between items-start">
              <div>
                <h3 class="font-medium text-white">{{ item.productName }}</h3>
                <p class="text-xs text-gray-400">{{ item.measurementUnit }}</p>
              </div>
              <button @click="removeItem(index)" class="text-gray-500 hover:text-red-400 p-1">
                <span class="material-icons text-sm">close</span>
              </button>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-3 items-end">
              <div class="space-y-1">
                <label class="text-[10px] text-gray-400 uppercase">Cantidad</label>
                <div class="relative">
                  <input 
                    v-model.number="item.quantity"
                    type="number" 
                    min="0"
                    step="0.01"
                    class="w-full bg-gray-900 border border-gray-700 rounded-lg px-2 py-1.5 text-right text-white font-mono focus:ring-1 focus:ring-blue-500 outline-none"
                  />
                </div>
              </div>
              
              <div class="space-y-1">
                 <label class="text-[10px] text-gray-400 uppercase">Vencimiento</label>
                 <input 
                   v-model="item.expirationDate"
                   type="date"
                   class="w-full bg-gray-900 border border-gray-700 rounded-lg px-2 py-1.5 text-white text-sm focus:ring-1 focus:ring-blue-500 outline-none"
                 />
              </div>

              <!-- Cost visible only for Entry -->
              <div v-if="movementType === 'entrada'" class="space-y-1">
                <label class="text-[10px] text-gray-400 uppercase">Costo Unit.</label>
                <div class="relative">
                  <span class="absolute left-2 top-1.5 text-gray-500 text-xs">$</span>
                  <input 
                    v-model.number="item.unitCost"
                    type="number" 
                    min="0"
                    step="50"
                    class="w-full bg-gray-900 border border-gray-700 rounded-lg pl-5 pr-2 py-1.5 text-right text-white font-mono focus:ring-1 focus:ring-blue-500 outline-none"
                  />
                </div>
              </div>
            </div>

            
            <div class="text-right text-xs font-mono text-emerald-400 pt-2 border-t border-gray-700/50">
              Subtotal: {{ formatCurrency(item.quantity * item.unitCost) }}
            </div>
         </div>
      </section>
    </main>

    <!-- Footer Search & Actions -->
    <div class="fixed bottom-0 left-0 right-0 bg-gray-900/95 backdrop-blur border-t border-gray-800 p-3 pb-6 z-40">
       <div class="max-w-3xl mx-auto space-y-3">
          <!-- Total -->
          <div class="flex justify-between items-end px-2">
            <div class="text-xs text-gray-400">
              {{ entryItems.length }} items
            </div>
            <div class="text-right">
              <div class="text-xs text-gray-400 mb-0.5">Total Entrada</div>
              <div class="text-2xl font-bold text-white font-mono leading-none">
                {{ formatCurrency(totalInvoice) }}
              </div>
            </div>
          </div>

          <!-- Search Input -->
          <div class="relative">
             <span class="material-icons absolute left-3 top-3 text-gray-500">search</span>
             <input 
               v-model="searchQuery"
               type="text" 
               placeholder="Buscar producto..."
               class="w-full bg-gray-800 border-none rounded-xl py-3 pl-10 pr-4 text-white placeholder-gray-500 focus:ring-2 focus:ring-blue-600 outline-none shadow-lg"
               @input="handleSearch"
             />
             
             <!-- Dropdown Results -->
             <div 
               v-if="searchResults.length > 0 && searchQuery"
               class="absolute bottom-full left-0 right-0 mb-2 bg-gray-800 rounded-xl border border-gray-700 shadow-2xl max-h-60 overflow-y-auto"
             >
               <div 
                 v-for="product in searchResults" 
                 :key="product.id"
                 @click="addItem(product)"
                 class="p-3 border-b border-gray-700 last:border-0 hover:bg-gray-700 cursor-pointer flex justify-between items-center"
               >
                 <div>
                   <div class="font-medium text-white">{{ product.name }}</div>
                   <div class="text-xs text-gray-400">{{ product.plu }} • {{ product.brand }}</div>
                 </div>
                 <div class="text-xs bg-gray-900 px-2 py-1 rounded text-gray-300">
                   Stock: {{ product.stock }}
                 </div>
               </div>
             </div>
          </div>

          <!-- Main Actions -->
          <button 
            @click="saveEntry"
            :disabled="entryItems.length === 0 || isSaving"
            class="w-full bg-blue-600 hover:bg-blue-500 disabled:bg-gray-800 disabled:text-gray-500 text-white font-bold py-3 rounded-xl shadow-lg transition-all flex items-center justify-center gap-2"
          >
            <span v-if="isSaving" class="animate-spin material-icons text-sm">refresh</span>
            <span v-else class="material-icons text-sm">save</span>
            <span>GUARDAR ENTRADA</span>
          </button>
       </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useInventoryStore } from '../stores/inventory';
import { Decimal } from 'decimal.js';
import type { Product } from '../types';

const router = useRouter();
const inventoryStore = useInventoryStore();

// State
const supplierName = ref('');
const invoiceRef = ref('');
const paymentType = ref('contado');
const movementType = ref('entrada');
const reason = ref('Compra');
const searchQuery = ref('');
const searchResults = ref<Product[]>([]);
const isSaving = ref(false);

interface EntryItem {
    productId: string;
    productName: string;
    quantity: number;
    unitCost: number;
    measurementUnit: string;
    expirationDate?: string;
}

const entryItems = ref<EntryItem[]>([]);

// Computed
const currentDate = computed(() => new Date().toLocaleDateString('es-CO', { 
  weekday: 'long', 
  year: 'numeric', 
  month: 'long', 
  day: 'numeric' 
}));

const totalInvoice = computed(() => {
  return entryItems.value.reduce((sum, item) => sum + (item.quantity * item.unitCost), 0);
});

const availableReasons = computed(() => {
  switch(movementType.value) {
    case 'entrada': return ['Compra', 'Devolución Cliente', 'Ajuste Positivo'];
    case 'salida': return ['Devolución Proveedor', 'Pérdida/Merma', 'Consumo Interno', 'Ajuste Negativo'];
    case 'ajuste': return ['Inventario Físico'];
    default: return [];
  }
});

// Watch for type change to reset reason
import { watch } from 'vue';
watch(movementType, (newVal) => {
  if (availableReasons.value.length > 0) {
    reason.value = availableReasons.value[0];
  }
});

// Methods
const getTypeColor = (type: string) => {
  switch(type) {
    case 'entrada': return 'bg-emerald-600 text-white shadow-sm';
    case 'salida': return 'bg-rose-600 text-white shadow-sm';
    case 'ajuste': return 'bg-amber-600 text-white shadow-sm';
    default: return 'bg-gray-700';
  }
};

const handleSearch = () => {
  if (!searchQuery.value) {
    searchResults.value = [];
    return;
  }
  searchResults.value = inventoryStore.searchProducts(searchQuery.value);
};

const addItem = (product: Product) => {
  const existing = entryItems.value.find(i => i.productId === product.id);
  if (existing) {
    searchQuery.value = '';
    searchResults.value = [];
    return;
  }

  // Cost default: if entry, use cost. if exit, use average cost (logic to be refined, but for now cost)
  entryItems.value.push({
    productId: product.id,
    productName: product.name,
    quantity: 1,
    unitCost: product.cost ? new Decimal(product.cost).toNumber() : 0,
    measurementUnit: product.measurementUnit,
    expirationDate: ''
  });

  // Reset search
  searchQuery.value = '';
  searchResults.value = [];
};

const removeItem = (index: number) => {
  entryItems.value.splice(index, 1);
};

const formatCurrency = (amount: number) => {
  return new Intl.NumberFormat('es-CO', { 
    style: 'currency', 
    currency: 'COP',
    maximumFractionDigits: 0 
  }).format(amount);
};

const saveEntry = async () => {
  if (entryItems.value.length === 0) return;
  
  isSaving.value = true;
  
  // Procesar cada item
  // En fase 2 real, haríamos un batch update o una transacción
  // Por ahora iteramos updateStock
  let successCount = 0;

  for (const item of entryItems.value) {
    const qty = new Decimal(item.quantity);
    if (qty.gt(0)) {
        // T1.2: Register logical movement
        const result = await inventoryStore.registerStockMovement({
          productId: item.productId,
          type: movementType.value as any, // Cast to match store type
          quantity: qty,
          reason: reason.value,
          expirationDate: item.expirationDate
        });
        
        if (result.success) successCount++;
    }
  }

  isSaving.value = false;
  
  if (successCount > 0) {
    // Notificación simple (podría usar toastStore)
    alert(`Entrada guardada exitosamente. ${successCount} productos actualizados.`);
    router.push('/inventory');
  } else {
    alert('Hubo errores al guardar algunos productos.');
  }
};
</script>

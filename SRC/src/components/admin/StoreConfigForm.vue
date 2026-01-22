<script setup lang="ts">
import { ref, computed } from 'vue';
import { useConfigStore } from '../../stores/configStore';
import BaseInput from '../ui/BaseInput.vue';
import BaseButton from '../ui/BaseButton.vue';

const configStore = useConfigStore();

// Local state linked to store (to avoid mutation warnings if using v-model direct on store props in strict mode, 
// though Pinia allows it. We'll bind directly for simplicity or use a local reactive object if needed. 
// For "Discard Changes" feature, local copy is better. Let's use direct binding for instant preview effect as requested in UX).

// Helper for file upload
const fileInput = ref<HTMLInputElement | null>(null);

const triggerFileUpload = () => {
  fileInput.value?.click();
};

const handleLogoUpload = async (event: Event) => {
  const target = event.target as HTMLInputElement;
  if (target.files && target.files[0]) {
    const file = target.files[0];
    if (file.size > 1024 * 1024) { // 1MB limit check
      alert('La imagen es muy pesada (Max 1MB)');
      return;
    }
    await configStore.setLogoFromFile(file);
  }
};

const removeLogo = () => {
  configStore.updateConfig({ logoUrl: null });
};

// Computed for Ticket Preview
const currentDate = new Date().toLocaleString();
</script>

<template>
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 h-full">
    <!-- Left Column: Form -->
    <div class="flex flex-col gap-6">
      
      <!-- Card: Identidad -->
      <div class="bg-white dark:bg-slate-800 rounded-xl p-5 shadow-sm border border-slate-100 dark:border-slate-700">
        <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-4 flex items-center gap-2">
          <span class="material-symbols-outlined text-primary">branding_watermark</span>
          Identidad Visual
        </h3>
        
        <div class="flex items-start gap-4 mb-6">
          <div 
            class="relative h-24 w-24 rounded-lg border-2 border-dashed border-slate-300 dark:border-slate-600 flex items-center justify-center overflow-hidden bg-slate-50 dark:bg-slate-900 cursor-pointer hover:border-primary transition-colors group"
            @click="triggerFileUpload"
          >
            <img v-if="configStore.logoUrl" :src="configStore.logoUrl" alt="Logo" class="h-full w-full object-contain" />
            <div v-else class="text-center p-2">
              <span class="material-symbols-outlined text-slate-400 group-hover:text-primary">add_photo_alternate</span>
              <p class="text-[10px] text-slate-500 leading-tight mt-1">Click para subir</p>
            </div>
            <input ref="fileInput" type="file" accept="image/*" class="hidden" @change="handleLogoUpload" />
          </div>
          
          <div class="flex-1 flex flex-col justify-center h-24 gap-2">
            <h4 class="text-sm font-semibold text-slate-700 dark:text-slate-200">Logo de la Tienda</h4>
            <p class="text-xs text-slate-500 dark:text-slate-400">Recomendado: 200x200px. Formatos: PNG, JPG.</p>
            <button 
              v-if="configStore.logoUrl" 
              @click="removeLogo"
              class="text-xs text-red-500 hover:text-red-600 font-medium flex items-center gap-1 self-start"
            >
              <span class="material-symbols-outlined text-[14px]">delete</span> Eliminar Logo
            </button>
          </div>
        </div>

        <div class="space-y-4">
          <BaseInput
            label="Nombre de la Tienda"
            v-model="configStore.storeName"
            placeholder="Ej: Tienda Don Pepe"
          />
        </div>
      </div>

      <!-- Card: Datos Fiscales -->
      <div class="bg-white dark:bg-slate-800 rounded-xl p-5 shadow-sm border border-slate-100 dark:border-slate-700">
        <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-4 flex items-center gap-2">
          <span class="material-symbols-outlined text-blue-500">receipt_long</span>
          Datos Fiscales & Contacto
        </h3>
        
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
          <BaseInput
            label="NIT / Cédula"
            v-model="configStore.documentId"
            placeholder="Ej: 900.123.456-7"
          />
          <div class="flex flex-col gap-1">
            <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Régimen</label>
            <select 
              v-model="configStore.regime"
              class="w-full h-10 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all dark:text-white"
            >
              <option value="No Responsable">No Responsable de IVA</option>
              <option value="Simplificado">Régimen Simplificado</option>
              <option value="Común">Régimen Común</option>
            </select>
          </div>
        </div>

        <BaseInput
          label="Dirección / Teléfono"
          v-model="configStore.contactInfo"
          placeholder="Ej: Calle 123 # 45-67 - Cel: 300 123 4567"
        />
      </div>

      <!-- Card: Ticket -->
      <div class="bg-white dark:bg-slate-800 rounded-xl p-5 shadow-sm border border-slate-100 dark:border-slate-700">
        <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-4 flex items-center gap-2">
          <span class="material-symbols-outlined text-purple-500">settings_applications</span>
          Personalización del Ticket
        </h3>
        
        <div class="flex flex-col gap-1 mb-4">
          <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Mensaje Final (Pie de Página)</label>
          <textarea 
            v-model="configStore.ticketFooter"
            rows="3"
            class="w-full rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 p-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all dark:text-white resize-none"
            placeholder="Mensaje de agradecimiento..."
          ></textarea>
        </div>

        <div class="flex flex-col gap-1">
          <label class="text-sm font-medium text-slate-700 dark:text-slate-300">Moneda Principal</label>
           <select 
              v-model="configStore.currency"
              class="w-full h-10 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all dark:text-white"
            >
              <option value="COP">Peso Colombiano (COP)</option>
              <option value="USD">Dólar Americano (USD)</option>
            </select>
        </div>
      </div>

    </div>

    <!-- Right Column: Preview -->
    <div class="flex flex-col">
      <div class="sticky top-6">
        <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 mb-4 flex items-center gap-2">
          <span class="material-symbols-outlined text-green-500">preview</span>
          Vista Previa del Ticket
        </h3>
        
        <!-- Ticket Container -->
        <div class="w-full max-w-sm mx-auto bg-white shadow-lg p-6 font-mono text-sm text-slate-800 border-t-8 border-primary relative">
           <!-- Paper Tear effect simulation (top/bottom) could be added via CSS but keeping simple -->
           
           <div class="text-center border-b-2 border-dashed border-slate-300 pb-4 mb-4">
              <div v-if="configStore.logoUrl" class="flex justify-center mb-2">
                <img :src="configStore.logoUrl" class="h-16 w-auto grayscale opacity-90" alt="Logo Ticket" />
              </div>
              <div v-else class="flex justify-center mb-2">
                 <span class="material-symbols-outlined text-4xl text-slate-400">storefront</span>
              </div>
              
              <h2 class="text-xl font-bold uppercase mb-1">{{ configStore.storeName || 'NOMBRE TIENDA' }}</h2>
              <p v-if="configStore.documentId">NIT/CC: {{ configStore.documentId }}</p>
              <p>{{ configStore.regime }}</p>
              <p class="text-xs break-words px-4">{{ configStore.contactInfo }}</p>
           </div>

           <div class="mb-4">
             <div class="flex justify-between">
               <span>FECHA:</span>
               <span>{{ currentDate }}</span>
             </div>
             <div class="flex justify-between">
               <span>TICKET #:</span>
               <span>000123</span>
             </div>
             <div class="flex justify-between">
               <span>CAJERO:</span>
               <span>Admin</span>
             </div>
           </div>

           <div class="border-b border-dashed border-slate-300 pb-2 mb-2">
             <div class="grid grid-cols-12 font-bold mb-1">
               <span class="col-span-6">DESC</span>
               <span class="col-span-2 text-right">CNT</span>
               <span class="col-span-4 text-right">TOTAL</span>
             </div>
             <!-- Mock Items -->
             <div class="grid grid-cols-12 mb-1">
               <span class="col-span-6 truncate">Leche Entera 1L</span>
               <span class="col-span-2 text-right">2</span>
               <span class="col-span-4 text-right">$9.000</span>
             </div>
             <div class="grid grid-cols-12 mb-1">
               <span class="col-span-6 truncate">Pan Tajado</span>
               <span class="col-span-2 text-right">1</span>
               <span class="col-span-4 text-right">$5.500</span>
             </div>
             <div class="grid grid-cols-12 mb-1">
               <span class="col-span-6 truncate">Huevos AA x30</span>
               <span class="col-span-2 text-right">1</span>
               <span class="col-span-4 text-right">$18.000</span>
             </div>
           </div>

           <div class="flex justify-between font-bold text-lg mb-4">
             <span>TOTAL</span>
             <span>$32.500</span>
           </div>
           
           <div class="flex justify-between text-xs mb-1">
             <span>Efectivo:</span>
             <span>$35.000</span>
           </div>
           <div class="flex justify-between text-xs mb-4">
             <span>Cambio:</span>
             <span>$2.500</span>
           </div>

           <div class="text-center pt-4 border-t-2 border-dashed border-slate-300">
             <p class="whitespace-pre-line text-sm">{{ configStore.ticketFooter }}</p>
             <p class="mt-4 text-xs text-slate-400">Software: Tienda de Barrio Pro</p>
           </div>

        </div>
        
        <p class="text-center text-xs text-slate-500 mt-4">
          * Vista preliminar aproximada. La impresión final depende de la impresora térmica.
        </p>

      </div>
    </div>
  </div>
</template>

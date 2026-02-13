<template>
  <div class="relative group">
    <!-- Traffic Light Dot -->
    <div 
      @click="handleIndicatorClick"
      class="flex items-center justify-center w-8 h-8 rounded-full transition-all duration-300 cursor-pointer hover:bg-black/5 dark:hover:bg-white/10"
      :title="statusFormatted"
    >
      <div class="relative flex h-3 w-3">
        <!-- Ping animation for active states -->
        <span 
          v-if="isSyncing || !supabaseConnected" 
          class="animate-ping absolute inline-flex h-full w-full rounded-full opacity-75"
          :class="dotColor"
        ></span>
        
        <!-- Main Dot -->
        <span 
          class="relative inline-flex rounded-full h-3 w-3 transition-colors duration-300"
          :class="dotColor"
        ></span>

        <!-- Conflict Badge (Tiny Red Dot) -->
        <span v-if="hasConflicts" class="absolute -top-1 -right-1 flex h-2 w-2">
          <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
          <span class="relative inline-flex rounded-full h-2 w-2 bg-red-500"></span>
        </span>
      </div>
    </div>

    <!-- Status Tooltip (Hover) -->
    <div class="absolute right-0 top-full mt-2 w-max max-w-xs px-3 py-1.5 bg-gray-900 text-white text-xs font-medium rounded-lg shadow-xl opacity-0 scale-95 group-hover:opacity-100 group-hover:scale-100 transition-all duration-200 pointer-events-none z-50">
      <div class="flex flex-col gap-0.5">
        <span class="font-bold">{{ statusFormatted }}</span>
        <span v-if="queueSize > 0" class="text-gray-300 text-[10px]">
          {{ queueSize }} cambios pendientes
        </span>
        <span v-if="hasConflicts" class="text-red-300 text-[10px]">
          {{ dlqSize }} errores requieren atención
        </span>
      </div>
    </div>

    <!-- Conflict Modal -->
    <ConflictResolver :is-open="showConflicts" 
                      @close="showConflicts = false" 
                      @resolved="updateQueueSize" />
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useDataSource } from '../../composables/useDataSource';
import syncQueue from '../../data/syncQueue';
import ConflictResolver from './ConflictResolver.vue';

const { supabaseConnected, isOnline } = useDataSource();
const queueSize = ref(0);
const dlqSize = ref(0);
const showConflicts = ref(false);
let interval: ReturnType<typeof setInterval> | null = null;

// Sync status derived from data source
const isSyncing = computed(() => isOnline.value && queueSize.value > 0);
const hasConflicts = computed(() => dlqSize.value > 0);

const dotColor = computed(() => {
  if (hasConflicts.value) return 'bg-red-500';
  if (!isOnline.value) return 'bg-gray-400';
  if (!supabaseConnected.value) return 'bg-amber-400';
  if (queueSize.value > 0) return 'bg-blue-500';
  return 'bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.4)]'; // Glowing green
});

const statusFormatted = computed(() => {
  if (hasConflicts.value) return 'Atención requerida';
  if (!isOnline.value) return 'Modo Offline';
  if (!supabaseConnected.value) return 'Reconectando...';
  if (queueSize.value > 0) return 'Sincronizando...';
  return 'Sistema Operativo';
});

// Poll queue size
const updateQueueSize = async () => {
    queueSize.value = await syncQueue.getQueueSize();
    dlqSize.value = await syncQueue.getDLQSize();
};

const handleIndicatorClick = () => {
  if (hasConflicts.value) {
    showConflicts.value = true;
  }
};

onMounted(() => {
    updateQueueSize();
    interval = setInterval(updateQueueSize, 2000); // Check every 2s
});

onUnmounted(() => {
    if (interval) clearInterval(interval);
});
</script>

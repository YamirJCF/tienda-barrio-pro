<template>
  <div class="flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-medium transition-colors duration-300"
       :class="statusClasses">
    
    <!-- Icon with pulse animation -->
    <div class="relative">
      <i class="material-icons text-lg">{{ statusIcon }}</i>
      <div v-if="isSyncing" class="absolute inset-0 rounded-full bg-current opacity-75 animate-ping"></div>
    </div>

    <!-- Status Text -->
    <span class="hidden sm:inline">{{ statusFormatted }}</span>

    <!-- Queue Counter -->
    <span v-if="queueSize > 0" 
          class="ml-1 px-1.5 py-0.5 rounded-full text-xs font-bold bg-white/20">
      {{ queueSize }}
    </span>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useDataSource } from '../../composables/useDataSource';
import { getQueueSize } from '../../data/syncQueue';

const { supabaseConnected, isOnline, currentSource } = useDataSource();
const queueSize = ref(0);
let interval: ReturnType<typeof setInterval> | null = null;

// Sync status derived from data source
const isSyncing = computed(() => isOnline.value && queueSize.value > 0);

const statusClasses = computed(() => {
  if (!isOnline.value) return 'bg-gray-100 text-gray-600 border border-gray-300';
  if (!supabaseConnected.value) return 'bg-amber-100 text-amber-700 border border-amber-300';
  if (queueSize.value > 0) return 'bg-blue-100 text-blue-700 border border-blue-300';
  return 'bg-green-100 text-green-700 border border-green-300';
});

const statusIcon = computed(() => {
  if (!isOnline.value) return 'cloud_off';
  if (!supabaseConnected.value) return 'cloud_queue';
  if (queueSize.value > 0) return 'sync';
  return 'cloud_done';
});

const statusFormatted = computed(() => {
  if (!isOnline.value) return 'Offline';
  if (!supabaseConnected.value) return 'Reconectando...';
  if (queueSize.value > 0) return 'Sincronizando...';
  return 'En línea';
});

// Poll queue size
const updateQueueSize = async () => {
    queueSize.value = await getQueueSize();
};

onMounted(() => {
    updateQueueSize();
    interval = setInterval(updateQueueSize, 2000); // Check every 2s
});

onUnmounted(() => {
    if (interval) clearInterval(interval);
});
</script>

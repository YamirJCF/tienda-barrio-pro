<template>
    <!-- This component is invisible but ensures network event listeners are always active -->
</template>

<script setup lang="ts">
import { onMounted, onUnmounted } from 'vue';

/**
 * Global Network Event Handler
 * This component must be mounted in App.vue to ensure network events
 * are always listened to, regardless of route changes or component lifecycle
 */

let isRegistered = false;

const handleOnline = async () => {
    console.log('🟢 [GlobalNetworkHandler] Network ONLINE event fired!');
    
    // Trigger sync queue processing
    try {
        console.log('🔄 [GlobalNetworkHandler] Importing syncQueue...');
        const { processSyncQueue } = await import('../../data/syncQueue');
        console.log('✅ [GlobalNetworkHandler] Calling processSyncQueue()...');
        processSyncQueue(); // Fire and forget
    } catch (error) {
        console.error('❌ [GlobalNetworkHandler] Failed to process sync queue:', error);
    }
};

const handleOffline = () => {
    console.log('🔴 [GlobalNetworkHandler] Network OFFLINE event fired!');
};

onMounted(() => {
    if (isRegistered) {
        console.warn('[GlobalNetworkHandler] Already registered, skipping...');
        return;
    }
    
    console.log('🎯 [GlobalNetworkHandler] Mounting global network event listeners');
    console.log(`📡 [GlobalNetworkHandler] Current navigator.onLine: ${navigator.onLine}`);
    
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);
    
    isRegistered = true;
    console.log('✅ [GlobalNetworkHandler] Event listeners registered successfully');
    
    // Process sync queue on mount if already online
    // This handles the case where user reloads page while online
    // (the 'online' event only fires on network state CHANGES, not on mount)
    if (navigator.onLine) {
        console.log('🔄 [GlobalNetworkHandler] Already online - checking sync queue on mount...');
        setTimeout(async () => {
            try {
                const { processSyncQueue } = await import('../../data/syncQueue');
                console.log('✅ [GlobalNetworkHandler] Calling processSyncQueue() from mount...');
                processSyncQueue(); // Fire and forget
            } catch (error) {
                console.error('❌ [GlobalNetworkHandler] Failed to process sync queue on mount:', error);
            }
        }, 1500); // Delay to ensure stores and auth are initialized
    }
});

onUnmounted(() => {
    console.log('🗑️ [GlobalNetworkHandler] Unmounting (this should NOT happen unless app closes)');
    window.removeEventListener('online', handleOnline);
    window.removeEventListener('offline', handleOffline);
    isRegistered = false;
});
</script>

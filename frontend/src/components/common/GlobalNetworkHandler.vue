<template>
    <div style="display: none;">
        <!-- This component is invisible but ensures network event listeners are always active -->
    </div>
</template>

<script setup lang="ts">
import { onMounted, onUnmounted } from 'vue';
import { logger } from '../../utils/logger';
import { getSupabaseClient } from '../../data/supabaseClient';
import { processSyncQueue } from '../../data/syncQueue';

/**
 * Global Network Event Handler
 * This component must be mounted in App.vue to ensure network events
 * are always listened to, regardless of route changes or component lifecycle
 */

let isRegistered = false;

const handleOnline = async () => {
    logger.log('🟢 [GlobalNetworkHandler] Network ONLINE event fired!');
    
    // Trigger sync queue processing only if authenticated
    try {
        logger.log('🔄 [GlobalNetworkHandler] Checking active session for syncQueue...');
        // Check for active session first
        const supabase = getSupabaseClient();
        if (!supabase) return;
        const { data: { session } } = await supabase.auth.getSession();
        if (!session) {
            logger.log('ℹ️ [GlobalNetworkHandler] No active session, skipping sync on reconnect.');
            return;
        }
        logger.log('✅ [GlobalNetworkHandler] Calling processSyncQueue()...');
        processSyncQueue(); // Fire and forget
    } catch (error) {
        console.error('❌ [GlobalNetworkHandler] Failed to process sync queue:', error);
    }
};

const handleOffline = () => {
    logger.log('🔴 [GlobalNetworkHandler] Network OFFLINE event fired!');
};

onMounted(() => {
    if (isRegistered) {
        console.warn('[GlobalNetworkHandler] Already registered, skipping...');
        return;
    }
    
    logger.log('🎯 [GlobalNetworkHandler] Mounting global network event listeners');
    logger.log(`📡 [GlobalNetworkHandler] Current navigator.onLine: ${navigator.onLine}`);
    
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);
    
    isRegistered = true;
    logger.log('✅ [GlobalNetworkHandler] Event listeners registered successfully');
    
    // Process sync queue on mount if already online AND user is authenticated
    // (the 'online' event only fires on network state CHANGES, not on mount)
    if (navigator.onLine) {
        logger.log('🔄 [GlobalNetworkHandler] Already online - checking sync queue on mount...');
        setTimeout(async () => {
            try {
                // Check for active session BEFORE processing queue
                const supabase = getSupabaseClient();
                if (!supabase) {
                    logger.log('ℹ️ [GlobalNetworkHandler] Supabase not configured, skipping sync queue.');
                    return;
                }
                const { data: { session } } = await supabase.auth.getSession();
                if (!session) {
                    logger.log('ℹ️ [GlobalNetworkHandler] No active session, skipping sync queue on mount.');
                    return;
                }

                logger.log('✅ [GlobalNetworkHandler] Calling processSyncQueue() from mount...');
                processSyncQueue(); // Fire and forget
            } catch (error) {
                console.error('❌ [GlobalNetworkHandler] Failed to process sync queue on mount:', error);
            }
        }, 1500); // Delay to ensure stores and auth are initialized
    }
});

onUnmounted(() => {
    logger.log('🗑️ [GlobalNetworkHandler] Unmounting (this should NOT happen unless app closes)');
    window.removeEventListener('online', handleOnline);
    window.removeEventListener('offline', handleOffline);
    isRegistered = false;
});
</script>

import { registerSW } from 'virtual:pwa-register';
import './init';

registerSW({ immediate: true });

import './index.css';
import 'vue-virtual-scroller/dist/vue-virtual-scroller.css';
import { createApp } from 'vue';
import { createPinia } from 'pinia';
import piniaPluginPersistedstate from 'pinia-plugin-persistedstate';
import VueVirtualScroller from 'vue-virtual-scroller';
import App from './App.vue';
import router from './router';

// =============================================
// Bootstrap: Async IIFE wraps the app initialization
// to allow token interception BEFORE Hash Router mounts.
// =============================================
(async () => {
    // Early Token Interception — BEFORE Hash Router processes the URL
    // Zero-cost for normal loads (module only loaded when tokens detected)
    let interceptResult: { intercepted: boolean; type?: string } | null = null;

    if (window.location.hash.includes('access_token')) {
        try {
            const { interceptAuthTokens } = await import('./utils/authTokenInterceptor');
            interceptResult = await interceptAuthTokens();
        } catch (err) {
            console.error('[Main] Token interception failed (non-fatal):', err);
        }
    }

    const pinia = createPinia();
    pinia.use(piniaPluginPersistedstate);

    const app = createApp(App);
    app.use(pinia);

    // CRITICAL: If interceptor captured auth tokens (signup/magiclink),
    // initialize the Pinia store NOW — BEFORE router mounts and guards fire.
    // This bridges the gap between Supabase session and Pinia state.
    // Without this, the router guard sees isAuthenticated=false and redirects to /login.
    if (interceptResult?.intercepted && interceptResult.type !== 'recovery') {
        const { useAuthStore } = await import('./stores/auth');
        const authStore = useAuthStore(pinia);
        const initialized = await authStore.initializeFromSession();
        console.log('[Main] Auth callback initialized:', initialized);
    }

    app.use(router);
    app.use(VueVirtualScroller);
    app.mount('#app');
})();

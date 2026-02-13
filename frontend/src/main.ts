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
    if (window.location.hash.includes('access_token')) {
        try {
            const { interceptAuthTokens } = await import('./utils/authTokenInterceptor');
            await interceptAuthTokens();
        } catch (err) {
            console.error('[Main] Token interception failed (non-fatal):', err);
        }
    }

    const pinia = createPinia();
    pinia.use(piniaPluginPersistedstate);

    const app = createApp(App);
    app.use(pinia);
    app.use(router);
    app.use(VueVirtualScroller);
    app.mount('#app');
})();

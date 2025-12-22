import './index.css'
import 'vue-virtual-scroller/dist/vue-virtual-scroller.css'
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import piniaPluginPersistedstate from 'pinia-plugin-persistedstate'
import VueVirtualScroller from 'vue-virtual-scroller'
import App from './App.vue'
import router from './router'

const pinia = createPinia()
pinia.use(piniaPluginPersistedstate)

const app = createApp(App)
app.use(pinia)
app.use(router)
app.use(VueVirtualScroller)
app.mount('#app')

import { defineStore } from 'pinia';
import { ref } from 'vue';
import { createPersistedState } from 'pinia-plugin-persistedstate';

export interface StoreConfig {
    storeName: string;
    logoUrl: string | null;
    documentId: string; // NIT or CC
    regime: string; // 'Común', 'Simplificado', 'No Responsable'
    contactInfo: string; // Address / Phone
    ticketFooter: string;
    currency: 'COP' | 'USD';
}

export const useConfigStore = defineStore(
    'config',
    () => {
        // Default State
        const storeName = ref('Mi Tienda de Barrio');
        const logoUrl = ref<string | null>(null);
        const documentId = ref('');
        const regime = ref('No Responsable');
        const contactInfo = ref('');
        const ticketFooter = ref('¡Gracias por su compra!\nVuelva pronto.');
        const currency = ref<'COP' | 'USD'>('COP');

        // Actions
        const updateConfig = (newConfig: Partial<StoreConfig>) => {
            if (newConfig.storeName !== undefined) storeName.value = newConfig.storeName;
            if (newConfig.logoUrl !== undefined) logoUrl.value = newConfig.logoUrl;
            if (newConfig.documentId !== undefined) documentId.value = newConfig.documentId;
            if (newConfig.regime !== undefined) regime.value = newConfig.regime;
            if (newConfig.contactInfo !== undefined) contactInfo.value = newConfig.contactInfo;
            if (newConfig.ticketFooter !== undefined) ticketFooter.value = newConfig.ticketFooter;
            if (newConfig.currency !== undefined) currency.value = newConfig.currency;
        };

        const resetConfig = () => {
            storeName.value = 'Mi Tienda de Barrio';
            logoUrl.value = null;
            documentId.value = '';
            regime.value = 'No Responsable';
            contactInfo.value = '';
            ticketFooter.value = '¡Gracias por su compra!\nVuelva pronto.';
            currency.value = 'COP';
        };

        // Helper to process image file to base64
        const setLogoFromFile = async (file: File) => {
            return new Promise<void>((resolve, reject) => {
                const reader = new FileReader();
                reader.onload = (e) => {
                    if (e.target?.result) {
                        logoUrl.value = e.target.result as string;
                        resolve();
                    }
                };
                reader.onerror = reject;
                reader.readAsDataURL(file);
            });
        };

        return {
            storeName,
            logoUrl,
            documentId,
            regime,
            contactInfo,
            ticketFooter,
            currency,
            updateConfig,
            resetConfig,
            setLogoFromFile,
        };
    },
    {
        persist: {
            key: 'tienda-config',
            storage: localStorage,
        },
    }
);

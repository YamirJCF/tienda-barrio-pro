/**
 * Scoped Storage - localStorage con claves aisladas por storeId
 * Permite que múltiples tiendas coexistan en el mismo dispositivo
 */

let currentStoreId: string | null = null;

/**
 * Establece el storeId actual para prefixar las claves
 */
export const setCurrentStoreId = (storeId: string | null): void => {
    currentStoreId = storeId;
    if (storeId) {
        console.log('[ScopedStorage] StoreId set:', storeId);
    }
};

/**
 * Obtiene el storeId actual
 */
export const getCurrentStoreId = (): string | null => currentStoreId;

/**
 * Genera la clave con scope del storeId
 */
const getScopedKey = (key: string): string => {
    if (!currentStoreId) {
        return key;
    }
    return `tienda-${currentStoreId}-${key}`;
};

/**
 * Storage adapter que prefija las claves con el storeId actual
 * Compatible con la interfaz Storage de localStorage
 */
export const scopedStorage: Storage = {
    get length() {
        return localStorage.length;
    },

    key(index: number) {
        return localStorage.key(index);
    },

    getItem(key: string) {
        const scopedKey = getScopedKey(key);
        return localStorage.getItem(scopedKey);
    },

    setItem(key: string, value: string) {
        const scopedKey = getScopedKey(key);
        localStorage.setItem(scopedKey, value);
    },

    removeItem(key: string) {
        const scopedKey = getScopedKey(key);
        localStorage.removeItem(scopedKey);
    },

    clear() {
        // Solo limpiar claves del storeId actual
        if (!currentStoreId) {
            console.warn('[ScopedStorage] Cannot clear without storeId');
            return;
        }

        const prefix = `tienda-${currentStoreId}-`;
        const keysToRemove: string[] = [];

        for (let i = 0; i < localStorage.length; i++) {
            const key = localStorage.key(i);
            if (key?.startsWith(prefix)) {
                keysToRemove.push(key);
            }
        }

        keysToRemove.forEach(k => localStorage.removeItem(k));
        console.log('[ScopedStorage] Cleared', keysToRemove.length, 'keys for store:', currentStoreId);
    }
};

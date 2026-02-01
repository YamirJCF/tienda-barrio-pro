import type { StorageAdapter } from './types';

/**
 * LocalStorage adapter implementing StorageAdapter interface.
 * This is the default storage backend for the application.
 */
const getPrefixedKey = (key: string): string => {
  return `${prefix}${key}`;
};

let prefix = '';

export const localStorageAdapter: StorageAdapter & { setPrefix: (p: string) => void } = {
  setPrefix(p: string) {
    prefix = p;
  },

  get<T>(key: string): T | null {
    try {
      const item = localStorage.getItem(getPrefixedKey(key));
      return item ? JSON.parse(item) : null;
    } catch (error) {
      console.error(`[LocalStorage] Error reading key "${getPrefixedKey(key)}":`, error);
      return null;
    }
  },

  set<T>(key: string, value: T): void {
    try {
      localStorage.setItem(getPrefixedKey(key), JSON.stringify(value));
    } catch (error) {
      console.error(`[LocalStorage] Error writing key "${getPrefixedKey(key)}":`, error);
    }
  },

  remove(key: string): void {
    try {
      localStorage.removeItem(getPrefixedKey(key));
    } catch (error) {
      console.error(`[LocalStorage] Error removing key "${getPrefixedKey(key)}":`, error);
    }
  },

  clear(): void {
    try {
      // Only clear items with current prefix to avoid wiping everything if we are scoped
      // But 'clear' usually implies wiping the store.
      // If we are in audit mode (prefix='audit-'), we only wipe audit keys?
      // Standard localStorage.clear() wipes EVERYTHING.
      // Let's implement smart clear.
      if (prefix) {
        Object.keys(localStorage).forEach(k => {
          if (k.startsWith(prefix)) {
            localStorage.removeItem(k);
          }
        });
      } else {
        localStorage.clear();
      }
    } catch (error) {
      console.error('[LocalStorage] Error clearing storage:', error);
    }
  },
};

/**
 * Factory to get the current storage adapter.
 * In the future, this can be configured to return different adapters.
 */
export const getStorageAdapter = (): StorageAdapter => {
  return localStorageAdapter;
};

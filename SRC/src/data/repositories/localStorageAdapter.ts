import type { StorageAdapter } from './types';

/**
 * LocalStorage adapter implementing StorageAdapter interface.
 * This is the default storage backend for the application.
 */
export const localStorageAdapter: StorageAdapter = {
  get<T>(key: string): T | null {
    try {
      const item = localStorage.getItem(key);
      return item ? JSON.parse(item) : null;
    } catch (error) {
      console.error(`[LocalStorage] Error reading key "${key}":`, error);
      return null;
    }
  },

  set<T>(key: string, value: T): void {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch (error) {
      console.error(`[LocalStorage] Error writing key "${key}":`, error);
    }
  },

  remove(key: string): void {
    try {
      localStorage.removeItem(key);
    } catch (error) {
      console.error(`[LocalStorage] Error removing key "${key}":`, error);
    }
  },

  clear(): void {
    try {
      localStorage.clear();
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

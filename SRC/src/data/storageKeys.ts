/**
 * Storage Keys - Centralized localStorage key constants
 * All localStorage keys used in the application
 */

export const STORAGE_KEYS = {
  // Core stores
  CART: 'tienda-cart',
  INVENTORY: 'tienda-inventory',
  SALES: 'tienda-sales',

  // App state
  STORE_STATUS: 'tienda-store-status',

  // User preferences
  THEME: 'tienda-theme',
  LAST_SYNC: 'tienda-last-sync',
} as const;

export type StorageKey = (typeof STORAGE_KEYS)[keyof typeof STORAGE_KEYS];

// Get all storage keys as array
export const getAllStorageKeys = (): string[] => Object.values(STORAGE_KEYS);

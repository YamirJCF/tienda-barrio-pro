/**
 * Data Layer - Centralized exports
 * Import everything data-related from here
 */

// Storage keys
export { STORAGE_KEYS, getAllStorageKeys } from './storageKeys';
export type { StorageKey } from './storageKeys';

// Sample data
export { SAMPLE_PRODUCTS, CATEGORIES, PAYMENT_METHODS } from './sampleData';
export type { SampleProduct } from './sampleData';

// Storage utilities
export {
    getStorageSize,
    formatBytes,
    clearStore,
    clearAllData,
    exportData,
    downloadData,
    importData,
    debugLogAllData,
    hasData,
    getDataSummary,
} from './storageUtils';
export type { StorageSnapshot } from './storageUtils';

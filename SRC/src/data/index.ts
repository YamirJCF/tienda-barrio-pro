/**
 * Data Layer - Centralized exports
 * Import everything data-related from here
 */

// Storage keys
export { STORAGE_KEYS, getAllStorageKeys } from './storageKeys';
export type { StorageKey } from './storageKeys';

// WO-003: sampleData exports eliminados - SPEC-007

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

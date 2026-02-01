/**
 * Storage Utilities - localStorage management functions
 * Clear, export, import, and debug utilities
 */

import { STORAGE_KEYS, getAllStorageKeys } from './storageKeys';
import { logger } from '../utils/logger';

export interface StorageSnapshot {
  timestamp: string;
  version: string;
  data: Record<string, any>;
}

/**
 * Get the current size of all localStorage data in bytes
 */
export const getStorageSize = (): { total: number; byKey: Record<string, number> } => {
  const byKey: Record<string, number> = {};
  let total = 0;

  getAllStorageKeys().forEach((key) => {
    const item = localStorage.getItem(key);
    if (item) {
      const size = new Blob([item]).size;
      byKey[key] = size;
      total += size;
    }
  });

  return { total, byKey };
};

/**
 * Format bytes to human readable string
 */
export const formatBytes = (bytes: number): string => {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
};

/**
 * Clear specific store data
 */
export const clearStore = (key: string): void => {
  localStorage.removeItem(key);
  logger.log(`[Storage] Cleared: ${key}`);
};

/**
 * Clear all application data
 */
export const clearAllData = (): void => {
  getAllStorageKeys().forEach((key) => {
    localStorage.removeItem(key);
  });
  logger.log('[Storage] All data cleared');
};

/**
 * Export all data as JSON snapshot
 */
export const exportData = (): StorageSnapshot => {
  const data: Record<string, any> = {};

  getAllStorageKeys().forEach((key) => {
    const item = localStorage.getItem(key);
    if (item) {
      try {
        data[key] = JSON.parse(item);
      } catch {
        data[key] = item;
      }
    }
  });

  const snapshot: StorageSnapshot = {
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    data,
  };

  logger.log('[Storage] Data exported:', snapshot);
  return snapshot;
};

/**
 * Download data as JSON file
 */
export const downloadData = (filename?: string): void => {
  const snapshot = exportData();
  const blob = new Blob([JSON.stringify(snapshot, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename || `tienda-backup-${new Date().toISOString().split('T')[0]}.json`;
  a.click();
  URL.revokeObjectURL(url);
};

/**
 * Import data from snapshot
 */
export const importData = (snapshot: StorageSnapshot): boolean => {
  try {
    Object.entries(snapshot.data).forEach(([key, value]) => {
      const stringValue = typeof value === 'string' ? value : JSON.stringify(value);
      localStorage.setItem(key, stringValue);
    });
    logger.log('[Storage] Data imported successfully');
    return true;
  } catch (error) {
    console.error('[Storage] Import failed:', error);
    return false;
  }
};

/**
 * Debug: Log all stored data
 */
export const debugLogAllData = (): void => {
  // Solo ejecutar en desarrollo
  if (!import.meta.env.DEV) return;

  console.group('[Storage Debug] Current Data');
  logger.log('Size:', formatBytes(getStorageSize().total));

  getAllStorageKeys().forEach((key) => {
    const item = localStorage.getItem(key);
    if (item) {
      try {
        logger.log(`${key}:`, JSON.parse(item));
      } catch {
        logger.log(`${key}:`, item);
      }
    } else {
      logger.log(`${key}: (empty)`);
    }
  });

  console.groupEnd();
};

/**
 * Check if data exists
 */
export const hasData = (): boolean => {
  return getAllStorageKeys().some((key) => localStorage.getItem(key) !== null);
};

/**
 * Get summary of stored data
 */
export const getDataSummary = (): {
  hasCart: boolean;
  hasInventory: boolean;
  hasSales: boolean;
  totalSize: string;
} => {
  const size = getStorageSize();
  return {
    hasCart: localStorage.getItem(STORAGE_KEYS.CART) !== null,
    hasInventory: localStorage.getItem(STORAGE_KEYS.INVENTORY) !== null,
    hasSales: localStorage.getItem(STORAGE_KEYS.SALES) !== null,
    totalSize: formatBytes(size.total),
  };
};

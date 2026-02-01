import { isAuditMode } from '../data/supabaseClient';

export const getStorageKey = (baseKey: string): string => {
    if (isAuditMode()) {
        return `audit-${baseKey}`;
    }
    return baseKey;
};

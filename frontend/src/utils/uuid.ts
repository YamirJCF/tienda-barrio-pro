/**
 * UUID Generator Utility
 * WO-001: Provides UUID generation for all entities
 * 
 * @module utils/uuid
 */

/**
 * Generate a UUID v4 compatible string
 * Uses crypto.randomUUID() if available, fallback for older browsers
 */
export const generateUUID = (): string => {
    // Modern browsers have crypto.randomUUID()
    if (typeof crypto !== 'undefined' && crypto.randomUUID) {
        return crypto.randomUUID();
    }

    // Fallback for older browsers
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
};

/**
 * Validate if a string is a valid UUID format
 */
export const isValidUUID = (id: string): boolean => {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    return uuidRegex.test(id);
};

export default generateUUID;

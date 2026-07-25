/**
 * WebCrypto Core Utility Module
 * Implements AES-GCM encryption with PBKDF2 key derivation using unique store salt.
 * 
 * @module utils/crypto
 */

const ENCRYPTION_ALGORITHM = 'AES-GCM';
const PBKDF2_ITERATIONS = 100000;

/**
 * Derives a non-extractable 256-bit AES-GCM CryptoKey from a user PIN and unique store salt using PBKDF2.
 * 
 * @param pin - The user/store PIN string
 * @param storeSalt - The unique salt associated with the store from Supabase
 * @returns Promise<CryptoKey> Non-extractable key for in-memory operations
 */
export async function deriveKeyFromPin(pin: string, storeSalt: string): Promise<CryptoKey> {
    if (!pin || pin.trim().length === 0) {
        throw new Error('PIN cannot be empty');
    }
    if (!storeSalt || storeSalt.trim().length === 0) {
        throw new Error('Store salt cannot be empty');
    }

    const encoder = new TextEncoder();
    const pinBuffer = encoder.encode(pin);
    const saltBuffer = encoder.encode(storeSalt);

    // Import raw PIN as key material
    const keyMaterial = await window.crypto.subtle.importKey(
        'raw',
        pinBuffer,
        { name: 'PBKDF2' },
        false,
        ['deriveBits', 'deriveKey']
    );

    // Derive AES-GCM 256-bit key
    return window.crypto.subtle.deriveKey(
        {
            name: 'PBKDF2',
            salt: saltBuffer,
            iterations: PBKDF2_ITERATIONS,
            hash: 'SHA-256',
        },
        keyMaterial,
        { name: ENCRYPTION_ALGORITHM, length: 256 },
        false, // Crucial: non-extractable (RAM only)
        ['encrypt', 'decrypt']
    );
}

/**
 * Encrypts a JSON-serializable object using AES-GCM with a random 12-byte Initialization Vector (IV).
 * 
 * @param data - The JavaScript object/data to encrypt
 * @param key - The AES-GCM CryptoKey
 * @returns Promise containing cipherText ArrayBuffer and iv Uint8Array
 */
export async function encryptData(
    data: object | unknown,
    key: CryptoKey
): Promise<{ cipherText: ArrayBuffer; iv: Uint8Array }> {
    if (!key) {
        throw new Error('CryptoKey is required for encryption');
    }

    const iv = window.crypto.getRandomValues(new Uint8Array(12));
    const encoder = new TextEncoder();
    const jsonString = JSON.stringify(data);
    const encodedData = encoder.encode(jsonString);

    const cipherText = await window.crypto.subtle.encrypt(
        { name: ENCRYPTION_ALGORITHM, iv },
        key,
        encodedData
    );

    return { cipherText, iv };
}

/**
 * Decrypts an AES-GCM encrypted ArrayBuffer back into a parsed JavaScript object.
 * 
 * @param cipherText - The encrypted ArrayBuffer
 * @param iv - The 12-byte Initialization Vector used during encryption
 * @param key - The AES-GCM CryptoKey
 * @returns Promise containing the parsed JavaScript object
 */
export async function decryptData(
    cipherText: ArrayBuffer,
    iv: Uint8Array,
    key: CryptoKey
): Promise<any> {
    if (!key) {
        throw new Error('CryptoKey is required for decryption');
    }
    if (!iv || iv.length !== 12) {
        throw new Error('Valid 12-byte IV is required for decryption');
    }

    const decryptedBuffer = await window.crypto.subtle.decrypt(
        { name: ENCRYPTION_ALGORITHM, iv },
        key,
        cipherText
    );

    const decoder = new TextDecoder();
    const jsonString = decoder.decode(decryptedBuffer);
    return JSON.parse(jsonString);
}

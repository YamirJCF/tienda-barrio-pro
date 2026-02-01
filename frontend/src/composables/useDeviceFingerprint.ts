/**
 * useDeviceFingerprint.ts
 *
 * SPEC-005: Generación de huella digital del dispositivo
 * Algoritmo: SHA-256(userAgent + screen + timezone + language)
 * Sin dependencias externas.
 */

import { ref, readonly } from 'vue';
import { logger } from '../utils/logger';

// Cache del fingerprint para evitar recálculos
const cachedFingerprint = ref<string | null>(null);
const isGenerating = ref(false);

/**
 * Genera un hash SHA-256 de los datos de identificación del dispositivo.
 * Determinista: mismo dispositivo = mismo hash.
 */
async function generateFingerprint(): Promise<string> {
  const data = [
    navigator.userAgent,
    `${screen.width}x${screen.height}x${screen.colorDepth}`,
    Intl.DateTimeFormat().resolvedOptions().timeZone,
    navigator.language,
    new Date().getTimezoneOffset().toString(),
  ].join('|');

  // Usar Web Crypto API para SHA-256
  const encoder = new TextEncoder();
  const dataBuffer = encoder.encode(data);
  const hashBuffer = await crypto.subtle.digest('SHA-256', dataBuffer);

  // Convertir a hex string
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');

  return hashHex;
}

/**
 * Composable para obtener el fingerprint del dispositivo.
 * El fingerprint se genera una sola vez y se cachea.
 */
export function useDeviceFingerprint() {
  const getFingerprint = async (): Promise<string> => {
    // Retornar cache si existe
    if (cachedFingerprint.value) {
      return cachedFingerprint.value;
    }

    // Evitar generaciones paralelas
    if (isGenerating.value) {
      // Esperar a que termine la generación actual
      await new Promise((resolve) => {
        const interval = setInterval(() => {
          if (cachedFingerprint.value) {
            clearInterval(interval);
            resolve(cachedFingerprint.value);
          }
        }, 50);
      });
      return cachedFingerprint.value!;
    }

    isGenerating.value = true;

    try {
      cachedFingerprint.value = await generateFingerprint();
      logger.log('[Fingerprint] Generated:', cachedFingerprint.value.substring(0, 16) + '...');
      return cachedFingerprint.value;
    } finally {
      isGenerating.value = false;
    }
  };

  // Versión resumida para mostrar en UI (primeros 8 caracteres)
  const getShortFingerprint = async (): Promise<string> => {
    const full = await getFingerprint();
    return full.substring(0, 8);
  };

  return {
    fingerprint: readonly(cachedFingerprint),
    isGenerating: readonly(isGenerating),
    getFingerprint,
    getShortFingerprint,
  };
}

export default useDeviceFingerprint;

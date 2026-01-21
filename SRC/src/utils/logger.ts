/**
 * Logger condicional para desarrollo
 * Solo imprime en modo DEV, silenciado en producción
 *
 * @module utils/logger
 * @security Resuelve QA Riesgo #1 - Exposición de datos sensibles
 */

const isDev = import.meta.env.DEV;

export const logger = {
  /**
   * Log informativo - Solo en desarrollo
   */
  log: (...args: unknown[]): void => {
    if (isDev) {
      console.log(...args);
    }
  },

  /**
   * Warning - Solo en desarrollo
   */
  warn: (...args: unknown[]): void => {
    if (isDev) {
      console.warn(...args);
    }
  },

  /**
   * Error - Siempre ejecuta (errores son críticos)
   */
  error: (...args: unknown[]): void => {
    console.error(...args);
  },
};

export default logger;

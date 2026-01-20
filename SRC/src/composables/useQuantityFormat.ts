import { Decimal } from 'decimal.js';

/**
 * Composable para formato estandarizado de cantidades en toda la aplicación.
 * 
 * Estándar de Decimales UX:
 * - Dinero ($): 0 decimales (siempre entero)
 * - Stock (un): 0 decimales (unidades siempre enteras)
 * - Stock (kg/lb): 2 decimales máximo
 * - Stock (g): 0 decimales (gramos siempre enteros)
 */
export const useQuantityFormat = () => {
    /**
     * Formatea una cantidad de stock según su unidad de medida.
     * @param value - Valor numérico o Decimal
     * @param unit - Unidad de medida ('un', 'kg', 'lb', 'g')
     * @returns String formateado
     */
    const formatStock = (value: Decimal | number | string, unit: string = 'un'): string => {
        let num: number;

        if (value instanceof Decimal) {
            num = value.toNumber();
        } else if (typeof value === 'string') {
            num = parseFloat(value) || 0;
        } else {
            num = Number(value) || 0;
        }

        switch (unit) {
            case 'un':
            case 'g':
                // Unidades y gramos siempre enteros
                return Math.round(num).toString();
            case 'kg':
            case 'lb':
                // Kg y lb con máximo 2 decimales, sin trailing zeros
                const rounded = Math.round(num * 100) / 100;
                return Number.isInteger(rounded) ? rounded.toString() : rounded.toFixed(2);
            default:
                // Default: 2 decimales si tiene decimales, entero si no
                return Number.isInteger(num) ? num.toString() : num.toFixed(2);
        }
    };

    /**
     * Formatea una cantidad genérica (para carrito, historial, etc.)
     * @param value - Valor numérico o Decimal
     * @returns String formateado (entero o 2 decimales)
     */
    const formatQuantity = (value: Decimal | number | string): string => {
        let num: number;

        if (value instanceof Decimal) {
            num = value.toNumber();
        } else if (typeof value === 'string') {
            num = parseFloat(value) || 0;
        } else {
            num = Number(value) || 0;
        }

        return Number.isInteger(num) ? num.toString() : num.toFixed(2);
    };

    return {
        formatStock,
        formatQuantity
    };
};

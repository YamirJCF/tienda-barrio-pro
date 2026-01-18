import { Decimal } from 'decimal.js';

/**
 * Composable for formatting currency values.
 * Centralizes the formatCurrency function that was duplicated across multiple files.
 */
export function useCurrencyFormat() {
    /**
     * Formats a Decimal or number to a currency string without the $ sign.
     * Uses Colombian number formatting (periods as thousands separators).
     * @example formatCurrency(new Decimal(1500000)) => "1.500.000"
     */
    const formatCurrency = (val: Decimal | number): string => {
        const decimal = val instanceof Decimal ? val : new Decimal(val);
        return decimal.toDecimalPlaces(0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
    };

    /**
     * Formats a Decimal or number to a currency string with the $ sign.
     * @example formatWithSign(new Decimal(1500000)) => "$ 1.500.000"
     */
    const formatWithSign = (val: Decimal | number): string => {
        return `$ ${formatCurrency(val)}`;
    };

    /**
     * Formats a Decimal to show fixed decimal places (for weight products).
     * @example formatDecimal(new Decimal(2.5), 1) => "2.5"
     */
    const formatDecimal = (val: Decimal | number, decimals: number = 1): string => {
        const decimal = val instanceof Decimal ? val : new Decimal(val);
        return decimal.toFixed(decimals);
    };

    return {
        formatCurrency,
        formatWithSign,
        formatDecimal,
    };
}

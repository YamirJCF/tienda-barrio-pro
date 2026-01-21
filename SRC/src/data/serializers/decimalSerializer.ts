import { Decimal } from 'decimal.js';

/**
 * Converts a string or number value to Decimal.
 * Returns Decimal(0) if value is undefined/null.
 */
export const toDecimal = (value: string | number | undefined | null): Decimal =>
  value !== undefined && value !== null ? new Decimal(value) : new Decimal(0);

/**
 * Converts a Decimal to string for serialization.
 * Returns undefined if value is undefined.
 */
export const fromDecimal = (value: Decimal | undefined): string | undefined => value?.toString();

/**
 * Converts an optional Decimal to string, defaulting to '0'.
 */
export const fromDecimalOrZero = (value: Decimal | undefined): string => value?.toString() ?? '0';

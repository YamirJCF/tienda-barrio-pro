import { Decimal } from 'decimal.js';

/**
 * Calculates the maximum legal amount chargeable in cash.
 * According to SIC Circular (Colombia), if exact change is not available,
 * the transaction must be rounded in favor of the consumer.
 * Use: Floor to nearest 50.
 *
 * @param amount - The exact fiscal amount (e.g., 21192)
 * @returns The cash payable amount (e.g., 21150)
 */
export const getLegalCashPayable = (amount: Decimal | number): Decimal => {
  const val = new Decimal(amount);
  // Floor(val / 50) * 50
  return val.div(50).floor().mul(50);
};

/**
 * Calculates the financial loss due to mandatory rounding for a single unit.
 * Useful for "Margin Leak" alerts.
 *
 * @param price - The unit price (e.g., 2399)
 * @returns The loss amount (e.g., 49)
 */
export const getMarginLoss = (price: Decimal | number): Decimal => {
  const val = new Decimal(price);
  return val.minus(getLegalCashPayable(val));
};

/**
 * Symmetric/Hybrid rounding to nearest 50.
 * Used for internal calculations of weighable items if needed,
 * or as a suggestion for "Efficient Pricing".
 *
 * @param val - The value to round
 * @returns Rounded value to nearest 50
 */
export const roundToNearest50 = (val: Decimal | number): Decimal => {
  const value = typeof val === 'number' ? val : val.toNumber();
  const remainder = value % 50;
  return remainder <= 25
    ? new Decimal(Math.floor(value / 50) * 50)
    : new Decimal(Math.ceil(value / 50) * 50);
};

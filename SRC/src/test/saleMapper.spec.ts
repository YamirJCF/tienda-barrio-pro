import { describe, it, expect } from 'vitest';
import { saleMapper } from '../data/repositories/saleRepository';
import { Decimal } from 'decimal.js';
import { Sale } from '../types';

// Mock DB Row
const mockSaleDB = {
    id: 'sale-001',
    ticket_number: 101,
    created_at: '2023-01-01T10:00:00Z',
    payment_method: 'efectivo',
    total: 5000, // Number
    employee_id: 'emp-001',
    client_id: null,
    amount_received: 5000,
    change_given: 0,
    rounding_difference: 0,
    is_voided: false,
    void_reason: null,
    voided_by: null,
    local_id: null,
    sync_status: 'synced',
    store_id: 'store-1'
};

// Mock Domain Object
const mockSaleDomain: Sale = {
    id: 'sale-001',
    ticketNumber: 101,
    date: '2023-01-01',
    timestamp: '2023-01-01T10:00:00Z',
    items: [], // Mapper returns empty
    total: new Decimal(5000),
    paymentMethod: 'cash',
    effectiveTotal: new Decimal(5000),
    amountReceived: new Decimal(5000),
    change: new Decimal(0),
    clientId: undefined,
    employeeId: 'emp-001',
    roundingDifference: new Decimal(0),
    syncStatus: 'synced'
};

describe('SaleMapper (WO-FE-007)', () => {
    it('should map Persistence (DB) to Domain correctly', () => {
        const result = saleMapper.toDomain(mockSaleDB);

        expect(result.id).toBe(mockSaleDB.id);
        expect(result.total).toBeInstanceOf(Decimal);
        expect(result.total.toNumber()).toBe(5000);
        expect(result.paymentMethod).toBe('efectivo');
    });

    it('should map Domain to Persistence (DB) correctly', () => {
        const result = saleMapper.toPersistence(mockSaleDomain);

        expect(result.id).toBe(mockSaleDomain.id);
        expect(result.total).toBe(5000); // Strict number check
        expect(typeof result.total).toBe('number');
        expect(result.payment_method).toBe('efectivo');
    });
});

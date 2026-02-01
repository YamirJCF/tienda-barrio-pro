import { describe, it, expect } from 'vitest';
import { clientMapper } from '../data/repositories/clientRepository';
import { Decimal } from 'decimal.js';
import { Client } from '../types';

const mockClientDB = {
    id: 'cli-001',
    name: 'Juan Perez',
    id_number: '12345678', // Snake case
    phone: '555-1234',
    email: null,
    balance: 1000, // Number
    credit_limit: 50000,
    created_at: '2023-01-01T00:00:00Z',
    updated_at: '2023-01-01T00:00:00Z',
    store_id: 'store-1',
    deleted_at: null,
    is_deleted: false,
    address: null,
    notes: null
};

const mockClientDomain: Client = {
    id: 'cli-001',
    name: 'Juan Perez',
    cc: '12345678', // Camel case mapping
    phone: '555-1234',
    totalDebt: new Decimal(1000),
    creditLimit: new Decimal(50000),
    createdAt: '2023-01-01T00:00:00Z',
    updatedAt: '2023-01-01T00:00:00Z',
    email: undefined,
    notes: undefined
};

describe('ClientMapper (WO-FE-008)', () => {
    it('should map Persistence (DB) to Domain correctly', () => {
        const result = clientMapper.toDomain(mockClientDB);

        expect(result.cc).toBe(mockClientDB.id_number); // Critical mapping
        expect(result.totalDebt).toBeInstanceOf(Decimal);
        expect(result.totalDebt.toNumber()).toBe(1000);
    });

    it('should map Domain to Persistence (DB) correctly', () => {
        const result = clientMapper.toPersistence(mockClientDomain);

        expect(result.id_number).toBe(mockClientDomain.cc);
        expect(result.balance).toBe(1000);
        expect(typeof result.balance).toBe('number');
    });
});

import { describe, it, expect } from 'vitest';
import { productMapper } from '../data/repositories/productRepository';
import { Decimal } from 'decimal.js';
import { Product } from '../types';

// Mock DB Row (Snake Case, Numbers)
const mockProductDB = {
    id: 'prod-001',
    name: 'Coca Cola',
    price: 2500, // Number in DB
    current_stock: 10, // Snake case in DB
    measurement_unit: 'un',
    category_id: null,
    min_stock: 5,
    cost_price: 2000,
    created_at: '2023-01-01T00:00:00Z',
    updated_at: '2023-01-01T00:00:00Z',
    store_id: 'store-1',
    barcode: '7700001',
    description: null,
    image_url: null,
    is_active: true,
    low_stock_alerted: false,
    tax_rate: 0
};

// Mock Domain Object (Camel Case, Decimals)
const mockProductDomain: Product = {
    id: 'prod-001',
    name: 'Coca Cola',
    price: new Decimal(2500),
    stock: new Decimal(10),
    measurementUnit: 'un',
    category: undefined,
    minStock: 5,
    cost: new Decimal(2000),
    createdAt: '2023-01-01T00:00:00Z',
    updatedAt: '2023-01-01T00:00:00Z',
    storeId: 'store-1',
    notifiedLowStock: false,
    isWeighable: false,
    brand: undefined
};

describe('ProductMapper (WO-FE-006)', () => {
    it('should map Persistence (DB) to Domain correctly', () => {
        const result = productMapper.toDomain(mockProductDB);

        expect(result.id).toBe(mockProductDB.id);
        expect(result.name).toBe(mockProductDB.name);
        expect(result.price).toBeInstanceOf(Decimal);
        expect(result.price.toNumber()).toBe(mockProductDB.price);
        expect(result.stock).toBeInstanceOf(Decimal);
        expect(result.stock.toNumber()).toBe(mockProductDB.current_stock);
        expect(result.category).toBeUndefined(); // ADR compliance
    });

    it('should map Domain to Persistence (DB) correctly', () => {
        const result = productMapper.toPersistence(mockProductDomain);

        expect(result.id).toBe(mockProductDomain.id);
        expect(result.price).toBe(2500); // Should be number
        expect(result.current_stock).toBe(10); // Should be mapped from stock
        expect(result.category_id).toBeNull(); // ADR compliance
        expect(typeof result.price).toBe('number');
    });

    it('should handle Decimal precision correctly', () => {
        const complexPrice = new Decimal(2500.99);
        const domain = { ...mockProductDomain, price: complexPrice };

        const persistence = productMapper.toPersistence(domain);
        expect(persistence.price).toBe(2500.99);
    });
});

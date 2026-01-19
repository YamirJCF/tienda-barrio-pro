/**
 * Tests para Inventory Store
 * WO-005: Setup Testing
 * 
 * Cubre:
 * - addProduct: genera ID único
 * - updateStock: rechaza stock negativo (T-001)
 * - getProductByPLU: encuentra producto
 */

import { describe, it, expect, beforeEach } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useInventoryStore } from '../../stores/inventory';
import { Decimal } from 'decimal.js';

describe('Inventory Store', () => {
    beforeEach(() => {
        // Crear nueva instancia de Pinia para cada test
        setActivePinia(createPinia());
    });

    describe('addProduct', () => {
        it('genera ID único autoincremental', () => {
            const store = useInventoryStore();

            const product1 = store.addProduct({
                name: 'Arroz',
                price: new Decimal(3500),
                isWeighable: false,
                measurementUnit: 'un',
                stock: new Decimal(100),
                minStock: 10,
            });

            const product2 = store.addProduct({
                name: 'Azúcar',
                price: new Decimal(2500),
                isWeighable: false,
                measurementUnit: 'un',
                stock: new Decimal(50),
                minStock: 5,
            });

            expect(product1.id).toBe(1);
            expect(product2.id).toBe(2);
            expect(product1.id).not.toBe(product2.id);
        });

        it('aplica redondeo híbrido 50 al precio', () => {
            const store = useInventoryStore();

            // 3523 debería redondearse a 3550 (resto 23 < 25)
            const product = store.addProduct({
                name: 'Papa',
                price: new Decimal(3523),
                isWeighable: true,
                measurementUnit: 'kg',
                stock: new Decimal(50),
                minStock: 10,
            });

            expect(product.price.toNumber()).toBe(3500);
        });

        it('asigna timestamps createdAt y updatedAt', () => {
            const store = useInventoryStore();

            const product = store.addProduct({
                name: 'Leche',
                price: new Decimal(5000),
                isWeighable: false,
                measurementUnit: 'un',
                stock: new Decimal(20),
                minStock: 5,
            });

            expect(product.createdAt).toBeDefined();
            expect(product.updatedAt).toBeDefined();
            expect(product.createdAt).toBe(product.updatedAt);
        });
    });

    describe('updateStock (T-001)', () => {
        it('permite reducir stock mientras sea positivo', () => {
            const store = useInventoryStore();

            const product = store.addProduct({
                name: 'Aceite',
                price: new Decimal(10000),
                isWeighable: false,
                measurementUnit: 'un',
                stock: new Decimal(10),
                minStock: 2,
            });

            const result = store.updateStock(product.id, -5);

            expect(result.success).toBe(true);
            expect(result.product?.stock.toNumber()).toBe(5);
        });

        it('RECHAZA stock negativo (T-001 Critical)', () => {
            const store = useInventoryStore();

            const product = store.addProduct({
                name: 'Huevos',
                price: new Decimal(15000),
                isWeighable: false,
                measurementUnit: 'un',
                stock: new Decimal(5),
                minStock: 2,
            });

            // Intentar reducir más de lo disponible
            const result = store.updateStock(product.id, -10);

            expect(result.success).toBe(false);
            expect(result.error).toContain('Stock insuficiente');
            // Stock original no debe cambiar
            expect(store.getProductById(product.id)?.stock.toNumber()).toBe(5);
        });

        it('permite incrementar stock sin límite', () => {
            const store = useInventoryStore();

            const product = store.addProduct({
                name: 'Pan',
                price: new Decimal(3000),
                isWeighable: false,
                measurementUnit: 'un',
                stock: new Decimal(10),
                minStock: 5,
            });

            const result = store.updateStock(product.id, 1000);

            expect(result.success).toBe(true);
            expect(result.product?.stock.toNumber()).toBe(1010);
        });

        it('retorna error si producto no existe', () => {
            const store = useInventoryStore();

            const result = store.updateStock(99999, 10);

            expect(result.success).toBe(false);
            expect(result.error).toBe('Producto no encontrado');
        });
    });

    describe('getProductByPLU', () => {
        it('encuentra producto por PLU exacto', () => {
            const store = useInventoryStore();

            store.addProduct({
                name: 'Coca Cola',
                plu: '7702004001',
                price: new Decimal(3500),
                isWeighable: false,
                measurementUnit: 'un',
                stock: new Decimal(50),
                minStock: 10,
            });

            const found = store.getProductByPLU('7702004001');

            expect(found).toBeDefined();
            expect(found?.name).toBe('Coca Cola');
        });

        it('retorna undefined si PLU no existe', () => {
            const store = useInventoryStore();

            const found = store.getProductByPLU('9999999999');

            expect(found).toBeUndefined();
        });

        it('busca solo por PLU, no parcial', () => {
            const store = useInventoryStore();

            store.addProduct({
                name: 'Producto Test',
                plu: '12345',
                price: new Decimal(1000),
                isWeighable: false,
                measurementUnit: 'un',
                stock: new Decimal(10),
                minStock: 1,
            });

            // Búsqueda parcial NO debe encontrar
            const found = store.getProductByPLU('123');

            expect(found).toBeUndefined();
        });
    });
});

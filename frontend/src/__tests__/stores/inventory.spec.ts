/**
 * Tests para Inventory Store
 * WO-005: Setup Testing
 *
 * Cubre:
 * - addProduct: genera ID único
 * - updateStock: rechaza stock negativo (T-001)
 * - getProductByPLU: encuentra producto
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useInventoryStore } from '../../stores/inventory';
import { useAuthStore } from '../../stores/auth';
import { Decimal } from 'decimal.js';

let mockIdCounter = 1;
vi.mock('../../data/repositories/productRepository', () => ({
  productRepository: {
    create: vi.fn(async (data) => ({
      ...data,
      id: `prod-${mockIdCounter++}`,
      createdAt: data.createdAt || new Date().toISOString(),
      updatedAt: data.updatedAt || new Date().toISOString(),
    })),
    registerEntry: vi.fn(async () => true),
    registerExit: vi.fn(async () => true),
  },
  productMapper: {
    toDomain: vi.fn((r) => r),
    toPersistence: vi.fn((r) => r),
  }
}));

describe('Inventory Store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    mockIdCounter = 1;
    const authStore = useAuthStore();
    authStore.currentUser = {
      id: 'usr-1',
      storeId: '11111111-1111-4111-8111-111111111111',
      name: 'Admin',
      type: 'admin',
      permissions: { canManageInventory: true }
    } as any;
  });

  describe('addProduct', () => {
    it('genera ID único', async () => {
      const store = useInventoryStore();

      const product1 = await store.addProduct({
        name: 'Arroz',
        price: new Decimal(3500),
        isWeighable: false,
        measurementUnit: 'un',
        stock: new Decimal(100),
        minStock: 10,
      });

      const product2 = await store.addProduct({
        name: 'Azúcar',
        price: new Decimal(2500),
        isWeighable: false,
        measurementUnit: 'un',
        stock: new Decimal(50),
        minStock: 5,
      });

      expect(product1?.id).toBeDefined();
      expect(product2?.id).toBeDefined();
      expect(product1?.id).not.toBe(product2?.id);
    });

    it('aplica redondeo híbrido 50 al precio', async () => {
      const store = useInventoryStore();

      // 3523 debería redondearse a 3500 (resto 23 <= 25)
      const product = await store.addProduct({
        name: 'Papa',
        price: new Decimal(3523),
        isWeighable: true,
        measurementUnit: 'kg',
        stock: new Decimal(50),
        minStock: 10,
      });

      expect(product?.price.toNumber()).toBe(3500);
    });

    it('asigna timestamps createdAt y updatedAt', async () => {
      const store = useInventoryStore();

      const product = await store.addProduct({
        name: 'Leche',
        price: new Decimal(5000),
        isWeighable: false,
        measurementUnit: 'un',
        stock: new Decimal(20),
        minStock: 5,
      });

      expect(product?.createdAt).toBeDefined();
      expect(product?.updatedAt).toBeDefined();
      expect(product?.createdAt).toBe(product?.updatedAt);
    });
  });

  describe('updateStock (T-001)', () => {
    it('permite reducir stock mientras sea positivo', async () => {
      const store = useInventoryStore();

      const product = await store.addProduct({
        name: 'Aceite',
        price: new Decimal(10000),
        isWeighable: false,
        measurementUnit: 'un',
        stock: new Decimal(10),
        minStock: 2,
      });

      const result = store.updateStock(product!.id, -5);

      expect(result.success).toBe(true);
      expect(result.product?.stock.toNumber()).toBe(5);
    });

    it('RECHAZA stock negativo (T-001 Critical)', async () => {
      const store = useInventoryStore();

      const product = await store.addProduct({
        name: 'Huevos',
        price: new Decimal(15000),
        isWeighable: false,
        measurementUnit: 'un',
        stock: new Decimal(5),
        minStock: 2,
      });

      // Intentar reducir más de lo disponible
      const result = store.updateStock(product!.id, -10);

      expect(result.success).toBe(false);
      expect(result.error).toContain('Stock insuficiente');
      // Stock original no debe cambiar
      expect(store.getProductById(product!.id)?.stock.toNumber()).toBe(5);
    });

    it('permite incrementar stock sin límite', async () => {
      const store = useInventoryStore();

      const product = await store.addProduct({
        name: 'Pan',
        price: new Decimal(3000),
        isWeighable: false,
        measurementUnit: 'un',
        stock: new Decimal(10),
        minStock: 5,
      });

      const result = store.updateStock(product!.id, 1000);

      expect(result.success).toBe(true);
      expect(result.product?.stock.toNumber()).toBe(1010);
    });

    it('retorna error si producto no existe', () => {
      const store = useInventoryStore();

      const result = store.updateStock('non-existent', 10);

      expect(result.success).toBe(false);
      expect(result.error).toBe('Producto no encontrado');
    });
  });

  describe('getProductByPLU', () => {
    it('encuentra producto por PLU exacto', async () => {
      const store = useInventoryStore();

      await store.addProduct({
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

    it('busca solo por PLU, no parcial', async () => {
      const store = useInventoryStore();

      await store.addProduct({
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

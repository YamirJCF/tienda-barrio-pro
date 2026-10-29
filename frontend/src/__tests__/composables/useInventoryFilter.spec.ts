import { describe, it, expect, beforeEach, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useInventoryStore } from '../../stores/inventory';
import { useInventoryFilter, resetInventorySortBaseline } from '../../composables/useInventoryFilter';
import { Decimal } from 'decimal.js';
import type { Product } from '../../types';

vi.mock('../../data/repositories/productRepository', () => ({
  productRepository: {
    getAll: vi.fn(async () => []),
    getMovementHistory: vi.fn(async () => []),
  },
  productMapper: {
    toDomain: vi.fn((x) => x),
    toPersistence: vi.fn((x) => x),
  },
}));

describe('useInventoryFilter (Gobernanza SWR Nivel 2 y Filtros 100% en Memoria)', () => {
  let inventoryStore: ReturnType<typeof useInventoryStore>;

  const mockProducts: Product[] = [
    {
      id: 'prod-1',
      name: 'Arroz Diana 1kg',
      plu: '1001',
      brand: 'Diana',
      category: 'Granos',
      price: new Decimal(4500),
      stock: new Decimal(15),
      minStock: 10,
      measurementUnit: 'un',
      storeId: 'store-1',
      isActive: true,
      createdAt: '2026-10-01T10:00:00Z',
    },
    {
      id: 'prod-2',
      name: 'Aceite Gourmet 1L',
      plu: '1002',
      brand: 'Gourmet',
      category: 'Abarrotes',
      price: new Decimal(12000),
      stock: new Decimal(3), // Low stock (3 <= 5) -> urgency: 3 - 5 = -2
      minStock: 5,
      measurementUnit: 'un',
      storeId: 'store-1',
      isActive: true,
      createdAt: '2026-10-05T12:00:00Z',
    },
    {
      id: 'prod-3',
      name: 'Panela Pastilla 500g',
      plu: '1003',
      brand: 'Riopaila',
      category: 'Abarrotes',
      price: new Decimal(3200),
      stock: new Decimal(0), // Out of stock (0 <= 2) -> urgency: 0 - 2 = -2 (desempate por nombre: Aceite vs Panela)
      minStock: 2,
      measurementUnit: 'un',
      storeId: 'store-1',
      isActive: true,
      createdAt: '2026-10-10T08:00:00Z',
    },
    {
      id: 'prod-4',
      name: 'Jabón Rey 300g',
      plu: '1004',
      brand: 'Dersa',
      category: 'Aseo',
      price: new Decimal(2800),
      stock: new Decimal(25),
      minStock: 5,
      measurementUnit: 'un',
      storeId: 'store-1',
      isActive: false, // Soft-deleted
      createdAt: '2026-10-15T15:00:00Z',
    },
  ];

  beforeEach(() => {
    setActivePinia(createPinia());
    inventoryStore = useInventoryStore();
    inventoryStore.products = [...mockProducts];
    resetInventorySortBaseline();
  });

  it('debe excluir por defecto los productos inactivos y ordenar por fecha descendente', () => {
    const { filteredProducts, activeFiltersCount } = useInventoryFilter();

    expect(activeFiltersCount.value).toBe(0);
    expect(filteredProducts.value.length).toBe(3);
    // Orden por defecto: created_desc -> prod-3 (Oct 10), prod-2 (Oct 5), prod-1 (Oct 1)
    expect(filteredProducts.value[0].id).toBe('prod-3');
    expect(filteredProducts.value[1].id).toBe('prod-2');
    expect(filteredProducts.value[2].id).toBe('prod-1');
  });

  it('debe incluir productos inactivos cuando includeInactive = true', () => {
    const { filteredProducts, includeInactive, activeFiltersCount } = useInventoryFilter();

    includeInactive.value = true;
    expect(activeFiltersCount.value).toBe(1);
    expect(filteredProducts.value.length).toBe(4);
    expect(filteredProducts.value.some((p) => p.id === 'prod-4')).toBe(true);
  });

  it('debe filtrar por búsqueda de texto en nombre, PLU, marca y categoría', () => {
    const { filteredProducts, searchQuery } = useInventoryFilter();

    // Búsqueda por nombre
    searchQuery.value = 'aceite';
    expect(filteredProducts.value.length).toBe(1);
    expect(filteredProducts.value[0].id).toBe('prod-2');

    // Búsqueda por PLU
    searchQuery.value = '1001';
    expect(filteredProducts.value.length).toBe(1);
    expect(filteredProducts.value[0].name).toBe('Arroz Diana 1kg');

    // Búsqueda por Marca
    searchQuery.value = 'riopaila';
    expect(filteredProducts.value.length).toBe(1);
    expect(filteredProducts.value[0].id).toBe('prod-3');

    // Búsqueda por Categoría en texto libre (nuevo)
    searchQuery.value = 'granos';
    expect(filteredProducts.value.length).toBe(1);
    expect(filteredProducts.value[0].id).toBe('prod-1');
  });

  it('debe filtrar por categoría seleccionada', () => {
    const { filteredProducts, selectedCategory, activeFiltersCount } = useInventoryFilter();

    selectedCategory.value = 'Abarrotes';
    expect(activeFiltersCount.value).toBe(1);
    expect(filteredProducts.value.length).toBe(2);
    expect(filteredProducts.value.every((p) => p.category === 'Abarrotes')).toBe(true);
  });

  it('debe filtrar exclusivamente productos con stock bajo (stock <= minStock)', () => {
    const { filteredProducts, onlyLowStock, activeFiltersCount } = useInventoryFilter();

    onlyLowStock.value = true;
    expect(activeFiltersCount.value).toBe(1);
    // prod-2 (stock: 3, minStock: 5) y prod-3 (stock: 0, minStock: 2)
    expect(filteredProducts.value.length).toBe(2);
    expect(filteredProducts.value.map((p) => p.id)).toEqual(['prod-3', 'prod-2']);
  });

  it('debe ordenar por "Más urgentes primero" (urgency_asc: stock - minStock)', () => {
    const { filteredProducts, sortBy } = useInventoryFilter();

    sortBy.value = 'urgency_asc';
    // prod-2: 3 - 5 = -2 (nombre: Aceite Gourmet 1L)
    // prod-3: 0 - 2 = -2 (nombre: Panela Pastilla 500g)
    // prod-1: 15 - 10 = +5 (nombre: Arroz Diana 1kg)
    // Desempate alfabético: Aceite Gourmet antes que Panela Pastilla
    expect(filteredProducts.value[0].id).toBe('prod-2');
    expect(filteredProducts.value[1].id).toBe('prod-3');
    expect(filteredProducts.value[2].id).toBe('prod-1');
  });

  it('debe ordenar alfabéticamente por nombre (A-Z y Z-A)', () => {
    const { filteredProducts, sortBy } = useInventoryFilter();

    sortBy.value = 'name_asc';
    expect(filteredProducts.value[0].name).toBe('Aceite Gourmet 1L');
    expect(filteredProducts.value[1].name).toBe('Arroz Diana 1kg');
    expect(filteredProducts.value[2].name).toBe('Panela Pastilla 500g');

    sortBy.value = 'name_desc';
    expect(filteredProducts.value[0].name).toBe('Panela Pastilla 500g');
    expect(filteredProducts.value[1].name).toBe('Arroz Diana 1kg');
    expect(filteredProducts.value[2].name).toBe('Aceite Gourmet 1L');
  });

  it('debe ordenar por existencia física de stock (ascendente y descendente)', () => {
    const { filteredProducts, sortBy } = useInventoryFilter();

    sortBy.value = 'stock_asc';
    expect(filteredProducts.value[0].id).toBe('prod-3'); // stock 0
    expect(filteredProducts.value[1].id).toBe('prod-2'); // stock 3
    expect(filteredProducts.value[2].id).toBe('prod-1'); // stock 15

    sortBy.value = 'stock_desc';
    expect(filteredProducts.value[0].id).toBe('prod-1'); // stock 15
    expect(filteredProducts.value[1].id).toBe('prod-2'); // stock 3
    expect(filteredProducts.value[2].id).toBe('prod-3'); // stock 0
  });

  it('debe ordenar por precio comercial (ascendente y descendente)', () => {
    const { filteredProducts, sortBy } = useInventoryFilter();

    sortBy.value = 'price_asc';
    expect(filteredProducts.value[0].id).toBe('prod-3'); // price 3200
    expect(filteredProducts.value[1].id).toBe('prod-1'); // price 4500
    expect(filteredProducts.value[2].id).toBe('prod-2'); // price 12000

    sortBy.value = 'price_desc';
    expect(filteredProducts.value[0].id).toBe('prod-2'); // price 12000
    expect(filteredProducts.value[1].id).toBe('prod-1'); // price 4500
    expect(filteredProducts.value[2].id).toBe('prod-3'); // price 3200
  });

  it('el orden NO debe contar en activeFiltersCount (regla D4)', () => {
    const { selectedCategory, onlyLowStock, sortBy, activeFiltersCount } = useInventoryFilter();

    selectedCategory.value = 'Abarrotes';
    onlyLowStock.value = true;
    sortBy.value = 'price_desc';

    // Cuenta categoría (1) y stock bajo (1). El orden NO cuenta como filtro activo
    expect(activeFiltersCount.value).toBe(2);
  });

  it('debe aplicar atajos internos con applyShortcutString()', () => {
    const {
      searchQuery,
      onlyLowStock,
      stockRule,
      brandFilter,
      applyShortcutString,
      filteredProducts,
    } = useInventoryFilter();

    const res = applyShortcutString('aceite bajo stock<=5 marca:gourmet', true);

    expect(res.remainingText).toBe('aceite');
    expect(searchQuery.value).toBe('aceite');
    expect(onlyLowStock.value).toBe(true);
    expect(stockRule.value).toEqual({ op: '<=', value: 5 });
    expect(brandFilter.value).toBe('gourmet');

    // Prod-2 (Aceite Gourmet 1L) cumple todo (stock 3 <= minStock 5)
    expect(filteredProducts.value.length).toBe(1);
    expect(filteredProducts.value[0].id).toBe('prod-2');
  });

  it('debe restablecer filtros pero conservar el orden con resetFilters() (regla D4)', () => {
    const {
      searchQuery,
      selectedCategory,
      onlyLowStock,
      includeInactive,
      sortBy,
      activeFiltersCount,
      resetFilters,
      filteredProducts,
    } = useInventoryFilter();

    searchQuery.value = 'Diana';
    selectedCategory.value = 'Granos';
    onlyLowStock.value = true;
    includeInactive.value = true;
    sortBy.value = 'price_asc';

    // 3 filtros activos (categoría, stock bajo, inactivos)
    expect(activeFiltersCount.value).toBe(3);

    resetFilters();

    expect(searchQuery.value).toBe('');
    expect(selectedCategory.value).toBe('all');
    expect(onlyLowStock.value).toBe(false);
    expect(includeInactive.value).toBe(false);
    // sortBy se conserva por sesión (regla D4)
    expect(sortBy.value).toBe('price_asc');
    expect(activeFiltersCount.value).toBe(0);
  });
});

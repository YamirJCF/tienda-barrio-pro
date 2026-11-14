import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { setActivePinia, createPinia } from 'pinia';
import { Decimal } from 'decimal.js';
import ProductSearchModal from '../../components/ProductSearchModal.vue';
import { useInventoryStore } from '../../stores/inventory';
import { useAuthStore } from '../../stores/auth';
import {
  productRepository,
  type POSProductPageParams,
  type PaginatedPOSProductsResult,
} from '../../data/repositories/productRepository';
import type { Product } from '../../types';

describe('ProductSearchModal - Prefix Search & Progressive 7-by-7 Pagination', () => {
  const storeId = 'b63adadd-8679-4abc-af6c-d72ac3aa49e1';

  const normalizeAccents = (value: string): string =>
    value
      .toLowerCase()
      .replace(/á/g, 'a')
      .replace(/é/g, 'e')
      .replace(/í/g, 'i')
      .replace(/ó/g, 'o')
      .replace(/[úü]/g, 'u');

  const makeProductsCatalog = (): Product[] => [
    {
      id: 'p-112',
      name: 'Aceite de cocina (300 ml)',
      plu: '112',
      price: new Decimal(4500),
      stock: new Decimal(28),
      minStock: 5,
      brand: 'Premier',
      category: 'Despensa',
      isWeighable: false,
      measurementUnit: 'un',
      storeId,
      isActive: true,
    },
    {
      id: 'p-115',
      name: 'Atun en lata',
      plu: '115',
      price: new Decimal(5800),
      stock: new Decimal(12),
      minStock: 5,
      brand: 'Van Camps',
      category: 'Despensa',
      isWeighable: false,
      measurementUnit: 'un',
      storeId,
      isActive: true,
    },
    {
      id: 'p-113',
      name: 'Café molido (125g)',
      plu: '113',
      price: new Decimal(4000),
      stock: new Decimal(20),
      minStock: 5,
      brand: 'Sello Rojo',
      category: 'Despensa',
      isWeighable: false,
      measurementUnit: 'un',
      storeId,
      isActive: true,
    },
    {
      id: 'p-123',
      name: 'Chocorramo',
      plu: '123',
      price: new Decimal(2400),
      stock: new Decimal(13),
      minStock: 5,
      brand: 'Ramo',
      category: 'Mecato',
      isWeighable: false,
      measurementUnit: 'un',
      storeId,
      isActive: true,
    },
    {
      id: 'p-117',
      name: 'Cubo de caldo',
      plu: '117',
      price: new Decimal(3600),
      stock: new Decimal(10),
      minStock: 5,
      brand: 'Knorr',
      category: 'Despensa',
      isWeighable: false,
      measurementUnit: 'un',
      storeId,
      isActive: true,
    },
    {
      id: 'p-124',
      name: 'Gaseosa coca-cola',
      plu: '124',
      price: new Decimal(4000),
      stock: new Decimal(24),
      minStock: 5,
      brand: 'Coca-Cola',
      category: 'Bebidas',
      isWeighable: false,
      measurementUnit: 'un',
      storeId,
      isActive: true,
    },
    {
      id: 'p-126',
      name: 'Jugo en caja hit',
      plu: '126',
      price: new Decimal(1500),
      stock: new Decimal(24),
      minStock: 5,
      brand: 'Hit',
      category: 'Bebidas',
      isWeighable: false,
      measurementUnit: 'un',
      storeId,
      isActive: true,
    },
    {
      id: 'p-132',
      name: 'Lavaloza líquido',
      plu: '132',
      price: new Decimal(8900),
      stock: new Decimal(10),
      minStock: 5,
      brand: 'Axion',
      category: 'Aseo',
      isWeighable: false,
      measurementUnit: 'un',
      storeId,
      isActive: true,
    },
    {
      id: 'p-136',
      name: 'Papel higienico',
      plu: '136',
      price: new Decimal(1900),
      stock: new Decimal(24),
      minStock: 5,
      brand: 'Familia',
      category: 'Aseo',
      isWeighable: false,
      measurementUnit: 'un',
      storeId,
      isActive: true,
    },
    {
      id: 'p-116',
      name: 'Salsa de tomate',
      plu: '116',
      price: new Decimal(3300),
      stock: new Decimal(12),
      minStock: 5,
      brand: 'Fruco',
      category: 'Despensa',
      isWeighable: false,
      measurementUnit: 'un',
      storeId,
      isActive: true,
    },
    ...Array.from({ length: 6 }, (_, idx) => {
      const n = idx + 201;
      return {
        id: `p-${n}`,
        name: `Producto Extra ${String(n).padStart(3, '0')}`,
        plu: String(n),
        price: new Decimal(1000 + idx * 100),
        stock: new Decimal(8),
        minStock: 2,
        brand: 'Genérica',
        category: 'General',
        isWeighable: false,
        measurementUnit: 'un' as const,
        storeId,
        isActive: true,
      };
    }),
  ];

  const simulateRpcFilterAndSlice = (
    dataset: Product[],
    params: POSProductPageParams,
  ): PaginatedPOSProductsResult => {
    const clean = (params.search || '').trim();
    const limit = params.limit ?? 7;
    const offset = params.offset ?? 0;

    let filtered: Product[];
    if (!clean) {
      filtered = dataset.filter((p) => p.isActive !== false && p.stock.gt(0));
    } else if (/^[0-9]+$/.test(clean)) {
      filtered = dataset
        .filter(
          (p) =>
            p.isActive !== false &&
            (p.plu === clean || (Boolean(p.plu?.startsWith(clean)) && p.stock.gt(0))),
        )
        .sort((a, b) => (a.plu === clean ? -1 : b.plu === clean ? 1 : 0));
    } else {
      const prefix = normalizeAccents(clean);
      filtered = dataset.filter(
        (p) =>
          p.isActive !== false &&
          p.stock.gt(0) &&
          normalizeAccents(p.name).startsWith(prefix),
      );
    }

    return {
      data: filtered.slice(offset, offset + limit),
      count: filtered.length,
    };
  };

  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
    vi.clearAllMocks();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  const setupStores = (dataset: Product[] = makeProductsCatalog()) => {
    const inventoryStore = useInventoryStore();
    const authStore = useAuthStore();

    authStore.currentUser = {
      id: 'usr-1',
      name: 'Cajero POS',
      email: 'cajero@test.com',
      type: 'admin',
      storeId,
    } as any;

    inventoryStore.products = [];

    const getAllSpy = vi.spyOn(productRepository, 'getAll').mockResolvedValue([]);
    const paginatedSpy = vi
      .spyOn(productRepository, 'getPaginatedPOS')
      .mockImplementation(async (params) => simulateRpcFilterAndSlice(dataset, params));
    const fetchPageSpy = vi.spyOn(inventoryStore, 'fetchProductsPage');

    return { inventoryStore, authStore, getAllSpy, paginatedSpy, fetchPageSpy };
  };

  const mountModal = (modelValue: boolean = true) => {
    return mount(ProductSearchModal, {
      props: {
        modelValue,
      },
      global: {
        stubs: {
          teleport: true,
        },
      },
    });
  };

  it('carga estrictamente de 7 en 7 al abrir y al pulsar Cargar más o hacer scroll', async () => {
    const { getAllSpy, paginatedSpy } = setupStores();
    const wrapper = mountModal(true);
    await flushPromises();

    // No debe disparar carga masiva de todo el inventario
    expect(getAllSpy).not.toHaveBeenCalled();

    // Primera petición: exactamente 7 elementos
    expect(paginatedSpy).toHaveBeenCalledTimes(1);
    expect(paginatedSpy).toHaveBeenNthCalledWith(1, {
      storeId,
      limit: 7,
      offset: 0,
      search: '',
    });

    expect(wrapper.findAll('[data-testid="pos-product-card"]')).toHaveLength(7);
    expect(wrapper.find('[data-testid="pos-product-count"]').text()).toBe('7 de 16');

    // Cargar siguientes 7 mediante botón
    const loadMoreBtn = wrapper.find('[data-testid="load-more-products-btn"]');
    expect(loadMoreBtn.exists()).toBe(true);
    expect(loadMoreBtn.text()).toContain('Cargar más productos (9 restantes)');
    await loadMoreBtn.trigger('click');
    await flushPromises();

    expect(paginatedSpy).toHaveBeenCalledTimes(2);
    expect(paginatedSpy).toHaveBeenNthCalledWith(2, {
      storeId,
      limit: 7,
      offset: 7,
      search: '',
    });
    expect(wrapper.findAll('[data-testid="pos-product-card"]')).toHaveLength(14);
    expect(wrapper.find('[data-testid="pos-product-count"]').text()).toBe('14 de 16');

    // Cargar los 2 restantes al hacer scroll al final de la lista
    const listEl = wrapper.find('[data-testid="pos-product-list"]');
    Object.defineProperty(listEl.element, 'scrollHeight', { value: 600, configurable: true });
    Object.defineProperty(listEl.element, 'clientHeight', { value: 300, configurable: true });
    Object.defineProperty(listEl.element, 'scrollTop', { value: 290, configurable: true });

    await listEl.trigger('scroll');
    await flushPromises();

    expect(paginatedSpy).toHaveBeenCalledTimes(3);
    expect(paginatedSpy).toHaveBeenNthCalledWith(3, {
      storeId,
      limit: 7,
      offset: 14,
      search: '',
    });
    expect(wrapper.findAll('[data-testid="pos-product-card"]')).toHaveLength(16);
    expect(wrapper.find('[data-testid="pos-product-count"]').text()).toBe('16 de 16');
    expect(wrapper.find('[data-testid="load-more-products-btn"]').exists()).toBe(false);
  });

  it('filtra por la primera letra o prefijo inicial del nombre desde 1 carácter (sin coincidencias en medio de las palabras)', async () => {
    vi.useFakeTimers();
    const { paginatedSpy } = setupStores();
    const wrapper = mountModal(true);
    await flushPromises();

    const searchInput = wrapper.find('input');
    expect(searchInput.exists()).toBe(true);

    // 1 letra: "l" debe mostrar solo "Lavaloza líquido" y excluir "Café molido", "Papel higienico", "Atun en lata", etc.
    await searchInput.setValue('l');
    vi.advanceTimersByTime(220);
    await flushPromises();

    expect(paginatedSpy).toHaveBeenLastCalledWith({
      storeId,
      limit: 7,
      offset: 0,
      search: 'l',
    });

    let cards = wrapper.findAll('[data-testid="pos-product-card"]');
    expect(cards).toHaveLength(1);
    expect(cards[0].text()).toContain('Lavaloza líquido');
    expect(wrapper.text()).not.toContain('Café molido');
    expect(wrapper.text()).not.toContain('Papel higienico');
    expect(wrapper.text()).not.toContain('Atun en lata');

    // 2 letras: "ca" debe mostrar solo "Café molido (125g)" y excluir "Cubo de caldo", "Gaseosa coca-cola", "Jugo en caja hit"
    await searchInput.setValue('ca');
    vi.advanceTimersByTime(220);
    await flushPromises();

    expect(paginatedSpy).toHaveBeenLastCalledWith({
      storeId,
      limit: 7,
      offset: 0,
      search: 'ca',
    });

    cards = wrapper.findAll('[data-testid="pos-product-card"]');
    expect(cards).toHaveLength(1);
    expect(cards[0].text()).toContain('Café molido (125g)');
    expect(wrapper.text()).not.toContain('Cubo de caldo');
    expect(wrapper.text()).not.toContain('Gaseosa coca-cola');
    expect(wrapper.text()).not.toContain('Jugo en caja hit');
  });

  it('permite buscar por PLU numérico y selecciona el producto cerrando el modal', async () => {
    vi.useFakeTimers();
    const { paginatedSpy } = setupStores();
    const wrapper = mountModal(true);
    await flushPromises();

    const searchInput = wrapper.find('input');
    await searchInput.setValue('113');
    vi.advanceTimersByTime(220);
    await flushPromises();

    expect(paginatedSpy).toHaveBeenLastCalledWith({
      storeId,
      limit: 7,
      offset: 0,
      search: '113',
    });

    const cards = wrapper.findAll('[data-testid="pos-product-card"]');
    expect(cards).toHaveLength(1);
    expect(cards[0].text()).toContain('Café molido (125g)');

    await cards[0].trigger('click');

    const selectedEvents = wrapper.emitted('select');
    expect(selectedEvents).toBeDefined();
    expect(selectedEvents![0][0]).toMatchObject({
      id: 'p-113',
      name: 'Café molido (125g)',
      plu: '113',
    });
    expect(wrapper.emitted('update:modelValue')?.[0]).toEqual([false]);
  });

  it('muestra error explícito con botón Reintentar cuando falla la consulta inicial o paginada (Regla 3)', async () => {
    const { paginatedSpy } = setupStores();
    paginatedSpy
      .mockRejectedValueOnce(new Error('Fallo de red al consultar buscar_producto_pos'))
      .mockImplementationOnce(async (params) => simulateRpcFilterAndSlice(makeProductsCatalog(), params))
      .mockRejectedValueOnce(new Error('Timeout al cargar página 2'))
      .mockImplementation(async (params) => simulateRpcFilterAndSlice(makeProductsCatalog(), params));

    const wrapper = mountModal(true);
    await flushPromises();

    // Error explícito en carga inicial (no silenciado como vacío)
    expect(wrapper.text()).toContain('Fallo de red al consultar buscar_producto_pos');
    expect(wrapper.text()).not.toContain('No se encontraron productos');
    const retryBtn = wrapper.find('[data-testid="retry-products-btn"]');
    expect(retryBtn.exists()).toBe(true);

    // Reintento recupera la página inicial de 7 productos
    await retryBtn.trigger('click');
    await flushPromises();
    expect(wrapper.findAll('[data-testid="pos-product-card"]')).toHaveLength(7);

    // Error al cargar la página 2 muestra banner de reintento manteniendo los 7 cargados
    await wrapper.find('[data-testid="load-more-products-btn"]').trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('Timeout al cargar página 2');
    expect(wrapper.findAll('[data-testid="pos-product-card"]')).toHaveLength(7);

    await wrapper.find('[data-testid="retry-products-btn"]').trigger('click');
    await flushPromises();
    expect(wrapper.findAll('[data-testid="pos-product-card"]')).toHaveLength(14);
  });
});

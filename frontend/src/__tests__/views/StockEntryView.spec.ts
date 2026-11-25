import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import Decimal from 'decimal.js';
import StockEntryView from '../../views/StockEntryView.vue';
import { useInventoryStore } from '../../stores/inventory';
import { useAuthStore } from '../../stores/auth';

enableAutoUnmount(afterEach);

const { mockPush, mockBack, mockShowSuccess } = vi.hoisted(() => ({
  mockPush: vi.fn(),
  mockBack: vi.fn(),
  mockShowSuccess: vi.fn(),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mockPush, back: mockBack }),
  useRoute: () => ({ params: {}, query: {} }),
}));

vi.mock('../../composables/useNotifications', () => ({
  useNotifications: () => ({
    showSuccess: mockShowSuccess,
    showError: vi.fn(),
    showWarning: vi.fn(),
    showInfo: vi.fn(),
  }),
}));

vi.mock('../../stores/suppliers', () => ({
  useSuppliersStore: () => ({
    suppliers: [{ id: 'sup-1', name: 'Distribuidora Sur' }],
    fetchSuppliers: vi.fn().mockResolvedValue(undefined),
  }),
}));

describe('StockEntryView.vue — Entrada Atómica y Autoridad SQL (WO-OLA2-C3-001)', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    Object.defineProperty(navigator, 'onLine', { value: true, configurable: true });

    const authStore = useAuthStore();
    authStore.currentUser = {
      id: 'owner-1',
      name: 'Admin',
      email: 'admin@tienda.co',
      type: 'admin',
      storeId: 'store-1',
      permissions: { canManageInventory: true, canFiar: true, canOpenCloseCash: true, canManageRefunds: true },
    } as any;
    authStore.isAuthenticated = true;

    const inventoryStore = useInventoryStore();
    inventoryStore.products = [
      {
        id: 'prod-1',
        storeId: 'store-1',
        name: 'Leche Entera 1L',
        plu: '101',
        brand: 'Alquería',
        price: new Decimal(4500),
        cost: new Decimal(3200),
        stock: new Decimal(5),
        minStock: 2,
        measurementUnit: 'un',
        isWeighable: false,
      } as any,
    ];
  });

  it('usa paleta dual DESIGN.md, omite totales monetarios locales y envía expirationDate estructurado al RPC atómico', async () => {
    const inventoryStore = useInventoryStore();
    const bulkSpy = vi.spyOn(inventoryStore, 'registerBulkStockEntry').mockResolvedValue({
      itemsProcessed: 1,
      totalUnits: 6,
      totalEntryCost: 19200,
      createdBatchIds: ['batch-1'],
    });

    const wrapper = mount(StockEntryView);
    await flushPromises();

    // Paleta dual DESIGN.md (sin fondo dark forzado bg-gray-900)
    expect(wrapper.html()).toContain('bg-background-light');
    expect(wrapper.html()).not.toContain('bg-gray-900');

    // Agregar producto desde búsqueda
    await wrapper.find('input[placeholder="Buscar producto..."]').setValue('Leche');
    await flushPromises();
    await wrapper.find('[data-testid="stock-entry-search-result-prod-1"]').trigger('click');
    await flushPromises();

    // Asignar cantidad = 6 y fecha de vencimiento
    const numberInputs = wrapper.findAll('input[type="number"]');
    await numberInputs[0].setValue(6);
    await wrapper.find('input[type="date"]').setValue('2026-12-30');
    await flushPromises();

    // Antes de confirmar NO debe mostrar subtotales ni "Total Entrada" calculado en cliente
    expect(wrapper.text()).toContain('1 producto(s) · 6 unidad(es)');
    expect(wrapper.text()).not.toContain('Subtotal:');
    expect(wrapper.text()).not.toContain('19.200');

    // Confirmar entrada atómica
    const submitBtn = wrapper.findAll('button').find((b) => b.text().includes('GUARDAR ENTRADA ATÓMICA'));
    expect(submitBtn).toBeDefined();
    await submitBtn!.trigger('click');
    await flushPromises();

    expect(bulkSpy).toHaveBeenCalledTimes(1);
    expect(bulkSpy).toHaveBeenCalledWith(
      expect.objectContaining({
        reason: 'Compra',
        items: [
          expect.objectContaining({
            productId: 'prod-1',
            quantity: 6,
            unitCost: 3200,
            salePrice: 4500,
            expirationDate: '2026-12-30',
          }),
        ],
      })
    );

    // Tras confirmar muestra el total autoritativo calculado en PostgreSQL
    expect(wrapper.find('[data-testid="bulk-entry-confirmed-banner"]').text()).toContain('$ 19.200');
  });

  it('muestra alerta N3 persistente y preserva los ítems capturados si el RPC atómico falla', async () => {
    const inventoryStore = useInventoryStore();
    vi.spyOn(inventoryStore, 'registerBulkStockEntry').mockRejectedValue(
      new Error('PRODUCT_NOT_FOUND: Fallo atómico en servidor')
    );

    const wrapper = mount(StockEntryView);
    await flushPromises();

    await wrapper.find('input[placeholder="Buscar producto..."]').setValue('Leche');
    await flushPromises();
    await wrapper.find('[data-testid="stock-entry-search-result-prod-1"]').trigger('click');
    await flushPromises();

    const submitBtn = wrapper.findAll('button').find((b) => b.text().includes('GUARDAR ENTRADA ATÓMICA'));
    await submitBtn!.trigger('click');
    await flushPromises();

    const errBanner = wrapper.find('[data-testid="bulk-entry-error-banner"]');
    expect(errBanner.exists()).toBe(true);
    expect(errBanner.text()).toContain('PRODUCT_NOT_FOUND');
    // Ítem capturado sigue vivo en pantalla (todo-o-nada)
    expect(wrapper.text()).toContain('Leche Entera 1L');
  });
});

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

  it('usa paleta dual DESIGN.md, aplica Glosario Único sin Vencimiento, omite totales locales y envía expirationDate: null', async () => {
    const inventoryStore = useInventoryStore();
    const bulkSpy = vi.spyOn(inventoryStore, 'registerBulkStockEntry').mockResolvedValue({
      itemsProcessed: 1,
      totalUnits: 6,
      totalEntryCost: 19200,
      createdBatchIds: ['batch-1'],
    });

    const wrapper = mount(StockEntryView);
    await flushPromises();

    // Paleta dual DESIGN.md (sin fondo dark forzado bg-gray-900) y Glosario Único (ARQ-005)
    expect(wrapper.html()).toContain('bg-background-light');
    expect(wrapper.html()).not.toContain('bg-gray-900');
    expect(wrapper.text()).toContain('Registrar Entrada');
    expect(wrapper.text()).not.toContain('Atómica');

    // Agregar producto desde búsqueda
    await wrapper.find('input[placeholder="Buscar producto..."]').setValue('Leche');
    await flushPromises();
    await wrapper.find('[data-testid="stock-entry-search-result-prod-1"]').trigger('click');
    await flushPromises();

    // Asignar cantidad = 6 y verificar que NO existe campo de fecha de vencimiento (SYSTEM_BOUNDARIES / ARQ-005)
    const numberInputs = wrapper.findAll('input[type="number"]');
    await numberInputs[0].setValue(6);
    expect(wrapper.find('input[type="date"]').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Vencimiento');
    await flushPromises();

    // Antes de confirmar NO debe mostrar subtotales ni "Total Entrada" calculado en cliente
    expect(wrapper.text()).toContain('1 producto(s) · 6 unidad(es)');
    expect(wrapper.text()).not.toContain('Subtotal:');
    expect(wrapper.text()).not.toContain('19.200');

    // Confirmar entrada
    const submitBtn = wrapper.findAll('button').find((b) => b.text().includes('GUARDAR ENTRADA'));
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
            expirationDate: null,
          }),
        ],
      })
    );

    // Tras confirmar muestra el total autoritativo sin siglas técnicas (SQL)
    const receiptText = wrapper.find('[data-testid="bulk-entry-confirmed-banner"]').text();
    expect(receiptText).toContain('$ 19.200');
    expect(receiptText).not.toContain('(SQL)');
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

    const submitBtn = wrapper.findAll('button').find((b) => b.text().includes('GUARDAR ENTRADA'));
    await submitBtn!.trigger('click');
    await flushPromises();

    const errBanner = wrapper.find('[data-testid="bulk-entry-error-banner"]');
    expect(errBanner.exists()).toBe(true);
    expect(errBanner.text()).toContain('PRODUCT_NOT_FOUND');
    // Ítem capturado sigue vivo en pantalla (todo-o-nada)
    expect(wrapper.text()).toContain('Leche Entera 1L');
  });
});

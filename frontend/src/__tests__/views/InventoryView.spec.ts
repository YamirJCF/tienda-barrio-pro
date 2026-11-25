import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { reactive } from 'vue';
import Decimal from 'decimal.js';
import InventoryView from '../../views/InventoryView.vue';
import { useInventoryStore } from '../../stores/inventory';
import { useAuthStore } from '../../stores/auth';
import { useBatchStore } from '../../stores/batches';

enableAutoUnmount(afterEach);

const { mockPush, mockRouteQuery } = vi.hoisted(() => ({
  mockPush: vi.fn(),
  mockRouteQuery: { value: {} as Record<string, string> },
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mockPush, back: vi.fn() }),
  useRoute: () => reactive({ params: {}, get query() { return mockRouteQuery.value; } }),
}));

vi.mock('../../composables/useNotifications', () => ({
  useNotifications: () => ({
    showSuccess: vi.fn(),
    showError: vi.fn(),
    showWarning: vi.fn(),
    showInfo: vi.fn(),
  }),
}));

vi.mock('../../stores/suppliers', () => ({
  useSuppliersStore: () => ({
    suppliers: [],
    fetchSuppliers: vi.fn().mockResolvedValue(undefined),
  }),
}));

vi.mock('../../data/supabaseClient', () => ({
  isSupabaseConfigured: () => false,
  isAuditMode: () => false,
  getSupabaseClient: () => null,
}));

describe('InventoryView.vue & Ficha Unificada de 3 Pestañas (WO-OLA2-C3-001)', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    mockRouteQuery.value = {};
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
    inventoryStore.initialized = true;
    inventoryStore.products = [
      {
        id: 'prod-1',
        storeId: 'store-1',
        name: 'Café Molido 500g',
        plu: '201',
        brand: 'Sello Rojo',
        category: 'Despensa',
        price: new Decimal(12500),
        cost: new Decimal(9000),
        stock: new Decimal(7),
        minStock: 2,
        measurementUnit: 'un',
        isWeighable: false,
        isActive: true,
      } as any,
    ];
    vi.spyOn(inventoryStore, 'initialize').mockResolvedValue(undefined);
  });

  const globalStubs = {
    teleport: true,
    BottomNav: true,
    RecycleScroller: {
      props: ['items'],
      template: '<div><div v-for="item in items" :key="item.id"><slot :item="item" /></div></div>',
    },
  };

  it('retira los 3 mini-botones de tarjetas y un clic abre Ficha Unificada con pestañas Datos | Lotes | Historial', async () => {
    const wrapper = mount(InventoryView, {
      global: { stubs: globalStubs },
    });
    await flushPromises();

    const card = wrapper.find('[data-testid="inventory-card-prod-1"]');
    expect(card.exists()).toBe(true);
    // Ya no existen los 3 mini botones huérfanos en tarjetas
    expect(card.find('button').exists()).toBe(false);
    expect(card.find('button[title="Ver historial"]').exists()).toBe(false);
    expect(card.find('button[title="Ver Lotes (FIFO)"]').exists()).toBe(false);
    // Formato de precio sin doble $
    expect(card.text()).toContain('$ 12.500');
    expect(card.text()).not.toContain('$$');

    await card.trigger('click');
    await flushPromises();

    expect(wrapper.find('[data-testid="ficha-tab-data"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="ficha-tab-batches"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="ficha-tab-kardex"]').exists()).toBe(true);
  });

  it('soporta deep-link ?product=prod-1&tab=batches y permite registrar Merma ($0) enviando batchId', async () => {
    const batchStore = useBatchStore();
    vi.spyOn(batchStore, 'fetchBatchesByProduct').mockImplementation(async () => {
      batchStore.batches = [
        {
          id: 'batch-old',
          product_id: 'prod-1',
          quantity_initial: 5,
          quantity_remaining: 3,
          cost_unit: 8500,
          sale_price: 12500,
          is_active: true,
          created_at: '2026-11-10T10:00:00Z',
          expiration_date: '2026-12-20',
        },
        {
          id: 'batch-new',
          product_id: 'prod-1',
          quantity_initial: 4,
          quantity_remaining: 4,
          cost_unit: 9000,
          sale_price: 12500,
          is_active: true,
          created_at: '2026-11-22T10:00:00Z',
          expiration_date: '2027-02-01',
        },
      ];
      return batchStore.batches;
    });

    const inventoryStore = useInventoryStore();
    const exitSpy = vi.spyOn(inventoryStore, 'registerLogisticExit').mockResolvedValue({
      movementId: 'mov-99',
      productId: 'prod-1',
      batchId: 'batch-new',
      movementType: 'merma',
      quantity: 1,
      newStock: 6,
      unitCost: 9000,
      actorName: 'Admin',
      actorRole: 'owner',
      createdAt: new Date().toISOString(),
    });

    mockRouteQuery.value = { product: 'prod-1', tab: 'batches' };
    const wrapper = mount(InventoryView, {
      global: { stubs: globalStubs },
    });
    await flushPromises();

    // Pestaña Lotes abierta directamente vía deep-link
    const openExitBtn = wrapper.find('[data-testid="open-batch-exit-btn"]');
    expect(openExitBtn.exists()).toBe(true);

    await openExitBtn.trigger('click');
    await flushPromises();

    // Elegir el segundo lote en estantería ('batch-new')
    await wrapper.find('[data-testid="shelf-batch-option-1"]').trigger('click');
    await wrapper.find('textarea').setValue('Bolsa perforada en depósito');
    await wrapper.find('[data-testid="confirm-batch-exit-btn"]').trigger('click');
    await flushPromises();

    expect(exitSpy).toHaveBeenCalledWith(
      expect.objectContaining({
        productId: 'prod-1',
        movementType: 'merma',
        quantity: 1,
        reason: 'Bolsa perforada en depósito',
        direction: 'negative',
        batchId: 'batch-new',
      })
    );
  });
});

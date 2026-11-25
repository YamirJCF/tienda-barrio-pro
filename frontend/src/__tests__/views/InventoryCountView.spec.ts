import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import Decimal from 'decimal.js';
import InventoryCountView from '../../views/InventoryCountView.vue';
import { useInventoryStore } from '../../stores/inventory';
import { useAuthStore } from '../../stores/auth';
import { useCashRegisterStore } from '../../stores/cashRegister';
import { productRepository } from '../../data/repositories/productRepository';

enableAutoUnmount(afterEach);

const { mockPush, mockShowSuccess, mockGetQueueSize, mockProcessSyncQueue } = vi.hoisted(() => ({
  mockPush: vi.fn(),
  mockShowSuccess: vi.fn(),
  mockGetQueueSize: vi.fn(),
  mockProcessSyncQueue: vi.fn(),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mockPush, back: vi.fn() }),
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

vi.mock('../../data/syncQueue', () => ({
  getQueueSize: mockGetQueueSize,
  processSyncQueue: mockProcessSyncQueue,
  getPendingMovements: vi.fn().mockResolvedValue([]),
}));

vi.mock('../../data/supabaseClient', () => ({
  isSupabaseConfigured: () => true,
  isAuditMode: () => false,
  getSupabaseClient: () => null,
}));

const globalStubs = {
  teleport: true,
};

describe('InventoryCountView.vue — Inventariado Físico con Caja Cerrada (WO-OLA2-C3-002)', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    localStorage.clear();
    Object.defineProperty(navigator, 'onLine', { value: true, configurable: true });
    mockGetQueueSize.mockResolvedValue(0);
    mockProcessSyncQueue.mockResolvedValue({ processed: 0, failed: 0 });

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

    const cashStore = useCashRegisterStore();
    cashStore.currentSession = null;

    const inventoryStore = useInventoryStore();
    inventoryStore.products = [
      {
        id: 'prod-1',
        storeId: 'store-1',
        name: 'Arroz 1kg',
        plu: '101',
        category: 'Granos',
        price: new Decimal(3500),
        cost: new Decimal(2200),
        stock: new Decimal(10),
        minStock: 2,
        measurementUnit: 'un',
        isWeighable: false,
        isActive: true,
      } as any,
      {
        id: 'prod-2',
        storeId: 'store-1',
        name: 'Aceite 1L',
        plu: '102',
        category: 'Aceites',
        price: new Decimal(9500),
        cost: new Decimal(7000),
        stock: new Decimal(9),
        minStock: 2,
        measurementUnit: 'un',
        isWeighable: false,
        isActive: true,
      } as any,
    ];
    vi.spyOn(inventoryStore, 'initialize').mockResolvedValue(undefined);
  });

  it('(a) muestra Compuerta F bloqueante si la caja está abierta y navega a /cash-control', async () => {
    vi.spyOn(productRepository, 'getStoreActiveBatchesStatus').mockResolvedValue({
      hasOpenCashSession: true,
      batches: [],
    });

    const wrapper = mount(InventoryCountView, { global: { stubs: globalStubs } });
    await flushPromises();

    const gate = wrapper.find('[data-testid="gate-open-cash"]');
    expect(gate.exists()).toBe(true);
    expect(gate.text()).toContain('Cierra la Caja Antes de Inventariar');

    await wrapper.find('[data-testid="go-close-cash-btn"]').trigger('click');
    expect(mockPush).toHaveBeenCalledWith('/cash-control');
  });

  it('(b) muestra Compuerta F bloqueante cuando hay cola offline pendiente (syncQueue > 0) y permite Sincronizar ahora', async () => {
    mockGetQueueSize.mockResolvedValueOnce(2).mockResolvedValueOnce(0);
    vi.spyOn(productRepository, 'getStoreActiveBatchesStatus').mockResolvedValue({
      hasOpenCashSession: false,
      batches: [],
    });

    const wrapper = mount(InventoryCountView, { global: { stubs: globalStubs } });
    await flushPromises();

    const gate = wrapper.find('[data-testid="gate-pending-sync"]');
    expect(gate.exists()).toBe(true);
    expect(gate.text()).toContain('2');

    await wrapper.find('[data-testid="sync-now-btn"]').trigger('click');
    await flushPromises();

    expect(mockProcessSyncQueue).toHaveBeenCalledTimes(1);
    expect(wrapper.find('[data-testid="gate-pending-sync"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="count-card-prod-1"]').exists()).toBe(true);
  });

  it('(c) falla cerrado con banner N3 y botón Reintentar si falla la verificación inicial en servidor', async () => {
    vi.spyOn(productRepository, 'getStoreActiveBatchesStatus').mockRejectedValue(
      new Error('RPC_TIMEOUT: Servidor ocupado')
    );

    const wrapper = mount(InventoryCountView, { global: { stubs: globalStubs } });
    await flushPromises();

    const errBanner = wrapper.find('[data-testid="count-precondition-error"]');
    expect(errBanner.exists()).toBe(true);
    expect(errBanner.text()).toContain('RPC_TIMEOUT');
    expect(wrapper.find('[data-testid="count-card-prod-1"]').exists()).toBe(false);
  });

  it('(d) flujo feliz con caja cerrada: botón ✓ Igual, 1 lote oculta selector vs 2 lotes muestra BatchShelfSelector, envía RPC y limpia borrador', async () => {
    vi.spyOn(productRepository, 'getStoreActiveBatchesStatus').mockResolvedValue({
      hasOpenCashSession: false,
      batches: [
        // prod-1 tiene 1 solo lote activo
        {
          id: 'b-p1-1',
          product_id: 'prod-1',
          quantity_initial: 10,
          quantity_remaining: 10,
          cost_unit: 2200,
          sale_price: 3500,
          is_active: true,
          created_at: '2026-11-10T10:00:00Z',
          expiration_date: null,
        },
        // prod-2 tiene 2 lotes activos
        {
          id: 'b-p2-old',
          product_id: 'prod-2',
          quantity_initial: 5,
          quantity_remaining: 5,
          cost_unit: 6500,
          sale_price: 9500,
          is_active: true,
          created_at: '2026-11-05T10:00:00Z',
          expiration_date: '2026-12-20',
        },
        {
          id: 'b-p2-new',
          product_id: 'prod-2',
          quantity_initial: 4,
          quantity_remaining: 4,
          cost_unit: 7000,
          sale_price: 9500,
          is_active: true,
          created_at: '2026-11-22T10:00:00Z',
          expiration_date: '2027-02-01',
        },
      ],
    });

    const inventoryStore = useInventoryStore();
    const applySpy = vi.spyOn(inventoryStore, 'applyPhysicalInventoryCount').mockResolvedValue({
      verifiedTotal: 2,
      unchangedCount: 1,
      adjustedCount: 1,
      shortagesCount: 1,
      surplusesCount: 0,
    });

    const wrapper = mount(InventoryCountView, { global: { stubs: globalStubs } });
    await flushPromises();

    // Producto 1 (1 lote): marcar Igual con 1 toque -> NO muestra BatchShelfSelector
    await wrapper.find('[data-testid="btn-equal-prod-1"]').trigger('click');
    // También probar diferencia en prod-1 sigue sin mostrar BatchShelfSelector (<= 1 lote)
    const card1 = wrapper.find('[data-testid="count-card-prod-1"]');
    await card1.find('[data-testid="input-counted-prod-1"]').setValue(8);
    await flushPromises();
    expect(card1.find('[data-testid="batch-shelf-selector"]').exists()).toBe(false);
    // Volver prod-1 a Igual con 1 toque
    await wrapper.find('[data-testid="btn-equal-prod-1"]').trigger('click');
    await flushPromises();

    // Producto 2 (2 lotes): contar 7 (faltan 2) -> SÍ muestra BatchShelfSelector y elegimos lote 2
    const card2 = wrapper.find('[data-testid="count-card-prod-2"]');
    await card2.find('[data-testid="input-counted-prod-2"]').setValue(7);
    await flushPromises();

    const selector2 = card2.find('[data-testid="batch-shelf-selector"]');
    expect(selector2.exists()).toBe(true);
    await card2.find('[data-testid="shelf-batch-option-1"]').trigger('click');
    await flushPromises();

    // Verificar persistencia de borrador en localStorage
    expect(localStorage.getItem('tienda-inventory-count-draft:store-1')).not.toBeNull();

    // Abrir modal y confirmar
    await wrapper.find('[data-testid="review-count-btn"]').trigger('click');
    await flushPromises();
    await wrapper.find('[data-testid="confirm-apply-count-btn"]').trigger('click');
    await flushPromises();

    expect(applySpy).toHaveBeenCalledTimes(1);
    expect(applySpy).toHaveBeenCalledWith(
      expect.objectContaining({
        items: [
          { productId: 'prod-1', countedQuantity: 10, batchId: null },
          { productId: 'prod-2', countedQuantity: 7, batchId: 'b-p2-new' },
        ],
      })
    );

    // Borrador limpiado y recibo mostrado
    expect(localStorage.getItem('tienda-inventory-count-draft:store-1')).toBeNull();
    expect(wrapper.find('[data-testid="inventory-count-receipt"]').exists()).toBe(true);
    expect(mockShowSuccess).toHaveBeenCalled();
  });

  it('(e) usa la verdad del servidor: si hasOpenCashSession es false pero cashStore.currentSession local seguía open, NO bloquea y reconcilia caché local', async () => {
    const cashStore = useCashRegisterStore();
    cashStore.currentSession = {
      id: 'sess-stale',
      storeId: 'store-1',
      status: 'open',
      openingBalance: new Decimal(50000),
      openedAt: new Date().toISOString(),
    } as any;
    const syncSpy = vi.spyOn(cashStore, 'syncFromBackend').mockResolvedValue(false as any);

    vi.spyOn(productRepository, 'getStoreActiveBatchesStatus').mockResolvedValue({
      hasOpenCashSession: false,
      batches: [],
    });

    const wrapper = mount(InventoryCountView, { global: { stubs: globalStubs } });
    await flushPromises();

    expect(wrapper.find('[data-testid="gate-open-cash"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="count-card-prod-1"]').exists()).toBe(true);
    expect(syncSpy).toHaveBeenCalledWith('store-1');
  });
});

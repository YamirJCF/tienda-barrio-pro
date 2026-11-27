import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { Decimal } from 'decimal.js';
import POSView from '../../views/POSView.vue';
import PersonalWithdrawalModal from '../../components/sales/PersonalWithdrawalModal.vue';
import { useInventoryStore } from '../../stores/inventory';
import { useCashRegisterStore } from '../../stores/cashRegister';
import { useAuthStore } from '../../stores/auth';
import { useCartStore } from '../../stores/cart';
import { saleRepository } from '../../data/repositories/saleRepository';
import { addToSyncQueue } from '../../data/syncQueue';

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
  useRoute: () => ({ query: {} }),
}));

vi.mock('../../composables/useNotifications', () => ({
  useNotifications: () => ({
    showSuccess: vi.fn(),
    showError: vi.fn(),
    showWarning: vi.fn(),
    showSaleSuccess: vi.fn(),
    showInfo: vi.fn(),
  }),
}));

vi.mock('../../composables/useHeartbeat', () => ({
  useHeartbeat: () => ({
    isPaused: { value: false },
    setPause: vi.fn(),
  }),
}));

vi.mock('../../data/syncQueue', () => ({
  addToSyncQueue: vi.fn().mockResolvedValue(true),
}));

vi.mock('../../data/supabaseClient', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../../data/supabaseClient')>();
  return {
    ...actual,
    isSupabaseConfigured: () => true,
    getSupabaseClient: () => ({
      rpc: vi.fn(),
      from: vi.fn(),
      channel: vi.fn(() => ({
        on: vi.fn().mockReturnThis(),
        subscribe: vi.fn().mockReturnValue({}),
      })),
      removeChannel: vi.fn(),
    }),
  };
});

enableAutoUnmount(afterEach);

describe('POSView.vue, PersonalWithdrawalModal y saleRepository — Hardening C1 (UX-ADR-007)', () => {
  const storeId = 'store-1';

  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
    vi.clearAllMocks();
    Object.defineProperty(window.navigator, 'onLine', { value: true, configurable: true });

    const authStore = useAuthStore();
    authStore.currentUser = {
      id: 'owner-1',
      name: 'Dueño POS',
      email: 'owner@test.com',
      type: 'admin',
      storeId,
    } as any;
    authStore.currentStore = { id: storeId, name: 'Tienda Test' } as any;

    const cashStore = useCashRegisterStore();
    cashStore.currentSession = {
      id: 'sess-1',
      storeId,
      employeeId: 'owner-1',
      status: 'open',
      openingTime: new Date().toISOString(),
      openingBalance: new Decimal(50000),
      transactions: [],
    } as any;
    vi.spyOn(cashStore, 'syncFromBackend').mockResolvedValue(true);
  });

  const mountPOS = () =>
    mount(POSView, {
      global: {
        stubs: {
          teleport: true,
          CheckoutModal: true,
          RefundModal: true,
          ProductSearchModal: true,
          WeightCalculatorModal: true,
          ForceSaleModal: true,
          SyncIndicator: true,
          BaseButton: { props: ['disabled', 'loading'], template: '<button :disabled="disabled"><slot /></button>' },
        },
      },
    });

  it('C1-H3 (Regla 3): NO muestra Sin Inventario cuando error de carga o isLoading están activos; muestra banner N3 con Reintentar', async () => {
    const inventoryStore = useInventoryStore();
    inventoryStore.products = [];
    inventoryStore.isLoading = true;
    inventoryStore.error = null;
    inventoryStore.initialized = false;
    const initSpy = vi.spyOn(inventoryStore, 'initialize').mockResolvedValue(undefined);

    const wrapper = mountPOS();
    await flushPromises();

    // Mientras carga, NO aparece "Sin Inventario"
    expect(wrapper.text()).not.toContain('Sin Inventario');

    // Simular fallo de carga con totalProducts === 0
    inventoryStore.isLoading = false;
    inventoryStore.initialized = false;
    inventoryStore.error = 'Error de red consultando catálogo';
    await flushPromises();

    expect(wrapper.text()).not.toContain('Sin Inventario');
    const errorBanner = wrapper.find('[data-testid="pos-inventory-error-banner"]');
    expect(errorBanner.exists()).toBe(true);
    expect(errorBanner.text()).toContain('Error de red consultando catálogo');

    await wrapper.get('[data-testid="pos-inventory-retry-btn"]').trigger('click');
    expect(initSpy).toHaveBeenCalledWith(undefined, true);

    // Solo cuando initialized=true && !isLoading && !error && totalProducts===0 aparece Sin Inventario
    inventoryStore.error = null;
    inventoryStore.initialized = true;
    await flushPromises();
    expect(wrapper.text()).toContain('Sin Inventario');
  });

  it('C1-H4: Clear Ticket limpia carrito, muestra barra Undo N2 y restaura en 1 toque o expira a los 6s', async () => {
    vi.useFakeTimers();
    try {
      const inventoryStore = useInventoryStore();
      inventoryStore.products = [{ id: 'p-1', name: 'Pan', price: new Decimal(2000), stock: new Decimal(5), measurementUnit: 'un', minStock: 1, storeId } as any];
      inventoryStore.initialized = true;
      vi.spyOn(inventoryStore, 'initialize').mockResolvedValue(undefined);

      const cartStore = useCartStore();
      cartStore.items = [
        { id: 'p-1', name: 'Pan', price: new Decimal(2000), quantity: new Decimal(2), measurementUnit: 'un', subtotal: new Decimal(4000) },
      ];

      const wrapper = mountPOS();
      await flushPromises();

      expect(wrapper.findAll('[data-testid="pos-cart-item"]')).toHaveLength(1);
      await wrapper.get('[data-testid="pos-clear-ticket-btn"]').trigger('click');

      expect(cartStore.items).toHaveLength(0);
      const undoBanner = wrapper.find('[data-testid="pos-clear-undo-banner"]');
      expect(undoBanner.exists()).toBe(true);

      await wrapper.get('[data-testid="pos-undo-clear-btn"]').trigger('click');
      expect(cartStore.items).toHaveLength(1);
      expect(cartStore.items[0].subtotal?.toNumber()).toBe(4000);
      expect(wrapper.find('[data-testid="pos-clear-undo-banner"]').exists()).toBe(false);

      // Limpiar de nuevo y verificar cierre automático al agregar un ítem nuevo
      await wrapper.get('[data-testid="pos-clear-ticket-btn"]').trigger('click');
      expect(wrapper.find('[data-testid="pos-clear-undo-banner"]').exists()).toBe(true);
      cartStore.items.push({
        id: 'p-1',
        name: 'Pan',
        price: new Decimal(2000),
        quantity: new Decimal(1),
        measurementUnit: 'un',
        subtotal: new Decimal(2000),
      });
      await flushPromises();
      expect(wrapper.find('[data-testid="pos-clear-undo-banner"]').exists()).toBe(false);

      // Limpiar de nuevo y verificar expiración a los 6000ms
      await wrapper.get('[data-testid="pos-clear-ticket-btn"]').trigger('click');
      expect(wrapper.find('[data-testid="pos-clear-undo-banner"]').exists()).toBe(true);
      vi.advanceTimersByTime(6050);
      await flushPromises();
      expect(wrapper.find('[data-testid="pos-clear-undo-banner"]').exists()).toBe(false);
    } finally {
      vi.useRealTimers();
    }
  });

  it('C1-H2: habilita Retiro $0 con carrito lleno y bloquea PersonalWithdrawalModal en modo offline', async () => {
    const inventoryStore = useInventoryStore();
    inventoryStore.products = [{ id: 'p-1', name: 'Café', price: new Decimal(3000), stock: new Decimal(5), measurementUnit: 'un', minStock: 1, storeId } as any];
    inventoryStore.initialized = true;
    vi.spyOn(inventoryStore, 'initialize').mockResolvedValue(undefined);

    const cartStore = useCartStore();
    const wrapper = mountPOS();
    await flushPromises();

    // Carrito vacío -> botón Retiro $0 deshabilitado
    const withdrawalBtn = wrapper.get('[data-testid="pos-personal-withdrawal-btn"]');
    expect((withdrawalBtn.element as HTMLButtonElement).disabled).toBe(true);

    cartStore.items = [
      { id: 'p-1', name: 'Café', price: new Decimal(3000), quantity: new Decimal(1), measurementUnit: 'un', subtotal: new Decimal(3000) },
    ];
    await flushPromises();
    expect((withdrawalBtn.element as HTMLButtonElement).disabled).toBe(false);

    await withdrawalBtn.trigger('click');
    await flushPromises();
    expect(wrapper.find('[data-testid="personal-withdrawal-panel"]').exists()).toBe(true);

    // Offline bloquea PersonalWithdrawalModal
    Object.defineProperty(window.navigator, 'onLine', { value: false, configurable: true });
    const offlineWithdrawal = mount(PersonalWithdrawalModal, {
      props: { modelValue: true, total: new Decimal(3000), itemCount: 1 },
      global: { stubs: { UIBaseModal: { template: '<div><slot /></div>' } } },
    });
    await flushPromises();
    expect(offlineWithdrawal.find('[data-testid="personal-withdrawal-offline-alert"]').exists()).toBe(true);
    expect((offlineWithdrawal.get('[data-testid="personal-withdrawal-confirm-btn"]').element as HTMLButtonElement).disabled).toBe(true);
  });

  it('saleRepository.processSale rechaza fiado y consumo_personal en modo offline sin encolar en syncQueue', async () => {
    Object.defineProperty(window.navigator, 'onLine', { value: false, configurable: true });

    const payloadBase = {
      items: [{ productId: 'p-1', productName: 'Pan', quantity: 1, price: 2000, subtotal: 2000 }],
      total: 2000,
    };

    const resFiado = await saleRepository.processSale({ ...payloadBase, paymentMethod: 'fiado', clientId: 'cli-1' }, storeId);
    expect(resFiado.success).toBe(false);
    expect(resFiado.code).toBe('OFFLINE_NOT_ALLOWED');

    const resRetiro = await saleRepository.processSale({ ...payloadBase, total: 0, paymentMethod: 'consumo_personal' }, storeId);
    expect(resRetiro.success).toBe(false);
    expect(resRetiro.code).toBe('OFFLINE_NOT_ALLOWED');

    expect(addToSyncQueue).not.toHaveBeenCalled();
  });

  it('saleRepository.processSale rechaza online paymentMethod "mixed" sin caer a addToSyncQueue (Regla 3)', async () => {
    Object.defineProperty(window.navigator, 'onLine', { value: true, configurable: true });

    const resMixed = await saleRepository.processSale(
      {
        items: [{ productId: 'p-1', productName: 'Pan', quantity: 1, price: 2000, subtotal: 2000 }],
        total: 2000,
        paymentMethod: 'mixed',
      },
      storeId
    );

    expect(resMixed.success).toBe(false);
    expect(resMixed.error).toContain('pago mixto no está permitido');
    expect(addToSyncQueue).not.toHaveBeenCalled();
  });

  it('ARQ-005 / FRD-007-01 R6: botón de Pausa en POS se oculta para Admin y se muestra para empleados', async () => {
    const inventoryStore = useInventoryStore();
    inventoryStore.products = [
      { id: 'p-1', name: 'Pan', price: new Decimal(2000), stock: new Decimal(10), measurementUnit: 'un' } as any,
    ];
    inventoryStore.initialized = true;
    inventoryStore.isLoading = false;
    inventoryStore.error = null;
    vi.spyOn(inventoryStore, 'initialize').mockResolvedValue(undefined);

    // 1. Admin: no ve el botón de pausa de supervisión
    const wrapperAdmin = mountPOS();
    await flushPromises();
    expect(wrapperAdmin.find('[data-testid="pos-pause-btn"]').exists()).toBe(false);
    wrapperAdmin.unmount();

    // 2. Empleado: sí ve el botón de pausa de supervisión
    const authStore = useAuthStore();
    authStore.currentUser = {
      id: 'emp-1',
      employeeId: 'emp-1',
      name: 'Cajero',
      email: 'cajero@test.com',
      type: 'employee',
      storeId,
    } as any;

    const wrapperEmp = mountPOS();
    await flushPromises();
    expect(wrapperEmp.find('[data-testid="pos-pause-btn"]').exists()).toBe(true);
  });
});

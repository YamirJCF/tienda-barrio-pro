import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { ref } from 'vue';
import { Decimal } from 'decimal.js';
import POSView from '../../views/POSView.vue';
import { useCartStore } from '../../stores/cart';

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
  useRoute: () => ({ query: {} }),
}));

vi.mock('../../composables/useNotifications', () => ({
  useNotifications: () => ({
    showSuccess: vi.fn(),
    showError: vi.fn(),
    showWarning: vi.fn(),
  }),
}));

vi.mock('../../composables/useHeartbeat', () => ({
  useHeartbeat: () => ({
    isPaused: ref(false),
    setPause: vi.fn(),
  }),
}));

vi.mock('../../stores/inventory', () => ({
  useInventoryStore: () => ({
    totalProducts: 10,
    products: [],
    initialize: vi.fn(),
    getProductByPLU: vi.fn(),
  }),
}));

vi.mock('../../stores/cashRegister', () => ({
  useCashRegisterStore: () => ({
    isOpen: true,
    syncFromBackend: vi.fn(),
  }),
}));

vi.mock('../../stores/auth', () => ({
  useAuthStore: () => ({
    canSell: true,
    canFiar: true,
    isAdmin: true,
    currentStore: { id: 'store-1' },
    currentUser: { id: 'user-1', employeeId: 'emp-1', storeId: 'store-1' },
  }),
}));

vi.mock('../../stores/sales', () => ({
  useSalesStore: () => ({
    nextTicketNumber: 33,
    addSale: vi.fn(),
    forceSale: vi.fn(),
  }),
}));

vi.mock('../../stores/clients', () => ({
  useClientsStore: () => ({
    clients: [],
    getClientById: vi.fn(),
  }),
}));

describe('POSView - Tarjetas Compactas y Teclado Plegable (Opción C)', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  const mountPOSView = () => {
    const cartStore = useCartStore();
    cartStore.items = [
      {
        id: 'prod-1',
        name: 'Detodito familiar',
        price: new Decimal(2400),
        quantity: new Decimal(1),
        measurementUnit: 'un',
        isWeighable: false,
      },
      {
        id: 'prod-2',
        name: 'Gaseosa coca-cola',
        price: new Decimal(4000),
        quantity: new Decimal(1),
        measurementUnit: 'un',
        isWeighable: false,
      },
      {
        id: 'prod-3',
        name: 'Queso campesino',
        price: new Decimal(15000),
        quantity: new Decimal(0.51),
        measurementUnit: 'kg',
        isWeighable: true,
        subtotal: new Decimal(7650),
      },
    ];

    const wrapper = mount(POSView, {
      global: {
        stubs: {
          teleport: true,
          CheckoutModal: true,
          ProductSearchModal: true,
          WeightCalculatorModal: true,
          ForceSaleModal: true,
          SyncIndicator: true,
          NoPermissionOverlay: true,
        },
      },
    });

    return { wrapper, cartStore };
  };

  it('muestra el teclado numérico inicialmente y lo oculta/muestra al presionar el handle, manteniendo Total a Pagar y COBRAR visibles', async () => {
    const { wrapper } = mountPOSView();

    const handle = wrapper.find('[data-testid="pos-keypad-handle"]');
    const panel = wrapper.find('[data-testid="pos-keypad-panel"]');
    const totalBar = wrapper.find('[data-testid="pos-total-bar"]');

    expect(handle.exists()).toBe(true);
    expect(panel.exists()).toBe(true);
    expect(handle.attributes('aria-expanded')).toBe('true');
    expect((panel.element as HTMLElement).style.display).not.toBe('none');
    expect(handle.text()).not.toContain('Ocultar');
    expect(handle.text()).not.toContain('Mostrar teclado');
    expect(totalBar.text()).toContain('Total a Pagar');
    expect(totalBar.text()).toContain('$ 14.050');
    expect(wrapper.text()).toContain('COBRAR $ 14.050');

    // Presionar handle para ocultar teclado
    await handle.trigger('click');

    expect(handle.attributes('aria-expanded')).toBe('false');
    expect((panel.element as HTMLElement).style.display).toBe('none');
    expect(handle.text()).not.toContain('Mostrar teclado');
    expect(handle.text()).not.toContain('Ocultar');
    // Total a Pagar y COBRAR siguen visibles
    expect(totalBar.text()).toContain('$ 14.050');
    expect(wrapper.text()).toContain('COBRAR $ 14.050');

    // Presionar nuevamente para volver a desplegar
    await handle.trigger('click');

    expect(handle.attributes('aria-expanded')).toBe('true');
    expect((panel.element as HTMLElement).style.display).not.toBe('none');
  });

  it('oculta el teclado al deslizar hacia abajo (swipe down) y lo despliega al deslizar hacia arriba (swipe up)', async () => {
    const { wrapper } = mountPOSView();

    const handle = wrapper.find('[data-testid="pos-keypad-handle"]');
    const panel = wrapper.find('[data-testid="pos-keypad-panel"]');

    expect((panel.element as HTMLElement).style.display).not.toBe('none');

    // Swipe down (> 25px)
    await handle.trigger('touchstart', { touches: [{ clientY: 500 }] });
    await handle.trigger('touchend', { changedTouches: [{ clientY: 560 }] });

    expect(handle.attributes('aria-expanded')).toBe('false');
    expect((panel.element as HTMLElement).style.display).toBe('none');

    // Swipe up (< -25px)
    await handle.trigger('touchstart', { touches: [{ clientY: 620 }] });
    await handle.trigger('touchend', { changedTouches: [{ clientY: 560 }] });

    expect(handle.attributes('aria-expanded')).toBe('true');
    expect((panel.element as HTMLElement).style.display).not.toBe('none');
  });

  it('conserva toda la información requerida en las tarjetas compactas del carrito y permite eliminar ítems sin colapsar el teclado', async () => {
    const { wrapper, cartStore } = mountPOSView();
    const handle = wrapper.find('[data-testid="pos-keypad-handle"]');
    const panel = wrapper.find('[data-testid="pos-keypad-panel"]');

    const cards = wrapper.findAll('[data-testid="pos-cart-item"]');
    expect(cards).toHaveLength(3);

    expect(cards[0].text()).toContain('x1');
    expect(cards[0].text()).toContain('Detodito familiar');
    expect(cards[0].text()).toContain('$ 2.400 un.');
    expect(cards[0].text()).toContain('$ 2.400');

    expect(cards[2].text()).toContain('x0.51');
    expect(cards[2].text()).toContain('Queso campesino');
    expect(cards[2].text()).toContain('$ 15.000 kg.');
    expect(cards[2].text()).toContain('$ 7.650');

    const removeBtn = cards[1].find('button[aria-label="Remove item"]');
    expect(removeBtn.exists()).toBe(true);
    await removeBtn.trigger('click');

    expect(cartStore.items).toHaveLength(2);
    expect(wrapper.findAll('[data-testid="pos-cart-item"]')).toHaveLength(2);
    expect(handle.attributes('aria-expanded')).toBe('true');
    expect((panel.element as HTMLElement).style.display).not.toBe('none');
  });

  it('oculta el teclado al presionar una tarjeta de producto del carrito', async () => {
    const { wrapper } = mountPOSView();
    const handle = wrapper.find('[data-testid="pos-keypad-handle"]');
    const panel = wrapper.find('[data-testid="pos-keypad-panel"]');
    const cards = wrapper.findAll('[data-testid="pos-cart-item"]');

    expect(handle.attributes('aria-expanded')).toBe('true');
    expect((panel.element as HTMLElement).style.display).not.toBe('none');

    await cards[0].trigger('click');

    expect(handle.attributes('aria-expanded')).toBe('false');
    expect((panel.element as HTMLElement).style.display).toBe('none');
  });

  it('muestra el botón Buscar (junto a Reembolsos para Admin/autorizados) y elimina el botón Nota', () => {
    const { wrapper } = mountPOSView();
    const panel = wrapper.find('[data-testid="pos-keypad-panel"]');
    const buttons = panel.findAll('button');
    const searchBtn = buttons.find((btn) => btn.text().includes('Buscar'));
    const refundsBtn = panel.find('[data-testid="pos-refunds-btn"]');
    const noteBtn = buttons.find((btn) => btn.text().includes('Nota'));

    expect(searchBtn?.exists()).toBe(true);
    expect(searchBtn?.classes()).toContain('flex-1');
    expect(refundsBtn.exists()).toBe(true);
    expect(noteBtn).toBeUndefined();
  });
});

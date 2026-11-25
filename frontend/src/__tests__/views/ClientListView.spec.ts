import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { Decimal } from 'decimal.js';
import ClientListView from '../../views/ClientListView.vue';
import { useAuthStore } from '../../stores/auth';
import { useClientsStore } from '../../stores/clients';

enableAutoUnmount(afterEach);

const { mockPush, mockShowSuccess, mockShowError } = vi.hoisted(() => ({
  mockPush: vi.fn(),
  mockShowSuccess: vi.fn(),
  mockShowError: vi.fn(),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mockPush }),
}));

vi.mock('@/composables/useNotifications', () => ({
  useNotifications: () => ({
    showSuccess: mockShowSuccess,
    showError: mockShowError,
    showWarning: vi.fn(),
    showInfo: vi.fn(),
  }),
}));

vi.mock('@/composables/useCurrencyFormat', () => ({
  useCurrencyFormat: () => ({
    formatCurrency: (v: any) => `$ ${Number(v || 0).toLocaleString('es-CO')}`,
  }),
}));

const globalStubs = {
  BottomNav: true,
  ClientFormModal: true,
  BaseInput: {
    props: ['modelValue', 'placeholder'],
    template: '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
  },
  BaseModal: {
    props: ['modelValue', 'title'],
    template: '<div v-if="modelValue"><slot /><slot name="footer" /></div>',
  },
  BaseButton: {
    props: ['disabled', 'loading'],
    template: '<button :disabled="disabled"><slot /></button>',
  },
  BaseListSkeleton: true,
  BaseEmptyState: true,
};

describe('ClientListView.vue — C4 Autoridad de Deuda Global y Política de Cupo (WO-OLA2-C4-001)', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    Object.defineProperty(navigator, 'onLine', { value: true, configurable: true });

    const authStore = useAuthStore();
    authStore.currentUser = {
      id: 'owner-1',
      name: 'Admin',
      type: 'admin',
      storeId: 'store-1',
      permissions: { canManageInventory: true, canFiar: true, canOpenCloseCash: true, canManageRefunds: true },
    } as any;
    authStore.isAuthenticated = true;
  });

  it('renderiza totalPortfolioDebt autoritativo del servidor sin .reduce() parcial ni border-l-[6px]', async () => {
    const clientsStore = useClientsStore();
    vi.spyOn(clientsStore, 'fetchClientsPage').mockResolvedValue({
      data: [
        {
          id: 'c-1',
          name: 'Ana Mora',
          cc: '10101010',
          totalDebt: new Decimal(20000),
          creditLimit: new Decimal(100000),
          storeId: 'store-1',
        },
      ],
      count: 15,
      totalPortfolioDebt: new Decimal(485000),
      debtorsCount: 9,
    });

    const wrapper = mount(ClientListView, { global: { stubs: globalStubs } });
    await flushPromises();

    // El badge muestra los $485.000 globales del servidor y NO los $20.000 de la página parcial
    const badge = wrapper.get('[data-testid="portfolio-total-debt-badge"]');
    expect(badge.text()).toContain('485.000');
    expect(badge.text()).not.toContain('20.000');
    expect(wrapper.html()).not.toContain('border-l-[6px]');
    expect(wrapper.html()).toContain('tabular-nums');
  });

  it('muestra botón Cupo Global solo a isAdmin, guarda política en BaseModal N2 y muestra error N1 inline sin doble toast', async () => {
    const authStore = useAuthStore();
    const clientsStore = useClientsStore();

    vi.spyOn(clientsStore, 'fetchClientsPage').mockResolvedValue({
      data: [],
      count: 0,
      totalPortfolioDebt: new Decimal(0),
      debtorsCount: 0,
    });
    vi.spyOn(clientsStore, 'getDefaultCreditLimit').mockResolvedValue(90000);
    const updateCupoSpy = vi.spyOn(clientsStore, 'updateGlobalCreditLimit');

    // Empleado canFiar NO ve botón Cupo Global
    authStore.loginAsEmployee(
      {
        id: 'emp-1',
        name: 'Cajero',
        username: '1001',
        permissions: { canManageInventory: false, canFiar: true, canOpenCloseCash: false, canManageRefunds: false },
      },
      'store-1'
    );
    const empWrapper = mount(ClientListView, { global: { stubs: globalStubs } });
    await flushPromises();
    expect(empWrapper.find('[data-testid="open-global-credit-modal-btn"]').exists()).toBe(false);

    // Admin sí ve botón, valida error N1 sin showError, y guarda éxito N2
    authStore.currentUser = {
      id: 'owner-1',
      name: 'Admin',
      type: 'admin',
      storeId: 'store-1',
      permissions: { canManageInventory: true, canFiar: true, canOpenCloseCash: true, canManageRefunds: true },
    } as any;

    const adminWrapper = mount(ClientListView, { global: { stubs: globalStubs } });
    await flushPromises();

    await adminWrapper.get('[data-testid="open-global-credit-modal-btn"]').trigger('click');
    await flushPromises();

    expect((adminWrapper.get('[data-testid="global-credit-limit-input"]').element as HTMLInputElement).value).toBe('90000');

    // Fallo del servidor -> error N1 inline, cero doble toast showError
    updateCupoSpy.mockRejectedValueOnce(new Error('ADMIN_ONLY_ACTION'));
    await adminWrapper.get('[data-testid="global-credit-limit-input"]').setValue(140000);
    await adminWrapper.get('[data-testid="save-global-credit-limit-btn"]').trigger('click');
    await flushPromises();

    expect(adminWrapper.get('[data-testid="global-credit-limit-error"]').text()).toContain('ADMIN_ONLY_ACTION');
    expect(mockShowError).not.toHaveBeenCalled();

    // Éxito -> toast N2 único y cierre
    updateCupoSpy.mockResolvedValueOnce(140000);
    await adminWrapper.get('[data-testid="save-global-credit-limit-btn"]').trigger('click');
    await flushPromises();

    expect(updateCupoSpy).toHaveBeenCalledWith('store-1', 140000);
    expect(mockShowSuccess).toHaveBeenCalledWith('Cupo global por defecto actualizado (aplica a clientes nuevos)');
  });

  it('muestra banner N3 fail-closed con Reintentar si falla fetchClientsPage', async () => {
    const clientsStore = useClientsStore();
    vi.spyOn(clientsStore, 'fetchClientsPage').mockRejectedValueOnce(new Error('Fallo de red C4'));

    const wrapper = mount(ClientListView, { global: { stubs: globalStubs } });
    await flushPromises();

    expect(wrapper.get('[data-testid="clients-error-banner"]').text()).toContain('Fallo de red C4');
  });

  it('bloquea carga sin internet con guardia fail-closed N3 sin mostrar $0 silencioso', async () => {
    Object.defineProperty(navigator, 'onLine', { value: false, configurable: true });
    const clientsStore = useClientsStore();
    const fetchSpy = vi.spyOn(clientsStore, 'fetchClientsPage');

    const wrapper = mount(ClientListView, { global: { stubs: globalStubs } });
    await flushPromises();

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(wrapper.get('[data-testid="clients-error-banner"]').text()).toContain('Sin conexión a internet');
    expect(wrapper.find('[data-testid="portfolio-total-debt-badge"]').exists()).toBe(false);
  });
});

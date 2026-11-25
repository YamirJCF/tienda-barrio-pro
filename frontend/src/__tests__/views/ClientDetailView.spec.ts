import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils';
import ClientDetailView from '../../views/ClientDetailView.vue';
import { createPinia, setActivePinia } from 'pinia';
import { Decimal } from 'decimal.js';
import { reactive, ref } from 'vue';

enableAutoUnmount(afterEach);

// Mock Router
const mockPush = vi.fn();
const mockRoute = reactive<{ params: { id: string }; query: Record<string, string> }>({
  params: { id: 'cli-001' },
  query: {},
});

vi.mock('vue-router', () => ({
  useRouter: () => ({
    push: mockPush
  }),
  useRoute: () => mockRoute
}));

// Mock Clients Store
const mockGetClientById = vi.fn();
const mockGetClientTransactions = vi.fn();
const mockGetClientStatement = vi.fn();
const mockGetAvailableCredit = vi.fn();
const mockDeleteClient = vi.fn();
const mockRegisterPayment = vi.fn();
const useStatementMock = ref(false);

vi.mock('../../stores/clients', () => ({
  useClientsStore: () => ({
    getClientById: mockGetClientById,
    getClientTransactions: mockGetClientTransactions,
    ...(useStatementMock.value ? { getClientStatement: mockGetClientStatement } : {}),
    getAvailableCredit: mockGetAvailableCredit,
    deleteClient: mockDeleteClient,
    registerPayment: mockRegisterPayment
  })
}));

// Mock Auth Store
const mockIsAdmin = ref(true);
const mockCanFiar = ref(true);

vi.mock('../../stores/auth', () => ({
  useAuthStore: () => ({
    get isAdmin() { return mockIsAdmin.value; },
    get canFiar() { return mockCanFiar.value; },
    currentStore: { id: 'store-uuid-1' },
    currentUser: { storeId: 'store-uuid-1' },
  })
}));

// Mock Cash Register Store
const mockSyncFromBackend = vi.fn().mockResolvedValue(true);
const cashMockState = reactive({
  isOpen: true,
  isStaleSession: false,
  syncFromBackend: mockSyncFromBackend,
});

vi.mock('../../stores/cashRegister', () => ({
  useCashRegisterStore: () => cashMockState
}));

const mockShowWarning = vi.fn();
const mockShowSuccess = vi.fn();
const mockShowError = vi.fn();
vi.mock('@/composables/useNotifications', () => ({
  useNotifications: () => ({
    showWarning: mockShowWarning,
    showSuccess: mockShowSuccess,
    showError: mockShowError,
    showInfo: vi.fn()
  })
}));

describe('ClientDetailView.vue', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    mockRoute.params.id = 'cli-001';
    mockRoute.query = {};
    mockIsAdmin.value = true;
    mockCanFiar.value = true;
    useStatementMock.value = false;
    cashMockState.isOpen = true;
    cashMockState.isStaleSession = false;
    mockSyncFromBackend.mockResolvedValue(true);

    // Default mock data
    mockGetClientById.mockReturnValue({
      id: 'cli-001',
      name: 'Maria Perez',
      cc: '10203040',
      phone: '3001234567',
      totalDebt: new Decimal(20000),
      creditLimit: new Decimal(100000),
      storeId: 'store-uuid-1'
    });

    mockGetClientTransactions.mockResolvedValue([
      {
        id: 'tx-001',
        clientId: 'cli-001',
        type: 'purchase',
        amount: new Decimal(20000),
        description: 'Venta #1001',
        date: '2023-01-01T12:00:00Z'
      }
    ]);

    mockGetAvailableCredit.mockReturnValue(new Decimal(80000));
  });

  const createWrapper = () => {
    return mount(ClientDetailView, {
      global: {
        plugins: [createPinia()],
        stubs: {
          BaseModal: {
            props: ['modelValue', 'title', 'showCloseButton'],
            template: `
              <div v-if="modelValue">
                <h3>{{ title }}</h3>
                <slot />
                <slot name="footer" />
              </div>
            `
          },
          BaseInput: {
            template: '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
            props: ['modelValue']
          },
          BaseButton: {
            props: ['disabled', 'loading'],
            template: '<button :disabled="disabled"><slot /></button>'
          },
          BaseListSkeleton: true,
          ClientFormModal: true,
          ChevronLeft: true,
          MoreVertical: true,
          Pencil: true,
          Trash2: true,
          Banknote: true,
          ShoppingCart: true,
          Plus: true,
          AlertTriangle: true,
          Info: true,
        }
      }
    });
  };

  it('renders client details correctly with DESIGN.md tokens and tabular-nums', () => {
    const wrapper = createWrapper();

    expect(wrapper.text()).toContain('Maria Perez');
    expect(wrapper.text()).toContain('C.C. 10.203.040');
    expect(wrapper.text()).toContain('20.000');
    expect(wrapper.text()).toContain('Disponibles: 80.000');
    expect(wrapper.text()).toContain('Total: 100.000');
    expect(wrapper.html()).not.toContain('bg-slate-800 rounded-b-');
    expect(wrapper.html()).not.toContain('bg-gradient-to-r');
    expect(wrapper.html()).toContain('tabular-nums');
  });

  it('hidrata Hero en frío desde statementData.client cuando getClientById es undefined (C4-H3)', async () => {
    useStatementMock.value = true;
    mockGetClientById.mockReturnValue(undefined);
    mockGetAvailableCredit.mockReturnValue(new Decimal(0));
    mockGetClientStatement.mockResolvedValue({
      client: {
        id: 'cli-001',
        name: 'Carlos Hidratado',
        cc: '99887766',
        totalDebt: new Decimal(35000),
        creditLimit: new Decimal(100000),
        creditAvailable: new Decimal(65000),
        storeId: 'store-uuid-1',
      },
      movements: [],
      count: 0,
      generatedAt: '2026-11-25T10:00:00Z',
    });

    const wrapper = createWrapper();
    await flushPromises();

    expect(wrapper.find('[data-testid="client-detail-hero"]').exists()).toBe(true);
    expect(wrapper.text()).toContain('Carlos Hidratado');
    expect(wrapper.text()).toContain('35.000');
    expect(wrapper.text()).toContain('Disponibles: 65.000');
  });

  it('navigates back to clients list when clicking back button', async () => {
    const wrapper = createWrapper();
    const backBtn = wrapper.find('button[aria-label="Volver"]');
    await backBtn.trigger('click');

    expect(mockPush).toHaveBeenCalledWith('/clients');
  });

  it('navigates back to POS with checkoutClientId when opened from POS (query.from === "pos")', async () => {
    mockRoute.query = { from: 'pos' };
    const wrapper = createWrapper();
    const backBtn = wrapper.find('button[aria-label="Volver"]');
    await backBtn.trigger('click');

    expect(mockPush).toHaveBeenCalledWith({
      path: '/pos',
      query: { checkoutClientId: 'cli-001' },
    });
  });

  it('only shows options menu button if user is admin', async () => {
    mockIsAdmin.value = false;
    let wrapper = createWrapper();
    expect(wrapper.find('button[aria-label="Opciones"]').exists()).toBe(false);

    mockIsAdmin.value = true;
    wrapper = createWrapper();
    expect(wrapper.find('button[aria-label="Opciones"]').exists()).toBe(true);
  });

  it('shows debt alert and blocks deletion if client has debt', async () => {
    const wrapper = createWrapper();

    const optionsBtn = wrapper.find('button[aria-label="Opciones"]');
    await optionsBtn.trigger('click');

    const deleteBtn = wrapper.findAll('button').find(b => b.text().includes('Eliminar cliente'));
    expect(deleteBtn).toBeDefined();
    await deleteBtn!.trigger('click');

    expect(wrapper.text()).toContain('Acción Denegada');
    expect(wrapper.text()).toContain('No se puede eliminar a Maria Perez porque tiene una deuda de:');
    expect(mockDeleteClient).not.toHaveBeenCalled();
  });

  it('allows deletion if client has no debt', async () => {
    mockGetClientById.mockReturnValue({
      id: 'cli-001',
      name: 'Maria Perez',
      cc: '10203040',
      phone: '3001234567',
      totalDebt: new Decimal(0),
      creditLimit: new Decimal(100000),
      storeId: 'store-uuid-1'
    });

    mockDeleteClient.mockResolvedValue({ success: true });

    const wrapper = createWrapper();

    const optionsBtn = wrapper.find('button[aria-label="Opciones"]');
    await optionsBtn.trigger('click');

    const deleteBtn = wrapper.findAll('button').find(b => b.text().includes('Eliminar cliente'));
    await deleteBtn!.trigger('click');

    expect(wrapper.text()).toContain('¿Eliminar cliente?');

    const confirmBtn = wrapper.findAll('button').find(b => b.text().includes('Eliminar'));
    await confirmBtn!.trigger('click');
    await flushPromises();

    expect(mockDeleteClient).toHaveBeenCalledWith('cli-001');
    expect(mockPush).toHaveBeenCalledWith('/clients');
  });

  it('renders recent transactions list', async () => {
    const wrapper = createWrapper();
    await flushPromises();

    expect(wrapper.text()).toContain('Historial de Transacciones');
    expect(wrapper.text()).toContain('Venta #1001');
    expect(wrapper.text()).toContain('+20.000');
  });

  it('does NOT redirect and keeps N1 error inside delete modal if server delete fails (no silent failure)', async () => {
    mockIsAdmin.value = true;
    mockGetClientById.mockReturnValue({
      id: 'cli-001',
      name: 'Maria Perez',
      cc: '10203040',
      phone: '3001234567',
      creditLimit: new Decimal(100000),
      totalDebt: new Decimal(0),
      storeId: 'store-uuid-1'
    });
    mockDeleteClient.mockResolvedValue({
      success: false,
      code: 'UNAUTHORIZED',
      error: 'No tienes permisos autorizados'
    });

    const wrapper = createWrapper();
    await flushPromises();

    await wrapper.find('button[aria-label="Opciones"]').trigger('click');
    const deleteBtn = wrapper.findAll('button').find(b => b.text().includes('Eliminar cliente'));
    await deleteBtn?.trigger('click');

    const confirmBtn = wrapper.findAll('button').find(b => b.text().includes('Eliminar'));
    await confirmBtn?.trigger('click');
    await flushPromises();

    expect(mockDeleteClient).toHaveBeenCalledWith('cli-001');
    expect(mockPush).not.toHaveBeenCalledWith('/clients');
    expect(wrapper.get('[data-testid="delete-client-error"]').text()).toContain('No tienes permisos autorizados');
    expect(mockShowError).not.toHaveBeenCalled();
  });

  it('aisla estado al cambiar de clientId y muestra client-detail-error-card si falla el segundo cliente', async () => {
    useStatementMock.value = true;
    mockGetClientById.mockImplementation((id: string) =>
      id === 'cli-001'
        ? {
            id: 'cli-001',
            name: 'Maria Perez',
            cc: '10203040',
            totalDebt: new Decimal(20000),
            creditLimit: new Decimal(100000),
            storeId: 'store-uuid-1',
          }
        : undefined
    );
    mockGetClientStatement
      .mockResolvedValueOnce({
        client: {
          id: 'cli-001',
          name: 'Maria Perez',
          cc: '10203040',
          totalDebt: new Decimal(20000),
          creditLimit: new Decimal(100000),
          creditAvailable: new Decimal(80000),
          storeId: 'store-uuid-1',
        },
        movements: [
          {
            id: 'tx-001',
            clientId: 'cli-001',
            type: 'purchase',
            amount: new Decimal(20000),
            description: 'Venta #1001',
            date: '2026-11-20T12:00:00Z',
          },
        ],
        count: 1,
        generatedAt: '2026-11-25T10:00:00Z',
      })
      .mockRejectedValueOnce(new Error('CLIENT_NOT_FOUND'));

    const wrapper = createWrapper();
    await flushPromises();
    expect(wrapper.text()).toContain('Maria Perez');

    mockRoute.params.id = 'cli-002';
    await flushPromises();

    expect(wrapper.text()).not.toContain('Maria Perez');
    expect(wrapper.find('[data-testid="client-detail-hero"]').exists()).toBe(false);
    expect(wrapper.get('[data-testid="client-detail-error-card"]').text()).toContain('CLIENT_NOT_FOUND');
  });

  it('valida sobre-abono y error RPC en alerta N1 inline (sin showWarning) y sincroniza caja fail-closed', async () => {
    mockRegisterPayment.mockResolvedValue({});
    const wrapper = createWrapper();
    await flushPromises();

    await wrapper.get('[data-testid="register-payment-btn"]').trigger('click');
    await flushPromises();

    expect(mockSyncFromBackend).toHaveBeenCalledWith('store-uuid-1', { throwOnError: true });

    const input = wrapper.find('input');
    const confirmBtn = wrapper.get('[data-testid="confirm-payment-btn"]');

    // Caso 1: Sobre-abono muestra alerta N1 inline, bloquea Confirmar y NO usa showWarning
    await input.setValue('25000');
    expect(wrapper.get('[data-testid="payment-overpayment-alert"]').text()).toContain('El abono no puede superar la deuda actual');
    expect((confirmBtn.element as HTMLButtonElement).disabled).toBe(true);
    expect(mockShowWarning).not.toHaveBeenCalled();
    expect(mockRegisterPayment).not.toHaveBeenCalled();

    // Caso 2: Error del RPC se renderiza en N1 inline sin showWarning
    mockRegisterPayment.mockRejectedValueOnce(new Error('Turno expirado en servidor'));
    await input.setValue('15000');
    expect((confirmBtn.element as HTMLButtonElement).disabled).toBe(false);
    await confirmBtn.trigger('click');
    await flushPromises();

    expect(wrapper.get('[data-testid="payment-modal-error"]').text()).toContain('Turno expirado en servidor');
    expect(mockShowWarning).not.toHaveBeenCalled();

    // Caso 3: Pago válido exitoso
    mockRegisterPayment.mockResolvedValueOnce({});
    await confirmBtn.trigger('click');
    await flushPromises();
    expect(mockRegisterPayment).toHaveBeenCalledWith('cli-001', new Decimal(15000), 'Abono Efectivo', 'efectivo');
  });

  it('muestra banner N3 fail-closed con Reintentar si syncFromBackend falla al abrir modal de abono', async () => {
    mockSyncFromBackend.mockRejectedValueOnce(new Error('NETWORK_DOWN'));
    cashMockState.isOpen = false;

    const wrapper = createWrapper();
    await flushPromises();

    await wrapper.get('[data-testid="register-payment-btn"]').trigger('click');
    await flushPromises();

    expect(wrapper.get('[data-testid="payment-cash-sync-error"]').text()).toContain('NETWORK_DOWN');
    expect(wrapper.find('[data-testid="payment-cash-closed-banner"]').exists()).toBe(false);

    await wrapper.find('input').setValue('10000');
    const confirmBtn = wrapper.get('[data-testid="confirm-payment-btn"]');
    expect((confirmBtn.element as HTMLButtonElement).disabled).toBe(true);

    // Reintentar con caja abierta limpia error y habilita botón
    cashMockState.isOpen = true;
    mockSyncFromBackend.mockResolvedValueOnce(true);
    await wrapper.get('[data-testid="payment-cash-sync-retry-btn"]').trigger('click');
    await flushPromises();

    expect(wrapper.find('[data-testid="payment-cash-sync-error"]').exists()).toBe(false);
    expect((confirmBtn.element as HTMLButtonElement).disabled).toBe(false);
  });
});

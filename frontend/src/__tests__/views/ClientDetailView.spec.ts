import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import ClientDetailView from '../../views/ClientDetailView.vue';
import { createPinia, setActivePinia } from 'pinia';
import { Decimal } from 'decimal.js';
import { ref } from 'vue';

// Mock Router
const mockPush = vi.fn();
const mockRoute = {
  params: { id: 'cli-001' }
};

vi.mock('vue-router', () => ({
  useRouter: () => ({
    push: mockPush
  }),
  useRoute: () => mockRoute
}));

// Mock Clients Store
const mockGetClientById = vi.fn();
const mockGetClientTransactions = vi.fn();
const mockGetAvailableCredit = vi.fn();
const mockDeleteClient = vi.fn();
const mockRegisterPayment = vi.fn();

vi.mock('../../stores/clients', () => ({
  useClientsStore: () => ({
    getClientById: mockGetClientById,
    getClientTransactions: mockGetClientTransactions,
    getAvailableCredit: mockGetAvailableCredit,
    deleteClient: mockDeleteClient,
    registerPayment: mockRegisterPayment
  })
}));

// Mock Auth Store
const mockIsAdmin = ref(true);

vi.mock('../../stores/auth', () => ({
  useAuthStore: () => ({
    get isAdmin() { return mockIsAdmin.value; }
  })
}));

// Mock window.alert
const mockAlert = vi.fn();
vi.stubGlobal('alert', mockAlert);

describe('ClientDetailView.vue', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    mockIsAdmin.value = true;
    
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
            template: `
              <div v-if="modelValue">
                <slot />
                <slot name="footer" />
              </div>
            `,
            props: ['modelValue']
          },
          BaseInput: {
            template: '<input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
            props: ['modelValue']
          },
          BaseButton: {
            template: '<button @click="$emit(\'click\')"><slot /></button>'
          },
          ClientFormModal: true,
          ChevronLeft: true,
          MoreVertical: true,
          Pencil: true,
          Trash2: true,
          Banknote: true,
          ShoppingCart: true,
          Plus: true,
          AlertTriangle: true
        }
      }
    });
  };

  it('renders client details correctly', () => {
    const wrapper = createWrapper();
    
    expect(wrapper.text()).toContain('Maria Perez');
    expect(wrapper.text()).toContain('C.C. 10.203.040');
    expect(wrapper.text()).toContain('$20.000'); // Total debt
    expect(wrapper.text()).toContain('Disponibles: $80.000');
    expect(wrapper.text()).toContain('Total: $100.000');
  });

  it('navigates back to clients list when clicking back button', async () => {
    const wrapper = createWrapper();
    const backBtn = wrapper.find('button[aria-label="Volver"]');
    await backBtn.trigger('click');
    
    expect(mockPush).toHaveBeenCalledWith('/clients');
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
    
    // Simulate opening menu and clicking delete
    const optionsBtn = wrapper.find('button[aria-label="Opciones"]');
    await optionsBtn.trigger('click');
    
    const deleteBtn = wrapper.findAll('button').find(b => b.text().includes('Eliminar cliente'));
    expect(deleteBtn).toBeDefined();
    await deleteBtn!.trigger('click');
    
    // Should show showDebtAlert instead of showDeleteConfirm
    expect(wrapper.text()).toContain('Acción Denegada');
    expect(wrapper.text()).toContain('No se puede eliminar a Maria Perez porque tiene una deuda de:');
    expect(mockDeleteClient).not.toHaveBeenCalled();
  });

  it('allows deletion if client has no debt', async () => {
    // Override mock to return 0 debt
    mockGetClientById.mockReturnValue({
      id: 'cli-001',
      name: 'Maria Perez',
      cc: '10203040',
      phone: '3001234567',
      totalDebt: new Decimal(0),
      creditLimit: new Decimal(100000),
      storeId: 'store-uuid-1'
    });
    
    const wrapper = createWrapper();
    
    const optionsBtn = wrapper.find('button[aria-label="Opciones"]');
    await optionsBtn.trigger('click');
    
    const deleteBtn = wrapper.findAll('button').find(b => b.text().includes('Eliminar cliente'));
    await deleteBtn!.trigger('click');
    
    // Should show delete confirmation modal
    expect(wrapper.text()).toContain('¿Eliminar cliente?');
    
    // Click confirm delete
    const confirmBtn = wrapper.findAll('button').find(b => b.text().includes('Eliminar'));
    await confirmBtn!.trigger('click');
    
    expect(mockDeleteClient).toHaveBeenCalledWith('cli-001');
    expect(mockPush).toHaveBeenCalledWith('/clients');
  });

  it('validates payment registration and registers payment', async () => {
    const wrapper = createWrapper();
    
    // Trigger Register Payment Modal
    const regPaymentBtn = wrapper.findAll('button').find(b => b.text().includes('REGISTRAR ABONO'));
    await regPaymentBtn!.trigger('click');
    
    // Get the input and fill it
    const input = wrapper.find('input');
    
    // Case 1: Overpayment validation
    await input.setValue('25000'); // Greater than debt (20000)
    
    const confirmBtn = wrapper.findAll('button').find(b => b.text().includes('Confirmar'));
    await confirmBtn!.trigger('click');
    
    expect(mockAlert).toHaveBeenCalledWith(
      expect.stringContaining('El abono no puede superar la deuda actual')
    );
    expect(mockRegisterPayment).not.toHaveBeenCalled();
    
    // Case 2: Valid payment
    await input.setValue('15000');
    await confirmBtn!.trigger('click');
    
    expect(mockRegisterPayment).toHaveBeenCalledWith('cli-001', new Decimal(15000), 'Abono Efectivo');
  });
});

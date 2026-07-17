import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount } from '@vue/test-utils';
import ClientDetailView from '@/views/ClientDetailView.vue';
import { Decimal } from 'decimal.js';

// Mocks for Router
const mockPush = vi.fn();
const mockRoute = {
  params: {
    id: 'cli-123'
  }
};
vi.mock('vue-router', () => ({
  useRouter: () => ({
    push: mockPush
  }),
  useRoute: () => mockRoute
}));

// Mocks for Stores
const mockGetClientById = vi.fn();
const mockGetClientTransactions = vi.fn();
const mockGetAvailableCredit = vi.fn();
const mockDeleteClient = vi.fn();
const mockRegisterPayment = vi.fn();

vi.mock('../stores/clients', () => ({
  useClientsStore: () => ({
    getClientById: mockGetClientById,
    getClientTransactions: mockGetClientTransactions,
    getAvailableCredit: mockGetAvailableCredit,
    deleteClient: mockDeleteClient,
    registerPayment: mockRegisterPayment,
  })
}));

let mockIsAdmin = true;
vi.mock('../stores/auth', () => ({
  useAuthStore: () => ({
    isAdmin: mockIsAdmin,
    currentUser: {
      type: mockIsAdmin ? 'admin' : 'employee'
    }
  })
}));

describe('ClientDetailView.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockIsAdmin = true;

    // Default mock returns
    mockGetClientById.mockReturnValue({
      id: 'cli-123',
      name: 'John Doe',
      cc: '1020304050',
      phone: '3001234567',
      creditLimit: new Decimal(500000),
      totalDebt: new Decimal(150000),
      storeId: 'store-uuid-123'
    });

    mockGetClientTransactions.mockResolvedValue([
      {
        id: 'tx-1',
        clientId: 'cli-123',
        type: 'purchase',
        amount: new Decimal(150000),
        description: 'Venta #1001',
        date: '2026-07-16T12:00:00Z'
      }
    ]);

    mockGetAvailableCredit.mockReturnValue(new Decimal(350000));
  });

  const createWrapper = () => {
    return mount(ClientDetailView, {
      global: {
        stubs: {
          BaseModal: {
            props: ['modelValue', 'title'],
            template: `
              <div v-if="modelValue" class="mock-modal">
                <h3>{{ title }}</h3>
                <slot />
                <slot name="footer" />
              </div>
            `
          },
          BaseInput: {
            props: ['modelValue', 'label'],
            template: `
              <div class="mock-input">
                <label>{{ label }}</label>
                <input :value="modelValue" @input="$emit('update:modelValue', $event.target.value)" />
              </div>
            `
          },
          BaseButton: {
            template: `<button @click="$emit('click', $event)"><slot /></button>`
          },
          ClientFormModal: true,
          Teleport: true,
          Transition: true
        }
      }
    });
  };

  it('renders client information correctly', async () => {
    const wrapper = createWrapper();
    // Allow watch and promises to resolve
    await vi.dynamicImportSettled();
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('John Doe');
    expect(wrapper.text()).toContain('C.C. 1.020.304.050');
    expect(wrapper.text()).toContain('$150.000'); // total debt
    expect(wrapper.text()).toContain('Cupo de Crédito');
    expect(wrapper.text()).toContain('Disponibles: $350.000');
  });

  it('renders recent transactions list', async () => {
    const wrapper = createWrapper();
    await vi.dynamicImportSettled();
    await wrapper.vm.$nextTick();
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('Movimientos Recientes');
    expect(wrapper.text()).toContain('Venta #1001');
    expect(wrapper.text()).toContain('+$150.000');
  });

  it('restricts edit access to non-admin roles', async () => {
    mockIsAdmin = false;
    const wrapper = createWrapper();
    await vi.dynamicImportSettled();

    // The options menu button (MoreVertical) shouldn't render
    const moreButton = wrapper.find('button[aria-label="Opciones"]');
    expect(moreButton.exists()).toBe(false);
  });

  it('allows edit access to admin roles', async () => {
    mockIsAdmin = true;
    const wrapper = createWrapper();
    await vi.dynamicImportSettled();

    // The options menu button (MoreVertical) should render
    const moreButton = wrapper.find('button[aria-label="Opciones"]');
    expect(moreButton.exists()).toBe(true);
  });

  it('prevents client deletion if they have outstanding debt', async () => {
    mockIsAdmin = true;
    const wrapper = createWrapper();
    await vi.dynamicImportSettled();

    // Open options menu
    await wrapper.find('button[aria-label="Opciones"]').trigger('click');
    
    // Click delete button
    const deleteBtn = wrapper.findAll('button').find(b => b.text().includes('Eliminar cliente'));
    expect(deleteBtn).toBeDefined();
    await deleteBtn?.trigger('click');

    // Should show debt blocking modal, not delete confirm modal
    expect(wrapper.text()).toContain('Acción Denegada');
    expect(wrapper.text()).toContain('No se puede eliminar a John Doe porque tiene una deuda de:');
    
    // Verify deleteClient was NOT called
    expect(mockDeleteClient).not.toHaveBeenCalled();
  });

  it('allows client deletion if they have zero debt', async () => {
    mockIsAdmin = true;
    // Set client debt to 0
    mockGetClientById.mockReturnValue({
      id: 'cli-123',
      name: 'John Doe',
      cc: '1020304050',
      phone: '3001234567',
      creditLimit: new Decimal(500000),
      totalDebt: new Decimal(0),
      storeId: 'store-uuid-123'
    });

    const wrapper = createWrapper();
    await vi.dynamicImportSettled();

    // Open options menu
    await wrapper.find('button[aria-label="Opciones"]').trigger('click');
    
    // Click delete button
    const deleteBtn = wrapper.findAll('button').find(b => b.text().includes('Eliminar cliente'));
    await deleteBtn?.trigger('click');

    // Should show delete confirm modal
    expect(wrapper.text()).toContain('¿Eliminar cliente?');
    
    // Click confirm delete button
    const confirmBtn = wrapper.findAll('button').find(b => b.text().includes('Eliminar'));
    await confirmBtn?.trigger('click');

    // Verify deleteClient was called and redirected
    expect(mockDeleteClient).toHaveBeenCalledWith('cli-123');
    expect(mockPush).toHaveBeenCalledWith('/clients');
  });

  it('prevents registering a payment that exceeds the outstanding debt', async () => {
    const wrapper = createWrapper();
    await vi.dynamicImportSettled();

    // Click register payment button
    const abonoBtn = wrapper.findAll('button').find(b => b.text().includes('REGISTRAR ABONO'));
    await abonoBtn?.trigger('click');
    
    // Set payment amount exceeding debt (150,000)
    const modal = wrapper.find('.mock-modal');
    expect(modal.exists()).toBe(true);
    
    const input = modal.find('input');
    await input.setValue('160000'); // 160,000 > 150,000

    // Spy on window.alert
    window.alert = vi.fn();

    // Click confirm payment button
    const confirmBtn = modal.findAll('button').find(b => b.text().includes('Confirmar'));
    await confirmBtn?.trigger('click');

    // Should trigger validation alert and not call registerPayment
    expect(window.alert).toHaveBeenCalled();
    expect(mockRegisterPayment).not.toHaveBeenCalled();
  });

  it('allows registering a valid payment amount', async () => {
    const wrapper = createWrapper();
    await vi.dynamicImportSettled();

    // Click register payment button
    const abonoBtn = wrapper.findAll('button').find(b => b.text().includes('REGISTRAR ABONO'));
    await abonoBtn?.trigger('click');
    
    const modal = wrapper.find('.mock-modal');
    const input = modal.find('input');
    await input.setValue('50000'); // 50,000 <= 150,000

    // Click confirm payment button
    const confirmBtn = modal.findAll('button').find(b => b.text().includes('Confirmar'));
    await confirmBtn?.trigger('click');

    // Verify registerPayment was called with correct arguments
    expect(mockRegisterPayment).toHaveBeenCalledWith('cli-123', new Decimal(50000), 'Abono Efectivo');
  });
});

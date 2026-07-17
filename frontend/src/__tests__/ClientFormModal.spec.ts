import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount } from '@vue/test-utils';
import ClientFormModal from '@/components/ClientFormModal.vue';
import { Decimal } from 'decimal.js';

// Define mocks for Clients store
const mockAddClient = vi.fn();
const mockUpdateClient = vi.fn();
const mockGetClientById = vi.fn();

vi.mock('../stores/clients', () => ({
  useClientsStore: () => ({
    addClient: mockAddClient,
    updateClient: mockUpdateClient,
    getClientById: mockGetClientById,
  })
}));

// Define mock state for Auth store
let mockCurrentUser: any = {
  id: 'admin-id',
  name: 'Test Admin',
  email: 'admin@test.com',
  type: 'admin',
  storeId: 'store-uuid-123'
};
let mockCurrentStore: any = {
  id: 'store-uuid-123'
};

vi.mock('../stores/auth', () => ({
  useAuthStore: () => ({
    currentUser: mockCurrentUser,
    currentStore: mockCurrentStore,
    isAdmin: mockCurrentUser?.type === 'admin'
  })
}));

// Mock notifications composable
const mockShowSuccess = vi.fn();
const mockShowError = vi.fn();
vi.mock('../composables/useNotifications', () => ({
  useNotifications: () => ({
    showSuccess: mockShowSuccess,
    showError: mockShowError
  })
}));

describe('ClientFormModal.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockCurrentUser = {
      id: 'admin-id',
      name: 'Test Admin',
      email: 'admin@test.com',
      type: 'admin',
      storeId: 'store-uuid-123'
    };
    mockCurrentStore = {
      id: 'store-uuid-123'
    };
  });

  const createWrapper = (props = {}) => {
    return mount(ClientFormModal, {
      props: {
        modelValue: true,
        ...props
      },
      global: {
        stubs: {
          Teleport: true,
          Transition: true
        }
      }
    });
  };

  it('renders with default title when creating client', () => {
    const wrapper = createWrapper();
    expect(wrapper.text()).toContain('Datos del Cliente');
    expect(wrapper.text()).not.toContain('Editar Cliente');
  });

  it('renders with edit title when editing client', () => {
    mockGetClientById.mockReturnValue({
      id: 'cli-001',
      name: 'Maria Perez',
      cc: '10203040',
      phone: '3001234567',
      creditLimit: new Decimal(100000),
      totalDebt: new Decimal(0),
      storeId: 'store-uuid-123'
    });

    const wrapper = createWrapper({ clientId: 'cli-001' });
    expect(wrapper.text()).toContain('Editar Cliente');
  });

  it('populates form data when editing client', async () => {
    mockGetClientById.mockReturnValue({
      id: 'cli-001',
      name: 'Maria Perez',
      cc: '10203040',
      phone: '3001234567',
      creditLimit: new Decimal(100000),
      totalDebt: new Decimal(0),
      storeId: 'store-uuid-123'
    });

    const wrapper = createWrapper({ clientId: 'cli-001' });
    
    // Check values of inputs
    const inputs = wrapper.findAll('input');
    const nameInput = inputs[0].element as HTMLInputElement;
    const ccInput = inputs[1].element as HTMLInputElement;
    const phoneInput = inputs[2].element as HTMLInputElement;
    const creditInput = inputs[3].element as HTMLInputElement;

    expect(nameInput.value).toBe('Maria Perez');
    expect(ccInput.value).toBe('10203040');
    expect(phoneInput.value).toBe('3001234567');
    expect(creditInput.value).toBe('100000');
  });

  it('disables identification (cc) input when in edit mode', () => {
    mockGetClientById.mockReturnValue({
      id: 'cli-001',
      name: 'Maria Perez',
      cc: '10203040',
      phone: '3001234567',
      creditLimit: new Decimal(100000),
      totalDebt: new Decimal(0),
      storeId: 'store-uuid-123'
    });

    const wrapper = createWrapper({ clientId: 'cli-001' });
    const ccInput = wrapper.findAll('input')[1];
    expect(ccInput.attributes()).toHaveProperty('disabled');
  });

  it('submits successfully when creating a new client', async () => {
    const mockCreatedClient = {
      id: 'new-cli-123',
      name: 'Nuevo Cliente',
      cc: '99988877',
      phone: '3201234567',
      creditLimit: new Decimal(50000),
      totalDebt: new Decimal(0),
      storeId: 'store-uuid-123'
    };
    mockAddClient.mockResolvedValue(mockCreatedClient);

    const wrapper = createWrapper();
    
    // Fill the form
    const inputs = wrapper.findAll('input');
    await inputs[0].setValue('Nuevo Cliente');
    await inputs[1].setValue('99988877');
    await inputs[2].setValue('3201234567');
    await inputs[3].setValue('50000');

    // Trigger save
    const saveButton = wrapper.findAll('button').find(b => b.text().includes('Guardar Cliente'));
    expect(saveButton).toBeDefined();
    await saveButton?.trigger('click');

    // Verify addClient was called with correct arguments
    expect(mockAddClient).toHaveBeenCalledWith({
      name: 'Nuevo Cliente',
      cc: '99988877',
      phone: '3201234567',
      creditLimit: new Decimal(50000),
      storeId: 'store-uuid-123'
    });

    expect(mockShowSuccess).toHaveBeenCalledWith('Cliente creado exitosamente');
    expect(wrapper.emitted('saved')).toBeTruthy();
    expect(wrapper.emitted('saved')?.[0]).toEqual([mockCreatedClient, 'create']);
  });

  it('submits successfully when editing an existing client', async () => {
    mockGetClientById.mockReturnValue({
      id: 'cli-001',
      name: 'Maria Perez',
      cc: '10203040',
      phone: '3001234567',
      creditLimit: new Decimal(100000),
      totalDebt: new Decimal(0),
      storeId: 'store-uuid-123'
    });

    const mockUpdatedClient = {
      id: 'cli-001',
      name: 'Maria Perez Modificada',
      cc: '10203040',
      phone: '3009999999',
      creditLimit: new Decimal(120000),
      totalDebt: new Decimal(0),
      storeId: 'store-uuid-123'
    };
    mockUpdateClient.mockResolvedValue(mockUpdatedClient);

    const wrapper = createWrapper({ clientId: 'cli-001' });

    // Modify form values
    const inputs = wrapper.findAll('input');
    await inputs[0].setValue('Maria Perez Modificada');
    await inputs[2].setValue('3009999999');
    await inputs[3].setValue('120000');

    // Trigger save
    const saveButton = wrapper.findAll('button').find(b => b.text().includes('Guardar Cliente'));
    await saveButton?.trigger('click');

    // Verify updateClient was called with correct arguments
    expect(mockUpdateClient).toHaveBeenCalledWith('cli-001', {
      name: 'Maria Perez Modificada',
      cc: '10203040',
      phone: '3009999999',
      creditLimit: new Decimal(120000)
    });

    expect(mockShowSuccess).toHaveBeenCalledWith('Cambios guardados');
    expect(wrapper.emitted('saved')).toBeTruthy();
    expect(wrapper.emitted('saved')?.[0]).toEqual([mockUpdatedClient, 'update']);
  });

  it('displays error if storeId is missing when creating a client', async () => {
    mockCurrentUser = null;
    mockCurrentStore = null;

    const wrapper = createWrapper();

    const inputs = wrapper.findAll('input');
    await inputs[0].setValue('Nuevo Cliente');
    await inputs[1].setValue('99988877');

    const saveButton = wrapper.findAll('button').find(b => b.text().includes('Guardar Cliente'));
    await saveButton?.trigger('click');

    expect(mockShowError).toHaveBeenCalledWith('Error: No se ha identificado la tienda activa. Recarga la página.');
  });
});

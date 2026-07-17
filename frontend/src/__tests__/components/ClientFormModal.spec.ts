import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import ClientFormModal from '../../components/ClientFormModal.vue';
import { createPinia, setActivePinia } from 'pinia';
import { Decimal } from 'decimal.js';

// Mock the notifications composable
const mockShowSuccess = vi.fn();
const mockShowError = vi.fn();

vi.mock('../../composables/useNotifications', () => ({
  useNotifications: () => ({
    showSuccess: mockShowSuccess,
    showError: mockShowError,
    showInfo: vi.fn(),
    showWarning: vi.fn(),
    dismiss: vi.fn(),
    dismissAll: vi.fn()
  })
}));

// Mock clients store
const mockAddClient = vi.fn();
const mockUpdateClient = vi.fn();
const mockGetClientById = vi.fn();

vi.mock('../../stores/clients', () => ({
  useClientsStore: () => ({
    clients: [
      {
        id: 'cli-001',
        name: 'Juan Perez',
        cc: '12345678',
        phone: '3001234567',
        totalDebt: new Decimal(1000),
        creditLimit: new Decimal(50000),
        storeId: 'store-uuid-1'
      }
    ],
    addClient: mockAddClient,
    updateClient: mockUpdateClient,
    getClientById: mockGetClientById
  })
}));

// Mock auth store variables
let mockCurrentUser: any = {
  id: 'usr-123',
  name: 'Admin User',
  email: 'admin@tienda.com',
  type: 'admin',
  storeId: 'store-uuid-1'
};
let mockCurrentStore: any = { id: 'store-uuid-1' };

vi.mock('../../stores/auth', () => ({
  useAuthStore: () => ({
    get currentUser() { return mockCurrentUser; },
    get currentStore() { return mockCurrentStore; },
    stores: [
      {
        id: 'store-uuid-1',
        storeName: 'Mi Tienda',
        ownerName: 'Admin User',
        email: 'admin@tienda.com'
      }
    ],
    get isAdmin() { return mockCurrentUser?.type === 'admin'; }
  })
}));

describe('ClientFormModal.vue', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    
    // Set default mock implementations
    mockCurrentUser = {
      id: 'usr-123',
      name: 'Admin User',
      email: 'admin@tienda.com',
      type: 'admin',
      storeId: 'store-uuid-1'
    };
    mockCurrentStore = { id: 'store-uuid-1' };
    
    mockGetClientById.mockReturnValue({
      id: 'cli-001',
      name: 'Juan Perez',
      cc: '12345678',
      phone: '3001234567',
      totalDebt: new Decimal(1000),
      creditLimit: new Decimal(50000),
      storeId: 'store-uuid-1'
    });
  });

  const createWrapper = (props = {}) => {
    return mount(ClientFormModal, {
      global: {
        plugins: [createPinia()],
        stubs: {
          Teleport: true
        }
      },
      props: {
        modelValue: true,
        ...props
      }
    });
  };

  it('renders "Datos del Cliente" title in create mode (no clientId)', () => {
    const wrapper = createWrapper();
    expect(wrapper.text()).toContain('Datos del Cliente');
    
    // Cédula input is not disabled in create mode
    const ccInput = wrapper.find('input[type="tel"]');
    expect(ccInput.attributes('disabled')).toBeUndefined();
  });

  it('renders "Editar Cliente" title and disables Cédula input in edit mode (with clientId)', async () => {
    const wrapper = createWrapper({ clientId: 'cli-001' });
    
    expect(wrapper.text()).toContain('Editar Cliente');
    
    const nameInput = wrapper.find('input[placeholder="Ej. María Pérez"]');
    expect((nameInput.element as HTMLInputElement).value).toBe('Juan Perez');
    
    const ccInput = wrapper.find('input[type="tel"]');
    expect((ccInput.element as HTMLInputElement).value).toBe('12345678');
    expect(ccInput.element.hasAttribute('disabled')).toBe(true);
  });

  it('validates fields and disables save button when name or cc is empty', async () => {
    const wrapper = createWrapper();
    
    const saveButton = wrapper.find('button.bg-primary');
    expect(saveButton.element.hasAttribute('disabled')).toBe(true);
    
    // Fill fields
    const inputs = wrapper.findAll('input');
    const nameInput = inputs[0]; // Name
    const ccInput = inputs[1]; // CC/Cédula
    
    await nameInput.setValue('Nico Gomez');
    await ccInput.setValue('98765432');
    
    expect(saveButton.element.hasAttribute('disabled')).toBe(false);
  });

  it('calls addClient with active storeId in create mode', async () => {
    mockAddClient.mockResolvedValue({ id: 'new-cli-123' });
    const wrapper = createWrapper();
    
    // Fill fields
    const inputs = wrapper.findAll('input');
    await inputs[0].setValue('Nico Gomez');
    await inputs[1].setValue('98765432');
    await inputs[2].setValue('3009876543'); // Phone
    await inputs[3].setValue('100000'); // Credit limit
    
    const saveButton = wrapper.find('button.bg-primary');
    await saveButton.trigger('click');
    
    expect(mockAddClient).toHaveBeenCalledWith({
      name: 'Nico Gomez',
      cc: '98765432',
      phone: '3009876543',
      creditLimit: new Decimal(100000),
      storeId: 'store-uuid-1'
    });
  });

  it('shows error notification when active storeId cannot be resolved in create mode', async () => {
    mockCurrentUser = null;
    mockCurrentStore = null;

    const wrapper = createWrapper();

    const inputs = wrapper.findAll('input');
    await inputs[0].setValue('Nico Gomez');
    await inputs[1].setValue('98765432');

    const saveButton = wrapper.find('button.bg-primary');
    await saveButton.trigger('click');

    expect(mockShowError).toHaveBeenCalledWith(
      expect.stringContaining('No se ha identificado la tienda activa')
    );
  });

  it('calls updateClient in edit mode', async () => {
    mockUpdateClient.mockResolvedValue({ id: 'cli-001' });
    const wrapper = createWrapper({ clientId: 'cli-001' });
    
    // Modify name and limit
    const inputs = wrapper.findAll('input');
    await inputs[0].setValue('Juan Perez Editado');
    await inputs[3].setValue('60000');
    
    const saveButton = wrapper.find('button.bg-primary');
    await saveButton.trigger('click');
    
    expect(mockUpdateClient).toHaveBeenCalledWith('cli-001', {
      name: 'Juan Perez Editado',
      cc: '12345678',
      phone: '3001234567',
      creditLimit: new Decimal(60000)
    });
  });
});

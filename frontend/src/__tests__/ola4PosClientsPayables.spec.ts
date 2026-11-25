import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import Decimal from 'decimal.js';
import { useAuthStore } from '../stores/auth';
import { useConfigStore } from '../stores/config';
import { useEmployeesStore } from '../stores/employees';
import { useClientsStore } from '../stores/clients';
import { usePayablesStore } from '../stores/payables';
import { saleRepository } from '../data/repositories/saleRepository';
import { clientRepository } from '../data/repositories/clientRepository';
import CheckoutModal from '../components/sales/CheckoutModal.vue';
import PersonalWithdrawalModal from '../components/sales/PersonalWithdrawalModal.vue';
import SaleDetailModal from '../components/history/SaleDetailModal.vue';
import ClientListView from '../views/ClientListView.vue';
import ClientDetailView from '../views/ClientDetailView.vue';
import ClientFormModal from '../components/ClientFormModal.vue';
import AdminHubView from '../views/AdminHubView.vue';
import PayInvoiceModal from '../components/suppliers/PayInvoiceModal.vue';
import SuppliersView from '../views/SuppliersView.vue';

const {
  mockRpc,
  mockFrom,
  mockPush,
  mockShowError,
  mockShowSuccess,
  mockShowWarning,
  cashMockState,
  idbPutSpy,
} = vi.hoisted(() => ({
  mockRpc: vi.fn(),
  mockFrom: vi.fn(),
  mockPush: vi.fn(),
  mockShowError: vi.fn(),
  mockShowSuccess: vi.fn(),
  mockShowWarning: vi.fn(),
  idbPutSpy: vi.fn().mockResolvedValue(undefined),
  cashMockState: {
    isOpen: true,
    isStaleSession: false,
    currentBalance: 100000,
    balancesByMethod: {
      efectivo: 100000,
      nequi: 5000,
      llave_bre: 0,
    } as Record<string, number>,
  },
}));

vi.mock('idb', () => ({
  openDB: vi.fn().mockResolvedValue({
    count: vi.fn().mockResolvedValue(0),
    put: (...args: any[]) => idbPutSpy(...args),
    getAll: vi.fn().mockResolvedValue([]),
  }),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mockPush, replace: vi.fn(), back: vi.fn() }),
  useRoute: () => ({ path: '/suppliers', params: { id: 'cli-1' }, query: { tab: 'payables' } }),
}));

vi.mock('../data/supabaseClient', () => ({
  getSupabaseClient: () => ({
    rpc: (...args: any[]) => mockRpc(...args),
    from: (...args: any[]) => mockFrom(...args),
  }),
  requireSupabase: () => ({
    rpc: (...args: any[]) => mockRpc(...args),
    from: (...args: any[]) => mockFrom(...args),
  }),
  isSupabaseConfigured: () => true,
  isAuditMode: () => false,
}));

vi.mock('@/lib/supabase', () => ({
  supabase: {
    rpc: (...args: any[]) => mockRpc(...args),
    from: (...args: any[]) => mockFrom(...args),
  },
}));

vi.mock('vue-toastification', () => ({
  useToast: () => ({
    success: mockShowSuccess,
    error: mockShowError,
    warning: mockShowWarning,
  }),
}));

vi.mock('../composables/useNotifications', () => ({
  useNotifications: () => ({
    showError: mockShowError,
    showSuccess: mockShowSuccess,
    showWarning: mockShowWarning,
  }),
}));

vi.mock('../composables/useCurrencyFormat', () => ({
  useCurrencyFormat: () => ({
    formatCurrency: (v: any) => String(v ?? 0),
    formatWithSign: (v: any) => `$ ${String(v ?? 0)}`,
  }),
}));

vi.mock('../stores/cashRegister', () => ({
  useCashRegisterStore: () => ({
    get isOpen() {
      return cashMockState.isOpen;
    },
    get isStaleSession() {
      return cashMockState.isStaleSession;
    },
    get currentBalance() {
      return cashMockState.currentBalance;
    },
    get balancesByMethod() {
      return cashMockState.balancesByMethod;
    },
    currentSession: { id: '11111111-1111-4111-8111-111111111111', openingBalance: new Decimal(50000) },
    transactions: [],
  }),
}));

vi.mock('../stores/suppliers', () => ({
  useSuppliersStore: () => ({
    suppliers: [{ id: 'sup-1', name: 'Distribuidora' }],
    isLoading: false,
    error: null,
    fetchSuppliers: vi.fn().mockResolvedValue([]),
    fetchSuppliersWithPayables: vi.fn().mockResolvedValue([]),
  }),
}));

const STORE_ID = '22222222-2222-4222-8222-222222222222';
const SESSION_ID = '11111111-1111-4111-8111-111111111111';
const EMP_UUID = '33333333-3333-4333-8333-333333333333';
const CLIENT_UUID = '44444444-4444-4444-8444-444444444444';

function setAdminSession(authStore: ReturnType<typeof useAuthStore>) {
  authStore.currentUser = {
    id: 'owner-1',
    name: 'Dueño Tienda',
    email: 'owner@tienda.co',
    type: 'admin',
    storeId: STORE_ID,
    permissions: { canManageInventory: true, canFiar: true, canOpenCloseCash: true, canManageRefunds: true },
  } as any;
  authStore.isAuthenticated = true;
}

function setEmployeeSession(authStore: ReturnType<typeof useAuthStore>, canFiar: boolean) {
  authStore.loginAsEmployee(
    {
      id: EMP_UUID,
      name: 'Laura Cajera',
      username: '1001',
      permissions: { canManageInventory: false, canFiar, canOpenCloseCash: false, canManageRefunds: false },
    },
    STORE_ID,
  );
}

describe('Fase 3 Ola 4 — POS, Retiro Personal $0, Clientes canFiar y CxP Admin-Only', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    Object.defineProperty(navigator, 'onLine', { value: true, configurable: true });
    cashMockState.isOpen = true;
    cashMockState.isStaleSession = false;
    cashMockState.currentBalance = 100000;
    cashMockState.balancesByMethod = { efectivo: 100000, nequi: 5000, llave_bre: 0 };
    mockRpc.mockResolvedValue({ data: { status: 'approved', pass_id: 'p-1', retry_count: 0 }, error: null });
  });

  it('[CHK-401][CHK-403][CHK-404] saleRepository sanitiza p_client_id en no-fiado, envía p_origin_session_id/p_sold_by/p_beneficiary_employee_id y mapea PERMISSION_DENIED', async () => {
    mockRpc.mockResolvedValueOnce({
      data: { success: true, data: { sale_id: 'sale-retiro-1', ticket_number: 45, total: 0 } },
      error: null,
    });

    const okRes = await saleRepository.processSale(
      {
        items: [{ productId: 'prod-1', productName: 'Café', quantity: 1, price: 5000, subtotal: 5000 }],
        total: 0,
        paymentMethod: 'consumo_personal',
        clientId: CLIENT_UUID, // debe sanitizarse a null (CHK-403)
        employeeId: EMP_UUID,
        originSessionId: SESSION_ID,
        beneficiaryEmployeeId: EMP_UUID,
      },
      STORE_ID,
    );

    expect(okRes.success).toBe(true);
    expect(okRes.id).toBe('sale-retiro-1');
    expect(okRes.total).toBe(0);
    expect(mockRpc).toHaveBeenCalledWith('rpc_procesar_venta_v3', expect.objectContaining({
      p_store_id: STORE_ID,
      p_client_id: null,
      p_payment_method: 'consumo_personal',
      p_amount_received: 0,
      p_origin_session_id: SESSION_ID,
      p_sold_by: EMP_UUID,
      p_beneficiary_employee_id: EMP_UUID,
    }));

    // Rechazo PERMISSION_DENIED (CHK-404)
    mockRpc.mockResolvedValueOnce({
      data: null,
      error: { message: 'PERMISSION_DENIED: canFiar', code: '42501' },
    });
    const deniedRes = await saleRepository.processSale(
      {
        items: [{ productId: 'prod-1', productName: 'Café', quantity: 1, price: 5000, subtotal: 5000 }],
        total: 5000,
        paymentMethod: 'fiado',
        clientId: CLIENT_UUID,
      },
      STORE_ID,
    );
    expect(deniedRes.success).toBe(false);
    expect(deniedRes.code).toBe('PERMISSION_DENIED');
    expect(deniedRes.error).toContain('canFiar');
  });

  it('[CHK-402][CHK-405] CheckoutModal oculta Fiado sin canFiar y excluye Retiro ($0); PersonalWithdrawalModal restringe beneficiario a Admin', async () => {
    const configStore = useConfigStore();
    configStore.paymentMethods = [
      { id: '1', name: 'Efectivo', code: 'efectivo', allowsChange: true, requiresReference: false, isActive: true },
      { id: '2', name: 'Fiado', code: 'fiado', allowsChange: false, requiresReference: false, isActive: true },
    ] as any;

    const authStore = useAuthStore();
    setEmployeeSession(authStore, false);

    const wrapperCheckoutEmp = mount(CheckoutModal, {
      props: { modelValue: true, total: new Decimal(8000) },
      global: {
        stubs: { UIBaseModal: { template: '<div><slot /></div>' } },
      },
    });

    // Empleado sin canFiar NO ve Fiado y Retiro ($0) vive fuera de CheckoutModal (UX-ADR-007)
    expect(wrapperCheckoutEmp.text()).not.toContain('Fiado');
    expect(wrapperCheckoutEmp.text()).not.toContain('Retiro ($0)');

    // Flujo separado en PersonalWithdrawalModal para empleado
    const wrapperEmp = mount(PersonalWithdrawalModal, {
      props: { modelValue: true, total: new Decimal(8000), itemCount: 2 },
      global: {
        stubs: { UIBaseModal: { template: '<div><slot /></div>' } },
      },
    });

    expect(wrapperEmp.find('[data-testid="beneficiary-employee-select"]').exists()).toBe(false);
    expect(wrapperEmp.text()).toContain('Laura Cajera');

    const confirmBtn = wrapperEmp.get('[data-testid="personal-withdrawal-confirm-btn"]');
    await confirmBtn.trigger('click');
    const emittedEmp = wrapperEmp.emitted('complete');
    expect(emittedEmp).toBeTruthy();
    expect(emittedEmp![0][0][0].method).toBe('consumo_personal');
    expect(emittedEmp![0][2]).toBeUndefined();
    expect(emittedEmp![0][3]).toBeUndefined();

    // Admin sí ve Fiado en CheckoutModal y selector de beneficiario en PersonalWithdrawalModal
    setAdminSession(authStore);
    const wrapperCheckoutAdmin = mount(CheckoutModal, {
      props: { modelValue: true, total: new Decimal(8000) },
      global: {
        stubs: { UIBaseModal: { template: '<div><slot /></div>' } },
      },
    });
    expect(wrapperCheckoutAdmin.text()).toContain('Fiado');

    const employeesStore = useEmployeesStore();
    employeesStore.employees = [
      { id: EMP_UUID, storeId: STORE_ID, name: 'Laura Cajera', username: '1001', pin: '', isActive: true, permissions: { canManageInventory: false, canFiar: true, canOpenCloseCash: false, canManageRefunds: false }, createdAt: '', updatedAt: '' },
    ];

    const wrapperAdmin = mount(PersonalWithdrawalModal, {
      props: { modelValue: true, total: new Decimal(8000), itemCount: 2 },
      global: {
        stubs: { UIBaseModal: { template: '<div><slot /></div>' } },
      },
    });
    const selectEl = wrapperAdmin.get('[data-testid="beneficiary-employee-select"]');
    await selectEl.setValue(EMP_UUID);

    const confirmAdminBtn = wrapperAdmin.get('[data-testid="personal-withdrawal-confirm-btn"]');
    await confirmAdminBtn.trigger('click');
    const emittedAdmin = wrapperAdmin.emitted('complete');
    expect(emittedAdmin![0][3]).toBe(EMP_UUID);
  });

  it('[CHK-404][CHK-407] clientRepository.getPaginated usa rpc_admin_get_clients sin p_include_deleted y ClientListView renderiza filtros/ordenamiento', async () => {
    const authStore = useAuthStore();
    setEmployeeSession(authStore, true);

    mockRpc.mockResolvedValue({
      data: {
        success: true,
        data: [
          {
            id: CLIENT_UUID,
            store_id: STORE_ID,
            name: 'Carlos Mora',
            id_number: '123456',
            phone: '300123',
            credit_limit: 50000,
            balance: 15000,
            created_at: '2026-11-19T00:00:00Z',
          },
        ],
        count: 1,
        total_portfolio_debt: 15000,
        debtors_count: 1,
      },
      error: null,
    });

    const pageRes = await clientRepository.getPaginated({
      storeId: STORE_ID,
      debtFilter: 'with_debt',
      orderBy: 'balance_desc',
      limit: 20,
      offset: 0,
    });
    expect(pageRes.count).toBe(1);
    expect(mockRpc).toHaveBeenCalledWith('rpc_admin_get_clients', {
      p_store_id: STORE_ID,
      p_filter_debt: 'con_deuda',
      p_search_query: null,
      p_order_by: 'balance_desc',
      p_limit: 20,
      p_offset: 0,
    });
    const argsCalled = mockRpc.mock.calls.find((c) => c[0] === 'rpc_admin_get_clients')?.[1];
    expect('p_include_deleted' in argsCalled).toBe(false);

    const wrapper = mount(ClientListView, {
      global: {
        stubs: { BottomNav: true, ClientFormModal: true, BaseInput: true, BaseButton: { template: '<button><slot /></button>' }, BaseListSkeleton: true, BaseEmptyState: true },
      },
    });
    await flushPromises();

    expect(wrapper.get('[data-testid="filter-debt-all"]').text()).toBe('Todos');
    expect(wrapper.get('[data-testid="filter-debt-with_debt"]').text()).toBe('Con Deuda');
    expect(wrapper.get('[data-testid="filter-debt-up_to_date"]').text()).toBe('Al Día');
    expect(wrapper.find('[data-testid="client-order-select"]').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('Eliminados');

    await wrapper.get('[data-testid="filter-debt-up_to_date"]').trigger('click');
    await flushPromises();
    expect(mockRpc).toHaveBeenCalledWith('rpc_admin_get_clients', expect.objectContaining({ p_filter_debt: 'sin_deuda' }));
  });

  it('[CHK-405][CHK-406] ClientDetailView protege Abonar/CSV con canFiar, AdminHubView actúa como Hub lanzador, ClientListView actualiza cupo global y ClientFormModal lo precarga', async () => {
    const authStore = useAuthStore();
    setEmployeeSession(authStore, false);
    const clientsStore = useClientsStore();
    clientsStore.clients = [
      { id: 'cli-1', storeId: STORE_ID, name: 'Ana', cc: '9001', totalDebt: new Decimal(10000), creditLimit: new Decimal(50000), createdAt: '', updatedAt: '' },
    ];
    mockRpc.mockResolvedValue({
      data: {
        success: true,
        data: {
          client: { id: 'cli-1', name: 'Ana', id_number: '9001', credit_limit: 50000, balance: 10000, credit_available: 40000 },
          movements: [],
        },
        count: 0,
      },
      error: null,
    });

    const detailEmpNoFiar = mount(ClientDetailView, {
      global: { stubs: { BaseModal: true, BaseInput: true, BaseButton: { template: '<button><slot /></button>' }, BaseListSkeleton: true, ClientFormModal: true } },
    });
    await flushPromises();
    expect(detailEmpNoFiar.find('[data-testid="register-payment-btn"]').exists()).toBe(false);
    expect(detailEmpNoFiar.find('[data-testid="export-client-csv-btn"]').exists()).toBe(false);

    // Con canFiar = true -> sí ve ambos
    setEmployeeSession(authStore, true);
    const detailEmpFiar = mount(ClientDetailView, {
      global: { stubs: { BaseModal: true, BaseInput: true, BaseButton: { template: '<button><slot /></button>' }, BaseListSkeleton: true, ClientFormModal: true } },
    });
    await flushPromises();
    expect(detailEmpFiar.find('[data-testid="register-payment-btn"]').exists()).toBe(true);
    expect(detailEmpFiar.find('[data-testid="export-client-csv-btn"]').exists()).toBe(true);

    // CHK-406 / UX-ADR-006: AdminHubView es Hub lanzador (sin input incrustado) y ClientListView guarda cupo global
    setAdminSession(authStore);
    const adminWrapper = mount(AdminHubView, {
      global: { stubs: { BottomNav: true, UserProfileSidebar: true } },
    });
    await flushPromises();
    expect(adminWrapper.find('[data-testid="global-credit-limit-input"]').exists()).toBe(false);
    expect(adminWrapper.find('[data-testid="admin-hub-clients-launcher"]').exists()).toBe(true);

    mockFrom.mockReturnValue({
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      single: vi.fn().mockResolvedValue({ data: { default_credit_limit: 95000 }, error: null }),
    });
    mockRpc.mockImplementation(async (fn: string) => {
      if (fn === 'rpc_admin_get_clients') {
        return { data: { success: true, data: [], count: 0, total_portfolio_debt: 0, debtors_count: 0 }, error: null };
      }
      if (fn === 'rpc_actualizar_cupo_credito_global') {
        return { data: { success: true, data: { default_credit_limit: 150000 } }, error: null };
      }
      return { data: { success: true }, error: null };
    });

    const listWrapper = mount(ClientListView, {
      global: {
        stubs: {
          BottomNav: true,
          ClientFormModal: true,
          BaseInput: true,
          BaseListSkeleton: true,
          BaseEmptyState: true,
          BaseModal: { props: ['modelValue'], template: '<div v-if="modelValue"><slot /><slot name="footer" /></div>' },
          BaseButton: { props: ['disabled', 'loading'], template: '<button :disabled="disabled"><slot /></button>' },
        },
      },
    });
    await flushPromises();
    await listWrapper.get('[data-testid="open-global-credit-modal-btn"]').trigger('click');
    await flushPromises();
    await listWrapper.get('[data-testid="global-credit-limit-input"]').setValue(150000);
    await listWrapper.get('[data-testid="save-global-credit-limit-btn"]').trigger('click');
    await flushPromises();
    expect(mockRpc).toHaveBeenCalledWith('rpc_actualizar_cupo_credito_global', {
      p_store_id: STORE_ID,
      p_default_credit_limit: 150000,
    });

    const modalWrapper = mount(ClientFormModal, {
      props: { modelValue: true },
      global: { stubs: { Teleport: true, BaseModal: true, BaseButton: true } },
    });
    await flushPromises();
    const limitInput = modalWrapper.find('input[type="number"]');
    expect((limitInput.element as HTMLInputElement).value).toBe('95000');
  });

  it('[CHK-408] SaleDetailModal muestra mensaje claro cuando rpc_anular_venta rechaza por CREDIT_REVERSAL_BLOCKED', async () => {
    const authStore = useAuthStore();
    setAdminSession(authStore);

    mockRpc
      .mockResolvedValueOnce({
        data: {
          success: true,
          ticket_number: 88,
          total: 10000,
          payment_method: 'fiado',
          employee_name: 'Dueño',
          client_name: 'Carlos',
          is_voided: false,
          items: [{ product_name: 'Café', quantity: 1, unit_price: 10000, subtotal: 10000 }],
          items_count: 1,
        },
        error: null,
      })
      .mockResolvedValueOnce({
        data: null,
        error: { message: 'CREDIT_REVERSAL_BLOCKED: El cliente ya abonó parte de esta venta.' },
      });

    const wrapper = mount(SaleDetailModal, {
      props: { modelValue: true, saleId: 'sale-fiado-88' },
      global: {
        stubs: {
          BaseModal: { template: '<div><slot /></div>' },
          BaseButton: { template: '<button @click="$emit(\'click\')"><slot /></button>' },
        },
      },
    });
    await flushPromises();

    await wrapper.find('textarea').setValue('Motivo de prueba mayor a diez caracteres');
    const confirmVoidBtn = wrapper.findAll('button').find((b) => b.text().includes('Confirmar Anulación'));
    await confirmVoidBtn!.trigger('click');
    await flushPromises();

    expect(wrapper.get('[data-testid="void-sale-error"]').text()).toContain('No se puede anular esta venta fiada');
    expect(mockShowError).toHaveBeenCalled();
  });

  it('[CHK-409][CHK-410] PayInvoiceModal valida liquidez del canal seleccionado, exige descripción interna, permite Pago externo / fuera de caja, y SuppliersView (?tab=payables) crea facturas paginadas', async () => {
    const authStore = useAuthStore();
    setAdminSession(authStore);

    const invoice = {
      id: 'inv-1',
      supplier_id: 'sup-1',
      supplier: { name: 'Distribuidora' },
      invoice_number: 'FAC-1',
      due_date: null,
      total_amount: 50000,
      amount_paid: 0,
      pending_balance: 50000,
      status: 'pendiente',
      store_id: STORE_ID,
    } as any;

    const modal = mount(PayInvoiceModal, {
      props: { show: true, invoice },
      global: {
        stubs: {
          BaseModal: {
            props: ['modelValue'],
            template: '<div v-if="modelValue"><slot /><slot name="footer" /></div>',
          },
          BaseInput: {
            props: ['modelValue'],
            template: '<input type="number" :value="modelValue" @input="$emit(\'update:modelValue\', Number($event.target.value))" />',
          },
          BaseButton: {
            props: ['disabled'],
            template: '<button :disabled="disabled" @click="$emit(\'click\')"><slot /></button>',
          },
        },
      },
    });

    expect(modal.text()).toContain('Pago externo / fuera de caja');
    // Canal Nequi solo tiene $5,000 aunque Efectivo tenga $100,000 -> pagar $20,000 debe mostrar bloqueo de liquidez
    await modal.get('[data-testid="pay-method-nequi"]').trigger('click');
    await modal.find('input[type="number"]').setValue(20000);
    expect(modal.get('[data-testid="insufficient-channel-balance-alert"]').text()).toContain('Nequi');

    // Cambio a Externo con caja cerrada funciona sin descripción obligatoria
    cashMockState.isOpen = false;
    await modal.get('[data-testid="pay-method-externo"]').trigger('click');
    mockRpc.mockResolvedValueOnce({ data: { success: true }, error: null });
    const confirmPayBtn = modal.findAll('button').find((b) => b.text().includes('Confirmar Abono'));
    expect((confirmPayBtn!.element as HTMLButtonElement).disabled).toBe(false);
    await confirmPayBtn!.trigger('click');
    await flushPromises();
    expect(mockRpc).toHaveBeenCalledWith('rpc_pay_supplier_invoice', {
      p_invoice_id: 'inv-1',
      p_amount: 20000,
      p_payment_method: 'externo',
      p_description: null,
    });

    // SuppliersView (?tab=payables) consulta rpc_obtener_cuentas_por_pagar y crea factura via rpc_crear_factura_proveedor sin due_date
    mockRpc
      .mockResolvedValueOnce({
        data: {
          success: true,
          data: [invoice],
          count: 1,
          summary: { total_debt: 50000, total_overdue: 0, pending_count: 1, overdue_count: 0 },
        },
        error: null,
      })
      .mockResolvedValueOnce({ data: { success: true, data: { invoice } }, error: null })
      .mockResolvedValueOnce({
        data: {
          success: true,
          data: [invoice],
          count: 1,
          summary: { total_debt: 95000, total_overdue: 0, pending_count: 2, overdue_count: 0 },
        },
        error: null,
      });

    const suppliersView = mount(SuppliersView, {
      global: {
        stubs: {
          BottomNav: true,
          Skeleton: true,
          BaseListSkeleton: true,
          PayInvoiceModal: true,
          BaseModal: {
            props: ['modelValue'],
            template: '<div v-if="modelValue"><slot /><slot name="footer" /></div>',
          },
          BaseButton: {
            props: ['disabled', 'loading'],
            template: '<button :disabled="disabled" @click="$emit(\'click\')"><slot /></button>',
          },
        },
      },
    });
    await flushPromises();
    expect(mockRpc).toHaveBeenCalledWith('rpc_obtener_cuentas_por_pagar', expect.objectContaining({ p_store_id: STORE_ID }));

    await suppliersView.get('[data-testid="open-create-invoice-btn"]').trigger('click');
    await suppliersView.get('[data-testid="toggle-new-supplier-mode"]').trigger('click');
    await suppliersView.get('[data-testid="create-invoice-supplier-input"]').setValue('Panadería Norte');
    await suppliersView.get('[data-testid="create-invoice-amount-input"]').setValue(45000);
    await suppliersView.get('[data-testid="submit-create-invoice-btn"]').trigger('click');
    await flushPromises();
    expect(mockRpc).toHaveBeenCalledWith('rpc_crear_factura_proveedor', {
      p_store_id: STORE_ID,
      p_supplier_id: null,
      p_supplier_name: 'Panadería Norte',
      p_total_amount: 45000,
      p_due_date: null,
      p_invoice_number: null,
    });
  });

  it('[CHK-401][CHK-402] Offline CREATE_SALE con originSessionId y beneficiaryEmployeeId pasa detectSchemaDrift y addToSyncQueue sin schema drift', async () => {
    const { detectSchemaDrift, sanitizeCamelToSnake } = await import('../services/schemaValidator');
    const { useInventoryStore } = await import('../stores/inventory');
    const inventoryStore = useInventoryStore();
    inventoryStore.products = [
      {
        id: 'prod-off-1',
        storeId: STORE_ID,
        name: 'Café Offline',
        price: new Decimal(5000),
        stock: new Decimal(20),
        measurementUnit: 'un',
        minStock: 1,
      } as any,
    ];

    const sanitizedSample = sanitizeCamelToSnake({
      id: 'off-1',
      localId: 'off-1',
      storeId: STORE_ID,
      clientId: null,
      employeeId: EMP_UUID,
      originSessionId: SESSION_ID,
      beneficiaryEmployeeId: EMP_UUID,
      paymentMethod: 'consumo_personal',
      total: 0,
      items: [{ productId: 'prod-off-1', quantity: 1, price: 5000, subtotal: 5000 }],
    });
    const drift = detectSchemaDrift(sanitizedSample, 'sales');
    expect(drift.drifted).toBe(false);
    expect(drift.obsoleteFields).toEqual([]);
    expect(sanitizedSample.origin_session_id).toBe(SESSION_ID);
    expect(sanitizedSample.beneficiary_employee_id).toBe(EMP_UUID);

    Object.defineProperty(navigator, 'onLine', { value: false, configurable: true });
    // Efectivo offline sí se encola en syncQueue con origin_session_id y sin client_id
    const offlineCashRes = await saleRepository.processSale(
      {
        items: [{ productId: 'prod-off-1', productName: 'Café Offline', quantity: 1, price: 5000, subtotal: 5000 }],
        total: 5000,
        paymentMethod: 'efectivo',
        clientId: CLIENT_UUID, // debe quedar null fuera de fiado
        employeeId: EMP_UUID,
        originSessionId: SESSION_ID,
      },
      STORE_ID,
    );

    expect(offlineCashRes.success).toBe(true);
    expect(idbPutSpy).toHaveBeenCalledTimes(1);
    const queuedItem = idbPutSpy.mock.calls[0][1];
    expect(queuedItem.type).toBe('CREATE_SALE');
    expect(queuedItem.payload.origin_session_id).toBe(SESSION_ID);
    expect(queuedItem.payload.client_id).toBeNull();

    // UX-ADR-007: consumo_personal offline queda bloqueado explícitamente (OFFLINE_NOT_ALLOWED)
    const offlineWithdrawalRes = await saleRepository.processSale(
      {
        items: [{ productId: 'prod-off-1', productName: 'Café Offline', quantity: 1, price: 5000, subtotal: 5000 }],
        total: 0,
        paymentMethod: 'consumo_personal',
        employeeId: EMP_UUID,
        originSessionId: SESSION_ID,
        beneficiaryEmployeeId: EMP_UUID,
      },
      STORE_ID,
    );
    expect(offlineWithdrawalRes.success).toBe(false);
    expect(offlineWithdrawalRes.code).toBe('OFFLINE_NOT_ALLOWED');
    expect(idbPutSpy).toHaveBeenCalledTimes(1);
  });
});

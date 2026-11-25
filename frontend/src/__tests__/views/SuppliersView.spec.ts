import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { reactive } from 'vue';
import SuppliersView from '../../views/SuppliersView.vue';
import { useAuthStore } from '../../stores/auth';
import { useSuppliersStore } from '../../stores/suppliers';

enableAutoUnmount(afterEach);

const {
  mockRpc,
  mockFrom,
  mockPush,
  mockReplace,
  mockRouteState,
  mockShowSuccess,
  mockShowError,
} = vi.hoisted(() => ({
  mockRpc: vi.fn(),
  mockFrom: vi.fn(),
  mockPush: vi.fn(),
  mockReplace: vi.fn(),
  mockRouteState: { path: '/suppliers', query: {} as Record<string, any> },
  mockShowSuccess: vi.fn(),
  mockShowError: vi.fn(),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mockPush, replace: mockReplace, back: vi.fn() }),
  useRoute: () => reactive({
    get path() { return mockRouteState.path; },
    params: {},
    get query() { return mockRouteState.query; },
  }),
}));

vi.mock('@/lib/supabase', () => ({
  supabase: {
    rpc: (...args: any[]) => mockRpc(...args),
    from: (...args: any[]) => mockFrom(...args),
  },
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
    formatWithSign: (v: any) => `$ ${Number(v || 0).toLocaleString('es-CO')}`,
  }),
}));

vi.mock('@/stores/cashRegister', () => ({
  useCashRegisterStore: () => ({
    isOpen: true,
    isStaleSession: false,
    currentBalance: 200000,
    balancesByMethod: { efectivo: 200000, nequi: 0, llave_bre: 0 },
    syncFromBackend: vi.fn().mockResolvedValue(true),
  }),
}));

const globalStubs = {
  BottomNav: true,
  Skeleton: true,
  BaseListSkeleton: true,
  BaseModal: {
    props: ['modelValue', 'title'],
    template: '<div v-if="modelValue"><slot /><slot name="footer" /></div>',
  },
  BaseButton: {
    props: ['disabled', 'loading'],
    template: '<button :disabled="disabled" @click="$emit(\'click\')"><slot /></button>',
  },
  BaseInput: {
    props: ['modelValue', 'type', 'disabled'],
    template:
      '<input :type="type || \'text\'" :disabled="disabled" :value="modelValue" @input="$emit(\'update:modelValue\', type === \'number\' ? Number($event.target.value) : $event.target.value)" />',
  },
};

const sampleSuppliers = [
  {
    id: 'sup-1',
    store_id: 'store-1',
    name: 'Distribuidora Norte',
    delivery_day: 2,
    frequency_days: 7,
    lead_time_days: 1,
    is_default: false,
    pending_debt: 185000,
    open_invoices_count: 2,
  },
  {
    id: 'sup-2',
    store_id: 'store-1',
    name: 'Proveedor General',
    delivery_day: null,
    frequency_days: 15,
    lead_time_days: 1,
    is_default: true,
    pending_debt: 0,
    open_invoices_count: 0,
  },
];

describe('SuppliersView.vue — Workspace Consolidado C5 (WO-OLA2-C5-001)', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    mockRouteState.path = '/suppliers';
    mockRouteState.query = {};

    const authStore = useAuthStore();
    authStore.currentUser = {
      id: 'owner-1',
      name: 'Admin',
      type: 'admin',
      storeId: 'store-1',
      permissions: { canManageInventory: true, canFiar: true, canOpenCloseCash: true, canManageRefunds: true },
    } as any;
    authStore.isAuthenticated = true;

    mockReplace.mockImplementation((loc: any) => {
      if (loc.path) mockRouteState.path = loc.path;
      if (loc.query) mockRouteState.query = { ...loc.query };
      return Promise.resolve();
    });
  });

  it('normaliza el alias /payables a /suppliers?tab=payables y muestra KPIs globales desde summary del servidor', async () => {
    mockRouteState.path = '/payables';
    mockRpc.mockImplementation(async (fn: string) => {
      if (fn === 'rpc_obtener_proveedores_con_cxp') {
        return { data: { success: true, data: sampleSuppliers }, error: null };
      }
      if (fn === 'rpc_obtener_cuentas_por_pagar') {
        // Solo 1 factura en la página filtrada, pero el summary global del servidor es mayor
        return {
          data: {
            success: true,
            data: [
              {
                id: 'inv-1',
                store_id: 'store-1',
                supplier_id: 'sup-1',
                supplier: { name: 'Distribuidora Norte' },
                invoice_number: 'FAC-99',
                total_amount: 100000,
                amount_paid: 60000,
                pending_balance: 40000,
                due_date: '2026-11-20',
                status: 'vencida',
              },
            ],
            count: 5,
            summary: {
              total_debt: 345000,
              total_overdue: 120000,
              pending_count: 3,
              overdue_count: 2,
            },
          },
          error: null,
        };
      }
      return { data: { success: true }, error: null };
    });

    const wrapper = mount(SuppliersView, { global: { stubs: globalStubs } });
    await flushPromises();

    expect(mockReplace).toHaveBeenCalledWith({ path: '/suppliers', query: { tab: 'payables' } });
    expect(wrapper.get('[data-testid="kpi-total-debt"]').text()).toContain('345.000');
    expect(wrapper.get('[data-testid="kpi-total-overdue"]').text()).toContain('120.000');
    expect(wrapper.get('[data-testid="invoice-card-inv-1"]').text()).toContain('40.000');
  });

  it('muestra banner N3 fail-closed con Reintentar cuando falla rpc_obtener_cuentas_por_pagar (sin "Todo al día")', async () => {
    mockRouteState.query = { tab: 'payables' };
    mockRpc.mockImplementation(async (fn: string) => {
      if (fn === 'rpc_obtener_proveedores_con_cxp') {
        return { data: { success: true, data: sampleSuppliers }, error: null };
      }
      if (fn === 'rpc_obtener_cuentas_por_pagar') {
        return { data: null, error: { message: 'ADMIN_ONLY_ACTION: Solo administrador.' } };
      }
      return { data: { success: true }, error: null };
    });

    const wrapper = mount(SuppliersView, { global: { stubs: globalStubs } });
    await flushPromises();

    expect(wrapper.find('[data-testid="payables-error-banner"]').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('Todo al día');

    // Al pulsar Reintentar vuelve a consultar
    await wrapper.get('[data-testid="payables-retry-btn"]').trigger('click');
    await flushPromises();
    const payableCalls = mockRpc.mock.calls.filter((c) => c[0] === 'rpc_obtener_cuentas_por_pagar');
    expect(payableCalls.length).toBeGreaterThanOrEqual(2);
  });

  it('muestra banner N3 fail-closed cuando falla rpc_obtener_proveedores_con_cxp', async () => {
    mockRpc.mockResolvedValue({ data: null, error: { message: 'Fallo de red en proveedores' } });

    const wrapper = mount(SuppliersView, { global: { stubs: globalStubs } });
    await flushPromises();

    const banner = wrapper.get('[data-testid="suppliers-error-banner"]');
    expect(banner.text()).toContain('Fallo de red en proveedores');
    expect(wrapper.text()).not.toContain('Sin proveedores');
  });

  it('crea factura seleccionando proveedor existente por FK (p_supplier_id) y filtra CxP al pulsar Ver CxP', async () => {
    mockRpc.mockImplementation(async (fn: string) => {
      if (fn === 'rpc_obtener_proveedores_con_cxp') {
        return { data: { success: true, data: sampleSuppliers }, error: null };
      }
      if (fn === 'rpc_obtener_cuentas_por_pagar') {
        return {
          data: {
            success: true,
            data: [],
            count: 0,
            summary: { total_debt: 0, total_overdue: 0, pending_count: 0, overdue_count: 0 },
          },
          error: null,
        };
      }
      if (fn === 'rpc_crear_factura_proveedor') {
        return {
          data: {
            success: true,
            data: {
              invoice: {
                id: 'inv-new',
                store_id: 'store-1',
                supplier_id: 'sup-1',
                supplier: { id: 'sup-1', name: 'Distribuidora Norte' },
                total_amount: 85000,
                amount_paid: 0,
                pending_balance: 85000,
                status: 'pendiente',
              },
            },
          },
          error: null,
        };
      }
      return { data: { success: true }, error: null };
    });

    const wrapper = mount(SuppliersView, { global: { stubs: globalStubs } });
    await flushPromises();

    // Desde tarjeta de Proveedor, pulsar "Ver CxP" abre pestaña payables filtrada por sup-1
    await wrapper.get('[data-testid="supplier-view-cxp-sup-1"]').trigger('click');
    await flushPromises();

    expect(mockReplace).toHaveBeenCalledWith({ path: '/suppliers', query: { tab: 'payables', supplier: 'sup-1' } });
    expect((wrapper.get('[data-testid="payables-supplier-filter"]').element as HTMLSelectElement).value).toBe('sup-1');

    // Crear factura usando selector relacional FK
    await wrapper.get('[data-testid="open-create-invoice-btn"]').trigger('click');
    await wrapper.get('[data-testid="create-invoice-supplier-select"]').setValue('sup-1');
    await wrapper.get('[data-testid="create-invoice-amount-input"]').setValue(85000);
    await wrapper.get('[data-testid="submit-create-invoice-btn"]').trigger('click');
    await flushPromises();

    expect(mockRpc).toHaveBeenCalledWith('rpc_crear_factura_proveedor', {
      p_store_id: 'store-1',
      p_supplier_id: 'sup-1',
      p_supplier_name: null,
      p_total_amount: 85000,
      p_due_date: null,
      p_invoice_number: null,
    });
    expect(mockShowSuccess).toHaveBeenCalledWith('Factura registrada en Cuentas por Pagar');
  });

  it('permite editar proveedor en BaseModal y eliminar mediante confirmación BaseModal N5 sin confirm() nativo', async () => {
    const confirmSpy = vi.fn();
    vi.stubGlobal('confirm', confirmSpy);
    mockRpc.mockResolvedValue({ data: { success: true, data: sampleSuppliers }, error: null });

    const wrapper = mount(SuppliersView, { global: { stubs: globalStubs } });
    await flushPromises();

    const suppliersStore = useSuppliersStore();
    const updateSpy = vi.spyOn(suppliersStore, 'updateSupplier').mockResolvedValue({ success: true });
    const deleteSpy = vi.spyOn(suppliersStore, 'deleteSupplier').mockResolvedValue({ success: true });

    // Editar proveedor
    await wrapper.get('[data-testid="edit-supplier-btn-sup-1"]').trigger('click');
    await wrapper.get('[data-testid="supplier-name-input"]').setValue('Distribuidora Norte SAS');
    await wrapper.get('[data-testid="submit-supplier-btn"]').trigger('click');
    await flushPromises();

    expect(updateSpy).toHaveBeenCalledWith('sup-1', expect.objectContaining({ name: 'Distribuidora Norte SAS' }));

    // Eliminar proveedor por BaseModal N5
    await wrapper.get('[data-testid="delete-supplier-btn-sup-1"]').trigger('click');
    await wrapper.get('[data-testid="confirm-delete-supplier-btn"]').trigger('click');
    await flushPromises();

    expect(deleteSpy).toHaveBeenCalledWith('sup-1');
    expect(confirmSpy).not.toHaveBeenCalled();
    vi.unstubAllGlobals();
  });
});

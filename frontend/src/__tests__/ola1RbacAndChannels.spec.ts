import { describe, it, expect, beforeEach, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { mount, flushPromises } from '@vue/test-utils';
import { ALLOWED_POS_PAYMENT_CODES } from '../stores/config';
import { useAuthStore } from '../stores/auth';
import { useEmployeesStore } from '../stores/employees';
import BottomNav from '../components/BottomNav.vue';
import EmployeeFormModal from '../components/EmployeeFormModal.vue';
import EmployeeManagerView from '../views/EmployeeManagerView.vue';
import PayInvoiceModal from '../components/suppliers/PayInvoiceModal.vue';

const mockPush = vi.fn();
const mockRoute: any = { name: 'pos', path: '/pos', query: {}, meta: {} };

vi.mock('vue-router', async (importOriginal) => {
  const actual = await importOriginal<any>();
  return {
    ...actual,
    useRouter: () => ({ push: mockPush, back: vi.fn() }),
    useRoute: () => mockRoute,
  };
});

const mockRpc = vi.fn();
const mockFrom = vi.fn();

vi.mock('../lib/supabase', () => ({
  supabase: {
    rpc: (...args: any[]) => mockRpc(...args),
    from: (...args: any[]) => mockFrom(...args),
    auth: {
      getSession: vi.fn().mockResolvedValue({ data: { session: { user: { id: 'uid-1' } } } }),
      signInAnonymously: vi.fn().mockResolvedValue({ error: null }),
      signOut: vi.fn().mockResolvedValue({ error: null }),
    },
  },
}));

vi.mock('../data/supabaseClient', () => ({
  getSupabaseClient: () => ({
    rpc: (...args: any[]) => mockRpc(...args),
    from: (...args: any[]) => mockFrom(...args),
  }),
  isSupabaseConfigured: () => true,
  isAuditMode: () => false,
}));

vi.mock('../composables/useNotifications', () => ({
  useNotifications: () => ({
    showSuccess: vi.fn(),
    showError: vi.fn(),
    showWarning: vi.fn(),
  }),
}));

vi.mock('../stores/cashRegister', () => ({
  useCashRegisterStore: () => ({
    isOpen: true,
    isStaleSession: false,
    currentBalance: 100000,
  }),
}));

vi.mock('../stores/payables', () => ({
  usePayablesStore: () => ({
    payInvoice: vi.fn().mockResolvedValue({ success: true }),
  }),
}));

describe('Fase 3 Ola 1 — RBAC 4 Permisos, Continuidad <24h, Snapshots y Canales', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    mockRpc.mockImplementation((fnName: string) => {
      if (fnName === 'check_daily_pass_status') {
        return Promise.resolve({ data: { status: 'approved', pass_id: 'pass-1', retry_count: 0 }, error: null });
      }
      return Promise.resolve({ data: { status: 'active' }, error: null });
    });
    Object.defineProperty(navigator, 'onLine', { value: true, configurable: true });
  });

  it('[CHK-111] authStore expone exactamente las 4 llaves delegables + capacidad base y excluye legacy', () => {
    const authStore = useAuthStore();
    expect('canViewReports' in authStore).toBe(false);
    expect('canViewInventory' in authStore).toBe(false);
    expect('canManageClients' in authStore).toBe(false);

    authStore.loginAsEmployee(
      {
        id: 'emp-1',
        name: 'Laura',
        username: '1001',
        permissions: {
          canManageInventory: true,
          canFiar: false,
          canOpenCloseCash: false,
          canManageRefunds: true,
        },
      },
      'store-1',
    );

    expect(authStore.isEmployee).toBe(true);
    expect(authStore.isAdmin).toBe(false);
    expect(authStore.canSell).toBe(true); // capacidad base
    expect(authStore.canManageInventory).toBe(true);
    expect(authStore.canManageRefunds).toBe(true);
    expect(authStore.canFiar).toBe(false);
    expect(authStore.canOpenCloseCash).toBe(false);
  });

  it('[CHK-111] employeeRepository.update usa rpc_actualizar_permisos_empleado y rechaza cambio directo de PIN', async () => {
    const { employeeRepository } = await import('../data/repositories/employeeRepository');
    mockRpc.mockResolvedValueOnce({ data: { success: true }, error: null });

    await expect(
      employeeRepository.update('emp-1', { pin: '9999' }),
    ).rejects.toThrow(/Cambiar PIN/);

    await employeeRepository.update('emp-1', {
      permissions: {
        canManageInventory: false,
        canFiar: true,
        canOpenCloseCash: false,
        canManageRefunds: true,
      },
    });

    expect(mockRpc).toHaveBeenCalledWith('rpc_actualizar_permisos_empleado', {
      p_employee_id: 'emp-1',
      p_permissions: {
        canManageInventory: false,
        canFiar: true,
        canOpenCloseCash: false,
        canManageRefunds: true,
      },
    });
  });

  it('[CHK-105/B-4] employeeRepository.getAll propaga error explícito del RPC y NO cae en fallback silencioso', async () => {
    const { employeeRepository } = await import('../data/repositories/employeeRepository');
    mockRpc.mockResolvedValueOnce({
      data: null,
      error: { message: 'ADMIN_ONLY_ACTION: Esta acción es exclusiva del Administrador.', code: '42501' },
    });

    await expect(employeeRepository.getAll('store-1')).rejects.toThrow(/ADMIN_ONLY_ACTION/);
    expect(mockFrom).not.toHaveBeenCalled();
  });

  it('[B-1] useSessionGuard registra UNAUTHORIZED_ACCESS persistente ante error 42501 ADMIN_ONLY_ACTION / PERMISSION_DENIED', async () => {
    const authStore = useAuthStore();
    authStore.loginAsEmployee(
      {
        id: 'emp-guard',
        name: 'Cajero',
        username: '7777',
        permissions: { canManageInventory: false, canFiar: false, canOpenCloseCash: false, canManageRefunds: false },
      },
      'store-1',
    );
    mockRpc.mockResolvedValueOnce({ data: null, error: null });

    const { handleAccessDeniedError } = await import('../composables/useSessionGuard');
    const handled = await handleAccessDeniedError({ message: 'PERMISSION_DENIED: canFiar', code: '42501' });

    expect(handled).toBe(true);
    expect(mockRpc).toHaveBeenCalledWith('rpc_log_security_event', expect.objectContaining({
      p_event_type: 'unauthorized_access',
      p_store_id: 'store-1',
    }));
  });

  it('[CHK-112] EmployeeFormModal muestra exactamente 4 interruptores y 0 switches legacy', () => {
    const wrapper = mount(EmployeeFormModal, {
      props: { modelValue: true },
      global: {
        stubs: { BaseModal: { template: '<div><slot /><slot name="footer" /></div>' }, BaseInput: true, BaseButton: true },
      },
    });

    const checkboxes = wrapper.findAll('input[type="checkbox"]');
    expect(checkboxes).toHaveLength(4);
    expect(wrapper.text()).toContain('Inventario completo');
    expect(wrapper.text()).toContain('Fiar y cobrar abonos');
    expect(wrapper.text()).toContain('Abrir/cerrar caja');
    expect(wrapper.text()).toContain('Reembolsos');
    expect(wrapper.text()).not.toContain('Ver Reportes');
    expect(wrapper.text()).not.toContain('Ver Inventario');
    expect(wrapper.text()).not.toContain('Puede Vender');
  });

  it('[CHK-112] EmployeeManagerView excluye owner_ del tope de 5 activos y filtra Activos/Inactivos + búsqueda', async () => {
    const employeesStore = useEmployeesStore();
    employeesStore.employees = [
      { id: '0', storeId: 's1', name: 'Dueño', username: 'owner_abc', pin: '', isActive: true, permissions: { canManageInventory: true, canFiar: true, canOpenCloseCash: true, canManageRefunds: true }, createdAt: '', updatedAt: '' },
      { id: '1', storeId: 's1', name: 'Carlos Perez', username: '101', pin: '', isActive: true, permissions: { canManageInventory: false, canFiar: false, canOpenCloseCash: false, canManageRefunds: false }, createdAt: '', updatedAt: '' },
      { id: '2', storeId: 's1', name: 'Maria Lopez', username: '102', pin: '', isActive: true, permissions: { canManageInventory: false, canFiar: false, canOpenCloseCash: false, canManageRefunds: false }, createdAt: '', updatedAt: '' },
      { id: '3', storeId: 's1', name: 'Pedro Ruiz', username: '103', pin: '', isActive: true, permissions: { canManageInventory: false, canFiar: false, canOpenCloseCash: false, canManageRefunds: false }, createdAt: '', updatedAt: '' },
      { id: '4', storeId: 's1', name: 'Ana Diaz', username: '104', pin: '', isActive: true, permissions: { canManageInventory: false, canFiar: false, canOpenCloseCash: false, canManageRefunds: false }, createdAt: '', updatedAt: '' },
      { id: '5', storeId: 's1', name: 'Sofia Inactive', username: '105', pin: '', isActive: false, permissions: { canManageInventory: false, canFiar: false, canOpenCloseCash: false, canManageRefunds: false }, createdAt: '', updatedAt: '' },
    ];

    const wrapper = mount(EmployeeManagerView, {
      global: {
        stubs: { BottomNav: true, EmployeeFormModal: true, BaseModal: true, BaseInput: true, BaseButton: true },
      },
    });

    // Con 1 owner_ activo + 4 empleados activos, el contador debe marcar 4/5 (no 5/5)
    expect(wrapper.get('[data-testid="active-employees-count"]').text()).toBe('4/5 activos');
    expect(wrapper.text()).toContain('Carlos Perez');
    expect(wrapper.text()).toContain('Sofia Inactive');

    // Filtro Inactivos
    const inactiveBtn = wrapper.findAll('button').find(b => b.text().trim() === 'Inactivos');
    await inactiveBtn!.trigger('click');
    expect(wrapper.text()).toContain('Sofia Inactive');
    expect(wrapper.text()).not.toContain('Carlos Perez');

    // Volver a Activos + Buscador
    const activeBtn = wrapper.findAll('button').find(b => b.text().trim() === 'Activos');
    await activeBtn!.trigger('click');
    const searchInput = wrapper.get('input[type="search"]');
    await searchInput.setValue('Maria');
    expect(wrapper.text()).toContain('Maria Lopez');
    expect(wrapper.text()).not.toContain('Pedro Ruiz');
  });

  it('[CHK-113] BottomNav oculta Reportes y Admin a empleados y respeta canManageInventory/canFiar', async () => {
    const authStore = useAuthStore();
    authStore.loginAsEmployee(
      {
        id: 'emp-2',
        name: 'Luis',
        username: '2002',
        permissions: {
          canManageInventory: false,
          canFiar: true,
          canOpenCloseCash: false,
          canManageRefunds: false,
        },
      },
      'store-1',
    );

    const wrapper = mount(BottomNav);
    expect(wrapper.text()).toContain('Vender');
    expect(wrapper.text()).toContain('Clientes');
    expect(wrapper.text()).not.toContain('Productos');
    expect(wrapper.text()).not.toContain('Reportes');
    expect(wrapper.text()).not.toContain('Admin');
  });

  it('[CHK-114] Config y PayInvoiceModal usan efectivo, nequi y llave_bre sin Daviplata ni bre legacy', () => {
    expect(ALLOWED_POS_PAYMENT_CODES.has('efectivo')).toBe(true);
    expect(ALLOWED_POS_PAYMENT_CODES.has('nequi')).toBe(true);
    expect(ALLOWED_POS_PAYMENT_CODES.has('llave_bre')).toBe(true);
    expect(ALLOWED_POS_PAYMENT_CODES.has('daviplata')).toBe(false);
    expect(ALLOWED_POS_PAYMENT_CODES.has('bre')).toBe(false);

    const wrapper = mount(PayInvoiceModal, {
      props: {
        show: true,
        invoice: {
          id: 'inv-1',
          supplier_id: 'sup-1',
          supplier: { name: 'Distribuidora' },
          invoice_number: 'FAC-1',
          due_date: '2026-11-30',
          total_amount: 50000,
          amount_paid: 0,
          status: 'pendiente',
          store_id: 's1',
        } as any,
      },
      global: { stubs: { BaseInput: true, BaseButton: { template: '<button><slot /></button>' } } },
    });

    expect(wrapper.text()).toContain('Llave Bre-B');
    expect(wrapper.text()).not.toMatch(/daviplata/i);
  });

  it('[CHK-106/CHK-107] authRepository normaliza códigos de error e incluye pases nocturnos <24h sin consultar employees.role', async () => {
    const { authRepository } = await import('../data/repositories/authRepository');
    mockRpc.mockResolvedValueOnce({ data: { success: false, code: 'MAX_RETRIES', message: 'Max' }, error: null });

    const reqRes = await authRepository.requestEmployeeAccess('1001', '1234', 'fp');
    expect(reqRes.success).toBe(false);
    expect(reqRes.error_code).toBe('MAX_RETRIES');

    const chainCash = {
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      gte: vi.fn().mockReturnThis(),
      limit: vi.fn().mockResolvedValue({ data: [{ id: 'sess-1' }], error: null }),
    };
    const inDatesSpy = vi.fn().mockReturnThis();
    const selectPassesSpy = vi.fn().mockReturnThis();
    const chainPasses = {
      select: selectPassesSpy,
      eq: vi.fn().mockReturnThis(),
      in: inDatesSpy,
      order: vi.fn().mockResolvedValue({
        data: [{ id: 'p1', employee_id: 'e1', employees: { name: 'Ana', store_id: 's1' }, device_fingerprint: 'PC', status: 'approved', requested_at: '2026-11-19T00:10:00Z' }],
        error: null,
      }),
    };
    mockFrom.mockImplementation((table: string) => (table === 'cash_sessions' ? chainCash : chainPasses));

    const devices = await authRepository.getAuthorizedDevices('s1');
    expect(devices).toHaveLength(1);
    expect(selectPassesSpy.mock.calls[0][0]).not.toContain('role');
    expect(inDatesSpy).toHaveBeenCalledWith('pass_date', expect.any(Array));
    expect(inDatesSpy.mock.calls[0][1]).toHaveLength(2);
  });

  it('[CHK-115] auditRepository prioriza snapshot histórico actor_name aunque el JOIN vivo a employees sea null', async () => {
    const { auditRepository } = await import('../data/repositories/auditRepository');
    const chainAudit = {
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      order: vi.fn().mockReturnThis(),
      range: vi.fn().mockResolvedValue({
        data: [{
          id: 'log-1',
          created_at: '2026-11-19T12:00:00Z',
          store_id: 's1',
          event_type: 'EMPLOYEE_PERMISSIONS_UPDATED',
          actor_name: 'Carlos Snapshot',
          actor_role: 'owner',
          employees: null,
          metadata: { severity: 'info' },
        }],
        error: null,
      }),
    };
    mockFrom.mockReturnValueOnce(chainAudit);

    const logs = await auditRepository.getLogs('s1');
    expect(logs[0].user_name).toBe('Carlos Snapshot');
    expect(logs[0].actor_name).toBe('Carlos Snapshot');
    expect(logs[0].actor_role).toBe('owner');
  });

  it('[CHK-115] useHistory prioriza actor_name en gastos/ventas en lugar de hardcodear Cajero', async () => {
    const authStore = useAuthStore();
    authStore.currentUser = {
      id: 'admin-1',
      name: 'Dueño',
      email: 'admin@tienda.co',
      type: 'admin',
      storeId: 's1',
      permissions: { canManageInventory: true, canFiar: true, canOpenCloseCash: true, canManageRefunds: true },
    } as any;
    authStore.stores = [{ id: 's1', storeName: 'Tienda', ownerName: 'Dueño', email: 'admin@tienda.co', password: '', createdAt: '' }] as any;

    const todayIso = new Date().toISOString();
    const chainExpenses = {
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      gte: vi.fn().mockResolvedValue({
        data: [{
          id: 'mov-1',
          session_id: 'sess-1',
          movement_type: 'expense',
          amount: 15000,
          description: '[Servicios] Pago agua',
          category: 'Servicios',
          payment_method: 'efectivo',
          voucher_ref: null,
          sale_id: null,
          actor_id: 'emp-old',
          actor_name: 'Sofía Snapshot',
          actor_role: 'employee',
          created_at: todayIso,
        }],
        error: null,
      }),
    };
    mockFrom.mockReturnValue(chainExpenses);

    const { useHistory } = await import('../composables/useHistory');
    const history = useHistory();
    await history.fetchHistory('expenses', 'today');

    expect(history.items.value).toHaveLength(1);
    expect(history.items.value[0].user).toBe('Sofía Snapshot');
    expect(history.items.value[0].user).not.toBe('Cajero');
  });

  it('[CHK-113] router bloquea rutas Admin-only y exige permisos canónicos a empleados', async () => {
    const authStore = useAuthStore();

    // Empleado autenticado con solo canFiar = true
    authStore.loginAsEmployee(
      {
        id: 'emp-router',
        name: 'Cajero Router',
        username: '5555',
        permissions: {
          canManageInventory: false,
          canFiar: true,
          canOpenCloseCash: false,
          canManageRefunds: false,
        },
      },
      'store-1',
    );
    await authStore.checkDailyApproval();

    const { default: router } = await import('../router');

    await router.push('/pos');
    expect(router.currentRoute.value.name).toBe('pos');

    await router.push('/admin');
    expect(router.currentRoute.value.name).toBe('dashboard');

    await router.push('/reports');
    expect(router.currentRoute.value.name).toBe('dashboard');

    await router.push('/admin/financial-dashboard');
    expect(router.currentRoute.value.name).toBe('dashboard');

    await router.push('/inventory');
    expect(router.currentRoute.value.name).toBe('dashboard');

    await router.push('/stock-entry');
    expect(router.currentRoute.value.name).toBe('dashboard');

    await router.push('/cash-control');
    expect(router.currentRoute.value.name).toBe('dashboard');

    await router.push('/clients');
    expect(router.currentRoute.value.name).toBe('clients');

    // Camino feliz: empleado con canManageInventory y canOpenCloseCash accede a inventario y caja, pero sigue bloqueado en /reports
    authStore.loginAsEmployee(
      {
        id: 'emp-router-2',
        name: 'Bodeguero Caja',
        username: '6666',
        permissions: {
          canManageInventory: true,
          canFiar: false,
          canOpenCloseCash: true,
          canManageRefunds: false,
        },
      },
      'store-1',
    );
    await authStore.checkDailyApproval();

    await router.push('/inventory');
    expect(router.currentRoute.value.name).toBe('inventory');

    await router.push('/cash-control');
    expect(router.currentRoute.value.name).toBe('cash-control');

    await router.push('/reports');
    expect(router.currentRoute.value.name).toBe('dashboard');
    await flushPromises();
  });
});

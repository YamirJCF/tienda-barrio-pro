import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { useAuthStore } from '../stores/auth';
import { useReportsStore } from '../stores/reports';
import { useFinancialStore } from '../stores/financial';
import { auditRepository } from '../data/repositories/auditRepository';
import cashRepository from '../data/repositories/cashRepository';
import DashboardView from '../views/DashboardView.vue';
import MyShiftMovementsView from '../views/MyShiftMovementsView.vue';
import ShiftForensicDetailModal from '../components/history/ShiftForensicDetailModal.vue';
import { useHistory } from '../composables/useHistory';

const { mockRpc, mockFrom, mockPush } = vi.hoisted(() => ({
  mockRpc: vi.fn(),
  mockFrom: vi.fn(),
  mockPush: vi.fn(),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mockPush, back: vi.fn() }),
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

vi.mock('../composables/useCurrencyFormat', () => ({
  useCurrencyFormat: () => ({
    formatCurrency: (v: any) => String(v ?? 0),
    formatWithSign: (v: any) => `$ ${String(v ?? 0)}`,
  }),
}));

vi.mock('../composables/useNotifications', () => ({
  useNotifications: () => ({
    showWarning: vi.fn(),
    showError: vi.fn(),
    showSuccess: vi.fn(),
  }),
}));

vi.mock('../stores/sales', () => ({
  useSalesStore: () => ({
    initialize: vi.fn(),
    isStoreOpen: true,
    todayCount: 4,
    todayFiadoCount: 1,
  }),
}));

vi.mock('../stores/inventory', () => ({
  useInventoryStore: () => ({
    initialize: vi.fn(),
    totalProducts: 12,
    lowStockProducts: [],
  }),
}));

vi.mock('../stores/cashRegister', () => ({
  useCashRegisterStore: () => ({
    syncFromBackend: vi.fn().mockResolvedValue(true),
  }),
}));

vi.mock('../stores/notificationsStore', () => ({
  useNotificationsStore: () => ({
    fetchNotifications: vi.fn().mockResolvedValue([]),
    getVisibleUnreadCount: () => 0,
  }),
}));

vi.mock('../stores/devices', () => ({
  useDevicesStore: () => ({
    fetchPendingRequests: vi.fn(),
  }),
}));

describe('Fase 3 Ola 3 — Reportes y Auditoría 100% Admin-only + Mis Movimientos del Turno', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    mockRpc.mockReset();
    mockFrom.mockReset();
    mockPush.mockReset();
  });

  function setAdminUser() {
    const authStore = useAuthStore();
    authStore.stores = [{ id: 'store-1', storeName: 'Tienda Centro', ownerName: 'Don Carlos', email: 'carlos@tienda.co', password: '', createdAt: '' }] as any;
    authStore.currentUser = {
      id: 'admin-1',
      name: 'Don Carlos',
      email: 'carlos@tienda.co',
      type: 'admin',
      storeId: 'store-1',
      permissions: {
        canManageInventory: true,
        canFiar: true,
        canOpenCloseCash: true,
        canManageRefunds: true,
      },
    } as any;
    return authStore;
  }

  function setEmployeeUser(perms = {
    canManageInventory: false,
    canFiar: false,
    canOpenCloseCash: false,
    canManageRefunds: false,
  }) {
    const authStore = useAuthStore();
    authStore.stores = [{ id: 'store-1', storeName: 'Tienda Centro', ownerName: 'Don Carlos', email: 'carlos@tienda.co', password: '', createdAt: '' }] as any;
    authStore.currentUser = {
      id: 'emp-1',
      employeeId: 'emp-1',
      name: 'Laura Cajera',
      email: 'laura@tienda.co',
      type: 'employee',
      storeId: 'store-1',
      permissions: perms,
    } as any;
    return authStore;
  }

  it('[CHK-301] useReportsStore bloquea fetchDailySummary para empleado y procesa respuesta/rechazo Admin', async () => {
    setEmployeeUser();
    const reportsStore = useReportsStore();

    await reportsStore.fetchDailySummary();
    expect(mockRpc).not.toHaveBeenCalled();
    expect(reportsStore.summary).toBeNull();

    await expect(reportsStore.fetchSmartSupplyReport()).rejects.toThrow('Acceso exclusivo del Administrador.');

    setAdminUser();
    mockRpc.mockResolvedValueOnce({
      data: {
        traffic_light: { status: 'green', message: 'Bien' },
        hero_number: 65000,
        money_breakdown: { cash: 40000, transfer: 20000, credit: 5000, nequi: 12000, llave_bre: 8000 },
        alerts: [],
        reminder: { message: 'OK' },
      },
      error: null,
    });
    await reportsStore.fetchDailySummary('2026-11-19');
    expect(mockRpc).toHaveBeenCalledWith('get_daily_summary', { p_store_id: 'store-1', p_date: '2026-11-19' });
    expect(reportsStore.summary?.money_breakdown.nequi).toBe(12000);
    expect(reportsStore.summary?.money_breakdown.llave_bre).toBe(8000);

    mockRpc.mockResolvedValueOnce({
      data: null,
      error: { code: '42501', message: 'ADMIN_ONLY_ACTION: Esta acción es exclusiva del Administrador.' },
    });
    await reportsStore.fetchDailySummary();
    expect(reportsStore.summary).toBeNull();
    expect(reportsStore.error).toBe('Acceso exclusivo del Administrador.');
  });

  it('[CHK-302] useFinancialStore restringe consultas de P&L a Admin y mapea ADMIN_ONLY_ACTION', async () => {
    setEmployeeUser();
    const financialStore = useFinancialStore();
    await financialStore.setPeriod('today');
    expect(mockRpc).not.toHaveBeenCalled();
    expect(financialStore.error).toContain('solo administradores');
  });

  it('[CHK-303 / CHK-304] auditRepository NO retorna [] silencioso ante rechazo RLS y usa rpc_obtener_auditoria_evidence_hub', async () => {
    const chainForbidden = {
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      order: vi.fn().mockReturnThis(),
      range: vi.fn().mockResolvedValue({
        data: null,
        error: { code: '42501', message: 'permission denied for table audit_seguridad' },
      }),
    };
    mockFrom.mockReturnValueOnce(chainForbidden);

    await expect(auditRepository.getLogs('store-1')).rejects.toThrow('ADMIN_ONLY_ACTION');

    const chainPricesForbidden = {
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      order: vi.fn().mockReturnThis(),
      limit: vi.fn().mockResolvedValue({
        data: null,
        error: { code: '42501', message: 'permission denied for table audit_precios' },
      }),
    };
    mockFrom.mockReturnValueOnce(chainPricesForbidden);
    await expect(auditRepository.getPriceChangeLogs('store-1')).rejects.toThrow('ADMIN_ONLY_ACTION');

    setAdminUser();
    mockRpc.mockResolvedValueOnce({
      data: {
        data: [
          {
            id: 'evt-1',
            domain: 'inventario',
            event_type: 'INVENTORY_COUNT_ADJUSTMENT',
            severity: 'warning',
            resource_id: 'prod-1',
            actor_id: 'emp-1',
            actor_name: 'Carlos Snapshot',
            actor_role: 'employee',
            ip_address: null,
            created_at: '2026-11-19T15:00:00Z',
            metadata: { product_name: 'Arroz 1kg' },
          },
        ],
        count: 1,
      },
      error: null,
    });

    const history = useHistory();
    await history.fetchHistory('audit', 'week');
    expect(mockRpc).toHaveBeenCalledWith(
      'rpc_obtener_auditoria_evidence_hub',
      expect.objectContaining({ p_store_id: 'store-1', p_domain: 'todos' })
    );
    expect(history.items.value).toHaveLength(1);
    expect(history.items.value[0].title).toBe('Ajuste por Conteo Físico');
    expect(history.items.value[0].badge?.text).toBe('Alerta');
    expect(history.items.value[0].user).toBe('Carlos Snapshot');
  });

  it('[CHK-305 / CHK-308] MyShiftMovementsView consume rpc_obtener_mis_movimientos_turno con filtros y maneja error sin silencio', async () => {
    setEmployeeUser();
    mockRpc.mockResolvedValueOnce({
      data: {
        data: [
          {
            id: 'mov-1',
            source: 'sale',
            payment_method: 'llave_bre',
            amount: 24000,
            description: 'Venta #109',
            category: 'Venta POS',
            created_at: '2026-11-19T14:20:00Z',
            actor_name: 'Laura Cajera',
            actor_role: 'employee',
          },
          {
            id: 'mov-2',
            source: 'personal_withdrawal',
            payment_method: 'consumo_personal',
            amount: 0,
            description: 'Venta #110',
            category: 'Retiro Personal',
            created_at: '2026-11-19T14:35:00Z',
            actor_name: 'Laura Cajera',
            actor_role: 'employee',
          },
        ],
        count: 2,
        has_open_shift: true,
        shift_id: 'sess-1',
        shift_opened_at: '2026-11-19T08:00:00Z',
      },
      error: null,
    });

    const wrapper = mount(MyShiftMovementsView, {
      global: {
        stubs: { BaseButton: { template: '<button><slot /></button>' } },
      },
    });
    await flushPromises();

    expect(mockRpc).toHaveBeenCalledWith('rpc_obtener_mis_movimientos_turno', {
      p_store_id: 'store-1',
      p_payment_method: 'all',
      p_limit: 100,
      p_offset: 0,
    });
    expect(wrapper.text()).toContain('Venta #109');
    expect(wrapper.text()).toContain('Llave Bre-B');
    expect(wrapper.text()).toContain('Retiro Personal ($0)');
    expect(wrapper.text()).not.toContain('expected_balance');

    mockRpc.mockResolvedValueOnce({
      data: null,
      error: { message: 'STORE_ACCESS_DENIED: Permiso revocado' },
    });
    await wrapper.findAll('button').find(b => b.text() === 'Nequi')!.trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('STORE_ACCESS_DENIED');
  });

  it('[CHK-306] ShiftForensicDetailModal muestra desglose multicanal y rechaza no-admin explícitamente', async () => {
    mockRpc.mockResolvedValueOnce({
      data: {
        success: true,
        data: {
          session: {
            id: 'sess-99',
            store_id: 'store-1',
            status: 'closed',
            forced_close: false,
            forced_close_without_count: false,
            closing_attempts: 2,
            opened_at: '2026-11-19T08:00:00Z',
            closed_at: '2026-11-19T20:00:00Z',
            opened_by_name: 'Ana Cajera',
            opened_by_role: 'employee',
            closed_by_name: 'Don Carlos',
            closed_by_role: 'owner',
            opening_balance: 50000,
            expected_balance: 90000,
            actual_balance: 88000,
            difference: -2000,
          },
          financial_summary: {
            total_sales_cash: 40000,
            total_sales_nequi: 25000,
            total_sales_llave_bre: 10000,
            total_sales_transfer: 35000,
            total_credit_sales: 15000,
            total_client_abonos: 5000,
            total_opex_expenses: 3000,
            total_refunds: 2000,
            total_supplier_payments: 12000,
            net_cash_flow: 63000,
          },
          movements: [],
          operational_noise: {
            voided_sales: [
              {
                sale_id: 's-1',
                ticket_number: 55,
                total: 8000,
                payment_method: 'efectivo',
                void_reason: 'Error de digitación',
                voided_by_name: 'Don Carlos',
                voided_by_role: 'owner',
                voided_at: '2026-11-19T13:00:00Z',
              },
            ],
            security_alerts: [],
          },
        },
      },
      error: null,
    });

    const wrapper = mount(ShiftForensicDetailModal, {
      props: { modelValue: true, sessionId: 'sess-99' },
      global: { stubs: { BaseButton: { template: '<button><slot /></button>' } } },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('Ana Cajera');
    expect(wrapper.text()).toContain('(2/3)');
    expect(wrapper.text()).toContain('Pagos a Proveedores');
    expect(wrapper.text()).toContain('Anulación Ticket #55');

    mockRpc.mockResolvedValueOnce({
      data: null,
      error: { code: '42501', message: 'ADMIN_ONLY_ACTION: Solo admin' },
    });
    await expect(cashRepository.getShiftForensicReport('sess-99')).rejects.toThrow('ADMIN_ONLY_ACTION');
  });

  it('[CHK-307 / CHK-308] DashboardView oculta KPIs financieros y accesos no autorizados para empleado; Admin sí los consulta', async () => {
    setEmployeeUser({
      canManageInventory: false,
      canFiar: false,
      canOpenCloseCash: false,
      canManageRefunds: false,
    });

    const empWrapper = mount(DashboardView, {
      global: {
        stubs: {
          BottomNav: true,
          UserProfileSidebar: true,
          SyncIndicator: true,
          StatCard: { props: ['title', 'value'], template: '<div data-test="stat-card">{{ title }}:{{ value }}</div>' },
        },
      },
    });
    await flushPromises();

    expect(mockRpc).not.toHaveBeenCalledWith('get_daily_summary', expect.anything());
    expect(empWrapper.find('[data-test="admin-kpi-grid"]').exists()).toBe(false);
    expect(empWrapper.find('[data-test="employee-shift-card"]').exists()).toBe(true);
    expect(empWrapper.text()).not.toContain('Caja Real');
    expect(empWrapper.text()).not.toContain('Ver Clientes');
    expect(empWrapper.text()).not.toContain('Gestionar Productos');
    expect(empWrapper.text()).toContain('Mis Movimientos del Turno');

    mockRpc.mockClear();
    setAdminUser();
    mockRpc.mockResolvedValueOnce({
      data: {
        traffic_light: { status: 'green', message: 'OK' },
        hero_number: 50000,
        money_breakdown: { cash: 30000, transfer: 20000, credit: 0 },
        alerts: [],
        reminder: { message: 'OK' },
      },
      error: null,
    });

    const adminWrapper = mount(DashboardView, {
      global: {
        stubs: {
          BottomNav: true,
          UserProfileSidebar: true,
          SyncIndicator: true,
          StatCard: { props: ['title', 'value'], template: '<div data-test="stat-card">{{ title }}:{{ value }}</div>' },
        },
      },
    });
    await flushPromises();

    expect(mockRpc).toHaveBeenCalledWith('get_daily_summary', { p_store_id: 'store-1' });
    expect(adminWrapper.find('[data-test="admin-kpi-grid"]').exists()).toBe(true);
    expect(adminWrapper.text()).toContain('Caja Real');
  });

  it('[CHK-305 / B3-5] cashRepository.getMultichannelCashHistory y ShiftForensicDetailModal filtran por canal vía RPC y propagan ADMIN_ONLY_ACTION', async () => {
    mockRpc.mockResolvedValueOnce({
      data: {
        success: true,
        data: {
          session: {
            id: 'sess-99',
            store_id: 'store-1',
            status: 'closed',
            forced_close: false,
            forced_close_without_count: false,
            closing_attempts: 1,
            opened_at: '2026-11-19T08:00:00Z',
            closed_at: '2026-11-19T20:00:00Z',
            opened_by_name: 'Ana Cajera',
            opened_by_role: 'employee',
            closed_by_name: 'Don Carlos',
            closed_by_role: 'owner',
            opening_balance: 50000,
            expected_balance: 90000,
            actual_balance: 90000,
            difference: 0,
          },
          financial_summary: {
            total_sales_cash: 25000,
            total_sales_nequi: 15000,
            total_sales_llave_bre: 0,
            total_sales_transfer: 15000,
            total_credit_sales: 0,
            total_client_abonos: 0,
            total_opex_expenses: 0,
            total_refunds: 0,
            total_supplier_payments: 0,
            net_cash_flow: 40000,
          },
          movements: [],
          operational_noise: { voided_sales: [], security_alerts: [] },
        },
      },
      error: null,
    });

    const wrapper = mount(ShiftForensicDetailModal, {
      props: { modelValue: true, sessionId: 'sess-99' },
      global: { stubs: { BaseButton: { template: '<button><slot /></button>' } } },
    });
    await flushPromises();

    mockRpc.mockResolvedValueOnce({
      data: {
        success: true,
        data: [
          {
            id: 'cm-nequi-1',
            session_id: 'sess-99',
            movement_type: 'ingreso',
            origin_type: 'venta',
            amount: 15000,
            payment_method: 'nequi',
            description: 'Venta #201 Nequi',
            actor_name: 'Ana Cajera',
            actor_role: 'employee',
            created_at: '2026-11-19T11:00:00Z',
          },
        ],
        count: 1,
      },
      error: null,
    });

    await wrapper.find('[data-test="shift-channel-filters"] button[data-channel="nequi"]').trigger('click');
    await flushPromises();

    expect(mockRpc).toHaveBeenCalledWith(
      'rpc_obtener_historial_caja_multicanal',
      expect.objectContaining({ p_store_id: 'store-1', p_session_id: 'sess-99', p_payment_method: 'nequi' })
    );
    expect(wrapper.text()).toContain('Venta #201 Nequi');

    mockRpc.mockResolvedValueOnce({
      data: null,
      error: { code: '42501', message: 'ADMIN_ONLY_ACTION: Acceso restringido' },
    });
    await expect(
      cashRepository.getMultichannelCashHistory({ storeId: 'store-1', paymentMethod: 'llave_bre' })
    ).rejects.toThrow('ADMIN_ONLY_ACTION');
  });

  it('[CHK-302 / B3-5] useHistory propaga ADMIN_ONLY_ACTION en sales/inventory/credits y fetchCreditLogs usa -05:00 + abono', async () => {
    setAdminUser();
    const history = useHistory();

    mockRpc.mockResolvedValueOnce({
      data: null,
      error: { code: '42501', message: 'ADMIN_ONLY_ACTION: Solo administradores' },
    });
    await history.fetchHistory('sales', 'today');
    expect(history.error.value).toBe('Acceso exclusivo del Administrador.');

    mockRpc.mockResolvedValueOnce({
      data: null,
      error: { code: '42501', message: 'ADMIN_ONLY_ACTION: Solo administradores' },
    });
    await history.fetchHistory('inventory', 'today');
    expect(history.error.value).toBe('Acceso exclusivo del Administrador.');

    mockRpc.mockResolvedValueOnce({
      data: null,
      error: { code: '42501', message: 'ADMIN_ONLY_ACTION: Solo administradores' },
    });
    await history.fetchHistory('credits', 'today');
    expect(history.error.value).toBe('Acceso exclusivo del Administrador.');

    mockRpc.mockResolvedValueOnce({
      data: [
        {
          id: 'cred-1',
          client_name: 'Doña Rosa',
          transaction_type: 'abono',
          amount: 20000,
          description: 'Abono a deuda',
          employee_name: 'Don Carlos',
          created_at: '2026-11-19T19:00:00-05:00',
        },
        {
          id: 'cred-2',
          client_name: 'Don Luis',
          transaction_type: 'venta_fiado',
          amount: 12000,
          description: 'Venta fiado',
          employee_name: 'Don Carlos',
          created_at: '2026-11-19T18:00:00-05:00',
        },
      ],
      error: null,
    });
    await history.fetchHistory('credits', 'today');
    expect(mockRpc).toHaveBeenLastCalledWith(
      'get_history_creditos',
      expect.objectContaining({
        p_store_id: 'store-1',
        p_start_date: expect.stringMatching(/T00:00:00-05:00$/),
        p_end_date: expect.stringMatching(/T23:59:59-05:00$/),
      })
    );
    expect(history.items.value[0].colorClass).toContain('emerald');
    expect(history.items.value[1].colorClass).toContain('red');
  });
});

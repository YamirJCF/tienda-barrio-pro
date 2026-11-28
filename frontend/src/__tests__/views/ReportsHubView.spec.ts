import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { reactive, ref } from 'vue';
import { Decimal } from 'decimal.js';

import ReportsHubView from '../../views/ReportsHubView.vue';
import FinancialDashboardTab from '../../components/reports/FinancialDashboardTab.vue';
import AuditHistoryTab from '../../components/reports/AuditHistoryTab.vue';
import ClientLedgerWidget from '../../components/reports/ClientLedgerWidget.vue';
import SaleDetailModal from '../../components/history/SaleDetailModal.vue';
import ShiftForensicDetailModal from '../../components/history/ShiftForensicDetailModal.vue';
import { expenseRepository } from '../../data/repositories/expenseRepository';
import { useFinancialStore } from '../../stores/financial';
import { useAuthStore } from '../../stores/auth';
import { useHistory } from '../../composables/useHistory';

enableAutoUnmount(afterEach);

afterEach(() => {
  vi.useRealTimers();
});

const {
  mockPush,
  mockReplace,
  mockRpc,
  mockFrom,
  mockShowWarning,
  mockShowError,
  mockShowSuccess,
  mockRoute,
} = vi.hoisted(() => ({
  mockPush: vi.fn(),
  mockReplace: vi.fn(),
  mockRpc: vi.fn(),
  mockFrom: vi.fn(),
  mockShowWarning: vi.fn(),
  mockShowError: vi.fn(),
  mockShowSuccess: vi.fn(),
  mockRoute: {
    path: '/reports',
    query: {} as Record<string, string>,
  },
}));

const reactiveRoute = reactive(mockRoute);

vi.mock('vue-router', () => ({
  useRouter: () => ({
    push: mockPush,
    replace: mockReplace,
  }),
  useRoute: () => reactiveRoute,
}));

vi.mock('../../data/supabaseClient', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../../data/supabaseClient')>();
  return {
    ...actual,
    isAuditMode: () => false,
    isSupabaseConfigured: () => true,
    getSupabaseClient: () => ({
      rpc: mockRpc,
      from: mockFrom,
    }),
    requireSupabase: () => ({
      rpc: mockRpc,
      from: mockFrom,
    }),
  };
});

vi.mock('../../data/repositories/auditRepository', () => ({
  auditRepository: {
    getLogs: vi.fn().mockResolvedValue({ success: true, data: [] }),
  },
}));

vi.mock('../../stores/employees', () => ({
  useEmployeesStore: () => ({
    activeOperationalEmployees: [],
    initialize: vi.fn().mockResolvedValue(undefined),
  }),
}));

vi.mock('@/composables/useNotifications', () => ({
  useNotifications: () => ({
    showWarning: mockShowWarning,
    showError: mockShowError,
    showSuccess: mockShowSuccess,
    showInfo: vi.fn(),
  }),
}));

const commonStubs = {
  BottomNav: true,
  ShiftForensicDetailModal: true,
  HistoryItemCard: true,
  BaseDropdown: {
    props: ['modelValue', 'options'],
    template: '<div data-testid="dropdown-stub"></div>',
  },
  BaseModal: {
    props: ['modelValue', 'title'],
    template: '<div v-if="modelValue"><slot /><slot name="footer" /></div>',
  },
  BaseButton: {
    props: ['disabled', 'loading'],
    template: '<button :disabled="disabled"><slot /></button>',
  },
};

let mockOnline = true;
Object.defineProperty(navigator, 'onLine', {
  configurable: true,
  get: () => mockOnline,
});

function setNavigatorOnline(value: boolean) {
  mockOnline = value;
}

describe('WO-OLA2-C6-001: Centro de Inteligencia y Auditoría (/reports)', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    setNavigatorOnline(true);

    reactiveRoute.path = '/reports';
    reactiveRoute.query = {};

    const authStore = useAuthStore();
    authStore.stores = [
      {
        id: 'store-001',
        storeName: 'Tienda Test',
        ownerName: 'Admin Test',
        email: 'admin@test.local',
        password: '',
        createdAt: '',
      },
    ];
    authStore.currentUser = {
      id: 'user-001',
      name: 'Admin Test',
      email: 'admin@test.local',
      type: 'admin',
      storeId: 'store-001',
    };

    mockRpc.mockImplementation(async (fnName: string) => {
      if (fnName === 'get_inventory_health') {
        return {
          data: {
            valor_total: 300000,
            dias_inventario: 15,
            estado: 'optimo',
            distribucion_rotacion: {
              rapida: { count: 5, valor: 150000, porcentaje: 50 },
              normal: { count: 4, valor: 120000, porcentaje: 40 },
              lenta: { count: 1, valor: 30000, porcentaje: 10 },
            },
          },
          error: null,
        };
      }
      if (fnName === 'get_client_ledger_summary') {
        return {
          data: {
            cartera_vencida: 25000,
            cartera_total: 40000,
            clientes_morosos: 1,
            top_deudores: [
              {
                client_id: 'cli-1',
                client_name: 'Don Pedro',
                dias_sin_pagar: 35,
                balance: 25000,
              },
            ],
          },
          error: null,
        };
      }
      if (fnName === 'get_stagnant_products') {
        return { data: [], error: null };
      }
      if (fnName === 'rpc_get_comprehensive_financial_report') {
        return {
          data: {
            revenue: 150000,
            cogs: 90000,
            gross_profit: 60000,
            gross_margin: 40,
            operational_expenses: 10000,
            net_profit: 50000,
            inventory_value: 300000,
            traffic_light: { status: 'green', message: 'Buen margen' },
            payment_breakdown: { cash: 100000, transfer: 30000, credit: 20000 },
            transactions_count: 4,
          },
          error: null,
        };
      }
      if (fnName === 'get_top_products_by_units') {
        return {
          data: [
            {
              product_id: 'prod-1',
              product_name: 'Arroz Roa 500g',
              units_sold: 12,
              dias_rotacion: 3,
              stock_actual: 20,
            },
          ],
          error: null,
        };
      }
      if (fnName === 'get_history_ventas') {
        return { data: [], error: null };
      }
      if (fnName === 'rpc_anular_venta') {
        return {
          data: null,
          error: { message: 'CREDIT_REVERSAL_BLOCKED: El cliente ya abonó parte de esta venta.' },
        };
      }
      if (fnName === 'get_sale_detail') {
        return {
          data: {
            success: true,
            id: 'sale-1',
            ticket_number: 42,
            created_at: '2026-11-25T15:00:00Z',
            total: 12000,
            payment_method: 'fiado',
            is_voided: false,
            client_id: 'cli-99',
            client_name: 'María Pérez',
            employee_name: 'Cajero 1',
            items_count: 1,
            items: [
              {
                product_id: 'prod-99',
                product_name: 'Aceite 1L',
                quantity: 1,
                unit_price: 12000,
                subtotal: 12000,
              },
            ],
          },
          error: null,
        };
      }
      return { data: null, error: null };
    });
  });

  it('1. Lazy mounting (v-if/v-else): al abrir /reports solo monta Dashboard y NO dispara RPCs de Historial hasta cambiar de tab', async () => {
    const wrapper = mount(ReportsHubView, {
      global: { stubs: commonStubs },
    });
    await flushPromises();

    expect(wrapper.findComponent(FinancialDashboardTab).exists()).toBe(true);
    expect(wrapper.findComponent(AuditHistoryTab).exists()).toBe(false);

    const calledFnsBefore = mockRpc.mock.calls.map((c) => c[0]);
    expect(calledFnsBefore).toContain('rpc_get_comprehensive_financial_report');
    expect(calledFnsBefore).not.toContain('get_history_ventas');

    await wrapper.get('[data-testid="reports-tab-history"]').trigger('click');
    await flushPromises();

    expect(wrapper.findComponent(FinancialDashboardTab).exists()).toBe(false);
    expect(wrapper.findComponent(AuditHistoryTab).exists()).toBe(true);
    expect(mockReplace).toHaveBeenCalledWith({
      path: '/reports',
      query: { tab: 'history' },
    });

    const calledFnsAfter = mockRpc.mock.calls.map((c) => c[0]);
    expect(calledFnsAfter).toContain('get_history_ventas');
  });

  it('2. Normaliza rutas alias (/admin/financial-dashboard y /history) a /reports?tab= y respeta ?from=admin en Volver', async () => {
    reactiveRoute.path = '/admin/financial-dashboard';
    reactiveRoute.query = { from: 'admin' };

    const wrapper1 = mount(ReportsHubView, {
      global: { stubs: commonStubs },
    });
    await flushPromises();

    expect(mockReplace).toHaveBeenCalledWith({
      path: '/reports',
      query: { from: 'admin', tab: 'dashboard' },
    });
    expect(wrapper1.findComponent(FinancialDashboardTab).exists()).toBe(true);

    await wrapper1.get('[data-testid="reports-back-btn"]').trigger('click');
    expect(mockPush).toHaveBeenCalledWith('/admin');

    vi.clearAllMocks();
    reactiveRoute.path = '/history';
    reactiveRoute.query = {};

    const wrapper2 = mount(ReportsHubView, {
      global: { stubs: commonStubs },
    });
    await flushPromises();

    expect(mockReplace).toHaveBeenCalledWith({
      path: '/reports',
      query: { tab: 'history' },
    });
    expect(wrapper2.findComponent(AuditHistoryTab).exists()).toBe(true);

    await wrapper2.get('[data-testid="reports-back-btn"]').trigger('click');
    expect(mockPush).toHaveBeenCalledWith('/');
  });

  it('3. Zona horaria America/Bogota en getDateRange (medianoche UTC sigue siendo día anterior en Bogotá) y eliminación de totalStagnantValue', () => {
    // 2026-11-26 02:00 UTC = 2026-11-25 21:00 America/Bogota (UTC-5)
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-11-26T02:00:00.000Z'));

    const store = useFinancialStore();
    const todayRange = store.getDateRange('today');
    expect(todayRange).toEqual({
      start: '2026-11-25',
      end: '2026-11-25',
    });

    const weekRange = store.getDateRange('week');
    expect(weekRange).toEqual({
      start: '2026-11-19',
      end: '2026-11-25',
    });

    expect('totalStagnantValue' in store).toBe(false);
  });

  it('4. Fail-closed offline (Regla 3): en offline no llama RPCs y muestra banner N3 con Reintentar en Dashboard y Auditoría', async () => {
    setNavigatorOnline(false);

    const dashWrapper = mount(FinancialDashboardTab, {
      global: { stubs: commonStubs },
    });
    await flushPromises();

    expect(mockRpc).not.toHaveBeenCalled();
    expect(dashWrapper.get('[data-testid="financial-error-banner"]').text()).toContain('Sin conexión');
    expect(dashWrapper.find('[data-testid="financial-retry-btn"]').exists()).toBe(true);

    const histWrapper = mount(AuditHistoryTab, {
      global: { stubs: commonStubs },
    });
    await flushPromises();

    expect(mockRpc).not.toHaveBeenCalled();
    expect(histWrapper.get('[data-testid="history-error-banner"]').text()).toContain('Sin conexión');
    expect(histWrapper.find('[data-testid="history-retry-btn"]').exists()).toBe(true);
    expect(histWrapper.text()).not.toContain('Sin registros');
  });

  it('5. Enlaces heterárquicos reales: Top Ventas, ClientLedgerWidget y SaleDetailModal navegan sin callejones sin salida', async () => {
    const dashWrapper = mount(FinancialDashboardTab, {
      global: { stubs: commonStubs },
    });
    await flushPromises();

    await dashWrapper.get('[data-testid="top-product-link"]').trigger('click');
    expect(mockPush).toHaveBeenCalledWith({
      path: '/inventory',
      query: { productId: 'prod-1' },
    });

    const ledgerWrapper = mount(ClientLedgerWidget, {
      props: {
        ledger: {
          cartera_vencida: 25000,
          cartera_total: 40000,
          clientes_morosos: 1,
          top_deudores: [
            {
              client_id: 'cli-1',
              client_name: 'Don Pedro',
              dias_sin_pagar: 35,
              balance: 25000,
            },
          ],
        },
        isLoading: false,
      },
    });

    await ledgerWrapper.get('[data-testid="ledger-clients-link"]').trigger('click');
    expect(mockPush).toHaveBeenCalledWith({
      path: '/clients',
      query: { debt: 'with_debt' },
    });

    await ledgerWrapper.get('[data-testid="ledger-debtor-link"]').trigger('click');
    expect(mockPush).toHaveBeenCalledWith('/clients/cli-1');

    const modalWrapper = mount(SaleDetailModal, {
      props: {
        modelValue: true,
        saleId: 'sale-1',
      },
      global: { stubs: commonStubs },
    });
    await flushPromises();

    await modalWrapper.get('[data-testid="sale-detail-client-link"]').trigger('click');
    expect(mockPush).toHaveBeenCalledWith('/clients/cli-99');

    await modalWrapper.get('[data-testid="sale-detail-product-link"]').trigger('click');
    expect(mockPush).toHaveBeenCalledWith({
      path: '/inventory',
      query: { productId: 'prod-99' },
    });

    // N1 inline validation & server error sin doble toast
    await modalWrapper.get('[data-testid="open-void-panel-btn"]').trigger('click');
    expect(
      modalWrapper.get('[data-testid="confirm-void-sale-btn"]').attributes('disabled')
    ).toBeDefined();

    await modalWrapper.get('textarea').setValue('Error de digitación en venta de prueba');
    await modalWrapper.get('[data-testid="confirm-void-sale-btn"]').trigger('click');
    await flushPromises();

    expect(modalWrapper.get('[data-testid="void-sale-error"]').text()).toContain(
      'No se puede anular esta venta fiada'
    );
    expect(mockShowWarning).not.toHaveBeenCalled();
    expect(mockShowError).not.toHaveBeenCalled();
  });

  it('6. Dominio expenses en rango week/yesterday usa expenseRepository.getExpensesByDateRange (America/Bogota) y no trunca a hoy', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-11-26T02:00:00.000Z')); // 2026-11-25 21:00 en Bogotá

    const getRangeSpy = vi.spyOn(expenseRepository, 'getExpensesByDateRange');
    const getTodaySpy = vi.spyOn(expenseRepository, 'getTodayExpenses');

    const chain = {
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      gte: vi.fn().mockReturnThis(),
      lte: vi.fn().mockReturnThis(),
      order: vi.fn().mockResolvedValue({
        data: [
          {
            id: 'exp-yesterday-1',
            amount: 18000,
            description: '[Servicios] Agua ayer',
            category: 'Servicios',
            payment_method: 'efectivo',
            created_at: '2026-11-24T20:00:00-05:00',
            actor_name: 'Carlos',
          },
        ],
        error: null,
      }),
    };
    mockFrom.mockReturnValue(chain);

    const history = useHistory();
    await history.fetchHistory('expenses', 'yesterday');

    expect(getRangeSpy).toHaveBeenCalledWith('store-001', '2026-11-24', '2026-11-24');
    expect(getTodaySpy).not.toHaveBeenCalled();
    expect(chain.gte).toHaveBeenCalledWith('created_at', '2026-11-24T00:00:00-05:00');
    expect(chain.lte).toHaveBeenCalledWith('created_at', '2026-11-24T23:59:59.999-05:00');
    expect(history.items.value).toHaveLength(1);
    expect(history.items.value[0].id).toBe('exp-yesterday-1');
  });

  it('7. AuditHistoryTab refresca al emitir @voided desde SaleDetailModal y muestra Read Model en showVoidModal', async () => {
    let salesFetchCount = 0;
    mockRpc.mockImplementation(async (fnName: string) => {
      if (fnName === 'get_history_ventas') {
        salesFetchCount += 1;
        return {
          data: [
            {
              id: 'sale-42',
              ticket_number: 42,
              items_count: 1,
              payment_method: 'fiado',
              client_name: 'María Pérez',
              total: 12000,
              is_voided: salesFetchCount > 1,
              actor_name: 'Admin Test',
              created_at: '2026-11-25T15:00:00Z',
            },
          ],
          error: null,
        };
      }
      if (fnName === 'get_sale_detail') {
        return {
          data: {
            success: true,
            id: 'sale-42',
            ticket_number: 42,
            created_at: '2026-11-25T15:00:00Z',
            total: 12000,
            payment_method: 'fiado',
            is_voided: false,
            client_id: 'cli-99',
            client_name: 'María Pérez',
            employee_name: 'Cajero 1',
            items_count: 1,
            items: [
              {
                product_id: 'prod-99',
                product_name: 'Aceite 1L',
                quantity: 1,
                unit_price: 12000,
                subtotal: 12000,
              },
            ],
          },
          error: null,
        };
      }
      if (fnName === 'rpc_anular_venta') {
        return { data: { success: true }, error: null };
      }
      return { data: null, error: null };
    });

    const histWrapper = mount(AuditHistoryTab, {
      props: { initialDomain: 'sales' },
      global: {
        stubs: {
          ...commonStubs,
          HistoryItemCard: {
            props: ['item'],
            template: '<button data-testid="history-card-stub" @click="$emit(\'click\', item.id)">{{ item.title }}</button>',
          },
        },
      },
    });
    await flushPromises();
    expect(salesFetchCount).toBe(1);

    await histWrapper.get('[data-testid="history-card-stub"]').trigger('click');
    await flushPromises();

    await histWrapper.get('[data-testid="open-void-panel-btn"]').trigger('click');
    const readModel = histWrapper.get('[data-testid="void-sale-read-model"]').text();
    expect(readModel).toContain('Venta #42');
    expect(readModel).toContain('$ 12.000');
    expect(readModel).toContain('Fiado');
    expect(readModel).toContain('María Pérez');

    await histWrapper.get('textarea').setValue('Anulación por corrección de prueba');
    await histWrapper.get('[data-testid="confirm-void-sale-btn"]').trigger('click');
    await flushPromises();

    expect(salesFetchCount).toBe(2);
  });

  it('8. ShiftForensicDetailModal usa BaseModal y renderiza Gastos OPEX y Reembolsos separados sin emojis ni doble $', async () => {
    mockRpc.mockResolvedValueOnce({
      data: {
        success: true,
        data: {
          session: {
            id: 'sess-99',
            store_id: 'store-001',
            opening_balance: 50000,
            expected_balance: 120000,
            actual_balance: 120000,
            difference: 0,
            closing_attempts: 1,
            opened_by_name: 'Ana',
            opened_by_role: 'employee',
            closed_by_name: 'Admin',
            forced_close: false,
          },
          financial_summary: {
            total_sales_cash: 70000,
            total_sales_nequi: 20000,
            total_sales_llave_bre: 10000,
            total_client_abonos: 5000,
            total_opex_expenses: 18000,
            total_refunds: 4500,
            total_supplier_payments: 30000,
          },
          movements: [],
          operational_noise: { voided_sales: [], security_alerts: [] },
        },
      },
      error: null,
    });

    const wrapper = mount(ShiftForensicDetailModal, {
      props: { modelValue: true, sessionId: 'sess-99' },
      global: {
        stubs: {
          BaseModal: {
            props: ['modelValue'],
            template: '<div v-if="modelValue"><slot name="header" /><slot /><slot name="footer" /></div>',
          },
          BaseButton: commonStubs.BaseButton,
        },
      },
    });
    await flushPromises();

    const opexText = wrapper.get('[data-testid="shift-forensic-opex"]').text();
    const refundsText = wrapper.get('[data-testid="shift-forensic-refunds"]').text();
    expect(opexText).toContain('Gastos de Caja');
    expect(opexText).toContain('-$ 18.000');
    expect(refundsText).toContain('Reembolsos');
    expect(refundsText).toContain('-$ 4.500');
    expect(wrapper.text()).not.toContain('22.500');
    expect(wrapper.text()).not.toMatch(/[\u{1F300}-\u{1FAFF}]/u);
  });

  it('9. useFinancialStore.setPeriod con cambio rápido honra únicamente el último período seleccionado (seq)', async () => {
    let resolveSlow!: (v: any) => void;
    let resolveFast!: (v: any) => void;

    mockRpc.mockImplementation(async (fnName: string, params: any) => {
      if (fnName === 'rpc_get_comprehensive_financial_report') {
        if (params.p_start_date === params.p_end_date) {
          return await new Promise((res) => { resolveSlow = res; });
        }
        return await new Promise((res) => { resolveFast = res; });
      }
      if (fnName === 'get_top_products_by_units') {
        return { data: [], error: null };
      }
      return { data: null, error: null };
    });

    const store = useFinancialStore();
    const slowToday = store.setPeriod('today');
    const fastMonth = store.setPeriod('month');

    await flushPromises();
    resolveFast({
      data: {
        revenue: 999000,
        cogs: 500000,
        gross_profit: 499000,
        gross_margin: 50,
        operational_expenses: 50000,
        net_profit: 449000,
        inventory_value: 300000,
        traffic_light: { status: 'green', message: 'Mes óptimo' },
        payment_breakdown: { cash: 999000, transfer: 0, credit: 0 },
      },
      error: null,
    });
    await fastMonth;

    resolveSlow({
      data: {
        revenue: 1000,
        cogs: 500,
        gross_profit: 500,
        gross_margin: 50,
        operational_expenses: 0,
        net_profit: 500,
        inventory_value: 300000,
        traffic_light: { status: 'gray', message: 'Hoy obsoleto' },
        payment_breakdown: { cash: 1000, transfer: 0, credit: 0 },
      },
      error: null,
    });
    await slowToday;

    expect(store.activePeriod).toBe('month');
    expect(store.summary?.revenue).toBe(999000);
    expect(store.isLoadingTimeSeries).toBe(false);
  });
});

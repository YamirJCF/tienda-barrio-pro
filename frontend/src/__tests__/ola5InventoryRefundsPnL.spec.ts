import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import Decimal from 'decimal.js';
import { useAuthStore } from '../stores/auth';
import { useInventoryStore } from '../stores/inventory';
import { useFinancialStore } from '../stores/financial';
import { useCashRegisterStore } from '../stores/cashRegister';
import { productRepository } from '../data/repositories/productRepository';
import StockEntryView from '../views/StockEntryView.vue';
import DashboardView from '../views/DashboardView.vue';
import POSView from '../views/POSView.vue';
import RefundModal from '../components/sales/RefundModal.vue';
import ProductKardexTab from '../components/inventory/ProductKardexTab.vue';
import FinancialDashboardTab from '../components/reports/FinancialDashboardTab.vue';
import ProductFormModal from '../components/ProductFormModal.vue';

const {
  mockRpc,
  mockFrom,
  mockPush,
  mockShowError,
  mockShowSuccess,
  mockShowWarning,
} = vi.hoisted(() => ({
  mockRpc: vi.fn(),
  mockFrom: vi.fn(),
  mockPush: vi.fn(),
  mockShowError: vi.fn(),
  mockShowSuccess: vi.fn(),
  mockShowWarning: vi.fn(),
}));

vi.mock('idb', () => ({
  openDB: vi.fn().mockResolvedValue({
    count: vi.fn().mockResolvedValue(0),
    put: vi.fn().mockResolvedValue(undefined),
    getAll: vi.fn().mockResolvedValue([]),
  }),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: mockPush, back: vi.fn() }),
  useRoute: () => ({ params: {}, query: {} }),
}));

vi.mock('vue-toastification', () => ({
  useToast: () => ({
    success: mockShowSuccess,
    error: mockShowError,
    warning: mockShowWarning,
    info: vi.fn(),
  }),
}));

vi.mock('../composables/useNotifications', () => ({
  useNotifications: () => ({
    showSuccess: mockShowSuccess,
    showError: mockShowError,
    showWarning: mockShowWarning,
    showInfo: vi.fn(),
    addNotification: vi.fn(),
  }),
}));

vi.mock('../composables/useHeartbeat', () => ({
  useHeartbeat: () => ({
    isPaused: { value: false },
    setPause: vi.fn(),
  }),
}));

vi.mock('../data/supabaseClient', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../data/supabaseClient')>();
  return {
    ...actual,
    isSupabaseConfigured: () => true,
    isAuditMode: () => false,
    getSupabaseClient: () => ({
      rpc: mockRpc,
      from: mockFrom,
      channel: vi.fn(() => ({
        on: vi.fn().mockReturnThis(),
        subscribe: vi.fn().mockReturnValue({}),
      })),
      removeChannel: vi.fn(),
    }),
  };
});

const STORE_ID = 'store-1';

function setEmpSession(
  authStore: ReturnType<typeof useAuthStore>,
  perms: { canManageInventory?: boolean; canManageRefunds?: boolean },
  name = 'Cajero Estándar',
  id = 'emp-1',
) {
  authStore.loginAsEmployee(
    {
      id,
      name,
      username: '1001',
      permissions: {
        canManageInventory: Boolean(perms.canManageInventory),
        canFiar: false,
        canOpenCloseCash: false,
        canManageRefunds: Boolean(perms.canManageRefunds),
      },
    },
    STORE_ID,
  );
}

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

describe('FASE 3 · OLA 5 — Inventario canManageInventory, Salidas $0, Reembolsos merma y P&L 4 Pilares', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    Object.defineProperty(navigator, 'onLine', { value: true, configurable: true });
    mockFrom.mockReturnValue({
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      gte: vi.fn().mockReturnThis(),
      lte: vi.fn().mockReturnThis(),
      order: vi.fn().mockReturnThis(),
      limit: vi.fn().mockReturnThis(),
      single: vi.fn().mockResolvedValue({ data: { cost_unit: 1000 }, error: null }),
      maybeSingle: vi.fn().mockResolvedValue({ data: null, error: null }),
      then: (cb: any) => cb({ data: [], error: null }),
    });
  });

  it('CHK-507: inventoryStore.registerStockMovement maneja ajustes negativos (-) y positivos (+) sin sumar negativos', async () => {
    const inventoryStore = useInventoryStore();
    inventoryStore.products = [
      {
        id: 'prod-1',
        storeId: 'store-1',
        name: 'Arroz Diana',
        price: new Decimal(3000),
        stock: new Decimal(10),
        minStock: 2,
        measurementUnit: 'un',
        isWeighable: false,
      } as any,
    ];

    vi.spyOn(productRepository, 'registerMovement').mockResolvedValue(true);
    vi.spyOn(productRepository, 'getById').mockResolvedValue({
      id: 'prod-1',
      storeId: 'store-1',
      name: 'Arroz Diana',
      price: new Decimal(3000),
      stock: new Decimal(7),
      minStock: 2,
      measurementUnit: 'un',
      isWeighable: false,
    } as any);

    const resNeg = await inventoryStore.registerStockMovement({
      productId: 'prod-1',
      type: 'ajuste',
      quantity: new Decimal(-3),
      reason: 'Faltante conteo',
    });
    expect(resNeg.success).toBe(true);
    expect(inventoryStore.products[0].stock.toNumber()).toBe(7);

    // Exceder stock negativo falla limpiamente
    const resTooLow = await inventoryStore.registerStockMovement({
      productId: 'prod-1',
      type: 'ajuste',
      quantity: new Decimal(-20),
      reason: 'Imposible',
    });
    expect(resTooLow.success).toBe(false);
  });

  it('CHK-503 & CHK-504 (Enmienda UX-ADR-004): DashboardView oculta Inventariado Físico sin canManageInventory y lo habilita cuando tiene permiso', async () => {
    const authStore = useAuthStore();
    setEmpSession(authStore, { canManageInventory: false }, 'Cajero Estándar', 'emp-basic');

    const wrapper = mount(DashboardView, {
      global: {
        stubs: {
          BottomNav: true,
          UserProfileSidebar: true,
          SyncIndicator: true,
        },
      },
    });
    await flushPromises();

    expect(wrapper.find('[data-testid="dashboard-inventory-count-btn"]').exists()).toBe(false);

    // Ahora empleado con canManageInventory sí ve acceso a Inventariado Físico (/inventory-count)
    setEmpSession(authStore, { canManageInventory: true }, 'Bodeguero', 'emp-inv');
    await flushPromises();

    const btn = wrapper.find('[data-testid="dashboard-inventory-count-btn"]');
    expect(btn.exists()).toBe(true);
    expect(btn.text()).toContain('Inventariado Físico');
  });

  it('CHK-505 & CHK-506: StockEntryView solo admite Compra/Reposición sin CxP y ProductFormModal habilita Costo para canManageInventory', async () => {
    const authStore = useAuthStore();
    setEmpSession(authStore, { canManageInventory: true }, 'Bodeguero', 'emp-inv');

    const entryWrapper = mount(StockEntryView);
    await flushPromises();
    const html = entryWrapper.html();
    expect(html).toContain('Compra');
    expect(html).toContain('Reposición de Proveedor');
    expect(html).not.toContain('Ajuste Positivo');
    expect(html).not.toContain('Devolución Cliente');
    expect(html).not.toContain('¿A qué factura corresponde esta devolución?');

    const formWrapper = mount(ProductFormModal, {
      props: { modelValue: true },
      global: {
        stubs: { teleport: true },
      },
    });
    await flushPromises();
    expect(formWrapper.text()).toContain('Costo ($)');
  });

  it('CHK-508 & CHK-509: POSView muestra botón Reembolsos al lado de Buscar según canManageRefunds y RefundModal ejecuta switch "merma"', async () => {
    const authStore = useAuthStore();
    setEmpSession(authStore, { canManageRefunds: false }, 'Cajero Sin Reembolso', 'emp-basic');

    const posDenied = mount(POSView, {
      global: {
        stubs: {
          CheckoutModal: true,
          RefundModal: true,
          ProductSearchModal: true,
          WeightCalculatorModal: true,
          ForceSaleModal: true,
          SyncIndicator: true,
        },
      },
    });
    expect(posDenied.find('[data-testid="pos-refunds-btn"]').exists()).toBe(false);

    setEmpSession(authStore, { canManageRefunds: true }, 'Cajero Reembolso', 'emp-ref');
    await flushPromises();
    expect(posDenied.find('[data-testid="pos-refunds-btn"]').exists()).toBe(true);

    mockRpc.mockImplementation(async (fnName: string, params: any) => {
      if (fnName === 'rpc_buscar_ventas_para_reembolso') {
        return {
          data: {
            success: true,
            data: [
              {
                sale_id: 'sale-1',
                ticket_number: 501,
                created_at: new Date().toISOString(),
                total: 3000,
                payment_method: 'efectivo',
                actor_name: 'Cajero Reembolso',
                items: [
                  {
                    sale_item_id: 'si-1',
                    product_id: 'prod-zero',
                    product_name: 'Leche Agotada',
                    plu: '9902',
                    current_stock: 0,
                    is_weighable: false,
                    measurement_unit: 'un',
                    quantity: 1,
                    refunded_quantity: 0,
                    remaining_quantity: 1,
                    unit_price: 3000,
                    subtotal: 3000,
                  },
                ],
              },
            ],
          },
          error: null,
        };
      }
      if (fnName === 'rpc_procesar_reembolso_item') {
        expect(params.p_is_merma).toBe(true);
        return {
          data: {
            success: true,
            data: {
              cash_movement_id: 'cm-1',
              inventory_movement_id: 'im-1',
              sale_id: 'sale-1',
              sale_item_id: 'si-1',
              ticket_number: 501,
              amount_refunded: 3000,
              quantity_refunded: 1,
              refund_channel: 'efectivo',
              original_channel: 'efectivo',
              is_merma: true,
              new_stock: 0,
              actor_name: 'Cajero Reembolso',
              actor_role: 'employee',
            },
          },
          error: null,
        };
      }
      return { data: null, error: null };
    });

    const cashRegisterStore = useCashRegisterStore();
    cashRegisterStore.currentSession = {
      id: 'session-open-1',
      storeId: STORE_ID,
      employeeId: 'emp-ref',
      status: 'open',
      openingTime: new Date().toISOString(),
      openingBalance: new Decimal(100000),
      transactions: [],
    } as any;

    const refundWrapper = mount(RefundModal, {
      props: { modelValue: true },
      global: { stubs: { teleport: true } },
    });
    await flushPromises();

    expect(refundWrapper.text()).toContain('Leche Agotada');
    const refundBtn = refundWrapper.findAll('button').find((b) => b.text().trim() === 'Reembolsar');
    expect(refundBtn).toBeDefined();
    await refundBtn!.trigger('click');

    // Activar etiqueta "merma" + ingresar motivo
    const mermaCheckbox = refundWrapper.find('input[type="checkbox"]');
    await mermaCheckbox.setValue(true);
    await refundWrapper.find('textarea').setValue('Bolsa rota entregada por cliente');

    const confirmBtn = refundWrapper.findAll('button').find((b) => b.text().includes('Confirmar Reembolso'));
    await confirmBtn!.trigger('click');
    await flushPromises();

    expect(mockShowSuccess).toHaveBeenCalled();
  });

  it('CHK-510: ProductKardexTab expone filtros de nuevos tipos, actor snapshot y botón contra-movimiento', async () => {
    const authStore = useAuthStore();
    setEmpSession(authStore, { canManageInventory: true }, 'Bodeguero', 'emp-inv');

    mockRpc.mockImplementation(async (fnName: string) => {
      if (fnName === 'get_inventory_kardex') {
        return {
          data: {
            success: true,
            count: 1,
            actors: [{ actor_key: 'emp-1', actor_name: 'Bodeguero', actor_role: 'employee' }],
            data: [
              {
                id: 'mov-1',
                movement_type: 'consumo_negocio',
                quantity: 2,
                reason: 'Limpieza local',
                unit_cost: 1200,
                actor_name: 'Bodeguero',
                actor_role: 'employee',
                reversed_movement_id: null,
                is_reversed: false,
                created_at: new Date().toISOString(),
              },
            ],
          },
          error: null,
        };
      }
      return { data: null, error: null };
    });

    const wrapper = mount(ProductKardexTab, {
      props: { productId: 'prod-1' },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('Consumo Negocio');
    expect(wrapper.text()).toContain('Retiro Personal');
    expect(wrapper.text()).toContain('Dev. Proveedor');
    expect(wrapper.text()).toContain('Ajuste Conteo');
    expect(wrapper.text()).toContain('Bodeguero · Empleado');
    expect(wrapper.text()).toContain('Contra-movimiento');
  });

  it('CHK-511 & CHK-512: FinancialDashboardView renderiza desglose OPEX al costo y módulo Admin de Consumos Personales', async () => {
    const authStore = useAuthStore();
    setAdminSession(authStore);

    const mockPnl = {
      period: { start: '2026-11-19', end: '2026-11-19' },
      gross_sales: 100000,
      refunds_total: 10000,
      revenue: 90000,
      cogs: 50000,
      gross_profit: 40000,
      gross_margin: 44.44,
      operational_expenses: 8500,
      net_profit: 31500,
      opex_breakdown: {
        cash_expenses: 5000,
        servicios: 5000,
        nomina: 0,
        transporte: 0,
        mantenimiento: 0,
        insumos: 0,
        otros: 0,
        merma_cost: 1500,
        consumo_negocio_cost: 1000,
        consumo_personal_cost: 1000,
        total: 8500,
      },
      personal_consumptions_summary: {
        total_cost: 1000,
        total_reference_sale_price: 2200,
        movements_count: 2,
        by_profile: [
          {
            profile_id: 'emp-1',
            profile_key: 'emp-1',
            profile_name: 'Carlos Cajero',
            profile_role: 'employee',
            total_cost: 1000,
            total_reference_sale_price: 2200,
            movements_count: 2,
            items_count: 2,
          },
        ],
      },
      inventory_value: 200000,
      payment_breakdown: {
        cash: 60000,
        transfer: 20000,
        credit: 10000,
        efectivo: 60000,
        nequi: 12000,
        llave_bre: 8000,
      },
      fiado_pendiente: 10000,
      traffic_light: { status: 'green', message: 'Todo estable' },
    };

    mockRpc.mockImplementation(async (fnName: string) => {
      if (fnName === 'rpc_get_comprehensive_financial_report') {
        return { data: mockPnl, error: null };
      }
      if (fnName === 'get_top_products_by_units' || fnName === 'get_stagnant_products') {
        return { data: [], error: null };
      }
      if (fnName === 'get_inventory_health') {
        return { data: null, error: null };
      }
      if (fnName === 'get_client_ledger_summary') {
        return { data: null, error: null };
      }
      return { data: null, error: null };
    });

    const finStore = useFinancialStore();
    finStore.summary = mockPnl as any;

    const wrapper = mount(FinancialDashboardTab, {
      global: {
        stubs: {
          InventoryHealthWidget: true,
          ClientLedgerWidget: true,
        },
      },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('Desglose OPEX del Período (Cero Doble Conteo)');
    expect(wrapper.text()).toContain('Consumos / Retiros Personales');
    expect(wrapper.text()).toContain('Carlos Cajero');
    expect(wrapper.text()).toContain('Ref: $ 2.200');
  });

  it('CHK-506 (B5-3): addProduct con cost y stock > 0 invoca rpc_registrar_entrada con purchasePrice = cost (no 0)', async () => {
    const authStore = useAuthStore();
    setAdminSession(authStore);
    const inventoryStore = useInventoryStore();

    vi.spyOn(productRepository, 'create').mockResolvedValue({
      id: 'prod-new-1',
      name: 'Aceite Girasol',
      price: new Decimal(2500),
      cost: new Decimal(1500),
      stock: new Decimal(0),
      minStock: 2,
      measurementUnit: 'un',
      isWeighable: false,
      storeId: STORE_ID,
    } as any);

    const entrySpy = vi.spyOn(productRepository, 'registerEntry').mockResolvedValue(true);

    await inventoryStore.addProduct({
      name: 'Aceite Girasol',
      price: new Decimal(2500),
      cost: new Decimal(1500),
      stock: new Decimal(10),
      minStock: 2,
      measurementUnit: 'un',
      isWeighable: false,
      storeId: STORE_ID,
    });

    expect(entrySpy).toHaveBeenCalledTimes(1);
    expect(entrySpy).toHaveBeenCalledWith(
      'prod-new-1',
      10,
      1500,
      2500,
      'Stock inicial al crear producto',
    );
  });
});

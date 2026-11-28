import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { reactive } from 'vue';
import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import Decimal from 'decimal.js';
import CashControlView from '../../views/CashControlView.vue';
import { cashRepository } from '../../data/repositories/cashRepository';

/**
 * Regresión: flujo de apertura con cierre forzado pendiente (SDD_017 RN-017-03)
 * + Consolidación C2 Workspace (/cash-control?tab=shift|expenses|movements) (UX-ADR-002).
 */

// ---- Router -------------------------------------------------------------
const mockRouterPush = vi.fn();
const mockRouterBack = vi.fn();
const mockRoute = reactive<{ path: string; query: Record<string, any> }>({
  path: '/cash-control',
  query: {},
});
const mockRouterReplace = vi.fn((location: any) => {
  if (location?.query) {
    mockRoute.query = { ...location.query };
  }
});

vi.mock('vue-router', () => ({
  useRoute: () => mockRoute,
  useRouter: () => ({ push: mockRouterPush, replace: mockRouterReplace, back: mockRouterBack }),
}));

// ---- Notificaciones -----------------------------------------------------
const mockShowError = vi.fn();
const mockShowSuccess = vi.fn();
const mockShowWarning = vi.fn();
vi.mock('../../composables/useNotifications', () => ({
  useNotifications: () => ({
    showError: mockShowError,
    showSuccess: mockShowSuccess,
    showWarning: mockShowWarning,
    showInfo: vi.fn(),
  }),
}));

// ---- Stores -------------------------------------------------------------
const mockOpenRegister = vi.fn();
const mockCloseRegister = vi.fn();
const mockSyncFromBackend = vi.fn();
const mockRegisterExpense = vi.fn();

const cashStoreState = reactive<{
  isOpen: boolean;
  isStaleSession: boolean;
  staleSessionDate: string;
  currentSession: any;
  pendingForcedSessionInfo: any;
  lastSyncError: string | null;
  adminExpectedSummary: { efectivo: number; nequi: number; llave_bre: number } | null;
}>({
  isOpen: false,
  isStaleSession: false,
  staleSessionDate: '',
  currentSession: null,
  pendingForcedSessionInfo: null,
  lastSyncError: null,
  adminExpectedSummary: null,
});

vi.mock('../../stores/cashRegister', () => ({
  useCashRegisterStore: () => ({
    get isOpen() { return cashStoreState.isOpen; },
    get isStaleSession() { return cashStoreState.isStaleSession; },
    get staleSessionDate() { return cashStoreState.staleSessionDate; },
    get currentSession() { return cashStoreState.currentSession; },
    get pendingForcedSessionInfo() { return cashStoreState.pendingForcedSessionInfo; },
    get lastSyncError() { return cashStoreState.lastSyncError; },
    get adminExpectedSummary() { return cashStoreState.adminExpectedSummary; },
    syncFromBackend: mockSyncFromBackend,
    openRegister: mockOpenRegister,
    closeRegister: mockCloseRegister,
    registerExpense: mockRegisterExpense,
    fetchPendingForcedSessions: (storeId?: string) => cashRepository.getPendingForcedSessions(storeId),
    reconcileForcedClose: (sessionId: string, employeeId: string, actualBalance: number, notes?: string) =>
      cashRepository.reconcileForcedSession(sessionId, employeeId, actualBalance, notes),
  }),
}));

const authState = reactive({
  isAdmin: true,
  canOpenCloseCash: true,
  currentStore: { id: 'store-1' },
  currentUser: { id: 'user-1', employeeId: 'emp-1', permissions: {} as Record<string, boolean> },
});

vi.mock('../../stores/auth', () => ({
  useAuthStore: () => authState,
}));

// ---- Supabase falso (vi.hoisted: vi.mock se eleva por encima de los imports) --
const { fromCalls, mockRpc, state, fakeSupabase } = vi.hoisted(() => {
  const fromCalls: { table: string; select: string }[] = [];
  const mockRpc = vi.fn();
  const state: { sessionsResult: { data: any; error: any } } = {
    sessionsResult: { data: [], error: null },
  };
  const fakeSupabase = {
    from: (table: string) => {
      const call = { table, select: '' };
      fromCalls.push(call);
      const chain: any = {
        select: (cols: string) => { call.select = cols; return chain; },
        eq: () => chain,
        is: () => chain,
        order: () => Promise.resolve(state.sessionsResult),
      };
      return chain;
    },
    rpc: (...args: any[]) => mockRpc(...args),
  };
  return { fromCalls, mockRpc, state, fakeSupabase };
});

vi.mock('../../data/supabaseClient', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../../data/supabaseClient')>()),
  requireSupabase: () => fakeSupabase,
}));

// ---- Componentes hijos (stubs) -------------------------------------------
const ForcedCloseAuditModalStub = {
  name: 'ForcedCloseAuditModal',
  props: ['isVisible', 'pendingSessions'],
  emits: ['confirm'],
  template: '<div data-test="audit-modal" />',
};
const BaseButtonStub = {
  props: ['disabled', 'loading', 'variant', 'size'],
  emits: ['click'],
  template: '<button :data-test="$attrs[\'data-test\'] || \'submit\'" :disabled="disabled" @click="$emit(\'click\')"><slot /></button>',
};

const mountView = () =>
  mount(CashControlView, {
    global: {
      plugins: [createPinia()],
      stubs: {
        Teleport: true,
        ForcedCloseAuditModal: ForcedCloseAuditModalStub,
        BaseButton: BaseButtonStub,
        PinChallengeModal: true,
        FormInputCurrency: {
          props: ['modelValue', 'disabled', 'placeholder', 'autofocus', 'allowNull'],
          emits: ['update:modelValue'],
          template: '<input :value="modelValue ?? \'\'" :disabled="disabled" @input="$emit(\'update:modelValue\', $event.target.value === \'\' ? (allowNull ? null : 0) : Number($event.target.value))" />',
        },
      },
    },
  });

const PENDING = [
  {
    id: 'sess-1',
    opened_at: '2026-10-17T20:56:14Z',
    opened_by: 'emp-other',
    opened_by_name: 'Cajero Prueba',
    opening_balance: 50000,
    expected_efectivo: 103000,
    nequi_summary: 25000,
    llave_bre_summary: 10000,
    is_opened_by_other: true,
  },
];

enableAutoUnmount(afterEach);

describe('CashControlView — cierre forzado pendiente y Workspace C2 (UX-ADR-002)', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    fromCalls.length = 0;
    state.sessionsResult = { data: { success: true, data: [] }, error: null };
    Object.defineProperty(navigator, 'onLine', { value: true, configurable: true });

    authState.isAdmin = true;
    authState.canOpenCloseCash = true;
    authState.currentStore = { id: 'store-1' };
    authState.currentUser = { id: 'user-1', employeeId: 'emp-1', permissions: {} };

    cashStoreState.isOpen = false;
    cashStoreState.isStaleSession = false;
    cashStoreState.staleSessionDate = '';
    cashStoreState.currentSession = null;
    cashStoreState.pendingForcedSessionInfo = null;
    cashStoreState.lastSyncError = null;
    cashStoreState.adminExpectedSummary = null;

    mockRoute.query = {};
    mockSyncFromBackend.mockResolvedValue(false);
    mockOpenRegister.mockResolvedValue(undefined);
    mockCloseRegister.mockResolvedValue({ success: true, sealedWithAlert: false });
    mockRegisterExpense.mockResolvedValue(undefined);
    mockRpc.mockImplementation((fnName: string) => {
      if (fnName === 'rpc_obtener_turnos_forzados_pendientes') {
        return Promise.resolve(state.sessionsResult);
      }
      return Promise.resolve({ data: { success: true, data: [] }, error: null });
    });
  });

  it('consulta rpc_obtener_turnos_forzados_pendientes (solo Admin) y nunca toca cash_session_balances', async () => {
    state.sessionsResult = { data: { success: true, data: PENDING }, error: null };
    mountView();
    await flushPromises();

    expect(mockRpc).toHaveBeenCalledWith('rpc_obtener_turnos_forzados_pendientes', {
      p_store_id: 'store-1',
    });
    expect(fromCalls.map(c => c.table)).not.toContain('cash_session_balances');
  });

  it('entrega al modal la sesión pendiente con resumen autoritativo de efectivo y digitales para Admin', async () => {
    state.sessionsResult = { data: { success: true, data: PENDING }, error: null };
    const wrapper = mountView();
    await flushPromises();

    const modal = wrapper.findComponent({ name: 'ForcedCloseAuditModal' });
    expect(modal.props('isVisible')).toBe(true);
    expect(modal.props('pendingSessions')).toEqual([
      {
        id: 'sess-1',
        openedAt: '2026-10-17T20:56:14Z',
        openedByName: 'Cajero Prueba',
        openedByRole: 'employee',
        openingBalance: 50000,
        expectedEfectivo: 103000,
        nequiSummary: 25000,
        llaveBreSummary: 10000,
        isOpenedByOther: true,
        channels: ['efectivo'],
      },
    ]);
  });

  it('RAMA ERROR: si falla la verificación de turnos pendientes, bloquea la apertura (falla cerrado)', async () => {
    state.sessionsResult = { data: null, error: { code: 'PGRST205', message: 'Could not find the table' } };
    const wrapper = mountView();
    await flushPromises();

    expect(wrapper.text()).toContain('Error al verificar turnos forzados pendientes');

    await wrapper.find('[data-test="cash-amount-input"]').setValue('50000');
    await wrapper.find('[data-test="submit"]').trigger('click');
    await flushPromises();

    expect(mockOpenRegister).not.toHaveBeenCalled();
    expect(mockShowError).toHaveBeenCalledWith(expect.stringContaining('Reintentar'));
  });

  it('RAMA BLOQUEO: con turno forzado pendiente no abre la caja', async () => {
    state.sessionsResult = { data: { success: true, data: PENDING }, error: null };
    const wrapper = mountView();
    await flushPromises();

    await wrapper.find('[data-test="cash-amount-input"]').setValue('50000');
    await wrapper.find('[data-test="submit"]').trigger('click');
    await flushPromises();

    expect(mockOpenRegister).not.toHaveBeenCalled();
    expect(mockShowError).toHaveBeenCalledWith(expect.stringContaining('reconciliar'));
  });

  it('RAMA FELIZ: sin turnos pendientes abre la caja tras digitar base explícita', async () => {
    const wrapper = mountView();
    await flushPromises();

    // Sin digitar nada, el botón debe permanecer bloqueado (prohibido envío en blanco)
    expect(wrapper.find('[data-test="submit"]').attributes('disabled')).toBeDefined();

    await wrapper.find('[data-test="cash-amount-input"]').setValue('0');
    await flushPromises();
    expect(wrapper.find('[data-test="submit"]').attributes('disabled')).toBeUndefined();

    await wrapper.find('[data-test="submit"]').trigger('click');
    await flushPromises();

    expect(mockOpenRegister).toHaveBeenCalledTimes(1);
  });

  it('reconciliación exitosa: llama al RPC con conteo y observación y retira la sesión de la cola', async () => {
    state.sessionsResult = { data: { success: true, data: PENDING }, error: null };
    const wrapper = mountView();
    await flushPromises();

    wrapper.findComponent({ name: 'ForcedCloseAuditModal' }).vm.$emit('confirm', 'sess-1', 103000, 'Conté el cajón completo');
    await flushPromises();

    expect(mockRpc).toHaveBeenCalledWith('rpc_reconciliar_cierre_forzado', {
      p_session_id: 'sess-1',
      p_employee_id: 'emp-1',
      p_actual_balance: 103000,
      p_notes: 'Conté el cajón completo',
    });
    expect(wrapper.findComponent({ name: 'ForcedCloseAuditModal' }).props('pendingSessions')).toEqual([]);
    expect(mockShowSuccess).toHaveBeenCalled();
  });

  it('RAMA ERROR RPC: traduce el código técnico a mensaje amigable y mantiene la sesión pendiente', async () => {
    state.sessionsResult = { data: { success: true, data: PENDING }, error: null };
    mockRpc.mockImplementation((fnName: string) => {
      if (fnName === 'rpc_obtener_turnos_forzados_pendientes') {
        return Promise.resolve(state.sessionsResult);
      }
      return Promise.resolve({
        data: null,
        error: { message: 'INSUFFICIENT_PERMISSIONS: Sin permiso para reconciliar cierres de caja.' },
      });
    });
    const wrapper = mountView();
    await flushPromises();

    wrapper.findComponent({ name: 'ForcedCloseAuditModal' }).vm.$emit('confirm', 'sess-1', 100, 'Nota válida');
    await flushPromises();

    expect(mockShowError).toHaveBeenCalledWith(expect.stringContaining('No tienes permiso'));
    expect(wrapper.findComponent({ name: 'ForcedCloseAuditModal' }).props('pendingSessions')).toHaveLength(1);
  });

  // =========================================================================
  // Nuevos tests WO-OLA2-C2-001 (UX-ADR-002): C2-H2, segregación por rol y OPEX
  // =========================================================================
  it('[C2-H2] falla syncFromBackend -> muestra banner N3 persistente, bloquea apertura (fail-closed) y permite Reintentar', async () => {
    mockSyncFromBackend.mockRejectedValueOnce(new Error('NETWORK_UNAVAILABLE'));

    const wrapper = mountView();
    await flushPromises();

    expect(mockSyncFromBackend).toHaveBeenCalledWith('store-1', { throwOnError: true });
    expect(wrapper.find('[data-test="sync-error-banner"]').exists()).toBe(true);
    expect(wrapper.text()).toContain('NETWORK_UNAVAILABLE');
    expect(wrapper.find('[data-test="submit"]').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Apertura de Caja');

    // Al pulsar Reintentar y responder bien -> desbloquea el formulario
    mockSyncFromBackend.mockResolvedValueOnce(false);
    await wrapper.find('[data-test="btn-retry-sync"]').trigger('click');
    await flushPromises();

    expect(wrapper.find('[data-test="sync-error-banner"]').exists()).toBe(false);
    expect(wrapper.text()).toContain('Apertura de Caja');
  });

  it('[C2-Segregación] empleado sin canOpenCloseCash accede solo a Mis Movimientos sin barra de tabs ni apertura', async () => {
    authState.isAdmin = false;
    authState.canOpenCloseCash = false;
    mockRoute.query = { tab: 'shift' };
    mockRpc.mockResolvedValueOnce({
      data: {
        data: [],
        count: 0,
        has_open_shift: true,
        shift_id: 'sess-1',
        shift_opened_at: '2026-11-24T08:00:00Z',
      },
      error: null,
    });

    const wrapper = mountView();
    await flushPromises();

    expect(mockRouterReplace).toHaveBeenCalledWith({ query: { tab: 'movements' } });
    expect(wrapper.find('[data-test="cash-workspace-tabs"]').exists()).toBe(false);
    expect(wrapper.text()).toContain('Mis Movimientos del Turno');
    expect(wrapper.text()).not.toContain('Apertura de Caja');
    expect(mockSyncFromBackend).not.toHaveBeenCalled();
  });

  it('[C2-Segregación] empleado con canOpenCloseCash no ve tab Gastos y ?tab=expenses redirige a shift', async () => {
    authState.isAdmin = false;
    authState.canOpenCloseCash = true;
    mockRoute.query = { tab: 'expenses' };

    const wrapper = mountView();
    await flushPromises();

    expect(mockRouterReplace).toHaveBeenCalledWith({ query: { tab: 'shift' } });
    expect(wrapper.find('[data-test="tab-shift"]').exists()).toBe(true);
    expect(wrapper.find('[data-test="tab-movements"]').exists()).toBe(true);
    expect(wrapper.find('[data-test="tab-expenses"]').exists()).toBe(false);
  });

  it('[C2-H1/C2-H3] Admin en tab Gastos muestra total_opex_expenses del servidor, valida N1 inline y traduce ADMIN_ONLY_ACTION', async () => {
    authState.isAdmin = true;
    cashStoreState.isOpen = true;
    cashStoreState.currentSession = {
      id: 'sess-admin-1',
      storeId: 'store-1',
      employeeId: 'user-1',
      status: 'open',
      openingTime: new Date().toISOString(),
      openingBalance: new Decimal(100000),
      transactions: [],
    };
    mockSyncFromBackend.mockResolvedValue(true);
    mockRoute.query = { tab: 'expenses' };

    // Total servidor (18000) distinto de la suma de items retornados (5000) para probar CERO .reduce() en cliente
    mockRpc.mockImplementation((fnName: string) => {
      if (fnName === 'rpc_obtener_turnos_forzados_pendientes') {
        return Promise.resolve({ data: { success: true, data: [] }, error: null });
      }
      return Promise.resolve({
        data: {
          success: true,
          session_id: 'sess-admin-1',
          session_status: 'open',
          total_opex_expenses: 18000,
          count: 1,
          data: [
            {
              id: 'exp-1',
              amount: 5000,
              description: 'Bolsas biodegradables',
              category: 'Insumos',
              payment_method: 'efectivo',
              voucher_ref: null,
              actor_name: 'Don Carlos',
              actor_role: 'owner',
              created_at: '2026-11-24T12:00:00Z',
            },
          ],
        },
        error: null,
      });
    });

    const wrapper = mountView();
    await flushPromises();
    await flushPromises();

    expect(mockRpc).toHaveBeenCalledWith('rpc_obtener_gastos_turno', { p_session_id: 'sess-admin-1' });
    expect(wrapper.text()).toContain('Gastos del Turno');
    expect(wrapper.find('[data-test="total-opex-expenses"]').text()).toContain('18.000');

    // Abrir modal -> enviar vacío -> errores N1 inline persistentes sin toast
    await wrapper.find('[data-test="btn-register-expense"]').trigger('click');
    await flushPromises();

    await wrapper.find('[data-test="btn-confirm-expense"]').trigger('click');
    await flushPromises();

    expect(wrapper.find('[data-test="error-expense-amount"]').text()).toContain('monto positivo');
    expect(wrapper.find('#expense-description-error').text()).toContain('al menos 3 caracteres');
    expect(mockRegisterExpense).not.toHaveBeenCalled();

    // Llenar campos válidos y simular rechazo ADMIN_ONLY_ACTION desde servidor (sin doble alerta)
    const inputs = wrapper.findAll('[data-test="expense-create-modal"] input');
    await inputs[0].setValue('10000');
    await inputs[1].setValue('Pago internet');
    const errAdmin: any = new Error('ADMIN_ONLY_ACTION: Solo el Administrador puede registrar gastos OPEX.');
    errAdmin.code = 'ADMIN_ONLY_ACTION';
    mockRegisterExpense.mockRejectedValueOnce(errAdmin);

    await wrapper.find('[data-test="btn-confirm-expense"]').trigger('click');
    await flushPromises();

    expect(wrapper.find('[data-test="expense-submit-error"]').text()).toContain('Solo el Administrador');
    expect(mockShowError).not.toHaveBeenCalled();
  });

  it('[C2-H2] en ?tab=expenses si syncFromBackend falla muestra sync-error-banner y NO "Caja Cerrada"', async () => {
    authState.isAdmin = true;
    mockRoute.query = { tab: 'expenses' };
    mockSyncFromBackend.mockRejectedValueOnce(new Error('SYNC_FAILED_EXPENSES'));

    const wrapper = mountView();
    await flushPromises();

    expect(mockSyncFromBackend).toHaveBeenCalledWith('store-1', { throwOnError: true });
    expect(wrapper.find('[data-test="sync-error-banner"]').exists()).toBe(true);
    expect(wrapper.text()).toContain('SYNC_FAILED_EXPENSES');
    expect(wrapper.find('[data-test="expenses-closed-banner"]').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Caja Cerrada');
  });

  it('[C2-H2] mutación en caja bloqueada en modo offline (checkConnectivity: true)', async () => {
    Object.defineProperty(navigator, 'onLine', { value: false, configurable: true });
    const wrapper = mountView();
    await flushPromises();

    await wrapper.find('[data-test="cash-amount-input"]').setValue('50000');
    await wrapper.find('[data-test="submit"]').trigger('click');
    await flushPromises();

    expect(mockOpenRegister).not.toHaveBeenCalled();
    expect(mockShowWarning).toHaveBeenCalledWith(expect.stringContaining('Sin conexión'), 'wifi_off');
  });

  it('[POL-SEG-01 v1.5] Cierre Admin: muestra efectivo esperado + resumen digital, sin campos de Nequi/Bre-B y bloquea envío en blanco', async () => {
    authState.isAdmin = true;
    cashStoreState.isOpen = true;
    cashStoreState.currentSession = { id: 'sess-admin-open', employeeId: 'emp-1', openedByName: 'Dueño' };
    cashStoreState.adminExpectedSummary = { efectivo: 120000, nequi: 45000, llave_bre: 15000 };
    mockSyncFromBackend.mockResolvedValueOnce(true);
    mockCloseRegister.mockResolvedValueOnce({
      success: true,
      sealedWithAlert: false,
      expectedEfectivo: 120000,
      actualEfectivo: 119500,
      difference: -500,
    });

    const wrapper = mountView();
    await flushPromises();

    // Admin ve su resumen esperado (servidor) y NO ve banner de Arqueo Ciego ni casillas Nequi/Bre-B Contado
    expect(wrapper.find('[data-test="admin-expected-summary"]').exists()).toBe(true);
    expect(wrapper.find('[data-test="admin-expected-summary"]').text()).toContain('120.000');
    expect(wrapper.find('[data-test="admin-expected-summary"]').text()).toContain('45.000');
    expect(wrapper.find('[data-test="employee-blind-protocol-banner"]').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Nequi Contado');
    expect(wrapper.text()).not.toContain('Llave Bre-B Contado');

    // Bloqueado mientras el campo esté vacío
    expect(wrapper.find('[data-test="submit"]').attributes('disabled')).toBeDefined();

    // Digita efectivo contado y cierra enviando solo efectivo
    await wrapper.find('[data-test="cash-amount-input"]').setValue('119500');
    await flushPromises();
    await wrapper.find('[data-test="submit"]').trigger('click');
    await flushPromises();

    expect(mockCloseRegister).toHaveBeenCalledWith({ efectivo: 119500 }, '', 'store-1');
  });

  it('[POL-SEG-01 v1.5] Cierre Empleado: oculta saldo esperado, solo pide efectivo físico y bloquea envío en blanco', async () => {
    authState.isAdmin = false;
    authState.canOpenCloseCash = true;
    cashStoreState.isOpen = true;
    cashStoreState.currentSession = { id: 'sess-emp-open', employeeId: 'emp-1', openedByName: 'Cajero' };
    cashStoreState.adminExpectedSummary = { efectivo: 120000, nequi: 45000, llave_bre: 15000 };
    mockSyncFromBackend.mockResolvedValueOnce(true);

    const wrapper = mountView();
    await flushPromises();

    // Empleado solo ve el campo de Efectivo en Cajón y NUNCA ve admin-expected-summary ni Nequi Contado
    expect(wrapper.text()).toContain('Efectivo en Cajón');
    expect(wrapper.find('[data-test="admin-expected-summary"]').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('120.000');
    expect(wrapper.text()).not.toContain('Nequi Contado');
    expect(wrapper.text()).not.toContain('Llave Bre-B Contado');

    // Bloqueado mientras esté vacío
    expect(wrapper.find('[data-test="submit"]').attributes('disabled')).toBeDefined();
  });
});

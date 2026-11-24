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
const mockSyncFromBackend = vi.fn();
const mockRegisterExpense = vi.fn();

const cashStoreState = reactive<{
  isOpen: boolean;
  isStaleSession: boolean;
  staleSessionDate: string;
  currentSession: any;
  pendingForcedSessionInfo: any;
  lastSyncError: string | null;
}>({
  isOpen: false,
  isStaleSession: false,
  staleSessionDate: '',
  currentSession: null,
  pendingForcedSessionInfo: null,
  lastSyncError: null,
});

vi.mock('../../stores/cashRegister', () => ({
  useCashRegisterStore: () => ({
    get isOpen() { return cashStoreState.isOpen; },
    get isStaleSession() { return cashStoreState.isStaleSession; },
    get staleSessionDate() { return cashStoreState.staleSessionDate; },
    get currentSession() { return cashStoreState.currentSession; },
    get pendingForcedSessionInfo() { return cashStoreState.pendingForcedSessionInfo; },
    get lastSyncError() { return cashStoreState.lastSyncError; },
    syncFromBackend: mockSyncFromBackend,
    openRegister: mockOpenRegister,
    closeRegister: vi.fn(),
    registerExpense: mockRegisterExpense,
    fetchPendingForcedSessions: () => cashRepository.getPendingForcedSessions(),
    reconcileForcedClose: (sessionId: string, employeeId: string, actualBalance: number) =>
      cashRepository.reconcileForcedSession(sessionId, employeeId, actualBalance),
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
          props: ['modelValue', 'disabled', 'placeholder', 'autofocus'],
          emits: ['update:modelValue'],
          template: '<input :value="modelValue" :disabled="disabled" @input="$emit(\'update:modelValue\', Number($event.target.value))" />',
        },
      },
    },
  });

const PENDING = [{ id: 'sess-1', opened_at: '2026-10-17T20:56:14Z' }];

enableAutoUnmount(afterEach);

describe('CashControlView — cierre forzado pendiente y Workspace C2 (UX-ADR-002)', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    fromCalls.length = 0;
    state.sessionsResult = { data: [], error: null };
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

    mockRoute.query = {};
    mockSyncFromBackend.mockResolvedValue(false);
    mockOpenRegister.mockResolvedValue(undefined);
    mockRegisterExpense.mockResolvedValue(undefined);
    mockRpc.mockResolvedValue({ data: { success: true, data: [] }, error: null });
  });

  it('consulta solo cash_sessions (nunca cash_session_balances) y no pide expected_balance (Arqueo Ciego)', async () => {
    state.sessionsResult = { data: PENDING, error: null };
    mountView();
    await flushPromises();

    expect(fromCalls.map(c => c.table)).toEqual(['cash_sessions']);
    expect(fromCalls[0].select).not.toContain('expected_balance');
  });

  it('entrega al modal la sesiÃ³n pendiente con canal efectivo y sin saldos esperados', async () => {
    state.sessionsResult = { data: PENDING, error: null };
    const wrapper = mountView();
    await flushPromises();

    const modal = wrapper.findComponent({ name: 'ForcedCloseAuditModal' });
    expect(modal.props('isVisible')).toBe(true);
    expect(modal.props('pendingSessions')).toEqual([
      { id: 'sess-1', openedAt: '2026-10-17T20:56:14Z', channels: ['efectivo'] },
    ]);
  });

  it('RAMA ERROR: si falla la verificaciÃ³n de turnos pendientes, bloquea la apertura (falla cerrado)', async () => {
    state.sessionsResult = { data: null, error: { code: 'PGRST205', message: 'Could not find the table' } };
    const wrapper = mountView();
    await flushPromises();

    expect(wrapper.text()).toContain('Error al verificar turnos forzados pendientes');

    await wrapper.find('[data-test="submit"]').trigger('click');
    await flushPromises();

    expect(mockOpenRegister).not.toHaveBeenCalled();
    expect(mockShowError).toHaveBeenCalledWith(expect.stringContaining('Reintentar'));
  });

  it('RAMA BLOQUEO: con turno forzado pendiente no abre la caja', async () => {
    state.sessionsResult = { data: PENDING, error: null };
    const wrapper = mountView();
    await flushPromises();

    await wrapper.find('[data-test="submit"]').trigger('click');
    await flushPromises();

    expect(mockOpenRegister).not.toHaveBeenCalled();
    expect(mockShowError).toHaveBeenCalledWith(expect.stringContaining('reconciliar'));
  });

  it('RAMA FELIZ: sin turnos pendientes abre la caja', async () => {
    const wrapper = mountView();
    await flushPromises();

    await wrapper.find('[data-test="submit"]').trigger('click');
    await flushPromises();

    expect(mockOpenRegister).toHaveBeenCalledTimes(1);
  });

  it('reconciliaciÃ³n exitosa: llama al RPC con el conteo y retira la sesiÃ³n de la cola', async () => {
    state.sessionsResult = { data: PENDING, error: null };
    const wrapper = mountView();
    await flushPromises();

    wrapper.findComponent({ name: 'ForcedCloseAuditModal' }).vm.$emit('confirm', 'sess-1', 103000);
    await flushPromises();

    expect(mockRpc).toHaveBeenCalledWith('rpc_reconciliar_cierre_forzado', {
      p_session_id: 'sess-1',
      p_employee_id: 'emp-1',
      p_actual_balance: 103000,
    });
    expect(wrapper.findComponent({ name: 'ForcedCloseAuditModal' }).props('pendingSessions')).toEqual([]);
    expect(mockShowSuccess).toHaveBeenCalled();
  });

  it('RAMA ERROR RPC: traduce el código técnico a mensaje amigable y mantiene la sesión pendiente', async () => {
    state.sessionsResult = { data: PENDING, error: null };
    mockRpc.mockResolvedValue({
      data: null,
      error: { message: 'INSUFFICIENT_PERMISSIONS: Sin permiso para reconciliar cierres de caja.' },
    });
    const wrapper = mountView();
    await flushPromises();

    wrapper.findComponent({ name: 'ForcedCloseAuditModal' }).vm.$emit('confirm', 'sess-1', 100);
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
    mockRpc.mockResolvedValueOnce({
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

    const wrapper = mountView();
    await flushPromises();

    expect(mockRpc).toHaveBeenCalledWith('rpc_obtener_gastos_turno', { p_session_id: 'sess-admin-1' });
    expect(wrapper.text()).toContain('Total Gastos OPEX del Turno');
    expect(wrapper.find('[data-test="total-opex-expenses"]').text()).toContain('18.000');

    // Abrir modal -> enviar vacío -> errores N1 inline persistentes sin toast
    await wrapper.find('[data-test="btn-register-expense"]').trigger('click');
    await flushPromises();

    await wrapper.find('[data-test="btn-confirm-expense"]').trigger('click');
    await flushPromises();

    expect(wrapper.find('[data-test="error-expense-amount"]').text()).toContain('monto positivo');
    expect(wrapper.find('#expense-description-error').text()).toContain('al menos 3 caracteres');
    expect(mockRegisterExpense).not.toHaveBeenCalled();

    // Llenar campos válidos y simular rechazo ADMIN_ONLY_ACTION desde servidor
    const inputs = wrapper.findAll('[data-test="expense-create-modal"] input');
    await inputs[0].setValue('10000');
    await inputs[1].setValue('Pago internet');
    const errAdmin: any = new Error('ADMIN_ONLY_ACTION: Solo el Administrador puede registrar gastos OPEX.');
    errAdmin.code = 'ADMIN_ONLY_ACTION';
    mockRegisterExpense.mockRejectedValueOnce(errAdmin);

    await wrapper.find('[data-test="btn-confirm-expense"]').trigger('click');
    await flushPromises();

    expect(wrapper.find('[data-test="expense-submit-error"]').text()).toContain('Solo el Administrador');
  });

  it('[C2-H2] mutación en caja bloqueada en modo offline (checkConnectivity: true)', async () => {
    Object.defineProperty(navigator, 'onLine', { value: false, configurable: true });
    const wrapper = mountView();
    await flushPromises();

    await wrapper.find('[data-test="submit"]').trigger('click');
    await flushPromises();

    expect(mockOpenRegister).not.toHaveBeenCalled();
    expect(mockShowWarning).toHaveBeenCalledWith(expect.stringContaining('Sin conexión'), 'wifi_off');
  });
});

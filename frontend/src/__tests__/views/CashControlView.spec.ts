import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import CashControlView from '../../views/CashControlView.vue';

/**
 * RegresiÃ³n: flujo de apertura con cierre forzado pendiente (SDD_017 RN-017-03).
 * Incidente 2026-10-21: la vista consultaba `cash_session_balances` (inexistente en
 * producciÃ³n -> PGRST205), la reconciliaciÃ³n quedaba inalcanzable y el flujo se cortaba.
 */

// ---- Router -------------------------------------------------------------
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn(), back: vi.fn() }),
}));

// ---- Notificaciones -----------------------------------------------------
const mockShowError = vi.fn();
const mockShowSuccess = vi.fn();
vi.mock('../../composables/useNotifications', () => ({
  useNotifications: () => ({
    showError: mockShowError,
    showSuccess: mockShowSuccess,
    showWarning: vi.fn(),
    showInfo: vi.fn(),
  }),
}));

// ---- Stores -------------------------------------------------------------
const mockOpenRegister = vi.fn();
const mockSyncFromBackend = vi.fn();
vi.mock('../../stores/cashRegister', () => ({
  useCashRegisterStore: () => ({
    isOpen: false,
    isStaleSession: false,
    staleSessionDate: '',
    currentSession: null,
    syncFromBackend: mockSyncFromBackend,
    openRegister: mockOpenRegister,
    closeRegister: vi.fn(),
  }),
}));

vi.mock('../../stores/auth', () => ({
  useAuthStore: () => ({
    isAdmin: true, // bypass PIN: el flujo llega directo a handlePinSuccess
    currentStore: { id: 'store-1' },
    currentUser: { id: 'user-1', employeeId: 'emp-1', permissions: {} },
  }),
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
  props: ['disabled', 'loading', 'variant'],
  emits: ['click'],
  template: '<button data-test="submit" :disabled="disabled" @click="$emit(\'click\')"><slot /></button>',
};

const mountView = () =>
  mount(CashControlView, {
    global: {
      plugins: [createPinia()],
      stubs: {
        ForcedCloseAuditModal: ForcedCloseAuditModalStub,
        BaseButton: BaseButtonStub,
        PinChallengeModal: true,
        FormInputCurrency: true,
      },
    },
  });

const PENDING = [{ id: 'sess-1', opened_at: '2026-10-17T20:56:14Z' }];

describe('CashControlView â€” cierre forzado pendiente (SDD_017 RN-017-03)', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    fromCalls.length = 0;
    state.sessionsResult = { data: [], error: null };
    mockSyncFromBackend.mockResolvedValue(false);
    mockOpenRegister.mockResolvedValue(undefined);
    mockRpc.mockResolvedValue({ data: { success: true, data: {} }, error: null });
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

  it('RAMA ERROR RPC: traduce el cÃ³digo tÃ©cnico a mensaje amigable y mantiene la sesiÃ³n pendiente', async () => {
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
});

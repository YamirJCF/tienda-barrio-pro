import { describe, it, expect, beforeEach, vi } from 'vitest';
import { useHistory } from '../composables/useHistory';

const { mockRpc } = vi.hoisted(() => ({
  mockRpc: vi.fn(),
}));

vi.mock('../stores/auth', () => ({
  useAuthStore: () => ({
    isAdmin: true,
    currentStore: { id: 'b63adadd-8679-4abc-af6c-d72ac3aa49e1' },
  }),
}));

vi.mock('../data/supabaseClient', () => ({
  getSupabaseClient: () => ({
    rpc: (...args: any[]) => mockRpc(...args),
  }),
  requireSupabase: () => ({
    rpc: (...args: any[]) => mockRpc(...args),
  }),
}));

describe('useHistory — Historial de Caja (get_history_caja)', () => {
  beforeEach(() => {
    mockRpc.mockReset();
  });

  it('NO lanza [DecimalError] Invalid argument: null cuando un turno tiene cierre forzado pendiente de reconciliación (actual_balance: null, difference: null)', async () => {
    mockRpc.mockResolvedValueOnce({
      data: [
        {
          id: '515cc17e-93ea-431c-9428-632648deff15',
          status: 'closed',
          event_type: 'CIERRE',
          reconciliation_status: 'forced_pending_reconciliation',
          opening_balance: 5000,
          actual_balance: null,
          expected_balance: 6200,
          difference: null,
          net_session_balance: 6200,
          opened_by_name: 'Carlos',
          closed_by_name: null,
          opened_at: '2026-10-22T23:05:18.702207+00:00',
          closed_at: '2026-10-24T15:02:57.3861+00:00',
          forced_close: true,
          total_movements: 1,
          total_income: 1200,
          total_expenses: 0,
        },
      ],
      error: null,
    });

    const history = useHistory();
    await history.fetchHistory('cash', 'week');

    expect(history.error.value).toBeNull();
    expect(history.items.value).toHaveLength(1);

    const item = history.items.value[0];
    expect(item.title).toBe('⚠️ Cierre Forzado (24h)');
    expect(item.subtitle).toContain('Pendiente de reconciliación');
    expect(item.subtitle).not.toContain('Cuadrada');
    expect(item.amountFormatted).toContain('Esp:');
    expect(item.user).toBe('Carlos → Sistema (24h)');
    expect(item.user).not.toContain('null');
    expect(item.badge?.text).toBe('Sin Reconciliar');
    expect(item.metadata.event_type).toBe('CIERRE');
  });

  it('formatea correctamente turnos con cierre forzado reconciliado, cerrados regulares y turnos abiertos, permitiendo filtrar por APERTURA / CIERRE', async () => {
    mockRpc.mockResolvedValueOnce({
      data: [
        {
          id: 'session-open-1',
          status: 'open',
          event_type: 'APERTURA',
          reconciliation_status: 'open',
          opening_balance: 50000,
          actual_balance: null,
          expected_balance: null,
          difference: null,
          net_session_balance: 70000,
          opened_by_name: 'Ana',
          closed_by_name: null,
          opened_at: '2026-10-24T22:17:15.847762+00:00',
          closed_at: null,
          forced_close: false,
          total_movements: 3,
          total_income: 25000,
          total_expenses: 5000,
        },
        {
          id: 'session-forced-rec-1',
          status: 'closed',
          event_type: 'CIERRE',
          reconciliation_status: 'forced_reconciled',
          opening_balance: 5000,
          actual_balance: 5000,
          expected_balance: 6200,
          difference: -1200,
          net_session_balance: 6200,
          opened_by_name: 'Carlos',
          closed_by_name: 'Admin',
          opened_at: '2026-10-22T23:05:18.702207+00:00',
          closed_at: '2026-10-24T15:02:57.3861+00:00',
          forced_close: true,
          total_movements: 1,
          total_income: 1200,
          total_expenses: 0,
        },
        {
          id: 'session-closed-ok-1',
          status: 'closed',
          event_type: 'CIERRE',
          reconciliation_status: 'closed_reconciled',
          opening_balance: 50000,
          actual_balance: 50000,
          expected_balance: 50000,
          difference: 0,
          net_session_balance: 50000,
          opened_by_name: 'Ana',
          closed_by_name: 'Ana',
          opened_at: '2026-10-20T12:00:00+00:00',
          closed_at: '2026-10-20T20:00:00+00:00',
          forced_close: false,
          total_movements: 0,
          total_income: 0,
          total_expenses: 0,
        },
      ],
      error: null,
    });

    const history = useHistory();
    await history.fetchHistory('cash', 'month');

    expect(history.error.value).toBeNull();
    expect(history.items.value).toHaveLength(3);

    const [openItem, forcedRecItem, closedOkItem] = history.items.value;
    expect(openItem.title).toBe('🟢 Turno Abierto');
    expect(openItem.amount).toBe(70000);
    expect(openItem.badge?.text).toBe('Abierto');

    expect(forcedRecItem.title).toBe('Turno Cerrado (Reconciliado)');
    expect(forcedRecItem.subtitle).toContain('Faltante:');
    expect(forcedRecItem.badge?.text).toBe('Forzado · Reconciliado');

    expect(closedOkItem.title).toBe('Turno Cerrado');
    expect(closedOkItem.subtitle).toContain('Cuadrada');
    expect(closedOkItem.badge?.text).toBe('Cerrado');

    // Probar filtro de sub-eventos APERTURA y CIERRE
    history.eventTypeFilter.value = 'APERTURA';
    expect(history.filteredItems.value).toHaveLength(1);
    expect(history.filteredItems.value[0].id).toBe('session-open-1');

    history.eventTypeFilter.value = 'CIERRE';
    expect(history.filteredItems.value).toHaveLength(2);
  });
});

describe('useHistory — Gobernanza de Filtros y Atajos (FRD-005, FRD-021)', () => {
  beforeEach(() => {
    mockRpc.mockReset();
  });

  it('inicia por defecto con dateFilter = "week" (Últimos 7 días) según FRD-005 Regla 6', () => {
    const history = useHistory();
    expect(history.dateFilter.value).toBe('week');
    expect(history.activeDateLabel.value).toBe('Últimos 7 días');
    expect(history.hasActiveFilters.value).toBe(false);
  });

  it('detecta y aplica atajos internos con applyShortcutQuery()', async () => {
    mockRpc.mockResolvedValue({ data: [], error: null });

    const history = useHistory();
    const employees = [{ id: 'emp-1', name: 'Carlos' }];

    const result = await history.applyShortcutQuery('ventas hoy efectivo empleado:carlos ticket #99', employees);

    expect(history.currentType.value).toBe('sales');
    expect(history.dateFilter.value).toBe('today');
    expect(history.paymentMethodFilter.value).toBe('CASH');
    expect(history.employeeFilter.value).toBe('emp-1');
    expect(history.searchQuery.value).toBe('ticket #99');
    expect(result.freeText).toBe('ticket #99');
    expect(result.matchedCount).toBe(4);
    expect(history.hasActiveFilters.value).toBe(true);
  });

  it('restablece filtros a su valor por defecto con resetFilters()', async () => {
    mockRpc.mockResolvedValue({ data: [], error: null });

    const history = useHistory();
    history.dateFilter.value = 'today';
    history.paymentMethodFilter.value = 'NEQUI';
    history.eventTypeFilter.value = 'cancellations';
    history.employeeFilter.value = 'emp-1';
    history.searchQuery.value = 'algo';

    expect(history.hasActiveFilters.value).toBe(true);

    await history.resetFilters();

    expect(history.dateFilter.value).toBe('week');
    expect(history.paymentMethodFilter.value).toBe('all');
    expect(history.eventTypeFilter.value).toBe('all');
    expect(history.employeeFilter.value).toBeNull();
    expect(history.searchQuery.value).toBe('');
    expect(history.hasActiveFilters.value).toBe(false);
  });

  it('filtra por método de pago multicanal (efectivo, nequi, digital)', () => {
    const history = useHistory();
    history.items.value = [
      {
        id: '1',
        type: 'sales',
        title: 'Venta #1',
        subtitle: '1 item',
        date: '2026-10-29',
        user: 'Ana',
        icon: 'cart',
        colorClass: '',
        metadata: { payment_method: 'efectivo' }
      },
      {
        id: '2',
        type: 'sales',
        title: 'Venta #2',
        subtitle: '1 item',
        date: '2026-10-29',
        user: 'Carlos',
        icon: 'cart',
        colorClass: '',
        metadata: { payment_method: 'nequi' }
      },
      {
        id: '3',
        type: 'sales',
        title: 'Venta #3',
        subtitle: '1 item',
        date: '2026-10-29',
        user: 'Carlos',
        icon: 'cart',
        colorClass: '',
        metadata: { payment_method: 'daviplata' }
      }
    ];

    history.paymentMethodFilter.value = 'efectivo';
    expect(history.filteredItems.value).toHaveLength(1);
    expect(history.filteredItems.value[0].id).toBe('1');

    history.paymentMethodFilter.value = 'digital';
    expect(history.filteredItems.value).toHaveLength(2); // nequi + daviplata

    history.paymentMethodFilter.value = 'nequi';
    expect(history.filteredItems.value).toHaveLength(1);
    expect(history.filteredItems.value[0].id).toBe('2');
  });
});

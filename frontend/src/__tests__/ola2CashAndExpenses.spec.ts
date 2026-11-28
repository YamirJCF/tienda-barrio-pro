/**
 * Tests Fase 3 Ola 2: Caja Dedicada POS, Propiedad del Turno, Cierre Asistido (3 Intentos),
 * +24h Expirado/Bloqueado, Notificaciones en BD y Gastos Menores 5 Categorías OPEX.
 * Cubre CHK-201 a CHK-210 (caminos felices + ramas de rechazo).
 */
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { createRouter, createMemoryHistory } from 'vue-router';
import Decimal from 'decimal.js';

// Mock global supabase client for repository & notificationsStore tests
const mockSupabaseRpc = vi.fn();
const mockNotificationsOrder = vi.fn();
const mockNotificationsUpdateIn = vi.fn();
const mockNotificationsUpdateEq = vi.fn();

const mockSupabaseClient = {
  rpc: (...args: any[]) => mockSupabaseRpc(...args),
  from: (table: string) => {
    if (table === 'notifications') {
      return {
        select: () => ({
          eq: () => ({
            order: () => ({
              limit: () => mockNotificationsOrder(),
            }),
          }),
        }),
        update: () => ({
          eq: (...args: any[]) => mockNotificationsUpdateEq(...args),
          in: () => ({
            eq: (...args: any[]) => mockNotificationsUpdateIn(...args),
          }),
        }),
      };
    }
    return {
      select: () => ({
        eq: () => ({
          eq: () => ({
            order: () => ({ limit: () => Promise.resolve({ data: [], error: null }) }),
            gte: () => Promise.resolve({ data: [], error: null }),
          }),
          order: () => Promise.resolve({ data: [], error: null }),
        }),
      }),
    };
  },
};

vi.mock('../data/supabaseClient', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../data/supabaseClient')>();
  return {
    ...actual,
    getSupabaseClient: () => mockSupabaseClient,
    requireSupabase: () => mockSupabaseClient,
    isSupabaseConfigured: () => true,
  };
});

vi.mock('../composables/useNotifications', () => ({
  useNotifications: () => ({
    showSuccess: vi.fn(),
    showError: vi.fn(),
    showWarning: vi.fn(),
    showInfo: vi.fn(),
  }),
}));

describe('Fase 3 Ola 2 — Control de Caja, Cierre Asistido, +24h, Notificaciones y Gastos OPEX', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    localStorage.clear();
    Object.defineProperty(navigator, 'onLine', { value: true, configurable: true });
  });

  // =========================================================================
  // CHK-203 & CHK-207: Cierre Asistido 3 Intentos + Propiedad Estricta
  // =========================================================================
  it('[CHK-203/207] closeRegister retorna COUNT_MISMATCH_RETRY sin cerrar sesión y sin exponer saldo esperado', async () => {
    const { useCashRegisterStore } = await import('../stores/cashRegister');
    const store = useCashRegisterStore();

    mockSupabaseRpc.mockResolvedValueOnce({
      data: {
        success: false,
        code: 'COUNT_MISMATCH_RETRY',
        attempts_used: 1,
        attempts_remaining: 2,
        message: 'El conteo no coincide con el registro del turno. Revisa y vuelve a intentar.',
      },
      error: null,
    });

    store.currentSession = {
      id: 'sess-111',
      storeId: '11111111-1111-1111-1111-111111111111',
      employeeId: 'emp-opener',
      openedByName: 'Laura Cajera',
      status: 'open',
      openingTime: new Date().toISOString(),
      openingBalance: new Decimal(100000),
      closingAttempts: 0,
      transactions: [],
    };

    const res = await store.closeRegister({ efectivo: 95000, nequi: 0, llave_bre: 0 });
    expect(res.success).toBe(false);
    expect(res.code).toBe('COUNT_MISMATCH_RETRY');
    expect(res.attemptsUsed).toBe(1);
    expect(res.attemptsRemaining).toBe(2);
    expect(store.isOpen).toBe(true);
    expect(store.currentSession?.closingAttempts).toBe(1);
  });

  it('[CHK-203] cashRepository registra evento dedicado UNAUTHORIZED_SHIFT_CLOSE cuando RPC rechaza propiedad', async () => {
    const { cashRepository } = await import('../data/repositories/cashRepository');

    mockSupabaseRpc
      .mockResolvedValueOnce({
        data: null,
        error: { message: 'SHIFT_OWNERSHIP_VIOLATION: Solo quien abrió este turno o el Administrador pueden cerrarlo.' },
      })
      .mockResolvedValueOnce({ data: null, error: null });

    const res = await cashRepository.registerEvent({
      id: 'sess-ajeno',
      store_id: '11111111-1111-1111-1111-111111111111',
      type: 'close',
      amount_declared: 50000,
      authorized_by_id: 'emp-intruder',
      authorized_by_name: 'Otro',
      authorized_by_type: 'employee',
    });

    expect(res.success).toBe(false);
    expect(res.code).toBe('SHIFT_OWNERSHIP_VIOLATION');
    expect(mockSupabaseRpc).toHaveBeenNthCalledWith(
      2,
      'rpc_log_security_event',
      expect.objectContaining({
        p_event_type: 'UNAUTHORIZED_SHIFT_CLOSE',
        p_store_id: '11111111-1111-1111-1111-111111111111',
      })
    );
  });

  // =========================================================================
  // CHK-207: CashControlView sin PinChallengeModal y sin modal "Esperado en Sistema"
  // =========================================================================
  it('[CHK-207] CashControlView bloquea cierre cuando el turno fue abierto por otro usuario y no monta PinChallengeModal', async () => {
    const CashControlView = (await import('../views/CashControlView.vue')).default;
    const { useAuthStore } = await import('../stores/auth');
    const { useCashRegisterStore } = await import('../stores/cashRegister');

    const authStore = useAuthStore();
    authStore.stores = [{ id: '11111111-1111-1111-1111-111111111111', storeName: 'Tienda Test' } as any];
    authStore.currentUser = {
      id: 'emp-b',
      employeeId: 'emp-b',
      name: 'Cajero B',
      email: 'cajerob@test.local',
      type: 'employee',
      storeId: '11111111-1111-1111-1111-111111111111',
      permissions: { canManageInventory: false, canFiar: false, canOpenCloseCash: true, canManageRefunds: false },
    };
    authStore.isAuthenticated = true;
    authStore.setDeviceStatus('approved');

    const cashStore = useCashRegisterStore();
    vi.spyOn(cashStore, 'syncFromBackend').mockImplementation(async () => {
      cashStore.currentSession = {
        id: 'sess-open-by-a',
        storeId: '11111111-1111-1111-1111-111111111111',
        employeeId: 'emp-a',
        openedByName: 'Cajero A',
        status: 'open',
        openingTime: new Date().toISOString(),
        openingBalance: new Decimal(50000),
        transactions: [],
      };
      return true;
    });

    const router = createRouter({
      history: createMemoryHistory(),
      routes: [
        { path: '/', name: 'dashboard', component: { template: '<div />' } },
        { path: '/cash-control', name: 'cash-control', component: CashControlView },
      ],
    });
    await router.push('/cash-control');

    const wrapper = mount(CashControlView, {
      global: {
        plugins: [router],
        stubs: { FormInputCurrency: true, ForcedCloseAuditModal: true },
      },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('Turno de Cajero A');
    expect(wrapper.html()).not.toContain('Esperado en Sistema');
    expect(wrapper.findComponent({ name: 'PinChallengeModal' }).exists()).toBe(false);
  });

  // =========================================================================
  // CHK-208 (Actualizado POL-SEG-02): ForcedCloseAuditModal exige conteo físico
  // obligatorio (prohibido omitir conteo), muestra resumen autoritativo al Admin
  // y exige observación breve (>= 5 caracteres) cuando el turno es de otro usuario.
  // =========================================================================
  it('[CHK-208] ForcedCloseAuditModal prohíbe cerrar sin conteo, muestra resumen Admin y exige observación para turno ajeno', async () => {
    const ForcedCloseAuditModal = (await import('../components/ForcedCloseAuditModal.vue')).default;

    const wrapper = mount(ForcedCloseAuditModal, {
      props: {
        isVisible: true,
        pendingSessions: [
          {
            id: 'sess-24h',
            openedAt: '2026-11-18T10:00:00Z',
            openedBy: 'emp-other',
            openedByName: 'Cajero Tarde',
            openingBalance: 50000,
            expectedEfectivo: 65000,
            nequiSummary: 35000,
            llaveBreSummary: 0,
            isOpenedByOther: true,
            channels: ['efectivo'],
          },
        ],
      },
      global: {
        stubs: {
          Teleport: true,
          FormInputCurrency: {
            props: ['modelValue', 'allowNull'],
            emits: ['update:modelValue'],
            template:
              '<input data-test="forced-cash-input" :value="modelValue ?? \'\'" @input="$emit(\'update:modelValue\', $event.target.value === \'\' ? null : Number($event.target.value))" />',
          },
        },
      },
    });

    // No existe opción de omitir conteo físico
    expect(wrapper.find('[data-test="skip-count-toggle"]').exists()).toBe(false);

    // Muestra resumen autoritativo del servidor para el Admin
    const summary = wrapper.find('[data-test="forced-close-session-summary"]');
    expect(summary.exists()).toBe(true);
    expect(summary.text()).toContain('Cajero Tarde');
    expect(summary.text()).toContain('65.000');
    expect(summary.text()).toContain('35.000');

    // Con monto vacío (null), botón deshabilitado
    const btn = wrapper.find('#btn-confirm-forced-close-audit');
    expect((btn.element as HTMLButtonElement).disabled).toBe(true);

    // Al digitar monto sin observación (turno de otro usuario), sigue deshabilitado
    await wrapper.find('input').setValue('64000');
    expect((btn.element as HTMLButtonElement).disabled).toBe(true);

    // Con observación >= 5 caracteres se habilita y emite (sessionId, monto, observación)
    await wrapper.find('[data-test="forced-close-notes-input"]').setValue('Empleado salió sin cerrar');
    expect((btn.element as HTMLButtonElement).disabled).toBe(false);

    await btn.trigger('click');
    expect(wrapper.emitted('confirm')?.[0]).toEqual(['sess-24h', 64000, 'Empleado salió sin cerrar']);
  });

  it('[CHK-208] router guard +24h redirige al abridor/Admin pero deja operar inventario/pos a otro empleado', async () => {
    const router = (await import('../router')).default;
    const { useAuthStore } = await import('../stores/auth');
    const { useCashRegisterStore } = await import('../stores/cashRegister');

    const authStore = useAuthStore();
    authStore.stores = [{ id: '11111111-1111-1111-1111-111111111111', storeName: 'Tienda Test' } as any];
    authStore.currentUser = {
      id: 'emp-logistica',
      employeeId: 'emp-logistica',
      name: 'Auxiliar Inventario',
      email: 'aux@test.local',
      type: 'employee',
      storeId: '11111111-1111-1111-1111-111111111111',
      permissions: { canManageInventory: true, canFiar: false, canOpenCloseCash: true, canManageRefunds: false },
    };
    authStore.isAuthenticated = true;
    authStore.setDeviceStatus('approved');
    vi.spyOn(authStore, 'verifySessionWithServer').mockResolvedValue({ success: true, status: 'active' } as any);

    const cashStore = useCashRegisterStore();
    cashStore.currentSession = {
      id: 'sess-stale',
      storeId: '11111111-1111-1111-1111-111111111111',
      employeeId: 'emp-otro-abridor',
      status: 'open',
      openingTime: new Date(Date.now() - 26 * 60 * 60 * 1000).toISOString(),
      openingBalance: new Decimal(10000),
      transactions: [],
    };

    // Otro empleado NO abridor navega a /inventory sin ser atrapado hacia cash-control
    await router.push('/inventory');
    expect(router.currentRoute.value.name).toBe('inventory');

    // Ahora cambia al abridor original e intenta navegar a /pos -> SÍ redirige a cash-control
    cashStore.currentSession.employeeId = 'emp-logistica';
    await router.push('/pos');
    expect(router.currentRoute.value.name).toBe('cash-control');

    // [B2-2] Post-rpc_check_and_force_close_shifts: currentSession es null pero pendingForcedSessionInfo existe -> Admin o abridor sigue redirigido
    cashStore.currentSession = null;
    cashStore.pendingForcedSessionInfo = {
      sessionId: 'sess-forced-24h',
      openedBy: 'emp-logistica',
      openedByName: 'Auxiliar Inventario',
      openedAt: '2026-11-18T10:00:00Z',
      closingAttempts: 0,
      lifecycleState: 'Expirado/Bloqueado',
    };
    await router.push('/inventory');
    expect(router.currentRoute.value.name).toBe('cash-control');
  });

  it('[B2-2] CashControlView permite al abridor original cerrar turno Expirado/Bloqueado tras rpc_check_and_force_close_shifts', async () => {
    const CashControlView = (await import('../views/CashControlView.vue')).default;
    const { useAuthStore } = await import('../stores/auth');
    const { useCashRegisterStore } = await import('../stores/cashRegister');

    const authStore = useAuthStore();
    authStore.stores = [{ id: '11111111-1111-1111-1111-111111111111', storeName: 'Tienda Test' } as any];
    authStore.currentUser = {
      id: 'emp-opener-exp',
      employeeId: 'emp-opener-exp',
      name: 'Cajero Expirado',
      email: 'exp@test.local',
      type: 'employee',
      storeId: '11111111-1111-1111-1111-111111111111',
      permissions: { canManageInventory: false, canFiar: false, canOpenCloseCash: true, canManageRefunds: false },
    };
    authStore.isAuthenticated = true;
    authStore.setDeviceStatus('approved');

    const cashStore = useCashRegisterStore();
    vi.spyOn(cashStore, 'syncFromBackend').mockImplementation(async () => {
      cashStore.currentSession = null;
      cashStore.pendingForcedSessionInfo = {
        sessionId: 'sess-forced-opener',
        openedBy: 'emp-opener-exp',
        openedByName: 'Cajero Expirado',
        openedAt: '2026-11-18T10:00:00Z',
        closingAttempts: 1,
        lifecycleState: 'Expirado/Bloqueado',
      };
      return false;
    });

    const router = createRouter({
      history: createMemoryHistory(),
      routes: [{ path: '/cash-control', name: 'cash-control', component: CashControlView }],
    });
    await router.push('/cash-control');

    const wrapper = mount(CashControlView, {
      global: { plugins: [router], stubs: { FormInputCurrency: true, ForcedCloseAuditModal: true } },
    });
    await flushPromises();

    // Debe mostrar pantalla de Cierre de Turno Expirado (+24h) con intento previo 1 de 3 (NO "Apertura de Caja")
    expect(wrapper.text()).toContain('CERRAR TURNO EXPIRADO');
    expect(wrapper.text()).toContain('Intento 1 de 3');
    expect(wrapper.text()).not.toContain('Apertura de Caja');
  });

  it('[B2-3] cashRepository.getStoreStatus propaga error real online sin caer a localStorage', async () => {
    const { cashRepository } = await import('../data/repositories/cashRepository');
    localStorage.setItem('tienda-store-status', JSON.stringify({ isOpen: true, openingAmount: 50000 }));

    mockSupabaseRpc.mockResolvedValueOnce({
      data: null,
      error: { message: 'DATABASE_TIMEOUT' },
    });

    await expect(cashRepository.getStoreStatus('11111111-1111-1111-1111-111111111111')).rejects.toThrow('DATABASE_TIMEOUT');
  });

  // =========================================================================
  // CHK-209: notificationsStore conectado a Supabase + filtrado admin
  // =========================================================================
  it('[CHK-209] notificationsStore carga alertas reales desde Supabase y oculta audience=admin a empleados', async () => {
    const { useNotificationsStore } = await import('../stores/notificationsStore');
    const store = useNotificationsStore();

    mockNotificationsOrder.mockResolvedValueOnce({
      data: [
        {
          id: 'notif-admin-1',
          store_id: '11111111-1111-1111-1111-111111111111',
          type: 'finance',
          title: 'Descuadre en Cierre de Caja',
          message: 'Alerta al 3.er intento',
          audience: 'admin',
          is_read: false,
          created_at: new Date().toISOString(),
          metadata: { event_type: 'CASH_DISCREPANCY_ALERT' },
        },
        {
          id: 'notif-all-1',
          store_id: '11111111-1111-1111-1111-111111111111',
          type: 'general',
          title: 'Aviso Turno',
          message: 'Mensaje general',
          audience: 'all',
          is_read: false,
          created_at: new Date().toISOString(),
          metadata: {},
        },
      ],
      error: null,
    });

    await store.fetchNotifications('11111111-1111-1111-1111-111111111111');

    expect(store.getVisibleNotifications('admin')).toHaveLength(2);
    expect(store.getVisibleNotifications('employee').map((n) => n.id)).toEqual(['notif-all-1']);

    mockNotificationsUpdateEq.mockResolvedValueOnce({ error: null });
    await store.markAsRead('notif-admin-1');
    expect(mockNotificationsUpdateEq).toHaveBeenCalledWith('id', 'notif-admin-1');

    // [B2-4] Al cambiar de tienda no filtra alertas de la tienda anterior y expone fetchError ante fallo real
    mockNotificationsOrder.mockResolvedValueOnce({ data: [], error: { message: 'RLS_READ_ERROR' } });
    await expect(store.fetchNotifications('22222222-2222-2222-2222-222222222222')).rejects.toBeTruthy();
    expect(store.fetchError).toContain('RLS_READ_ERROR');
    expect(store.notifications).toHaveLength(0);
  });

  // =========================================================================
  // CHK-210: ShiftExpensesTab (5 categorías, sin Reembolso ni Pago Proveedor Pan, Read Model SQL)
  //          y expenseRepository (canal real + movement_type = 'gasto')
  // =========================================================================
  it('[CHK-210 / B2-5] ShiftExpensesTab expone solo 5 categorías OPEX sin Reembolso ni Pago Proveedor Pan y usa rpc_obtener_gastos_turno', async () => {
    const ShiftExpensesTab = (await import('../components/cash/ShiftExpensesTab.vue')).default;
    const { useAuthStore } = await import('../stores/auth');
    const authStore = useAuthStore();
    authStore.stores = [{ id: '11111111-1111-1111-1111-111111111111', storeName: 'Tienda Test' } as any];
    authStore.currentUser = {
      id: 'admin-1',
      name: 'Admin Test',
      email: 'admin@test.local',
      type: 'admin',
      storeId: '11111111-1111-1111-1111-111111111111',
      permissions: { canManageInventory: true, canFiar: true, canOpenCloseCash: true, canManageRefunds: true },
    } as any;

    mockSupabaseRpc.mockResolvedValueOnce({
      data: {
        success: true,
        session_id: 'sess-gastos',
        session_status: 'open',
        total_opex_expenses: 5000,
        count: 1,
        data: [
          {
            id: 'tx-gasto',
            amount: 5000,
            description: 'Bolsas',
            category: 'Insumos',
            payment_method: 'efectivo',
            voucher_ref: null,
            actor_name: 'Admin Test',
            actor_role: 'owner',
            created_at: new Date().toISOString(),
          },
        ],
      },
      error: null,
    });

    const wrapper = mount(ShiftExpensesTab, {
      props: {
        sessionId: 'sess-gastos',
        isOpen: true,
      },
      global: {
        stubs: { FormInputCurrency: true, Teleport: true },
      },
    });
    await flushPromises();

    // Lista de gastos OPEX solo muestra tx-gasto ('Bolsas'), nunca 'pago_proveedor' ('Factura leche')
    expect(wrapper.text()).toContain('Gastos del Turno');
    expect(wrapper.text()).toContain('Bolsas');
    expect(wrapper.text()).not.toContain('Factura leche');

    // Abrir BaseModal
    await wrapper.find('[data-test="btn-register-expense"]').trigger('click');
    await flushPromises();
    const text = wrapper.text();
    expect(text).toContain('Servicios');
    expect(text).toContain('Nomina');
    expect(text).toContain('Transporte');
    expect(text).toContain('Mantenimiento');
    expect(text).toContain('Insumos');
    expect(text).not.toContain('Reembolso');
    expect(wrapper.html()).not.toContain('Pago Proveedor Pan');
  });

  it('[B2-5] expenseRepository.createExpense lanza error explícito si no hay caja abierta (nunca null)', async () => {
    const { expenseRepository } = await import('../data/repositories/expenseRepository');

    mockSupabaseRpc.mockResolvedValueOnce({
      data: { isOpen: false },
      error: null,
    });

    await expect(
      expenseRepository.createExpense({
        store_id: '11111111-1111-1111-1111-111111111111',
        amount: 5000,
        description: 'Luz',
        category: 'Servicios',
        payment_method: 'efectivo',
      })
    ).rejects.toThrow('NO_OPEN_SESSION');
  });

  it('[CHK-210] expenseRepository envía canal real (sin efectivo hardcodeado) y voucher_ref', async () => {
    const { expenseRepository } = await import('../data/repositories/expenseRepository');

    mockSupabaseRpc
      .mockResolvedValueOnce({
        data: { isOpen: true, sessionId: 'sess-exp', openingAmount: 10000, openedAt: new Date().toISOString() },
        error: null,
      })
      .mockResolvedValueOnce({
        data: {
          success: true,
          data: {
            movement_id: 'mov-1',
            payment_method: 'nequi',
            voucher_ref: 'NEQ-42',
            actor_name: 'Cajero A',
            actor_role: 'employee',
          },
        },
        error: null,
      });

    const created = await expenseRepository.createExpense({
      store_id: '11111111-1111-1111-1111-111111111111',
      amount: 15000,
      description: 'Compra bolsas',
      category: 'Insumos',
      payment_method: 'nequi',
      voucher_ref: 'NEQ-42',
    });

    expect(created?.payment_method).toBe('nequi');
    expect(mockSupabaseRpc).toHaveBeenLastCalledWith(
      'rpc_registrar_gasto_v2',
      expect.objectContaining({
        p_payment_method: 'nequi',
        p_voucher_ref: 'NEQ-42',
      })
    );
  });
});

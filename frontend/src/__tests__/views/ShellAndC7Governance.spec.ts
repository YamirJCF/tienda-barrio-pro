import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { reactive, ref } from 'vue';

import ToastNotification from '../../components/ToastNotification.vue';
import OfflineBanner from '../../components/common/OfflineBanner.vue';
import ConflictResolver from '../../components/common/ConflictResolver.vue';
import NotificationCenterView from '../../views/NotificationCenterView.vue';
import EmployeeManagerView from '../../views/EmployeeManagerView.vue';
import BottomNav from '../../components/BottomNav.vue';
import PinUnlockModal from '../../components/PinUnlockModal.vue';
import App from '../../App.vue';

import { useNotifications } from '../../composables/useNotifications';
import { useNotificationsStore } from '../../stores/notificationsStore';
import { useEmployeesStore } from '../../stores/employees';
import { useAuthStore } from '../../stores/auth';
import { useDevicesStore } from '../../stores/devices';
import { useCriticalAlerts } from '../../composables/useCriticalAlerts';
import { useSalesStore } from '../../stores/sales';
import syncQueue from '../../data/syncQueue';
import { employeeRepository } from '../../data/repositories/employeeRepository';

enableAutoUnmount(afterEach);

const { mockPush, mockReplace, mockRoute, mockRpc, mockFrom, mockIsOnline } = vi.hoisted(() => ({
  mockPush: vi.fn(),
  mockReplace: vi.fn(),
  mockRoute: { path: '/pos', name: 'pos', query: {} as Record<string, string> },
  mockRpc: vi.fn(),
  mockFrom: vi.fn(),
  mockIsOnline: { value: true },
}));

const reactiveRoute = reactive(mockRoute);

vi.mock('vue-router', () => ({
  useRouter: () => ({
    push: mockPush,
    replace: mockReplace,
    back: vi.fn(),
    currentRoute: ref(reactiveRoute),
  }),
  useRoute: () => reactiveRoute,
  RouterView: { template: '<div data-testid="router-view-stub" />' },
}));

vi.mock('../../composables/useDataSource', () => ({
  useDataSource: () => ({
    isOnline: ref(mockIsOnline.value),
  }),
}));

vi.mock('../../composables/useNetworkStatus', () => ({
  useNetworkStatus: vi.fn(),
}));

vi.mock('../../composables/useDataIntegrity', () => ({
  checkDataIntegrity: () => ({ wasCorrupted: false, repairedKeys: [] }),
}));

vi.mock('../../composables/useHeartbeat', () => ({
  useHeartbeat: vi.fn(),
}));

vi.mock('../../composables/useSessionGuard', () => ({
  useSessionGuard: vi.fn(),
  default: vi.fn(),
}));

vi.mock('../../lib/supabase', () => ({
  supabase: {
    rpc: mockRpc,
    from: mockFrom,
    channel: vi.fn(() => ({
      on: vi.fn().mockReturnThis(),
      subscribe: vi.fn().mockReturnValue({}),
    })),
    removeChannel: vi.fn().mockResolvedValue(undefined),
  },
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

let onlineState = true;
Object.defineProperty(navigator, 'onLine', {
  configurable: true,
  get: () => onlineState,
});

function setOnline(val: boolean) {
  onlineState = val;
  mockIsOnline.value = val;
}

describe('WO-OLA2-C7-SHELL-001: Shell Global, Árbitro N5, Enrutador N4 y Resiliencia C7', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    setOnline(true);
    reactiveRoute.path = '/pos';
    reactiveRoute.name = 'pos';
    reactiveRoute.query = {};

    const { dismissAll } = useNotifications();
    dismissAll();
    const { dismissAlert } = useCriticalAlerts();
    dismissAlert();
  });

  it('a) ToastNotification renderiza iconos SVG de Lucide reales ante strings heredados (sin tags string inválidos)', async () => {
    const { showSuccess, showError, showWarning, showInfo, showSaleOffline } = useNotifications();
    showSuccess('Venta OK');
    showError('Error de red');
    showWarning('Stock bajo');
    showInfo('Información');
    showSaleOffline('#042');

    const wrapper = mount(ToastNotification, {
      global: { stubs: { Teleport: true } },
    });
    await flushPromises();

    const svgs = wrapper.findAll('svg');
    expect(svgs.length).toBeGreaterThanOrEqual(5);
    expect(wrapper.html()).not.toContain('<check_circle');
    expect(wrapper.html()).not.toContain('<cloud_off');
    expect(wrapper.text()).toContain('Venta OK');
    expect(wrapper.text()).toContain('#042');
  });

  it('b) Árbitro N5 en App.vue excluye modales concurrentes por prioridad estricta y reemplaza alert()', async () => {
    const alertSpy = vi.fn();
    vi.stubGlobal('alert', alertSpy);
    const authStore = useAuthStore();
    authStore.isAuthenticated = true;
    authStore.stores = [
      { id: 's1', storeName: 'Tienda', ownerName: 'Dueño', email: 'a@b.co', password: '', createdAt: '' },
    ];
    authStore.currentUser = {
      id: 'admin-1',
      name: 'Dueño',
      email: 'a@b.co',
      type: 'admin',
      storeId: 's1',
    };
    vi.spyOn(authStore, 'checkLegalCompliance').mockResolvedValue(undefined as any);
    mockRpc.mockResolvedValue({ data: null, error: null });
    mockFrom.mockReturnValue({
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      maybeSingle: vi.fn().mockResolvedValue({ data: null, error: null }),
    });

    const devicesStore = useDevicesStore();
    devicesStore.pendingRequests = [
      {
        id: 'req-1',
        employeeId: 'emp-1',
        employeeName: 'Ana',
        deviceFingerprint: 'fp-1',
        userAgent: 'Chrome',
        status: 'pending',
        requestedAt: '2026-11-25T10:00:00Z',
      },
    ];
    devicesStore.isModalMinimized = false;

    const wrapper = mount(App, {
      global: {
        stubs: {
          GlobalNetworkHandler: true,
          OfflineBanner: true,
          LegalComplianceGate: true,
          GlobalAccessRequestModal: { template: '<div data-testid="stub-access-modal" />' },
          PinKeypad: true,
          CriticalAlertModal: {
            props: ['isVisible', 'title', 'message'],
            template: '<div v-if="isVisible" data-testid="stub-critical-modal">{{ title }}: {{ message }}</div>',
          },
          ToastNotification: true,
        },
      },
    });
    await flushPromises();

    // sync:auth_required NO llama alert(), navega a /login y activa alerta N5
    window.dispatchEvent(new CustomEvent('sync:auth_required'));
    await flushPromises();

    expect(alertSpy).not.toHaveBeenCalled();
    expect(mockPush).toHaveBeenCalledWith('/login');

    // Mientras access_request está activo (prioridad 4), critical_alert (prioridad 5) NO se muestra
    expect(wrapper.find('[data-testid="stub-access-modal"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="stub-critical-modal"]').exists()).toBe(false);

    // Al abrir PIN (prioridad 3), access_request desaparece y PinUnlockModal muestra su cabecera sin emoji
    window.dispatchEvent(new CustomEvent('sync:pin_required'));
    await flushPromises();
    expect(wrapper.find('[data-testid="stub-access-modal"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="pin-unlock-modal"]').exists()).toBe(true);
    expect(wrapper.get('[data-testid="pin-unlock-modal"]').text()).not.toContain('🔑');

    // Al activarse legal gate (prioridad 2), PIN pasa a suppressed y se oculta
    authStore.legalComplianceStatus = 'requires_major_acceptance' as any;
    authStore.legalPendingMajorDocs = [{ id: 'doc-1' } as any];
    reactiveRoute.path = '/admin';
    await flushPromises();
    expect(wrapper.find('[data-testid="pin-unlock-modal"]').exists()).toBe(false);

    // Al limpiarse gates superiores, critical_alert (prioridad 5) finalmente emerge
    authStore.legalComplianceStatus = 'compliant' as any;
    authStore.legalPendingMajorDocs = [];
    wrapper.findComponent(PinUnlockModal).vm.$.exposed?.close();
    devicesStore.pendingRequests = [];
    await flushPromises();

    expect(wrapper.get('[data-testid="stub-critical-modal"]').text()).toContain('Sesión Expirada');
    vi.unstubAllGlobals();
  });

  it('c) OfflineBanner permite cierre real y ConflictResolver monta ForceSaleModal sin alert() ni material-icons', async () => {
    setOnline(false);
    const offlineWrapper = mount(OfflineBanner);
    await flushPromises();
    expect(offlineWrapper.find('[data-testid="offline-banner"]').exists()).toBe(true);

    await offlineWrapper.get('[data-testid="offline-banner-dismiss"]').trigger('click');
    await flushPromises();
    expect(offlineWrapper.find('[data-testid="offline-banner"]').exists()).toBe(false);

    setOnline(true);
    const alertSpy = vi.fn();
    vi.stubGlobal('alert', alertSpy);
    const authStore = useAuthStore();
    authStore.currentUser = {
      id: 'admin-1',
      name: 'Dueño',
      email: 'a@b.co',
      type: 'admin',
      storeId: 's1',
    };
    vi.spyOn(authStore, 'checkLegalCompliance').mockResolvedValue(undefined as any);
    mockRpc.mockResolvedValue({ data: null, error: null });
    mockFrom.mockReturnValue({
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      maybeSingle: vi.fn().mockResolvedValue({ data: null, error: null }),
    });
    const salesStore = useSalesStore();
    vi.spyOn(salesStore, 'forceSale').mockResolvedValue({ success: false, error: 'Motivo insuficiente' });
    vi.spyOn(syncQueue, 'getDLQItems').mockResolvedValue([
      {
        id: 'dlq-1',
        type: 'CREATE_SALE',
        timestamp: Date.now(),
        error: 'Stock insuficiente para Arroz',
        payload: {
          storeId: 's1',
          total: 5000,
          paymentMethod: 'efectivo',
          items: [{ productId: 'p1', productName: 'Arroz', quantity: 2, price: 2500, subtotal: 5000 }],
        },
      } as any,
    ]);

    const conflictWrapper = mount(ConflictResolver, {
      props: { isOpen: false },
      global: {
        stubs: {
          ForceSaleModal: {
            props: ['isOpen', 'items'],
            emits: ['confirm', 'cancel'],
            template: '<div v-if="isOpen" data-testid="force-sale-mounted"><button data-testid="force-confirm-btn" @click="$emit(\'confirm\', \'Forzado por conteo\')">Confirmar</button></div>',
          },
        },
      },
    });
    await conflictWrapper.setProps({ isOpen: true });
    await flushPromises();

    expect(conflictWrapper.html()).not.toContain('material-icons');
    const forceBtn = conflictWrapper.findAll('button').find((b) => b.text().includes('Forzar Venta'));
    expect(forceBtn).toBeDefined();
    await forceBtn!.trigger('click');
    await flushPromises();

    expect(conflictWrapper.find('[data-testid="force-sale-mounted"]').exists()).toBe(true);
    await conflictWrapper.get('[data-testid="force-confirm-btn"]').trigger('click');
    await flushPromises();

    expect(alertSpy).not.toHaveBeenCalled();
    expect(conflictWrapper.get('[data-testid="conflict-action-error"]').text()).toContain('Motivo insuficiente');
    vi.unstubAllGlobals();
  });

  it('d) NotificationCenterView enruta vía metadata + permisos sin border-l-4 y marca leída la notificación', async () => {
    const authStore = useAuthStore();
    authStore.isAuthenticated = true;
    authStore.stores = [{ id: 's1', storeName: 'Tienda', ownerName: 'Dueño', email: 'a@b.co', password: '', createdAt: '' }];
    authStore.currentUser = {
      id: 'admin-1',
      name: 'Dueño',
      email: 'a@b.co',
      type: 'admin',
      storeId: 's1',
      permissions: { canManageInventory: true, canFiar: true, canOpenCloseCash: true, canManageRefunds: true },
    };

    const notifStore = useNotificationsStore();
    vi.spyOn(notifStore, 'fetchNotifications').mockResolvedValue(undefined);
    const markReadSpy = vi.spyOn(notifStore, 'markAsRead').mockResolvedValue(undefined);

    notifStore.notifications = [
      { id: 'n-prod', type: 'inventory', audience: 'all', icon: 'Package', title: 'Stock', message: 'Bajo', createdAt: '2026-11-25T10:06:00Z', isRead: false, metadata: { productId: 'p-1' } },
      { id: 'n-cli', type: 'finance', audience: 'all', icon: 'Store', title: 'Fiado', message: 'Deuda', createdAt: '2026-11-25T10:05:00Z', isRead: false, metadata: { clientId: 'c-1' } },
      { id: 'n-sale', type: 'finance', audience: 'admin', icon: 'Banknote', title: 'Venta', message: 'Anulada', createdAt: '2026-11-25T10:04:00Z', isRead: false, metadata: { saleId: 'sale-1' } },
      { id: 'n-force', type: 'security', audience: 'admin', icon: 'Shield', title: 'Cierre Forzado 24h', message: 'Reconciliar', createdAt: '2026-11-25T10:03:00Z', isRead: false, metadata: { sessionId: 'sess-1', eventType: 'FORCE_CLOSE_24H' } },
      { id: 'n-cash', type: 'finance', audience: 'admin', icon: 'Banknote', title: 'Cierre de Turno', message: 'Normal', createdAt: '2026-11-25T10:02:00Z', isRead: false, metadata: { sessionId: 'sess-2' } },
      { id: 'n-sup', type: 'finance', audience: 'admin', icon: 'Banknote', title: 'Factura CxP', message: 'Vence hoy', createdAt: '2026-11-25T10:01:00Z', isRead: false, metadata: { supplierId: 'sup-1' } },
    ];

    const wrapper = mount(NotificationCenterView, {
      global: { stubs: { NotificationSecurityWidget: true } },
    });
    await flushPromises();

    const cards = wrapper.findAll('[data-testid="notification-card"]');
    expect(cards).toHaveLength(6);
    expect(wrapper.html()).not.toContain('border-l-4');

    await cards[0].trigger('click');
    await cards[1].trigger('click');
    await cards[2].trigger('click');
    await cards[3].trigger('click');
    await cards[4].trigger('click');
    await cards[5].trigger('click');

    expect(markReadSpy).toHaveBeenCalledTimes(6);
    expect(mockPush).toHaveBeenNthCalledWith(1, '/inventory?productId=p-1&tab=batches');
    expect(mockPush).toHaveBeenNthCalledWith(2, '/clients/c-1');
    expect(mockPush).toHaveBeenNthCalledWith(3, '/reports?tab=history&domain=sales&saleId=sale-1');
    expect(mockPush).toHaveBeenNthCalledWith(4, '/cash-control');
    expect(mockPush).toHaveBeenNthCalledWith(5, '/reports?tab=history&domain=cash&sessionId=sess-2');
    expect(mockPush).toHaveBeenNthCalledWith(6, '/suppliers?tab=payables');

    // Empleado sin permisos no accede a rutas Admin de saleId/supplierId y sessionId va a /cash-control
    mockPush.mockClear();
    authStore.loginAsEmployee(
      { id: 'emp-1', name: 'Luis', username: '200', permissions: { canManageInventory: false, canFiar: false, canOpenCloseCash: false, canManageRefunds: false } },
      's1'
    );
    notifStore.notifications = [
      { id: 'n-emp-sess', type: 'finance', audience: 'all', icon: 'Banknote', title: 'Turno', message: 'Info', createdAt: '2026-11-25T10:06:00Z', isRead: false, metadata: { sessionId: 'sess-9' } },
      { id: 'n-emp-prod', type: 'inventory', audience: 'all', icon: 'Package', title: 'Stock', message: 'Info', createdAt: '2026-11-25T10:05:00Z', isRead: false, metadata: { productId: 'p-9' } },
    ];
    await flushPromises();
    const empCards = wrapper.findAll('[data-testid="notification-card"]');
    await empCards[0].trigger('click');
    await empCards[1].trigger('click');
    expect(mockPush).toHaveBeenCalledTimes(1);
    expect(mockPush).toHaveBeenCalledWith('/cash-control');
  });

  it('e) EmployeeManagerView muestra N3 + Reintentar, aviso N1 5/5 y employees.ts excluye owner_ al reactivar el 5to operativo', async () => {
    const authStore = useAuthStore();
    authStore.isAuthenticated = true;
    authStore.stores = [{ id: 's1', storeName: 'Tienda', ownerName: 'Dueño', email: 'a@b.co', password: '', createdAt: '' }];
    authStore.currentUser = { id: 'admin-1', name: 'Dueño', email: 'a@b.co', type: 'admin', storeId: 's1' };

    setOnline(false);
    const empStore = useEmployeesStore();
    const wrapper = mount(EmployeeManagerView, {
      global: { stubs: { BottomNav: true, EmployeeFormModal: true, BaseModal: true, BaseInput: true } },
    });
    await flushPromises();

    expect(wrapper.get('[data-testid="employees-error-banner"]').text()).toContain('Sin conexión');
    expect(wrapper.text()).not.toContain('Sin empleados');

    // Reconectar y devolver 1 owner_ + 4 activos + 1 inactivo
    setOnline(true);
    const perms = { canManageInventory: false, canFiar: false, canOpenCloseCash: false, canManageRefunds: false };
    vi.spyOn(employeeRepository, 'getAll').mockResolvedValue([
      { id: '0', storeId: 's1', name: 'Dueño', username: 'owner_abc', pin: '', isActive: true, permissions: perms, createdAt: '', updatedAt: '' },
      { id: '1', storeId: 's1', name: 'Emp 1', username: 'e1', pin: '', isActive: true, permissions: perms, createdAt: '', updatedAt: '' },
      { id: '2', storeId: 's1', name: 'Emp 2', username: 'e2', pin: '', isActive: true, permissions: perms, createdAt: '', updatedAt: '' },
      { id: '3', storeId: 's1', name: 'Emp 3', username: 'e3', pin: '', isActive: true, permissions: perms, createdAt: '', updatedAt: '' },
      { id: '4', storeId: 's1', name: 'Emp 4', username: 'e4', pin: '', isActive: true, permissions: perms, createdAt: '', updatedAt: '' },
      { id: '5', storeId: 's1', name: 'Emp 5', username: 'e5', pin: '', isActive: false, permissions: perms, createdAt: '', updatedAt: '' },
    ]);

    await wrapper.get('[data-testid="employees-retry-btn"]').trigger('click');
    await flushPromises();

    expect(wrapper.text()).toContain('@e1');

    // Activar al 5to empleado operativo NO debe fallar por culpa de owner_abc
    vi.spyOn(employeeRepository, 'update').mockResolvedValue({
      id: '5', storeId: 's1', name: 'Emp 5', username: 'e5', pin: '', isActive: true, permissions: perms, createdAt: '', updatedAt: '',
    });
    const updated = await empStore.updateEmployee('5', { isActive: true });
    expect(updated?.isActive).toBe(true);
    await flushPromises();

    expect(wrapper.get('[data-testid="employees-limit-banner"]').text()).toContain('5/5');
  });

  it('f) BottomNav incluye Inicio como primer destino apuntando a / en grid de 6 columnas para Admin', async () => {
    const authStore = useAuthStore();
    authStore.isAuthenticated = true;
    authStore.stores = [{ id: 's1', storeName: 'Tienda', ownerName: 'Dueño', email: 'a@b.co', password: '', createdAt: '' }];
    authStore.currentUser = {
      id: 'admin-1',
      name: 'Dueño',
      email: 'a@b.co',
      type: 'admin',
      storeId: 's1',
      permissions: { canManageInventory: true, canFiar: true, canOpenCloseCash: true, canManageRefunds: true },
    };

    const wrapper = mount(BottomNav);
    const buttons = wrapper.findAll('button');
    expect(buttons).toHaveLength(6);
    expect(buttons[0].text()).toContain('Inicio');
    expect(wrapper.find('.grid-cols-6').exists()).toBe(true);

    await wrapper.get('[data-testid="bottom-nav-home"]').trigger('click');
    expect(mockPush).toHaveBeenCalledWith('/');
  });
});

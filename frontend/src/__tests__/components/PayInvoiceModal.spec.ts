import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { reactive } from 'vue';
import PayInvoiceModal from '../../components/suppliers/PayInvoiceModal.vue';
import { useAuthStore } from '../../stores/auth';
import { usePayablesStore } from '../../stores/payables';
import { useCashRegisterStore } from '../../stores/cashRegister';

enableAutoUnmount(afterEach);

const { mockRpc, mockShowSuccess, mockSyncFromBackend } = vi.hoisted(() => ({
  mockRpc: vi.fn(),
  mockShowSuccess: vi.fn(),
  mockSyncFromBackend: vi.fn().mockResolvedValue(true),
}));

vi.mock('@/composables/useNotifications', () => ({
  useNotifications: () => ({
    showSuccess: mockShowSuccess,
    showError: vi.fn(),
    showWarning: vi.fn(),
    showInfo: vi.fn(),
  }),
}));

vi.mock('@/lib/supabase', () => ({
  supabase: {
    rpc: (...args: any[]) => mockRpc(...args),
  },
}));

const cashMockState = reactive({
  isOpen: true,
  isStaleSession: false,
  currentBalance: 100000,
  balancesByMethod: {
    efectivo: 100000,
    nequi: 12000,
    llave_bre: 0,
  } as Record<string, number>,
  syncFromBackend: (...args: any[]) => mockSyncFromBackend(...args),
});

vi.mock('@/stores/cashRegister', () => ({
  useCashRegisterStore: () => cashMockState,
}));

const baseInvoice = {
  id: 'inv-100',
  store_id: 'store-1',
  supplier_id: 'sup-1',
  supplier: { name: 'Distribuidora Sur' },
  invoice_number: 'FAC-100',
  total_amount: 80000,
  amount_paid: 30000,
  pending_balance: 50000,
  due_date: '2026-12-15',
  status: 'pendiente' as const,
};

const modalStubs = {
  BaseModal: {
    props: ['modelValue', 'title'],
    template: '<div v-if="modelValue" data-testid="pay-modal-wrapper"><slot /><slot name="footer" /></div>',
  },
  BaseInput: {
    props: ['modelValue', 'disabled'],
    template:
      '<input type="number" :disabled="disabled" :value="modelValue" @input="$emit(\'update:modelValue\', Number($event.target.value))" />',
  },
  BaseButton: {
    props: ['disabled', 'loading'],
    template: '<button :disabled="disabled"><slot /></button>',
  },
};

describe('PayInvoiceModal.vue (WO-OLA2-C5-001)', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    cashMockState.isOpen = true;
    cashMockState.isStaleSession = false;
    cashMockState.currentBalance = 100000;
    cashMockState.balancesByMethod = { efectivo: 100000, nequi: 12000, llave_bre: 0 };

    const authStore = useAuthStore();
    authStore.currentUser = {
      id: 'admin-1',
      name: 'Admin',
      type: 'admin',
      storeId: 'store-1',
      permissions: { canManageInventory: true, canFiar: true, canOpenCloseCash: true, canManageRefunds: true },
    } as any;
    authStore.isAuthenticated = true;
  });

  it('sincroniza caja al abrirse y lee pending_balance del servidor sin restar en cliente', async () => {
    // Escenario intencional: si la UI restara total_amount - amount_paid daría 80k-30k=50k,
    // pero probamos con pending_balance autoritativo del servidor = 42000
    const serverInvoice = { ...baseInvoice, pending_balance: 42000 };

    const wrapper = mount(PayInvoiceModal, {
      props: { show: true, invoice: serverInvoice },
      global: { stubs: modalStubs },
    });
    await flushPromises();

    expect(mockSyncFromBackend).toHaveBeenCalledWith('store-1', { throwOnError: true });
    expect(wrapper.text()).toContain('42.000');

    // Al elegir Nequi ($12.000) e ingresar $20.000 muestra bloqueo N1 por sobregiro de canal
    await wrapper.get('[data-testid="pay-method-nequi"]').trigger('click');
    await wrapper.find('input[type="number"]').setValue(20000);
    expect(wrapper.get('[data-testid="insufficient-channel-balance-alert"]').text()).toContain('Nequi');
  });

  it('envía abono por canal interno con descripción obligatoria y notifica vía useNotifications', async () => {
    const payablesStore = usePayablesStore();
    const paySpy = vi.spyOn(payablesStore, 'payInvoice').mockResolvedValue({ success: true });

    const wrapper = mount(PayInvoiceModal, {
      props: { show: true, invoice: baseInvoice },
      global: { stubs: modalStubs },
    });
    await flushPromises();

    await wrapper.find('input[type="number"]').setValue(25000);
    await wrapper.get('[data-testid="pay-method-efectivo"]').trigger('click');

    // Sin descripción el botón Confirmar Abono permanece bloqueado
    const confirmBtnBefore = wrapper.findAll('button').find((b) => b.text().includes('Confirmar Abono'))!;
    expect((confirmBtnBefore.element as HTMLButtonElement).disabled).toBe(true);

    await wrapper.get('[data-testid="pay-invoice-description-input"]').setValue('Abono factura proveedor');
    expect((confirmBtnBefore.element as HTMLButtonElement).disabled).toBe(false);

    await confirmBtnBefore.trigger('click');
    await flushPromises();

    expect(paySpy).toHaveBeenCalledWith('inv-100', 25000, 'efectivo', 'Abono factura proveedor');
    expect(mockShowSuccess).toHaveBeenCalledWith('Abono registrado correctamente');
    expect(wrapper.emitted('success')).toBeTruthy();
    expect(wrapper.emitted('close')).toBeTruthy();
  });

  it('permite Pago externo / fuera de caja con caja cerrada y muestra alerta informativa sin emojis ni border-l-4', async () => {
    cashMockState.isOpen = false;
    const payablesStore = usePayablesStore();
    const paySpy = vi.spyOn(payablesStore, 'payInvoice').mockResolvedValue({ success: true });

    const wrapper = mount(PayInvoiceModal, {
      props: { show: true, invoice: baseInvoice },
      global: { stubs: modalStubs },
    });
    await flushPromises();

    expect(wrapper.html()).not.toContain('border-l-4');
    expect(wrapper.text()).not.toContain('ℹ️');
    expect(wrapper.text()).not.toContain('🚫');

    await wrapper.find('input[type="number"]').setValue(50000);
    await wrapper.get('[data-testid="pay-method-externo"]').trigger('click');
    const confirmBtn = wrapper.findAll('button').find((b) => b.text().includes('Confirmar Abono'))!;
    expect((confirmBtn.element as HTMLButtonElement).disabled).toBe(false);

    await confirmBtn.trigger('click');
    await flushPromises();

    expect(paySpy).toHaveBeenCalledWith('inv-100', 50000, 'externo', undefined);
  });

  it('falla cerrado con banner N3 si syncFromBackend lanza error y no muestra falsamente "Turno de caja cerrado"', async () => {
    mockSyncFromBackend.mockRejectedValueOnce(new Error('TIMEOUT_CAJA'));

    const wrapper = mount(PayInvoiceModal, {
      props: { show: true, invoice: baseInvoice },
      global: { stubs: modalStubs },
    });
    await flushPromises();

    expect(mockSyncFromBackend).toHaveBeenCalledWith('store-1', { throwOnError: true });
    const syncBanner = wrapper.get('[data-testid="pay-modal-cash-sync-error"]');
    expect(syncBanner.text()).toContain('TIMEOUT_CAJA');
    expect(wrapper.find('[data-testid="pay-modal-cash-closed-banner"]').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Turno de caja cerrado.');

    // Aunque seleccione canal interno con error de sincronización, Confirmar Abono queda bloqueado (fail-closed)
    await wrapper.find('input[type="number"]').setValue(10000);
    await wrapper.get('[data-testid="pay-method-efectivo"]').trigger('click');
    await wrapper.get('[data-testid="pay-invoice-description-input"]').setValue('Intento bloqueado');
    const confirmBlockedBtn = wrapper.findAll('button').find((b) => b.text().includes('Confirmar Abono'))!;
    expect((confirmBlockedBtn.element as HTMLButtonElement).disabled).toBe(true);

    // Reintentar vuelve a consultar y limpia el banner N3 al resolverse
    mockSyncFromBackend.mockResolvedValueOnce(true);
    await wrapper.get('[data-testid="pay-modal-cash-sync-retry-btn"]').trigger('click');
    await flushPromises();

    expect(mockSyncFromBackend).toHaveBeenCalledTimes(2);
    expect(wrapper.find('[data-testid="pay-modal-cash-sync-error"]').exists()).toBe(false);
    expect((confirmBlockedBtn.element as HTMLButtonElement).disabled).toBe(false);
  });
});

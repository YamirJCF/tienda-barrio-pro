import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { mount, flushPromises, enableAutoUnmount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { Decimal } from 'decimal.js';
import RefundModal from '../../components/sales/RefundModal.vue';
import { useAuthStore } from '../../stores/auth';
import { useCashRegisterStore } from '../../stores/cashRegister';
import { saleRepository, type RefundCandidateSale } from '../../data/repositories/saleRepository';

const { mockShowSuccess, mockShowError } = vi.hoisted(() => ({
  mockShowSuccess: vi.fn(),
  mockShowError: vi.fn(),
}));

vi.mock('../../composables/useNotifications', () => ({
  useNotifications: () => ({
    showSuccess: mockShowSuccess,
    showError: mockShowError,
    showWarning: vi.fn(),
    showInfo: vi.fn(),
  }),
}));

enableAutoUnmount(afterEach);

describe('RefundModal.vue — Read Model FIFO y Resiliencia N1/N3 (C1-H4)', () => {
  const storeId = 'store-1';

  const makeCandidates = (): RefundCandidateSale[] => [
    {
      sale_id: 'sale-100',
      ticket_number: 501,
      created_at: '2026-11-25T10:00:00Z',
      total: 6000,
      payment_method: 'efectivo',
      actor_name: 'Carlos Cajero',
      items: [
        {
          sale_item_id: 'si-100',
          product_id: 'prod-1',
          product_name: 'Leche Entera 1L',
          plu: '1001',
          current_stock: 12,
          is_weighable: false,
          measurement_unit: 'unidad',
          quantity: 2,
          refunded_quantity: 0,
          remaining_quantity: 2,
          unit_price: 3000,
          subtotal: 6000,
          fifo_batches: [
            {
              batch_id: '99999999-aaaa-bbbb-cccc-000000000102',
              quantity: 2,
              unit_cost: 1850,
              created_at: '2026-11-24T09:00:00Z',
            },
          ],
        },
      ],
    },
  ];

  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
    vi.clearAllMocks();
    Object.defineProperty(window.navigator, 'onLine', { value: true, configurable: true });

    const authStore = useAuthStore();
    authStore.currentUser = {
      id: 'owner-1',
      name: 'Owner',
      email: 'owner@test.com',
      type: 'admin',
      storeId,
    } as any;
    authStore.currentStore = { id: storeId, name: 'Tienda Test' } as any;

    const cashStore = useCashRegisterStore();
    cashStore.currentSession = {
      id: 'session-1',
      storeId,
      employeeId: 'owner-1',
      status: 'open',
      openingTime: new Date().toISOString(),
      openingBalance: new Decimal(100000),
      transactions: [],
    } as any;
  });

  const mountRefundModal = () =>
    mount(RefundModal, {
      props: { modelValue: true },
      global: {
        stubs: {
          teleport: true,
          BaseModal: { template: '<div><slot /></div>' },
          BaseButton: { props: ['disabled', 'loading'], template: '<button :disabled="disabled"><slot /></button>' },
        },
      },
    });

  it('muestra Read Model FIFO (fifo_batches) y cambia política entre reingreso vendible y merma', async () => {
    vi.spyOn(saleRepository, 'searchRefundCandidates').mockResolvedValueOnce(makeCandidates());

    const wrapper = mountRefundModal();
    await flushPromises();

    const refundBtn = wrapper.findAll('button').find((b) => b.text().trim() === 'Reembolsar');
    expect(refundBtn).toBeDefined();
    await refundBtn!.trigger('click');

    const fifoCard = wrapper.find('[data-testid="refund-fifo-read-model"]');
    expect(fifoCard.exists()).toBe(true);
    expect(fifoCard.text()).toContain('Trazabilidad / Reingreso FIFO');
    expect(fifoCard.text()).toContain('Lote #99999999');
    expect(fifoCard.text()).toContain('Cant. orig: 2');
    expect(fifoCard.text()).toContain('$ 1.850');
    expect(fifoCard.text()).toContain('Reingreso vendible FIFO');

    const authorityCard = wrapper.find('[data-testid="refund-server-authority-card"]');
    expect(authorityCard.exists()).toBe(true);
    expect(authorityCard.text()).toContain('$ 3.000');
    expect(authorityCard.text()).toContain('$ 6.000');
    expect(wrapper.text()).not.toContain('~est.');

    await wrapper.find('input[type="checkbox"]').setValue(true);
    expect(fifoCard.text()).toContain('Sin reingreso (Merma)');
    expect(fifoCard.text()).toContain('0 unidades reingresan a stock vendible');
  });

  it('muestra banner N3 con Reintentar si falla la búsqueda sin falsos vacíos ni toast de error', async () => {
    const searchSpy = vi
      .spyOn(saleRepository, 'searchRefundCandidates')
      .mockRejectedValueOnce(new Error('Timeout consultando ventas en Supabase'))
      .mockResolvedValueOnce(makeCandidates());

    const wrapper = mountRefundModal();
    await flushPromises();

    const errorBox = wrapper.find('[data-testid="refund-search-error"]');
    expect(errorBox.exists()).toBe(true);
    expect(errorBox.text()).toContain('Timeout consultando ventas en Supabase');
    expect(wrapper.text()).not.toContain('No se encontraron ventas activas para reembolsar.');
    expect(mockShowError).not.toHaveBeenCalled();

    await wrapper.get('[data-testid="refund-search-retry-btn"]').trigger('click');
    await flushPromises();

    expect(searchSpy).toHaveBeenCalledTimes(2);
    expect(wrapper.find('[data-testid="refund-search-error"]').exists()).toBe(false);
    expect(wrapper.text()).toContain('Leche Entera 1L');
  });

  it('muestra error N1 inline si falla submitRefund sin usar showError efímero', async () => {
    vi.spyOn(saleRepository, 'searchRefundCandidates').mockResolvedValueOnce(makeCandidates());
    vi.spyOn(saleRepository, 'processItemRefund').mockRejectedValueOnce(
      new Error('Fondos insuficientes en efectivo para reembolsar.')
    );

    const wrapper = mountRefundModal();
    await flushPromises();

    await wrapper.findAll('button').find((b) => b.text().trim() === 'Reembolsar')!.trigger('click');
    await wrapper.find('textarea').setValue('Producto devuelto en caja');
    await wrapper.get('[data-testid="refund-confirm-btn"]').trigger('click');
    await flushPromises();

    const submitErr = wrapper.find('[data-testid="refund-submit-error"]');
    expect(submitErr.exists()).toBe(true);
    expect(submitErr.text()).toContain('Fondos insuficientes en efectivo');
    expect(mockShowError).not.toHaveBeenCalled();
  });

  it('bloquea envío cuando está offline o la caja está cerrada', async () => {
    vi.spyOn(saleRepository, 'searchRefundCandidates').mockResolvedValue(makeCandidates());
    const cashStore = useCashRegisterStore();
    cashStore.currentSession = null;

    const wrapperClosed = mountRefundModal();
    await flushPromises();
    expect(wrapperClosed.find('[data-testid="refund-cash-closed-alert"]').exists()).toBe(true);
    await wrapperClosed.findAll('button').find((b) => b.text().trim() === 'Reembolsar')!.trigger('click');
    await wrapperClosed.find('textarea').setValue('Motivo válido reembolso');
    expect((wrapperClosed.get('[data-testid="refund-confirm-btn"]').element as HTMLButtonElement).disabled).toBe(true);

    // Offline
    Object.defineProperty(window.navigator, 'onLine', { value: false, configurable: true });
    const wrapperOffline = mountRefundModal();
    await flushPromises();
    expect(wrapperOffline.find('[data-testid="refund-offline-alert"]').exists()).toBe(true);
    expect(wrapperOffline.find('[data-testid="refund-search-error"]').exists()).toBe(true);
  });

  it('bloquea envío con mensaje específico cuando la sesión de caja superó 24h (isStaleSession = true)', async () => {
    vi.spyOn(saleRepository, 'searchRefundCandidates').mockResolvedValue(makeCandidates());
    const cashStore = useCashRegisterStore();
    cashStore.currentSession = {
      id: 'session-stale-1',
      storeId,
      employeeId: 'owner-1',
      status: 'open',
      isExpired24h: true,
      openingTime: new Date(Date.now() - 25 * 60 * 60 * 1000).toISOString(),
      openingBalance: new Decimal(100000),
      transactions: [],
    } as any;

    const wrapperStale = mountRefundModal();
    await flushPromises();

    const alert = wrapperStale.find('[data-testid="refund-cash-closed-alert"]');
    expect(alert.exists()).toBe(true);
    expect(alert.text()).toContain('superó las 24 horas');

    await wrapperStale.findAll('button').find((b) => b.text().trim() === 'Reembolsar')!.trigger('click');
    await wrapperStale.find('textarea').setValue('Motivo válido reembolso');
    expect((wrapperStale.get('[data-testid="refund-confirm-btn"]').element as HTMLButtonElement).disabled).toBe(true);
  });
});

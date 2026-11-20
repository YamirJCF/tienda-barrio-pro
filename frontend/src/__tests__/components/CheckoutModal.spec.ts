import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { setActivePinia, createPinia } from 'pinia';
import CheckoutModal from '../../components/sales/CheckoutModal.vue';
import { useClientsStore } from '../../stores/clients';
import { useConfigStore } from '../../stores/config';
import { useAuthStore } from '../../stores/auth';
import {
  clientRepository,
  type ClientPageParams,
  type PaginatedClientsResult,
} from '../../data/repositories/clientRepository';
import { Decimal } from 'decimal.js';
import type { Client } from '../../types';

const mockPush = vi.fn();
vi.mock('vue-router', () => ({
  useRouter: () => ({
    push: mockPush,
  }),
}));

describe('CheckoutModal - Paginated 5-by-5 Fiado Client Selector', () => {
  const storeId = 'b63adadd-8679-4abc-af6c-d72ac3aa49e1';

  const makeClientsCatalog = (): Client[] => [
    {
      id: 'c-1',
      name: 'MARIA',
      cc: '1067817999',
      phone: '3107272757',
      totalDebt: new Decimal(0),
      creditLimit: new Decimal(100000),
      storeId,
    },
    {
      id: 'c-2',
      name: 'prueba',
      cc: '10567817999',
      phone: '3214380880',
      totalDebt: new Decimal(1000),
      creditLimit: new Decimal(100000),
      storeId,
    },
    ...Array.from({ length: 10 }, (_, idx) => {
      const n = idx + 3;
      return {
        id: `c-${n}`,
        name: `Cliente ${String(n).padStart(2, '0')}`,
        cc: `10000000${n}`,
        phone: `30011122${String(n).padStart(2, '0')}`,
        totalDebt: new Decimal(n % 2 === 0 ? n * 1000 : 0),
        creditLimit: new Decimal(100000),
        storeId,
      };
    }),
  ];

  const filterAndSliceDataset = (
    dataset: Client[],
    params: ClientPageParams
  ): PaginatedClientsResult => {
    const q = (params.search || '').trim().toLowerCase();
    const filtered = dataset.filter((c) => {
      if (q) {
        const hit =
          c.name.toLowerCase().includes(q) ||
          c.cc.toLowerCase().includes(q) ||
          (c.phone || '').toLowerCase().includes(q);
        if (!hit) return false;
      }
      if (params.debtFilter === 'with_debt') return c.totalDebt.gt(0);
      if (params.debtFilter === 'up_to_date') return c.totalDebt.lte(0);
      return true;
    });
    const limit = params.limit ?? 5;
    const offset = params.offset ?? 0;
    return {
      data: filtered.slice(offset, offset + limit),
      count: filtered.length,
    };
  };

  beforeEach(() => {
    setActivePinia(createPinia());
    vi.restoreAllMocks();
    vi.clearAllMocks();
  });

  const setupStores = (dataset: Client[] = makeClientsCatalog()) => {
    const clientsStore = useClientsStore();
    const configStore = useConfigStore();
    const authStore = useAuthStore();

    authStore.currentUser = {
      id: 'usr-1',
      name: 'Owner',
      email: 'owner@test.com',
      type: 'admin',
      storeId,
    } as any;

    configStore.paymentMethods = [
      { code: 'cash', name: 'Efectivo', isActive: true, allowsChange: true, requiresReference: false, sortOrder: 1 },
      { code: 'fiado', name: 'Fiado / Crédito', isActive: true, allowsChange: false, requiresReference: false, sortOrder: 2 },
    ];

    clientsStore.clients = [];
    const paginatedSpy = vi
      .spyOn(clientRepository, 'getPaginated')
      .mockImplementation(async (params) => filterAndSliceDataset(dataset, params));
    const initSpy = vi.spyOn(clientsStore, 'initialize').mockResolvedValue(undefined as any);
    const fetchPageSpy = vi.spyOn(clientsStore, 'fetchClientsPage');

    return { clientsStore, configStore, authStore, paginatedSpy, initSpy, fetchPageSpy, dataset };
  };

  const mountModal = (propsOverride: Record<string, any> = {}) => {
    return mount(CheckoutModal, {
      props: {
        modelValue: true,
        total: new Decimal(1200),
        ...propsOverride,
      },
      global: {
        stubs: {
          teleport: true,
        },
      },
    });
  };

  const switchToFiadoTab = async (wrapper: ReturnType<typeof mountModal>) => {
    const fiadoTab = wrapper.findAll('button').find((b) => b.text().includes('Fiado'));
    expect(fiadoTab).toBeDefined();
    await fiadoTab!.trigger('click');
    await flushPromises();
  };

  it('requests only 5 clients on Fiado tab without calling initialize/getAll and renders complete compact card details', async () => {
    const { initSpy, fetchPageSpy, clientsStore } = setupStores();
    const wrapper = mountModal();

    // Opening in Cash must not load any clients at all
    expect(initSpy).not.toHaveBeenCalled();
    expect(fetchPageSpy).not.toHaveBeenCalled();

    await switchToFiadoTab(wrapper);

    expect(initSpy).not.toHaveBeenCalled();
    expect(fetchPageSpy).toHaveBeenCalledTimes(1);
    expect(fetchPageSpy).toHaveBeenCalledWith({
      storeId,
      limit: 5,
      offset: 0,
      search: '',
      debtFilter: 'all',
    });

    // Only 5 clients in store & rendered out of 12 total
    expect(clientsStore.clients.length).toBe(5);
    const cards = wrapper.findAll('[data-testid="fiado-client-card"]');
    expect(cards.length).toBe(5);
    expect(wrapper.text()).toContain('5 de 12');

    // Compact cards render complete client info
    const mariaText = cards[0].text();
    expect(mariaText).toContain('MA');
    expect(mariaText).toContain('MARIA');
    expect(mariaText).toContain('CC: 1067817999');
    expect(mariaText).toContain('Tel: 3107272757');
    expect(mariaText).toContain('Cupo: $100.000');
    expect(mariaText).toContain('Deuda: $0');

    const pruebaText = cards[1].text();
    expect(pruebaText).toContain('PR');
    expect(pruebaText).toContain('prueba');
    expect(pruebaText).toContain('Deuda: $1.000');
  });

  it('loads subsequent batches strictly 5 by 5 via load-more button and scroll', async () => {
    const { fetchPageSpy, clientsStore } = setupStores(); // 12 total clients
    const wrapper = mountModal();

    await switchToFiadoTab(wrapper);
    expect(wrapper.findAll('[data-testid="fiado-client-card"]').length).toBe(5);
    expect(wrapper.text()).toContain('5 de 12');

    // 2nd request via button -> offset 5, limit 5 (5 + 5 = 10 of 12)
    const loadMoreBtn = wrapper.find('[data-testid="load-more-clients-btn"]');
    expect(loadMoreBtn.exists()).toBe(true);
    expect(loadMoreBtn.text()).toContain('Cargar más clientes (7 restantes)');
    await loadMoreBtn.trigger('click');
    await flushPromises();

    expect(fetchPageSpy).toHaveBeenNthCalledWith(2, {
      storeId,
      limit: 5,
      offset: 5,
      search: '',
      debtFilter: 'all',
    });
    expect(wrapper.findAll('[data-testid="fiado-client-card"]').length).toBe(10);
    expect(clientsStore.clients.length).toBe(10);
    expect(wrapper.text()).toContain('10 de 12');

    // 3rd request via scroll near bottom -> offset 10, limit 5 (remaining 2 -> 12 of 12)
    const listEl = wrapper.find('[data-testid="fiado-client-list"]').element as HTMLElement;
    Object.defineProperty(listEl, 'scrollHeight', { value: 600, configurable: true });
    Object.defineProperty(listEl, 'clientHeight', { value: 200, configurable: true });
    Object.defineProperty(listEl, 'scrollTop', { value: 390, configurable: true });

    await wrapper.find('[data-testid="fiado-client-list"]').trigger('scroll');
    await flushPromises();

    expect(fetchPageSpy).toHaveBeenNthCalledWith(3, {
      storeId,
      limit: 5,
      offset: 10,
      search: '',
      debtFilter: 'all',
    });
    expect(wrapper.findAll('[data-testid="fiado-client-card"]').length).toBe(12);
    expect(wrapper.text()).toContain('12 de 12');
    expect(wrapper.find('[data-testid="load-more-clients-btn"]').exists()).toBe(false);
  });

  it('triggers a fresh offset=0 paginated query when searching and omits debt filter chips', async () => {
    const { fetchPageSpy } = setupStores();
    const wrapper = mountModal();

    await switchToFiadoTab(wrapper);
    fetchPageSpy.mockClear();

    // Filter chips must not exist
    const buttonTexts = wrapper.findAll('button').map((b) => b.text().trim());
    expect(buttonTexts).not.toContain('Todos');
    expect(buttonTexts).not.toContain('Con Deuda');
    expect(buttonTexts).not.toContain('Al Día');

    // Search by name
    const searchInput = wrapper.find('input[aria-label*="Buscar cliente"]');
    await searchInput.setValue('Cliente');
    await flushPromises();

    expect(fetchPageSpy).toHaveBeenLastCalledWith({
      storeId,
      limit: 5,
      offset: 0,
      search: 'Cliente',
      debtFilter: 'all',
    });
    expect(wrapper.findAll('[data-testid="fiado-client-card"]').length).toBe(5);
    expect(wrapper.text()).toContain('5 de 10');

    // Clear search
    await wrapper.find('button[aria-label="Limpiar búsqueda"]').trigger('click');
    await flushPromises();

    expect(fetchPageSpy).toHaveBeenLastCalledWith({
      storeId,
      limit: 5,
      offset: 0,
      search: '',
      debtFilter: 'all',
    });
    expect(wrapper.findAll('[data-testid="fiado-client-card"]').length).toBe(5);
    expect(wrapper.text()).toContain('5 de 12');
  });

  it('selects client, navigates to detail on selected name click, omits Nota de Fiado, allows Cambiar, and emits complete', async () => {
    const dataset = makeClientsCatalog();
    const { fetchPageSpy } = setupStores(dataset);
    const wrapper = mountModal({ total: new Decimal(120000) }); // Exceeds MARIA's creditLimit

    await switchToFiadoTab(wrapper);

    // Before selecting client, no detail navigation link nor Nota de Fiado box exists, and clicking a card does not navigate
    expect(wrapper.find('[data-testid="selected-client-name-link"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="fiado-note-field"]').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Nota de Fiado');
    await wrapper.findAll('[data-testid="fiado-client-card"]')[0].trigger('click');
    expect(mockPush).not.toHaveBeenCalled();

    // Summary card shows selected client & credit limit warning without Nota de Fiado box
    expect(wrapper.text()).toContain('Cliente Seleccionado');
    expect(wrapper.text()).toContain('superará el cupo disponible');
    expect(wrapper.find('[data-testid="fiado-note-field"]').exists()).toBe(false);
    expect(wrapper.text()).not.toContain('Nota de Fiado');

    // Clicking selected client name navigates to detail view
    const nameLink = wrapper.find('[data-testid="selected-client-name-link"]');
    await nameLink.trigger('click');
    expect(wrapper.emitted('update:modelValue')?.[0]).toEqual([false]);
    expect(mockPush).toHaveBeenCalledWith({
      path: '/clients/c-1',
      query: { from: 'pos' },
    });

    // Returning via Cambiar shows inline paginated list without Nota de Fiado
    const changeBtn = wrapper.findAll('button').find((b) => b.text().includes('Cambiar'));
    await changeBtn!.trigger('click');
    expect(wrapper.find('input[aria-label*="Buscar cliente"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="fiado-note-field"]').exists()).toBe(false);

    // Re-select and confirm sale
    await wrapper.findAll('[data-testid="fiado-client-card"]')[0].trigger('click');
    const confirmBtn = wrapper.findAll('button').find((b) => b.text().includes('CONFIRMAR'));
    await confirmBtn!.trigger('click');

    expect(wrapper.emitted('complete')).toBeDefined();
    expect(wrapper.emitted('complete')![0][0]).toEqual([
      expect.objectContaining({
        method: 'fiado',
      }),
    ]);
    expect(wrapper.emitted('complete')![0][2]).toBe('c-1');

    // Opening directly on fiado with selectedClient doesn't fetch list until Cambiar is pressed
    fetchPageSpy.mockClear();
    const restoredWrapper = mountModal({
      selectedClient: dataset[0],
      initialMethod: 'fiado',
    });
    await flushPromises();
    expect(fetchPageSpy).not.toHaveBeenCalled();
    expect(restoredWrapper.find('[data-testid="selected-client-name-link"]').exists()).toBe(true);

    const restoredChangeBtn = restoredWrapper.findAll('button').find((b) => b.text().includes('Cambiar'));
    await restoredChangeBtn!.trigger('click');
    await flushPromises();
    expect(fetchPageSpy).toHaveBeenCalledWith({
      storeId,
      limit: 5,
      offset: 0,
      search: '',
      debtFilter: 'all',
    });
  });

  it('shows explicit loading and error states with Reintentar instead of silent empty fallback', async () => {
    const { clientsStore } = setupStores([]);
    let rejectFirst!: (err: Error) => void;
    let attempt = 0;

    vi.spyOn(clientsStore, 'fetchClientsPage').mockImplementation(async () => {
      attempt++;
      if (attempt === 1) {
        return new Promise<PaginatedClientsResult>((_, reject) => {
          rejectFirst = reject;
        });
      }
      return { data: makeClientsCatalog().slice(0, 5), count: 5 };
    });

    const wrapper = mountModal();
    const fiadoTab = wrapper.findAll('button').find((b) => b.text().includes('Fiado'));
    await fiadoTab!.trigger('click');

    // While pending, loading indicator renders explicitly
    expect(wrapper.text()).toContain('Cargando clientes...');

    // When request fails, error message and Reintentar render explicitly
    rejectFirst(new Error('Error de red al consultar clientes'));
    await flushPromises();

    expect(wrapper.text()).toContain('Error de red al consultar clientes');
    const retryBtn = wrapper.findAll('button').find((b) => b.text().includes('Reintentar'));
    expect(retryBtn).toBeDefined();

    await retryBtn!.trigger('click');
    await flushPromises();
    expect(wrapper.findAll('[data-testid="fiado-client-card"]').length).toBe(5);
  });

  it('excludes unauthorized payment method code "card" (Tarjeta Débito/Crédito) even if present in persisted config state', () => {
    const { configStore } = setupStores();

    configStore.paymentMethods = [
      { id: '1', code: 'cash', name: 'Efectivo', isActive: true, allowsChange: true, requiresReference: false, sortOrder: 10 },
      { id: '2', code: 'nequi', name: 'Nequi', isActive: true, allowsChange: false, requiresReference: true, sortOrder: 20 },
      { id: '3', code: 'fiado', name: 'Fiado / Crédito', isActive: true, allowsChange: false, requiresReference: false, sortOrder: 30 },
      { id: '4', code: 'card', name: 'Tarjeta Débito/Crédito', isActive: true, allowsChange: false, requiresReference: true, sortOrder: 40 },
    ];

    expect(configStore.activePaymentMethods.map((m) => m.code)).toEqual(['cash', 'nequi', 'fiado']);

    const wrapper = mountModal();
    expect(wrapper.text()).toContain('Efectivo');
    expect(wrapper.text()).toContain('Nequi');
    expect(wrapper.text()).toContain('Fiado / Crédito');
    expect(wrapper.text()).not.toContain('Tarjeta Débito/Crédito');
  });
});

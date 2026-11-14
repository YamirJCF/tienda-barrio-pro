import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { setActivePinia, createPinia } from 'pinia';
import CheckoutModal from '../../components/sales/CheckoutModal.vue';
import { useClientsStore } from '../../stores/clients';
import { useConfigStore } from '../../stores/config';
import { useAuthStore } from '../../stores/auth';
import { Decimal } from 'decimal.js';
import type { Client } from '../../types';

describe('CheckoutModal - Inline Compact Fiado Client Selector & Progressive Loading', () => {
  const storeId = 'b63adadd-8679-4abc-af6c-d72ac3aa49e1';

  const mockClients: Client[] = [
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
    {
      id: 'c-3',
      name: 'Carlos Mendoza',
      cc: '80112233',
      phone: '3001112233',
      totalDebt: new Decimal(25000),
      creditLimit: new Decimal(80000),
      storeId,
    },
    {
      id: 'c-4',
      name: 'Ana Lucía Gómez',
      cc: '52998877',
      phone: '3112223344',
      totalDebt: new Decimal(0),
      creditLimit: new Decimal(50000),
      storeId,
    },
    {
      id: 'c-5',
      name: 'Pedro Ramírez',
      cc: '79445566',
      phone: '3159998877',
      totalDebt: new Decimal(15000),
      creditLimit: new Decimal(60000),
      storeId,
    },
    {
      id: 'c-6',
      name: 'Laura Torres',
      cc: '1012345678',
      phone: '3204445566',
      totalDebt: new Decimal(0),
      creditLimit: new Decimal(120000),
      storeId,
    },
  ];

  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  const setupStores = (clientsOverride?: Client[]) => {
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

    clientsStore.clients = clientsOverride ? [...clientsOverride] : [...mockClients.slice(0, 2)];
    return { clientsStore, configStore, authStore };
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
  };

  it('renders inline search input, filters, and compact client cards immediately on Fiado tab (zero extra clicks)', async () => {
    setupStores();
    const wrapper = mountModal();

    await switchToFiadoTab(wrapper);

    // Inline search input must be directly present (no modal button to open search)
    const searchInput = wrapper.find('input[aria-label*="Buscar cliente"]');
    expect(searchInput.exists()).toBe(true);
    expect(wrapper.text()).not.toContain('Seleccionar Cliente de Cartera');

    // Filter chips visible
    expect(wrapper.text()).toContain('Todos');
    expect(wrapper.text()).toContain('Con Deuda');
    expect(wrapper.text()).toContain('Al Día');

    // Compact cards render all required info
    const cards = wrapper.findAll('[data-testid="fiado-client-card"]');
    expect(cards.length).toBe(2);

    const mariaCardText = cards[0].text();
    expect(mariaCardText).toContain('MA');
    expect(mariaCardText).toContain('MARIA');
    expect(mariaCardText).toContain('CC: 1067817999');
    expect(mariaCardText).toContain('Tel: 3107272757');
    expect(mariaCardText).toContain('Cupo: $100.000');
    expect(mariaCardText).toContain('Deuda: $0');

    const pruebaCardText = cards[1].text();
    expect(pruebaCardText).toContain('PR');
    expect(pruebaCardText).toContain('prueba');
    expect(pruebaCardText).toContain('CC: 10567817999');
    expect(pruebaCardText).toContain('Tel: 3214380880');
    expect(pruebaCardText).toContain('Cupo: $100.000');
    expect(pruebaCardText).toContain('Deuda: $1.000');
  });

  it('filters clients in real-time by search query and status filter chips', async () => {
    setupStores(mockClients);
    const wrapper = mountModal();

    await switchToFiadoTab(wrapper);

    // Search by phone / name / CC
    const searchInput = wrapper.find('input[aria-label*="Buscar cliente"]');
    await searchInput.setValue('Carlos');

    let cards = wrapper.findAll('[data-testid="fiado-client-card"]');
    expect(cards.length).toBe(1);
    expect(cards[0].text()).toContain('Carlos Mendoza');

    // Clear search button restores list
    const clearBtn = wrapper.find('button[aria-label="Limpiar búsqueda"]');
    expect(clearBtn.exists()).toBe(true);
    await clearBtn.trigger('click');

    // Filter by "Con Deuda" (clients c-2, c-3, c-5 -> 3 clients)
    const debtFilterBtn = wrapper.findAll('button').find((b) => b.text().trim() === 'Con Deuda');
    expect(debtFilterBtn).toBeDefined();
    await debtFilterBtn!.trigger('click');

    cards = wrapper.findAll('[data-testid="fiado-client-card"]');
    expect(cards.length).toBe(3);
    expect(cards.map((c) => c.text()).join(' ')).toContain('prueba');
    expect(cards.map((c) => c.text()).join(' ')).toContain('Carlos Mendoza');
    expect(cards.map((c) => c.text()).join(' ')).toContain('Pedro Ramírez');

    // Filter by "Al Día" (clients c-1, c-4, c-6 -> 3 clients)
    const upToDateBtn = wrapper.findAll('button').find((b) => b.text().trim() === 'Al Día');
    await upToDateBtn!.trigger('click');

    cards = wrapper.findAll('[data-testid="fiado-client-card"]');
    expect(cards.length).toBe(3);
    expect(cards.map((c) => c.text()).join(' ')).toContain('MARIA');
    expect(cards.map((c) => c.text()).join(' ')).toContain('Ana Lucía Gómez');
  });

  it('progressively loads only 4 initial clients and loads remaining clients via button or scroll', async () => {
    setupStores(mockClients); // 6 clients
    const wrapper = mountModal();

    await switchToFiadoTab(wrapper);

    // Initially only 4 clients rendered to fit viewport cleanly
    expect(wrapper.findAll('[data-testid="fiado-client-card"]').length).toBe(4);
    expect(wrapper.text()).toContain('4 de 6');

    const loadMoreBtn = wrapper.find('[data-testid="load-more-clients-btn"]');
    expect(loadMoreBtn.exists()).toBe(true);
    expect(loadMoreBtn.text()).toContain('Ver más clientes (2 restantes)');

    // Clicking load more renders all 6 clients
    await loadMoreBtn.trigger('click');
    expect(wrapper.findAll('[data-testid="fiado-client-card"]').length).toBe(6);
    expect(wrapper.text()).toContain('6 de 6');
    expect(wrapper.find('[data-testid="load-more-clients-btn"]').exists()).toBe(false);

    // Reset filter/search resets back to 4 visible, then test scroll trigger
    const searchInput = wrapper.find('input[aria-label*="Buscar cliente"]');
    await searchInput.setValue('MARIA');
    await searchInput.setValue('');
    expect(wrapper.findAll('[data-testid="fiado-client-card"]').length).toBe(4);

    const listEl = wrapper.find('[data-testid="fiado-client-list"]').element as HTMLElement;
    Object.defineProperty(listEl, 'scrollTop', { value: 300, configurable: true });
    Object.defineProperty(listEl, 'clientHeight', { value: 200, configurable: true });
    Object.defineProperty(listEl, 'scrollHeight', { value: 500, configurable: true });

    await wrapper.find('[data-testid="fiado-client-list"]').trigger('scroll');
    expect(wrapper.findAll('[data-testid="fiado-client-card"]').length).toBe(6);
  });

  it('selects a client from inline list, allows switching back with Cambiar, and completes transaction', async () => {
    setupStores();
    const wrapper = mountModal({ total: new Decimal(120000) }); // Exceeds MARIA's creditLimit (100.000)

    await switchToFiadoTab(wrapper);

    // Select MARIA directly from inline list
    const mariaCard = wrapper.findAll('[data-testid="fiado-client-card"]')[0];
    await mariaCard.trigger('click');

    // Summary card is shown with credit limit warning
    expect(wrapper.text()).toContain('Cliente Seleccionado');
    expect(wrapper.text()).toContain('MARIA');
    expect(wrapper.text()).toContain('superará el cupo disponible');

    // Clicking "Cambiar" immediately brings back the inline list
    const changeBtn = wrapper.findAll('button').find((b) => b.text().includes('Cambiar'));
    expect(changeBtn).toBeDefined();
    await changeBtn!.trigger('click');
    expect(wrapper.find('input[aria-label*="Buscar cliente"]').exists()).toBe(true);

    // Select MARIA again and confirm sale
    await wrapper.findAll('[data-testid="fiado-client-card"]')[0].trigger('click');

    const confirmBtn = wrapper.findAll('button').find((b) => b.text().includes('CONFIRMAR'));
    expect(confirmBtn).toBeDefined();
    await confirmBtn!.trigger('click');

    expect(wrapper.emitted('complete')).toBeDefined();
    const emitArgs = wrapper.emitted('complete')![0];
    expect(emitArgs[2]).toBe(mockClients[0].id);
  });

  it('shows explicit loading and error states instead of silent empty fallback', async () => {
    const { clientsStore } = setupStores([]);
    vi.spyOn(clientsStore, 'initialize').mockResolvedValue(undefined as any);
    clientsStore.isLoading = true;

    const wrapper = mountModal();
    await switchToFiadoTab(wrapper);
    expect(wrapper.text()).toContain('Cargando clientes...');

    // Simulate load failure with empty clients
    clientsStore.isLoading = false;
    clientsStore.error = 'Error al cargar clientes';
    await wrapper.vm.$nextTick();

    expect(wrapper.text()).toContain('Error al cargar clientes');
    const retryBtn = wrapper.findAll('button').find((b) => b.text().includes('Reintentar'));
    expect(retryBtn).toBeDefined();
    await retryBtn!.trigger('click');
    expect(clientsStore.initialize).toHaveBeenCalledWith(storeId, true);
  });

  it('triggers clientsStore.initialize when clients array is empty on modal open', async () => {
    const { clientsStore } = setupStores([]);
    const initSpy = vi.spyOn(clientsStore, 'initialize').mockResolvedValue(undefined as any);

    const wrapper = mountModal({ modelValue: false });

    await wrapper.setProps({ modelValue: true });
    await wrapper.vm.$nextTick();
    expect(initSpy).toHaveBeenCalledWith(storeId);
  });
});

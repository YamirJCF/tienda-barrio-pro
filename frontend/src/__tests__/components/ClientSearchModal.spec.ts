import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { setActivePinia, createPinia } from 'pinia';
import ClientSearchModal from '../../components/sales/ClientSearchModal.vue';
import { useClientsStore } from '../../stores/clients';
import { Decimal } from 'decimal.js';
import type { Client } from '../../types';

describe('ClientSearchModal Component', () => {
  const mockClients: Client[] = [
    {
      id: '5bdeeed8-e25a-49e1-bc1f-ee7bba2ecd21',
      name: 'MARIA',
      cc: '1067817999',
      phone: '3107272757',
      totalDebt: new Decimal(0),
      creditLimit: new Decimal(100000),
      storeId: 'b63adadd-8679-4abc-af6c-d72ac3aa49e1',
    },
    {
      id: '271d7fb4-c0c5-4749-a9f5-cf9ee24ef09a',
      name: 'Don Jairo',
      cc: '10567817999',
      phone: '3214380880',
      totalDebt: new Decimal(25000),
      creditLimit: new Decimal(80000),
      storeId: 'b63adadd-8679-4abc-af6c-d72ac3aa49e1',
    },
  ];

  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  it('renders all clients initially and displays financial details', () => {
    const clientsStore = useClientsStore();
    clientsStore.clients = [...mockClients];

    const wrapper = mount(ClientSearchModal, {
      props: {
        modelValue: true,
      },
      global: {
        stubs: {
          teleport: true,
        },
      },
    });

    expect(wrapper.text()).toContain('Seleccionar Cliente para Fiado');
    expect(wrapper.text()).toContain('MARIA');
    expect(wrapper.text()).toContain('Don Jairo');
    expect(wrapper.text()).toContain('Cupo Límite');
    expect(wrapper.text()).toContain('Deuda Actual');
  });

  it('filters clients in real time when typing into search box', async () => {
    const clientsStore = useClientsStore();
    clientsStore.clients = [...mockClients];

    const wrapper = mount(ClientSearchModal, {
      props: {
        modelValue: true,
      },
      global: {
        stubs: {
          teleport: true,
        },
      },
    });

    const searchInput = wrapper.find('input[type="text"]');
    expect(searchInput.exists()).toBe(true);

    // Type 'MARIA'
    await searchInput.setValue('MARIA');
    expect(wrapper.text()).toContain('MARIA');
    expect(wrapper.text()).not.toContain('Don Jairo');

    // Type non-existent query -> shows friendly empty state
    await searchInput.setValue('xyz123');
    expect(wrapper.text()).toContain('Sin resultados para "xyz123"');
    expect(wrapper.text()).toContain('Intenta buscar por otro término o cédula');
  });

  it('filters by status chips (Con Deuda / Al Día)', async () => {
    const clientsStore = useClientsStore();
    clientsStore.clients = [...mockClients];

    const wrapper = mount(ClientSearchModal, {
      props: {
        modelValue: true,
      },
      global: {
        stubs: {
          teleport: true,
        },
      },
    });

    // Click "Con Deuda" chip
    const withDebtChip = wrapper.findAll('button').find(b => b.text().includes('Con Deuda'));
    expect(withDebtChip).toBeDefined();
    await withDebtChip!.trigger('click');

    expect(wrapper.text()).toContain('Don Jairo');
    expect(wrapper.text()).not.toContain('MARIA');

    // Click "Al Día" chip
    const upToDateChip = wrapper.findAll('button').find(b => b.text().includes('Al Día'));
    expect(upToDateChip).toBeDefined();
    await upToDateChip!.trigger('click');

    expect(wrapper.text()).toContain('MARIA');
    expect(wrapper.text()).not.toContain('Don Jairo');
  });

  it('emits select event and closes modal when client card is clicked', async () => {
    const clientsStore = useClientsStore();
    clientsStore.clients = [...mockClients];

    const wrapper = mount(ClientSearchModal, {
      props: {
        modelValue: true,
      },
      global: {
        stubs: {
          teleport: true,
        },
      },
    });

    const mariaCard = wrapper.findAll('.cursor-pointer').find(el => el.text().includes('MARIA'));
    expect(mariaCard).toBeDefined();
    await mariaCard!.trigger('click');

    expect(wrapper.emitted('select')).toBeDefined();
    expect(wrapper.emitted('select')![0][0]).toEqual(mockClients[0]);
    expect(wrapper.emitted('update:modelValue')![0][0]).toBe(false);
  });

  it('shows loading spinner when clientsStore is loading', () => {
    const clientsStore = useClientsStore();
    clientsStore.isLoading = true;

    const wrapper = mount(ClientSearchModal, {
      props: {
        modelValue: true,
      },
      global: {
        stubs: {
          teleport: true,
        },
      },
    });

    expect(wrapper.text()).toContain('Cargando cartera de clientes...');
  });
});

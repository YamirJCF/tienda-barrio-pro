import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import { setActivePinia, createPinia } from 'pinia';
import CheckoutModal from '../../components/sales/CheckoutModal.vue';
import ClientSearchModal from '../../components/sales/ClientSearchModal.vue';
import { useClientsStore } from '../../stores/clients';
import { useConfigStore } from '../../stores/config';
import { useAuthStore } from '../../stores/auth';
import { Decimal } from 'decimal.js';
import type { Client } from '../../types';

describe('CheckoutModal - Fiado Client Selection & Dedicated Search Modal', () => {
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
      name: 'prueba',
      cc: '10567817999',
      phone: '3214380880',
      totalDebt: new Decimal(1000),
      creditLimit: new Decimal(100000),
      storeId: 'b63adadd-8679-4abc-af6c-d72ac3aa49e1',
    },
  ];

  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  const setupStores = () => {
    const clientsStore = useClientsStore();
    const configStore = useConfigStore();
    const authStore = useAuthStore();

    authStore.currentUser = {
      id: 'usr-1',
      name: 'Owner',
      email: 'owner@test.com',
      type: 'admin',
      storeId: 'b63adadd-8679-4abc-af6c-d72ac3aa49e1',
    } as any;

    configStore.paymentMethods = [
      { code: 'cash', name: 'Efectivo', isActive: true, allowsChange: true, requiresReference: false, sortOrder: 1 },
      { code: 'fiado', name: 'Fiado / Crédito', isActive: true, allowsChange: false, requiresReference: false, sortOrder: 2 },
    ];

    clientsStore.clients = [...mockClients];
    return { clientsStore, configStore, authStore };
  };

  it('renders client selection trigger button when fiado is selected with no initial client', async () => {
    setupStores();

    const wrapper = mount(CheckoutModal, {
      props: {
        modelValue: true,
        total: new Decimal(1200),
      },
      global: {
        stubs: {
          teleport: true,
        },
      },
    });

    // Switch to fiado
    const fiadoTab = wrapper.findAll('button').find((b) => b.text().includes('Fiado'));
    expect(fiadoTab).toBeDefined();
    await fiadoTab!.trigger('click');

    // Trigger button should be visible
    const triggerBtn = wrapper.find('button.border-dashed');
    expect(triggerBtn.exists()).toBe(true);
    expect(triggerBtn.text()).toContain('Seleccionar Cliente de Cartera');

    // Clicking trigger opens ClientSearchModal
    await triggerBtn.trigger('click');
    const searchModal = wrapper.findComponent(ClientSearchModal);
    expect(searchModal.exists()).toBe(true);
    expect(searchModal.props('modelValue')).toBe(true);
  });

  it('displays client card and allows changing client', async () => {
    setupStores();

    const wrapper = mount(CheckoutModal, {
      props: {
        modelValue: true,
        total: new Decimal(1200),
        selectedClient: mockClients[0],
      },
      global: {
        stubs: {
          teleport: true,
        },
      },
    });

    // Switch to fiado
    const fiadoTab = wrapper.findAll('button').find((b) => b.text().includes('Fiado'));
    await fiadoTab!.trigger('click');

    // Client card should show MARIA
    expect(wrapper.text()).toContain('MARIA');
    expect(wrapper.text()).toContain('CC: 1067817999');
    expect(wrapper.text()).toContain('Cliente para Crédito');

    // Click "Cambiar" button opens search modal
    const changeBtn = wrapper.findAll('button').find(b => b.text().includes('Cambiar'));
    expect(changeBtn).toBeDefined();
    await changeBtn!.trigger('click');

    const searchModal = wrapper.findComponent(ClientSearchModal);
    expect(searchModal.props('modelValue')).toBe(true);
  });

  it('completes transaction with selected client id', async () => {
    setupStores();

    const wrapper = mount(CheckoutModal, {
      props: {
        modelValue: true,
        total: new Decimal(1200),
        selectedClient: mockClients[0],
      },
      global: {
        stubs: {
          teleport: true,
        },
      },
    });

    // Switch to fiado
    const fiadoTab = wrapper.findAll('button').find((b) => b.text().includes('Fiado'));
    await fiadoTab!.trigger('click');

    // Confirm button should be enabled
    const confirmBtn = wrapper.findAll('button').find(b => b.text().includes('CONFIRMAR'));
    expect(confirmBtn).toBeDefined();
    await confirmBtn!.trigger('click');

    expect(wrapper.emitted('complete')).toBeDefined();
    const emitArgs = wrapper.emitted('complete')![0];
    expect(emitArgs[2]).toBe(mockClients[0].id); // clientId emitted correctly
  });

  it('triggers clientsStore.initialize when clients array is empty', async () => {
    const { clientsStore } = setupStores();
    clientsStore.clients = [];
    const initSpy = vi.spyOn(clientsStore, 'initialize').mockResolvedValue(undefined as any);

    const wrapper = mount(CheckoutModal, {
      props: {
        modelValue: false,
        total: new Decimal(1200),
      },
      global: {
        stubs: {
          teleport: true,
        },
      },
    });

    await wrapper.setProps({ modelValue: true });
    await wrapper.vm.$nextTick();
    expect(initSpy).toHaveBeenCalledWith('b63adadd-8679-4abc-af6c-d72ac3aa49e1');
  });
});

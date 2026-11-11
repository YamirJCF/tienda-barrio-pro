import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { Decimal } from 'decimal.js';

const { mockRpc, mockState } = vi.hoisted(() => ({
  mockRpc: vi.fn(),
  mockState: { configured: true },
}));

vi.mock('../../data/supabaseClient', () => ({
  isSupabaseConfigured: () => mockState.configured,
  getSupabaseClient: () =>
    mockState.configured
      ? {
          rpc: mockRpc,
          from: vi.fn(),
          auth: {
            getUser: vi.fn(),
            signInAnonymously: vi.fn(),
            signOut: vi.fn(),
          },
        }
      : null,
  requireSupabase: () => ({
    rpc: mockRpc,
    auth: {
      getUser: vi.fn(),
      signInAnonymously: vi.fn(),
      signOut: vi.fn(),
    },
  }),
  isAuditMode: () => false,
}));

const mockShowError = vi.fn();
const mockShowSuccess = vi.fn();
const mockShowWarning = vi.fn();
vi.mock('../../composables/useNotifications', () => ({
  useNotifications: () => ({
    showError: mockShowError,
    showSuccess: mockShowSuccess,
    showWarning: mockShowWarning,
    showInfo: vi.fn(),
  }),
}));

import { clientRepository, ClientRepositoryError } from '../../data/repositories/clientRepository';
import { useClientsStore } from '../../stores/clients';
import { useAuthStore } from '../../stores/auth';
import { useConfigStore } from '../../stores/config';
import CheckoutModal from '../../components/sales/CheckoutModal.vue';
import ClientFormModal from '../../components/ClientFormModal.vue';

describe('SDD-030 — Ciclo de Vida Opaco en Cartera y Exención Contado', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    localStorage.clear();
    mockState.configured = true;
    Object.defineProperty(navigator, 'onLine', { value: true, configurable: true });
  });

  describe('clientRepository RPC enforcement', () => {
    it('bloquea alta offline sin encolar ni crear cliente falso (FRD-029 E2)', async () => {
      Object.defineProperty(navigator, 'onLine', { value: false, configurable: true });

      await expect(
        clientRepository.create({
          name: 'Ana Perez',
          cc: '101010',
          totalDebt: new Decimal(0),
          creditLimit: new Decimal(50000),
          storeId: '11111111-1111-4111-8111-111111111111',
        })
      ).rejects.toMatchObject({ code: 'OFFLINE' });

      expect(mockRpc).not.toHaveBeenCalled();
    });

    it('invoca rpc_crear_cliente_fiado y conserva saldo en reactivación silenciosa (FRD-030 RN-05)', async () => {
      mockRpc.mockResolvedValueOnce({
        data: {
          success: true,
          data: {
            client: {
              id: 'cli-reactivated',
              store_id: '11111111-1111-4111-8111-111111111111',
              name: 'Beto Reactivado',
              id_number: '1000002',
              phone: '3110000000',
              credit_limit: 90000,
              balance: 0,
              created_at: '2026-01-01T00:00:00Z',
              updated_at: '2026-11-11T12:00:00Z',
            },
            confirmation_id: 'conf-99',
            confirmed_at: '2026-11-11T12:00:00Z',
          },
        },
        error: null,
      });

      const store = useClientsStore();
      const created = await store.addClient({
        name: 'Beto Reactivado',
        cc: '1000002',
        phone: '3110000000',
        creditLimit: new Decimal(90000),
        storeId: '11111111-1111-4111-8111-111111111111',
      });

      expect(mockRpc).toHaveBeenCalledWith('rpc_crear_cliente_fiado', {
        p_store_id: '11111111-1111-4111-8111-111111111111',
        p_name: 'Beto Reactivado',
        p_id_number: '1000002',
        p_phone: '3110000000',
        p_credit_limit: 90000,
      });
      expect(created?.id).toBe('cli-reactivated');
      expect(store.clients).toHaveLength(1);
    });

    it('rechaza eliminación con deuda (CLIENT_HAS_DEBT) desde servidor sin borrar en tienda', async () => {
      mockRpc.mockResolvedValueOnce({
        data: null,
        error: { message: 'CLIENT_HAS_DEBT: Saldo $20000', code: 'P0001' },
      });

      const store = useClientsStore();
      store.clients = [
        {
          id: 'cli-debt',
          name: 'Deudor',
          cc: '555',
          totalDebt: new Decimal(0), // Aunque caché esté desactualizado a $0, servidor manda
          creditLimit: new Decimal(100000),
          storeId: 'store-1',
        },
      ];

      const result = await store.deleteClient('cli-debt');
      expect(result.success).toBe(false);
      expect(result.code).toBe('CLIENT_HAS_DEBT');
      expect(store.clients).toHaveLength(1);
    });

    it('consulta estado de cuenta vía rpc_obtener_estado_cuenta_cliente preservando montos y signos exactos', async () => {
      mockRpc.mockResolvedValueOnce({
        data: {
          success: true,
          count: 2,
          data: {
            client: {
              id: 'cli-1',
              name: 'Maria',
              id_number: '12345',
              phone: '3001112233',
              credit_limit: 100000,
              balance: 5000,
              credit_available: 95000,
            },
            movements: [
              {
                id: 'm2',
                transaction_type: 'abono',
                amount: -15000,
                previous_balance: 20000,
                new_balance: 5000,
                reference_id: null,
                ticket_number: null,
                created_at: '2026-11-11T15:00:00Z',
              },
              {
                id: 'm1',
                transaction_type: 'venta_fiado',
                amount: 20000,
                previous_balance: 0,
                new_balance: 20000,
                reference_id: 'sale-1',
                ticket_number: 42,
                created_at: '2026-11-11T14:00:00Z',
              },
            ],
            generated_at: '2026-11-11T16:00:00Z',
          },
        },
        error: null,
      });

      const stmt = await clientRepository.getStatement('cli-1');
      expect(mockRpc).toHaveBeenCalledWith('rpc_obtener_estado_cuenta_cliente', {
        p_client_id: 'cli-1',
        p_limit: 100,
        p_offset: 0,
      });
      expect(stmt.count).toBe(2);
      expect(stmt.movements[0].type).toBe('payment');
      expect(Number(stmt.movements[0].amount)).toBe(15000);
      expect(stmt.movements[0].previousBalance.toNumber()).toBe(20000);
      expect(stmt.movements[0].newBalance.toNumber()).toBe(5000);
      expect(stmt.movements[1].description).toBe('Venta Fiado #42');
    });

    it('expone ClientRepositoryError explícito si getStatement recibe CLIENT_NOT_FOUND', async () => {
      mockRpc.mockResolvedValueOnce({
        data: null,
        error: { message: 'CLIENT_NOT_FOUND', code: 'P0002' },
      });

      await expect(clientRepository.getStatement('missing')).rejects.toBeInstanceOf(
        ClientRepositoryError
      );
    });
  });

  describe('ClientFormModal.vue — Alta con confirmación directa y errores visibles', () => {
    it('no renderiza casillas adicionales (RN-14) y muestra error real del backend al duplicar cédula', async () => {
      mockRpc.mockResolvedValueOnce({
        data: null,
        error: { message: 'DUPLICATE_CLIENT_ID_NUMBER', code: '23505' },
      });

      const authStore = useAuthStore();
      authStore.currentUser = {
        id: 'adm-1',
        name: 'Admin Tienda',
        email: 'admin@tienda.co',
        type: 'admin',
        storeId: '11111111-1111-4111-8111-111111111111',
      };

      const store = useClientsStore();
      vi.spyOn(store, 'addClient').mockRejectedValueOnce(
        new ClientRepositoryError(
          'Ya existe un cliente registrado con esta cédula en la tienda.',
          'DUPLICATE_CLIENT_ID_NUMBER'
        )
      );

      const wrapper = mount(ClientFormModal, {
        props: { modelValue: true },
        global: { stubs: { Teleport: true, Transition: true } },
      });

      // RN-14: Prohibido mostrar checkboxes en creación de cliente fiado
      expect(wrapper.find('input[type="checkbox"]').exists()).toBe(false);

      const inputs = wrapper.findAll('input');
      await inputs[0].setValue('Juan Duplicado');
      await inputs[1].setValue('10203040');

      const saveBtn = wrapper.findAll('button').find((b) => b.text().includes('Guardar Cliente'))!;
      await saveBtn.trigger('click');
      await flushPromises();

      expect(wrapper.find('[role="alert"]').text()).toContain(
        'Ya existe un cliente registrado con esta cédula en la tienda.'
      );
      expect(mockShowError).toHaveBeenCalledWith(
        'Ya existe un cliente registrado con esta cédula en la tienda.'
      );
    });
  });

  describe('CheckoutModal.vue — Exención en ventas de contado (FRD-029 RN-16)', () => {
    it('no adjunta clientId al emitir complete en pago en efectivo aunque hubiera selectedClient previo', async () => {
      const configStore = useConfigStore();
      configStore.paymentMethods = [
        { id: '1', code: 'cash', name: 'Efectivo', isActive: true, allowsChange: true, requiresReference: false, sortOrder: 1 },
        { id: '2', code: 'fiado', name: 'Fiado', isActive: true, allowsChange: false, requiresReference: false, sortOrder: 2 },
      ];

      const wrapper = mount(CheckoutModal, {
        props: {
          modelValue: true,
          total: new Decimal(10000),
          selectedClient: {
            id: 'cli-previo',
            name: 'Cliente Preseleccionado',
            cc: '111222',
            totalDebt: new Decimal(0),
            creditLimit: new Decimal(50000),
            storeId: 'store-1',
          },
        },
        global: { stubs: { Teleport: true } },
      });

      // Ingresar monto en pestaña Efectivo (allowsChange)
      const exactBtn = wrapper.findAll('button').find((b) => b.text().includes('Usar monto exacto'));
      expect(exactBtn).toBeDefined();
      await exactBtn!.trigger('click');

      const confirmBtn = wrapper
        .findAll('button')
        .find((b) => b.text().includes('CONFIRMAR'))!;
      await confirmBtn.trigger('click');

      const emitted = wrapper.emitted('complete');
      expect(emitted).toBeTruthy();
      expect(emitted![0][2]).toBeUndefined();
    });
  });
});

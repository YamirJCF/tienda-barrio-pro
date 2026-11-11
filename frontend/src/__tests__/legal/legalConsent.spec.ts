import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';
import { reactive } from 'vue';

// Mock router
const mockPush = vi.fn();
const mockBack = vi.fn();
const mockRoute = reactive({ path: '/dashboard', query: {} as Record<string, any> });

vi.mock('vue-router', () => ({
  useRouter: () => ({
    push: mockPush,
    back: mockBack,
    replace: vi.fn(),
  }),
  useRoute: () => mockRoute,
}));

// Mock notifications
const mockShowError = vi.fn();
const mockShowSuccess = vi.fn();
vi.mock('../../composables/useNotifications', () => ({
  useNotifications: () => ({
    showError: mockShowError,
    showSuccess: mockShowSuccess,
    showWarning: vi.fn(),
    showInfo: vi.fn(),
  }),
}));

const { mockRpc, mockGetUser, mockState } = vi.hoisted(() => ({
  mockRpc: vi.fn(),
  mockGetUser: vi.fn(),
  mockState: { configured: true },
}));

vi.mock('../../data/supabaseClient', () => ({
  isSupabaseConfigured: () => mockState.configured,
  getSupabaseClient: () =>
    mockState.configured
      ? {
          rpc: mockRpc,
          from: vi.fn(() => ({
            select: vi.fn(() => ({
              order: vi.fn().mockResolvedValue({ data: [], error: null }),
            })),
          })),
          auth: {
            getUser: mockGetUser,
            signInWithPassword: vi.fn(),
            signOut: vi.fn(),
          },
        }
      : null,
  requireSupabase: () => ({
    rpc: mockRpc,
    auth: {
      getUser: mockGetUser,
      signInAnonymously: vi.fn(),
      signOut: vi.fn(),
    },
  }),
  isAuditMode: () => false,
}));

import { legalRepository } from '../../data/repositories/legalRepository';
import { useAuthStore } from '../../stores/auth';
import { useCartStore } from '../../stores/cart';
import RegisterStoreView from '../../views/RegisterStoreView.vue';
import LegalComplianceGate from '../../components/legal/LegalComplianceGate.vue';

const sampleCatalog = {
  terms_of_service: {
    version_id: '11111111-1111-4111-8111-111111111111',
    document_type: 'terms_of_service' as const,
    version_code: '1.0',
    change_level: 'major' as const,
    content: 'Texto íntegro de Términos y Condiciones v1.0.',
    change_summary: 'Versión inicial',
    published_at: '2026-11-11T10:00:00Z',
  },
  privacy_policy: {
    version_id: '22222222-2222-4222-8222-222222222222',
    document_type: 'privacy_policy' as const,
    version_code: '1.0',
    change_level: 'major' as const,
    content: 'Texto íntegro de Política de Tratamiento de Datos v1.0.',
    change_summary: 'Versión inicial Ley 1581',
    published_at: '2026-11-11T10:00:00Z',
  },
};

describe('SDD-029 — Legal Consentimiento Versionado', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    mockState.configured = true;
    mockRoute.path = '/dashboard';
    mockRoute.query = {};
    Object.defineProperty(navigator, 'onLine', { value: true, configurable: true });
  });

  describe('legalRepository', () => {
    it('obtiene catálogo vigente y traduce MISSING_ACTIVE_LEGAL_DOCUMENTS sin silencio', async () => {
      mockRpc.mockResolvedValueOnce({
        data: { success: true, data: sampleCatalog },
        error: null,
      });

      const res = await legalRepository.getActiveDocuments();
      expect(res.terms_of_service.version_id).toBe(sampleCatalog.terms_of_service.version_id);
      expect(res.privacy_policy.version_code).toBe('1.0');

      mockRpc.mockResolvedValueOnce({
        data: null,
        error: { message: 'MISSING_ACTIVE_LEGAL_DOCUMENTS: Sin versiones', code: 'P0001' },
      });

      await expect(legalRepository.getActiveDocuments()).rejects.toMatchObject({
        code: 'MISSING_ACTIVE_LEGAL_DOCUMENTS',
      });
    });

    it('propaga LEGAL_VERSION_SUPERSEDED al intentar aceptar versión reemplazada', async () => {
      mockRpc.mockResolvedValueOnce({
        data: null,
        error: { message: 'LEGAL_VERSION_SUPERSEDED: expirada', code: 'P0001' },
      });

      await expect(
        legalRepository.acceptLegalVersions('store-1', ['old-v1'])
      ).rejects.toMatchObject({
        code: 'LEGAL_VERSION_SUPERSEDED',
      });
    });
  });

  describe('RegisterStoreView.vue (FRD-029 Caso A / RN-01..RN-04)', () => {
    it('presenta dos casillas DESMARCADAS por defecto, permite leer textos completos y exige ambas marcadas', async () => {
      mockRpc.mockResolvedValue({
        data: { success: true, data: sampleCatalog },
        error: null,
      });

      const wrapper = mount(RegisterStoreView, {
        global: {
          stubs: {
            Teleport: true,
            RouterLink: true,
          },
        },
      });

      await flushPromises();

      const termsCb = wrapper.find('#accept-terms');
      const privacyCb = wrapper.find('#accept-privacy');
      expect(termsCb.exists()).toBe(true);
      expect(privacyCb.exists()).toBe(true);
      expect((termsCb.element as HTMLInputElement).checked).toBe(false);
      expect((privacyCb.element as HTMLInputElement).checked).toBe(false);

      // Rellenar datos válidos del formulario
      await wrapper.find('#storeName').setValue('Tienda La Esquina');
      await wrapper.find('#ownerName').setValue('Carlos Ruiz');
      await wrapper.find('#email').setValue('carlos@ejemplo.com');
      await wrapper.find('#password').setValue('Clave1234');
      await wrapper.find('#confirmPassword').setValue('Clave1234');

      const submitBtn = wrapper.findAll('button').find((b) => b.text().includes('Abrir mi Tienda'))!;
      expect(submitBtn.attributes('disabled')).toBeDefined();

      // Solo una casilla marcada -> sigue bloqueado (RN-01)
      await termsCb.setValue(true);
      expect(submitBtn.attributes('disabled')).toBeDefined();

      // Abrir lector completo de Política de Datos (RN-03) sin perder datos del formulario
      const readPrivacyBtn = wrapper
        .findAll('button')
        .find((b) => b.text().includes('Política de Tratamiento de Datos Personales'))!;
      await readPrivacyBtn.trigger('click');
      expect(wrapper.text()).toContain(sampleCatalog.privacy_policy.content);

      // Cerrar modal lector y marcar segunda casilla
      const understoodBtn = wrapper.findAll('button').find((b) => b.text().includes('Entendido'))!;
      await understoodBtn.trigger('click');
      await privacyCb.setValue(true);

      expect(submitBtn.attributes('disabled')).toBeUndefined();
      expect((wrapper.find('#storeName').element as HTMLInputElement).value).toBe('Tienda La Esquina');
    });

    it('envía IDs vigentes y ante LEGAL_VERSION_SUPERSEDED desmarca casillas y recarga catálogo', async () => {
      const updatedCatalog = {
        ...sampleCatalog,
        privacy_policy: {
          ...sampleCatalog.privacy_policy,
          version_id: '33333333-3333-4333-8333-333333333333',
          version_code: '2.0',
        },
      };

      mockRpc
        .mockResolvedValueOnce({ data: { success: true, data: sampleCatalog }, error: null })
        .mockResolvedValueOnce({ data: { success: true, data: updatedCatalog }, error: null });

      const authStore = useAuthStore();
      const registerSpy = vi.spyOn(authStore, 'registerStore').mockResolvedValueOnce({
        success: false,
        error_code: 'LEGAL_VERSION_SUPERSEDED',
        error: 'LEGAL_VERSION_SUPERSEDED',
      });

      const wrapper = mount(RegisterStoreView, {
        global: { stubs: { Teleport: true, RouterLink: true } },
      });
      await flushPromises();

      await wrapper.find('#storeName').setValue('Tienda El Sol');
      await wrapper.find('#ownerName').setValue('Ana Lopez');
      await wrapper.find('#email').setValue('ana@tienda.co');
      await wrapper.find('#password').setValue('Clave1234');
      await wrapper.find('#confirmPassword').setValue('Clave1234');
      await wrapper.find('#accept-terms').setValue(true);
      await wrapper.find('#accept-privacy').setValue(true);

      const submitBtn = wrapper.findAll('button').find((b) => b.text().includes('Abrir mi Tienda'))!;
      await submitBtn.trigger('click');
      await flushPromises();

      expect(registerSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          acceptedTermsVersionId: sampleCatalog.terms_of_service.version_id,
          acceptedPrivacyVersionId: sampleCatalog.privacy_policy.version_id,
          originChannel: 'web_register',
        })
      );

      // Tras rechazo por versión superada: casillas desmarcadas, nueva versión 2.0 cargada, error visible
      expect((wrapper.find('#accept-terms').element as HTMLInputElement).checked).toBe(false);
      expect((wrapper.find('#accept-privacy').element as HTMLInputElement).checked).toBe(false);
      expect(wrapper.text()).toContain('v2.0');
      expect(wrapper.find('[role="alert"]').text()).toContain('fue actualizada');
    });
  });

  describe('LegalComplianceGate.vue (FRD-029 Casos C y D / RN-10..RN-12)', () => {
    it('bloquea con modal en requires_major_acceptance, permite consultar soporte (RN-12) y suprime bloqueo si hay venta en POS (RN-10)', async () => {
      const authStore = useAuthStore();
      const cartStore = useCartStore();

      authStore.isAuthenticated = true;
      authStore.currentUser = {
        id: 'adm-1',
        name: 'Dueño',
        email: 'dueno@tienda.co',
        type: 'admin',
        storeId: 'store-1',
      };
      authStore.legalComplianceStatus = 'requires_major_acceptance';
      authStore.legalPendingMajorDocs = [sampleCatalog.privacy_policy];
      authStore.legalSupportChannel = {
        contact: 'soporte@tiendabarriopro.co',
        message: 'Canal oficial de soporte legal',
      };

      const wrapper = mount(LegalComplianceGate, {
        global: { stubs: { Teleport: true } },
      });

      const dialog = wrapper.find('[role="dialog"]');
      expect(dialog.exists()).toBe(true);

      const acceptBtn = wrapper.findAll('button').find((b) => b.text().includes('Aceptar y Continuar'))!;
      expect(acceptBtn.attributes('disabled')).toBeDefined();

      // Abrir ayuda de rechazo (RN-12)
      const rejectToggle = wrapper
        .findAll('button')
        .find((b) => b.text().includes('No acepto / Consultar soporte'))!;
      await rejectToggle.trigger('click');
      expect(wrapper.text()).toContain('soporte@tiendabarriopro.co');

      // RN-10: Si está en /pos con carrito activo, NO interrumpe venta en curso
      mockRoute.path = '/pos';
      cartStore.items = [{ id: 'p1', name: 'Arroz', price: 3000, quantity: 1 } as any];
      await flushPromises();
      expect(wrapper.find('[role="dialog"]').exists()).toBe(false);
    });

    it('muestra aviso no bloqueante sin casilla en minor_notice_available (RN-11)', async () => {
      const authStore = useAuthStore();
      authStore.isAuthenticated = true;
      authStore.currentUser = {
        id: 'adm-1',
        name: 'Dueño',
        email: 'dueno@tienda.co',
        type: 'admin',
        storeId: 'store-1',
      };
      authStore.legalComplianceStatus = 'minor_notice_available';
      authStore.legalPendingMinorNotices = [
        {
          ...sampleCatalog.terms_of_service,
          change_level: 'minor',
          version_code: '1.1',
          change_summary: 'Corrección ortográfica',
        },
      ];

      const wrapper = mount(LegalComplianceGate, {
        global: { stubs: { Teleport: true } },
      });

      expect(wrapper.find('[role="dialog"]').exists()).toBe(false);
      expect(wrapper.find('[role="region"]').text()).toContain('Corrección ortográfica');
      expect(wrapper.find('input[type="checkbox"]').exists()).toBe(false);
    });
  });
});

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useAuthStore } from '../../stores/auth';
import { authRepository } from '../../data/repositories/authRepository';
import { verifySessionDeduped, handleAccessDeniedError, handleSessionStatusTransition } from '../../composables/useSessionGuard';

vi.mock('../../data/repositories/authRepository', () => ({
  authRepository: {
    verifySessionAccessState: vi.fn(),
    logout: vi.fn(),
    checkDailyPassStatus: vi.fn(),
  }
}));

vi.mock('vue-toastification', () => ({
  useToast: vi.fn(() => ({
    warning: vi.fn(),
    error: vi.fn(),
    info: vi.fn(),
    success: vi.fn(),
  }))
}));

describe('useSessionGuard & Continuous Session Verification (SDD-013 v3.1.0)', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  it('debe compartir la misma promesa (in-flight deduplication) si se llama concurrentemente', async () => {
    const authStore = useAuthStore();
    authStore.isAuthenticated = true;

    let resolvePromise: any;
    const pendingPromise = new Promise((resolve) => {
      resolvePromise = resolve;
    });

    (authRepository.verifySessionAccessState as any).mockReturnValue(pendingPromise);

    const call1 = verifySessionDeduped();
    const call2 = verifySessionDeduped();

    resolvePromise({ success: true, status: 'active', store_id: 'test-store' });

    const [res1, res2] = await Promise.all([call1, call2]);

    expect(res1.status).toBe('active');
    expect(res2.status).toBe('active');
    expect(authRepository.verifySessionAccessState).toHaveBeenCalledTimes(1);
  });

  it('debe mantener sesión activa y dailyAccessState approved si el servidor responde active', async () => {
    const authStore = useAuthStore();
    authStore.isAuthenticated = true;
    authStore.dailyAccessState.status = 'none';

    (authRepository.verifySessionAccessState as any).mockResolvedValue({
      success: true,
      status: 'active',
      store_id: 'store-123',
      role: 'admin'
    });

    const result = await authStore.verifySessionWithServer();

    expect(result.status).toBe('active');
    expect(authStore.isAuthenticated).toBe(true);
    expect(authStore.dailyAccessState.status).toBe('approved');
  });

  it('debe marcar pase como expirado y descartar carrito si el servidor responde requires_daily_pass', async () => {
    const authStore = useAuthStore();
    authStore.isAuthenticated = true;
    authStore.dailyAccessState.status = 'approved';

    (authRepository.verifySessionAccessState as any).mockResolvedValue({
      success: false,
      status: 'requires_daily_pass',
      reason: 'PASS_EXPIRED_OR_PENDING'
    });

    const result = await authStore.verifySessionWithServer();

    expect(result.status).toBe('requires_daily_pass');
    expect(authStore.dailyAccessState.status).toBe('expired');
  });

  it('debe desautenticar y revocar cryptoKey si el servidor responde requires_login o revoked_or_disabled', async () => {
    const authStore = useAuthStore();
    authStore.isAuthenticated = true;
    authStore.dailyAccessState.status = 'approved';

    (authRepository.verifySessionAccessState as any).mockResolvedValue({
      success: false,
      status: 'revoked_or_disabled',
      reason: 'EMPLOYEE_INACTIVE'
    });

    const result = await authStore.verifySessionWithServer();

    expect(result.status).toBe('revoked_or_disabled');
    expect(authStore.isAuthenticated).toBe(false);
    expect(authStore.dailyAccessState.status).toBe('expired');
    expect(authStore.sessionCryptoKey).toBeNull();
  });

  it('handleAccessDeniedError detecta STORE_ACCESS_DENIED y redirige con un solo aviso', async () => {
    const authStore = useAuthStore();
    authStore.isAuthenticated = true;

    (authRepository.verifySessionAccessState as any).mockResolvedValue({
      success: false,
      status: 'requires_login',
      reason: 'NO_AUTH_TOKEN'
    });

    const mockRouter = {
      push: vi.fn(),
      currentRoute: { value: { path: '/inventory', name: 'inventory', meta: { requiresAuth: true } } }
    };

    const handled = await handleAccessDeniedError(
      { message: 'P0001: STORE_ACCESS_DENIED: El usuario no tiene acceso a esta tienda' },
      mockRouter
    );

    expect(handled).toBe(true);
    expect(mockRouter.push).toHaveBeenCalledWith({ name: 'login' });
  });
});

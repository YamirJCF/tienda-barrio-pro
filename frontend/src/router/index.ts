import { createRouter, createWebHashHistory, RouteRecordRaw } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { useCashRegisterStore } from '../stores/cashRegister';
import { verifySessionDeduped } from '../composables/useSessionGuard';
import { logger } from '../utils/logger';
import { supabase } from '../lib/supabase'; // Import supabase client
import LoginView from '../views/LoginView.vue';
import DashboardView from '../views/DashboardView.vue';
// ⚠️ SystemAuditView se importa dinámicamente solo en DEV (ver abajo)

let verifiedAdminUserId: string | null = null;

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    alias: ['/dashboard'],
    name: 'dashboard',
    component: DashboardView,
    meta: { requiresAuth: true },
  },
  {
    path: '/login',
    name: 'login',
    component: LoginView,
    meta: { guest: true },
  },
  {
    path: '/register-store',
    name: 'register-store',
    component: () => import('../views/RegisterStoreView.vue'),
    meta: { guest: true },
  },
  {
    path: '/forgot-password',
    name: 'forgot-password',
    component: () => import('../views/ForgotPasswordView.vue'),
    meta: { guest: true },
  },
  {
    path: '/check-email',
    name: 'check-email',
    component: () => import('../views/CheckEmailView.vue'),
    meta: { requiresAuth: true }, // Acceso permitido solo a usuarios registrados (aunque no verificados)
  },
  {
    path: '/legal/privacy',
    alias: ['/legal/terms'],
    name: 'privacy-policy',
    component: () => import('../views/PrivacyPolicyView.vue'),
    meta: { requiresAuth: false },
  },
  {
    path: '/platform/legal',
    name: 'platform-legal',
    component: () => import('../views/PlatformLegalAdminView.vue'),
    meta: { requiresAuth: false },
  },
  {
    path: '/update-password',
    name: 'update-password',
    component: () => import('../views/auth/UpdatePasswordView.vue'),
    meta: { requiresAuth: false }, // Allow access with Supabase session (bypass Pinia check)
  },
  // WO-008: Sala de Espera Diaria
  {
    path: '/daily-waiting-room',
    name: 'daily-waiting-room',
    component: () => import('../views/DailyWaitingRoom.vue'),
    meta: { requiresAuth: true }
  },
  // WO-008: Waiting Room (Email Verification)
  {
    path: '/auth/waiting-verification',
    name: 'waiting-verification',
    component: () => import('../views/auth/WaitingRoomView.vue'),
    meta: { guest: true, requiresAuth: false }
  },
  // Rutas Protegidas
  {
    path: '/admin',
    name: 'admin',
    component: () => import('../views/AdminHubView.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/pos',
    name: 'pos',
    component: () => import('../views/POSView.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/inventory',
    name: 'inventory',
    component: () => import('../views/InventoryView.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/clients',
    name: 'clients',
    component: () => import('../views/ClientListView.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/clients/:id',
    name: 'client-detail',
    component: () => import('../views/ClientDetailView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/employees',
    name: 'employees',
    component: () => import('../views/EmployeeManagerView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/stock-entry',
    name: 'stock-entry',
    component: () => import('../views/StockEntryView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/inventory-count',
    name: 'inventory-count',
    component: () => import('../views/InventoryCountView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/cash-control',
    name: 'cash-control',
    component: () => import('../views/CashControlView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/notifications',
    name: 'notifications',
    component: () => import('../views/NotificationCenterView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/reports',
    name: 'reports',
    alias: ['/admin/financial-dashboard', '/history'],
    component: () => import('../views/ReportsHubView.vue'),
    meta: { requiresAuth: true },
  },
  // Suppliers & Payables Management (Admin only — UX-ADR-005)
  {
    path: '/suppliers',
    alias: ['/payables'],
    name: 'suppliers',
    component: () => import('../views/SuppliersView.vue'),
    meta: { requiresAuth: true }
  },
  // Catch-all for Supabase Auth fragments (access_token=...) and 404s
  {
    path: '/:pathMatch(.*)*',
    name: 'auth-callback',
    component: () => import('../views/auth/AuthCallbackView.vue'),
    meta: { requiresAuth: false }
  },
];

// ============================================
// 🔒 INYECCIÓN SEGURA: Panel de Auditoría
// Solo se incluye en modo DESARROLLO (npm run dev)
// En producción (npm run build) esta ruta NO existirá
// ============================================
if (import.meta.env.DEV) {
  routes.push({
    path: '/sys-audit',
    name: 'system-audit',
    component: () => import('../views/SystemAuditView.vue'), // Lazy loading
    meta: { guest: true, devOnly: true },
  });
}

const router = createRouter({
  history: createWebHashHistory(),
  routes,
});

// GUARDIA DE SEGURIDAD
router.beforeEach(async (to, from, next) => {
  const authStore = useAuthStore();
  const isAuthenticated = authStore.isAuthenticated;

  if (!isAuthenticated) {
    verifiedAdminUserId = null;
  }

  // 1. Caso: Intenta entrar a ruta protegida sin auth
  if (to.meta.requiresAuth && !isAuthenticated) {
    return next({ name: 'login' });
  }

  // 2. Caso: Intenta entrar a Login/Register estando ya autenticado
  if (to.meta.guest && isAuthenticated) {
    return next({ name: 'dashboard' });
  }

  // 3. Caso Crítico: Autenticado pero SIN TIENDA registrada
  // Evitamos bucle infinito permitiendo estar en 'register-store'
  // FIX: Usar currentUser.storeId en lugar de hasStores (array local legacy)
  const hasStoreId = !!authStore.currentUser?.storeId;
  if (isAuthenticated && !hasStoreId && to.name !== 'register-store') {
    return next({ name: 'register-store' });
  }

  // =============================================
  // WO-008: Email Confirmation Check (Security Enforcer)
  // =============================================
  if (isAuthenticated && to.meta.requiresAuth && to.name !== 'check-email' && to.name !== 'waiting-verification') {
    // Only check for Admins (Owner accounts)
    if (authStore.isAdmin) {
      const currentUserId = authStore.currentUser?.id ?? null;
      if (currentUserId && verifiedAdminUserId !== currentUserId) {
        // We need to check the real session status
        const { data: { session } } = await supabase.auth.getSession();

        // If session exists but email is not confirmed
        if (session?.user && !session.user.email_confirmed_at && session.user.identities && session.user.identities[0]?.identity_data?.email_verified !== true) {
          logger.warn('🔒 [Router] Unverified email detected. Redirecting to check-email.');
          return next({
            name: 'waiting-verification',
            query: { email: session.user.email }
          });
        }
        verifiedAdminUserId = currentUserId;
      }
    }
  }

  // =============================================
  // SDD-013 v3.1.0: Server Session Authority Check
  // =============================================
  if (isAuthenticated && to.meta.requiresAuth && to.name !== 'check-email' && to.name !== 'waiting-verification' && to.name !== 'update-password') {
    if (!from.name) {
      try {
        const verification = await verifySessionDeduped();
        if (verification.status === 'requires_login' || verification.status === 'revoked_or_disabled') {
          logger.warn('🔒 [Router] Servidor requiere inicio de sesión. Redirigiendo a login.');
          const loggedOut = await authStore.logout();
          if (loggedOut) {
            return next({ name: 'login' });
          }
        }
        if (verification.status === 'requires_daily_pass') {
          logger.warn('🔒 [Router] Pase diario expirado o ausente. Redirigiendo a sala de espera.');
          return next({ name: 'daily-waiting-room' });
        }
      } catch (err) {
        logger.error('🔒 [Router] Error verificando sesión con servidor:', err);
      }
    }
  }

  // =============================================
  // WO-008: Daily Access Check (Zero Trust)
  // =============================================
  if (isAuthenticated && to.meta.requiresAuth && to.name !== 'daily-waiting-room' && to.name !== 'check-email' && to.name !== 'waiting-verification') {
    const dailyStatus = authStore.dailyAccessStatus;

    // FIX: Force clean login on startup if session is expired
    // Handles User Request: "Always start at login"
    if (dailyStatus === 'expired' || dailyStatus === 'none') {
      logger.log('🔒 [Router] Session expired or invalid on sensitive route. Forcing logout.');
      const loggedOut = await authStore.logout();
      if (loggedOut) {
        return next({ name: 'login' });
      }
    }

    // Si el status no es 'approved' (pending/rejected), bloquear acceso ir a Waiting Room
    if (dailyStatus !== 'approved') {
      return next({ name: 'daily-waiting-room' });
    }
  }

  // =============================================
  // SPEC-005: Permissions Guards
  // =============================================

  // FRD-004 / FRD-017 / SDD-027-02: Stale Shift (+24h Expirado/Bloqueado) Guard
  // Redirige únicamente al abridor original (con permiso) o al Admin, tanto si la sesión sigue open (>24h)
  // como si rpc_check_and_force_close_shifts ya la marcó Expirado/Bloqueado (pendingForcedSessionInfo).
  // Nunca bloquea labores no monetarias de otros empleados.
  if (isAuthenticated && to.meta.requiresAuth && to.name !== 'cash-control' && to.name !== 'login') {
    const cashRegisterStore = useCashRegisterStore();
    const hasStaleOrForced =
      cashRegisterStore.isStaleSession || Boolean(cashRegisterStore.pendingForcedSessionInfo);

    if (hasStaleOrForced) {
      const currentActorId = authStore.currentUser?.employeeId || authStore.currentUser?.id;
      const openerId = cashRegisterStore.isStaleSession
        ? cashRegisterStore.currentSession?.employeeId
        : cashRegisterStore.pendingForcedSessionInfo?.openedBy;
      const isOriginalOpener = Boolean(openerId && currentActorId && openerId === currentActorId);

      if (authStore.isAdmin || (authStore.canOpenCloseCash && isOriginalOpener)) {
        logger.log('🔒 [Router] Stale/Expirado (+24h) shift detected for opener/admin. Redirecting to cash-control.');
        return next({ name: 'cash-control' });
      }
    }
  }

  // 1. Employee Management: STRICTLY Admin only
  if (to.name === 'employees' && !authStore.isAdmin) {
    return next({ name: 'dashboard' });
  }

  // 1b. Reports Hub (consolidado UX-ADR-008): STRICTLY Admin only (SDD-003-01 / POL-AUD-02)
  if (to.name === 'reports' && !authStore.isAdmin) {
    return next({ name: 'dashboard' });
  }

  // 2. Admin Hub: STRICTLY Admin only
  if (to.name === 'admin' && !authStore.isAdmin) {
    return next({ name: 'dashboard' });
  }

  // 3b. Inventory, Stock Entry & Inventory Count: Requires canManageInventory (or Admin)
  if ((to.name === 'inventory' || to.name === 'stock-entry' || to.name === 'inventory-count') && !authStore.canManageInventory) {
    return next({ name: 'dashboard' });
  }

  // 3c. Clients & Client Detail: Requires canFiar (or Admin)
  if ((to.name === 'clients' || to.name === 'client-detail') && !authStore.canFiar) {
    return next({ name: 'dashboard' });
  }

  // 4. Suppliers & Payables (consolidated UX-ADR-005): Admin only
  if (to.name === 'suppliers' && !authStore.isAdmin) {
    return next({ name: 'dashboard' });
  }

  next();
});

export default router;

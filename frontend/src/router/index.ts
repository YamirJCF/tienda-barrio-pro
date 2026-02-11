import { createRouter, createWebHashHistory, RouteRecordRaw } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import { logger } from '../utils/logger';
import LoginView from '../views/LoginView.vue';
import DashboardView from '../views/DashboardView.vue';
// OFFLINE-CRITICAL: Eager imports for offline functionality
import POSView from '../views/POSView.vue';
import InventoryView from '../views/InventoryView.vue';
import ClientListView from '../views/ClientListView.vue';
import CashControlView from '../views/CashControlView.vue';
import AdminHubView from '../views/AdminHubView.vue';
import EmployeeManagerView from '../views/EmployeeManagerView.vue';
// ⚠️ SystemAuditView se importa dinámicamente solo en DEV (ver abajo)

const routes: RouteRecordRaw[] = [
  {
    path: '/',
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
    meta: { requiresAuth: false } // Public but logic driven
  },
  // Rutas Protegidas
  {
    path: '/admin',
    name: 'admin',
    component: AdminHubView,
    meta: { requiresAuth: true }
  },
  {
    path: '/pos',
    name: 'pos',
    component: POSView,
    meta: { requiresAuth: true }
  },
  {
    path: '/inventory',
    name: 'inventory',
    component: InventoryView,
    meta: { requiresAuth: true }
  },
  {
    path: '/clients',
    name: 'clients',
    component: ClientListView,
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
    component: EmployeeManagerView,
    meta: { requiresAuth: true },
  },
  {
    path: '/stock-entry',
    name: 'stock-entry',
    component: () => import('../views/StockEntryView.vue'),
    meta: { requiresAuth: true },
  },
  {
    path: '/cash-control',
    name: 'cash-control',
    component: CashControlView,
    meta: { requiresAuth: true },
  },
  {
    path: '/expenses',
    name: 'expenses',
    component: () => import('../views/ExpensesView.vue'),
    meta: { requiresAuth: true }
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
    component: () => import('../views/ReportsView.vue'),
    meta: { requiresAuth: true },
  },
  // SPEC-009: Ruta de Historiales
  {
    path: '/history',
    name: 'history',
    component: () => import('../views/HistoryView.vue'),
    meta: { requiresAuth: true }
  },
  // Suppliers Management (Admin only)
  {
    path: '/suppliers',
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
  const hasStore = authStore.hasStores;

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
  // WO-008: Daily Access Check (Zero Trust)
  // =============================================
  // =============================================
  // WO-008: Daily Access Check (Zero Trust)
  // =============================================
  if (isAuthenticated && to.meta.requiresAuth && to.name !== 'daily-waiting-room' && to.name !== 'check-email') {
    const dailyStatus = authStore.dailyAccessStatus;

    // FIX: Force clean login on startup if session is expired
    // Handles User Request: "Always start at login"
    if (dailyStatus === 'expired' || dailyStatus === 'none') {
      logger.log('🔒 [Router] Session expired or invalid on sensitive route. Forcing logout.');
      await authStore.logout();
      return next({ name: 'login' });
    }

    // Si el status no es 'approved' (pending/rejected), bloquear acceso ir a Waiting Room
    if (dailyStatus !== 'approved') {
      return next({ name: 'daily-waiting-room' });
    }
  }

  // =============================================
  // SPEC-005: Permissions Guards
  // =============================================

  // FRD-004/FRD-015: Stale Shift Guard
  // If a cash session from a previous day is still open, block everything except cash-control
  if (isAuthenticated && to.meta.requiresAuth && to.name !== 'cash-control' && to.name !== 'login') {
    const { useCashRegisterStore } = await import('../stores/cashRegister');
    const cashRegisterStore = useCashRegisterStore();
    if (cashRegisterStore.isStaleSession) {
      logger.log('🔒 [Router] Stale shift detected. Redirecting to cash-control for mandatory closure.');
      return next({ name: 'cash-control' });
    }
  }

  // 1. Employee Management: STRICTLY Admin only
  if (to.name === 'employees' && !authStore.isAdmin) {
    return next({ name: 'dashboard' });
  }

  // 2. Admin Hub: Admin OR Reports Viewer
  if (to.name === 'admin') {
    if (!authStore.isAdmin && !authStore.canViewReports) {
      return next({ name: 'dashboard' });
    }
    // Block "Gestión" tab for non-admins
    if (to.query.tab === 'gestion' && !authStore.isAdmin) {
      return next({ name: 'admin', query: { tab: 'reportes' } });
    }
  }

  // 3. Cash Control: Needs permission
  if (to.name === 'cash-control' && !authStore.canOpenCloseCash) {
    return next({ name: 'dashboard' });
  }

  // 4. Suppliers: Admin only
  if (to.name === 'suppliers' && !authStore.isAdmin) {
    return next({ name: 'dashboard' });
  }

  // =============================================
  // SPEC-005: Guard para POS - Tienda Abierta
  // =============================================
  // Empleados no pueden acceder al POS si la tienda está cerrada
  if (to.name === 'pos' && isAuthenticated) {
    const isAdmin = authStore.isAdmin;
    // SPEC-005 Update: La validación de 'tienda abierta' se delega al componente POS o lógica de caja
    // ya que authStore no mantiene el estado global de apertura.

    /* BLOQUE ELIMINADO POR REFACTORIZACION IAM
    if (!isAdmin && !storeIsOpen) {
       console.warn('[Router] POS bloqueado: tienda cerrada');
       return next({ name: 'dashboard' });
    }
    */
  }

  next();
});

export default router;

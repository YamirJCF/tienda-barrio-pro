import { createRouter, createWebHashHistory, RouteRecordRaw } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import LoginView from '../views/LoginView.vue';
import DashboardView from '../views/DashboardView.vue';
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
  // WO-008: Sala de Espera Diaria
  {
    path: '/daily-waiting-room',
    name: 'daily-waiting-room',
    component: () => import('../views/DailyWaitingRoom.vue'),
    meta: { requiresAuth: true }
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
    path: '/cash-control',
    name: 'cash-control',
    component: () => import('../views/CashControlView.vue'),
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
router.beforeEach((to, from, next) => {
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
  if (isAuthenticated && !hasStore && to.name !== 'register-store') {
    return next({ name: 'register-store' });
  }

  // =============================================
  // WO-008: Daily Access Check (Zero Trust)
  // =============================================
  if (isAuthenticated && to.meta.requiresAuth && to.name !== 'daily-waiting-room' && to.name !== 'check-email') {
    const dailyStatus = authStore.dailyAccessStatus;

    // Si el status no es 'approved', bloquear acceso
    if (dailyStatus !== 'approved') {
      console.log('[Router] Bloqueo de seguridad diaria. Status:', dailyStatus);
      return next({ name: 'daily-waiting-room' });
    }
  }

  // =============================================
  // SPEC-005: Permissions Guards
  // =============================================

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

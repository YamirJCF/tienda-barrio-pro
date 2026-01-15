import { createRouter, createWebHashHistory, RouteRecordRaw } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import LoginView from '../views/LoginView.vue';
import DashboardView from '../views/DashboardView.vue';
import AdminHubView from '../views/AdminHubView.vue';
import POSView from '../views/POSView.vue';
import InventoryView from '../views/InventoryView.vue';
import ClientListView from '../views/ClientListView.vue';
import ClientDetailView from '../views/ClientDetailView.vue';
import EmployeeManagerView from '../views/EmployeeManagerView.vue';
import StockEntryView from '../views/StockEntryView.vue';
import CashControlView from '../views/CashControlView.vue';
import ExpensesView from '../views/ExpensesView.vue';
import NotificationCenterView from '../views/NotificationCenterView.vue';
import RegisterStoreView from '../views/RegisterStoreView.vue';
import ForgotPasswordView from '../views/ForgotPasswordView.vue';
// ⚠️ SystemAuditView se importa dinámicamente solo en DEV (ver abajo)

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    name: 'dashboard',
    component: DashboardView,
    meta: { requiresAuth: true }
  },
  {
    path: '/login',
    name: 'login',
    component: LoginView,
    meta: { guest: true }
  },
  {
    path: '/register-store',
    name: 'register-store',
    component: RegisterStoreView,
    meta: { guest: true }
  },
  {
    path: '/forgot-password',
    name: 'forgot-password',
    component: ForgotPasswordView,
    meta: { guest: true }
  },
  // Rutas Protegidas
  { path: '/admin', name: 'admin', component: AdminHubView, meta: { requiresAuth: true } },
  { path: '/pos', name: 'pos', component: POSView, meta: { requiresAuth: true } },
  { path: '/inventory', name: 'inventory', component: InventoryView, meta: { requiresAuth: true } },
  { path: '/clients', name: 'clients', component: ClientListView, meta: { requiresAuth: true } },
  { path: '/clients/:id', name: 'client-detail', component: ClientDetailView, meta: { requiresAuth: true } },
  { path: '/employees', name: 'employees', component: EmployeeManagerView, meta: { requiresAuth: true } },
  { path: '/stock-entry', name: 'stock-entry', component: StockEntryView, meta: { requiresAuth: true } },
  { path: '/cash-control', name: 'cash-control', component: CashControlView, meta: { requiresAuth: true } },
  { path: '/expenses', name: 'expenses', component: ExpensesView, meta: { requiresAuth: true } },
  { path: '/notifications', name: 'notifications', component: NotificationCenterView, meta: { requiresAuth: true } },
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
    meta: { guest: true, devOnly: true }
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

  next();
});

export default router;
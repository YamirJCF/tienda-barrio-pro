import { createRouter, createWebHashHistory } from 'vue-router';
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

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    {
      path: '/',
      name: 'dashboard',
      component: DashboardView,
    },
    {
      path: '/admin',
      name: 'admin',
      component: AdminHubView,
    },
    {
      path: '/login',
      name: 'login',
      component: LoginView,
    },
    {
      path: '/pos',
      name: 'pos',
      component: POSView,
    },
    {
      path: '/inventory',
      name: 'inventory',
      component: InventoryView,
    },
    {
      path: '/clients',
      name: 'clients',
      component: ClientListView,
    },
    {
      path: '/clients/:id',
      name: 'client-detail',
      component: ClientDetailView,
    },
    {
      path: '/employees',
      name: 'employees',
      component: EmployeeManagerView,
    },
    {
      path: '/stock-entry',
      name: 'stock-entry',
      component: StockEntryView,
    },
    {
      path: '/cash-control',
      name: 'cash-control',
      component: CashControlView,
    },
    {
      path: '/expenses',
      name: 'expenses',
      component: ExpensesView,
    },
    {
      path: '/notifications',
      name: 'notifications',
      component: NotificationCenterView,
    },
    {
      path: '/register-store',
      name: 'register-store',
      component: RegisterStoreView,
    },
    {
      path: '/forgot-password',
      name: 'forgot-password',
      component: ForgotPasswordView,
    },
  ],
});

export default router;
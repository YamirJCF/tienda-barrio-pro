import { createRouter, createWebHashHistory } from 'vue-router';
import LoginView from '../views/LoginView.vue';
import DashboardView from '../views/DashboardView.vue';
import AdminHubView from '../views/AdminHubView.vue';
import POSView from '../views/POSView.vue';
import InventoryView from '../views/InventoryView.vue';
import ClientListView from '../views/ClientListView.vue';
import ClientDetailView from '../views/ClientDetailView.vue';

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
  ],
});

export default router;
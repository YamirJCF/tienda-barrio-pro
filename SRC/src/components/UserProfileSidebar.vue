<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
// T-011: Store para preferencias persistentes
import { usePreferencesStore } from '../stores/preferences';

interface Props {
  isOpen: boolean;
  userType?: 'admin' | 'employee';
  userName?: string;
  userEmail?: string;
  userRole?: string;
}

const props = withDefaults(defineProps<Props>(), {
  userType: 'admin',
  userName: 'Don José',
  userEmail: 'tienda@ejemplo.com',
  userRole: 'VENDEDOR'
});

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'logout'): void;
}>();

const router = useRouter();
// T-011: Usar store persistente en lugar de refs locales
const preferencesStore = usePreferencesStore();

// T-011: Computed que referencian el store
const saleSoundsEnabled = computed(() => preferencesStore.saleSoundsEnabled);
const darkModeEnabled = computed(() => preferencesStore.darkModeEnabled);
const notificationsEnabled = computed(() => preferencesStore.notificationsEnabled);

// Computed
const userInitials = computed(() => {
  return props.userName
    .split(' ')
    .map(word => word[0])
    .join('')
    .substring(0, 2)
    .toUpperCase();
});

const isAdmin = computed(() => props.userType === 'admin');

// Methods
const closeSidebar = () => {
  emit('close');
};

const handleLogout = () => {
  emit('logout');
  router.push('/login');
};

const toggleDarkMode = () => {
  preferencesStore.toggleDarkMode();
};

const navigateToHelp = () => {
  // Placeholder for help center navigation
  console.log('Navigate to help center');
};

const navigateToSecurity = () => {
  // T-005: Navegación a configuración de seguridad (Admin > Gestión > Seguridad)
  router.push('/admin?tab=gestion');
  emit('close');
};
</script>

<template>
  <Teleport to="body">
    <Transition name="sidebar">
      <div v-if="isOpen" class="fixed inset-0 z-50">
        <!-- Overlay -->
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity duration-300"
          @click="closeSidebar"></div>

        <!-- Sidebar Panel -->
        <div
          class="fixed inset-y-0 right-0 z-50 w-full max-w-[320px] bg-white dark:bg-[#1a2632] shadow-2xl transform transition-transform duration-300 ease-in-out flex flex-col h-full">

          <!-- Profile Header Section -->
          <div
            class="relative flex flex-col items-center bg-slate-50 dark:bg-[#15202b] border-b border-slate-100 dark:border-slate-800 p-6 pt-12 shrink-0">
            <!-- Close Button -->
            <button @click="closeSidebar"
              class="absolute top-4 right-4 p-2 text-slate-400 hover:text-slate-600 dark:text-slate-500 dark:hover:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700 rounded-full transition-colors focus:outline-none focus:ring-2 focus:ring-primary/50">
              <span class="material-symbols-outlined text-[24px]">close</span>
            </button>

            <!-- Avatar -->
            <div class="relative group" :class="{ 'cursor-pointer': isAdmin }">
              <div v-if="isAdmin"
                class="w-24 h-24 rounded-full bg-cover bg-center shadow-md border-4 border-white dark:border-slate-800 bg-gradient-to-br from-blue-400 to-purple-500">
              </div>
              <div v-else
                class="w-24 h-24 rounded-full bg-slate-200 dark:bg-slate-700 flex items-center justify-center border-4 border-white dark:border-slate-800 shadow-md">
                <span class="text-3xl font-bold text-slate-500 dark:text-slate-300">{{ userInitials }}</span>
              </div>

              <!-- Edit badge (Admin only) -->
              <div v-if="isAdmin"
                class="absolute bottom-0 right-0 bg-primary rounded-full p-1 border-2 border-white dark:border-slate-800">
                <span class="material-symbols-outlined text-white text-[14px]">edit</span>
              </div>
            </div>

            <!-- User Info -->
            <div class="flex flex-col items-center mt-4 text-center">
              <h2 class="text-xl font-bold text-slate-900 dark:text-white tracking-tight">{{ userName }}</h2>
              <div class="mt-2">
                <span v-if="isAdmin"
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-bold bg-primary text-white tracking-wide shadow-sm">
                  ADMINISTRADOR
                </span>
                <span v-else
                  class="inline-flex items-center px-2.5 py-1 rounded border border-gray-200 dark:border-slate-600 text-xs font-bold bg-gray-100 dark:bg-slate-700 text-gray-600 dark:text-gray-300 tracking-wide uppercase">
                  {{ userRole }}
                </span>
              </div>
              <p v-if="isAdmin" class="mt-2 text-sm text-slate-500 dark:text-slate-400 font-medium">{{ userEmail }}</p>
            </div>
          </div>

          <!-- Menu Options (Scrollable Content) -->
          <div class="flex-1 overflow-y-auto scrollbar-hide p-4 space-y-6 bg-white dark:bg-[#1a2632]">

            <!-- Admin-only sections -->
            <template v-if="isAdmin">
              <!-- Group: Mi Cuenta -->
              <div>
                <h3 class="px-2 mb-2 text-xs font-semibold text-slate-400 dark:text-slate-500 uppercase tracking-wider">
                  Mi Cuenta</h3>
                <div class="space-y-1">
                  <!-- Item: Seguridad -->
                  <button @click="navigateToSecurity"
                    class="w-full flex items-center justify-between p-3 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-all group focus:outline-none focus:bg-slate-50 dark:focus:bg-slate-800">
                    <div class="flex items-center gap-3">
                      <div
                        class="w-9 h-9 shrink-0 rounded-lg bg-[#e7edf3] dark:bg-slate-700 flex items-center justify-center text-slate-700 dark:text-slate-200 group-hover:bg-white dark:group-hover:bg-slate-600 group-hover:shadow-sm transition-all">
                        <span class="material-symbols-outlined text-[20px]">lock</span>
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200">Seguridad y Contraseña</span>
                    </div>
                    <span
                      class="material-symbols-outlined text-slate-400 dark:text-slate-500 text-[20px]">chevron_right</span>
                  </button>

                  <!-- Item: Notificaciones (Toggle) -->
                  <div
                    class="w-full flex items-center justify-between p-3 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-all group">
                    <div class="flex items-center gap-3">
                      <div
                        class="w-9 h-9 shrink-0 rounded-lg bg-[#e7edf3] dark:bg-slate-700 flex items-center justify-center text-slate-700 dark:text-slate-200 group-hover:bg-white dark:group-hover:bg-slate-600 group-hover:shadow-sm transition-all">
                        <span class="material-symbols-outlined text-[20px]">notifications</span>
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200">Notificaciones</span>
                    </div>
                    <!-- Toggle Switch -->
                    <label class="relative inline-flex items-center cursor-pointer">
                      <input v-model="notificationsEnabled" type="checkbox" class="sr-only peer" />
                      <div
                        class="w-11 h-6 bg-slate-200 dark:bg-slate-600 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-slate-600 peer-checked:bg-primary">
                      </div>
                    </label>
                  </div>
                </div>
              </div>

              <!-- Group: Soporte -->
              <div>
                <h3 class="px-2 mb-2 text-xs font-semibold text-slate-400 dark:text-slate-500 uppercase tracking-wider">
                  Soporte</h3>
                <div class="space-y-1">
                  <!-- Item: Centro de Ayuda -->
                  <button @click="navigateToHelp"
                    class="w-full flex items-center justify-between p-3 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-all group focus:outline-none focus:bg-slate-50 dark:focus:bg-slate-800">
                    <div class="flex items-center gap-3">
                      <div
                        class="w-9 h-9 shrink-0 rounded-lg bg-[#e7edf3] dark:bg-slate-700 flex items-center justify-center text-slate-700 dark:text-slate-200 group-hover:bg-white dark:group-hover:bg-slate-600 group-hover:shadow-sm transition-all">
                        <span class="material-symbols-outlined text-[20px]">help</span>
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200">Centro de Ayuda</span>
                    </div>
                  </button>

                  <!-- Item: Contactar Soporte -->
                  <button
                    class="w-full flex items-center justify-between p-3 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-all group focus:outline-none focus:bg-slate-50 dark:focus:bg-slate-800">
                    <div class="flex items-center gap-3">
                      <div
                        class="w-9 h-9 shrink-0 rounded-lg bg-[#e7edf3] dark:bg-slate-700 flex items-center justify-center text-slate-700 dark:text-slate-200 group-hover:bg-white dark:group-hover:bg-slate-600 group-hover:shadow-sm transition-all">
                        <span class="material-symbols-outlined text-[20px]">chat_bubble</span>
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200">Contactar Soporte</span>
                    </div>
                  </button>

                  <!-- Item: Términos y Condiciones -->
                  <button
                    class="w-full flex items-center justify-between p-3 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-all group focus:outline-none focus:bg-slate-50 dark:focus:bg-slate-800">
                    <div class="flex items-center gap-3">
                      <div
                        class="w-9 h-9 shrink-0 rounded-lg bg-[#e7edf3] dark:bg-slate-700 flex items-center justify-center text-slate-700 dark:text-slate-200 group-hover:bg-white dark:group-hover:bg-slate-600 group-hover:shadow-sm transition-all">
                        <span class="material-symbols-outlined text-[20px]">description</span>
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200">Términos y Condiciones</span>
                    </div>
                  </button>
                </div>
              </div>
            </template>

            <!-- Employee-only sections -->
            <template v-else>
              <!-- Group: Preferencias -->
              <div>
                <h3 class="px-2 mb-2 text-xs font-semibold text-slate-400 dark:text-slate-500 uppercase tracking-wider">
                  Preferencias</h3>
                <div class="space-y-1">
                  <!-- Item: Sonidos de Venta -->
                  <div
                    class="w-full flex items-center justify-between p-3 rounded-lg hover:bg-gray-50 dark:hover:bg-slate-800/50 transition-all group">
                    <div class="flex items-center gap-3">
                      <div
                        class="w-9 h-9 shrink-0 rounded-lg bg-gray-100 dark:bg-slate-700 flex items-center justify-center text-slate-600 dark:text-slate-300 group-hover:bg-white dark:group-hover:bg-slate-600 group-hover:shadow-sm transition-all">
                        <span class="material-symbols-outlined text-[20px]">volume_up</span>
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200">Sonidos de Venta</span>
                    </div>
                    <label class="relative inline-flex items-center cursor-pointer">
                      <input v-model="saleSoundsEnabled" type="checkbox" class="sr-only peer" />
                      <div
                        class="w-11 h-6 bg-gray-200 dark:bg-slate-600 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-slate-600 peer-checked:bg-primary">
                      </div>
                    </label>
                  </div>

                  <!-- Item: Modo Oscuro -->
                  <div
                    class="w-full flex items-center justify-between p-3 rounded-lg hover:bg-gray-50 dark:hover:bg-slate-800/50 transition-all group">
                    <div class="flex items-center gap-3">
                      <div
                        class="w-9 h-9 shrink-0 rounded-lg bg-gray-100 dark:bg-slate-700 flex items-center justify-center text-slate-600 dark:text-slate-300 group-hover:bg-white dark:group-hover:bg-slate-600 group-hover:shadow-sm transition-all">
                        <span class="material-symbols-outlined text-[20px]">dark_mode</span>
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200">Modo Oscuro</span>
                    </div>
                    <label class="relative inline-flex items-center cursor-pointer">
                      <input v-model="darkModeEnabled" @change="toggleDarkMode" type="checkbox" class="sr-only peer" />
                      <div
                        class="w-11 h-6 bg-gray-200 dark:bg-slate-600 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-slate-600 peer-checked:bg-primary">
                      </div>
                    </label>
                  </div>
                </div>
              </div>

              <!-- Group: Ayuda y Soporte -->
              <div>
                <h3 class="px-2 mb-2 text-xs font-semibold text-slate-400 dark:text-slate-500 uppercase tracking-wider">
                  Ayuda y Soporte</h3>
                <div class="space-y-1">
                  <button
                    class="w-full flex items-center justify-between p-3 rounded-lg hover:bg-gray-50 dark:hover:bg-slate-800/50 transition-all group focus:outline-none focus:bg-gray-50 dark:focus:bg-slate-800">
                    <div class="flex items-center gap-3">
                      <div
                        class="w-9 h-9 shrink-0 rounded-lg bg-gray-100 dark:bg-slate-700 flex items-center justify-center text-slate-600 dark:text-slate-300 group-hover:bg-white dark:group-hover:bg-slate-600 group-hover:shadow-sm transition-all">
                        <span class="material-symbols-outlined text-[20px]">menu_book</span>
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200">Ver Tutoriales</span>
                    </div>
                    <span
                      class="material-symbols-outlined text-slate-400 dark:text-slate-500 text-[20px]">chevron_right</span>
                  </button>

                  <button
                    class="w-full flex items-center justify-between p-3 rounded-lg hover:bg-gray-50 dark:hover:bg-slate-800/50 transition-all group focus:outline-none focus:bg-gray-50 dark:focus:bg-slate-800">
                    <div class="flex items-center gap-3">
                      <div
                        class="w-9 h-9 shrink-0 rounded-lg bg-gray-100 dark:bg-slate-700 flex items-center justify-center text-slate-600 dark:text-slate-300 group-hover:bg-white dark:group-hover:bg-slate-600 group-hover:shadow-sm transition-all">
                        <span class="material-symbols-outlined text-[20px]">flag</span>
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200">Reportar un problema</span>
                    </div>
                    <span
                      class="material-symbols-outlined text-slate-400 dark:text-slate-500 text-[20px]">chevron_right</span>
                  </button>
                </div>
              </div>

              <!-- Info Banner for Employee -->
              <div class="mt-4 mx-2">
                <div
                  class="bg-blue-50 dark:bg-blue-900/20 p-4 rounded-lg flex items-start gap-3 border border-blue-100 dark:border-blue-900/30">
                  <span class="material-symbols-outlined text-blue-500 text-[20px] shrink-0 mt-0.5">lock</span>
                  <p class="text-xs text-blue-800 dark:text-blue-200 leading-relaxed">
                    Tu cuenta es gestionada por el administrador. Para cambiar tu PIN o datos personales, contacta a tu
                    jefe.
                  </p>
                </div>
              </div>
            </template>
          </div>

          <!-- Footer (Logout) -->
          <div class="p-4 border-t border-slate-100 dark:border-slate-800 bg-white dark:bg-[#1a2632] shrink-0 pb-8">
            <button @click="handleLogout"
              class="w-full flex items-center justify-center gap-2 p-3.5 rounded-lg bg-red-50 hover:bg-red-100 text-red-600 dark:bg-red-900/20 dark:hover:bg-red-900/30 dark:text-red-400 transition-colors font-semibold shadow-sm border border-transparent focus:outline-none focus:ring-2 focus:ring-red-500/50">
              <span class="material-symbols-outlined text-[20px]">logout</span>
              Cerrar Sesión
            </button>
            <p class="text-center text-[11px] text-slate-400 dark:text-slate-500 mt-4 font-medium tracking-wide">
              Versión 1.0.2 - Build 2025
            </p>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.scrollbar-hide::-webkit-scrollbar {
  display: none;
}

.scrollbar-hide {
  -ms-overflow-style: none;
  scrollbar-width: none;
}

.sidebar-enter-active,
.sidebar-leave-active {
  transition: opacity 0.3s ease;
}

.sidebar-enter-from,
.sidebar-leave-to {
  opacity: 0;
}

.sidebar-enter-active .fixed.inset-y-0 {
  animation: slideInRight 0.3s ease-out;
}

.sidebar-leave-active .fixed.inset-y-0 {
  animation: slideOutRight 0.3s ease-in;
}

@keyframes slideInRight {
  from {
    transform: translateX(100%);
  }

  to {
    transform: translateX(0);
  }
}

@keyframes slideOutRight {
  from {
    transform: translateX(0);
  }

  to {
    transform: translateX(100%);
  }
}
</style>

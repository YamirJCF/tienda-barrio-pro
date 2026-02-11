<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
// T-011: Store para preferencias persistentes
import { usePreferencesStore } from '../stores/preferences';
import { useAuthStore } from '../stores/auth';
import { logger } from '../utils/logger';
import ChangePasswordModal from '@/components/security/ChangePasswordModal.vue';
import { 
  X, 
  Settings, 
  ShieldCheck, 
  Bell, 
  HelpCircle, 
  MessageSquare, 
  FileText, 
  Volume2, 
  Moon, 
  BookOpen, 
  Flag, 
  LogOut,
  User as UserIcon,
  ChevronRight,
  Edit2
} from 'lucide-vue-next';

interface Props {
  isOpen: boolean;
  // Fallbacks provided for backward compatibility, but store is primary
  userType?: 'admin' | 'employee';
  userName?: string;
  userEmail?: string;
  userRole?: string;
}

const props = withDefaults(defineProps<Props>(), {
  userType: 'admin',
  userName: 'Don José',
  userEmail: 'tienda@ejemplo.com',
  userRole: 'VENDEDOR',
});

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'logout'): void;
}>();

const router = useRouter();
const authStore = useAuthStore();
// T-011: Usar store persistente en lugar de refs locales
const preferencesStore = usePreferencesStore();

// User info from store (Authority source)
const currentUser = computed(() => authStore.currentUser);
const displayUserName = computed(() => currentUser.value?.name || props.userName);
const displayUserEmail = computed(() => currentUser.value?.email || props.userEmail);
const isAdmin = computed(() => currentUser.value?.type === 'admin');

// T-011: Computed que referencian el store
// T-011: Computed que referencian el store con get/set para v-model
const saleSoundsEnabled = computed({
  get: () => preferencesStore.saleSoundsEnabled,
  set: (val) => preferencesStore.toggleSaleSounds() // Assuming toggle or creating a set action would be better, but toggle matches boolean flip
});

const darkModeEnabled = computed({
  get: () => preferencesStore.darkModeEnabled,
  set: (val) => preferencesStore.toggleDarkMode()
});

const notificationsEnabled = computed({
  get: () => preferencesStore.notificationsEnabled,
  set: (val) => preferencesStore.toggleNotifications()
});

// Computed
const userInitials = computed(() => {
  const name = displayUserName.value;
  if (!name) return '??';
  return name
    .split(' ')
    .filter(word => word.length > 0)
    .map((word) => word[0])
    .join('')
    .substring(0, 2)
    .toUpperCase();
});

// Methods
const closeSidebar = () => {
  emit('close');
};

const handleLogout = async () => {
  emit('logout');
  await authStore.logout();
  router.push('/login');
};

const toggleDarkMode = () => {
  preferencesStore.toggleDarkMode();
};

const navigateToHelp = () => {
  // Placeholder for help center navigation
  logger.log('Navigate to help center');
};

// Password change modal state
const showPasswordModal = ref(false);

const navigateToSecurity = () => {
  // Open password change modal directly
  showPasswordModal.value = true;
};
</script>

<template>
  <Teleport to="body">
    <Transition name="sidebar">
      <div v-if="isOpen" class="fixed inset-0 z-50">
        <!-- Overlay -->
        <div
          class="absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity duration-300"
          @click="closeSidebar"
        ></div>

        <!-- Sidebar Panel -->
        <div
          class="fixed inset-y-0 right-0 z-50 w-full max-w-[320px] bg-white dark:bg-[#1a2632] shadow-2xl transform transition-transform duration-300 ease-in-out flex flex-col h-full"
        >
          <!-- Profile Header Section -->
          <div
            class="relative flex flex-col items-center bg-white dark:bg-[#15202b] border-b border-slate-100 dark:border-slate-800 p-6 pt-12 shrink-0"
          >
            <!-- Close Button -->
            <button
              @click="closeSidebar"
              class="absolute top-4 right-4 p-2 text-slate-400 hover:text-slate-600 dark:text-slate-500 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl transition-colors focus:outline-none focus:ring-2 focus:ring-primary/50"
            >
              <X :size="20" :stroke-width="1.5" />
            </button>

            <!-- Avatar (Squircle Nu-Style) -->
            <div class="relative group" :class="{ 'cursor-pointer': isAdmin }">
              <div
                class="w-24 h-24 rounded-[2rem] flex items-center justify-center border-4 border-white dark:border-slate-800 shadow-sm transition-transform duration-300 group-hover:scale-105"
                :class="isAdmin ? 'bg-indigo-50 text-indigo-600 dark:bg-indigo-500/20 dark:text-indigo-300' : 'bg-slate-100 text-slate-500 dark:bg-slate-700 dark:text-slate-300'"
              >
                <span class="text-3xl font-bold tracking-tight">{{ userInitials }}</span>
              </div>

              <!-- Edit badge (Admin only) -->
              <div
                v-if="isAdmin"
                class="absolute -bottom-1 -right-1 bg-white dark:bg-slate-800 rounded-xl p-1.5 shadow-sm border border-slate-100 dark:border-slate-700 text-indigo-600 dark:text-indigo-400"
              >
                <Edit2 :size="14" :stroke-width="1.5" />
              </div>
            </div>

            <!-- User Info -->
            <div class="flex flex-col items-center mt-5 text-center">
              <h2 class="text-xl font-bold text-slate-900 dark:text-white tracking-tight">
                {{ displayUserName }}
              </h2>
              <div class="mt-2.5">
                <span
                  v-if="isAdmin"
                  class="inline-flex items-center px-3 py-1 rounded-full text-[10px] font-bold bg-indigo-50 text-indigo-700 dark:bg-indigo-500/20 dark:text-indigo-300 tracking-widest uppercase border border-indigo-100 dark:border-indigo-500/30"
                >
                  ADMINISTRADOR
                </span>
                <span
                  v-else
                  class="inline-flex items-center px-3 py-1 rounded-full border border-slate-200 dark:border-slate-700 text-[10px] font-bold bg-slate-50 dark:bg-slate-800 text-slate-600 dark:text-slate-400 tracking-widest uppercase"
                >
                  {{ userRole }}
                </span>
              </div>
              <p v-if="isAdmin" class="mt-2 text-sm text-slate-500 dark:text-slate-400 font-medium">
                {{ displayUserEmail }}
              </p>
            </div>
          </div>

          <!-- Menu Options (Scrollable Content) -->
          <div
            class="flex-1 overflow-y-auto scrollbar-hide p-4 space-y-6 bg-white dark:bg-[#1a2632]"
          >
            <!-- Admin-only sections -->
            <template v-if="isAdmin">
              <!-- Group: Mi Cuenta -->
              <div>
                <h3
                  class="px-3 mb-3 text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-widest"
                >
                  Mi Cuenta
                </h3>
                <div class="space-y-1">
                  <!-- Item: Seguridad -->
                  <button
                    @click="navigateToSecurity"
                    class="w-full flex items-center justify-between p-3 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-all group focus:outline-none focus:bg-slate-50 dark:focus:bg-slate-800"
                  >
                    <div class="flex items-center gap-4">
                      <div
                        class="w-10 h-10 shrink-0 rounded-xl bg-slate-50 dark:bg-slate-800/80 flex items-center justify-center text-slate-600 dark:text-slate-400 group-hover:bg-white dark:group-hover:bg-slate-700 group-hover:shadow-sm transition-all border border-transparent group-hover:border-slate-100 dark:group-hover:border-slate-700"
                      >
                        <ShieldCheck :size="20" :stroke-width="1.5" />
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                        >Seguridad y Contraseña</span
                      >
                    </div>
                    <ChevronRight :size="18" :stroke-width="1.5" class="text-slate-400" />
                  </button>

                  <!-- Item: Notificaciones (Toggle) -->
                  <div
                    class="w-full flex items-center justify-between p-3 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-all group"
                  >
                    <div class="flex items-center gap-4">
                      <div
                        class="w-10 h-10 shrink-0 rounded-xl bg-slate-50 dark:bg-slate-800/80 flex items-center justify-center text-slate-600 dark:text-slate-400 group-hover:bg-white dark:group-hover:bg-slate-700 group-hover:shadow-sm transition-all border border-transparent group-hover:border-slate-100 dark:group-hover:border-slate-700"
                      >
                        <Bell :size="20" :stroke-width="1.5" />
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                        >Notificaciones</span
                      >
                    </div>
                    <!-- Toggle Switch -->
                    <label class="relative inline-flex items-center cursor-pointer">
                      <input v-model="notificationsEnabled" type="checkbox" class="sr-only peer" />
                      <div
                        class="w-11 h-6 bg-slate-200 dark:bg-slate-700 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-slate-600 peer-checked:bg-primary"
                      ></div>
                    </label>
                  </div>
                </div>
              </div>

              <!-- Group: Soporte -->
              <div>
                <h3
                  class="px-3 mb-3 text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-widest"
                >
                  Soporte
                </h3>
                <div class="space-y-1">
                  <!-- Item: Centro de Ayuda -->
                  <button
                    @click="navigateToHelp"
                    class="w-full flex items-center justify-between p-3 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-all group focus:outline-none focus:bg-slate-50 dark:focus:bg-slate-800"
                  >
                    <div class="flex items-center gap-4">
                      <div
                        class="w-10 h-10 shrink-0 rounded-xl bg-slate-50 dark:bg-slate-800/80 flex items-center justify-center text-slate-600 dark:text-slate-400 group-hover:bg-white dark:group-hover:bg-slate-700 group-hover:shadow-sm transition-all border border-transparent group-hover:border-slate-100 dark:group-hover:border-slate-700"
                      >
                        <HelpCircle :size="20" :stroke-width="1.5" />
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                        >Centro de Ayuda</span
                      >
                    </div>
                  </button>

                  <!-- Item: Contactar Soporte -->
                  <button
                    class="w-full flex items-center justify-between p-3 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-all group focus:outline-none focus:bg-slate-50 dark:focus:bg-slate-800"
                  >
                    <div class="flex items-center gap-4">
                      <div
                        class="w-10 h-10 shrink-0 rounded-xl bg-slate-50 dark:bg-slate-800/80 flex items-center justify-center text-slate-600 dark:text-slate-400 group-hover:bg-white dark:group-hover:bg-slate-700 group-hover:shadow-sm transition-all border border-transparent group-hover:border-slate-100 dark:group-hover:border-slate-700"
                      >
                        <MessageSquare :size="20" :stroke-width="1.5" />
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                        >Contactar Soporte</span
                      >
                    </div>
                  </button>

                  <!-- Item: Términos y Condiciones -->
                  <button
                    class="w-full flex items-center justify-between p-3 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-all group focus:outline-none focus:bg-slate-50 dark:focus:bg-slate-800"
                  >
                    <div class="flex items-center gap-4">
                      <div
                        class="w-10 h-10 shrink-0 rounded-xl bg-slate-50 dark:bg-slate-800/80 flex items-center justify-center text-slate-600 dark:text-slate-400 group-hover:bg-white dark:group-hover:bg-slate-700 group-hover:shadow-sm transition-all border border-transparent group-hover:border-slate-100 dark:group-hover:border-slate-700"
                      >
                        <FileText :size="20" :stroke-width="1.5" />
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                        >Términos y Condiciones</span
                      >
                    </div>
                  </button>
                </div>
              </div>
            </template>

            <!-- Employee-only sections -->
            <template v-else>
              <!-- Group: Preferencias -->
              <div>
                <h3
                  class="px-3 mb-3 text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-widest"
                >
                  Preferencias
                </h3>
                <div class="space-y-1">
                  <!-- Item: Sonidos de Venta -->
                  <div
                    class="w-full flex items-center justify-between p-3 rounded-xl hover:bg-gray-50 dark:hover:bg-slate-800/50 transition-all group"
                  >
                    <div class="flex items-center gap-4">
                      <div
                        class="w-10 h-10 shrink-0 rounded-xl bg-slate-50 dark:bg-slate-800/80 flex items-center justify-center text-slate-600 dark:text-slate-400 group-hover:bg-white dark:group-hover:bg-slate-700 group-hover:shadow-sm transition-all border border-transparent group-hover:border-slate-100 dark:group-hover:border-slate-700"
                      >
                        <Volume2 :size="20" :stroke-width="1.5" />
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                        >Sonidos de Venta</span
                      >
                    </div>
                    <label class="relative inline-flex items-center cursor-pointer">
                      <input v-model="saleSoundsEnabled" type="checkbox" class="sr-only peer" />
                      <div
                        class="w-11 h-6 bg-slate-200 dark:bg-slate-700 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-slate-600 peer-checked:bg-primary"
                      ></div>
                    </label>
                  </div>

                  <!-- Item: Modo Oscuro -->
                  <div
                    class="w-full flex items-center justify-between p-3 rounded-xl hover:bg-gray-50 dark:hover:bg-slate-800/50 transition-all group"
                  >
                    <div class="flex items-center gap-4">
                      <div
                        class="w-10 h-10 shrink-0 rounded-xl bg-slate-50 dark:bg-slate-800/80 flex items-center justify-center text-slate-600 dark:text-slate-400 group-hover:bg-white dark:group-hover:bg-slate-700 group-hover:shadow-sm transition-all border border-transparent group-hover:border-slate-100 dark:group-hover:border-slate-700"
                      >
                        <Moon :size="20" :stroke-width="1.5" />
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                        >Modo Oscuro</span
                      >
                    </div>
                    <label class="relative inline-flex items-center cursor-pointer">
                      <input
                        v-model="darkModeEnabled"
                        @change="toggleDarkMode"
                        type="checkbox"
                        class="sr-only peer"
                      />
                      <div
                        class="w-11 h-6 bg-slate-200 dark:bg-slate-700 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full rtl:peer-checked:after:-translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-slate-600 peer-checked:bg-primary"
                      ></div>
                    </label>
                  </div>
                </div>
              </div>

              <!-- Group: Ayuda y Soporte -->
              <div>
                <h3
                  class="px-3 mb-3 text-[11px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-widest"
                >
                  Ayuda y Soporte
                </h3>
                <div class="space-y-1">
                  <button
                    class="w-full flex items-center justify-between p-3 rounded-xl hover:bg-gray-50 dark:hover:bg-slate-800/50 transition-all group focus:outline-none focus:bg-gray-50 dark:focus:bg-slate-800"
                  >
                    <div class="flex items-center gap-4">
                      <div
                        class="w-10 h-10 shrink-0 rounded-xl bg-slate-50 dark:bg-slate-800/80 flex items-center justify-center text-slate-600 dark:text-slate-400 group-hover:bg-white dark:group-hover:bg-slate-700 group-hover:shadow-sm transition-all border border-transparent group-hover:border-slate-100 dark:group-hover:border-slate-700"
                      >
                        <BookOpen :size="20" :stroke-width="1.5" />
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                        >Ver Tutoriales</span
                      >
                    </div>
                    <ChevronRight :size="18" :stroke-width="1.5" class="text-slate-400" />
                  </button>

                  <button
                    class="w-full flex items-center justify-between p-3 rounded-xl hover:bg-gray-50 dark:hover:bg-slate-800/50 transition-all group focus:outline-none focus:bg-gray-50 dark:focus:bg-slate-800"
                  >
                    <div class="flex items-center gap-4">
                      <div
                        class="w-10 h-10 shrink-0 rounded-xl bg-slate-50 dark:bg-slate-800/80 flex items-center justify-center text-slate-600 dark:text-slate-400 group-hover:bg-white dark:group-hover:bg-slate-700 group-hover:shadow-sm transition-all border border-transparent group-hover:border-slate-100 dark:group-hover:border-slate-700"
                      >
                        <Flag :size="20" :stroke-width="1.5" />
                      </div>
                      <span class="text-sm font-medium text-slate-700 dark:text-slate-200"
                        >Reportar un problema</span
                      >
                    </div>
                    <ChevronRight :size="18" :stroke-width="1.5" class="text-slate-400" />
                  </button>
                </div>
              </div>

              <!-- Info Banner for Employee -->
              <div class="mt-4 mx-2">
                <div
                  class="bg-blue-50 dark:bg-blue-900/20 p-4 rounded-xl flex items-start gap-3 border border-blue-100 dark:border-blue-900/30"
                >
                  <ShieldCheck :size="18" :stroke-width="1.5" class="text-blue-500 shrink-0 mt-0.5" />
                  <p class="text-xs text-blue-800 dark:text-blue-200 leading-relaxed font-medium">
                    Tu cuenta es gestionada por el administrador. Para cambiar tu PIN o datos
                    personales, contacta a tu jefe.
                  </p>
                </div>
              </div>
            </template>
          </div>

          <!-- Footer (Logout) -->
          <div
            class="p-4 border-t border-slate-100 dark:border-slate-800 bg-white dark:bg-[#1a2632] shrink-0 pb-8"
          >
            <button
              @click="handleLogout"
              class="w-full flex items-center justify-center gap-2 p-3.5 rounded-xl bg-red-50 hover:bg-red-100 text-red-600 dark:bg-red-900/20 dark:hover:bg-red-900/30 dark:text-red-400 transition-colors font-semibold shadow-sm border border-transparent focus:outline-none focus:ring-2 focus:ring-red-500/50"
            >
              <LogOut :size="18" :stroke-width="1.5" />
              Cerrar Sesión
            </button>
            <p
              class="text-center text-[10px] uppercase tracking-widest text-slate-400 dark:text-slate-500 mt-4 font-bold"
            >
              Versión 1.0.2 - Build 2025
            </p>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>

  <!-- Password Change Modal -->
  <ChangePasswordModal v-model="showPasswordModal" />
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

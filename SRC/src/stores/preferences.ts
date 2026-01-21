/**
 * T-011: Store para persistir preferencias del usuario
 * Notificaciones, sonidos y otras configuraciones personales
 */
import { defineStore } from 'pinia';
import { ref } from 'vue';

export const usePreferencesStore = defineStore(
  'preferences',
  () => {
    // Preferencias
    const notificationsEnabled = ref(true);
    const saleSoundsEnabled = ref(true);
    const darkModeEnabled = ref(false);
    const showTutorials = ref(true);

    // Methods
    const toggleNotifications = () => {
      notificationsEnabled.value = !notificationsEnabled.value;
    };

    const toggleSaleSounds = () => {
      saleSoundsEnabled.value = !saleSoundsEnabled.value;
    };

    const toggleDarkMode = () => {
      darkModeEnabled.value = !darkModeEnabled.value;
      document.documentElement.classList.toggle('dark', darkModeEnabled.value);
    };

    const toggleTutorials = () => {
      showTutorials.value = !showTutorials.value;
    };

    // Aplicar dark mode al inicializar
    const initializeDarkMode = () => {
      document.documentElement.classList.toggle('dark', darkModeEnabled.value);
    };

    return {
      notificationsEnabled,
      saleSoundsEnabled,
      darkModeEnabled,
      showTutorials,
      toggleNotifications,
      toggleSaleSounds,
      toggleDarkMode,
      toggleTutorials,
      initializeDarkMode,
    };
  },
  {
    persist: {
      key: 'tienda-preferences',
      storage: localStorage,
    },
  },
);

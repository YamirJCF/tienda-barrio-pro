<template>
  <div 
    class="relative inline-block text-left" 
    :class="isOpen ? 'z-50' : 'z-10'"
    ref="dropdownRef"
  >
    <!-- Trigger Button -->
    <button
      type="button"
      @click="toggleDropdown"
      :disabled="disabled"
      :aria-expanded="isOpen"
      aria-haspopup="listbox"
      class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-semibold border transition-all cursor-pointer active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed select-none"
      :class="isActiveSelection
        ? 'bg-primary/10 text-primary border-primary/30 dark:bg-primary/20 dark:text-blue-400 dark:border-primary/40 font-bold shadow-sm'
        : 'bg-white dark:bg-slate-800/90 text-slate-700 dark:text-slate-200 border-gray-200 dark:border-slate-700 hover:border-slate-400 dark:hover:border-slate-500'"
    >
      <span class="truncate max-w-[150px]">{{ currentLabel }}</span>
      <ChevronDown 
        :size="14" 
        class="transition-transform duration-200 shrink-0 text-slate-400"
        :class="{ 'rotate-180': isOpen }" 
      />
    </button>

    <!-- Dropdown Menu Panel -->
    <Transition
      enter-active-class="transition duration-100 ease-out"
      enter-from-class="transform scale-95 opacity-0"
      enter-to-class="transform scale-100 opacity-100"
      leave-active-class="transition duration-75 ease-in"
      leave-from-class="transform scale-100 opacity-100"
      leave-to-class="transform scale-95 opacity-0"
    >
      <div
        v-if="isOpen"
        class="absolute top-full mt-1.5 z-50 min-w-[200px] max-w-[280px] w-max bg-white dark:bg-slate-800 border border-gray-200 dark:border-slate-700 rounded-2xl shadow-xl overflow-hidden focus:outline-none"
        :class="alignRight ? 'right-0' : 'left-0'"
        role="listbox"
      >
        <!-- Mini buscador interno si hay más de searchThreshold opciones -->
        <div v-if="shouldShowSearch" class="p-2 border-b border-gray-100 dark:border-slate-700/60">
          <div class="relative flex items-center">
            <Search :size="13" class="absolute left-2.5 text-slate-400" />
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Buscar..."
              class="w-full text-xs pl-7 pr-2.5 py-1.5 bg-gray-50 dark:bg-slate-900 border border-gray-200 dark:border-slate-700 rounded-lg text-slate-800 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-1 focus:ring-primary"
            />
          </div>
        </div>

        <!-- Lista de Opciones -->
        <div class="max-h-60 overflow-y-auto py-1 [&::-webkit-scrollbar]:hidden [-ms-overflow-style:none] [scrollbar-width:none]">
          <div
            v-for="opt in filteredOptions"
            :key="opt.value"
            @click="selectOption(opt.value)"
            role="option"
            :aria-selected="opt.value === modelValue"
            class="px-3.5 py-2 text-xs flex items-center justify-between cursor-pointer transition-colors active:bg-gray-200 dark:active:bg-slate-700"
            :class="opt.value === modelValue
              ? 'bg-primary/10 text-primary font-bold dark:bg-primary/20 dark:text-blue-400'
              : 'text-slate-700 dark:text-slate-200 hover:bg-gray-100 dark:hover:bg-slate-700/60'"
          >
            <span class="truncate">{{ opt.label }}</span>
            <Check v-if="opt.value === modelValue" :size="13" class="stroke-[2.5] text-primary dark:text-blue-400 shrink-0 ml-2" />
          </div>

          <div v-if="filteredOptions.length === 0" class="px-3.5 py-3 text-xs text-slate-400 text-center italic">
            Sin coincidencias
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { ChevronDown, Check, Search } from 'lucide-vue-next';

export interface DropdownOption {
  value: string;
  label: string;
}

const props = withDefaults(
  defineProps<{
    modelValue: string;
    options: DropdownOption[];
    prefixLabel?: string;
    searchable?: boolean;
    searchThreshold?: number;
    disabled?: boolean;
  }>(),
  {
    prefixLabel: '',
    searchable: false,
    searchThreshold: 8,
    disabled: false,
  }
);

const emit = defineEmits<{
  'update:modelValue': [value: string];
}>();

const isOpen = ref(false);
const searchQuery = ref('');
const dropdownRef = ref<HTMLElement | null>(null);
const alignRight = ref(false);

const currentOption = computed(() =>
  props.options.find((o) => o.value === props.modelValue)
);

const currentLabel = computed(() => {
  const lbl = currentOption.value ? currentOption.value.label : props.modelValue;
  return props.prefixLabel ? `${props.prefixLabel}: ${lbl}` : lbl;
});

const isActiveSelection = computed(() => {
  return props.modelValue !== 'all' && props.modelValue !== 'created_desc' && props.modelValue !== 'ALL' && props.modelValue !== 'week';
});

const shouldShowSearch = computed(() => {
  return props.searchable || props.options.length > props.searchThreshold;
});

const filteredOptions = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  if (!q) return props.options;
  return props.options.filter((o) => o.label.toLowerCase().includes(q));
});

const toggleDropdown = () => {
  if (props.disabled) return;
  isOpen.value = !isOpen.value;
  if (isOpen.value) {
    searchQuery.value = '';
    if (dropdownRef.value && typeof window !== 'undefined') {
      const rect = dropdownRef.value.getBoundingClientRect();
      alignRight.value = rect.left + 240 > window.innerWidth;
    }
  }
};

const selectOption = (val: string) => {
  emit('update:modelValue', val);
  isOpen.value = false;
};

// Cerrar al hacer clic fuera o pulsar Esc
const handleClickOutside = (e: MouseEvent) => {
  if (dropdownRef.value && !dropdownRef.value.contains(e.target as Node)) {
    isOpen.value = false;
  }
};

const handleKeyDown = (e: KeyboardEvent) => {
  if (e.key === 'Escape' && isOpen.value) {
    isOpen.value = false;
  }
};

onMounted(() => {
  document.addEventListener('click', handleClickOutside);
  document.addEventListener('keydown', handleKeyDown);
});

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside);
  document.removeEventListener('keydown', handleKeyDown);
});
</script>

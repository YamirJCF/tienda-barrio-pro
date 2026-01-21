<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import type { Product, MeasurementUnit } from '../stores/inventory';
import { Decimal } from 'decimal.js';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';

// WO: UNIT_LABELS definido localmente (antes importado de sampleData eliminado)
const UNIT_LABELS: Record<string, string> = {
  un: 'Unidades',
  kg: 'Kilogramos',
  g: 'Gramos',
  lb: 'Libras',
  l: 'Litros',
  ml: 'Mililitros',
};

// Conversion factors to base unit (grams)
const TO_GRAMS: Record<string, number> = {
  g: 1,
  kg: 1000,
  lb: 453.592,
};

// Props
interface Props {
  modelValue: boolean;
  product: Product | null;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  confirm: [{ product: Product; quantity: Decimal; subtotal: Decimal }];
}>();

// Composables
const { roundHybrid50 } = useCurrencyFormat();

// State
const inputMode = ref<'weight' | 'value'>('value');
const inputValue = ref('');
const sellUnit = ref<MeasurementUnit>('lb'); // Default sell unit

// Initialize sell unit from product when it changes
watch(
  () => props.product,
  (product) => {
    if (product) {
      sellUnit.value = product.measurementUnit;
      inputValue.value = '';
    }
  },
);

// Convert between units
const convertUnits = (
  value: Decimal,
  fromUnit: MeasurementUnit,
  toUnit: MeasurementUnit,
): Decimal => {
  if (fromUnit === toUnit) return value;

  // Convert to grams first, then to target unit
  const inGrams = value.times(TO_GRAMS[fromUnit] || 1);
  return inGrams.div(TO_GRAMS[toUnit] || 1);
};

// Price per unit based on sell unit (converted from product's base unit)
const pricePerSellUnit = computed(() => {
  if (!props.product) return new Decimal(0);

  const basePrice = props.product.price;
  const baseUnit = props.product.measurementUnit;

  if (baseUnit === sellUnit.value) return basePrice;

  // Convert: if base is kg at $5000, and selling in g, price per g = $5000/1000 = $5
  const baseToGrams = TO_GRAMS[baseUnit] || 1;
  const sellToGrams = TO_GRAMS[sellUnit.value] || 1;

  // Price per gram = base price / grams in base unit
  // Price per sell unit = price per gram * grams in sell unit
  return basePrice.div(baseToGrams).times(sellToGrams);
});

// Calculated weight in sell unit
const calculatedWeight = computed(() => {
  if (!props.product || !inputValue.value) return new Decimal(0);
  const value = new Decimal(inputValue.value || 0);

  if (inputMode.value === 'value') {
    // peso = valor / precio_por_unidad_de_venta
    if (pricePerSellUnit.value.isZero()) return new Decimal(0);
    return value.div(pricePerSellUnit.value);
  } else {
    return value;
  }
});

// Calculated value (redondeado a múltiplos de $50)
const calculatedValue = computed(() => {
  if (!props.product || !inputValue.value) return new Decimal(0);
  const value = new Decimal(inputValue.value || 0);

  if (inputMode.value === 'weight') {
    return roundHybrid50(value.times(pricePerSellUnit.value));
  } else {
    return roundHybrid50(value);
  }
});

// Quantity in product's base unit (for stock update)
const quantityInBaseUnit = computed(() => {
  if (!props.product) return new Decimal(0);
  return convertUnits(calculatedWeight.value, sellUnit.value, props.product.measurementUnit);
});

const isValid = computed(() => {
  if (!inputValue.value) return false;
  const val = new Decimal(inputValue.value || 0);
  return val.gt(0);
});

const formattedPrice = computed(() => {
  return formatCurrency(pricePerSellUnit.value);
});

const sellUnitLabel = computed(() => {
  return UNIT_LABELS[sellUnit.value] || sellUnit.value;
});

const formattedResult = computed(() => {
  if (inputMode.value === 'value') {
    return `= ${calculatedWeight.value.toFixed(3)} ${sellUnit.value}`;
  } else {
    return `= ${formatCurrency(calculatedValue.value)}`;
  }
});

// Methods
const formatCurrency = (val: Decimal) => {
  return `$ ${val
    .toDecimalPlaces(0)
    .toString()
    .replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`;
};

const close = () => {
  emit('update:modelValue', false);
  inputValue.value = '';
};

const confirm = () => {
  if (!props.product || !isValid.value) return;

  emit('confirm', {
    product: props.product,
    quantity: quantityInBaseUnit.value, // Always in product's base unit
    subtotal: calculatedValue.value,
  });

  close();
};

const handleNumpad = (value: string) => {
  if (value === 'backspace') {
    inputValue.value = inputValue.value.slice(0, -1);
  } else if (value === '.' && inputValue.value.includes('.')) {
    return;
  } else {
    inputValue.value += value;
  }
};

const clear = () => {
  inputValue.value = '';
};
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div
        v-if="modelValue && product"
        class="fixed inset-0 z-50 flex items-end justify-center bg-gray-800/80"
        @click.self="close"
      >
        <div
          class="w-full max-w-[480px] mx-auto bg-white dark:bg-background-dark rounded-t-2xl shadow-2xl flex flex-col animate-slide-up"
        >
          <!-- Header -->
          <div class="bg-gradient-to-r from-primary to-blue-600 text-white p-4 rounded-t-2xl">
            <div class="flex justify-center mb-2">
              <div class="h-1.5 w-12 rounded-full bg-white/30" @click="close"></div>
            </div>
            <div class="flex items-center justify-between">
              <div>
                <h2 class="text-lg font-bold">{{ product.name }}</h2>
                <p class="text-sm opacity-90">{{ formattedPrice }} / {{ sellUnitLabel }}</p>
              </div>
              <span class="material-symbols-outlined text-3xl opacity-70">scale</span>
            </div>
          </div>

          <!-- Sell Unit Selector -->
          <div
            class="p-3 border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-900"
          >
            <div
              class="text-[10px] font-bold text-gray-500 uppercase tracking-wider mb-2 text-center"
            >
              Vender en:
            </div>
            <div class="flex gap-2">
              <button
                type="button"
                class="flex-1 h-9 rounded-lg flex items-center justify-center text-xs font-bold transition-all"
                :class="
                  sellUnit === 'kg'
                    ? 'bg-primary text-white'
                    : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 border border-gray-200 dark:border-gray-700'
                "
                @click="
                  sellUnit = 'kg';
                  clear();
                "
              >
                kg
              </button>
              <button
                type="button"
                class="flex-1 h-9 rounded-lg flex items-center justify-center text-xs font-bold transition-all"
                :class="
                  sellUnit === 'lb'
                    ? 'bg-primary text-white'
                    : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 border border-gray-200 dark:border-gray-700'
                "
                @click="
                  sellUnit = 'lb';
                  clear();
                "
              >
                Libras
              </button>
              <button
                type="button"
                class="flex-1 h-9 rounded-lg flex items-center justify-center text-xs font-bold transition-all"
                :class="
                  sellUnit === 'g'
                    ? 'bg-primary text-white'
                    : 'bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 border border-gray-200 dark:border-gray-700'
                "
                @click="
                  sellUnit = 'g';
                  clear();
                "
              >
                Gramos
              </button>
            </div>
          </div>

          <!-- Mode Toggle -->
          <div class="p-4 border-b border-gray-100 dark:border-gray-800">
            <div class="bg-gray-100 dark:bg-gray-800 p-1 rounded-lg flex h-10">
              <button
                type="button"
                class="flex-1 flex items-center justify-center gap-2 rounded-md text-xs font-bold transition-all"
                :class="
                  inputMode === 'weight'
                    ? 'bg-white dark:bg-gray-700 text-primary shadow-sm'
                    : 'text-gray-500 dark:text-gray-400'
                "
                @click="
                  inputMode = 'weight';
                  clear();
                "
              >
                <span class="material-symbols-outlined text-[16px]">scale</span>
                Por Peso
              </button>
              <button
                type="button"
                class="flex-1 flex items-center justify-center gap-2 rounded-md text-xs font-bold transition-all"
                :class="
                  inputMode === 'value'
                    ? 'bg-white dark:bg-gray-700 text-primary shadow-sm'
                    : 'text-gray-500 dark:text-gray-400'
                "
                @click="
                  inputMode = 'value';
                  clear();
                "
              >
                <span class="material-symbols-outlined text-[16px]">payments</span>
                Por Valor
              </button>
            </div>
          </div>

          <!-- Input Display -->
          <div class="p-5 text-center">
            <div class="text-xs font-bold text-gray-500 uppercase tracking-wider mb-2">
              {{ inputMode === 'value' ? 'Valor a cobrar' : `Cantidad (${sellUnit})` }}
            </div>
            <div
              class="text-4xl font-bold text-gray-900 dark:text-white mb-2 min-h-[48px] tabular-nums"
            >
              {{ inputMode === 'value' ? '$ ' : '' }}{{ inputValue || '0'
              }}{{ inputMode === 'weight' ? ` ${sellUnit}` : '' }}
            </div>
            <div v-if="inputValue" class="text-lg text-primary font-medium">
              {{ formattedResult }}
            </div>
          </div>

          <!-- Numpad -->
          <div class="grid grid-cols-3 gap-2 p-4 bg-gray-50 dark:bg-gray-900">
            <button
              v-for="num in ['7', '8', '9', '4', '5', '6', '1', '2', '3', '.', '0', '00']"
              :key="num"
              class="h-12 rounded-xl bg-white dark:bg-gray-800 text-gray-900 dark:text-white font-bold text-xl shadow-sm active:scale-95 transition-transform border border-gray-100 dark:border-gray-700"
              @click="handleNumpad(num)"
            >
              {{ num }}
            </button>
          </div>

          <!-- Actions -->
          <div
            class="grid grid-cols-2 gap-3 p-4 bg-white dark:bg-background-dark border-t border-gray-100 dark:border-gray-800 pb-8"
          >
            <button
              type="button"
              class="h-12 rounded-xl bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-200 font-bold text-sm hover:bg-gray-200 transition-colors flex items-center justify-center gap-2"
              @click="close"
            >
              <span class="material-symbols-outlined text-[18px]">close</span>
              Cancelar
            </button>
            <button
              type="button"
              class="h-12 rounded-xl bg-primary hover:bg-primary-dark text-white font-bold text-sm shadow-lg transition-colors flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
              :disabled="!isValid"
              @click="confirm"
            >
              <span class="material-symbols-outlined text-[18px]">add_shopping_cart</span>
              Agregar {{ formatCurrency(calculatedValue) }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.modal-enter-active,
.modal-leave-active {
  transition: opacity 0.3s ease;
}

.modal-enter-from,
.modal-leave-to {
  opacity: 0;
}

.animate-slide-up {
  animation: slideUp 0.3s ease-out;
}

@keyframes slideUp {
  from {
    transform: translateY(100%);
  }

  to {
    transform: translateY(0);
  }
}
</style>

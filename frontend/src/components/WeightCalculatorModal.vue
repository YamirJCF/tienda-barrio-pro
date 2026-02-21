<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import type { Product, MeasurementUnit } from '../types';
import { Decimal } from 'decimal.js';
import { useCurrencyFormat } from '../composables/useCurrencyFormat';
import BaseModal from './ui/BaseModal.vue';
import BaseButton from './ui/BaseButton.vue';
import { Scale, Banknote, ShoppingCart, Delete } from 'lucide-vue-next';

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
  } else if (value === '.') {
    // Block decimals in 'value' mode (COP is integer)
    if (inputMode.value === 'value') return;
    // Prevent double dot in 'weight' mode
    if (inputValue.value.includes('.')) return;
    inputValue.value += value;
  } else {
    inputValue.value += value;
  }
};

const clear = () => {
  inputValue.value = '';
};
</script>

<template>
  <BaseModal
    :model-value="modelValue"
    @update:model-value="close"
    content-class="flex flex-col overflow-y-auto"
    max-height="100dvh"
    :show-drag-handle="false"
  >
    <template #header>
        <div class="bg-gradient-to-r from-primary to-blue-600 text-white p-4 w-full">
            <div class="flex justify-center mb-2">
              <div class="h-1.5 w-12 rounded-full bg-white/30" @click="close"></div>
            </div>
            <div class="flex items-center justify-between">
              <div>
                <h2 class="text-lg font-bold">{{ product?.name }}</h2>
                <p class="text-sm opacity-90">{{ formattedPrice }} / {{ sellUnitLabel }}</p>
              </div>
              <Scale :size="30" class="opacity-70" />
            </div>
        </div>
    </template>

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
              <BaseButton
                v-for="unit in ['kg', 'lb', 'g']" 
                :key="unit"
                :variant="sellUnit === unit ? 'primary' : 'outline'"
                size="sm"
                class="flex-1"
                @click="sellUnit = unit as any; clear();"
              >
                {{ unit === 'lb' ? 'Libras' : unit === 'g' ? 'Gramos' : 'kg' }}
              </BaseButton>
            </div>
          </div>

          <!-- Mode Toggle -->
          <div class="px-3 py-2 border-b border-gray-100 dark:border-gray-800">
            <div class="bg-gray-100 dark:bg-gray-800 p-1 rounded-lg flex h-9">
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
                <Scale :size="14" />
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
                <Banknote :size="14" />
                Por Valor
              </button>
            </div>
          </div>

          <!-- Input Display -->
          <div class="px-4 py-3 text-center">
            <div class="text-[10px] font-bold text-gray-500 uppercase tracking-wider mb-1">
              {{ inputMode === 'value' ? 'Valor a cobrar' : `Cantidad (${sellUnit})` }}
            </div>
            <div
              class="text-3xl font-bold text-gray-900 dark:text-white mb-1 min-h-[40px] tabular-nums"
            >
              {{ inputMode === 'value' ? '$ ' : '' }}{{ inputValue || '0'
              }}{{ inputMode === 'weight' ? ` ${sellUnit}` : '' }}
            </div>
            <div v-if="inputValue" class="text-base text-primary font-medium">
              {{ formattedResult }}
            </div>
          </div>

          <!-- Numpad -->
          <div class="grid grid-cols-3 gap-1.5 px-3 py-2 bg-gray-50 dark:bg-gray-900">
            <BaseButton
              v-for="num in ['7', '8', '9', '4', '5', '6', '1', '2', '3', '.', '0', '00']"
              :key="num"
              @click="handleNumpad(num)"
              :disabled="num === '.' && inputMode === 'value'"
              variant="secondary"
              class="h-11 text-lg font-bold bg-white dark:bg-gray-800"
              :class="{ 'opacity-30 cursor-not-allowed': num === '.' && inputMode === 'value' }"
            >
              {{ num }}
            </BaseButton>
            <BaseButton
                @click="handleNumpad('backspace')"
                variant="danger"
                class="bg-rose-100 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400 border-none col-span-3 h-10"
            >
                <Delete :size="18" />
            </BaseButton>
          </div>

    <template #footer>
          <div class="grid grid-cols-2 gap-3 px-4 py-3 bg-white dark:bg-background-dark border-t border-gray-100 dark:border-gray-800 pb-safe">
            <BaseButton
              @click="close"
              variant="secondary"
            >
              Cancelar
            </BaseButton>
            <BaseButton
              @click="confirm"
              :disabled="!isValid"
              variant="primary"
              :icon="ShoppingCart"
            >
              Agregar {{ formatCurrency(calculatedValue) }}
            </BaseButton>
          </div>
    </template>
  </BaseModal>
</template>



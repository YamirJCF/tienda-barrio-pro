<script setup lang="ts">
import { ref, watch } from 'vue';
import BaseModal from './ui/BaseModal.vue';
import BaseInput from './ui/BaseInput.vue';
import BaseButton from './ui/BaseButton.vue';

// Props
interface Props {
  modelValue: boolean;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'update:modelValue': [value: boolean];
  add: [item: { name: string; price: number }];
}>();

// State
const itemName = ref('');
const itemPrice = ref('');
const nameInput = ref<any>(null);

// Methods
const close = () => {
  emit('update:modelValue', false);
  resetForm();
};

const resetForm = () => {
  itemName.value = '';
  itemPrice.value = '';
};

const addItem = () => {
  if (!itemName.value.trim() || !itemPrice.value) return;

  emit('add', {
    name: itemName.value.trim(),
    price: parseFloat(itemPrice.value),
  });
  close();
};

const isValid = () => {
  return itemName.value.trim() !== '' && itemPrice.value !== '' && parseFloat(itemPrice.value) > 0;
};

// Focus input when modal opens
watch(
  () => props.modelValue,
  (isOpen) => {
    if (isOpen) {
      setTimeout(() => {
        nameInput.value?.focus();
      }, 100);
    }
  },
);
</script>

<template>
  <BaseModal
    :model-value="modelValue"
    @update:model-value="close"
    title="Agregar Nota / Varios"
  >
    <!-- Content -->
    <div class="p-4 space-y-4">
      <BaseInput
        ref="nameInput"
        v-model="itemName"
        label="Descripción"
        placeholder="Ej. Servicio, Producto especial..."
      />
      
      <BaseInput
        v-model="itemPrice"
        label="Precio"
        type="number"
        placeholder="0"
        icon="attach_money"
        class="font-bold text-primary"
      />
    </div>

    <!-- Actions -->
    <template #footer>
        <div class="p-4 pt-0 grid grid-cols-2 gap-3 pb-8">
            <BaseButton
                @click="close"
                variant="secondary"
            >
                Cancelar
            </BaseButton>
            <BaseButton
                @click="addItem"
                :disabled="!isValid()"
                variant="primary"
                icon="add"
            >
                Agregar
            </BaseButton>
        </div>
    </template>
  </BaseModal>
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

@keyframes slideUp {
  from {
    transform: translateY(100%);
  }
  to {
    transform: translateY(0);
  }
}

.animate-slide-up {
  animation: slideUp 0.3s ease-out;
}
</style>

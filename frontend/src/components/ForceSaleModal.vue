<template>
  <div v-if="isOpen" class="modal-overlay" @click.self="handleCancel">
    <div class="modal-card">
      <!-- Header -->
      <div class="modal-header">
        <h2>⚠️ Venta Forzada (Excepción Admin)</h2>
        <button class="close-btn" @click="handleCancel" aria-label="Cerrar">×</button>
      </div>

      <!-- Body -->
      <div class="modal-body">
        <div class="warning-banner">
          <p><strong>Stock insuficiente detectado.</strong></p>
          <p>Faltan <strong>{{ totalDeficit }}</strong> unidades en total.</p>
        </div>

        <div class="affected-items">
          <h3>Productos afectados:</h3>
          <ul>
            <li v-for="item in items" :key="item.productId">
              <strong>{{ item.name }}</strong>
              — Solicitado: {{ item.requested }} {{ item.unit }}
              | Disponible: {{ item.available }} {{ item.unit }}
              | Faltan: <strong>{{ item.deficit }}</strong>
            </li>
          </ul>
        </div>

        <div class="justification-section">
          <label for="justification">Justificación (mínimo 10 caracteres):</label>
          <textarea
            id="justification"
            v-model="justification"
            placeholder="Ej: Cliente VIP, ajuste de inventario pendiente, etc."
            rows="3"
            :class="{ 'invalid': showError }"
          ></textarea>
          <p v-if="showError" class="error-text">La justificación debe tener al menos 10 caracteres.</p>
        </div>

        <div class="audit-notice">
          <p>🔒 Esta acción quedará registrada en el log de auditoría.</p>
        </div>
      </div>

      <!-- Footer -->
      <div class="modal-footer">
        <button class="btn-cancel" @click="handleCancel">Cancelar</button>
        <button 
          class="btn-force" 
          @click="handleConfirm"
          :disabled="isProcessing || justification.length < 10"
        >
          {{ isProcessing ? 'Procesando...' : 'Forzar Venta' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import type { ForceSaleItemInfo } from '../composables/useSaleProcessor'

interface Props {
  isOpen: boolean
  items: ForceSaleItemInfo[]
}

const props = defineProps<Props>()
const emit = defineEmits<{
  confirm: [justification: string]
  cancel: []
}>()

const justification = ref('')
const isProcessing = ref(false)
const showError = ref(false)

const totalDeficit = computed(() => {
  return props.items.reduce((sum, item) => sum + item.deficit, 0)
})

const handleConfirm = () => {
  if (justification.value.length < 10) {
    showError.value = true
    return
  }
  showError.value = false
  isProcessing.value = true
  emit('confirm', justification.value)
}

const handleCancel = () => {
  justification.value = ''
  showError.value = false
  isProcessing.value = false
  emit('cancel')
}
</script>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-card {
  background: white;
  border-radius: 12px;
  max-width: 500px;
  width: 90%;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
  animation: slideIn 0.2s ease-out;
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateY(-20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem;
  border-bottom: 1px solid #e5e7eb;
}

.modal-header h2 {
  margin: 0;
  font-size: 1.25rem;
  color: #dc2626;
}

.close-btn {
  background: none;
  border: none;
  font-size: 2rem;
  color: #6b7280;
  cursor: pointer;
  line-height: 1;
  padding: 0;
  width: 32px;
  height: 32px;
}

.close-btn:hover {
  color: #111827;
}

.modal-body {
  padding: 1.5rem;
  max-height: 60vh;
  overflow-y: auto;
}

.warning-banner {
  background: #fef3c7;
  border-left: 4px solid #f59e0b;
  padding: 1rem;
  margin-bottom: 1.5rem;
  border-radius: 4px;
}

.warning-banner p {
  margin: 0.25rem 0;
  color: #92400e;
}

.affected-items {
  margin-bottom: 1.5rem;
}

.affected-items h3 {
  font-size: 0.95rem;
  margin-bottom: 0.5rem;
  color: #374151;
}

.affected-items ul {
  list-style: none;
  padding: 0;
  margin: 0;
}

.affected-items li {
  padding: 0.5rem;
  background: #f9fafb;
  border-radius: 4px;
  margin-bottom: 0.5rem;
  color: #6b7280;
}

.justification-section {
  margin-bottom: 1rem;
}

.justification-section label {
  display: block;
  font-weight: 500;
  margin-bottom: 0.5rem;
  color: #374151;
}

.justification-section textarea {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-family: inherit;
  font-size: 0.95rem;
  resize: vertical;
  transition: border-color 0.2s;
}

.justification-section textarea:focus {
  outline: none;
  border-color: #3b82f6;
}

.justification-section textarea.invalid {
  border-color: #dc2626;
}

.error-text {
  color: #dc2626;
  font-size: 0.85rem;
  margin-top: 0.25rem;
}

.audit-notice {
  background: #eff6ff;
  border-left: 4px solid #3b82f6;
  padding: 0.75rem;
  border-radius: 4px;
}

.audit-notice p {
  margin: 0;
  color: #1e40af;
  font-size: 0.9rem;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  padding: 1.5rem;
  border-top: 1px solid #e5e7eb;
}

.btn-cancel,
.btn-force {
  padding: 0.75rem 1.5rem;
  border-radius: 6px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  border: none;
}

.btn-cancel {
  background: #f3f4f6;
  color: #374151;
}

.btn-cancel:hover {
  background: #e5e7eb;
}

.btn-force {
  background: #dc2626;
  color: white;
}

.btn-force:hover:not(:disabled) {
  background: #b91c1c;
}

.btn-force:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>

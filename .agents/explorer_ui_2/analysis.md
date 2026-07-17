# UI Investigation Report: Client Editing Integration

This report provides the read-only investigation and exact change blueprints for integrating client editing functionality in `ClientDetailView.vue` and correcting the API parameter mapping in `ClientFormModal.vue`.

---

## Executive Summary
1. **ClientDetailView.vue Integration**: The required auth-related imports and computeds already exist. We need to add the `ClientFormModal` import, define a reactive state `showEditModal`, insert a conditional edit button in the options dropdown (before the delete button), and render the modal component at the end of the template.
2. **ClientFormModal.vue Fix**: In the edit branch of the `save()` method, we need to map the ID field to the key `cc` instead of `cedula` when calling `clientsStore.updateClient`.

---

## 1. Investigation of `ClientDetailView.vue`

### 1.1 Import `ClientFormModal`
- **Location**: Around line 11, after other component imports.
- **Proposed Import Statement**:
  ```typescript
  import ClientFormModal from '../components/ClientFormModal.vue';
  ```
- **Lucide Icons**: Since we want to use an icon for "Editar cliente", we should also import the `Edit` icon from `lucide-vue-next` (around line 11-21).
  ```typescript
  import { 
    ArrowLeft, 
    MoreVertical, 
    Trash2, 
    Receipt, 
    Banknote, 
    ShoppingCart, 
    Plus,
    AlertTriangle,
    ChevronLeft,
    Edit // <-- Add this icon
  } from 'lucide-vue-next';
  ```

### 1.2 Import `useAuthStore`
- **Current Observation**: Already imported on line 5:
  ```typescript
  5: import { useAuthStore } from '../stores/auth';
  ```
- **Action**: No new import statement is needed; it is already present.

### 1.3 Reactive State `showEditModal`
- **Location**: Inside the `<script setup>` block, under the `// State` section, after line 34.
- **Proposed Code**:
  ```typescript
  // State
  const paymentAmount = ref('');
  const showPaymentModal = ref(false);
  const showOptionsMenu = ref(false);
  const showDeleteConfirm = ref(false);
  const showDebtAlert = ref(false);
  const showEditModal = ref(false); // <-- Add this state
  ```

### 1.4 Computed `isAdmin`
- **Current Observation**: Already defined on line 27:
  ```typescript
  26: const authStore = useAuthStore();
  27: const isAdmin = computed(() => authStore.isAdmin);
  ```
- **Action**: No new computed property is needed; it is already present and active.

### 1.5 "Editar cliente" Dropdown Button
- **Location**: Inside the dropdown menu container `<div v-if="showOptionsMenu" ...>` (between lines 186 and 187), placed *before* the "Eliminar cliente" button.
- **Proposed Code**:
  ```html
  <!-- Dropdown Menu -->
  <Transition name="dropdown">
    <div
      v-if="showOptionsMenu"
      class="absolute right-0 top-12 bg-white dark:bg-slate-800 rounded-xl shadow-xl border border-slate-200 dark:border-slate-700 overflow-hidden min-w-[180px] z-50"
    >
      <!-- Proposed "Editar cliente" Button -->
      <button
        v-if="isAdmin"
        @click="showEditModal = true; closeOptionsMenu()"
        class="w-full px-4 py-3 flex items-center gap-3 text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors text-left border-b border-slate-100 dark:border-slate-700/50"
      >
        <Edit :size="20" :stroke-width="1.5" />
        <span class="font-medium">Editar cliente</span>
      </button>

      <button
        @click="confirmDelete"
        class="w-full px-4 py-3 flex items-center gap-3 text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors text-left"
      >
        <Trash2 :size="20" :stroke-width="1.5" />
        <span class="font-medium">Eliminar cliente</span>
      </button>
    </div>
  </Transition>
  ```

### 1.6 Render `<ClientFormModal>`
- **Location**: At the end of the `<template>` block, right before the closing tag `</div>` on line 428.
- **Proposed Code**:
  ```html
      <!-- Debt Blocking Alert Modal -->
      <BaseModal
        v-model="showDebtAlert"
        title="Acción Denegada"
      >
          <!-- ... modal content ... -->
      </BaseModal>

      <!-- Render Edit Client Modal -->
      <ClientFormModal 
        v-model="showEditModal" 
        :client-id="clientId" 
        @saved="showEditModal = false" 
      />
    </div>
  </template>
  ```

---

## 2. Investigation of `ClientFormModal.vue`

### 2.1 Update Key in `save()` Method
- **Current Observation**: On line 84, inside the `isEdit` conditional block, the object `updateData` uses the key `cedula` to pass the identification number:
  ```typescript
  81:     if (isEdit.value && props.clientId) {
  82:       const updateData = {
  83:           name: data.name,
  84:           cedula: data.cc,
  85:           phone: data.phone,
  86:           creditLimit: data.creditLimit
  87:       };
  88:       client = await clientsStore.updateClient(props.clientId, updateData);
  ```
- **Proposed Change**: Replace line 84 to use `cc` instead of `cedula` to align with the backend/store signature:
  ```typescript
  81:     if (isEdit.value && props.clientId) {
  82:       const updateData = {
  83:           name: data.name,
  84:           cc: data.cc, // <-- Changed from cedula: data.cc
  85:           phone: data.phone,
  86:           creditLimit: data.creditLimit
  87:       };
  88:       client = await clientsStore.updateClient(props.clientId, updateData);
  ```

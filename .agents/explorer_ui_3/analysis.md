# UI Exploration Analysis Report

This analysis outlines the required changes to integrate client editing capabilities and fix the data mapping for updating clients in the frontend components.

---

## 1. Investigation of `ClientDetailView.vue`

Path: `frontend/src/views/ClientDetailView.vue`

### 1.1 Importing `ClientFormModal`
- **Location**: In the `<script setup lang="ts">` block, around line 10, next to the other component imports.
- **Proposed Code**:
  ```typescript
  import ClientFormModal from '../components/ClientFormModal.vue';
  ```

### 1.2 Importing `useAuthStore`
- **Location**: Line 5 of the file already contains this import:
  ```typescript
  import { useAuthStore } from '../stores/auth';
  ```
- **Finding**: No changes needed; it is already imported.

### 1.3 Adding Reactive State `showEditModal`
- **Location**: Inside the state section, around line 35 (after other modal and option menu refs).
- **Proposed Code**:
  ```typescript
  const showEditModal = ref(false);
  ```

### 1.4 Adding Computed Property `isAdmin`
- **Location**: Line 27 already defines this property:
  ```typescript
  const isAdmin = computed(() => authStore.isAdmin);
  ```
- **Finding**: No changes needed; it is already defined.

### 1.5 Adding "Editar cliente" Button in Options Dropdown Menu
- **Location**: Inside the `<template>` block, inside the dropdown container (lines 182-196), immediately before the "Eliminar cliente" button (line 187).
- **Proposed Code**:
  ```html
  <!-- Dropdown Menu -->
  <Transition name="dropdown">
    <div
      v-if="showOptionsMenu"
      class="absolute right-0 top-12 bg-white dark:bg-slate-800 rounded-xl shadow-xl border border-slate-200 dark:border-slate-700 overflow-hidden min-w-[180px] z-50"
    >
      <!-- NEW EDIT CLIENT BUTTON -->
      <button
        v-if="isAdmin"
        @click="showEditModal = true; showOptionsMenu = false"
        class="w-full px-4 py-3 flex items-center gap-3 text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors text-left"
      >
        <Pencil :size="20" :stroke-width="1.5" />
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
- **Note**: The `Pencil` (or another edit-related icon) needs to be imported from `lucide-vue-next` if used (at lines 11-21).

### 1.6 Rendering `<ClientFormModal>`
- **Location**: Near the end of the template block, right before the closing `</div>` tag of the main container (line 428).
- **Proposed Code**:
  ```html
      <!-- Client Edit Form Modal -->
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

Path: `frontend/src/components/ClientFormModal.vue`

### 2.1 Mapping ID Key for Client Update
- **Location**: Inside the `save()` method, specifically within the `isEdit` conditional block at lines 81-88.
- **Original Code (lines 82-87)**:
  ```typescript
  const updateData = {
      name: data.name,
      cedula: data.cc,
      phone: data.phone,
      creditLimit: data.creditLimit
  };
  ```
- **Proposed Modification**: Change `cedula` to `cc` to match the expected interface structure for updating client records.
- **New Code**:
  ```typescript
  const updateData = {
      name: data.name,
      cc: data.cc,
      phone: data.phone,
      creditLimit: data.creditLimit
  };
  ```

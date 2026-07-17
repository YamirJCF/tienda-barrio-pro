# Analysis of Client Editing UI Integration

This document outlines the findings of the investigation on how to integrate the client editing functionality into `ClientDetailView.vue` and correct the payload property key mismatch in `ClientFormModal.vue`.

---

## 1. Investigation on `ClientDetailView.vue`

### 1.1 Importing `ClientFormModal`
- **Location:** In the `<script setup lang="ts">` section (around lines 8-11).
- **Proposed Code:**
  ```typescript
  import ClientFormModal from '../components/ClientFormModal.vue';
  ```
  This can be placed directly after `import BaseButton from '../components/ui/BaseButton.vue';` on line 10.

### 1.2 Importing `useAuthStore`
- **Status:** **Already present** in the file.
- **Location:** Line 5:
  ```typescript
  import { useAuthStore } from '../stores/auth';
  ```
  No additional import statement is required.

### 1.3 Adding Reactive State `showEditModal`
- **Location:** Inside the `// State` section (around lines 30-34).
- **Proposed Code:**
  ```typescript
  const showEditModal = ref(false);
  ```
  This can be added on line 35, right after `const showDebtAlert = ref(false);`.

### 1.4 Adding Computed Property `isAdmin`
- **Status:** **Already present** in the file.
- **Location:** Lines 26-27:
  ```typescript
  const authStore = useAuthStore();
  const isAdmin = computed(() => authStore.isAdmin);
  ```
  No additional computed property definition is required.

### 1.5 Adding the "Editar cliente" Dropdown Option
- **Location:** Inside the dropdown menu container `<div v-if="showOptionsMenu">` (lines 184-194), placed **before** the "Eliminar cliente" button.
- **Icon Dependency:** We need to import the `Pencil` icon from `lucide-vue-next` (at lines 11-21) to match the standard style of the app.
- **Proposed Code:**
  Update the `lucide-vue-next` import:
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
    Pencil // Added icon
  } from 'lucide-vue-next';
  ```
  Insert the edit option button in the template:
  ```html
  <!-- Dropdown Menu -->
  <Transition name="dropdown">
    <div
      v-if="showOptionsMenu"
      class="absolute right-0 top-12 bg-white dark:bg-slate-800 rounded-xl shadow-xl border border-slate-200 dark:border-slate-700 overflow-hidden min-w-[180px] z-50"
    >
      <button
        v-if="isAdmin"
        @click="showEditModal = true; closeOptionsMenu()"
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

### 1.6 Rendering `ClientFormModal` in the Template
- **Location:** At the very end of the template block (around line 428), right before the closing `</div>` tag of the root element.
- **Proposed Code:**
  ```html
      <!-- Debt Blocking Alert Modal -->
      ...
      </BaseModal>

      <!-- Client Edit Modal -->
      <ClientFormModal
        v-model="showEditModal"
        :client-id="clientId"
        @saved="showEditModal = false"
      />
    </div>
  </template>
  ```

---

## 2. Investigation on `ClientFormModal.vue`

### 2.1 Mismatched Property in `updateData`
- **Location:** Inside the `save()` method, in the block under `if (isEdit.value && props.clientId)` at line 84.
- **Issue:** The payload object is using the key `cedula: data.cc`. However, the clients store or backend expects `cc` instead of `cedula`.
- **Proposed Change:**
  Replace `cedula: data.cc` with `cc: data.cc`.
  ```typescript
  // Before:
  const updateData = {
      name: data.name,
      cedula: data.cc,
      phone: data.phone,
      creditLimit: data.creditLimit
  };

  // After:
  const updateData = {
      name: data.name,
      cc: data.cc,
      phone: data.phone,
      creditLimit: data.creditLimit
  };
  ```

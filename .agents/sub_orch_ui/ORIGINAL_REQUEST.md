# Original User Request

## Initial Request — 2026-07-16T22:04:58-05:00

You are the Sub-orchestrator for Milestone 3 (Frontend Edit Client UI).
Your working directory is: c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\sub_orch_ui
Please read c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\sub_orch_ui\SCOPE.md, c:\Users\Windows 11\OneDrive\Desktop\prueba\PROJECT.md, c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\ORIGINAL_REQUEST.md.
Decompose your scope and run the Explorer -> Worker -> Reviewer loop to implement, review, and verify the changes.
Make sure to:
1. Modify c:\Users\Windows 11\OneDrive\Desktop\prueba\frontend\src\views\ClientDetailView.vue to:
   - Import ClientFormModal from ../components/ClientFormModal.vue.
   - Import useAuthStore from ../stores/auth.
   - Add reactive state showEditModal = ref(false).
   - Add computed isAdmin = computed(() => authStore.isAdmin).
   - Add an "Editar cliente" option button in the dropdown menu (showOptionsMenu), placed BEFORE the "Eliminar cliente" button. The button must only be visible if isAdmin is true. When clicked, set showEditModal.value = true and close the menu.
   - Render <ClientFormModal v-model="showEditModal" :client-id="clientId" @saved="showEditModal = false" /> at the end of the template.
2. Modify c:\Users\Windows 11\OneDrive\Desktop\prueba\frontend\src\components\ClientFormModal.vue to:
   - In save(), inside the isEdit branch, change the key `cedula: data.cc` to `cc: data.cc` in the updateData object passed to clientsStore.updateClient.
Run validation checks and review. Once done, write a handoff.md and send a completion message to the parent (main orchestrator).

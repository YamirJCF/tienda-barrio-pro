## 2026-07-17T03:06:31Z
Your identity is worker_ui_1.
Your working directory is: c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\worker_ui_1

Please implement the following frontend changes:

1. Modify `c:\Users\Windows 11\OneDrive\Desktop\prueba\frontend\src\views\ClientDetailView.vue`:
   - Import `ClientFormModal` from `../components/ClientFormModal.vue`.
   - Import `Pencil` icon from `lucide-vue-next`.
   - Add reactive state `showEditModal = ref(false)`.
   - Ensure computed `isAdmin = computed(() => authStore.isAdmin)` is active and correct.
   - Add an "Editar cliente" option button in the dropdown menu (showOptionsMenu), placed BEFORE the "Eliminar cliente" button. The button must only be visible if `isAdmin` is true. When clicked, set `showEditModal.value = true` and close the menu (using `closeOptionsMenu()`).
   - Render `<ClientFormModal v-model="showEditModal" :client-id="clientId" @saved="showEditModal = false" />` at the end of the template (inside the main/root div, before the closing `</div>` tag).
   
2. Modify `c:\Users\Windows 11\OneDrive\Desktop\prueba\frontend\src\components\ClientFormModal.vue`:
   - In `save()`, inside the `isEdit` branch, change the key `cedula: data.cc` to `cc: data.cc` in the `updateData` object passed to `clientsStore.updateClient`.

Verify the build of the frontend by locating `package.json` and running the build/compile script (e.g., `npm run build` or `npm run type-check`). Document the exact commands and results in your handoff report.

# Scope: Milestone 3 - Frontend Edit Client UI

## Architecture
- Component layer: `ClientDetailView.vue` (detail view for a client) and `ClientFormModal.vue` (modal form for creating/editing clients).
- Auth store: `useAuthStore` to check admin status.

## Milestones
| # | Name | Scope | Status |
|---|------|-------|--------|
| 1 | Enable Edit in ClientDetailView | Import `ClientFormModal` and `useAuthStore` into `ClientDetailView.vue`. Add computed `isAdmin` and reactive state `showEditModal`. Add "Editar cliente" button to dropdown options (visible only for admin). Add `<ClientFormModal>` component to the template. | IN_PROGRESS |
| 2 | Correct mapping in ClientFormModal | Update `save()` in `ClientFormModal.vue` inside `isEdit` block to pass `cc` key instead of `cedula` in the `updateData` object to `clientsStore.updateClient`. | IN_PROGRESS |

## Interface Contracts
- `ClientFormModal` component uses `v-model` for visibility, takes `client-id` prop, and emits `saved` event.

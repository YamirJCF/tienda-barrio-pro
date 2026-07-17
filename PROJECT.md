# Project: Tienda Barrio Pro - Fix Ledger & Client Editing

## Architecture
- Database layer: Supabase PostgreSQL database containing client ledger schema (`client_ledger`) and custom RPC functions (`registrar_abono`). Views are utilized to expose `client_transactions` as read-only virtual tables to client frontend, while writing goes exclusively via the RPC.
- Frontend layer: Vue 3 single page application with Pinia stores and client-side repository services (`clientRepository.ts`).
- Component layer: Client form inputs, detail pages, and modal views.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | DB Migration & RPC | Create DB migration SQL file for backfill, cascade drop table, view creation, and `registrar_abono` RPC function. Also update `clean_database.sql`. | None | IN_PROGRESS (Conv: 246ce8c8-7824-40fc-87cc-b59c4fee1132) |
| 2 | Frontend Store & Repo | Update `clientRepository.ts` to mock offline operations, and `clients.ts` Pinia store action `registerPayment` to call `registrar_abono` RPC. | M1 | PLANNED |
| 3 | Frontend Edit Client UI | Import `ClientFormModal` into `ClientDetailView.vue`, conditionalize "Editar cliente" dropdown button, and fix key mapping in `ClientFormModal.vue` (`cc` instead of `cedula`). | None | IN_PROGRESS (Conv: e39b6a8d-5e6c-478d-acae-d3c9a1cdedea) |
| 4 | Verification & Build | Verify frontend builds successfully, and run tests. | M2, M3 | PLANNED |

## Interface Contracts
### clients.ts store ↔ Supabase RPC `registrar_abono`
- Signature: `registrar_abono(p_client_id: uuid, p_amount: numeric)`
- Output payload:
  ```json
  {
    "success": boolean,
    "error": string | null
  }
  ```

## Code Layout
- Migrations: `supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql`
- Script: `supabase/scripts/clean_database.sql`
- Frontend Repository: `frontend/src/data/repositories/clientRepository.ts`
- Frontend Pinia Store: `frontend/src/stores/clients.ts`
- Vue Component (Modal): `frontend/src/components/ClientFormModal.vue`
- Vue View: `frontend/src/views/ClientDetailView.vue`

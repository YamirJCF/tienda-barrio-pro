# Project Plan: Tienda Barrio Pro - Fix Ledger & Client Editing

This plan outlines the steps for executing the database reconciliation, frontend repository updates, Pinia store adjustments, and the client editing UI capability.

## Project Abstraction & Strategy
To maintain unidirectional data flow (Backend Authority) and system integrity, we structure the project into 4 milestones. Note that Milestone 3 has no backend dependencies and runs in parallel with Milestone 1 and 2:
1. **Milestone 1: Database Migration & RPC (`registrar_abono`)**
   - Create migration SQL to backfill existing payments and purchases from `client_transactions` to `client_ledger`.
   - Recreate the view `client_transactions` based on `client_ledger` with `security_invoker = true`.
   - Grant select permissions on `client_transactions` view.
   - Recreate RPC function `registrar_abono` to insert into `client_ledger` with a negative amount and perform IDOR & balance validation.
   - Modify `supabase/scripts/clean_database.sql` to clean `client_ledger` instead of `client_transactions`.
2. **Milestone 2: Frontend Repository & Store Updates**
   - Update `clientRepository.ts` so `updateDebt`, `addTransaction`, and `updatePendingTransactionSaleId` act as no-ops when Supabase is active.
   - Update `clients.ts` store action `registerPayment` to call the `registrar_abono` RPC, handles local Pinia state, and propagates errors.
3. **Milestone 3: Frontend Edit Client UI (Running in Parallel)**
   - Implement "Editar cliente" button in `ClientDetailView.vue` dropdown (visible only for admin).
   - Show `ClientFormModal` on click, bound to the client details.
   - Fix bug in `ClientFormModal.vue` to map `cc: data.cc` instead of `cedula: data.cc`.
4. **Milestone 4: Verification & Build (Depends on M2 and M3)**
   - Verify linting and build (`npm run build` on frontend).
   - Run tests.

## Orchestration Plan
We will spawn sub-orchestrators (`self` archetype) for milestones. Milestones 1 and 3 are spawned first in parallel. Once Milestone 1 completes, Milestone 2 will be spawned. Once both Milestones 2 and 3 complete, Milestone 4 will perform the final validation.
Each sub-orchestrator will run in its own folder:
- Milestone 1: `.agents/sub_orch_db/`
- Milestone 2: `.agents/sub_orch_repo/`
- Milestone 3: `.agents/sub_orch_ui/`
- Milestone 4: `.agents/sub_orch_verify/`

## Liveness & Heartbeats
We will use the recurring heartbeat cron `task-15` (every 10 minutes) to check in on subagents. If any subagent stalls, we will follow the retry/replace/skip protocol.

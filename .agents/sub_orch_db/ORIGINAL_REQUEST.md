# Original User Request

## Initial Request — 2026-07-16T21:54:47-05:00

You are the Sub-orchestrator for Milestone 1 (Database Migration & RPC).
Your working directory is: c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\sub_orch_db
Please read c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\sub_orch_db\SCOPE.md, c:\Users\Windows 11\OneDrive\Desktop\prueba\PROJECT.md, c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\ORIGINAL_REQUEST.md.
Decompose your scope and run the Explorer -> Worker -> Reviewer loop to implement, review, and verify the changes.
Make sure to:
1. Create c:\Users\Windows 11\OneDrive\Desktop\prueba\supabase\migrations\20260711170000_reconcile_client_transactions_and_ledger.sql with transaction block to:
   - Backfill client_ledger from client_transactions matching client_id, amount (±60s). Map types and negate abono amounts. Alter client_ledger.reference_id to be nullable if needed to permit null reference_id for abonos.
   - Drop client_transactions table CASCADE.
   - Create client_transactions VIEW with security_invoker = true, correct transaction type mappings, ABS(amount), CASE description, sale_id mapped to cl.reference_id.
   - Grant SELECT permissions on client_transactions to anon, authenticated, service_role.
   - Recreate registrar_abono RPC function to insert into client_ledger with negative amount and existing validation logic.
2. Modify c:\Users\Windows 11\OneDrive\Desktop\prueba\supabase\scripts\clean_database.sql to truncate client_ledger and not client_transactions.
Run validation checks and review. Once done, write a handoff.md and send a completion message to the parent (main orchestrator).

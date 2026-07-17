## 2026-07-17T02:57:47Z

You are the Database Developer / Supabase Implementer for Milestone 1.
Your working directory is: c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\worker_db
Please load the supabase-admin skill (path: c:\Users\Windows 11\OneDrive\Desktop\prueba\.agent\skills\supabase-admin\SKILL.md) and implement the changes described in the explorer analysis (c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\explorer_db\analysis.md).

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A Forensic Auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Specifically:
1. Create the migration file:
   `c:\Users\Windows 11\OneDrive\Desktop\prueba\supabase\migrations\20260711170000_reconcile_client_transactions_and_ledger.sql`
   With the SQL content specified in the explorer report. Make sure reference_id is made nullable, backfill is done from `client_transactions` matching `client_id` and amount (within ±60s window, mapping types and negating payments), drop table `client_transactions` cascade, create view `client_transactions` with security_invoker = true, correct transaction type mappings, ABS(amount), and CASE description, grant select permissions, and recreate registrar_abono RPC function.
2. Modify:
   `c:\Users\Windows 11\OneDrive\Desktop\prueba\supabase\scripts\clean_database.sql`
   To replace `public.client_transactions` with `public.client_ledger` in the `TRUNCATE TABLE` list and reset client balances to 0 in the transaction block.
3. Apply the migrations to the database. You can use the `supabase-mcp-server` MCP tools (such as `execute_sql` or `apply_migration`), or run the `supabase` CLI command if available.
4. Verify the database state by running the database validation tests (e.g. `supabase/tests/schema_integrity_test.sql`, `supabase/tests/verify_financial_core.sql`, and any tests under `tests/sql/`). Document the command executed and the results.
Write your completion status to `c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\worker_db\progress.md` and your handoff report to `c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\worker_db\handoff.md`.

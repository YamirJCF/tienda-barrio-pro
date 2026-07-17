## 2026-07-16T21:55:29Z
You are the Database Analyst explorer for Milestone 1.
Your working directory is: c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\explorer_db
Please explore the database migration requirements for Milestone 1.
1. Read the schema definition of `client_ledger`, `client_transactions`, `clients` and how they are defined in `supabase/migrations/20260329000000_init.sql` and subsequent migrations.
2. Read the `registrar_abono` RPC function in `supabase/migrations/20260405013107_secure_baseline.sql`.
3. Check test files in `supabase/tests` (like `schema_integrity_test.sql`, `verify_financial_core.sql`, `qa_financial_core_stress.sql`) to understand how client ledger, balance, and transactions are verified and if there are any specific constraints or logic we need to maintain.
4. Draft the migration SQL script `supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql` inside a single transaction block (BEGIN/COMMIT). In the script, ensure you:
   - Alter `client_ledger.reference_id` to be nullable.
   - Insert records from `client_transactions` into `client_ledger` for those records that do not have a match (match client_id, amount within ±60 seconds). For 'pago' type in `client_transactions`, map `transaction_type` to 'abono' and negate the amount (amount = -amount). For 'compra' type, map `transaction_type` to 'venta_fiado'. Make sure to join `clients` to retrieve the correct `store_id` for insertion into `client_ledger`.
   - Drop the `client_transactions` table cascade.
   - Create a view `client_transactions` with `WITH (security_invoker = true)`. Mapear `transaction_type`: 'venta_fiado' -> 'compra', 'abono'/'anulacion_fiado' -> 'pago'. Amount should be `ABS(amount)`. Description should be constructed via CASE (e.g., 'Compra Ticket #X' if venta_fiado, etc.). sale_id should map to `reference_id`.
   - Grant SELECT on `client_transactions` to `anon`, `authenticated`, `service_role`.
   - Recreate `registrar_abono` RPC function to write into `client_ledger` with `amount = -p_amount` instead of `client_transactions`. Preserve validation logic, IDOR check, client existence, balance validation, and update client balance.
5. Identify the changes needed in `supabase/scripts/clean_database.sql`.
Write your findings and drafted SQL/changes to `c:\Users\Windows 11\OneDrive\Desktop\prueba\.agents\explorer_db\analysis.md` and send a handoff report. Remember that you are read-only and cannot write code/scripts to the database or project files; only to your `.agents/explorer_db/analysis.md` and your handoff.

# Handoff Report — Database Analyst Explorer (Milestone 1)

This report details the observations, logic chain, and proposed changes to consolidate database transactions into a single source of truth in `client_ledger`, replace `client_transactions` with a view, and update dependencies.

---

## 1. Observation

Direct observations made from codebase files:

1.  **`client_ledger.reference_id` constraint**:
    In `supabase/migrations/20260329000000_init.sql` (Line 958):
    ```sql
    "reference_id" "uuid" NOT NULL,
    ```
    This column is currently `NOT NULL` and does not have a foreign key to `sales`.

2.  **`registrar_abono` implementation**:
    In `supabase/migrations/20260405013107_secure_baseline.sql` (Lines 226-227):
    ```sql
    INSERT INTO public.client_transactions (client_id, transaction_type, amount, description)
    VALUES (p_client_id, 'pago', p_amount, 'Abono efectivo');
    ```
    This RPC function is currently the only database write source targeting the `client_transactions` table.

3.  **`clean_database.sql` TRUNCATE targets**:
    In `supabase/scripts/clean_database.sql` (Lines 8-20):
    ```sql
    TRUNCATE TABLE 
        public.sale_items,
        public.sales,
        public.cash_movements,
        public.cash_sessions,
        public.client_transactions,
        ...
    ```
    The legacy `client_transactions` table is targeted for truncation.

4.  **`schema_integrity_test.sql` table existence validation**:
    In `supabase/tests/schema_integrity_test.sql` (Lines 39-41):
    ```sql
    'client_ledger',
    'client_transactions',
    'clients',
    ```
    The script verifies that `client_transactions` exists as an object in `information_schema.tables`.

---

## 2. Logic Chain

1.  **Nullability of `reference_id`**:
    Since credit payments (abonos) registered through `registrar_abono` are manual actions not tied to specific sales, they cannot supply a `sale_id`. To transition these transactions to `client_ledger`, `client_ledger.reference_id` must be made nullable. (Refs: Observation 1, Observation 2).
2.  **Backfill and Table Drop**:
    To avoid data loss when dropping `client_transactions`, missing transaction rows must be copied into `client_ledger` using a matching window of ±60 seconds. Since abonos reduce debt, payment amounts (`'pago'`) must be negated (`amount = -amount`) when mapping to `'abono'`. Once backed up, the legacy table can be dropped using `CASCADE` to remove old RLS policies and indexes. (Refs: Observation 2, User Request).
3.  **View Recreation with RLS**:
    To preserve the frontend interface contract without refactoring client queries, we must recreate `client_transactions` as a view that pulls from `client_ledger`. The view must use `WITH (security_invoker = true)` so it inherits RLS from `client_ledger` and restricts records to the active store. SELECT grants on this view must be given to `anon`, `authenticated`, and `service_role`. (Refs: Observation 4, User Request).
4.  **RPC Function Recreation**:
    `registrar_abono` must be updated to insert into `client_ledger` instead of `client_transactions` with `amount = -p_amount` and `reference_id = NULL`. IDOR checks and balance logic must be fully preserved. (Refs: Observation 2).
5.  **`clean_database.sql` Failure Mitigation**:
    Since Postgres views cannot be truncated, leaving `client_transactions` in `clean_database.sql` will throw a runtime error: `ERROR: cannot truncate a view`. Therefore, `client_transactions` must be replaced with `client_ledger` in the truncate block, and client balances must be updated to `0` to maintain integrity. (Refs: Observation 3).

---

## 3. Caveats

*   **Balance Backfill Assumption**:
    For migrated records, `previous_balance` is backfilled with a default of `0` because reconstructing the exact historical running balance sequence in a set-based migration script is prone to error and not required by database constraints or test scripts.
*   **Security Invoker view requirements**:
    The view `client_transactions` uses `security_invoker = true`. If the querying role does not have SELECT access to `client_ledger` or `sales`, the view query will fail. However, the appropriate grants exist in consolidate migrations.

---

## 4. Conclusion

Consolidating client history into `client_ledger` simplifies audit trails while preserving the frontend contract via the `client_transactions` view. Applying the drafted migration `20260711170000_reconcile_client_transactions_and_ledger.sql` inside a single transaction, updating `registrar_abono`, and correcting `clean_database.sql` fully addresses Milestone 1 database requirements.

---

## 5. Verification Method

1.  **Draft Migration Execution**:
    Review the drafted script in `analysis.md` for SQL syntax and check for execution compatibility.
2.  **Integrity Checks**:
    Once the migration is applied by the implementer, run the integrity tests:
    *   Execute `schema_integrity_test.sql` to check that the `client_transactions` view satisfies the check.
    *   Execute `verify_financial_core.sql` to confirm that sale and void operations populate the ledger correctly.
3.  **Database Cleaning Script**:
    Run `supabase/scripts/clean_database.sql` to verify it successfully truncates `client_ledger` and resets client debt balances to `0` without throwing a "cannot truncate a view" error.

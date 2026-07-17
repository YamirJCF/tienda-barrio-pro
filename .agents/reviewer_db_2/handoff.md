# Handoff Report — Reviewer DB 2

## 1. Observation

Direct observations from code review:
- **`registrar_abono` definition**:
  - Path: `supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql`
  - Lines 96-100:
    ```sql
    CREATE OR REPLACE FUNCTION public.registrar_abono(p_client_id uuid, p_amount numeric)
     RETURNS json
     LANGUAGE plpgsql
     SECURITY DEFINER
    AS $function$
    ```
  - Line 160:
    ```sql
    ALTER FUNCTION public.registrar_abono(uuid, numeric) OWNER TO postgres;
    ```
- **Backfill query**:
  - Path: `supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql`
  - Lines 40-41:
    ```sql
    FROM public.client_transactions ct
    JOIN public.clients c ON ct.client_id = c.id
    ```
- **View definition**:
  - Path: `supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql`
  - Lines 66-67:
    ```sql
    CREATE OR REPLACE VIEW public.client_transactions 
    WITH (security_invoker = true) AS
    ```
  - Lines 81-83:
    ```sql
        WHEN cl.transaction_type = 'abono' THEN 'Abono efectivo'
        ELSE 'Otro'
    END AS description,
    cl.reference_id AS sale_id,
    cl.created_at
    ```
- **`clean_database.sql` table list**:
  - Path: `supabase/scripts/clean_database.sql`
  - Lines 8-20:
    ```sql
    TRUNCATE TABLE 
        public.sale_items,
        public.sales,
        public.cash_movements,
        public.cash_sessions,
        public.client_ledger,
        public.inventory_movements,
        public.price_change_logs,
        public.daily_passes,
        public.daily_reports,
        public.audit_logs,
        public.error_logs
    CASCADE;
    ```
- **`00_seed_data.sql` table list**:
  - Path: `tests/sql/00_seed_data.sql`
  - Lines 11-18:
    ```sql
    TRUNCATE TABLE sale_items CASCADE;
    TRUNCATE TABLE sales CASCADE;
    TRUNCATE TABLE inventory_movements CASCADE;
    TRUNCATE TABLE client_ledger CASCADE;
    TRUNCATE TABLE clients CASCADE;
    TRUNCATE TABLE products CASCADE;
    TRUNCATE TABLE employees CASCADE;
    TRUNCATE TABLE stores CASCADE;
    ```
- **`00_seed_data.sql` client seeding**:
  - Path: `tests/sql/00_seed_data.sql`
  - Line 135:
    ```sql
    ('11111111-1111-1111-1111-111111111111', 'Cliente Fiador', 'C002', '3109876543', 500000, 150000), -- Debe 150k
    ```
  - No inserts to `client_ledger` exist in `00_seed_data.sql`.

## 2. Logic Chain

1. **`registrar_abono` security and ownership**: We observed that `SECURITY DEFINER` and ownership `postgres` are applied. However, the function does not set the `search_path`. Without a secure `search_path`, PostgreSQL will look up unqualified functions/operators (e.g. `json_build_object`, `=`) using the caller's search path, creating a potential path hijacking vulnerability.
2. **Missing `p_amount` validation**: Since the `client_transactions` table check constraint `amount > 0` was dropped (and views don't have constraints), and `registrar_abono` has no `p_amount > 0` check, a negative payment amount passed to the RPC would be allowed. This would result in adding debt to the client's balance in `clients` and inserting a positive value in `client_ledger` with type `abono`.
3. **Backfill join correctness**: The query uses `JOIN public.clients c ON ct.client_id = c.id` and maps `c.store_id` to the store ID in the ledger. Since client records are scoped by store, this maps the store ID correctly.
4. **View columns mapping**: The view maps `reference_id` as `sale_id`, `created_at` directly, dynamically constructs `description` (handling ticket number lookups), and sets `WITH (security_invoker = true)`. This conforms fully to the view specifications.
5. **View truncation prevention**: We verified that `clean_database.sql` and `00_seed_data.sql` truncate the underlying `client_ledger` table instead of the `client_transactions` view. This prevents PostgreSQL from throwing the `cannot truncate a view` error.
6. **Data consistency in seeding**: We observed that 'Cliente Fiador' has a seeded balance of `150000`, but there are no matching ledger records. This results in an inconsistent database state.

## 3. Caveats

- **Time-based backfilling heuristic**: The backfilling query matches transactions and ledger entries using a ±60-second window. In the event of duplicate identical transactions for the same client in that window, one might be skipped.
- **Local DB test execution**: Live database test execution was not performed due to tool environment restrictions (missing `call_mcp_tool` and cli timeout). Verification relies on detailed static analysis.

## 4. Conclusion

The migration and scripts are functional and prevent direct view truncation bugs, but they introduce two major issues: a missing validation constraint on payment amount (`p_amount <= 0`) in the RPC, and a missing secure `search_path` on the `SECURITY DEFINER` function. Additionally, `00_seed_data.sql` has a minor data inconsistency. Changes should be requested to resolve these issues before merging.

## 5. Verification Method

To verify:
1. Inspect `supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql` for:
   - `IF p_amount <= 0 THEN ...` validation.
   - `SET search_path = public, pg_temp` on `registrar_abono`.
   - `CREATE INDEX IF NOT EXISTS idx_ledger_reference ON public.client_ledger (reference_id);`
2. Run database migration tests (e.g. `supabase db reset`) to ensure the migration executes without error.
3. Call `registrar_abono` with a negative amount and ensure it returns an error rather than updating the balance.

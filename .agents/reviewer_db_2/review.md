# Database Consolidation Review Report

## Review Summary

**Verdict**: REQUEST_CHANGES

The database migration and scripts for Milestone 1 are well-structured and align closely with the requirements. However, there are a few security, validation, and consistency issues that need to be addressed before approval. Specifically, the database-level check constraint on transaction amounts was lost during the table-to-view transition, creating a vulnerability where negative abonos could be processed via the RPC. Additionally, the `SECURITY DEFINER` function lacks a secure `search_path`, and the test seed data contains a minor data inconsistency.

---

## Findings

### [Major] Finding 1: Missing `p_amount` validation in `registrar_abono`
- **What**: The RPC function `registrar_abono` does not check if the payment amount is positive (`p_amount > 0`).
- **Where**: `supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql` (lines 96-157)
- **Why**: The legacy table `client_transactions` had a check constraint `client_transactions_amount_check` (`amount > 0`). Since that table was replaced by a view, this constraint is gone. Without checking `p_amount > 0` inside the RPC function, a malicious or errant caller could pass a negative amount, which would increase the client's balance (debt) and write a positive amount to `client_ledger` under type `abono`, violating business logic.
- **Suggestion**: Add a check at the beginning of the function:
  ```sql
  IF p_amount <= 0 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'El monto del abono debe ser mayor a cero',
      'code', 'INVALID_AMOUNT'
    );
  END IF;
  ```

### [Major] Finding 2: Missing `search_path` on `SECURITY DEFINER` RPC function
- **What**: The function `registrar_abono` is defined as `SECURITY DEFINER` but does not specify a secure `search_path`.
- **Where**: `supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql` (line 99)
- **Why**: In PostgreSQL, `SECURITY DEFINER` functions run with the privileges of the owner (`postgres`). If a secure `search_path` is not explicitly set, a malicious caller could manipulate their local search path to override schema-unqualified functions or operators used inside the function, leading to privilege escalation.
- **Suggestion**: Specify the search path in the function definition:
  ```sql
  CREATE OR REPLACE FUNCTION public.registrar_abono(p_client_id uuid, p_amount numeric)
   RETURNS json
   LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = public, pg_temp
  AS $function$
  ```

### [Minor] Finding 3: Inconsistent client balance in `00_seed_data.sql`
- **What**: The client 'Cliente Fiador' is seeded with a balance of `150000` (debt), but no corresponding entry is inserted in `client_ledger`.
- **Where**: `tests/sql/00_seed_data.sql` (line 135)
- **Why**: This creates an inconsistent initial state where the client has a 150k debt but their transaction history (viewed via `client_transactions` view) is completely empty.
- **Suggestion**: Either set the initial balance to 0 for all clients in the seed script, or insert a corresponding `venta_fiado` record in `client_ledger` with `amount = 150000` for `Cliente Fiador`.

### [Minor] Finding 4: Missing index on `client_ledger.reference_id`
- **What**: There is no index on `client_ledger.reference_id` (which maps to `sale_id`).
- **Where**: `supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql`
- **Why**: Although joining with `sales` on `cl.reference_id = s.id` is fast (since `sales.id` is primary key), any queries filtering the `client_transactions` view by `sale_id` (e.g. checking ledger history for a specific sale) will trigger a sequential scan on the `client_ledger` table.
- **Suggestion**: Add a btree index in the migration file:
  ```sql
  CREATE INDEX IF NOT EXISTS idx_ledger_reference ON public.client_ledger (reference_id);
  ```

### [Minor] Finding 5: API Response envelope alignment
- **What**: The RPC returns `new_balance` at the root of the JSON object instead of nesting it in a `data` key.
- **Where**: `supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql` (lines 152-155)
- **Why**: User Rule 4.2 states that action responses should place success payloads inside a `data` key. 
- **Suggestion**: Wrap the return payload under the `data` key:
  ```sql
  RETURN json_build_object(
    'success', true,
    'data', json_build_object('new_balance', v_new_balance)
  );
  ```
  *(Note: Coordinate this with the frontend implementation of Milestone 2).*

### [Informational] Finding 6: Critical Sequence Risk for Frontend Writes
- **What**: The frontend `clientRepository.ts` attempts to write directly to `'client_transactions'` using `insert` and `update` commands.
- **Where**: `frontend/src/data/repositories/clientRepository.ts` (lines 183 and 231)
- **Why**: Replacing the table with a view makes it read-only. Frontend writes will fail until the frontend is updated to call `registrar_abono` and use simulated offline storage.
- **Suggestion**: Ensure Milestone 2 frontend updates are applied immediately following this database migration.

---

## Verified Claims

- **Alter table reference_id nullable** → verified via static check of line 9 → **PASS** (Correctly drops NOT NULL constraint allowing general abonos).
- **Backfill join logic & store_id mapping** → verified via static check of lines 25-41 → **PASS** (Correctly joins `public.clients` to obtain and insert the matching `store_id`).
- **Backfill transaction type & amount signs** → verified via static check of lines 28-30, 34-37 → **PASS** (Correctly negates payments and maps type strings).
- **Backfill duplicate avoidance (NOT EXISTS)** → verified via static check of lines 42-53 → **PASS** (Checks existing ledger entries within ±60s window).
- **View creation with security_invoker = true** → verified via static check of lines 66-67 → **PASS** (Ensures RLS propagates to the view).
- **View columns mapping** → verified via static check of lines 68-83 → **PASS** (Correctly exposes all legacy columns: `description`, `sale_id`, `created_at`, etc.).
- **View owner & grants** → verified via static check of lines 88 and 91 → **PASS** (Owned by `postgres` and grants SELECT to `anon`, `authenticated`, `service_role`).
- **Clean database script doesn't truncate view** → verified via static check of `clean_database.sql` → **PASS** (Truncates `client_ledger` and updates client balances to 0, avoiding direct view truncation).
- **Test seed script doesn't truncate view** → verified via static check of `00_seed_data.sql` → **PASS** (Truncates `client_ledger` instead of `client_transactions`).

---

## Coverage Gaps

- **Post-migration testing of frontend client ledger operations** — risk level: **medium** — recommendation: **investigate** (Ensure that the end-to-end integration tests are executed once Milestone 2 frontend adjustments are complete).

---

## Unverified Items

- **Database migration execution** — Could not run the migration script against a live database instance because the Supabase local CLI requires interactive permission approval (which timed out) and the `call_mcp_tool` wrapper for Supabase MCP was not registered in the current agent toolset. Static verification was used instead.

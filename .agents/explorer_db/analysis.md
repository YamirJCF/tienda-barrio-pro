# Database Analysis & Migration Design: Reconcile Client Transactions and Ledger

This document details the analysis of client transaction and ledger schemas, RPC functions, and test cases, followed by the drafted SQL migration script for Milestone 1.

---

## 1. Schema Analysis

### 1.1 `public.clients`
*   **Source File**: `supabase/migrations/20260329000000_init.sql`
*   **Key Columns**:
    *   `id` `uuid` (Primary Key, default `gen_random_uuid()`)
    *   `store_id` `uuid` (Foreign Key referencing `stores(id)`)
    *   `name` `text` (Min length 3)
    *   `balance` `numeric(12,0)` (Default 0, constraint `clients_balance_check`: `balance >= 0`)
*   **Role**: Serves as the master record for clients. The `balance` column tracks the client's current outstanding credit (debt) at the store.

### 1.2 `public.client_ledger` (Transactional Source of Truth)
*   **Source File**: `supabase/migrations/20260329000000_init.sql`
*   **Key Columns**:
    *   `id` `uuid` (Primary Key, default `gen_random_uuid()`)
    *   `client_id` `uuid` (Foreign Key referencing `clients(id)`)
    *   `store_id` `uuid` (Foreign Key referencing `stores(id)`)
    *   `amount` `numeric(12,0)` (Positive for sales/credit addition, negative for payments/voids)
    *   `previous_balance` `numeric(12,0)` (Client balance prior to transaction)
    *   `new_balance` `numeric(12,0)` (Generated column: `previous_balance + amount`)
    *   `reference_id` `uuid` (Currently `NOT NULL`, references `sales.id` for credit purchases/voids)
    *   `transaction_type` `text` (Constraint: `'venta_fiado'`, `'abono'`, `'anulacion_fiado'`)
*   **RLS Policies**:
    *   `ledger_read_store`: Enforces reading only within the user's current store (`store_id = public.get_current_store_id()`).
    *   **No DELETE policy** (Implicit deny), making it audit-immutable.

### 1.3 `public.client_transactions` (Legacy Table to be Replaced by View)
*   **Source File**: `supabase/migrations/20260329000000_init.sql`
*   **Key Columns**:
    *   `id` `uuid` (Primary Key)
    *   `client_id` `uuid` (Foreign Key referencing `clients(id)`)
    *   `transaction_type` `text` (Constraint: `'compra'`, `'pago'`)
    *   `amount` `numeric(12,0)` (Constraint: `amount > 0`)
    *   `description` `text`
    *   `sale_id` `uuid` (Foreign Key referencing `sales(id)`)
*   **RLS Policies**:
    *   `client_tx_insert_store` / `client_tx_select_store`: Enforces access within the store scope by joining clients.

---

## 2. RPC Analysis: `registrar_abono`

*   **Source File**: `supabase/migrations/20260405013107_secure_baseline.sql`
*   **Current Logic**:
    1.  **Client Existence Check**: Verifies that the client exists in `public.clients`.
    2.  **IDOR Mitigation Check**: Validates that the active session user (`auth.uid()`) is an employee or administrator associated with the client's store.
    3.  **Balance Check**: Rejects the payment if it exceeds the client's current outstanding balance (`p_amount > v_client.balance`).
    4.  **Balance Update**: Subtracts the payment amount from the client's balance: `UPDATE public.clients SET balance = balance - p_amount`.
    5.  **Insert Transaction**: Inserts a record into the legacy table `public.client_transactions` with `transaction_type = 'pago'`, `amount = p_amount`, and `description = 'Abono efectivo'`.
*   **Proposed Logic**:
    *   Instead of inserting into `public.client_transactions`, it must write directly to `public.client_ledger` with `amount = -p_amount` (negative amount since it reduces the client's debt).
    *   The `reference_id` must be set to `NULL` (since a manual credit payment is not associated with a specific sale ticket).
    *   All validation logic (existence, IDOR check, balance verification, and balance updates) remains intact.

---

## 3. Test Coverage Insights

1.  **`schema_integrity_test.sql`**:
    *   Asserts that database tables (including `client_transactions` and `client_ledger`) exist in the `public` schema. Replacing `client_transactions` with a VIEW of the same name satisfies this check since views are listed in `information_schema.tables`.
2.  **`verify_financial_core.sql`**:
    *   Validates credit sales and void operations by inspecting `client_ledger` directly (`transaction_type = 'venta_fiado'` and `'anulacion_fiado'`). It does not rely on the legacy `client_transactions` table for core verification.
3.  **`qa_financial_core_stress.sql`**:
    *   Verifies security constraints such as ledger immutability (lack of `DELETE` policies on `client_ledger`) and balance constraints. Replacing the table with a view does not affect these tests.

---

## 4. Drafted SQL Migration Script

Below is the drafted SQL script for the migration `supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql`.

```sql
-- Migration: Reconcile client_transactions and client_ledger
-- Path: supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql

BEGIN;

-- 1. Alter client_ledger.reference_id to be nullable
-- This allows manual abonos (payments) to be registered without being associated with a specific sale reference.
ALTER TABLE public.client_ledger ALTER COLUMN reference_id DROP NOT NULL;

-- 2. Backfill missing records from client_transactions into client_ledger
-- Match criteria: client_id, amount (with correct type mapping and signs) within ±60 seconds.
-- For 'pago' (positive in transactions) -> map to 'abono' (negative in ledger: amount = -amount).
-- For 'compra' (positive in transactions) -> map to 'venta_fiado' (positive in ledger: amount = amount).
INSERT INTO public.client_ledger (
    client_id,
    store_id,
    amount,
    previous_balance,
    reference_id,
    transaction_type,
    created_at,
    created_by
)
SELECT 
    ct.client_id,
    c.store_id,
    CASE 
        WHEN ct.transaction_type = 'pago' THEN -ct.amount
        ELSE ct.amount
    END AS amount,
    0 AS previous_balance, -- Set to 0 since we cannot easily reconstruct historical sequential balance history in a set-based insert
    ct.sale_id AS reference_id,
    CASE 
        WHEN ct.transaction_type = 'pago' THEN 'abono'
        ELSE 'venta_fiado'
    END AS transaction_type,
    ct.created_at,
    NULL AS created_by
FROM public.client_transactions ct
JOIN public.clients c ON ct.client_id = c.id
WHERE NOT EXISTS (
    SELECT 1 
    FROM public.client_ledger cl
    WHERE cl.client_id = ct.client_id
      AND cl.created_at >= ct.created_at - INTERVAL '60 seconds'
      AND cl.created_at <= ct.created_at + INTERVAL '60 seconds'
      AND (
          (ct.transaction_type = 'compra' AND cl.transaction_type = 'venta_fiado' AND cl.amount = ct.amount)
          OR
          (ct.transaction_type = 'pago' AND cl.transaction_type = 'abono' AND cl.amount = -ct.amount)
      )
);

-- 3. Drop the legacy client_transactions table cascade
-- Cascading will automatically remove old indexes and permissive RLS policies associated with the table.
DROP TABLE public.client_transactions CASCADE;

-- 4. Create the client_transactions VIEW with security_invoker = true
-- Mapping rules:
--   - transaction_type: 'venta_fiado' -> 'compra', 'abono'/'anulacion_fiado' -> 'pago'
--   - amount: ABS(amount)
--   - description: Constructed via CASE to retain human-readable details
--   - sale_id: Maps to reference_id
-- WITH (security_invoker = true) ensures that RLS policies on client_ledger propagate to the view.
CREATE OR REPLACE VIEW public.client_transactions 
WITH (security_invoker = true) AS
SELECT 
    cl.id,
    cl.client_id,
    CASE 
        WHEN cl.transaction_type = 'venta_fiado' THEN 'compra'
        WHEN cl.transaction_type IN ('abono', 'anulacion_fiado') THEN 'pago'
    END AS transaction_type,
    ABS(cl.amount) AS amount,
    CASE 
        WHEN cl.transaction_type = 'venta_fiado' THEN COALESCE('Compra Ticket #' || s.ticket_number, 'Compra')
        WHEN cl.transaction_type = 'anulacion_fiado' THEN COALESCE('Anulación Ticket #' || s.ticket_number, 'Anulación')
        WHEN cl.transaction_type = 'abono' THEN 'Abono efectivo'
        ELSE 'Otro'
    END AS description,
    cl.reference_id AS sale_id,
    cl.created_at
FROM public.client_ledger cl
LEFT JOIN public.sales s ON cl.reference_id = s.id;

-- 5. Grant SELECT permissions on the view to appropriate database roles
GRANT SELECT ON public.client_transactions TO anon, authenticated, service_role;

-- 6. Recreate the registrar_abono RPC function
-- This version writes into client_ledger with negative amount instead of client_transactions,
-- while retaining all security (IDOR mitigation) and domain validation logic (balance checks).
CREATE OR REPLACE FUNCTION public.registrar_abono(p_client_id uuid, p_amount numeric)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_client public.clients%ROWTYPE;
  v_new_balance DECIMAL;
BEGIN
  -- 1. Obtener cliente
  SELECT * INTO v_client FROM public.clients WHERE id = p_client_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Cliente no encontrado', 'code', 'CLIENT_NOT_FOUND');
  END IF;

  -- 2. Mitigación IDOR: Verificar que el usuario pertenece a la misma tienda
  IF NOT EXISTS (SELECT 1 FROM public.employees WHERE store_id = v_client.store_id AND id = auth.uid()) 
     AND NOT EXISTS (SELECT 1 FROM public.admin_profiles WHERE store_id = v_client.store_id AND id = auth.uid()) THEN
      RAISE EXCEPTION 'IDOR Detectado: Acceso denegado a cliente.' USING ERRCODE = 'P0001';
  END IF;
  
  -- 3. Validar monto no excede el balance actual
  IF p_amount > v_client.balance THEN
    RETURN json_build_object(
      'success', false,
      'error', format('El abono ($%s) supera la deuda actual ($%s)', p_amount, v_client.balance),
      'code', 'AMOUNT_EXCEEDS_BALANCE'
    );
  END IF;
  
  v_new_balance := v_client.balance - p_amount;
  
  -- 4. Actualizar balance del cliente
  UPDATE public.clients SET balance = v_new_balance WHERE id = p_client_id;
  
  -- 5. Registrar en el Ledger (con valor negativo)
  INSERT INTO public.client_ledger (
      client_id,
      store_id,
      amount,
      previous_balance,
      reference_id,
      transaction_type,
      created_by
  )
  VALUES (
      p_client_id,
      v_client.store_id,
      -p_amount,
      v_client.balance,
      NULL,
      'abono',
      auth.uid()
  );
  
  RETURN json_build_object(
    'success', true,
    'new_balance', v_new_balance
  );
END;
$function$;

-- Enforce owner of registrar_abono is postgres
ALTER FUNCTION public.registrar_abono(uuid, numeric) OWNER TO postgres;

COMMIT;
```

---

## 5. Changes Needed in `supabase/scripts/clean_database.sql`

Because `public.client_transactions` is transitioning from a table to a view, running the original `clean_database.sql` script will fail:
> `ERROR: cannot truncate a view`

### 5.1 Required Modifications
1.  **Remove View**: Remove `public.client_transactions,` from the list of tables inside the `TRUNCATE TABLE` statement.
2.  **Add Ledger**: Add `public.client_ledger,` to the `TRUNCATE TABLE` statement to clear client transactions.
3.  **Reset Client Balances (Recommended)**: Add an explicit update to reset all client balances to `0`. If transaction records are wiped, keeping non-zero balances on clients would violate data integrity.

### 5.2 Line-by-Line Changes
In `supabase/scripts/clean_database.sql`:

*   **Before (Lines 8-20)**:
    ```sql
    TRUNCATE TABLE 
        public.sale_items,
        public.sales,
        public.cash_movements,
        public.cash_sessions,
        public.client_transactions,
        public.inventory_movements,
        public.price_change_logs,
        public.daily_passes,
        public.daily_reports,
        public.audit_logs,
        public.error_logs
    CASCADE;
    ```

*   **After**:
    ```sql
    TRUNCATE TABLE 
        public.sale_items,
        public.sales,
        public.cash_movements,
        public.cash_sessions,
        public.client_ledger, -- Replaces client_transactions
        public.inventory_movements,
        public.price_change_logs,
        public.daily_passes,
        public.daily_reports,
        public.audit_logs,
        public.error_logs
    CASCADE;

    -- Reset all client debt balances to keep database state consistent
    UPDATE public.clients SET balance = 0;
    ```

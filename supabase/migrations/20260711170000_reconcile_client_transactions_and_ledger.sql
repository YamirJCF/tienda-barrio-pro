-- Migration: Reconcile client_transactions and client_ledger
-- Path: supabase/migrations/20260711170000_reconcile_client_transactions_and_ledger.sql
-- Author: Database Developer

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
DROP TABLE IF EXISTS public.client_transactions CASCADE;

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

-- Ensure view is owned by postgres
ALTER VIEW public.client_transactions OWNER TO postgres;

-- 5. Grant SELECT permissions on the view to appropriate database roles
GRANT SELECT ON public.client_transactions TO anon, authenticated, service_role;

-- 6. Recreate the registrar_abono RPC function
-- This version writes into client_ledger with negative amount instead of client_transactions,
-- while retaining all security (IDOR mitigation) and domain validation logic (balance checks).
CREATE OR REPLACE FUNCTION public.registrar_abono(p_client_id uuid, p_amount numeric)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_client public.clients%ROWTYPE;
  v_new_balance DECIMAL;
BEGIN
  -- Validar monto positivo
  IF p_amount <= 0 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'El monto del abono debe ser mayor a cero',
      'code', 'INVALID_AMOUNT'
    );
  END IF;

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
    'new_balance', v_new_balance,
    'data', json_build_object('new_balance', v_new_balance)
  );
END;
$function$;

-- Enforce owner of registrar_abono is postgres
ALTER FUNCTION public.registrar_abono(uuid, numeric) OWNER TO postgres;

-- 7. Add index on client_ledger.reference_id
CREATE INDEX IF NOT EXISTS idx_ledger_reference ON public.client_ledger (reference_id);

COMMIT;

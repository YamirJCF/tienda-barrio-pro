-- Migration: Schema and Backfill for Multichannel Cash Sessions
-- Date: 2026-07-27

-- 1. cash_movements: Añadir columna y backfill
ALTER TABLE public.cash_movements
ADD COLUMN payment_method TEXT;

-- Para evitar locks largos, en producción este UPDATE se debería hacer loteado,
-- pero dado que estamos en el script de migración transaccional local, lo ejecutamos directamente.
-- Si el dataset es muy grande, se recomienda aislar esto en un DO $$ bloque o fuera de tx.
UPDATE public.cash_movements 
SET payment_method = 'efectivo' 
WHERE payment_method IS NULL;

ALTER TABLE public.cash_movements 
ALTER COLUMN payment_method SET NOT NULL;

ALTER TABLE public.cash_movements 
ALTER COLUMN payment_method SET DEFAULT 'efectivo';

-- 2. cash_session_balances: Nueva tabla
CREATE TABLE public.cash_session_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.cash_sessions(id) ON DELETE CASCADE,
    payment_method TEXT NOT NULL,
    expected_amount NUMERIC(12, 0) NOT NULL DEFAULT 0,
    actual_amount NUMERIC(12, 0) DEFAULT NULL,
    difference NUMERIC(12, 0) DEFAULT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT cash_session_balances_unique_method UNIQUE (session_id, payment_method)
);

-- Índices
CREATE INDEX idx_cash_session_balances_session ON public.cash_session_balances(session_id);

-- 3. Backfill de Sesiones Históricas
INSERT INTO public.cash_session_balances (
    session_id, 
    payment_method, 
    expected_amount, 
    actual_amount, 
    difference,
    created_at,
    updated_at
)
SELECT 
    id AS session_id,
    'efectivo' AS payment_method,
    COALESCE(expected_balance, 0) AS expected_amount,
    actual_balance AS actual_amount,
    CASE 
        WHEN actual_balance IS NOT NULL THEN actual_balance - COALESCE(expected_balance, 0)
        ELSE NULL 
    END AS difference,
    opened_at AS created_at,
    COALESCE(closed_at, opened_at) AS updated_at
FROM public.cash_sessions
WHERE expected_balance IS NOT NULL OR actual_balance IS NOT NULL;


-- 4. RLS Policies
ALTER TABLE public.cash_session_balances ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lectura balances caja para employees y admins"
ON public.cash_session_balances FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.cash_sessions cs
        JOIN public.store_employees se ON cs.store_id = se.store_id
        WHERE cs.id = cash_session_balances.session_id
          AND se.employee_id = public.get_employee_id_from_session()
    )
    OR
    EXISTS (
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid()
    )
);

CREATE POLICY "Escritura balances caja para employees y admins"
ON public.cash_session_balances FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.cash_sessions cs
        JOIN public.store_employees se ON cs.store_id = se.store_id
        WHERE cs.id = cash_session_balances.session_id
          AND se.employee_id = public.get_employee_id_from_session()
    )
    OR
    EXISTS (
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid()
    )
);

CREATE POLICY "Actualización balances caja para employees y admins"
ON public.cash_session_balances FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM public.cash_sessions cs
        JOIN public.store_employees se ON cs.store_id = se.store_id
        WHERE cs.id = cash_session_balances.session_id
          AND se.employee_id = public.get_employee_id_from_session()
    )
    OR
    EXISTS (
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid()
    )
);

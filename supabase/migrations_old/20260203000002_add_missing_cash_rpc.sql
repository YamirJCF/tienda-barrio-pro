-- MIGRATION: ADD_MISSING_CASH_RPC
-- Fecha: 2026-02-03
-- Objetivo: Crear la funcion RPC `get_active_cash_session` que el frontend esta buscando
--           para sincronizar el estado de la caja.

-- FIX: Drop first to allow return type change (ERROR: 42P13)
DROP FUNCTION IF EXISTS public.get_active_cash_session(uuid);

CREATE OR REPLACE FUNCTION public.get_active_cash_session(p_store_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session RECORD;
BEGIN
    SELECT * INTO v_session
    FROM public.cash_sessions
    WHERE store_id = p_store_id
      AND status = 'open'
    ORDER BY opened_at DESC
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'isOpen', true,
            'sessionId', v_session.id,
            'openingAmount', v_session.opening_balance,
            'openedBy', v_session.opened_by,
            'openedAt', v_session.opened_at
        );
    ELSE
        RETURN jsonb_build_object('isOpen', false);
    END IF;
END;
$$;

-- Permisos para que el empleado (anon/authenticated) pueda consultar
GRANT EXECUTE ON FUNCTION public.get_active_cash_session(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_cash_session(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.get_active_cash_session(uuid) TO service_role;

-- FIX RLS: Ensure employees can select cash_sessions just in case they fallback to legacy
-- Policies might already exist, but making sure:
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'cash_sessions' AND policyname = 'Employees can view store sessions'
    ) THEN
        CREATE POLICY "Employees can view store sessions" ON public.cash_sessions
        FOR SELECT
        USING (store_id = public.get_current_store_id());
    END IF;
END $$;

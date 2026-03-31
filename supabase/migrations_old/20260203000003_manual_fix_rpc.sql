-- MIGRATION: ADD_MISSING_CASH_RPC (SAFE VERSION)
-- Objective: Ensure get_active_cash_session exists
-- Execute via Supabase SQL Editor

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

GRANT EXECUTE ON FUNCTION public.get_active_cash_session(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_cash_session(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.get_active_cash_session(uuid) TO service_role;

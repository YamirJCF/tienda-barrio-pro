-- MIGRATION: FIX_ADMIN_SYNC_PERMS_V2 (SECURE)
-- Objective: Fix "Split Brain" sync issue by ensuring:
-- 1. RPC exists AND is secure (Primary Path)
-- 2. RLS Policies exist for Owners (Fallback Path)

-- 1. Ensure RPC Exists (Primary Sync Mechanism) with Security Check
DROP FUNCTION IF EXISTS public.get_active_cash_session(uuid);

CREATE OR REPLACE FUNCTION public.get_active_cash_session(p_store_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session RECORD;
    v_requester_store_id UUID;
BEGIN
    -- SECURITY CHECK: Verify requester belongs to the requested store
    -- We can use the helper function get_current_store_id() which handles Admin/Employee/Pass logic
    v_requester_store_id := public.get_current_store_id();
    
    IF v_requester_store_id IS NULL OR v_requester_store_id != p_store_id THEN
        -- If requester has no store or requests a different store, return closed/unauthorized
        -- We return 'isOpen': false to avoid leaking existence, effectively behaving like it's closed/inaccessible
        RETURN jsonb_build_object('isOpen', false, 'error', 'Unauthorized');
    END IF;

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

-- 2. Ensure RLS Policies for Owners (Fallback Mechanism)
-- If RPC fails or is not called, Admin must be able to SELECT via RLS.

DO $$
BEGIN
    -- Policy for Admin Profiles (Explicit Link)
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'cash_sessions' AND policyname = 'Admins can view store sessions'
    ) THEN
        CREATE POLICY "Admins can view store sessions" ON public.cash_sessions
        FOR SELECT
        USING (
            -- Check if the row's store_id matches any store owned by the admin
            store_id IN (
                SELECT store_id FROM public.admin_profiles WHERE id = auth.uid()
            )
        );
    END IF;
END $$;

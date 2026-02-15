-- ==============================================================================
-- FIX: assert_store_access had TWO wrong column references
-- Bug 1: stores.admin_id → stores.owner_id (actual column name)
-- Bug 2: employees.user_id → removed (employees are PIN-based, not auth-linked)
-- Date: 2026-02-15
-- Impact: ALL history RPCs + daily summary + smart supply were broken
-- ==============================================================================

CREATE OR REPLACE FUNCTION assert_store_access(p_store_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Validate that the current auth user is the store owner
    IF NOT EXISTS (
        SELECT 1 FROM stores WHERE id = p_store_id AND owner_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED'
            USING HINT = 'El usuario no tiene acceso a esta tienda';
    END IF;
END;
$$;

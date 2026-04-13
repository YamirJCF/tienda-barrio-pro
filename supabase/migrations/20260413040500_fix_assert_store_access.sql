-- ==============================================================================
-- MIGRATION: FIX ASSERT STORE ACCESS
-- Corrige el error "column admin_id does not exist" utilizando la abstracción correcta
-- ==============================================================================

CREATE OR REPLACE FUNCTION assert_store_access(p_store_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF public.get_current_store_id() IS NULL OR public.get_current_store_id() != p_store_id THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED'
            USING HINT = 'El usuario no tiene acceso a esta tienda';
    END IF;
END;
$$;

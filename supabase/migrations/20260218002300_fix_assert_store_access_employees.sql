-- Fix: Allow employees (permanent and daily pass) in assert_store_access
-- Previously, this function only allowed Store Owners, blocking employees from executing RPCs.

CREATE OR REPLACE FUNCTION public.assert_store_access(p_store_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_employee_id UUID;
    v_is_active BOOLEAN;
BEGIN
    -- 1. Check if Owner/Admin (Direct ownership)
    IF EXISTS (
        SELECT 1 FROM stores WHERE id = p_store_id AND owner_id = auth.uid()
    ) THEN
        RETURN;
    END IF;

    -- 2. Check if Employee (Permanent or Daily Pass)
    -- reuse existing logic to get employee_id from session (handles auth.uid for both types)
    v_employee_id := public.get_employee_id_from_session();
    
    IF v_employee_id IS NOT NULL THEN
        -- Verify the employee belongs to the requested store and is active
        SELECT is_active INTO v_is_active 
        FROM public.employees 
        WHERE id = v_employee_id AND store_id = p_store_id;

        IF FOUND AND v_is_active THEN
            RETURN; -- Access Granted
        END IF;
    END IF;

    -- 3. Deny Access
    RAISE EXCEPTION 'STORE_ACCESS_DENIED'
        USING HINT = 'El usuario no tiene acceso a esta tienda o su cuenta está inactiva';
END;
$function$;

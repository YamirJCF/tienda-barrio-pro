-- Fix: Allow admin_profiles in assert_store_access
-- Previously, we added employees, but forgot to explicitly allow Admin Profiles (who are not necessarily the store owner in the stores table).

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
    -- 1. Check if Owner (Direct ownership in stores table)
    IF EXISTS (
        SELECT 1 FROM stores WHERE id = p_store_id AND owner_id = auth.uid()
    ) THEN
        RETURN;
    END IF;

    -- 2. Check if Admin Profile (Super Admin / Store Admin)
    -- Admin profiles have full access to their assigned store
    IF EXISTS (
        SELECT 1 FROM public.admin_profiles WHERE id = auth.uid() AND store_id = p_store_id
    ) THEN
        RETURN;
    END IF;

    -- 3. Check if Employee (Permanent or Daily Pass)
    -- reuse existing logic to get employee_id from session (handles auth.uid for both types)
    v_employee_id := public.get_employee_id_from_session();
    
    IF v_employee_id IS NOT NULL THEN
        -- Verify the employee belongs to the requested store and is active
        SELECT is_active INTO v_is_active 
        FROM public.employees 
        WHERE id = v_employee_id AND store_id = p_store_id;

        -- If found and active, grant access
        IF FOUND AND v_is_active IS TRUE THEN
            RETURN; 
        END IF;
    END IF;

    -- 4. Deny Access
    RAISE EXCEPTION 'STORE_ACCESS_DENIED'
        USING HINT = 'El usuario no tiene acceso a esta tienda o su cuenta está inactiva';
END;
$function$;

-- MIGRATION: FIX_GET_EMPLOYEE_PUBLIC_INFO
-- Datum: 2026-02-02
-- Description: 
-- Removes reference to non-existent column 'is_active' on table 'stores' in RPC 'get_employee_public_info'.

CREATE OR REPLACE FUNCTION public.get_employee_public_info(p_alias TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Necesario para leer employees siendo anon
AS $$
DECLARE
    v_employee RECORD;
BEGIN
    SELECT e.id, e.name, e.store_id, s.name as store_name
    INTO v_employee
    FROM public.employees e
    JOIN public.stores s ON e.store_id = s.id
    WHERE e.alias = p_alias 
      AND e.is_active = true;
      -- REMOVED: AND s.is_active = true; (Column does not exist)

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Empleado no encontrado');
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'employee_id', v_employee.id,
        'name', v_employee.name,
        'store_id', v_employee.store_id,
        'store_name', v_employee.store_name
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_employee_public_info(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_employee_public_info(text) TO authenticated;

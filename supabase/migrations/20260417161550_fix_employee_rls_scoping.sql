-- MIGRATION: FIX_EMPLOYEE_RLS_SCOPING
-- Date: 2026-04-17
-- Description:
-- Restores step 4 of get_current_store_id() according to historical file 20260202181500_fix_pos_access_rls.sql.
-- Ensure Zero-Auth Employees (using anonymous auth.uid() mapped via daily_passes) are
-- correctly discovered by RLS policies so they do not see an empty store.

CREATE OR REPLACE FUNCTION public.get_current_store_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_store_id UUID;
BEGIN
  -- 1. Intentar obtener desde App Metadata (JWT)
  v_store_id := (auth.jwt() -> 'app_metadata' ->> 'store_id')::uuid;
  
  IF v_store_id IS NOT NULL THEN
    RETURN v_store_id;
  END IF;

  -- 2. Fallback: Buscar en admin_profiles (Dueño/Admin)
  SELECT store_id INTO v_store_id
  FROM public.admin_profiles
  WHERE id = auth.uid();
  
  IF v_store_id IS NOT NULL THEN
    RETURN v_store_id;
  END IF;

  -- 3. Fallback: Buscar en employees (Usuario de sistema con auth real)
  SELECT store_id INTO v_store_id
  FROM public.employees
  WHERE id = auth.uid();

  IF v_store_id IS NOT NULL THEN
    RETURN v_store_id;
  END IF;

  -- 4. Fallback: Buscar en daily_passes (Empleados Anonimos con Pase Aprobado)
  SELECT store_id INTO v_store_id
  FROM public.daily_passes
  WHERE auth_user_id = auth.uid() 
    AND status = 'approved' 
    AND pass_date = CURRENT_DATE;

  RETURN v_store_id;
END;
$$;

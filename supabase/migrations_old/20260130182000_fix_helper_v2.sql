-- =============================================
-- MIGRATION: FIX GET_CURRENT_STORE_ID V2 (Support Employees)
-- Fecha: 2026-01-30
-- Autor: @[/qa]
-- Descripción: Versión mejorada de la función helper.
-- Ahora busca en 'admin_profiles' (Dueños) Y en 'employees' (Personal).
-- Esto asegura que los empleados también puedan pasar las políticas RLS.
-- =============================================

CREATE OR REPLACE FUNCTION public.get_current_store_id()
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $$
DECLARE
  v_store_id uuid;
BEGIN
  -- 1. Intentar obtener desde App Metadata (JWT) - Optimización futura
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

  -- 3. Fallback: Buscar en employees (Personal)
  SELECT store_id INTO v_store_id
  FROM public.employees
  WHERE id = auth.uid();

  RETURN v_store_id;
END;
$$;

-- =============================================
-- MIGRATION: FIX GET_CURRENT_STORE_ID (Magic Bullet)
-- Fecha: 2026-01-30
-- Autor: @[/qa]
-- Descripción: Actualiza la función helper central para que no dependa
-- exclusivamente del JWT claim (que suele faltar), sino que busque activamente
-- en la tabla admin_profiles usando el ID del usuario autenticado.
-- Esto arregla RLS para: products, sales, inventory, etc.
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
  -- Nota: Requiere que un Auth Hook inyecte este valor.
  v_store_id := (auth.jwt() -> 'app_metadata' ->> 'store_id')::uuid;
  
  IF v_store_id IS NOT NULL THEN
    RETURN v_store_id;
  END IF;

  -- 2. Fallback Seguro: Buscar en admin_profiles (Dueño/Admin)
  -- Al ser SECURITY DEFINER, puede leer admin_profiles sin recursión infinita
  -- (siempre que la política de admin_profiles no use get_current_store_id, lo cual arreglamos antes)
  SELECT store_id INTO v_store_id
  FROM public.admin_profiles
  WHERE id = auth.uid();
  
  RETURN v_store_id;
END;
$$;

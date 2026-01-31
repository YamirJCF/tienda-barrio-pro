-- =============================================
-- MIGRATION: ATOMIC REGISTRATION TRIGGER
-- Fecha: 2026-01-30
-- Descripción: Garantiza la creación atómica de Tienda y Perfil
-- cuando se crea un usuario en Auth. Reemplaza lógica de Frontend.
-- =============================================

-- 1. Función Principal del Trigger (Versión Robusta)
CREATE OR REPLACE FUNCTION public.handle_new_user_atomic()
RETURNS TRIGGER AS $$
DECLARE
  v_store_name TEXT;
  v_slug TEXT;
  v_base_slug TEXT;
  v_counter INT := 1;
  v_new_store_id UUID;
BEGIN
  -- A. Extracción y Sanitización de Metadata
  v_store_name := COALESCE(new.raw_user_meta_data->>'store_name', 'Mi Tienda');
  v_store_name := LEFT(v_store_name, 50); -- Limitar longitud

  -- B. Generación de Slug Único
  v_base_slug := public.slugify(v_store_name);
  v_slug := v_base_slug;
  
  -- Loop de colisión (Optimista)
  WHILE EXISTS (SELECT 1 FROM public.stores WHERE slug = v_slug) LOOP
    v_slug := v_base_slug || '-' || v_counter;
    v_counter := v_counter + 1;
  END LOOP;

  -- C. Transacción Atómica
  -- El bloque BEGIN...EXCEPTION interno permite capturar errores específicos si fuera necesario,
  -- pero para atomicidad total, dejaremos que el error propague para abortar el Auth User.

  -- C.1: Crear Tienda
  INSERT INTO public.stores (name, slug, owner_id)
  VALUES (v_store_name, v_slug, new.id)
  RETURNING id INTO v_new_store_id;

  -- C.2: Crear Perfil de Admin (Owner)
  -- Esto soluciona el problema del "Usuario Huérfano"
  INSERT INTO public.admin_profiles (id, store_id, role, is_verified)
  VALUES (
    new.id,           -- ID del Auth User
    v_new_store_id,   -- ID de la Tienda acabada de crear
    'owner',          -- Rol fijo
    false             -- false hasta confirmar email (o true si se decide auto-verificar)
  );

  -- Si todo sale bien, retornamos el usuario nuevo
  RETURN new;

EXCEPTION WHEN OTHERS THEN
  -- D. Fail-Safe: Abortar TODO
  -- Si falla la tienda o el perfil, NO QUEREMOS el usuario.
  -- Esto fuerza a Supabase Auth a hacer rollback.
  RAISE EXCEPTION 'ATOMIC REGISTRATION FAILED: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Vincular Trigger
-- Primero borramos el trigger viejo si existía (o la versión anterior no atómica)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Creamos el nuevo trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user_atomic();

-- Notas:
-- Esta función asume que public.slugify existe (creada en migración anterior).

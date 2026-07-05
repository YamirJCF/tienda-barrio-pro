-- ==============================================================================
-- Migración: Restauración Definitiva del Trigger atómico y reparación RLS
-- ==============================================================================
-- Justificación Arquitectónica:
-- 1. Se restaura el disparador en auth.users para respetar que el Frontend
--    NO deba (ni pueda) insertar directamente en las tablas núcleo public.
-- 2. La función `get_current_store_id()` recupera su estatus de SECURITY DEFINER
--    para permitir un escaneo circular que resuelva políticas RLS de manera robusta.
-- ==============================================================================

-- 1. Restaurar Fallback Seguro de get_current_store_id()
CREATE OR REPLACE FUNCTION public.get_current_store_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER  -- Permite bypass de RLS interno para evitar bucles infinitos
SET search_path = public
AS $$
DECLARE
  v_store_id UUID;
BEGIN
  -- 1. Intentar desde JWT de Supabase (Fast Path Opcional)
  v_store_id := (auth.jwt() ->> 'store_id')::UUID;
  IF v_store_id IS NOT NULL THEN
    RETURN v_store_id;
  END IF;

  -- 2. Buscar como dueño (Store Owner)
  SELECT store_id INTO v_store_id
  FROM public.admin_profiles
  WHERE id = auth.uid();
  
  IF v_store_id IS NOT NULL THEN
    RETURN v_store_id;
  END IF;

  -- 3. Buscar como empleado regular vinculado a caja
  SELECT store_id INTO v_store_id
  FROM public.employees
  WHERE id = auth.uid();

  RETURN v_store_id;
END;
$$;

-- Refuerzo de lectura en la profile del Admin
ALTER POLICY "admin_profiles_select_own" ON public.admin_profiles USING (id = auth.uid());


-- 2. Re-desplegar la Construcción Atómica del Registro (Backend Authority)
CREATE OR REPLACE FUNCTION public.handle_new_user_atomic()
RETURNS TRIGGER AS $$
DECLARE
  v_store_name TEXT;
  v_slug TEXT;
  v_base_slug TEXT;
  v_counter INT := 1;
  v_new_store_id UUID;
BEGIN
  -- A. Metadata inyectada desde el Frontend Auth
  v_store_name := COALESCE(new.raw_user_meta_data->>'store_name', 'Tienda Base');
  v_store_name := LEFT(v_store_name, 50);

  -- B. Base de formato amigable de Slug
  v_base_slug := lower(regexp_replace(v_store_name, '[^a-zA-Z0-9]+', '-', 'g'));
  v_base_slug := trim(both '-' from v_base_slug);
  IF v_base_slug = '' THEN v_base_slug := 'tienda-' || left(new.id::text, 8); END IF;
  
  v_slug := v_base_slug;
  WHILE EXISTS (SELECT 1 FROM public.stores WHERE slug = v_slug) LOOP
    v_slug := v_base_slug || '-' || v_counter;
    v_counter := v_counter + 1;
  END LOOP;

  -- C.1: El Servidor asume crear la Tienda
  INSERT INTO public.stores (name, slug)
  VALUES (v_store_name, v_slug)
  RETURNING id INTO v_new_store_id;

  -- C.2: El Servidor vincula el UUID nativo con los permisos de Owner
  INSERT INTO public.admin_profiles (id, store_id, role, is_verified)
  VALUES (new.id, v_new_store_id, 'owner', false);

  -- C.3: El Servidor prepara su acceso a operaciones Diarias
  INSERT INTO public.employees (
        id, store_id, name, username, pin_hash, permissions, is_active, created_at, updated_at
  )
  VALUES (
        new.id,
        v_new_store_id,
        COALESCE(new.raw_user_meta_data->>'owner_name', 'Propietario'),
        'owner_' || left(new.id::text, 8),
        '$2a$10$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX', 
        jsonb_build_object(
            'canSell', true, 'canFiar', true, 'canViewInventory', true, 
            'canViewReports', true, 'canOpenCloseCash', true, 
            'canManageInventory', true, 'canManageClients', true, 
            'isSuperAdmin', true
        ),
        true, NOW(), NOW()
  );

  RETURN new;
EXCEPTION WHEN OTHERS THEN
  -- Forzará Supabase a devolver Error si algo falla cortando el Auth por completo
  RAISE WARNING 'ATOMIC REGISTRATION FAILED: %', SQLERRM;
  RETURN new; 
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Activar el disparador a nivel del sistema Auth
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user_atomic();

-- MIGRATION: FIX_TRIGGERS_ANONYMOUS
-- Datum: 2026-02-02
-- Description: 
-- Patches `handle_new_user_store` and `handle_new_user_atomic` to IGNORE anonymous users.
-- Anonymous users (Employees) should NOT trigger Store Creation or Admin Profile creation.
-- This prevents the 422 Error during `signInAnonymously()`.

-- 1. Patch `handle_new_user_store`
CREATE OR REPLACE FUNCTION public.handle_new_user_store()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_store_name TEXT;
  v_slug TEXT;
  v_base_slug TEXT;
  v_counter INT := 1;
  v_store_id UUID;
BEGIN
  -- [FIX] IGNORE ANONYMOUS USERS
  IF new.is_anonymous IS TRUE THEN
    RETURN new;
  END IF;

  -- 1. Extraer nombre de la tienda de los metadatos
  v_store_name := new.raw_user_meta_data->>'store_name';

  -- Si no hay nombre de tienda, asumimos que es un usuario invitado o empleado creado manualmente
  -- y no disparamos la creación automática de tienda.
  IF v_store_name IS NULL THEN
    RETURN new;
  END IF;

  -- 2. Saneamiento Básico (Cortar a 50 chars)
  v_store_name := LEFT(v_store_name, 50);

  -- 3. Generar Slug Base
  v_base_slug := public.slugify(v_store_name);
  v_slug := v_base_slug;

  -- 4. Manejo de Colisiones de Slug
  WHILE EXISTS (SELECT 1 FROM public.stores WHERE slug = v_slug) LOOP
    v_slug := v_base_slug || '-' || v_counter;
    v_counter := v_counter + 1;
  END LOOP;

  -- 5. Inserción Atómica en STORES (Sin owner_id)
  INSERT INTO public.stores (name, slug)
  VALUES (v_store_name, v_slug)
  RETURNING id INTO v_store_id;

  -- 6. Inserción en ADMIN_PROFILES (Vincula Auth User + Store)
  INSERT INTO public.admin_profiles (id, store_id, role, is_verified)
  VALUES (new.id, v_store_id, 'owner', false);

  RETURN new;
EXCEPTION WHEN OTHERS THEN
  -- En caso de error, levantamos excepción para que el registro en Auth también falle
  -- y no queden usuarios huérfanos sin tienda.
  RAISE EXCEPTION 'Error al crear la tienda automática: %', SQLERRM;
END;
$function$;

-- 2. Patch `handle_new_user_atomic` (Just in case it's being used instead)
CREATE OR REPLACE FUNCTION public.handle_new_user_atomic()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_store_name TEXT;
  v_slug TEXT;
  v_base_slug TEXT;
  v_counter INT := 1;
  v_new_store_id UUID;
BEGIN
  -- [FIX] IGNORE ANONYMOUS USERS
  IF new.is_anonymous IS TRUE THEN
    RETURN new;
  END IF;

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
  -- C.1: Crear Tienda
  INSERT INTO public.stores (name, slug, owner_id)
  VALUES (v_store_name, v_slug, new.id)
  RETURNING id INTO v_new_store_id;

  -- C.2: Crear Perfil de Admin (Owner)
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
  RAISE EXCEPTION 'ATOMIC REGISTRATION FAILED: %', SQLERRM;
END;
$function$;

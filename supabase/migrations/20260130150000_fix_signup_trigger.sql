-- =============================================
-- MIGRATION: FIX SIGNUP TRIGGER (Schema V2)
-- Fecha: 2026-01-30
-- Autor: @[/data]
-- Descripción: Ajusta el trigger de registro para soportar la separación
-- de `stores` y `admin_profiles` (eliminando owner_id de stores).
-- =============================================

CREATE OR REPLACE FUNCTION public.handle_new_user_store()
RETURNS TRIGGER AS $$
DECLARE
  v_store_name TEXT;
  v_slug TEXT;
  v_base_slug TEXT;
  v_counter INT := 1;
  v_store_id UUID;
BEGIN
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

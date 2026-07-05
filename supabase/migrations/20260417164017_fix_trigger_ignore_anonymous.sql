-- MIGRATION: FIX_TRIGGER_IGNORE_ANONYMOUS
-- Date: 2026-04-17
-- Description:
-- Restores the anonymous user guard in handle_new_user_atomic() from historical file
-- 20260202185500_fix_triggers_anonymous.sql. The consolidation of April 13 removed 
-- the critical "IF new.is_anonymous IS TRUE THEN RETURN new;" check, causing every
-- employee login (signInAnonymously) to create phantom stores and admin_profiles.
-- Also cleans up phantom data created during the period the guard was missing.

-- STEP 1: Restore the anonymous guard
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
  -- [FIX] IGNORE ANONYMOUS USERS (Restored from 20260202185500)
  IF new.is_anonymous IS TRUE THEN
    RETURN new;
  END IF;

  v_store_name := COALESCE(new.raw_user_meta_data->>'store_name', 'Tienda Principal');
  v_store_name := LEFT(v_store_name, 50);

  v_base_slug := lower(regexp_replace(v_store_name, '[^a-zA-Z0-9]+', '-', 'g'));
  v_base_slug := trim(both '-' from v_base_slug);
  IF v_base_slug = '' THEN v_base_slug := 'tienda-' || left(new.id::text, 8); END IF;
  
  v_slug := v_base_slug;
  WHILE EXISTS (SELECT 1 FROM public.stores WHERE slug = v_slug) LOOP
    v_slug := v_base_slug || '-' || v_counter;
    v_counter := v_counter + 1;
  END LOOP;

  INSERT INTO public.stores (name, slug)
  VALUES (v_store_name, v_slug)
  RETURNING id INTO v_new_store_id;

  INSERT INTO public.admin_profiles (id, store_id, role, is_verified)
  VALUES (new.id, v_new_store_id, 'owner', false);

  INSERT INTO public.employees (id, store_id, name, username, pin_hash, permissions, is_active, created_at, updated_at)
  VALUES (new.id, v_new_store_id, COALESCE(new.raw_user_meta_data->>'owner_name', 'Propietario'), 'owner_' || left(new.id::text, 8), '$2a$10$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX', jsonb_build_object('canSell', true, 'canFiar', true, 'canViewInventory', true, 'canViewReports', true, 'canOpenCloseCash', true, 'canManageInventory', true, 'canManageClients', true, 'isSuperAdmin', true), true, NOW(), NOW());

  RETURN new;
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'ATOMIC REGISTRATION FAILED: %', SQLERRM;
  RETURN new;
END;
$function$;

-- STEP 2: Clean up phantom data created by anonymous users
DELETE FROM public.employees 
WHERE store_id IN (
  SELECT s.id FROM stores s
  JOIN admin_profiles ap ON ap.store_id = s.id
  JOIN auth.users au ON au.id = ap.id
  WHERE au.is_anonymous = true
);

DELETE FROM public.admin_profiles 
WHERE id IN (
  SELECT au.id FROM auth.users au WHERE au.is_anonymous = true
);

-- NOTE: Phantom store IDs discovered via forensic query on 2026-04-17
DELETE FROM public.stores 
WHERE id IN (
  '97f09ccc-38c5-4725-aaee-6abffe807bb8',
  'bb7a0375-9185-433a-bce6-650d3fcce95f',
  '0e96fade-18ed-4469-a218-bbe34c225e11'
);

-- 1. Schema Fixes
-- Add owner_id to stores to link with auth.users
ALTER TABLE public.stores 
ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES auth.users(id);

-- Make pin_hash nullable in employees (since we use Supabase Auth for admins now)
ALTER TABLE public.employees
ALTER COLUMN pin_hash DROP NOT NULL;

-- 2. Update Trigger Function to create Store AND Employee
CREATE OR REPLACE FUNCTION public.handle_new_user_store()
RETURNS TRIGGER AS $$
DECLARE
  v_store_name TEXT;
  v_owner_name TEXT;
  v_slug TEXT;
  v_base_slug TEXT;
  v_counter INT := 1;
  v_store_id UUID;
BEGIN
  -- Extract metadata
  v_store_name := new.raw_user_meta_data->>'store_name';
  v_owner_name := new.raw_user_meta_data->>'owner_name'; -- Capture Owner Name

  -- Skip if not a store registration
  IF v_store_name IS NULL THEN
    RETURN new;
  END IF;

  -- 1. Sanitize Store Name
  v_store_name := LEFT(v_store_name, 50);

  -- 2. Generate Slug
  v_base_slug := public.slugify(v_store_name);
  v_slug := v_base_slug;

  WHILE EXISTS (SELECT 1 FROM public.stores WHERE slug = v_slug) LOOP
    v_slug := v_base_slug || '-' || v_counter;
    v_counter := v_counter + 1;
  END LOOP;

  -- 3. Insert Store (RETURNING ID)
  INSERT INTO public.stores (name, slug, owner_id)
  VALUES (v_store_name, v_slug, new.id)
  RETURNING id INTO v_store_id;

  -- 4. Insert Admin Employee (Linked to Store)
  -- Uses email as username. PIN is NULL.
  INSERT INTO public.employees (
    store_id, 
    name, 
    username, 
    pin_hash, 
    is_active, 
    permissions
  )
  VALUES (
    v_store_id,
    COALESCE(v_owner_name, 'Admin'),
    new.email,
    NULL, -- No PIN initially
    true,
    '{"admin": true, "canSell": true, "canViewReports": true, "canManageInventory": true}'::jsonb
  );

  RETURN new;
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'Error al crear la tienda y usuario: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

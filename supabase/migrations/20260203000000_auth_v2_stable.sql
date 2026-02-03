-- MIGRATION: AUTH_V2_STABLE
-- Datum: 2026-02-03
-- Description: 
-- Consolidated "Master Migration" for Employee Authentication System (Zero-Auth).
-- Merges logic from:
-- 1. 20260202181500_fix_pos_access_rls.sql
-- 2. 20260202183000_auto_approve_employees.sql
-- 3. 20260202185500_fix_triggers_anonymous.sql
-- 4. 20260202191500_fix_pass_upsert.sql
-- 5. 20260202192500_add_updated_at_daily_passes.sql

-- =============================================
-- 1. SCHEMA UPGRADES (Daily Passes)
-- =============================================
ALTER TABLE public.daily_passes 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_daily_passes_updated_at ON public.daily_passes;

CREATE TRIGGER update_daily_passes_updated_at
    BEFORE UPDATE ON public.daily_passes
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================
-- 2. CORE LOGIC: Request Access (Upsert + Auto-Approve)
-- =============================================
CREATE OR REPLACE FUNCTION public.request_employee_access(
    p_alias TEXT,
    p_pin TEXT,
    p_device_fingerprint TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_employee RECORD;
    v_pass_id UUID;
    v_pin_valid BOOLEAN := false;
BEGIN
    -- A. Identificar Empleado
    SELECT e.*, au.email as owner_email 
    INTO v_employee
    FROM public.employees e
    JOIN public.stores s ON e.store_id = s.id
    LEFT JOIN auth.users au ON s.owner_id = au.id
    WHERE e.alias = p_alias;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'code', 'USER_NOT_FOUND', 'message', 'Alias no existe');
    END IF;

    -- Validar PIN (Dual Mode)
    IF v_employee.pin_code IS NOT DISTINCT FROM p_pin THEN
         v_pin_valid := true;
    ELSIF v_employee.pin_hash IS NOT NULL AND v_employee.pin_hash = crypt(p_pin, v_employee.pin_hash) THEN
         v_pin_valid := true;
    END IF;

    IF NOT v_pin_valid THEN
         RETURN jsonb_build_object('success', false, 'code', 'INVALID_CREDENTIALS', 'message', 'PIN Incorrecto');
    END IF;

    -- B. Gestión del Pase Diario (UPSERT PATTERN)
    INSERT INTO public.daily_passes (
        employee_id,
        store_id,
        device_fingerprint,
        status,
        pass_date,
        requested_at,
        resolved_at,
        resolved_by,
        auth_user_id
    ) VALUES (
        v_employee.id,
        v_employee.store_id,
        p_device_fingerprint,
        'approved', -- AUTO-APPROVE
        CURRENT_DATE,
        now(),
        now(),
        v_employee.id,
        auth.uid()
    )
    ON CONFLICT (employee_id, pass_date) 
    DO UPDATE SET 
        auth_user_id = EXCLUDED.auth_user_id, -- Session Takeover
        device_fingerprint = EXCLUDED.device_fingerprint,
        status = 'approved',
        updated_at = now()
    RETURNING id INTO v_pass_id;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'approved',
        'employee', jsonb_build_object(
            'id', v_employee.id,
            'name', v_employee.name,
            'role', 'employee',
            'store_id', v_employee.store_id,
            'permissions', v_employee.permissions
        )
    );
END;
$$;

-- =============================================
-- 3. CORE LOGIC: Context Resolution (RLS Support)
-- =============================================
CREATE OR REPLACE FUNCTION public.get_current_store_id()
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_store_id UUID;
BEGIN
  -- 1. JWT Metadata
  v_store_id := (auth.jwt() -> 'app_metadata' ->> 'store_id')::uuid;
  IF v_store_id IS NOT NULL THEN RETURN v_store_id; END IF;

  -- 2. Owner/Admin
  SELECT store_id INTO v_store_id FROM public.admin_profiles WHERE id = auth.uid();
  IF v_store_id IS NOT NULL THEN RETURN v_store_id; END IF;

  -- 3. System Employee
  SELECT store_id INTO v_store_id FROM public.employees WHERE id = auth.uid();
  IF v_store_id IS NOT NULL THEN RETURN v_store_id; END IF;

  -- 4. Anonymous Employee (Daily Pass Linked)
  SELECT store_id INTO v_store_id 
  FROM public.daily_passes
  WHERE auth_user_id = auth.uid() 
    AND status = 'approved' 
    AND pass_date = CURRENT_DATE;

  RETURN v_store_id;
END;
$function$;

-- =============================================
-- 4. INFRASTRUCTURE: Trigger Patch (Anonymous Safety)
-- =============================================
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

  v_store_name := COALESCE(new.raw_user_meta_data->>'store_name', 'Mi Tienda');
  v_store_name := LEFT(v_store_name, 50);

  v_base_slug := public.slugify(v_store_name);
  v_slug := v_base_slug;
  
  WHILE EXISTS (SELECT 1 FROM public.stores WHERE slug = v_slug) LOOP
    v_slug := v_base_slug || '-' || v_counter;
    v_counter := v_counter + 1;
  END LOOP;

  INSERT INTO public.stores (name, slug, owner_id)
  VALUES (v_store_name, v_slug, new.id)
  RETURNING id INTO v_new_store_id;

  INSERT INTO public.admin_profiles (id, store_id, role, is_verified)
  VALUES (new.id, v_new_store_id, 'owner', false);

  RETURN new;
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'ATOMIC REGISTRATION FAILED: %', SQLERRM;
END;
$function$;

-- MIGRATION: FIX_LEGACY_EMPLOYEE_RPCS
-- Datum: 2026-02-02
-- Autor: AntiGravity (Zero-Auth Refinement)
-- Description: 
-- 1. Updates legacy RPCs to use 'alias' instead of 'username'.
-- 2. Updates legacy RPCs to use 'pin_code' (or 'pin_hash') for compatibility.
-- 3. Updates logic to support both Plain PIN (Simplified) and Hash PIN (Legacy) during transition.

-- 1. Ensure pin_code column exists (Simplified Strategy Storage)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'employees' AND column_name = 'pin_code') THEN
        ALTER TABLE public.employees ADD COLUMN pin_code TEXT;
    END IF;
    END IF;
END $$;

-- 1.1 DROP Legacy Functions to avoid Return Type Conflicts
DROP FUNCTION IF EXISTS public.crear_empleado(uuid, text, text, text, jsonb);
DROP FUNCTION IF EXISTS public.actualizar_pin_empleado(uuid, text);
DROP FUNCTION IF EXISTS public.validar_pin_empleado(text, text);
DROP FUNCTION IF EXISTS public.request_employee_access(text, text, text);

-- 2. Update 'crear_empleado' to use 'alias' and 'pin_code'
CREATE OR REPLACE FUNCTION public.crear_empleado(
    p_store_id UUID,
    p_name TEXT,
    p_username TEXT, -- Mapped to alias
    p_pin TEXT,
    p_permissions JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_new_id UUID;
BEGIN
    -- Validar unicidad de alias
    IF EXISTS (SELECT 1 FROM public.employees WHERE alias = p_username) THEN
        RETURN jsonb_build_object('success', false, 'error', 'El alias ya existe');
    END IF;

    INSERT INTO public.employees (
        store_id,
        name,
        alias,
        pin_code, -- Storing plain text as per Simplified Strategy (or we could hash it here)
        permissions,
        is_active
    ) VALUES (
        p_store_id,
        p_name,
        p_username,
        p_pin,
        p_permissions,
        true
    ) RETURNING id INTO v_new_id;

    RETURN jsonb_build_object('success', true, 'employee_id', v_new_id);
EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'El alias ya existe');
WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
GRANT EXECUTE ON FUNCTION public.crear_empleado(uuid, text, text, text, jsonb) TO authenticated;

-- 3. Update 'actualizar_pin_empleado' to update 'pin_code'
CREATE OR REPLACE FUNCTION public.actualizar_pin_empleado(
  p_employee_id UUID,
  p_new_pin TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_store_id UUID;
BEGIN
  SELECT store_id INTO v_store_id FROM public.employees WHERE id = p_employee_id;

  IF NOT FOUND THEN
     RETURN jsonb_build_object('success', false, 'error', 'Empleado no encontrado');
  END IF;

  -- Security Check
  IF v_store_id != public.get_current_store_id() THEN
     RETURN jsonb_build_object('success', false, 'error', 'No autorizado');
  END IF;

  UPDATE public.employees
  SET 
    pin_code = p_new_pin, -- Simple update
    pin_hash = NULL, -- Clear legacy hash to force use of pin_code
    updated_at = now()
  WHERE id = p_employee_id;

  RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
GRANT EXECUTE ON FUNCTION public.actualizar_pin_empleado(uuid, text) TO authenticated;


-- 4. Update 'validar_pin_empleado' (Local Check) to support alias and dual-pin strategy
CREATE OR REPLACE FUNCTION public.validar_pin_empleado(
    p_username TEXT,
    p_pin TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_employee RECORD;
    v_pin_valid BOOLEAN := false;
BEGIN
    SELECT * INTO v_employee
    FROM public.employees
    WHERE alias = p_username 
      AND is_active = true;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Usuario no encontrado');
    END IF;

    -- Dual Check
    IF v_employee.pin_code IS NOT DISTINCT FROM p_pin THEN
        v_pin_valid := true;
    ELSIF v_employee.pin_hash IS NOT NULL AND v_employee.pin_hash = crypt(p_pin, v_employee.pin_hash) THEN
        v_pin_valid := true;
    END IF;

    IF NOT v_pin_valid THEN
        RETURN jsonb_build_object('success', false, 'error', 'PIN Incorrecto');
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'employee', jsonb_build_object(
            'id', v_employee.id,
            'name', v_employee.name,
            'username', v_employee.alias, -- Return alias as username
            'store_id', v_employee.store_id,
            'permissions', v_employee.permissions
        )
    );
END;
$$;
GRANT EXECUTE ON FUNCTION public.validar_pin_empleado(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.validar_pin_empleado(text, text) TO anon;

-- 5. Update 'request_employee_access' (Zero-Auth Login) to support dual-pin strategy
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
    v_pass_status TEXT;
    v_store_owner_email TEXT;
    v_pin_valid BOOLEAN := false;
BEGIN
    -- A. Identificar Empleado y Validar PIN
    SELECT e.*, s.email as owner_email 
    INTO v_employee
    FROM public.employees e
    JOIN public.stores s ON e.store_id = s.id
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

    -- B. Gestión del Pase Diario (Copied from previous migration)
    SELECT id, status INTO v_pass_id, v_pass_status
    FROM public.daily_passes
    WHERE employee_id = v_employee.id 
      AND pass_date = CURRENT_DATE;

    IF v_pass_status = 'approved' THEN
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
    END IF;

    IF v_pass_status = 'pending' THEN
        RETURN jsonb_build_object(
            'success', true,
            'status', 'pending',
            'message', 'Esperando aprobación del administrador',
            'pass_id', v_pass_id
        );
    END IF;

    INSERT INTO public.daily_passes (
        employee_id,
        store_id,
        device_fingerprint,
        status,
        pass_date,
        requested_at
    ) VALUES (
        v_employee.id,
        v_employee.store_id,
        p_device_fingerprint,
        'pending',
        CURRENT_DATE,
        now()
    ) RETURNING id INTO v_pass_id;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'pending',
        'message', 'Solicitud enviada. Esperando aprobación.',
        'pass_id', v_pass_id
    );

END;
$$;
GRANT EXECUTE ON FUNCTION public.request_employee_access(text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.request_employee_access(text, text, text) TO authenticated;

-- MIGRATION: FIX_POS_ACCESS_RLS_V2
-- Datum: 2026-02-02
-- Description: 
-- 1. Updates `request_employee_access` to persist `auth.uid()` in `daily_passes`.
-- 2. ENFORCES STRICT SESSION CHECK: A pass is only valid for the specific anonymous `auth.uid()`.
--    This prevents "Authorization Bypass" where a new device inherits an old approval.
-- 3. Updates `get_current_store_id` to resolve store_id from `daily_passes` using `auth.uid()`.

-- 1. Update `request_employee_access` with STRICT Auth Check
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
    v_pin_valid BOOLEAN := false;
BEGIN
    -- A. Identificar Empleado y Validar PIN
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

    -- B. Gestión del Pase Diario (STRICT SESSION CHECK)
    -- Buscamos un pase aprobado PARA ESTA SESION ESPECIFICA (auth.uid())
    SELECT id, status INTO v_pass_id, v_pass_status
    FROM public.daily_passes
    WHERE employee_id = v_employee.id 
      AND pass_date = CURRENT_DATE
      AND auth_user_id = auth.uid(); -- KEY SECURITY FIX: Must match current session

    -- Si ya existe y está aprobado PARA MI SESION, devolvemos éxito
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

    -- C. Si no existe pase para esta sesion, CREAMOS UNO NUEVO (Aunque el empleado tenga otros pases)
    INSERT INTO public.daily_passes (
        employee_id,
        store_id,
        device_fingerprint,
        status,
        pass_date,
        requested_at,
        auth_user_id -- Persist Session ID
    ) VALUES (
        v_employee.id,
        v_employee.store_id,
        p_device_fingerprint,
        'pending',
        CURRENT_DATE,
        now(),
        auth.uid() -- Bind to this specific anonymous session
    ) RETURNING id INTO v_pass_id;

    -- Encolar Notificación 
    BEGIN
        IF v_employee.owner_email IS NOT NULL THEN
            INSERT INTO public.notification_queue (type, recipient_email, payload)
            VALUES (
                'daily_pass_request',
                v_employee.owner_email,
                jsonb_build_object(
                    'employee_name', v_employee.name,
                    'store_id', v_employee.store_id,
                    'pass_id', v_pass_id,
                    'timestamp', now()
                )
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Error encolando notificacion: %', SQLERRM;
    END;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'pending',
        'message', 'Solicitud enviada. Esperando aprobación.',
        'pass_id', v_pass_id
    );

END;
$$;


-- 2. Update `get_current_store_id` (The RLS Key)
CREATE OR REPLACE FUNCTION public.get_current_store_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_store_id UUID;
BEGIN
  -- 1. Intentar obtener desde App Metadata (JWT)
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

  -- 3. Fallback: Buscar en employees (Usuario de sistema con auth real)
  SELECT store_id INTO v_store_id
  FROM public.employees
  WHERE id = auth.uid();

  IF v_store_id IS NOT NULL THEN
    RETURN v_store_id;
  END IF;

  -- 4. Fallback: Buscar en daily_passes (Empleados Anonimos con Pase Aprobado)
  SELECT store_id INTO v_store_id
  FROM public.daily_passes
  WHERE auth_user_id = auth.uid() 
    AND status = 'approved' 
    AND pass_date = CURRENT_DATE;

  RETURN v_store_id;
END;
$$;

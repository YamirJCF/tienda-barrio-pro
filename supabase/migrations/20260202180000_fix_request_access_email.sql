-- MIGRATION: FIX_REQUEST_ACCESS_EMAIL
-- Datum: 2026-02-02
-- Description: 
-- Fixes 'column s.email does not exist' error in 'request_employee_access' RPC.
-- Corrects the query to join 'auth.users' via 'stores.owner_id' to retrieve the owner's email.

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
    -- FIX: Join with auth.users to get email, as stores.email does not exist
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

    -- B. Gestión del Pase Diario
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

    -- Crear nuevo pase
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

    -- Encolar Notificación (Opcional, si falla no bloquea login)
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
        -- Ignorar error de notificación
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
GRANT EXECUTE ON FUNCTION public.request_employee_access(text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.request_employee_access(text, text, text) TO authenticated;

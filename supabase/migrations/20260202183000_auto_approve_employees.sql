-- MIGRATION: AUTO_APPROVE_EMPLOYEES_MVP
-- Datum: 2026-02-02
-- Description: 
-- modifies `request_employee_access` to AUTO-APPROVE requests if the PIN is valid.
-- This removes the wait time for the MVP phase, acting as a "Pass-Through" Auth.
-- Security Note: Still enforces 4-digit PIN + Device Hard Binding (RLS), just skips manual review.

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

    -- B. Gestión del Pase Diario (STRICT SESSION CHECK)
    SELECT id, status INTO v_pass_id, v_pass_status
    FROM public.daily_passes
    WHERE employee_id = v_employee.id 
      AND pass_date = CURRENT_DATE
      AND auth_user_id = auth.uid(); 

    -- Si ya existe y está aprobado, éxito directo
    IF v_pass_status = 'approved' THEN
        RETURN jsonb_build_object(
            'success', true,
            'status', 'approved',
            'employee', jsonb_build_object(
                'id', v_employee.id,
                'name', v_employee.name,
                'role', 'employee',
                'store_id', v_employee.store_id, -- STORE ID ALWAYS COMES FROM EMPLOYEE RECORD
                'permissions', v_employee.permissions
            )
        );
    END IF;

    -- C. Crear nuevo pase (AUTO-APPROVED FOR MVP)
    INSERT INTO public.daily_passes (
        employee_id,
        store_id,
        device_fingerprint,
        status,
        pass_date,
        requested_at,
        resolved_at,        -- Auto-Resolved time
        resolved_by,        -- System Auto-Resolution
        auth_user_id
    ) VALUES (
        v_employee.id,
        v_employee.store_id,
        p_device_fingerprint,
        'approved',         -- MVP: Bypass 'pending'
        CURRENT_DATE,
        now(),
        now(),              -- Resolved immediately
        v_employee.id,      -- Self-authorized via PIN
        auth.uid()
    ) RETURNING id INTO v_pass_id;

    -- Notificación Ops (Opcional - Cambio a "Nuevo Acceso" en vez de "Solicitud")
    BEGIN
        IF v_employee.owner_email IS NOT NULL THEN
            INSERT INTO public.notification_queue (type, recipient_email, payload)
            VALUES (
                'daily_pass_approved', -- Changed type to reflect auto-approval
                v_employee.owner_email,
                jsonb_build_object(
                    'employee_name', v_employee.name,
                    'store_id', v_employee.store_id,
                    'pass_id', v_pass_id,
                    'timestamp', now(),
                    'method', 'auto_mvp'
                )
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Error notificacion: %', SQLERRM;
    END;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'approved',  -- Immediate Success
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

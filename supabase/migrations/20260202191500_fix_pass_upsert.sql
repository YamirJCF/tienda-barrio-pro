-- MIGRATION: FIX_PASS_UPSERT
-- Datum: 2026-02-02
-- Description: 
-- Modifies `request_employee_access` to use UPSERT (ON CONFLICT).
-- Solves Error 409 (Duplicate Key) when an employee logs in twice or re-opens the app.
-- Implements "Session Takeover": The latest device/session gets the active pass.

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

    -- B. Gestión del Pase Diario (UPSERT PATTERN)
    -- Intenta insertar. Si choca con el UNIQUE(employee_id, pass_date), actualiza la sesión.
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
        'approved',         -- MVP: Auto-Approve
        CURRENT_DATE,
        now(),
        now(),
        v_employee.id,
        auth.uid()
    )
    ON CONFLICT (employee_id, pass_date) 
    DO UPDATE SET 
        auth_user_id = EXCLUDED.auth_user_id, -- Takeover Session
        device_fingerprint = EXCLUDED.device_fingerprint,
        status = 'approved', -- Ensure it's approved
        updated_at = now()
    RETURNING id INTO v_pass_id;

    -- Log de Auditoría / Notificación (Simplificado)
    -- Podríamos registrar que hubo un takeover, pero para MVP es suficiente.

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

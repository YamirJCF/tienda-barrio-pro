-- MIGRATION: RESTORE_GATEKEEPER_HISTORY
-- Date: 2026-04-17
-- Description:
-- Fixes request_employee_access to NOT join stores.owner_id (which doesnt exist).
-- Restores ZERO TRUST INITIAL 'pending' status for devices, overriding the accidental auto-approve.
-- Re-introduces aprobar_pase_diario RPC to handle the authorization from frontend.

CREATE OR REPLACE FUNCTION public.request_employee_access(
    p_username TEXT,
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
    SELECT e.* 
    INTO v_employee
    FROM public.employees e
    JOIN public.stores s ON e.store_id = s.id
    WHERE e.username = p_username;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'code', 'USER_NOT_FOUND', 'message', 'Alias no existe');
    END IF;

    IF v_employee.pin_hash IS NOT NULL AND v_employee.pin_hash = crypt(p_pin, v_employee.pin_hash) THEN
         v_pin_valid := true;
    END IF;

    IF NOT v_pin_valid THEN
         RETURN jsonb_build_object('success', false, 'code', 'INVALID_CREDENTIALS', 'message', 'PIN Incorrecto');
    END IF;

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
        'pending', 
        CURRENT_DATE,
        now(),
        now(),
        NULL, 
        auth.uid()
    )
    ON CONFLICT (employee_id, pass_date) 
    DO UPDATE SET 
        auth_user_id = EXCLUDED.auth_user_id,
        device_fingerprint = EXCLUDED.device_fingerprint,
        status = CASE 
            WHEN public.daily_passes.status = 'approved' AND public.daily_passes.device_fingerprint = EXCLUDED.device_fingerprint THEN 'approved' 
            ELSE 'pending' 
        END,
        requested_at = now(),
        updated_at = now()
    RETURNING id INTO v_pass_id;

    IF (SELECT status FROM public.daily_passes WHERE id = v_pass_id) = 'approved' THEN
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
    ELSE
        RETURN jsonb_build_object(
            'success', true,
            'status', 'pending',
            'pass_id', v_pass_id,
            'employee', jsonb_build_object(
                'id', v_employee.id,
                'name', v_employee.name,
                'role', 'employee',
                'store_id', v_employee.store_id,
                'permissions', v_employee.permissions
            )
        );
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.request_employee_access(text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.request_employee_access(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_employee_access(text, text, text) TO service_role;

CREATE OR REPLACE FUNCTION public.aprobar_pase_diario(p_pass_id uuid, p_admin_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.daily_passes
  SET status = 'approved', resolved_at = now(), resolved_by = p_admin_id
  WHERE id = p_pass_id AND status = 'pending';
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Pase no encontrado o ya procesado', 'code', 'NOT_FOUND');
  END IF;
  
  RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.aprobar_pase_diario(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aprobar_pase_diario(uuid, uuid) TO service_role;

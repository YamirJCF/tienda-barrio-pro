-- Migración: Verificación Continua de Sesión y Unificación de Criterio de Pases Diarios
-- SDD: SDD_013_GESTION_SESIONES v3.1.0
-- Fecha: 2026-10-31

-- 1. Unificar check_daily_pass_status con el criterio canónico de Bogotá y cruce nocturno de get_current_store_id()
CREATE OR REPLACE FUNCTION public.check_daily_pass_status(
  p_employee_id uuid,
  p_device_fingerprint text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_pass public.daily_passes%ROWTYPE;
  v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
BEGIN
  -- Unificación de criterio con get_current_store_id() y get_employee_id_from_session()
  SELECT * INTO v_pass 
  FROM public.daily_passes
  WHERE employee_id = p_employee_id
    AND (
      pass_date = v_today
      OR (
        pass_date = v_today - 1
        AND EXISTS (
          SELECT 1 FROM public.cash_sessions cs
          WHERE cs.store_id = daily_passes.store_id
            AND cs.status = 'open'
            AND cs.opened_at >= (now() - interval '24 hours')
        )
      )
    )
  ORDER BY requested_at DESC 
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object('status', 'none');
  END IF;

  RETURN json_build_object(
    'status', v_pass.status,
    'pass_id', v_pass.id,
    'retry_count', v_pass.retry_count
  );
END;
$$;

-- 2. Nueva RPC: rpc_verificar_estado_sesion
CREATE OR REPLACE FUNCTION public.rpc_verificar_estado_sesion()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_auth_uid UUID := auth.uid();
  v_store_id UUID;
  v_role TEXT := 'employee';
  v_user_name TEXT := 'Usuario';
  v_store_name TEXT := 'Mi Tienda';
  v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
  v_pass RECORD;
  v_emp RECORD;
  v_admin RECORD;
BEGIN
  -- 1. Si no hay auth.uid() en Supabase, sesión no autenticada en servidor
  IF v_auth_uid IS NULL THEN
    RETURN json_build_object(
      'success', false,
      'status', 'requires_login',
      'reason', 'NO_AUTH_TOKEN'
    );
  END IF;

  -- 2. Identificar si es Administrador / Dueño
  SELECT ap.store_id, ap.role, s.name, (s.subscription_plan IS NOT NULL) AS is_active
  INTO v_admin
  FROM public.admin_profiles ap
  JOIN public.stores s ON s.id = ap.store_id
  WHERE ap.id = v_auth_uid;

  IF FOUND THEN
    RETURN json_build_object(
      'success', true,
      'status', 'active',
      'role', COALESCE(v_admin.role, 'admin'),
      'store_id', v_admin.store_id,
      'store_name', v_admin.name,
      'user_id', v_auth_uid,
      'pass_id', NULL
    );
  END IF;

  -- 3. Identificar si es Empleado autenticado directo
  SELECT e.id, e.store_id, e.name, e.is_active, s.name AS store_name
  INTO v_emp
  FROM public.employees e
  JOIN public.stores s ON s.id = e.store_id
  WHERE e.id = v_auth_uid;

  IF FOUND THEN
    IF NOT v_emp.is_active THEN
      RETURN json_build_object(
        'success', false,
        'status', 'revoked_or_disabled',
        'reason', 'EMPLOYEE_INACTIVE'
      );
    END IF;

    RETURN json_build_object(
      'success', true,
      'status', 'active',
      'role', 'employee',
      'store_id', v_emp.store_id,
      'store_name', v_emp.store_name,
      'employee_id', v_emp.id,
      'user_name', v_emp.name,
      'pass_id', NULL
    );
  END IF;

  -- 4. Identificar si es Empleado operando vía Daily Pass
  SELECT dp.id AS pass_id, dp.employee_id, dp.store_id, dp.status, dp.pass_date,
         e.name AS employee_name, e.is_active AS employee_active, s.name AS store_name
  INTO v_pass
  FROM public.daily_passes dp
  JOIN public.employees e ON e.id = dp.employee_id
  JOIN public.stores s ON s.id = dp.store_id
  WHERE dp.auth_user_id = v_auth_uid
  ORDER BY dp.requested_at DESC
  LIMIT 1;

  IF FOUND THEN
    -- Validar si el empleado fue desactivado
    IF NOT v_pass.employee_active THEN
      RETURN json_build_object(
        'success', false,
        'status', 'revoked_or_disabled',
        'reason', 'EMPLOYEE_INACTIVE'
      );
    END IF;

    -- Validar si el pase fue revocado o rechazado
    IF v_pass.status = 'rejected' OR v_pass.status = 'revoked' THEN
      RETURN json_build_object(
        'success', false,
        'status', 'revoked_or_disabled',
        'reason', 'PASS_REVOKED_OR_REJECTED'
      );
    END IF;

    -- Validar si el pase está aprobado y vigente según la regla unificada (hoy o turno nocturno con caja abierta)
    IF v_pass.status = 'approved' AND (
      v_pass.pass_date = v_today
      OR (
        v_pass.pass_date = v_today - 1
        AND EXISTS (
          SELECT 1 FROM public.cash_sessions cs
          WHERE cs.store_id = v_pass.store_id
            AND cs.status = 'open'
            AND cs.opened_at >= (now() - interval '24 hours')
        )
      )
    ) THEN
      RETURN json_build_object(
        'success', true,
        'status', 'active',
        'role', 'employee',
        'store_id', v_pass.store_id,
        'store_name', v_pass.store_name,
        'employee_id', v_pass.employee_id,
        'user_name', v_pass.employee_name,
        'pass_id', v_pass.pass_id
      );
    ELSE
      -- Pase expiró de fecha o pendiente de renovación diaria
      RETURN json_build_object(
        'success', false,
        'status', 'requires_daily_pass',
        'reason', 'PASS_EXPIRED_OR_PENDING',
        'store_id', v_pass.store_id,
        'employee_id', v_pass.employee_id
      );
    END IF;
  END IF;

  -- 5. Si no coincide con ninguna entidad válida
  RETURN json_build_object(
    'success', false,
    'status', 'requires_login',
    'reason', 'UNKNOWN_IDENTITY'
  );
END;
$$;

-- 3. Privilegios explícitos (Regla 8)
GRANT EXECUTE ON FUNCTION public.check_daily_pass_status(uuid, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_verificar_estado_sesion() TO anon, authenticated, service_role;

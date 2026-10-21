-- ==============================================================================
-- FIX: rpc_reconciliar_cierre_forzado (reconciliación de cierre forzado a las 24h)
--
-- Defectos corregidos (verificados contra producción el 2026-10-21):
--   1. INSERT en audit_logs usaba columnas inexistentes (action, entity, entity_id,
--      payload) -> error 42703 en cada reconciliación (la reconciliación nunca funcionó).
--      Columnas reales: actor_id, event_type, resource_id, metadata, store_id, severity.
--   2. Sin assert_store_access (Regla 4): cualquier autenticado podía reconciliar
--      sesiones de otra tienda (SECURITY DEFINER sin validación de tenant).
--   3. Retornaba {success:false} para errores de negocio (Regla 3): ahora RAISE.
--   4. Convención de signo invertida (expected - actual). Se estandariza a
--      difference = actual - expected (positivo = sobrante), igual que cerrar_caja
--      y conforme a SDD_020 H-5.
--   5. Sin SET search_path en función SECURITY DEFINER.
--
-- Firma y nombre se conservan (Muro 2). Sin consumidores SQL (pg_proc: 0).
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.rpc_reconciliar_cierre_forzado(
    p_session_id     UUID,
    p_employee_id    UUID,
    p_actual_balance NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_session     public.cash_sessions%ROWTYPE;
    v_permissions JSONB;
    v_role        TEXT;
    v_difference  NUMERIC;
BEGIN
    IF p_actual_balance IS NULL OR p_actual_balance < 0 THEN
        RAISE EXCEPTION 'INVALID_BALANCE: El balance real debe ser mayor o igual a cero.'
            USING ERRCODE = '22023';
    END IF;

    -- Bloqueo de fila: evita doble reconciliación concurrente
    SELECT * INTO v_session
    FROM public.cash_sessions
    WHERE id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'SESSION_NOT_FOUND: La sesión de caja (%) no existe.', p_session_id
            USING ERRCODE = 'P0002';
    END IF;

    -- Aislamiento multi-tenant centralizado (Regla 4)
    PERFORM public.assert_store_access(v_session.store_id);

    -- El empleado debe existir en la misma tienda (FK cash_sessions.closed_by -> employees)
    SELECT e.permissions INTO v_permissions
    FROM public.employees e
    WHERE e.id = p_employee_id
      AND e.store_id = v_session.store_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'EMPLOYEE_NOT_FOUND: El empleado no existe en la tienda de la sesión.'
            USING ERRCODE = 'P0002';
    END IF;

    -- Autorización: admin/owner de la tienda o permiso canOpenCloseCash
    SELECT ap.role INTO v_role
    FROM public.admin_profiles ap
    WHERE ap.id = auth.uid()
      AND ap.store_id = v_session.store_id;

    IF (v_role IS NULL OR v_role NOT IN ('admin', 'owner'))
       AND NOT COALESCE((v_permissions ->> 'canOpenCloseCash')::boolean, false) THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERMISSIONS: Sin permiso para reconciliar cierres de caja.'
            USING ERRCODE = 'P0001';
    END IF;

    -- audit_logs.actor_id tiene DOS FK (employees y auth.users: fk_audit_user).
    -- Un empleado sin identidad en auth.users no puede ser actor de auditoría:
    -- se falla de forma explícita en lugar de un error de FK críptico (Regla 3).
    IF NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = p_employee_id) THEN
        RAISE EXCEPTION 'AUDIT_ACTOR_UNRESOLVABLE: El empleado no tiene identidad de autenticación para firmar la auditoría. Debe reconciliar un administrador.'
            USING ERRCODE = 'P0001';
    END IF;

    -- Precondiciones estrictas (evita doble reconciliación)
    IF v_session.status <> 'closed'
       OR COALESCE(v_session.forced_close, false) = false
       OR v_session.actual_balance IS NOT NULL THEN
        RAISE EXCEPTION 'SESSION_NOT_RECONCILABLE: La sesión no fue cerrada forzosamente o ya fue reconciliada.'
            USING ERRCODE = 'P0001';
    END IF;

    -- Convención contable (igual a cerrar_caja): actual - expected (negativo = faltante)
    v_difference := p_actual_balance - v_session.expected_balance;

    -- No modifica status: no dispara trg_audit_cash_closed (AFTER UPDATE OF status)
    UPDATE public.cash_sessions
    SET actual_balance = p_actual_balance,
        difference     = v_difference,
        closed_by      = p_employee_id
    WHERE id = p_session_id;

    -- Bitácora con las columnas reales de audit_logs
    INSERT INTO public.audit_logs (
        actor_id, store_id, event_type, resource_id, metadata, severity, created_at
    ) VALUES (
        p_employee_id,
        v_session.store_id,
        'FORCED_CLOSE_RECONCILED',
        p_session_id::text,
        jsonb_build_object(
            'reconciled_by',    p_employee_id,
            'actual_balance',   p_actual_balance,
            'expected_balance', v_session.expected_balance,
            'difference',       v_difference,
            'reconciled_at',    NOW()
        ),
        CASE WHEN v_difference = 0 THEN 'info' ELSE 'warning' END,
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'session_id',       p_session_id,
            'expected_balance', v_session.expected_balance,
            'actual_balance',   p_actual_balance,
            'difference',       v_difference
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_reconciliar_cierre_forzado(UUID, UUID, NUMERIC) TO authenticated, service_role;

-- ============================================================================
-- MIGRACIÓN: Cierre Forzado (+24h) con Declaración Obligatoria de Efectivo Físico,
--            Ficha Resumen para Admin y Observación Obligatoria en Turno Ajeno
-- Fecha: 2026-11-27
-- Referencias: ARQ-002 (POL-SEG-01, POL-SEG-02), FRD-027-02, FRD-004 v2.3
-- ============================================================================

-- 1. rpc_check_and_force_close_shifts:
--    Alinea expected_balance exclusivamente al EFECTIVO físico del cajón
--    (sin mezclar Nequi ni Llave Bre-B).
CREATE OR REPLACE FUNCTION public.rpc_check_and_force_close_shifts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    r RECORD;
    v_ingresos_efectivo NUMERIC;
    v_gastos_efectivo NUMERIC;
    v_expected_efectivo NUMERIC;
    v_emp_fk_id UUID;
    closed_count INT := 0;
BEGIN
    FOR r IN
        SELECT id, store_id, opened_by, opened_by_name, opened_by_role, opening_balance, opened_at
        FROM public.cash_sessions
        WHERE status = 'open'
          AND opened_at < (NOW() - INTERVAL '24 hours')
        FOR UPDATE
    LOOP
        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos_efectivo
        FROM public.cash_movements
        WHERE session_id = r.id
          AND movement_type = 'ingreso'
          AND payment_method = 'efectivo';

        SELECT COALESCE(SUM(amount), 0) INTO v_gastos_efectivo
        FROM public.cash_movements
        WHERE session_id = r.id
          AND movement_type IN ('gasto', 'pago_proveedor', 'reembolso')
          AND payment_method = 'efectivo';

        v_expected_efectivo := COALESCE(r.opening_balance, 0) + v_ingresos_efectivo - v_gastos_efectivo;

        UPDATE public.cash_sessions
        SET status           = 'closed',
            forced_close     = true,
            expected_balance = v_expected_efectivo,
            actual_balance   = NULL,
            difference       = NULL,
            closed_at        = NOW()
        WHERE id = r.id;

        SELECT id INTO v_emp_fk_id FROM public.employees WHERE id = r.opened_by LIMIT 1;

        INSERT INTO public.audit_logs (
            actor_id,
            actor_name,
            actor_role,
            store_id,
            event_type,
            resource_id,
            metadata,
            severity,
            created_at
        ) VALUES (
            v_emp_fk_id,
            COALESCE(r.opened_by_name, 'Sistema (24h)'),
            COALESCE(r.opened_by_role, 'employee'),
            r.store_id,
            'FORCED_CLOSE_24H',
            r.id::text,
            jsonb_build_object(
                'reason', 'Shift exceeded 24 hours without manual closure',
                'lifecycle_state', 'Expirado/Bloqueado',
                'opened_by', r.opened_by,
                'opened_by_name', r.opened_by_name,
                'opened_at', r.opened_at,
                'forced_at', NOW(),
                'expected_efectivo', v_expected_efectivo
            ),
            'warning',
            NOW()
        );

        INSERT INTO public.notifications (
            store_id,
            type,
            title,
            message,
            audience,
            is_read,
            metadata,
            created_at
        ) VALUES (
            r.store_id,
            'finance',
            'Turno Vencido (+24h)',
            format('El turno abierto por %s superó las 24 horas y fue bloqueado para cierre obligatorio.', COALESCE(r.opened_by_name, 'un usuario')),
            'admin',
            false,
            jsonb_build_object(
                'event_type', 'FORCED_CLOSE_24H',
                'session_id', r.id,
                'opened_by', r.opened_by,
                'opened_by_name', r.opened_by_name
            ),
            NOW()
        );

        closed_count := closed_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'closed_count', closed_count);
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

-- 2. rpc_obtener_turnos_forzados_pendientes (EXCLUSIVO ADMINISTRADOR):
--    Entrega la ficha resumen autoritativa del servidor para cada turno +24h pendiente
--    (quién lo abrió, base inicial, efectivo esperado en cajón y resumen informativo digital).
CREATE OR REPLACE FUNCTION public.rpc_obtener_turnos_forzados_pendientes(p_store_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_snap RECORD;
    v_result JSONB := '[]'::jsonb;
    r RECORD;
    v_in_efectivo NUMERIC;
    v_out_efectivo NUMERIC;
    v_in_nequi NUMERIC;
    v_out_nequi NUMERIC;
    v_in_llave_bre NUMERIC;
    v_out_llave_bre NUMERIC;
    v_expected_efectivo NUMERIC;
BEGIN
    PERFORM public.assert_store_access(p_store_id);
    PERFORM public.assert_store_admin(p_store_id);

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(p_store_id);

    FOR r IN
        SELECT id, opened_at, opened_by, opened_by_name, opened_by_role, opening_balance
        FROM public.cash_sessions
        WHERE store_id = p_store_id
          AND status = 'closed'
          AND COALESCE(forced_close, false) = true
          AND actual_balance IS NULL
        ORDER BY opened_at ASC
    LOOP
        SELECT COALESCE(SUM(amount), 0) INTO v_in_efectivo
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type = 'ingreso' AND payment_method = 'efectivo';

        SELECT COALESCE(SUM(amount), 0) INTO v_out_efectivo
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type IN ('gasto', 'pago_proveedor', 'reembolso') AND payment_method = 'efectivo';

        SELECT COALESCE(SUM(amount), 0) INTO v_in_nequi
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type = 'ingreso' AND payment_method = 'nequi';

        SELECT COALESCE(SUM(amount), 0) INTO v_out_nequi
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type IN ('gasto', 'pago_proveedor', 'reembolso') AND payment_method = 'nequi';

        SELECT COALESCE(SUM(amount), 0) INTO v_in_llave_bre
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type = 'ingreso' AND payment_method = 'llave_bre';

        SELECT COALESCE(SUM(amount), 0) INTO v_out_llave_bre
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type IN ('gasto', 'pago_proveedor', 'reembolso') AND payment_method = 'llave_bre';

        v_expected_efectivo := COALESCE(r.opening_balance, 0) + v_in_efectivo - v_out_efectivo;

        v_result := v_result || jsonb_build_array(
            jsonb_build_object(
                'id', r.id,
                'opened_at', r.opened_at,
                'opened_by', r.opened_by,
                'opened_by_name', COALESCE(r.opened_by_name, 'Usuario'),
                'opened_by_role', COALESCE(r.opened_by_role, 'employee'),
                'opening_balance', COALESCE(r.opening_balance, 0),
                'expected_efectivo', v_expected_efectivo,
                'nequi_summary', v_in_nequi - v_out_nequi,
                'llave_bre_summary', v_in_llave_bre - v_out_llave_bre,
                'is_opened_by_other', (r.opened_by IS DISTINCT FROM v_snap.actor_id)
            )
        );
    END LOOP;

    RETURN jsonb_build_object('success', true, 'data', v_result);
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

-- 3. rpc_reconciliar_cierre_forzado (Declaración OBLIGATORIA de efectivo físico):
--    - Rechaza p_actual_balance IS NULL o < 0 (CERO cierres sin conteo).
--    - Exige observación breve (>= 5 caracteres) cuando el Admin cierra el turno vencido de otro usuario.
--    - Recalcula expected_balance exclusivamente en efectivo físico y guarda la diferencia exacta al peso.
DROP FUNCTION IF EXISTS public.rpc_reconciliar_cierre_forzado(uuid, uuid, numeric);
DROP FUNCTION IF EXISTS public.rpc_reconciliar_cierre_forzado(uuid, uuid, numeric, text);

CREATE OR REPLACE FUNCTION public.rpc_reconciliar_cierre_forzado(
    p_session_id uuid,
    p_employee_id uuid DEFAULT NULL::uuid,
    p_actual_balance numeric DEFAULT NULL::numeric,
    p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_session           public.cash_sessions%ROWTYPE;
    v_snap              RECORD;
    v_emp_fk_id         UUID;
    v_is_other_opener   BOOLEAN := false;
    v_in_efectivo       NUMERIC := 0;
    v_out_efectivo      NUMERIC := 0;
    v_in_nequi          NUMERIC := 0;
    v_out_nequi         NUMERIC := 0;
    v_in_llave_bre      NUMERIC := 0;
    v_out_llave_bre     NUMERIC := 0;
    v_expected_efectivo NUMERIC := 0;
    v_difference        NUMERIC := 0;
    v_clean_notes       TEXT := NULLIF(trim(COALESCE(p_notes, '')), '');
BEGIN
    -- Prohibición absoluta de cerrar sin declarar monto físico
    IF p_actual_balance IS NULL OR p_actual_balance < 0 THEN
        RAISE EXCEPTION 'INVALID_BALANCE: Debes declarar explícitamente el efectivo físico recuperado (0 o mayor). No se permite cerrar sin conteo.'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_session
    FROM public.cash_sessions
    WHERE id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'SESSION_NOT_FOUND: La sesión de caja (%) no existe.', p_session_id
            USING ERRCODE = 'P0002';
    END IF;

    PERFORM public.assert_store_access(v_session.store_id);
    PERFORM public.assert_store_admin(v_session.store_id);

    IF v_session.status <> 'closed'
       OR COALESCE(v_session.forced_close, false) = false
       OR v_session.actual_balance IS NOT NULL THEN
        RAISE EXCEPTION 'SESSION_NOT_RECONCILABLE: La sesión no fue cerrada forzosamente o ya fue reconciliada.'
            USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_session.store_id);
    SELECT e.id INTO v_emp_fk_id
    FROM public.employees e
    WHERE e.id = v_snap.actor_id AND e.store_id = v_session.store_id
    LIMIT 1;

    v_is_other_opener := (v_session.opened_by IS DISTINCT FROM v_snap.actor_id);

    IF v_is_other_opener AND (v_clean_notes IS NULL OR length(v_clean_notes) < 5) THEN
        RAISE EXCEPTION 'OBSERVATION_REQUIRED: Debes escribir una observación breve (mínimo 5 caracteres) al cerrar un turno vencido abierto por otro usuario.'
            USING ERRCODE = '22023';
    END IF;

    -- Recalcular esperado exclusivamente en efectivo físico del cajón
    SELECT COALESCE(SUM(amount), 0) INTO v_in_efectivo
    FROM public.cash_movements
    WHERE session_id = p_session_id AND movement_type = 'ingreso' AND payment_method = 'efectivo';

    SELECT COALESCE(SUM(amount), 0) INTO v_out_efectivo
    FROM public.cash_movements
    WHERE session_id = p_session_id AND movement_type IN ('gasto', 'pago_proveedor', 'reembolso') AND payment_method = 'efectivo';

    SELECT COALESCE(SUM(amount), 0) INTO v_in_nequi
    FROM public.cash_movements
    WHERE session_id = p_session_id AND movement_type = 'ingreso' AND payment_method = 'nequi';

    SELECT COALESCE(SUM(amount), 0) INTO v_out_nequi
    FROM public.cash_movements
    WHERE session_id = p_session_id AND movement_type IN ('gasto', 'pago_proveedor', 'reembolso') AND payment_method = 'nequi';

    SELECT COALESCE(SUM(amount), 0) INTO v_in_llave_bre
    FROM public.cash_movements
    WHERE session_id = p_session_id AND movement_type = 'ingreso' AND payment_method = 'llave_bre';

    SELECT COALESCE(SUM(amount), 0) INTO v_out_llave_bre
    FROM public.cash_movements
    WHERE session_id = p_session_id AND movement_type IN ('gasto', 'pago_proveedor', 'reembolso') AND payment_method = 'llave_bre';

    v_expected_efectivo := COALESCE(v_session.opening_balance, 0) + v_in_efectivo - v_out_efectivo;
    v_difference        := p_actual_balance - v_expected_efectivo;

    UPDATE public.cash_sessions
    SET expected_balance           = v_expected_efectivo,
        actual_balance             = p_actual_balance,
        difference                 = v_difference,
        closed_by                  = v_snap.actor_id,
        closed_by_name             = v_snap.actor_name,
        closed_by_role             = v_snap.actor_role,
        forced_close_without_count = false
    WHERE id = p_session_id;

    INSERT INTO public.audit_logs (
        actor_id, actor_name, actor_role, store_id, event_type, resource_id, metadata, severity, created_at
    ) VALUES (
        v_emp_fk_id,
        v_snap.actor_name,
        v_snap.actor_role,
        v_session.store_id,
        'FORCED_CLOSE_RECONCILED',
        p_session_id::text,
        jsonb_build_object(
            'session_id', p_session_id,
            'opened_by', v_session.opened_by,
            'opened_by_name', v_session.opened_by_name,
            'is_opened_by_other', v_is_other_opener,
            'notes', v_clean_notes,
            'expected_efectivo', v_expected_efectivo,
            'actual_efectivo', p_actual_balance,
            'difference', v_difference,
            'digital_summary', jsonb_build_object(
                'nequi', v_in_nequi - v_out_nequi,
                'llave_bre', v_in_llave_bre - v_out_llave_bre
            )
        ),
        CASE WHEN v_difference <> 0 OR v_is_other_opener THEN 'warning' ELSE 'info' END,
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'session_id', p_session_id,
        'expected_efectivo', v_expected_efectivo,
        'actual_efectivo', p_actual_balance,
        'difference', v_difference
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_check_and_force_close_shifts() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_check_and_force_close_shifts() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_obtener_turnos_forzados_pendientes(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_obtener_turnos_forzados_pendientes(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_reconciliar_cierre_forzado(uuid, uuid, numeric, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_reconciliar_cierre_forzado(uuid, uuid, numeric, text) TO authenticated, service_role;

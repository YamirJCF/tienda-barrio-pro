-- ============================================================================
-- MIGRACIÓN: ARQ-005 / POL-SEG-01 v1.5 — Arqueo Físico Exclusivo de Efectivo,
--            Resumen Esperado para Admin y Margen Global P_MARGEN_DESCUADRE_EFECTIVO
-- Fecha: 2026-11-26
-- Referencias: ARQ-002 v1.5 (POL-SEG-01), ARQ-004 v1.2, ARQ-005 v1.0, FRD-004 v2.3
-- ============================================================================

-- 1. Tabla global de parámetros del sistema (ARQ-004)
--    Regla 8: GRANT ALL explícito en toda tabla nueva.
CREATE TABLE IF NOT EXISTS public.system_parameters (
    code text PRIMARY KEY,
    name text NOT NULL,
    numeric_value numeric,
    text_value text,
    unit text NOT NULL,
    policy_origin text NOT NULL,
    scope text NOT NULL DEFAULT 'global',
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.system_parameters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "system_parameters_read_authenticated" ON public.system_parameters;
CREATE POLICY "system_parameters_read_authenticated"
    ON public.system_parameters
    FOR SELECT
    TO authenticated
    USING (true);

GRANT ALL ON TABLE public.system_parameters TO anon, authenticated, service_role;

INSERT INTO public.system_parameters (
    code,
    name,
    numeric_value,
    unit,
    policy_origin,
    scope
) VALUES (
    'P_MARGEN_DESCUADRE_EFECTIVO',
    'Margen global permitido para monedas sueltas en el arqueo ciego de efectivo de empleados',
    1000,
    'COP',
    'POL-SEG-01',
    'global'
)
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name,
    numeric_value = EXCLUDED.numeric_value,
    unit = EXCLUDED.unit,
    policy_origin = EXCLUDED.policy_origin,
    scope = EXCLUDED.scope,
    updated_at = now();

-- 2. get_active_cash_session:
--    - Para EMPLEADO: Arqueo Ciego estricto (NUNCA viaja adminExpectedSummary).
--    - Para ADMIN: Incluye adminExpectedSummary calculado 100% en PostgreSQL
--      (efectivo esperado en cajón + resumen informativo de Nequi y Llave Bre-B).
CREATE OR REPLACE FUNCTION public.get_active_cash_session(p_store_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_session RECORD;
    v_forced RECORD;
    v_is_expired BOOLEAN := false;
    v_is_admin BOOLEAN := false;
    v_in_efectivo NUMERIC := 0;
    v_out_efectivo NUMERIC := 0;
    v_in_nequi NUMERIC := 0;
    v_out_nequi NUMERIC := 0;
    v_in_llave_bre NUMERIC := 0;
    v_out_llave_bre NUMERIC := 0;
    v_expected_efectivo NUMERIC := 0;
    v_expected_nequi NUMERIC := 0;
    v_expected_llave_bre NUMERIC := 0;
    v_payload JSONB;
BEGIN
    PERFORM public.assert_store_access(p_store_id);
    v_is_admin := public.is_store_admin(p_store_id);

    SELECT * INTO v_session
    FROM public.cash_sessions
    WHERE store_id = p_store_id AND status = 'open'
    ORDER BY opened_at DESC
    LIMIT 1;

    IF FOUND THEN
        v_is_expired := (NOW() - v_session.opened_at) >= INTERVAL '24 hours';

        v_payload := jsonb_build_object(
            'isOpen', true,
            'sessionId', v_session.id,
            'openingAmount', v_session.opening_balance,
            'openedBy', v_session.opened_by,
            'openedByName', COALESCE(v_session.opened_by_name, 'Usuario'),
            'openedByRole', COALESCE(v_session.opened_by_role, 'employee'),
            'openedAt', v_session.opened_at,
            'closingAttempts', COALESCE(v_session.closing_attempts, 0),
            'isExpired24h', v_is_expired,
            'lifecycleState', CASE WHEN v_is_expired THEN 'Expirado/Bloqueado' ELSE 'open' END
        );

        -- Solo para Administrador (Dueño): exponer resumen esperado de cajón y canales digitales
        IF v_is_admin THEN
            SELECT COALESCE(SUM(amount), 0) INTO v_in_efectivo
            FROM public.cash_movements
            WHERE session_id = v_session.id AND movement_type = 'ingreso' AND payment_method = 'efectivo';

            SELECT COALESCE(SUM(amount), 0) INTO v_out_efectivo
            FROM public.cash_movements
            WHERE session_id = v_session.id AND movement_type IN ('gasto', 'pago_proveedor', 'reembolso') AND payment_method = 'efectivo';

            SELECT COALESCE(SUM(amount), 0) INTO v_in_nequi
            FROM public.cash_movements
            WHERE session_id = v_session.id AND movement_type = 'ingreso' AND payment_method = 'nequi';

            SELECT COALESCE(SUM(amount), 0) INTO v_out_nequi
            FROM public.cash_movements
            WHERE session_id = v_session.id AND movement_type IN ('gasto', 'pago_proveedor', 'reembolso') AND payment_method = 'nequi';

            SELECT COALESCE(SUM(amount), 0) INTO v_in_llave_bre
            FROM public.cash_movements
            WHERE session_id = v_session.id AND movement_type = 'ingreso' AND payment_method = 'llave_bre';

            SELECT COALESCE(SUM(amount), 0) INTO v_out_llave_bre
            FROM public.cash_movements
            WHERE session_id = v_session.id AND movement_type IN ('gasto', 'pago_proveedor', 'reembolso') AND payment_method = 'llave_bre';

            v_expected_efectivo  := COALESCE(v_session.opening_balance, 0) + v_in_efectivo - v_out_efectivo;
            v_expected_nequi     := v_in_nequi - v_out_nequi;
            v_expected_llave_bre := v_in_llave_bre - v_out_llave_bre;

            v_payload := v_payload || jsonb_build_object(
                'adminExpectedSummary', jsonb_build_object(
                    'efectivo', v_expected_efectivo,
                    'nequi', v_expected_nequi,
                    'llave_bre', v_expected_llave_bre
                )
            );
        END IF;

        RETURN v_payload;
    END IF;

    -- Si no hay sesión abierta, reportar si existe turno Expirado/Bloqueado pendiente (+24h)
    SELECT id, opened_by, opened_by_name, opened_by_role, opened_at, closing_attempts
    INTO v_forced
    FROM public.cash_sessions
    WHERE store_id = p_store_id
      AND status = 'closed'
      AND COALESCE(forced_close, false) = true
      AND actual_balance IS NULL
    ORDER BY opened_at ASC
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'isOpen', false,
            'pendingForcedSession', jsonb_build_object(
                'sessionId', v_forced.id,
                'openedBy', v_forced.opened_by,
                'openedByName', COALESCE(v_forced.opened_by_name, 'Usuario'),
                'openedByRole', COALESCE(v_forced.opened_by_role, 'employee'),
                'openedAt', v_forced.opened_at,
                'closingAttempts', COALESCE(v_forced.closing_attempts, 0),
                'lifecycleState', 'Expirado/Bloqueado'
            )
        );
    END IF;

    RETURN jsonb_build_object('isOpen', false);
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

-- 3. cerrar_caja (firma retrocompatible):
--    - Arqueo físico EXCLUSIVAMENTE sobre el Efectivo del cajón.
--    - Canales digitales (Nequi / Llave Bre-B) quedan como resumen informativo en metadata/auditoría.
--    - Diferencia exacta al peso = v_declared_efectivo - v_expected_efectivo (siempre guardada íntegra).
--    - Empleados: Cierre Asistido (3 intentos) solo si ABS(diferencia) > P_MARGEN_DESCUADRE_EFECTIVO.
--    - Admin: sella en 1 paso y recibe resumen exacto del cierre (sin auto-alerta).
CREATE OR REPLACE FUNCTION public.cerrar_caja(
    p_session_id uuid,
    p_employee_id uuid DEFAULT NULL::uuid,
    p_actual_balance numeric DEFAULT NULL::numeric,
    p_declared_nequi numeric DEFAULT 0,
    p_declared_llave_bre numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_session RECORD;
    v_snap RECORD;
    v_is_admin BOOLEAN := false;
    v_emp_fk_id UUID;
    v_declared_efectivo NUMERIC;
    v_margin NUMERIC;

    v_in_efectivo NUMERIC := 0;
    v_out_efectivo NUMERIC := 0;
    v_in_nequi NUMERIC := 0;
    v_out_nequi NUMERIC := 0;
    v_in_llave_bre NUMERIC := 0;
    v_out_llave_bre NUMERIC := 0;

    v_expected_efectivo NUMERIC := 0;
    v_expected_nequi NUMERIC := 0;
    v_expected_llave_bre NUMERIC := 0;
    v_difference NUMERIC := 0;

    v_exceeds_margin BOOLEAN := false;
    v_next_attempts SMALLINT := 0;
    v_sealed_with_alert BOOLEAN := false;
    v_closed_at TIMESTAMPTZ := NOW();
    v_is_expired_pending BOOLEAN := false;
    v_response_data JSONB;
BEGIN
    -- Prohibición de envíos en blanco o montos negativos (POL-SEG-01 v1.5)
    IF p_actual_balance IS NULL OR p_actual_balance < 0 THEN
        RAISE EXCEPTION 'INVALID_BALANCE: Debes declarar explícitamente el efectivo contado en el cajón (0 o mayor).'
            USING ERRCODE = '22023';
    END IF;

    v_declared_efectivo := p_actual_balance;

    -- Leer parámetro global obligatorio P_MARGEN_DESCUADRE_EFECTIVO (Regla 3: cero fallback silencioso)
    SELECT numeric_value INTO v_margin
    FROM public.system_parameters
    WHERE code = 'P_MARGEN_DESCUADRE_EFECTIVO';

    IF v_margin IS NULL OR v_margin < 0 THEN
        RAISE EXCEPTION 'SYSTEM_PARAMETER_MISSING: Falta el parámetro global P_MARGEN_DESCUADRE_EFECTIVO en system_parameters.'
            USING ERRCODE = 'P0002';
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
    PERFORM public.assert_employee_permission(v_session.store_id, 'canOpenCloseCash');

    -- Se permite cerrar sesión abierta O sesión +24h cerrada forzosamente aún sin conteo (solo abridor original / Admin)
    v_is_expired_pending := (
        v_session.status = 'closed'
        AND COALESCE(v_session.forced_close, false) = true
        AND v_session.actual_balance IS NULL
    );

    IF v_session.status <> 'open' AND NOT v_is_expired_pending THEN
        RAISE EXCEPTION 'ALREADY_CLOSED: La sesión de caja ya fue cerrada previamente.'
            USING ERRCODE = 'P0001';
    END IF;

    -- Identidad y propiedad estricta del turno (SDD-003-01 / POL-SEG-03)
    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_session.store_id);
    v_is_admin := public.is_store_admin(v_session.store_id);

    IF NOT v_is_admin AND v_session.opened_by IS DISTINCT FROM v_snap.actor_id THEN
        RAISE EXCEPTION 'SHIFT_OWNERSHIP_VIOLATION: Solo quien abrió este turno o el Administrador pueden cerrarlo.'
            USING ERRCODE = '42501';
    END IF;

    -- Calcular saldos esperados por canal (POL-FIN-02)
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

    v_expected_efectivo  := COALESCE(v_session.opening_balance, 0) + v_in_efectivo - v_out_efectivo;
    v_expected_nequi     := v_in_nequi - v_out_nequi;
    v_expected_llave_bre := v_in_llave_bre - v_out_llave_bre;

    -- Arqueo físico exclusivo sobre el efectivo del cajón (diferencia exacta al peso)
    v_difference     := v_declared_efectivo - v_expected_efectivo;
    v_exceeds_margin := ABS(v_difference) > v_margin;

    -- Cierre Asistido (Intentos 1 y 2 para empleados SOLO si supera P_MARGEN_DESCUADRE_EFECTIVO)
    IF NOT v_is_admin AND v_exceeds_margin AND COALESCE(v_session.closing_attempts, 0) < 2 THEN
        v_next_attempts := COALESCE(v_session.closing_attempts, 0) + 1;

        UPDATE public.cash_sessions
        SET closing_attempts = v_next_attempts
        WHERE id = p_session_id;

        RETURN jsonb_build_object(
            'success', false,
            'code', 'COUNT_MISMATCH_RETRY',
            'attempts_used', v_next_attempts,
            'attempts_remaining', 3 - v_next_attempts,
            'message', 'El conteo de efectivo no coincide con el registro del turno. Revisa y vuelve a intentar.'
        );
    END IF;

    -- Sellado (dentro de margen, Admin, o 3.er intento fallido de empleado)
    IF v_exceeds_margin AND NOT v_is_admin THEN
        v_next_attempts := 3;
        v_sealed_with_alert := true;
    ELSE
        v_next_attempts := COALESCE(v_session.closing_attempts, 0) + CASE WHEN v_difference <> 0 THEN 1 ELSE 0 END;
        v_sealed_with_alert := false;
    END IF;

    -- Se guarda SIEMPRE la diferencia exacta al peso (dentro o fuera del margen)
    UPDATE public.cash_sessions
    SET closed_by = v_snap.actor_id,
        closed_by_name = v_snap.actor_name,
        closed_by_role = v_snap.actor_role,
        expected_balance = v_expected_efectivo,
        actual_balance = v_declared_efectivo,
        difference = v_difference,
        closing_attempts = v_next_attempts,
        status = 'closed',
        closed_at = v_closed_at
    WHERE id = p_session_id;

    -- Si un empleado cerró al 3.er intento superando P_MARGEN_DESCUADRE_EFECTIVO, registrar alerta al Admin
    IF v_sealed_with_alert THEN
        SELECT e.id INTO v_emp_fk_id
        FROM public.employees e
        WHERE e.id = v_snap.actor_id AND e.store_id = v_session.store_id
        LIMIT 1;

        INSERT INTO public.audit_logs (
            actor_id, actor_name, actor_role, store_id, event_type, resource_id, metadata, severity, created_at
        ) VALUES (
            v_emp_fk_id,
            v_snap.actor_name,
            v_snap.actor_role,
            v_session.store_id,
            'CASH_DISCREPANCY_ALERT',
            p_session_id::text,
            jsonb_build_object(
                'session_id', p_session_id,
                'closing_attempts', v_next_attempts,
                'margin_applied', v_margin,
                'expected_efectivo', v_expected_efectivo,
                'declared_efectivo', v_declared_efectivo,
                'difference', v_difference,
                'digital_summary', jsonb_build_object(
                    'nequi', v_expected_nequi,
                    'llave_bre', v_expected_llave_bre
                )
            ),
            'warning',
            v_closed_at
        );

        INSERT INTO public.notifications (
            store_id, type, title, message, audience, is_read, metadata, created_at
        ) VALUES (
            v_session.store_id,
            'finance',
            'Descuadre en Cierre de Caja (3.er Intento)',
            format('%s cerró el turno con diferencia de efectivo al 3.er intento. Revisa el reporte de caja.', v_snap.actor_name),
            'admin',
            false,
            jsonb_build_object(
                'event_type', 'CASH_DISCREPANCY_ALERT',
                'session_id', p_session_id,
                'actor_name', v_snap.actor_name,
                'actor_role', v_snap.actor_role,
                'closing_attempts', v_next_attempts,
                'margin_applied', v_margin,
                'expected_balance', v_expected_efectivo,
                'actual_balance', v_declared_efectivo,
                'difference', v_difference
            ),
            v_closed_at
        );
    END IF;

    v_response_data := jsonb_build_object(
        'session_id', p_session_id,
        'status', 'closed',
        'sealed_with_alert', v_sealed_with_alert,
        'closing_attempts', v_next_attempts,
        'closed_at', v_closed_at,
        'closed_by_name', v_snap.actor_name,
        'closed_by_role', v_snap.actor_role
    );

    -- Solo al Administrador se le devuelve el resumen exacto del cierre (empleados permanecen a ciegas)
    IF v_is_admin THEN
        v_response_data := v_response_data || jsonb_build_object(
            'expected_efectivo', v_expected_efectivo,
            'actual_efectivo', v_declared_efectivo,
            'difference', v_difference,
            'digital_summary', jsonb_build_object(
                'nequi', v_expected_nequi,
                'llave_bre', v_expected_llave_bre
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_response_data
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

REVOKE ALL ON FUNCTION public.get_active_cash_session(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_active_cash_session(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.cerrar_caja(uuid, uuid, numeric, numeric, numeric) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cerrar_caja(uuid, uuid, numeric, numeric, numeric) TO authenticated, service_role;

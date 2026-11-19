-- ============================================================================
-- FASE 3 - OLA 2: Caja Dedicada POS, Propiedad Estricta del Turno,
--                 Cierre Asistido (3 intentos), +24h y Gastos OPEX
-- Átomos: CHK-201, CHK-202, CHK-203, CHK-204, CHK-205, CHK-206, CHK-209
-- SDDs:   SDD-003-01, SDD-004, SDD-017, SDD-020, SDD-022, SDD-026, SDD-027-02
-- ============================================================================

-- ============================================================================
-- [CHK-201] DDL cash_sessions: closing_attempts, forced_close_without_count,
--           liberación de FK restrictiva a employees para managers y GRANT ALL
-- ============================================================================
ALTER TABLE public.cash_sessions
    ADD COLUMN IF NOT EXISTS closing_attempts SMALLINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS forced_close_without_count BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.cash_sessions
    DROP CONSTRAINT IF EXISTS cash_sessions_opened_by_fkey,
    DROP CONSTRAINT IF EXISTS cash_sessions_closed_by_fkey;

GRANT ALL ON TABLE public.cash_sessions TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.cash_movements TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.notifications TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.audit_logs TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.audit_seguridad TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.audit_caja TO anon, authenticated, service_role;

-- Ampliar event_type permitidos en audit_seguridad para eventos de Ola 2 y Ola 3
ALTER TABLE public.audit_seguridad
    DROP CONSTRAINT IF EXISTS audit_seguridad_event_type_check;

ALTER TABLE public.audit_seguridad
    ADD CONSTRAINT audit_seguridad_event_type_check CHECK (
        event_type = ANY (ARRAY[
            'LOGIN_SUCCESS'::text,
            'LOGIN_FAILED'::text,
            'PIN_CHANGE'::text,
            'UNAUTHORIZED_ACCESS'::text,
            'UNAUTHORIZED_SHIFT_CLOSE'::text,
            'CASH_DISCREPANCY_ALERT'::text,
            'FORCED_CLOSE_24H'::text,
            'FORCED_CLOSE_NO_COUNT'::text,
            'FORCE_SALE'::text,
            'SESSION_EXPIRED'::text,
            'ROLE_CHANGE'::text,
            'EMPLOYEE_DEACTIVATED'::text,
            'DEVICE_ACCESS_APPROVE'::text,
            'DEVICE_ACCESS_REJECT'::text,
            'DEVICE_ACCESS_REVOKE'::text,
            'CONCURRENT_MUTATION_BLOCKED'::text
        ])
    );

-- Triggers forenses de audit_caja compatibles con owner/manager y snapshot histórico
CREATE OR REPLACE FUNCTION public.fn_audit_cash_opened()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_emp_fk_id UUID;
BEGIN
    SELECT id INTO v_emp_fk_id FROM public.employees WHERE id = NEW.opened_by LIMIT 1;

    INSERT INTO public.audit_caja (
        session_id, store_id, event_type, actor_id, actor_name, actor_role, metadata
    ) VALUES (
        NEW.id,
        NEW.store_id,
        'APERTURA',
        v_emp_fk_id,
        COALESCE(NEW.opened_by_name, 'Sistema'),
        COALESCE(NEW.opened_by_role, 'employee'),
        jsonb_build_object(
            'initial_amount', NEW.opening_balance,
            'actor_uuid', NEW.opened_by,
            'actor_name', NEW.opened_by_name,
            'actor_role', NEW.opened_by_role
        )
    );
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_audit_cash_closed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_emp_fk_id UUID;
    v_is_reconciliation BOOLEAN := (
        OLD.status = 'closed'
        AND NEW.status = 'closed'
        AND OLD.actual_balance IS NULL
        AND NEW.actual_balance IS NOT NULL
    );
BEGIN
    IF ((OLD.status IS DISTINCT FROM NEW.status) AND NEW.status = 'closed') OR v_is_reconciliation THEN
        SELECT id INTO v_emp_fk_id FROM public.employees WHERE id = NEW.closed_by LIMIT 1;

        INSERT INTO public.audit_caja (
            session_id, store_id, event_type, actor_id, actor_name, actor_role, metadata
        ) VALUES (
            NEW.id,
            NEW.store_id,
            'CIERRE',
            v_emp_fk_id,
            COALESCE(NEW.closed_by_name, CASE WHEN NEW.forced_close AND NEW.actual_balance IS NULL THEN 'Sistema (24h)' ELSE 'Sistema' END),
            COALESCE(NEW.closed_by_role, 'employee'),
            jsonb_build_object(
                'initial_amount', NEW.opening_balance,
                'expected_amount', NEW.expected_balance,
                'final_amount', NEW.actual_balance,
                'difference', NEW.difference,
                'closing_attempts', NEW.closing_attempts,
                'forced_close', COALESCE(NEW.forced_close, false),
                'forced_close_without_count', COALESCE(NEW.forced_close_without_count, false),
                'actor_uuid', NEW.closed_by,
                'actor_name', NEW.closed_by_name,
                'actor_role', NEW.closed_by_role
            )
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_cash_closed ON public.cash_sessions;
CREATE TRIGGER trg_audit_cash_closed
    AFTER UPDATE ON public.cash_sessions
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_audit_cash_closed();


-- ============================================================================
-- [CHK-202] abrir_caja y get_active_cash_session
--           Exige canOpenCloseCash, compuerta RECONCILIATION_REQUIRED y snapshot
-- ============================================================================
CREATE OR REPLACE FUNCTION public.abrir_caja(
    p_store_id uuid,
    p_employee_id uuid,
    p_opening_balance numeric
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_existing_session UUID;
    v_session_id UUID;
    v_snap RECORD;
    v_opened_at TIMESTAMPTZ := NOW();
BEGIN
    -- 1. Aislamiento Multi-Tenant y Permiso canOpenCloseCash (Admin o empleado autorizado)
    PERFORM public.assert_store_access(p_store_id);
    PERFORM public.assert_employee_permission(p_store_id, 'canOpenCloseCash');

    -- 2. Validación de monto inicial
    IF p_opening_balance IS NULL OR p_opening_balance < 0 THEN
        RAISE EXCEPTION 'INVALID_OPENING_AMOUNT: El monto de apertura debe ser mayor o igual a cero.'
            USING ERRCODE = '22023';
    END IF;

    -- 3. Compuerta D-7 / RN-017-03: Bloquear si existe turno expirado (+24h) pendiente de cierre/reconciliación
    IF EXISTS (
        SELECT 1 FROM public.cash_sessions
        WHERE store_id = p_store_id
          AND status = 'closed'
          AND COALESCE(forced_close, false) = true
          AND actual_balance IS NULL
    ) THEN
        RAISE EXCEPTION 'RECONCILIATION_REQUIRED: Existe un turno cerrado forzosamente pendiente de reconciliación. Debe resolverse antes de abrir un nuevo turno.'
            USING ERRCODE = 'P0001';
    END IF;

    -- 4. Verificar que no exista otra sesión ya abierta
    SELECT id INTO v_existing_session
    FROM public.cash_sessions
    WHERE store_id = p_store_id AND status = 'open'
    FOR UPDATE;

    IF FOUND THEN
        RAISE EXCEPTION 'CASH_ALREADY_OPEN: Ya existe una caja abierta en esta tienda.'
            USING ERRCODE = 'P0001';
    END IF;

    -- 5. Resolver identidad y fotografía histórica inmutable del abridor
    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(p_store_id);

    INSERT INTO public.cash_sessions (
        store_id,
        opened_by,
        opened_by_name,
        opened_by_role,
        opening_balance,
        status,
        opened_at,
        forced_close,
        closing_attempts,
        forced_close_without_count
    ) VALUES (
        p_store_id,
        v_snap.actor_id,
        v_snap.actor_name,
        v_snap.actor_role,
        p_opening_balance,
        'open',
        v_opened_at,
        false,
        0,
        false
    ) RETURNING id INTO v_session_id;

    RETURN json_build_object(
        'success', true,
        'session_id', v_session_id,
        'status', 'open',
        'opening_balance', p_opening_balance,
        'opened_by', v_snap.actor_id,
        'opened_by_name', v_snap.actor_name,
        'opened_by_role', v_snap.actor_role,
        'opened_at', v_opened_at
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

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
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    SELECT * INTO v_session
    FROM public.cash_sessions
    WHERE store_id = p_store_id AND status = 'open'
    ORDER BY opened_at DESC
    LIMIT 1;

    IF FOUND THEN
        v_is_expired := (NOW() - v_session.opened_at) >= INTERVAL '24 hours';

        -- Arqueo ciego: NUNCA incluir expected_balance ni difference en este payload
        RETURN jsonb_build_object(
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


-- ============================================================================
-- [CHK-203] Seguridad persistente + Propiedad Estricta + Cierre Asistido (3 intentos)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_log_security_event(
    p_event_type text,
    p_store_id uuid DEFAULT NULL::uuid,
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_event TEXT := UPPER(TRIM(COALESCE(p_event_type, '')));
    v_employee_id UUID;
    v_actor_name TEXT := 'Sistema';
    v_actor_role TEXT := 'employee';
    v_snap RECORD;
    v_ip TEXT;
    v_user_agent TEXT;
    v_headers JSONB;
BEGIN
    IF v_event NOT IN (
        'LOGIN_SUCCESS', 'LOGIN_FAILED', 'PIN_CHANGE', 'UNAUTHORIZED_ACCESS',
        'UNAUTHORIZED_SHIFT_CLOSE', 'CASH_DISCREPANCY_ALERT', 'FORCED_CLOSE_24H', 'FORCED_CLOSE_NO_COUNT',
        'FORCE_SALE', 'SESSION_EXPIRED', 'ROLE_CHANGE', 'EMPLOYEE_DEACTIVATED',
        'DEVICE_ACCESS_APPROVE', 'DEVICE_ACCESS_REJECT', 'DEVICE_ACCESS_REVOKE',
        'CONCURRENT_MUTATION_BLOCKED'
    ) THEN
        RAISE EXCEPTION 'INVALID_SECURITY_EVENT_TYPE: Evento de seguridad (%) no reconocido.', p_event_type
            USING ERRCODE = '22023';
    END IF;

    IF p_store_id IS NOT NULL THEN
        -- B2-1 / Regla 4: Blindaje multi-tenant obligatorio en SECURITY DEFINER
        PERFORM public.assert_store_access(p_store_id);

        BEGIN
            SELECT * INTO v_snap FROM public.resolve_actor_snapshot(p_store_id);
            v_actor_name := v_snap.actor_name;
            v_actor_role := v_snap.actor_role;
            SELECT e.id INTO v_employee_id
            FROM public.employees e
            WHERE e.id = v_snap.actor_id AND e.store_id = p_store_id
            LIMIT 1;
        EXCEPTION WHEN OTHERS THEN
            v_employee_id := NULL;
        END;
    END IF;

    BEGIN
        v_headers := NULLIF(current_setting('request.headers', true), '')::jsonb;
        v_ip := v_headers->>'x-forwarded-for';
        v_user_agent := v_headers->>'user-agent';
    EXCEPTION WHEN OTHERS THEN
        v_ip := NULL;
        v_user_agent := NULL;
    END;

    INSERT INTO public.audit_seguridad (
        actor_id, actor_name, actor_role, store_id, event_type, ip_address, user_agent, metadata
    ) VALUES (
        v_employee_id,
        v_actor_name,
        v_actor_role,
        p_store_id,
        v_event,
        v_ip,
        v_user_agent,
        COALESCE(p_metadata, '{}'::jsonb)
    );

    IF p_store_id IS NOT NULL THEN
        INSERT INTO public.audit_logs (
            actor_id, actor_name, actor_role, store_id, event_type, resource_id, metadata, severity
        ) VALUES (
            v_employee_id,
            v_actor_name,
            v_actor_role,
            p_store_id,
            v_event,
            COALESCE(p_metadata->>'resource_id', p_metadata->>'session_id', p_metadata->>'permission_key', p_store_id::text),
            COALESCE(p_metadata, '{}'::jsonb),
            COALESCE(NULLIF(p_metadata->>'severity', ''), 'warning')
        );

        -- Alerta inmediata al Administrador cuando intentan cerrar turno ajeno
        IF v_event = 'UNAUTHORIZED_SHIFT_CLOSE' THEN
            INSERT INTO public.notifications (
                store_id, type, title, message, audience, is_read, metadata
            ) VALUES (
                p_store_id,
                'security',
                'Intento Bloqueado de Cierre de Caja',
                format('%s intentó cerrar un turno abierto por otro usuario.', COALESCE(v_actor_name, 'Un colaborador')),
                'admin',
                false,
                jsonb_build_object(
                    'event_type', 'UNAUTHORIZED_SHIFT_CLOSE',
                    'session_id', p_metadata->>'session_id',
                    'actor_name', v_actor_name,
                    'actor_role', v_actor_role
                ) || COALESCE(p_metadata, '{}'::jsonb)
            );
        END IF;
    END IF;
END;
$$;

DROP FUNCTION IF EXISTS public.cerrar_caja(uuid, uuid, numeric);

CREATE OR REPLACE FUNCTION public.cerrar_caja(
    p_session_id uuid,
    p_employee_id uuid DEFAULT NULL::uuid,
    p_actual_balance numeric DEFAULT 0,
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
    v_declared_efectivo NUMERIC := COALESCE(p_actual_balance, 0);
    v_declared_nequi NUMERIC := COALESCE(p_declared_nequi, 0);
    v_declared_llave_bre NUMERIC := COALESCE(p_declared_llave_bre, 0);

    v_in_efectivo NUMERIC := 0;
    v_out_efectivo NUMERIC := 0;
    v_in_nequi NUMERIC := 0;
    v_out_nequi NUMERIC := 0;
    v_in_llave_bre NUMERIC := 0;
    v_out_llave_bre NUMERIC := 0;

    v_expected_efectivo NUMERIC := 0;
    v_expected_nequi NUMERIC := 0;
    v_expected_llave_bre NUMERIC := 0;

    v_expected_total NUMERIC := 0;
    v_actual_total NUMERIC := 0;
    v_difference NUMERIC := 0;

    v_has_mismatch BOOLEAN := false;
    v_next_attempts SMALLINT := 0;
    v_sealed_with_alert BOOLEAN := false;
    v_closed_at TIMESTAMPTZ := NOW();
    v_is_expired_pending BOOLEAN := false;
BEGIN
    IF p_actual_balance IS NULL OR p_actual_balance < 0
       OR p_declared_nequi IS NULL OR p_declared_nequi < 0
       OR p_declared_llave_bre IS NULL OR p_declared_llave_bre < 0 THEN
        RAISE EXCEPTION 'INVALID_BALANCE: Los montos declarados por canal deben ser mayores o iguales a cero.'
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

    -- Calcular saldos esperados por cada canal SIN compensación cruzada (POL-FIN-02)
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

    v_has_mismatch := (
        v_declared_efectivo <> v_expected_efectivo
        OR v_declared_nequi <> v_expected_nequi
        OR v_declared_llave_bre <> v_expected_llave_bre
    );

    -- Cierre Asistido (Intentos 1 y 2 para cajeros empleados: NO sella y NUNCA revela esperados ni diferencias)
    IF NOT v_is_admin AND v_has_mismatch AND COALESCE(v_session.closing_attempts, 0) < 2 THEN
        v_next_attempts := COALESCE(v_session.closing_attempts, 0) + 1;

        UPDATE public.cash_sessions
        SET closing_attempts = v_next_attempts
        WHERE id = p_session_id;

        RETURN jsonb_build_object(
            'success', false,
            'code', 'COUNT_MISMATCH_RETRY',
            'attempts_used', v_next_attempts,
            'attempts_remaining', 3 - v_next_attempts,
            'message', 'El conteo no coincide con el registro del turno. Revisa y vuelve a intentar.'
        );
    END IF;

    -- Sellado (cuadra perfecto, Admin, o 3.er intento fallido de empleado)
    v_expected_total := v_expected_efectivo + v_expected_nequi + v_expected_llave_bre;
    v_actual_total   := v_declared_efectivo + v_declared_nequi + v_declared_llave_bre;
    v_difference     := v_actual_total - v_expected_total;

    IF v_has_mismatch AND NOT v_is_admin THEN
        v_next_attempts := 3;
        v_sealed_with_alert := true;
    ELSE
        v_next_attempts := COALESCE(v_session.closing_attempts, 0) + CASE WHEN v_has_mismatch THEN 1 ELSE 0 END;
        v_sealed_with_alert := false;
    END IF;

    UPDATE public.cash_sessions
    SET closed_by = v_snap.actor_id,
        closed_by_name = v_snap.actor_name,
        closed_by_role = v_snap.actor_role,
        expected_balance = v_expected_total,
        actual_balance = v_actual_total,
        difference = v_difference,
        closing_attempts = v_next_attempts,
        status = 'closed',
        closed_at = v_closed_at
    WHERE id = p_session_id;

    -- Si cerró al 3.er intento con descuadre, registrar en audit_logs y notifications para Admin
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
                'expected_total', v_expected_total,
                'actual_total', v_actual_total,
                'difference', v_difference,
                'channels', jsonb_build_object(
                    'efectivo', jsonb_build_object('expected', v_expected_efectivo, 'declared', v_declared_efectivo),
                    'nequi', jsonb_build_object('expected', v_expected_nequi, 'declared', v_declared_nequi),
                    'llave_bre', jsonb_build_object('expected', v_expected_llave_bre, 'declared', v_declared_llave_bre)
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
            format('%s cerró el turno con diferencia al 3.er intento. Revisa el reporte de caja.', v_snap.actor_name),
            'admin',
            false,
            jsonb_build_object(
                'event_type', 'CASH_DISCREPANCY_ALERT',
                'session_id', p_session_id,
                'actor_name', v_snap.actor_name,
                'actor_role', v_snap.actor_role,
                'closing_attempts', v_next_attempts,
                'expected_balance', v_expected_total,
                'actual_balance', v_actual_total,
                'difference', v_difference
            ),
            v_closed_at
        );
    END IF;

    -- Respuesta sellada SIN expected_balance ni difference (POL-SEG-01: Arqueo Ciego)
    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'session_id', p_session_id,
            'status', 'closed',
            'sealed_with_alert', v_sealed_with_alert,
            'closing_attempts', v_next_attempts,
            'closed_at', v_closed_at,
            'closed_by_name', v_snap.actor_name,
            'closed_by_role', v_snap.actor_role
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;


-- ============================================================================
-- [CHK-204] rpc_check_and_force_close_shifts (+24h Expirado/Bloqueado, Regla 3)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_check_and_force_close_shifts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    r RECORD;
    v_ingresos NUMERIC;
    v_gastos NUMERIC;
    v_expected NUMERIC;
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
        -- Consolidado multicanal oficial (efectivo + nequi + llave_bre)
        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
        FROM public.cash_movements
        WHERE session_id = r.id
          AND movement_type = 'ingreso'
          AND payment_method IN ('efectivo', 'nequi', 'llave_bre');

        SELECT COALESCE(SUM(amount), 0) INTO v_gastos
        FROM public.cash_movements
        WHERE session_id = r.id
          AND movement_type IN ('gasto', 'pago_proveedor', 'reembolso')
          AND payment_method IN ('efectivo', 'nequi', 'llave_bre');

        v_expected := COALESCE(r.opening_balance, 0) + v_ingresos - v_gastos;

        UPDATE public.cash_sessions
        SET status           = 'closed',
            forced_close     = true,
            expected_balance = v_expected,
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
                'expected_balance', v_expected
            ),
            'warning',
            NOW()
        );

        -- Regla 3: notifications es tabla obligatoria (sin IF EXISTS information_schema)
        INSERT INTO public.notifications (
            store_id, type, title, message, audience, is_read, metadata, created_at
        ) VALUES (
            r.store_id,
            'finance',
            'Turno Expirado (+24 Horas)',
            format('El turno abierto por %s superó 24 horas y pasó a Expirado/Bloqueado. Requiere cierre o reconciliación administrativa.', COALESCE(r.opened_by_name, 'un colaborador')),
            'admin',
            false,
            jsonb_build_object(
                'event_type', 'FORCED_CLOSE_24H',
                'lifecycle_state', 'Expirado/Bloqueado',
                'session_id', r.id,
                'opened_by', r.opened_by,
                'opened_by_name', r.opened_by_name
            ),
            NOW()
        );

        closed_count := closed_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'closed_shifts', closed_count,
            'lifecycle_state', 'Expirado/Bloqueado'
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;


-- ============================================================================
-- [CHK-205] rpc_reconciliar_cierre_forzado (100% Admin-only + Conteo Opcional)
-- ============================================================================
DROP FUNCTION IF EXISTS public.rpc_reconciliar_cierre_forzado(uuid, uuid, numeric);

CREATE OR REPLACE FUNCTION public.rpc_reconciliar_cierre_forzado(
    p_session_id uuid,
    p_employee_id uuid DEFAULT NULL::uuid,
    p_actual_balance numeric DEFAULT NULL::numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_session        public.cash_sessions%ROWTYPE;
    v_snap           RECORD;
    v_emp_fk_id      UUID;
    v_final_actual   NUMERIC;
    v_difference     NUMERIC;
    v_without_count  BOOLEAN := false;
    v_event_type     TEXT;
BEGIN
    IF p_actual_balance IS NOT NULL AND p_actual_balance < 0 THEN
        RAISE EXCEPTION 'INVALID_BALANCE: El balance real debe ser mayor o igual a cero.'
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

    -- 100% Admin-only para cierre forzoso administrativo (+24h)
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

    -- Regla 3 FRD-027-02 / SDD-027-02: p_actual_balance opcional; si NULL asume expected con diff = 0
    IF p_actual_balance IS NULL THEN
        v_without_count := true;
        v_final_actual  := COALESCE(v_session.expected_balance, 0);
        v_difference    := 0;
        v_event_type    := 'FORCED_CLOSE_NO_COUNT';
    ELSE
        v_without_count := false;
        v_final_actual  := p_actual_balance;
        v_difference    := v_final_actual - COALESCE(v_session.expected_balance, 0);
        v_event_type    := 'FORCED_CLOSE_RECONCILED';
    END IF;

    UPDATE public.cash_sessions
    SET actual_balance             = v_final_actual,
        difference                 = v_difference,
        closed_by                  = v_snap.actor_id,
        closed_by_name             = v_snap.actor_name,
        closed_by_role             = v_snap.actor_role,
        forced_close_without_count = v_without_count
    WHERE id = p_session_id;

    INSERT INTO public.audit_logs (
        actor_id, actor_name, actor_role, store_id, event_type, resource_id, metadata, severity, created_at
    ) VALUES (
        v_emp_fk_id,
        v_snap.actor_name,
        v_snap.actor_role,
        v_session.store_id,
        v_event_type,
        p_session_id::text,
        jsonb_build_object(
            'reconciled_by', v_snap.actor_id,
            'reconciled_by_name', v_snap.actor_name,
            'reconciled_by_role', v_snap.actor_role,
            'actual_balance', v_final_actual,
            'expected_balance', v_session.expected_balance,
            'difference', v_difference,
            'forced_close_without_count', v_without_count,
            'reconciled_at', NOW()
        ),
        CASE WHEN v_without_count OR v_difference <> 0 THEN 'warning' ELSE 'info' END,
        NOW()
    );

    IF v_without_count THEN
        INSERT INTO public.notifications (
            store_id, type, title, message, audience, is_read, metadata, created_at
        ) VALUES (
            v_session.store_id,
            'finance',
            'Cierre Forzoso sin Conteo Físico',
            format('%s cerró forzosamente el turno omitiendo conteo físico (saldo asumido: $%s). Verificar efectivo real.', v_snap.actor_name, v_final_actual),
            'admin',
            false,
            jsonb_build_object(
                'event_type', 'FORCED_CLOSE_NO_COUNT',
                'session_id', p_session_id,
                'assumed_balance', v_final_actual,
                'actor_name', v_snap.actor_name,
                'actor_role', v_snap.actor_role
            ),
            NOW()
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'session_id', p_session_id,
            'expected_balance', v_session.expected_balance,
            'actual_balance', v_final_actual,
            'difference', v_difference,
            'forced_close_without_count', v_without_count,
            'closed_by_name', v_snap.actor_name,
            'closed_by_role', v_snap.actor_role
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;


-- ============================================================================
-- [CHK-206] rpc_registrar_gasto_v2: 5 categorías OPEX cerradas (sin 'Reembolso'),
--           canales ('efectivo','nequi','llave_bre'), p_voucher_ref y snapshot
-- ============================================================================
CREATE OR REPLACE FUNCTION public.rpc_registrar_gasto_v2(
    p_session_id uuid,
    p_amount numeric,
    p_payment_method text,
    p_category text,
    p_description text,
    p_voucher_ref text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_session RECORD;
    v_method TEXT := LOWER(TRIM(COALESCE(p_payment_method, '')));
    v_category TEXT := TRIM(COALESCE(p_category, ''));
    v_ingresos NUMERIC := 0;
    v_egresos NUMERIC := 0;
    v_available NUMERIC := 0;
    v_movement_id UUID;
    v_snap RECORD;
    v_emp_fk_id UUID;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'INVALID_AMOUNT: El monto del gasto debe ser un valor positivo mayor a cero.'
            USING ERRCODE = '22023';
    END IF;

    IF v_method NOT IN ('efectivo', 'nequi', 'llave_bre') THEN
        RAISE EXCEPTION 'INVALID_PAYMENT_METHOD: Canal de pago (%) no válido. Permitidos: efectivo, nequi, llave_bre.', p_payment_method
            USING ERRCODE = '22023';
    END IF;

    -- Catálogo OPEX estricto de 5 categorías (POL-FIN-04 / SDD-026: 'Reembolso' retirado)
    IF v_category NOT IN ('Servicios', 'Nomina', 'Transporte', 'Mantenimiento', 'Insumos') THEN
        RAISE EXCEPTION 'INVALID_OPEX_CATEGORY: Categoría (%) no permitida. Permitidas: Servicios, Nomina, Transporte, Mantenimiento, Insumos.', p_category
            USING ERRCODE = '22023';
    END IF;

    IF p_description IS NULL OR LENGTH(TRIM(p_description)) < 3 THEN
        RAISE EXCEPTION 'EMPTY_DESCRIPTION: La descripción del gasto debe contener al menos 3 caracteres.'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_session
    FROM public.cash_sessions
    WHERE id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'NO_OPEN_SESSION: La sesión de caja (%) no existe.', p_session_id
            USING ERRCODE = 'P0002';
    END IF;

    PERFORM public.assert_store_access(v_session.store_id);

    IF v_session.status <> 'open' THEN
        RAISE EXCEPTION 'NO_OPEN_SESSION: No existe una sesión de caja abierta para registrar el gasto.'
            USING ERRCODE = 'P0001';
    END IF;

    IF (NOW() - v_session.opened_at) > INTERVAL '24 hours' THEN
        RAISE EXCEPTION 'SHIFT_EXPIRED_24H: El turno de caja superó el límite de 24 horas y pasó a Expirado/Bloqueado.'
            USING ERRCODE = 'P0001';
    END IF;

    IF v_method = 'efectivo' THEN
        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
        FROM public.cash_movements
        WHERE session_id = p_session_id AND movement_type = 'ingreso' AND payment_method = 'efectivo';

        SELECT COALESCE(SUM(amount), 0) INTO v_egresos
        FROM public.cash_movements
        WHERE session_id = p_session_id AND movement_type IN ('gasto', 'pago_proveedor', 'reembolso') AND payment_method = 'efectivo';

        v_available := COALESCE(v_session.opening_balance, 0) + v_ingresos - v_egresos;
    ELSE
        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
        FROM public.cash_movements
        WHERE session_id = p_session_id AND movement_type = 'ingreso' AND payment_method = v_method;

        SELECT COALESCE(SUM(amount), 0) INTO v_egresos
        FROM public.cash_movements
        WHERE session_id = p_session_id AND movement_type IN ('gasto', 'pago_proveedor', 'reembolso') AND payment_method = v_method;

        v_available := v_ingresos - v_egresos;
    END IF;

    IF p_amount > v_available THEN
        RAISE EXCEPTION 'INSUFFICIENT_CHANNEL_FUNDS: Fondos insuficientes en canal % (Disponible: %, Solicitado: %).', v_method, v_available, p_amount
            USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_session.store_id);
    SELECT e.id INTO v_emp_fk_id
    FROM public.employees e
    WHERE e.id = v_snap.actor_id AND e.store_id = v_session.store_id
    LIMIT 1;

    INSERT INTO public.cash_movements (
        session_id, movement_type, amount, description, payment_method, category, voucher_ref, actor_id, actor_name, actor_role
    ) VALUES (
        p_session_id, 'gasto', p_amount, TRIM(p_description), v_method, v_category, NULLIF(TRIM(p_voucher_ref), ''), v_emp_fk_id, v_snap.actor_name, v_snap.actor_role
    ) RETURNING id INTO v_movement_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'movement_id', v_movement_id,
            'session_id', p_session_id,
            'amount', p_amount,
            'payment_method', v_method,
            'category', v_category,
            'description', TRIM(p_description),
            'voucher_ref', NULLIF(TRIM(p_voucher_ref), ''),
            'movement_type', 'gasto',
            'remaining_channel_balance', v_available - p_amount,
            'actor_name', v_snap.actor_name,
            'actor_role', v_snap.actor_role,
            'created_at', NOW()
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;


-- ============================================================================
-- [CHK-209] RLS Centralizado de notifications (Regla 4) + GRANT ALL
-- ============================================================================
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view store notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own store notifications" ON public.notifications;
DROP POLICY IF EXISTS "Store members can insert general notifications" ON public.notifications;
DROP POLICY IF EXISTS "notifications_select_store" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update_store" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert_store" ON public.notifications;
DROP POLICY IF EXISTS "notifications_delete_store" ON public.notifications;

-- SELECT: Admin ve toda notificación de la tienda; empleados solo ('all','employee'), NUNCA 'admin'
CREATE POLICY "notifications_select_store" ON public.notifications
    FOR SELECT
    USING (
        store_id = public.get_current_store_id()
        AND (
            public.is_store_admin(store_id)
            OR audience = 'all'
            OR (audience = 'employee' AND EXISTS (
                SELECT 1 FROM public.employees e
                WHERE e.id = COALESCE(public.get_employee_id_from_session(), auth.uid())
                  AND e.store_id = notifications.store_id
            ))
        )
    );

-- UPDATE (marcar leída): Misma regla de audiencia y pertenencia a la tienda
CREATE POLICY "notifications_update_store" ON public.notifications
    FOR UPDATE
    USING (
        store_id = public.get_current_store_id()
        AND (
            public.is_store_admin(store_id)
            OR audience = 'all'
            OR (audience = 'employee' AND EXISTS (
                SELECT 1 FROM public.employees e
                WHERE e.id = COALESCE(public.get_employee_id_from_session(), auth.uid())
                  AND e.store_id = notifications.store_id
            ))
        )
    )
    WITH CHECK (
        store_id = public.get_current_store_id()
    );

-- INSERT directo PostgREST (B2-4): Empleados tienen PROHIBIDO insertar audience = 'admin' (las alertas de seguridad/caja usan SECURITY DEFINER)
CREATE POLICY "notifications_insert_store" ON public.notifications
    FOR INSERT
    WITH CHECK (
        store_id = public.get_current_store_id()
        AND (
            public.is_store_admin(store_id)
            OR audience = 'all'
        )
    );

-- DELETE: Exclusivo Administrador de la tienda
CREATE POLICY "notifications_delete_store" ON public.notifications
    FOR DELETE
    USING (
        store_id = public.get_current_store_id()
        AND public.is_store_admin(store_id)
    );

GRANT ALL ON TABLE public.notifications TO anon, authenticated, service_role;

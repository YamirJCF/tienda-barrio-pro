-- ============================================================================
-- MIGRACIÓN WO-OLA2-C2-001 (UX-ADR-002 / SDD-026):
-- Blindaje de Gastos OPEX 100% exclusivos del Administrador (assert_store_admin)
-- y Read Model autoritativo rpc_obtener_gastos_turno(p_session_id uuid).
-- Reglas aplicadas: Regla 2 (esquema real), Regla 3 (sin fallos silenciosos),
-- Regla 4 (assert_store_access + assert_store_admin), Regla 8 (GRANT EXECUTE).
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
SET search_path = public, pg_temp
AS $function$
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
    -- Enmienda UX-ADR-002 / SDD-026: Gastos OPEX estrictamente exclusivos del Administrador
    PERFORM public.assert_store_admin(v_session.store_id);

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
$function$;

GRANT EXECUTE ON FUNCTION public.rpc_registrar_gasto_v2(uuid, numeric, text, text, text, text)
    TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- Read Model Autoritativo OPEX del Turno (Exclusivo Admin, cero suma cliente)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_obtener_gastos_turno(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
    v_session RECORD;
    v_total_opex NUMERIC := 0;
    v_count INT := 0;
    v_data JSONB := '[]'::jsonb;
BEGIN
    SELECT id, store_id, status
    INTO v_session
    FROM public.cash_sessions
    WHERE id = p_session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'NO_OPEN_SESSION: La sesión de caja (%) no existe.', p_session_id
            USING ERRCODE = 'P0002';
    END IF;

    PERFORM public.assert_store_access(v_session.store_id);
    PERFORM public.assert_store_admin(v_session.store_id);

    SELECT
        COALESCE(SUM(cm.amount), 0),
        COUNT(*)::int,
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', cm.id,
                    'amount', cm.amount,
                    'description', cm.description,
                    'category', cm.category,
                    'payment_method', COALESCE(cm.payment_method, 'efectivo'),
                    'voucher_ref', cm.voucher_ref,
                    'actor_name', COALESCE(NULLIF(TRIM(cm.actor_name), ''), 'Administrador'),
                    'actor_role', COALESCE(NULLIF(TRIM(cm.actor_role), ''), 'owner'),
                    'created_at', cm.created_at
                )
                ORDER BY cm.created_at DESC, cm.id DESC
            ),
            '[]'::jsonb
        )
    INTO v_total_opex, v_count, v_data
    FROM public.cash_movements cm
    WHERE cm.session_id = p_session_id
      AND cm.movement_type = 'gasto';

    RETURN jsonb_build_object(
        'success', true,
        'session_id', v_session.id,
        'session_status', v_session.status,
        'total_opex_expenses', v_total_opex,
        'count', v_count,
        'data', v_data
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.rpc_obtener_gastos_turno(uuid)
    TO anon, authenticated, service_role;

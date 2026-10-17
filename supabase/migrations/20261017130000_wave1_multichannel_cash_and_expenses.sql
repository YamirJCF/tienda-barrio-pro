-- Migration: Wave 1 - Multichannel Cash Movements, OPEX Expenses v2, and 24h Shift Closure
-- Author: Data Architect (@[/data]) & Tech Lead (@[/orchestrator])
-- Certified SDDs: SDD_004, SDD_017, SDD_020, SDD_022, SDD_023, SDD_026

-- ==============================================================================
-- 1. DDL: Estructura Multicanal y Categorización en cash_movements
-- ==============================================================================

-- 1.1 Añadir columna payment_method con backfill seguro y constraint
ALTER TABLE public.cash_movements
ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'efectivo';

UPDATE public.cash_movements
SET payment_method = 'efectivo'
WHERE payment_method IS NULL;

ALTER TABLE public.cash_movements
ALTER COLUMN payment_method SET NOT NULL;

ALTER TABLE public.cash_movements
DROP CONSTRAINT IF EXISTS chk_cash_movements_payment_method;

ALTER TABLE public.cash_movements
ADD CONSTRAINT chk_cash_movements_payment_method
CHECK (payment_method IN ('efectivo', 'nequi', 'daviplata', 'bre'));

-- 1.2 Añadir columnas opcionales de categorización y comprobante para OPEX (SDD-022, SDD-026)
ALTER TABLE public.cash_movements
ADD COLUMN IF NOT EXISTS category TEXT;

ALTER TABLE public.cash_movements
ADD COLUMN IF NOT EXISTS voucher_ref TEXT;

-- 1.3 Índice compuesto para optimizar cómputo de saldos por canal en tiempo de ejecución
CREATE INDEX IF NOT EXISTS idx_cash_movements_session_channel_type
ON public.cash_movements (session_id, payment_method, movement_type);

-- ==============================================================================
-- 2. RPC: rpc_registrar_gasto_v2 (Registro Seguro de Gastos OPEX Multicanal)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.rpc_registrar_gasto_v2(
    p_session_id UUID,
    p_amount NUMERIC,
    p_payment_method TEXT,
    p_category TEXT,
    p_description TEXT,
    p_voucher_ref TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_session RECORD;
    v_actor_id UUID := auth.uid();
    v_method TEXT := LOWER(TRIM(p_payment_method));
    v_ingresos NUMERIC := 0;
    v_egresos NUMERIC := 0;
    v_available NUMERIC := 0;
    v_movement_id UUID;
BEGIN
    -- 1. Validación de parámetros de entrada
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'INVALID_AMOUNT: El monto del gasto debe ser un valor positivo mayor a cero.'
            USING ERRCODE = '22023';
    END IF;

    IF v_method NOT IN ('efectivo', 'nequi', 'daviplata', 'bre') THEN
        RAISE EXCEPTION 'INVALID_PAYMENT_METHOD: Canal de pago (%) no válido. Permitidos: efectivo, nequi, daviplata, bre.', p_payment_method
            USING ERRCODE = '22023';
    END IF;

    IF p_description IS NULL OR LENGTH(TRIM(p_description)) < 3 THEN
        RAISE EXCEPTION 'INVALID_DESCRIPTION: La descripción del gasto debe contener al menos 3 caracteres.'
            USING ERRCODE = '22023';
    END IF;

    -- 2. Obtener y bloquear la sesión de caja
    SELECT * INTO v_session
    FROM public.cash_sessions
    WHERE id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'SESSION_NOT_FOUND: La sesión de caja (%) no existe.', p_session_id
            USING ERRCODE = 'P0002';
    END IF;

    -- 3. Validación obligatoria de aislamiento multi-tenant (Regla 4 AGENTS.md)
    PERFORM public.assert_store_access(v_session.store_id);

    -- 4. Validar estado de la sesión
    IF v_session.status <> 'open' THEN
        RAISE EXCEPTION 'SHIFT_CLOSED: No se pueden registrar gastos en una caja cerrada.'
            USING ERRCODE = 'P0001';
    END IF;

    -- 5. Validar límite de 24 horas (POL-SEG-01 / SDD-017 / SDD-023)
    IF (now() - v_session.opened_at) > INTERVAL '24 hours' THEN
        RAISE EXCEPTION 'SHIFT_EXPIRED_24H: El turno de caja superó el límite legal de 24 horas. Debe cerrarse antes de registrar nuevos movimientos.'
            USING ERRCODE = 'P0001';
    END IF;

    -- 6. Calcular disponibilidad de fondos en el canal solicitado
    IF v_method = 'efectivo' THEN
        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
        FROM public.cash_movements
        WHERE session_id = p_session_id
          AND movement_type = 'ingreso'
          AND payment_method = 'efectivo';

        SELECT COALESCE(SUM(amount), 0) INTO v_egresos
        FROM public.cash_movements
        WHERE session_id = p_session_id
          AND movement_type IN ('gasto', 'pago_proveedor')
          AND payment_method = 'efectivo';

        v_available := v_session.opening_balance + v_ingresos - v_egresos;
    ELSE
        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
        FROM public.cash_movements
        WHERE session_id = p_session_id
          AND movement_type = 'ingreso'
          AND payment_method = v_method;

        SELECT COALESCE(SUM(amount), 0) INTO v_egresos
        FROM public.cash_movements
        WHERE session_id = p_session_id
          AND movement_type IN ('gasto', 'pago_proveedor')
          AND payment_method = v_method;

        v_available := v_ingresos - v_egresos;
    END IF;

    -- 7. Prevenir sobregiro (POL-FIN-01 / POL-FIN-02)
    IF p_amount > v_available THEN
        RAISE EXCEPTION 'INSUFFICIENT_CHANNEL_FUNDS: Fondos insuficientes en canal % (Disponible: %, Solicitado: %).', v_method, v_available, p_amount
            USING ERRCODE = 'P0001';
    END IF;

    -- 8. Asentar egreso en cash_movements
    INSERT INTO public.cash_movements (
        session_id,
        movement_type,
        amount,
        description,
        payment_method,
        category,
        voucher_ref
    ) VALUES (
        p_session_id,
        'gasto',
        p_amount,
        TRIM(p_description),
        v_method,
        TRIM(p_category),
        TRIM(p_voucher_ref)
    ) RETURNING id INTO v_movement_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'movement_id', v_movement_id,
            'session_id', p_session_id,
            'amount', p_amount,
            'payment_method', v_method,
            'category', TRIM(p_category),
            'description', TRIM(p_description),
            'voucher_ref', TRIM(p_voucher_ref),
            'remaining_channel_balance', v_available - p_amount,
            'created_at', now()
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_registrar_gasto_v2 TO authenticated, service_role;

-- ==============================================================================
-- 3. RPC: cerrar_caja (Arqueo con Conciliación Real y Manejo de Errores)
-- ==============================================================================

DROP FUNCTION IF EXISTS public.cerrar_caja(UUID, UUID, NUMERIC);

CREATE OR REPLACE FUNCTION public.cerrar_caja(
    p_session_id UUID,
    p_employee_id UUID,
    p_actual_balance NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_session RECORD;
    v_ingresos NUMERIC := 0;
    v_gastos NUMERIC := 0;
    v_expected NUMERIC := 0;
    v_difference NUMERIC := 0;
BEGIN
    IF p_actual_balance IS NULL OR p_actual_balance < 0 THEN
        RAISE EXCEPTION 'INVALID_ACTUAL_BALANCE: El monto en caja física debe ser mayor o igual a cero.'
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

    IF v_session.status = 'closed' THEN
        RAISE EXCEPTION 'ALREADY_CLOSED: La sesión de caja ya fue cerrada previamente.'
            USING ERRCODE = 'P0001';
    END IF;

    -- Calcular ingresos exclusivamente en efectivo
    SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
    FROM public.cash_movements
    WHERE session_id = p_session_id
      AND movement_type = 'ingreso'
      AND payment_method = 'efectivo';

    -- Calcular egresos exclusivamente en efectivo (gastos + pagos a proveedor)
    SELECT COALESCE(SUM(amount), 0) INTO v_gastos
    FROM public.cash_movements
    WHERE session_id = p_session_id
      AND movement_type IN ('gasto', 'pago_proveedor')
      AND payment_method = 'efectivo';

    -- Conciliación en efectivo: expected = base + ingresos - egresos
    v_expected := v_session.opening_balance + v_ingresos - v_gastos;
    -- Convención contable: difference = actual - expected (negativo = faltante, positivo = sobrante)
    v_difference := p_actual_balance - v_expected;

    UPDATE public.cash_sessions
    SET closed_by = p_employee_id,
        expected_balance = v_expected,
        actual_balance = p_actual_balance,
        difference = v_difference,
        status = 'closed',
        closed_at = now()
    WHERE id = p_session_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'session_id', p_session_id,
            'expected_balance', v_expected,
            'actual_balance', p_actual_balance,
            'difference', v_difference,
            'closed_at', now()
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cerrar_caja TO authenticated, service_role;

-- ==============================================================================
-- 4. RPC: rpc_check_and_force_close_shifts (Cierre Automático por Caducidad 24H)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.rpc_check_and_force_close_shifts()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    r RECORD;
    v_ingresos NUMERIC;
    v_gastos NUMERIC;
    v_expected NUMERIC;
    closed_count INT := 0;
BEGIN
    FOR r IN 
        SELECT id, store_id, opened_by, opening_balance, opened_at 
        FROM public.cash_sessions 
        WHERE status = 'open' 
          AND opened_at < (NOW() - INTERVAL '24 hours')
    LOOP
        -- Calcular ingresos en efectivo
        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
        FROM public.cash_movements
        WHERE session_id = r.id
          AND movement_type = 'ingreso'
          AND payment_method = 'efectivo';

        -- Calcular egresos en efectivo
        SELECT COALESCE(SUM(amount), 0) INTO v_gastos
        FROM public.cash_movements
        WHERE session_id = r.id
          AND movement_type IN ('gasto', 'pago_proveedor')
          AND payment_method = 'efectivo';

        v_expected := r.opening_balance + v_ingresos - v_gastos;

        UPDATE public.cash_sessions 
        SET status           = 'closed',
            forced_close     = true,
            expected_balance = v_expected,
            actual_balance   = NULL,
            difference       = NULL,
            closed_at        = NOW()
        WHERE id = r.id;

        -- Registrar en bitácora inmutable usando las columnas reales de audit_logs
        INSERT INTO public.audit_logs (
            actor_id,
            store_id,
            event_type,
            resource_id,
            metadata,
            severity,
            created_at
        ) VALUES (
            r.opened_by,
            r.store_id,
            'FORCED_CLOSE_24H',
            r.id::text,
            jsonb_build_object(
                'reason', 'Shift exceeded 24 hours without manual closure',
                'opened_at', r.opened_at,
                'forced_at', NOW(),
                'expected_balance', v_expected,
                'multichannel_segregated', true
            ),
            'warning',
            NOW()
        );

        -- Alerta de campana al administrador si la tabla notifications existe
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
            INSERT INTO public.notifications (
                store_id, type, title, message, audience, is_read, created_at
            ) VALUES (
                r.store_id,
                'finance',
                '⚠️ Cierre Forzado de Caja (24 Horas)',
                'Una caja fue cerrada automáticamente por el sistema tras cumplir 24 horas abierta. Se requiere verificación de saldo antes de iniciar nuevo turno.',
                'admin',
                FALSE,
                NOW()
            );
        END IF;

        closed_count := closed_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object('closed_shifts', closed_count)
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_check_and_force_close_shifts TO authenticated, service_role;

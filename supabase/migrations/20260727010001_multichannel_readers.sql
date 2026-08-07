-- Migration: Phase 2.2 - Multichannel Readers and Triggers
-- Date: 2026-07-27

-- ==============================================================================
-- 1. Modificar Trigger de Auditoría para Cierre de Caja
-- ==============================================================================
-- Este trigger consolida los saldos desde la nueva tabla (Fase 3) o
-- hace fallback a las columnas antiguas si el frontend aún no ha migrado (Fase 2).
CREATE OR REPLACE FUNCTION public.fn_audit_cash_closed()
RETURNS TRIGGER AS $$
DECLARE
    v_final_amounts JSONB;
BEGIN
    IF (OLD.status IS DISTINCT FROM NEW.status) AND NEW.status = 'closed' THEN
        -- Intentar extraer los saldos de la nueva tabla multicanal
        SELECT jsonb_object_agg(
            payment_method, 
            jsonb_build_object(
                'expected', expected_amount, 
                'actual', actual_amount, 
                'difference', difference
            )
        ) INTO v_final_amounts
        FROM public.cash_session_balances
        WHERE session_id = NEW.id;

        -- Fallback de compatibilidad: Si la nueva tabla aún no tiene el 'actual_amount' (porque el frontend viejo cerró la caja),
        -- usamos los valores legacy de NEW para no perder la auditoría del descuadre físico.
        IF v_final_amounts IS NULL OR NOT (v_final_amounts ? 'efectivo') OR (v_final_amounts->'efectivo'->>'actual') IS NULL THEN
            v_final_amounts := jsonb_build_object(
                'efectivo', jsonb_build_object(
                    'expected', NEW.expected_balance,
                    'actual', NEW.actual_balance,
                    'difference', NEW.difference
                )
            );
        END IF;

        INSERT INTO public.audit_caja (session_id, store_id, event_type, actor_id, metadata)
        VALUES (
            NEW.id,
            NEW.store_id,
            'CIERRE',
            NEW.closed_by,
            jsonb_build_object(
                'initial_amount', NEW.opening_balance,
                'balances', v_final_amounts,
                -- Mantenemos campos legacy top-level temporalmente por retrocompatibilidad de vistas
                'final_amount', NEW.actual_balance,
                'difference', NEW.difference
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==============================================================================
-- 2. Reescribir rpc_check_and_force_close_shifts para Multicanal
-- ==============================================================================
-- Se encarga de forzar el cierre calculando el expected_balance de todos los métodos.
CREATE OR REPLACE FUNCTION rpc_check_and_force_close_shifts()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $FUNC$
DECLARE
    r RECORD;
    closed_count INT := 0;
    v_total_expected DECIMAL := 0;
BEGIN
    FOR r IN 
        SELECT id, store_id, opening_balance, opened_at 
        FROM public.cash_sessions 
        WHERE status = 'open' 
          AND opened_at < (NOW() - INTERVAL '24 hours')
    LOOP
        -- Calcular e insertar en la nueva tabla multicanal
        WITH methods AS (
            SELECT DISTINCT payment_method FROM public.cash_movements WHERE session_id = r.id
            UNION
            SELECT 'efectivo'
        )
        INSERT INTO public.cash_session_balances (session_id, payment_method, expected_amount)
        SELECT 
            r.id,
            methods.payment_method,
            (CASE WHEN methods.payment_method = 'efectivo' THEN r.opening_balance ELSE 0 END) +
            COALESCE(SUM(CASE WHEN m.movement_type = 'ingreso' THEN m.amount ELSE 0 END), 0) -
            COALESCE(SUM(CASE WHEN m.movement_type IN ('gasto', 'pago_proveedor') THEN m.amount ELSE 0 END), 0)
        FROM methods
        LEFT JOIN public.cash_movements m ON m.session_id = r.id AND m.payment_method = methods.payment_method
        GROUP BY methods.payment_method
        ON CONFLICT (session_id, payment_method) 
        DO UPDATE SET expected_amount = EXCLUDED.expected_amount;

        -- Sumar el total esperado de todos los canales (Fase 2 compatibilidad)
        SELECT COALESCE(SUM(expected_amount), 0) INTO v_total_expected
        FROM public.cash_session_balances
        WHERE session_id = r.id;

        -- Cerrar la sesión (manteniendo expected_balance general para compatibilidad)
        UPDATE public.cash_sessions 
        SET status         = 'closed',
            forced_close   = true,
            expected_balance = v_total_expected, 
            actual_balance = NULL,
            difference     = NULL,
            closed_at      = NOW()
        WHERE id = r.id;

        -- Auditoría
        INSERT INTO public.audit_logs (
            store_id, action, entity, entity_id, payload, created_at
        ) VALUES (
            r.store_id,
            'FORCED_CLOSE_24H',
            'cash_sessions',
            r.id,
            jsonb_build_object(
                'reason',           'Shift exceeded 24 hours without manual closure',
                'opened_at',        r.opened_at,
                'forced_at',        NOW(),
                'expected_balance', v_total_expected,
                'multichannel',     true
            ),
            NOW()
        );

        INSERT INTO public.notifications (
            store_id, type, title, message, audience, is_read, created_at
        ) VALUES (
            r.store_id,
            'finance',
            '⚠️ Cierre Forzado de Caja (24 Horas)',
            'Una caja fue cerrada automáticamente por el sistema tras cumplir 24 horas abierta. Se requiere verificación de saldo multicanal antes de iniciar nuevo turno.',
            'admin',
            FALSE,
            NOW()
        );

        closed_count := closed_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'closed_shifts', closed_count);
END;
$FUNC$;

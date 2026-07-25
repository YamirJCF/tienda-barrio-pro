-- Migration: 24h Forced Closure Mechanism & Audit Logging
-- Date: 2026-07-25
-- FRD-017 v3.0 Compliance

CREATE OR REPLACE FUNCTION rpc_check_and_force_close_shifts()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    r RECORD;
    v_ingresos DECIMAL;
    v_gastos DECIMAL;
    v_expected DECIMAL;
    closed_count INT := 0;
BEGIN
    FOR r IN 
        SELECT id, store_id, opening_balance, opened_at 
        FROM public.cash_sessions 
        WHERE status = 'open' 
          AND opened_at < (NOW() - INTERVAL '24 hours')
    LOOP
        -- Calcular ingresos de la sesión
        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type = 'ingreso';
        
        -- Calcular gastos de la sesión
        SELECT COALESCE(SUM(amount), 0) INTO v_gastos
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type = 'gasto';
        
        v_expected := r.opening_balance + v_ingresos - v_gastos;

        -- 1. Cerrar la sesión de caja
        UPDATE public.cash_sessions 
        SET status = 'closed',
            expected_balance = v_expected,
            actual_balance = NULL, 
            difference = NULL,
            closed_at = NOW()
        WHERE id = r.id;

        -- 2. Insertar registro de auditoría
        INSERT INTO public.audit_logs (
            store_id,
            action,
            entity,
            entity_id,
            payload,
            created_at
        ) VALUES (
            r.store_id,
            'FORCED_CLOSE_24H',
            'cash_sessions',
            r.id,
            jsonb_build_object(
                'reason', 'Shift exceeded 24 hours without manual closure',
                'opened_at', r.opened_at,
                'forced_at', NOW(),
                'expected_balance', v_expected
            ),
            NOW()
        );

        -- 3. Insertar notificación para el administrador
        INSERT INTO public.notifications (
            store_id,
            type,
            title,
            message,
            audience,
            is_read,
            created_at
        ) VALUES (
            r.store_id,
            'finance',
            '⚠️ Cierre Forzado de Caja (24 Horas)',
            'Una caja fue cerrada automáticamente por el sistema tras cumplir 24 horas abierta. Se requiere verificación de saldo antes de iniciar nuevo turno.',
            'admin',
            FALSE,
            NOW()
        );

        closed_count := closed_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'closed_shifts', closed_count
    );
END;
$$;

GRANT EXECUTE ON FUNCTION rpc_check_and_force_close_shifts() TO authenticated;

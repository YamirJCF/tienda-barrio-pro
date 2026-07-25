-- Migration: Add forced_close column and reconciliation RPC
-- Date: 2026-07-25
-- FRD-017 v3.0 — Completes Task 4 backend requirements

-- ============================================================
-- 1. DDL: Add explicit forced_close marker to cash_sessions
-- ============================================================
ALTER TABLE public.cash_sessions
ADD COLUMN IF NOT EXISTS forced_close BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.cash_sessions.forced_close IS
  'FRD-017: Marcado como true únicamente cuando el sistema cierra la sesión automáticamente por exceder el límite de 24 horas. Permite distinguir cierres automáticos de manuales sin inferencias frágiles.';

-- ============================================================
-- 2. Functions: Update rpc_check_and_force_close_shifts to
--    set forced_close = true (the critical missing step)
-- ============================================================
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
        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type = 'ingreso';
        
        SELECT COALESCE(SUM(amount), 0) INTO v_gastos
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type = 'gasto';
        
        v_expected := r.opening_balance + v_ingresos - v_gastos;

        UPDATE public.cash_sessions 
        SET status         = 'closed',
            forced_close   = true,          -- SEÑAL EXPLÍCITA (FRD-017)
            expected_balance = v_expected,
            actual_balance = NULL,          -- Pendiente de reconciliación manual
            difference     = NULL,
            closed_at      = NOW()
        WHERE id = r.id;

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
                'expected_balance', v_expected
            ),
            NOW()
        );

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

        closed_count := closed_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'closed_shifts', closed_count);
END;
$$;

GRANT EXECUTE ON FUNCTION rpc_check_and_force_close_shifts() TO authenticated;

-- ============================================================
-- 3. Functions: rpc_reconciliar_cierre_forzado
--    Único RPC autorizado para conciliar un cierre forzado.
--    Precondiciones estrictas para evitar doble-reconciliación.
-- ============================================================
CREATE OR REPLACE FUNCTION rpc_reconciliar_cierre_forzado(
    p_session_id   UUID,
    p_employee_id  UUID,
    p_actual_balance NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session     public.cash_sessions%ROWTYPE;
    v_employee    RECORD;
    v_difference  DECIMAL;
BEGIN
    -- Validar input
    IF p_actual_balance < 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'El balance real no puede ser negativo', 'code', 'INVALID_BALANCE');
    END IF;

    -- Verificar que el empleado tiene permiso canOpenCloseCash
    SELECT e.id, e.permissions INTO v_employee
    FROM public.employees e
    WHERE e.id = p_employee_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Empleado no encontrado', 'code', 'EMPLOYEE_NOT_FOUND');
    END IF;

    IF NOT COALESCE((v_employee.permissions->>'canOpenCloseCash')::boolean, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Sin permiso para reconciliar cierres de caja', 'code', 'INSUFFICIENT_PERMISSIONS');
    END IF;

    -- Obtener la sesión con precondiciones estrictas (evita doble-reconciliación)
    SELECT * INTO v_session
    FROM public.cash_sessions
    WHERE id            = p_session_id
      AND status        = 'closed'
      AND forced_close  = true
      AND actual_balance IS NULL;   -- Aún no ha sido conciliada

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error',  'La sesión no existe, no fue cerrada forzosamente, o ya fue reconciliada',
            'code',   'SESSION_NOT_RECONCILIABLE'
        );
    END IF;

    v_difference := v_session.expected_balance - p_actual_balance;

    -- Actualizar la sesión con el conteo físico real
    UPDATE public.cash_sessions
    SET actual_balance = p_actual_balance,
        difference     = v_difference,
        closed_by      = p_employee_id
    WHERE id = p_session_id;

    -- Registrar auditoría de la reconciliación
    INSERT INTO public.audit_logs (
        store_id, action, entity, entity_id, payload, created_at
    ) VALUES (
        v_session.store_id,
        'FORCED_CLOSE_RECONCILED',
        'cash_sessions',
        p_session_id,
        jsonb_build_object(
            'reconciled_by',    p_employee_id,
            'actual_balance',   p_actual_balance,
            'expected_balance', v_session.expected_balance,
            'difference',       v_difference,
            'reconciled_at',    NOW()
        ),
        NOW()
    );

    RETURN jsonb_build_object(
        'success',          true,
        'expected_balance', v_session.expected_balance,
        'actual_balance',   p_actual_balance,
        'difference',       v_difference
    );
END;
$$;

GRANT EXECUTE ON FUNCTION rpc_reconciliar_cierre_forzado(UUID, UUID, NUMERIC) TO authenticated;

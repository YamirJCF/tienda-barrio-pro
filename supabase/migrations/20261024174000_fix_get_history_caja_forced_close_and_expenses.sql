-- =============================================================================
-- Migración: 20261024174000_fix_get_history_caja_forced_close_and_expenses.sql
-- Objetivo:
--   1. Incluir 'pago_proveedor' en total_expenses de get_history_caja (paridad con cerrar_caja).
--   2. Exponer net_session_balance, reconciliation_status y event_type calculados en Backend (Muro 1).
--   3. Filtrar sesiones por fecha de apertura O cierre en zona horaria America/Bogota.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_history_caja(
    p_store_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_result JSONB;
BEGIN
    -- Regla 4: Aislamiento Multi-Tenant obligatorio en instrucción #1
    PERFORM public.assert_store_access(p_store_id);

    SELECT COALESCE(jsonb_agg(row_data ORDER BY COALESCE(closed_at, opened_at) DESC, opened_at DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', cs.id,
            'status', cs.status,
            'event_type', CASE WHEN cs.status = 'closed' THEN 'CIERRE' ELSE 'APERTURA' END,
            'reconciliation_status', CASE
                WHEN cs.status = 'open' THEN 'open'
                WHEN COALESCE(cs.forced_close, false) = true AND cs.actual_balance IS NULL THEN 'forced_pending_reconciliation'
                WHEN COALESCE(cs.forced_close, false) = true AND cs.actual_balance IS NOT NULL THEN 'forced_reconciled'
                ELSE 'closed_reconciled'
            END,
            'opening_balance', cs.opening_balance,
            'actual_balance', cs.actual_balance,
            'expected_balance', cs.expected_balance,
            'difference', cs.difference,
            'net_session_balance', (
                cs.opening_balance
                + COALESCE((
                    SELECT SUM(cm.amount)
                    FROM public.cash_movements cm
                    WHERE cm.session_id = cs.id AND cm.movement_type = 'ingreso'
                ), 0)
                - COALESCE((
                    SELECT SUM(cm.amount)
                    FROM public.cash_movements cm
                    WHERE cm.session_id = cs.id AND cm.movement_type IN ('gasto', 'pago_proveedor')
                ), 0)
            ),
            'opened_by_name', COALESCE(eo.name, ap_open.id::text, 'Desconocido'),
            'closed_by_name', COALESCE(ec.name, ap_close.id::text, NULL),
            'opened_at', cs.opened_at,
            'closed_at', cs.closed_at,
            'forced_close', COALESCE(cs.forced_close, false),
            'total_movements', (SELECT COUNT(*) FROM public.cash_movements cm WHERE cm.session_id = cs.id),
            'total_income', (
                SELECT COALESCE(SUM(cm.amount), 0)
                FROM public.cash_movements cm
                WHERE cm.session_id = cs.id AND cm.movement_type = 'ingreso'
            ),
            'total_expenses', (
                SELECT COALESCE(SUM(cm.amount), 0)
                FROM public.cash_movements cm
                WHERE cm.session_id = cs.id AND cm.movement_type IN ('gasto', 'pago_proveedor')
            ),
            'income_efectivo', (
                SELECT COALESCE(SUM(cm.amount), 0)
                FROM public.cash_movements cm
                WHERE cm.session_id = cs.id AND cm.movement_type = 'ingreso' AND cm.payment_method = 'efectivo'
            ),
            'income_nequi', (
                SELECT COALESCE(SUM(cm.amount), 0)
                FROM public.cash_movements cm
                WHERE cm.session_id = cs.id AND cm.movement_type = 'ingreso' AND cm.payment_method = 'nequi'
            ),
            'income_daviplata', (
                SELECT COALESCE(SUM(cm.amount), 0)
                FROM public.cash_movements cm
                WHERE cm.session_id = cs.id AND cm.movement_type = 'ingreso' AND cm.payment_method = 'daviplata'
            ),
            'income_bre', (
                SELECT COALESCE(SUM(cm.amount), 0)
                FROM public.cash_movements cm
                WHERE cm.session_id = cs.id AND cm.movement_type = 'ingreso' AND cm.payment_method = 'bre'
            )
        ) AS row_data,
        cs.opened_at,
        cs.closed_at
        FROM public.cash_sessions cs
        LEFT JOIN public.employees eo ON eo.id = cs.opened_by
        LEFT JOIN public.employees ec ON ec.id = cs.closed_by
        LEFT JOIN public.admin_profiles ap_open ON ap_open.id = cs.opened_by
        LEFT JOIN public.admin_profiles ap_close ON ap_close.id = cs.closed_by
        WHERE cs.store_id = p_store_id
          AND (
              (cs.opened_at AT TIME ZONE 'America/Bogota')::DATE BETWEEN p_start_date AND p_end_date
              OR (cs.closed_at IS NOT NULL AND (cs.closed_at AT TIME ZONE 'America/Bogota')::DATE BETWEEN p_start_date AND p_end_date)
          )
        LIMIT 100
    ) sub;

    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_history_caja(UUID, DATE, DATE) TO authenticated, service_role;

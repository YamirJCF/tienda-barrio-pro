-- =============================================
-- Migration: Forced Close Logic & System Notifications (FRD-017)
-- =============================================

-- 1. Create system_notifications table
CREATE TABLE IF NOT EXISTS public.system_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS for system_notifications
ALTER TABLE public.system_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "system_notifications_select" ON public.system_notifications
    FOR SELECT USING (store_id = public.get_current_store_id());

CREATE POLICY "system_notifications_update" ON public.system_notifications
    FOR UPDATE USING (store_id = public.get_current_store_id());

-- 2. RPC to force-close stale cash sessions (> 24 hours open)
CREATE OR REPLACE FUNCTION public.rpc_force_close_stale_registers()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session RECORD;
    v_closed_count INT := 0;
    v_total_income NUMERIC := 0;
    v_total_expense NUMERIC := 0;
    v_calc_expected NUMERIC := 0;
BEGIN
    FOR v_session IN
        SELECT id, store_id, opening_balance, opened_by, opened_at
        FROM public.cash_sessions
        WHERE status = 'open'
          AND opened_at < (NOW() - INTERVAL '24 hours')
    LOOP
        -- Calculate income & expenses from cash_movements
        SELECT COALESCE(SUM(amount), 0) INTO v_total_income
        FROM public.cash_movements
        WHERE session_id = v_session.id AND type = 'income';

        SELECT COALESCE(SUM(amount), 0) INTO v_total_expense
        FROM public.cash_movements
        WHERE session_id = v_session.id AND type = 'expense';

        v_calc_expected := v_session.opening_balance + v_total_income - v_total_expense;

        -- Close the stale session
        UPDATE public.cash_sessions
        SET status = 'closed',
            closed_at = NOW(),
            expected_balance = v_calc_expected,
            actual_balance = v_calc_expected,
            difference = 0
        WHERE id = v_session.id;

        -- Insert audit log
        INSERT INTO public.audit_logs (
            store_id,
            action,
            entity,
            entity_id,
            details,
            created_at
        ) VALUES (
            v_session.store_id,
            'FORCED_CLOSE',
            'cash_sessions',
            v_session.id,
            jsonb_build_object(
                'reason', 'Cierre automático por superar las 24 horas continuas de apertura',
                'opened_at', v_session.opened_at,
                'closed_at', NOW(),
                'expected_balance', v_calc_expected
            ),
            NOW()
        );

        -- Insert system notification for store
        INSERT INTO public.system_notifications (
            store_id,
            type,
            title,
            message,
            created_at
        ) VALUES (
            v_session.store_id,
            'FORCED_CLOSE',
            'Turno Cerrado Forzosamente',
            'Su último turno de caja superó las 24 horas de apertura sin arqueo manual. El sistema realizó un cierre forzado para proteger la trazabilidad contable. Por favor audite su efectivo.',
            NOW()
        );

        v_closed_count := v_closed_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'closed_count', v_closed_count
    );
END;
$$;

-- 3. RPC to fetch unread system notifications
CREATE OR REPLACE FUNCTION public.rpc_get_unread_notifications(p_store_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_notifications JSONB;
BEGIN
    SELECT COALESCE(jsonb_agg(to_jsonb(n)), '[]'::jsonb)
    INTO v_notifications
    FROM (
        SELECT id, type, title, message, created_at
        FROM public.system_notifications
        WHERE store_id = p_store_id
          AND read = FALSE
        ORDER BY created_at DESC
    ) n;

    RETURN jsonb_build_object(
        'success', true,
        'notifications', v_notifications
    );
END;
$$;

-- 4. RPC to mark notification as read
CREATE OR REPLACE FUNCTION public.rpc_mark_notification_read(p_notification_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE public.system_notifications
    SET read = TRUE
    WHERE id = p_notification_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- 5. Updated get_active_cash_session with Lazy Evaluation
CREATE OR REPLACE FUNCTION public.get_active_cash_session(p_store_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session RECORD;
BEGIN
    -- Lazy Evaluation: Force close any session > 24h old before checking status
    PERFORM public.rpc_force_close_stale_registers();

    SELECT * INTO v_session
    FROM public.cash_sessions
    WHERE store_id = p_store_id
      AND status = 'open'
    ORDER BY opened_at DESC
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'isOpen', true,
            'sessionId', v_session.id,
            'openingAmount', v_session.opening_balance,
            'openedBy', v_session.opened_by,
            'openedAt', v_session.opened_at
        );
    ELSE
        RETURN jsonb_build_object('isOpen', false);
    END IF;
END;
$$;

-- Grants
GRANT EXECUTE ON FUNCTION public.rpc_force_close_stale_registers() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_get_unread_notifications(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_mark_notification_read(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_active_cash_session(UUID) TO authenticated, anon, service_role;


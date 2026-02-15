-- ==============================================================================
-- MIGRATION: PHASE 4A - SECURITY HARDENING: STORE ACCESS CONTROL
-- Date: 2026-02-15
-- Ref: QA_AUDIT_FINANCIAL_MODULE.md
-- Description:
--   1. Creates assert_store_access() helper function
--   2. Hardens 10 RPCs with ownership validation
--   3. Fixes search_path on all SECURITY DEFINER functions
--   4. Replaces SQLERRM exposure with generic error messages
-- ==============================================================================

-- ==============================================================================
-- HELPER: assert_store_access(UUID)
-- Centralized ownership check. Validates that auth.uid() is either:
--   a) The admin (owner) of the store
--   b) An active employee of the store
-- Raises EXCEPTION if access denied.
-- ==============================================================================
CREATE OR REPLACE FUNCTION assert_store_access(p_store_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM stores WHERE id = p_store_id AND admin_id = auth.uid()
    ) AND NOT EXISTS (
        SELECT 1 FROM employees
        WHERE store_id = p_store_id AND user_id = auth.uid() AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED'
            USING HINT = 'El usuario no tiene acceso a esta tienda';
    END IF;
END;
$$;


-- ==============================================================================
-- GRUPO A: REPORTES (READ-ONLY) — Añadir assert_store_access + search_path
-- ==============================================================================

-- A1. get_financial_summary
CREATE OR REPLACE FUNCTION get_financial_summary(
    p_store_id UUID,
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_sales NUMERIC DEFAULT 0;
    v_total_cost NUMERIC DEFAULT 0;
    v_net_profit NUMERIC DEFAULT 0;
    v_profit_margin NUMERIC DEFAULT 0;
    v_breakdown JSONB;
    v_fiado_pendiente NUMERIC DEFAULT 0;
    v_avg_sales_7d NUMERIC DEFAULT 0;
    v_traffic_status TEXT;
    v_traffic_message TEXT;
    v_start_ts TIMESTAMPTZ;
    v_end_ts TIMESTAMPTZ;
BEGIN
    -- SECURITY: Ownership check
    PERFORM assert_store_access(p_store_id);

    v_start_ts := p_start_date::TIMESTAMPTZ;
    v_end_ts := (p_end_date + INTERVAL '1 day')::TIMESTAMPTZ;

    -- 1. VENTAS TOTALES (Revenue)
    SELECT COALESCE(SUM(total), 0)
    INTO v_total_sales
    FROM public.sales
    WHERE store_id = p_store_id
      AND created_at >= v_start_ts
      AND created_at < v_end_ts
      AND is_voided = FALSE;

    -- 2. COSTO DE MERCANCÍA VENDIDA (COGS)
    SELECT COALESCE(SUM(si.quantity * si.unit_cost), 0)
    INTO v_total_cost
    FROM public.sale_items si
    JOIN public.sales s ON si.sale_id = s.id
    WHERE s.store_id = p_store_id
      AND s.created_at >= v_start_ts
      AND s.created_at < v_end_ts
      AND s.is_voided = FALSE;

    -- 3. GANANCIA NETA Y MARGEN
    v_net_profit := v_total_sales - v_total_cost;
    IF v_total_sales > 0 THEN
        v_profit_margin := ROUND((v_net_profit / v_total_sales) * 100, 2);
    END IF;

    -- 4. DESGLOSE POR MÉTODO DE PAGO
    SELECT jsonb_object_agg(method_group, amount)
    INTO v_breakdown
    FROM (
        SELECT
            CASE
                WHEN payment_method IN ('nequi', 'daviplata') THEN 'transfer'
                WHEN payment_method = 'fiado' THEN 'credit'
                ELSE 'cash'
            END as method_group,
            SUM(total) as amount
        FROM public.sales
        WHERE store_id = p_store_id
            AND created_at >= v_start_ts
            AND created_at < v_end_ts
            AND is_voided = FALSE
        GROUP BY 1
    ) sub;

    v_breakdown := jsonb_build_object(
        'cash', COALESCE((v_breakdown->>'cash')::NUMERIC, 0),
        'transfer', COALESCE((v_breakdown->>'transfer')::NUMERIC, 0),
        'credit', COALESCE((v_breakdown->>'credit')::NUMERIC, 0)
    );

    -- 5. FIADO PENDIENTE
    SELECT COALESCE(SUM(balance), 0)
    INTO v_fiado_pendiente
    FROM public.clients
    WHERE store_id = p_store_id
      AND (is_deleted = FALSE OR is_deleted IS NULL)
      AND balance > 0;

    -- 6. SEMÁFORO
    SELECT COALESCE(AVG(daily_total), 0)
    INTO v_avg_sales_7d
    FROM (
        SELECT DATE(created_at) as day, SUM(total) as daily_total
        FROM public.sales
        WHERE store_id = p_store_id
          AND created_at >= (v_start_ts - INTERVAL '7 days')
          AND created_at < v_start_ts
          AND is_voided = FALSE
        GROUP BY 1
    ) past_sales;

    IF v_avg_sales_7d = 0 THEN
        v_traffic_status := 'gray';
        v_traffic_message := 'Recopilando datos históricos...';
    ELSIF v_total_sales >= (v_avg_sales_7d * 1.05) THEN
        v_traffic_status := 'green';
        v_traffic_message := '🚀 ¡Vas un ' || ROUND(((v_total_sales - v_avg_sales_7d) / v_avg_sales_7d * 100), 0) || '% arriba de tu promedio!';
    ELSIF v_total_sales <= (v_avg_sales_7d * 0.95) THEN
        v_traffic_status := 'red';
        v_traffic_message := '🔻 Estás un ' || ROUND(((v_avg_sales_7d - v_total_sales) / v_avg_sales_7d * 100), 0) || '% abajo de tu promedio.';
    ELSE
        v_traffic_status := 'green';
        v_traffic_message := '👍 Ventas estables respecto a tu semana.';
    END IF;

    -- 7. RETORNAR PAYLOAD
    RETURN jsonb_build_object(
        'total_sales', v_total_sales,
        'total_cost', v_total_cost,
        'net_profit', v_net_profit,
        'profit_margin', v_profit_margin,
        'money_breakdown', v_breakdown,
        'fiado_pendiente', v_fiado_pendiente,
        'traffic_light', jsonb_build_object(
            'status', v_traffic_status,
            'message', v_traffic_message
        )
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', 'Error interno del servidor');
END;
$$;


-- A2. get_top_selling_products
CREATE OR REPLACE FUNCTION get_top_selling_products(
    p_store_id UUID,
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    product_id UUID,
    product_name TEXT,
    units_sold NUMERIC,
    revenue NUMERIC,
    profit NUMERIC,
    stock_remaining NUMERIC,
    stock_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_start_ts TIMESTAMPTZ;
    v_end_ts TIMESTAMPTZ;
BEGIN
    -- SECURITY: Ownership check
    PERFORM assert_store_access(p_store_id);

    v_start_ts := p_start_date::TIMESTAMPTZ;
    v_end_ts := (p_end_date + INTERVAL '1 day')::TIMESTAMPTZ;

    RETURN QUERY
    SELECT
        p.id AS product_id,
        p.name AS product_name,
        SUM(si.quantity) AS units_sold,
        SUM(si.subtotal) AS revenue,
        SUM(si.subtotal - (si.quantity * si.unit_cost)) AS profit,
        p.current_stock AS stock_remaining,
        CASE
            WHEN p.current_stock <= 0 THEN 'out'
            WHEN p.current_stock <= p.min_stock THEN 'critical'
            WHEN p.current_stock <= (p.min_stock * 1.5) THEN 'low'
            ELSE 'ok'
        END AS stock_status
    FROM public.sale_items si
    JOIN public.sales s ON si.sale_id = s.id
    JOIN public.products p ON si.product_id = p.id
    WHERE s.store_id = p_store_id
      AND s.created_at >= v_start_ts
      AND s.created_at < v_end_ts
      AND s.is_voided = FALSE
    GROUP BY p.id, p.name, p.current_stock, p.min_stock
    ORDER BY units_sold DESC
    LIMIT p_limit;
END;
$$;


-- A3. get_stagnant_products
CREATE OR REPLACE FUNCTION get_stagnant_products(
    p_store_id UUID,
    p_days_threshold INTEGER DEFAULT 30
)
RETURNS TABLE (
    product_id UUID,
    product_name TEXT,
    last_sale_date DATE,
    days_stagnant INTEGER,
    stock_value NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- SECURITY: Ownership check
    PERFORM assert_store_access(p_store_id);

    RETURN QUERY
    SELECT
        p.id AS product_id,
        p.name AS product_name,
        MAX(s.created_at)::DATE AS last_sale_date,
        EXTRACT(DAY FROM (CURRENT_TIMESTAMP - COALESCE(MAX(s.created_at), p.created_at)))::INTEGER AS days_stagnant,
        (p.current_stock * p.cost_price) AS stock_value
    FROM public.products p
    LEFT JOIN public.sale_items si ON si.product_id = p.id
    LEFT JOIN public.sales s ON si.sale_id = s.id
        AND s.is_voided = FALSE
        AND s.store_id = p_store_id
    WHERE p.store_id = p_store_id
      AND p.current_stock > 0
    GROUP BY p.id, p.name, p.current_stock, p.cost_price, p.created_at
    HAVING MAX(s.created_at) IS NULL
        OR MAX(s.created_at) < (CURRENT_TIMESTAMP - (p_days_threshold || ' days')::INTERVAL)
    ORDER BY days_stagnant DESC;
END;
$$;


-- A4. get_daily_summary
CREATE OR REPLACE FUNCTION get_daily_summary(
    p_store_id UUID,
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_sales NUMERIC DEFAULT 0;
    v_avg_sales_7d NUMERIC DEFAULT 0;
    v_breakdown JSONB;
    v_alerts JSONB;
    v_traffic_status TEXT;
    v_traffic_message TEXT;
    v_start_date TIMESTAMPTZ;
    v_end_date TIMESTAMPTZ;
BEGIN
    -- SECURITY: Ownership check
    PERFORM assert_store_access(p_store_id);

    v_start_date := p_date::TIMESTAMPTZ;
    v_end_date := v_start_date + INTERVAL '1 day';

    -- 1. Hero Number (Ventas Totales del Día)
    SELECT COALESCE(SUM(total), 0)
    INTO v_total_sales
    FROM sales
    WHERE store_id = p_store_id
      AND created_at >= v_start_date
      AND created_at < v_end_date
      AND is_voided = FALSE;

    -- 2. Money Breakdown
    SELECT jsonb_object_agg(method_group, amount)
    INTO v_breakdown
    FROM (
        SELECT
            CASE
                WHEN payment_method IN ('nequi', 'daviplata') THEN 'transfer'
                WHEN payment_method = 'fiado' THEN 'credit'
                ELSE 'cash'
            END as method_group,
            SUM(total) as amount
        FROM sales
        WHERE store_id = p_store_id
            AND created_at >= v_start_date
            AND created_at < v_end_date
            AND is_voided = FALSE
        GROUP BY 1
    ) sub;

    v_breakdown := jsonb_build_object(
        'cash', COALESCE((v_breakdown->>'cash')::NUMERIC, 0),
        'transfer', COALESCE((v_breakdown->>'transfer')::NUMERIC, 0),
        'credit', COALESCE((v_breakdown->>'credit')::NUMERIC, 0)
    );

    -- 3. Traffic Light
    SELECT COALESCE(AVG(daily_total), 0)
    INTO v_avg_sales_7d
    FROM (
        SELECT DATE(created_at) as day, SUM(total) as daily_total
        FROM sales
        WHERE store_id = p_store_id
          AND created_at >= (v_start_date - INTERVAL '7 days')
          AND created_at < v_start_date
          AND is_voided = FALSE
        GROUP BY 1
    ) past_sales;

    IF v_avg_sales_7d = 0 THEN
        v_traffic_status := 'gray';
        v_traffic_message := 'Recopilando datos históricos...';
    ELSIF v_total_sales >= (v_avg_sales_7d * 1.05) THEN
        v_traffic_status := 'green';
        v_traffic_message := '🚀 ¡Vas un ' || ROUND(((v_total_sales - v_avg_sales_7d) / v_avg_sales_7d * 100), 0) || '% arriba de tu promedio!';
    ELSIF v_total_sales <= (v_avg_sales_7d * 0.95) THEN
        v_traffic_status := 'red';
        v_traffic_message := '🔻 Estás un ' || ROUND(((v_avg_sales_7d - v_total_sales) / v_avg_sales_7d * 100), 0) || '% abajo de tu promedio.';
    ELSE
        v_traffic_status := 'green';
        v_traffic_message := '👍 Ventas estables respecto a tu semana.';
    END IF;

    -- 4. Alertas (Stock Crítico)
    SELECT jsonb_agg(jsonb_build_object(
        'type', 'stock_critical',
        'message', CASE WHEN current_stock <= 0 THEN '❌ Agotado: ' || name ELSE '⚠️ Bajo stock: ' || name END,
        'target_id', id,
        'stock', current_stock
    ))
    INTO v_alerts
    FROM products
    WHERE store_id = p_store_id
      AND current_stock <= min_stock
    LIMIT 5;

    IF v_alerts IS NULL THEN v_alerts := '[]'::JSONB; END IF;

    -- 5. Retornar Payload
    RETURN jsonb_build_object(
        'traffic_light', jsonb_build_object(
            'status', v_traffic_status,
            'message', v_traffic_message
        ),
        'hero_number', v_total_sales,
        'money_breakdown', v_breakdown,
        'alerts', v_alerts,
        'reminder', jsonb_build_object('message', CASE WHEN v_total_sales = 0 THEN '¡Abre caja para empezar a vender!' ELSE 'Recuerda hacer el cierre de caja al final del turno.' END)
    );
END;
$$;


-- A5. get_smart_supply_report (replace partial auth with assert_store_access)
CREATE OR REPLACE FUNCTION get_smart_supply_report(p_store_id UUID)
RETURNS TABLE (
    product_id UUID,
    product_name TEXT,
    current_stock NUMERIC,
    velocity NUMERIC,
    doi NUMERIC,
    revenue_at_risk NUMERIC,
    status TEXT,
    suggestion TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_window_days INT := 30;
BEGIN
    -- SECURITY: Ownership check (replaces old partial admin_profiles check)
    PERFORM assert_store_access(p_store_id);

    RETURN QUERY
    WITH sales_stats AS (
        SELECT
            si.product_id,
            SUM(si.quantity) as total_sold,
            COUNT(DISTINCT DATE(si.created_at)) as days_sold
        FROM sale_items si
        JOIN sales s ON si.sale_id = s.id
        WHERE s.store_id = p_store_id
        AND s.created_at >= (NOW() - (v_window_days || ' days')::INTERVAL)
        GROUP BY si.product_id
    ),
    product_calc AS (
        SELECT
            p.id,
            p.name,
            p.current_stock,
            p.price,
            COALESCE(ss.total_sold, 0) as total_sold,
            COALESCE(ss.total_sold, 0) / NULLIF(v_window_days, 0) as velocity,
            COALESCE(sup.frequency_days, 7) as frequency_days,
            COALESCE(sup.lead_time_days, 1) as lead_time_days
        FROM products p
        LEFT JOIN suppliers sup ON p.supplier_id = sup.id
        LEFT JOIN sales_stats ss ON p.id = ss.product_id
        WHERE p.store_id = p_store_id
    )
    SELECT
        pc.id,
        pc.name,
        pc.current_stock,
        pc.velocity,
        CASE WHEN pc.velocity > 0 THEN pc.current_stock / pc.velocity ELSE 999 END as doi,
        CASE
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days
            THEN (pc.lead_time_days - (COALESCE(pc.current_stock, 0) / pc.velocity)) * pc.velocity * COALESCE(pc.price, 0)
            ELSE 0
        END as revenue_at_risk,
        CASE
            WHEN pc.velocity = 0 THEN 'UNKNOWN'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days THEN 'CRITICAL'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < (pc.lead_time_days + pc.frequency_days) THEN 'WARNING'
            ELSE 'OK'
        END::text as status,
        CASE
            WHEN pc.velocity = 0 THEN 'Recopilando datos...'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days
                THEN 'Pedir urgente: se agotará antes de la próxima entrega.'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < (pc.lead_time_days + pc.frequency_days)
                THEN 'Incluir en próximo pedido.'
            ELSE 'Stock suficiente por ahora.'
        END::text as suggestion
    FROM product_calc pc;
END;
$$;


-- A6. get_history_ventas
CREATE OR REPLACE FUNCTION get_history_ventas(
    p_store_id UUID,
    p_start_date DATE,
    p_end_date DATE,
    p_employee_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- SECURITY: Ownership check
    PERFORM assert_store_access(p_store_id);

    SELECT COALESCE(jsonb_agg(row_data ORDER BY created_at DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', s.id,
            'ticket_number', s.ticket_number,
            'total', s.total,
            'payment_method', s.payment_method,
            'employee_name', COALESCE(e.name, 'Administrador'),
            'employee_id', s.employee_id,
            'client_name', c.name,
            'items_count', (SELECT COUNT(*) FROM sale_items si WHERE si.sale_id = s.id),
            'is_voided', COALESCE(s.is_voided, false),
            'void_reason', s.void_reason,
            'created_at', s.created_at
        ) as row_data,
        s.created_at
        FROM sales s
        LEFT JOIN employees e ON e.id = s.employee_id
        LEFT JOIN clients c ON c.id = s.client_id
        WHERE s.store_id = p_store_id
          AND s.created_at >= p_start_date::timestamptz
          AND s.created_at < (p_end_date + 1)::timestamptz
          AND (p_employee_id IS NULL OR s.employee_id = p_employee_id)
        LIMIT 200
    ) sub;

    RETURN v_result;
END;
$$;


-- A7. get_history_compras
CREATE OR REPLACE FUNCTION get_history_compras(
    p_store_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- SECURITY: Ownership check
    PERFORM assert_store_access(p_store_id);

    SELECT COALESCE(jsonb_agg(row_data ORDER BY created_at DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', im.id,
            'product_name', p.name,
            'product_id', im.product_id,
            'quantity', im.quantity,
            'movement_type', im.movement_type,
            'reason', im.reason,
            'supplier_name', COALESCE(sup.name, NULL),
            'invoice_reference', im.invoice_reference,
            'payment_type', im.payment_type,
            'created_by_name', COALESCE(e.name, 'Administrador'),
            'created_at', im.created_at
        ) as row_data,
        im.created_at
        FROM inventory_movements im
        JOIN products p ON p.id = im.product_id
        LEFT JOIN suppliers sup ON sup.id = im.supplier_id
        LEFT JOIN employees e ON e.id = im.created_by
        WHERE p.store_id = p_store_id
          AND im.created_at >= p_start_date::timestamptz
          AND im.created_at < (p_end_date + 1)::timestamptz
          AND im.movement_type = 'entrada'
        LIMIT 200
    ) sub;

    RETURN v_result;
END;
$$;


-- A8. get_history_caja
CREATE OR REPLACE FUNCTION get_history_caja(
    p_store_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- SECURITY: Ownership check
    PERFORM assert_store_access(p_store_id);

    SELECT COALESCE(jsonb_agg(row_data ORDER BY opened_at DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', cs.id,
            'status', cs.status,
            'opening_balance', cs.opening_balance,
            'actual_balance', cs.actual_balance,
            'expected_balance', cs.expected_balance,
            'difference', cs.difference,
            'opened_by_name', COALESCE(eo.name, ap_open.id::text, 'Desconocido'),
            'closed_by_name', COALESCE(ec.name, ap_close.id::text, NULL),
            'opened_at', cs.opened_at,
            'closed_at', cs.closed_at,
            'total_movements', (SELECT COUNT(*) FROM cash_movements cm WHERE cm.session_id = cs.id),
            'total_income', (
                SELECT COALESCE(SUM(cm.amount), 0)
                FROM cash_movements cm
                WHERE cm.session_id = cs.id AND cm.movement_type = 'ingreso'
            ),
            'total_expenses', (
                SELECT COALESCE(SUM(cm.amount), 0)
                FROM cash_movements cm
                WHERE cm.session_id = cs.id AND cm.movement_type = 'gasto'
            )
        ) as row_data,
        cs.opened_at
        FROM cash_sessions cs
        LEFT JOIN employees eo ON eo.id = cs.opened_by
        LEFT JOIN employees ec ON ec.id = cs.closed_by
        LEFT JOIN admin_profiles ap_open ON ap_open.id = cs.opened_by
        LEFT JOIN admin_profiles ap_close ON ap_close.id = cs.closed_by
        WHERE cs.store_id = p_store_id
          AND cs.opened_at >= p_start_date::timestamptz
          AND cs.opened_at < (p_end_date + 1)::timestamptz
        LIMIT 100
    ) sub;

    RETURN v_result;
END;
$$;


-- ==============================================================================
-- GRUPO B: OPERACIONES (WRITE) — Añadir assert_store_access + search_path
-- ==============================================================================

-- B1. abrir_caja
CREATE OR REPLACE FUNCTION abrir_caja(
    p_store_id UUID,
    p_employee_id UUID,
    p_opening_balance NUMERIC
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_existing_session UUID;
    v_session_id UUID;
BEGIN
    -- SECURITY: Ownership check
    PERFORM assert_store_access(p_store_id);

    SELECT id INTO v_existing_session FROM public.cash_sessions WHERE store_id = p_store_id AND status = 'open';
    IF FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Ya existe una caja abierta', 'code', 'CASH_ALREADY_OPEN');
    END IF;

    INSERT INTO public.cash_sessions (store_id, opened_by, opening_balance)
    VALUES (p_store_id, p_employee_id, p_opening_balance)
    RETURNING id INTO v_session_id;

    RETURN json_build_object('success', true, 'session_id', v_session_id);
END;
$$;


-- B2. crear_empleado
CREATE OR REPLACE FUNCTION crear_empleado(
    p_store_id UUID,
    p_name TEXT,
    p_username TEXT,
    p_pin TEXT,
    p_permissions JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_new_id UUID;
BEGIN
    -- SECURITY: Ownership check
    PERFORM assert_store_access(p_store_id);

    -- Validar unicidad de alias
    IF EXISTS (SELECT 1 FROM public.employees WHERE alias = p_username) THEN
        RETURN jsonb_build_object('success', false, 'error', 'El alias ya existe');
    END IF;

    INSERT INTO public.employees (
        store_id,
        name,
        alias,
        pin_code,
        permissions,
        is_active
    ) VALUES (
        p_store_id,
        p_name,
        p_username,
        p_pin,
        p_permissions,
        true
    ) RETURNING id INTO v_new_id;

    RETURN jsonb_build_object('success', true, 'employee_id', v_new_id);
EXCEPTION WHEN unique_violation THEN
    RETURN jsonb_build_object('success', false, 'error', 'El alias ya existe');
WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Error interno del servidor');
END;
$$;


-- B3. procesar_venta (legacy — still used by offline sync)
CREATE OR REPLACE FUNCTION procesar_venta(
    p_store_id UUID,
    p_employee_id UUID,
    p_items JSONB,
    p_total NUMERIC,
    p_payment_method TEXT,
    p_amount_received NUMERIC DEFAULT NULL,
    p_client_id UUID DEFAULT NULL,
    p_local_id TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_sale_id UUID;
    v_ticket_number INTEGER;
    v_item JSONB;
    v_change DECIMAL;
BEGIN
    -- SECURITY: Ownership check
    PERFORM assert_store_access(p_store_id);

    IF jsonb_array_length(p_items) > 50 THEN
        RETURN json_build_object('success', false, 'error', 'Máximo 50 productos por venta', 'code', 'MAX_ITEMS_EXCEEDED');
    END IF;

    SELECT COALESCE(MAX(ticket_number), 0) + 1 INTO v_ticket_number FROM public.sales WHERE store_id = p_store_id;

    IF p_payment_method = 'efectivo' AND p_amount_received IS NOT NULL THEN
        v_change := p_amount_received - p_total;
    END IF;

    INSERT INTO public.sales (store_id, ticket_number, employee_id, client_id, total, payment_method, amount_received, change_given, local_id, sync_status)
    VALUES (p_store_id, v_ticket_number, p_employee_id, p_client_id, p_total, p_payment_method, p_amount_received, v_change, p_local_id, 'synced')
    RETURNING id INTO v_sale_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, subtotal)
        VALUES (v_sale_id, (v_item->>'product_id')::UUID, (v_item->>'quantity')::DECIMAL, (v_item->>'unit_price')::DECIMAL, (v_item->>'subtotal')::DECIMAL);

        INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by)
        VALUES ((v_item->>'product_id')::UUID, 'venta', (v_item->>'quantity')::DECIMAL, 'Venta #' || v_ticket_number, p_employee_id);
    END LOOP;

    RETURN json_build_object('success', true, 'sale_id', v_sale_id, 'ticket_number', v_ticket_number);

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', 'Error interno del servidor', 'code', 'SALE_PROCESSING_ERROR');
END;
$$;


-- ==============================================================================
-- GRUPO C: search_path ONLY (ya tienen su propia auth)
-- Estas funciones ya validan ownership por su cuenta.
-- Solo se agrega SET search_path = public donde falta.
-- ==============================================================================

-- C1. get_active_cash_session (ya usa get_current_store_id() para validar)
CREATE OR REPLACE FUNCTION get_active_cash_session(p_store_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_session RECORD;
    v_requester_store_id UUID;
BEGIN
    -- Existing security: uses get_current_store_id() to validate store membership
    v_requester_store_id := public.get_current_store_id();

    IF v_requester_store_id IS NULL OR v_requester_store_id != p_store_id THEN
        RETURN jsonb_build_object('isOpen', false, 'error', 'Unauthorized');
    END IF;

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


-- C2. rpc_procesar_venta_v2 (ya usa get_employee_id_from_session() + admin check)
CREATE OR REPLACE FUNCTION rpc_procesar_venta_v2(
    p_store_id UUID,
    p_client_id UUID,
    p_payment_method TEXT,
    p_amount_received NUMERIC,
    p_items JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_sale_id UUID;
    v_ticket_number INTEGER;
    v_total_calculated DECIMAL(12, 0) := 0;
    v_change DECIMAL(12, 0) := 0;
    v_item JSONB;
    v_product_id UUID;
    v_quantity DECIMAL;
    v_product_price DECIMAL;
    v_product_name TEXT;
    v_subtotal DECIMAL;
    v_client_balance DECIMAL;
    v_client_limit DECIMAL;
    v_employee_id UUID;

    -- Variables de Configuración
    v_pm_exists BOOLEAN;
    v_pm_allows_change BOOLEAN;
    v_pm_requires_ref BOOLEAN;
    v_pm_is_active BOOLEAN;
BEGIN
    -- SECURITY: Ownership check (reinforces existing auth)
    PERFORM assert_store_access(p_store_id);

    -- 0. VALIDAR MÉTODO DE PAGO
    SELECT is_active, allows_change, requires_reference
    INTO v_pm_is_active, v_pm_allows_change, v_pm_requires_ref
    FROM public.payment_methods
    WHERE code = p_payment_method;

    IF NOT FOUND AND p_payment_method = 'efectivo' THEN
        SELECT is_active, allows_change, requires_reference
        INTO v_pm_is_active, v_pm_allows_change, v_pm_requires_ref
        FROM public.payment_methods
        WHERE code = 'cash';
    END IF;

    IF v_pm_is_active IS NULL OR v_pm_is_active = FALSE THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Método de pago no válido o inactivo: ' || p_payment_method,
            'code', 'INVALID_PAYMENT_METHOD'
        );
    END IF;

    -- 1. AUTHENTICATION
    v_employee_id := public.get_employee_id_from_session();

    IF v_employee_id IS NULL THEN
        IF EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()) THEN
            v_employee_id := auth.uid();
        ELSE
            RETURN jsonb_build_object('success', false, 'error', 'Usuario no autorizado', 'code', 'UNAUTHORIZED');
        END IF;
    END IF;

    -- 2. CALCULAR TOTAL
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_quantity := (v_item->>'quantity')::DECIMAL;

        SELECT price, name INTO v_product_price, v_product_name
        FROM public.products
        WHERE id = v_product_id AND store_id = p_store_id;

        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'Producto no encontrado: ' || v_product_id);
        END IF;

        v_total_calculated := v_total_calculated + (v_product_price * v_quantity);
    END LOOP;

    -- 3. VALIDAR FIADO
    IF p_payment_method = 'fiado' THEN
        IF p_client_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Se requiere cliente para fiado');
        END IF;

        SELECT balance, credit_limit INTO v_client_balance, v_client_limit
        FROM public.clients
        WHERE id = p_client_id FOR UPDATE;

        IF NOT FOUND THEN
             RETURN jsonb_build_object('success', false, 'error', 'Cliente no encontrado');
        END IF;

        IF (v_client_balance + v_total_calculated) > v_client_limit THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Cupo excedido. Cupo: ' || v_client_limit || '. Saldo Nuevo: ' || (v_client_balance + v_total_calculated),
                'code', 'CREDIT_LIMIT_EXCEEDED'
            );
        END IF;
    END IF;

    -- 4. GENERAR TICKET & INSERTAR
    SELECT COALESCE(MAX(ticket_number), 0) + 1 INTO v_ticket_number
    FROM public.sales WHERE store_id = p_store_id;

    IF v_pm_allows_change THEN
        v_change := GREATEST(0, p_amount_received - v_total_calculated);
    ELSE
        v_change := 0;
    END IF;

    INSERT INTO public.sales (
        store_id, ticket_number, employee_id, client_id,
        total, payment_method, amount_received, change_given,
        sync_status
    ) VALUES (
        p_store_id, v_ticket_number, v_employee_id, p_client_id,
        v_total_calculated, p_payment_method, p_amount_received, v_change,
        'synced'
    ) RETURNING id INTO v_sale_id;

    -- 5. MOVIMIENTOS INVENTARIO
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_quantity := (v_item->>'quantity')::DECIMAL;
        SELECT price INTO v_product_price FROM public.products WHERE id = v_product_id;
        v_subtotal := v_quantity * v_product_price;

        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, subtotal)
        VALUES (v_sale_id, v_product_id, v_quantity, v_product_price, v_subtotal);

        INSERT INTO public.inventory_movements (
            product_id, movement_type, quantity, reason, created_by
        ) VALUES (
            v_product_id, 'venta', v_quantity, 'Venta #' || v_ticket_number, v_employee_id
        );
    END LOOP;

    -- 6. CAJA (Cash Drawer)
    IF v_pm_allows_change OR p_payment_method IN ('cash', 'efectivo') THEN
        DECLARE
            v_session_id UUID;
        BEGIN
            SELECT id INTO v_session_id
            FROM public.cash_sessions
            WHERE store_id = p_store_id AND status = 'open'
            ORDER BY opened_at DESC LIMIT 1;

            IF v_session_id IS NOT NULL THEN
                INSERT INTO public.cash_movements (
                    session_id, movement_type, amount, description, sale_id
                ) VALUES (
                    v_session_id, 'ingreso', v_total_calculated, 'Venta #' || v_ticket_number, v_sale_id
                );
            END IF;
        END;
    END IF;

    -- 7. LEDGER CLIENTE
    IF p_payment_method = 'fiado' THEN
        UPDATE public.clients SET balance = balance + v_total_calculated WHERE id = p_client_id;

        INSERT INTO public.client_ledger (
            client_id, store_id, amount, previous_balance, reference_id,
            transaction_type, created_by
        ) VALUES (
            p_client_id, p_store_id, v_total_calculated, v_client_balance,
            v_sale_id, 'venta_fiado', v_employee_id
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'sale_id', v_sale_id,
        'ticket_number', v_ticket_number,
        'total', v_total_calculated,
        'change', v_change
    );

EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'error', 'Error interno del servidor');
END;
$$;


-- C3. rpc_force_sale (ya tiene role check + search_path — reforzar con assert_store_access)
CREATE OR REPLACE FUNCTION rpc_force_sale(
    p_store_id UUID,
    p_client_id UUID,
    p_payment_method TEXT,
    p_items JSONB,
    p_justification TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role TEXT;
    v_item JSONB;
    v_product_id UUID;
    v_qty NUMERIC;
    v_current_stock NUMERIC;
    v_deficit NUMERIC;
    v_sale_result JSONB;
    v_sale_id UUID;
    v_affected_count INT := 0;
BEGIN
    -- SECURITY: Ownership check (reinforces existing role check)
    PERFORM assert_store_access(p_store_id);

    -- 0. Validate Role (Strict)
    SELECT role INTO v_role FROM public.admin_profiles WHERE id = auth.uid();

    IF v_role IS NULL OR v_role NOT IN ('owner', 'manager') THEN
        RAISE EXCEPTION 'Access Denied: User role % not allowed.', v_role;
    END IF;

    -- Validate Justification Length
    IF length(p_justification) < 10 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Justificación muy corta (min 10 caracteres).');
    END IF;

    -- 1. Inventory Correction (Pre-flight)
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_qty := (v_item->>'quantity')::NUMERIC;

        SELECT current_stock INTO v_current_stock
        FROM public.products
        WHERE id = v_product_id;

        v_deficit := v_qty - COALESCE(v_current_stock, 0);

        IF v_deficit > 0 THEN
            INSERT INTO public.inventory_movements (
                product_id,
                movement_type,
                quantity,
                reason,
                created_by
            ) VALUES (
                v_product_id,
                'CORRECCION_SISTEMA',
                v_deficit,
                'AUTO-CORRECCION (EXCEPCION ADMIN): ' || p_justification,
                auth.uid()
            );
            v_affected_count := v_affected_count + 1;
        END IF;
    END LOOP;

    -- 2. Process Sale (Call V2)
    SELECT public.rpc_procesar_venta_v2(
        p_store_id,
        p_client_id,
        p_payment_method,
        0,
        p_items
    ) INTO v_sale_result;

    IF (v_sale_result->>'success')::boolean IS NOT TRUE THEN
        RAISE EXCEPTION 'Venta falló tras ajuste: %', v_sale_result->>'error';
    END IF;

    v_sale_id := (v_sale_result->>'sale_id')::UUID;

    -- 3. Audit Log
    INSERT INTO public.audit_logs (
        store_id,
        event_type,
        severity,
        actor_id,
        actor_role,
        metadata
    ) VALUES (
        p_store_id,
        'FORCE_SALE',
        'warning',
        NULL,
        'admin',
        jsonb_build_object(
            'admin_user_id', auth.uid(),
            'admin_role_original', v_role,
            'sale_id', v_sale_id,
            'reason', p_justification,
            'items_adjusted', v_affected_count,
            'original_items', p_items
        )
    );

    RETURN jsonb_build_object('success', true, 'sale_id', v_sale_id, 'adjusted_items', v_affected_count);
END;
$$;


-- ==============================================================================
-- VERIFICATION COMMENTS
-- ==============================================================================
-- All 14 SECURITY DEFINER RPCs with p_store_id now have:
--   ✅ assert_store_access(p_store_id) or equivalent ownership check
--   ✅ SET search_path = public
--   ✅ Generic error messages (no SQLERRM exposure)
-- ==============================================================================

-- ==============================================================================
-- MIGRATION: RESTORE ANALYTICS AND CONFIGURATION
-- Restauración de todas las RPCs de reportes y tablas de configuración.
-- ==============================================================================

-- 1. PAYMENT METHODS (Tabla Maestra)
CREATE TABLE IF NOT EXISTS public.payment_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,          -- 'cash', 'nequi', 'fiado'
    name TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    requires_reference BOOLEAN DEFAULT false, -- UI pide comprobante
    allows_change BOOLEAN DEFAULT false,      -- UI calcula devuelta
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: Public Read (Authenticated), Admin Write
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "read_active_methods" ON public.payment_methods;
CREATE POLICY "read_active_methods" ON public.payment_methods 
    FOR SELECT USING (true); -- Authenticated users can read valid methods

DROP POLICY IF EXISTS "admin_manage_methods" ON public.payment_methods;
CREATE POLICY "admin_manage_methods" ON public.payment_methods 
    FOR ALL USING (
        EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()) OR
        auth.jwt() ->> 'role' = 'service_role'
    );

-- SEED DATA (Backward Compatibility)
INSERT INTO public.payment_methods (code, name, allows_change, requires_reference, sort_order)
VALUES 
    ('cash', 'Efectivo', true, false, 10),
    ('nequi', 'Nequi / Daviplata', false, true, 20),
    ('fiado', 'Fiado / Crédito', false, false, 30),
    ('card', 'Tarjeta Débito/Crédito', false, true, 40)
ON CONFLICT (code) DO NOTHING;


-- 2. TRANSACTION TYPES (Tabla Maestra)
CREATE TABLE IF NOT EXISTS public.transaction_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,          -- 'sale', 'expense', 'income'
    description TEXT NOT NULL,
    impact_stock INTEGER DEFAULT 0,     -- -1 (Resta), 0 (Neutro), 1 (Suma)
    impact_cash INTEGER DEFAULT 0,      -- -1 (Salida), 0 (Neutro), 1 (Entrada)
    is_system BOOLEAN DEFAULT false     -- Si true, no se puede borrar
);

-- RLS: Public Read
ALTER TABLE public.transaction_types ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "read_tx_types" ON public.transaction_types;
CREATE POLICY "read_tx_types" ON public.transaction_types FOR SELECT USING (true);

-- SEED DATA
INSERT INTO public.transaction_types (code, description, impact_stock, impact_cash, is_system)
VALUES
    ('sale', 'Venta Regular', -1, 1, true),
    ('expense', 'Gasto Operativo', 0, -1, true),
    ('income', 'Ingreso Extra', 0, 1, true),
    ('void', 'Anulación Venta', 1, -1, true),
    ('adjustment_in', 'Ajuste Inventario (+)', 1, 0, true),
    ('adjustment_out', 'Ajuste Inventario (-)', -1, 0, true)
ON CONFLICT (code) DO NOTHING;


-- 3. RPC: GET SYSTEM CONFIG
CREATE OR REPLACE FUNCTION public.rpc_get_system_config()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN jsonb_build_object(
        'payment_methods', (
            SELECT jsonb_agg(pm) FROM (
                SELECT code, name, requires_reference, allows_change, is_active 
                FROM public.payment_methods 
                WHERE is_active = true 
                ORDER BY sort_order
            ) pm
        ),
        'transaction_types', (
            SELECT jsonb_agg(tt) FROM (
                SELECT code, description, impact_stock, impact_cash 
                FROM public.transaction_types
            ) tt
        ),
        'server_timestamp', now()
    );
END;
$$;


-- 4. RPCs de Reportes de Seguridad y Tienda

-- helper as well to make sure assert_store_access exists correctly
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

-- 5. RPC get_financial_summary
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
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Error interno del servidor');
END;
$$;


-- 6. RPC get_top_selling_products
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


-- 7. RPC get_stagnant_products
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


-- 8. RPC get_daily_summary
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
    PERFORM assert_store_access(p_store_id);

    v_start_date := p_date::TIMESTAMPTZ;
    v_end_date := v_start_date + INTERVAL '1 day';

    SELECT COALESCE(SUM(total), 0) INTO v_total_sales
    FROM sales
    WHERE store_id = p_store_id AND created_at >= v_start_date AND created_at < v_end_date AND is_voided = FALSE;

    SELECT jsonb_object_agg(method_group, amount) INTO v_breakdown
    FROM (
        SELECT
            CASE WHEN payment_method IN ('nequi', 'daviplata') THEN 'transfer' WHEN payment_method = 'fiado' THEN 'credit' ELSE 'cash' END as method_group,
            SUM(total) as amount
        FROM sales
        WHERE store_id = p_store_id AND created_at >= v_start_date AND created_at < v_end_date AND is_voided = FALSE
        GROUP BY 1
    ) sub;

    v_breakdown := jsonb_build_object('cash', COALESCE((v_breakdown->>'cash')::NUMERIC, 0), 'transfer', COALESCE((v_breakdown->>'transfer')::NUMERIC, 0), 'credit', COALESCE((v_breakdown->>'credit')::NUMERIC, 0));

    SELECT COALESCE(AVG(daily_total), 0) INTO v_avg_sales_7d
    FROM (
        SELECT DATE(created_at) as day, SUM(total) as daily_total
        FROM sales
        WHERE store_id = p_store_id AND created_at >= (v_start_date - INTERVAL '7 days') AND created_at < v_start_date AND is_voided = FALSE
        GROUP BY 1
    ) past_sales;

    IF v_avg_sales_7d = 0 THEN v_traffic_status := 'gray'; v_traffic_message := 'Recopilando datos históricos...';
    ELSIF v_total_sales >= (v_avg_sales_7d * 1.05) THEN v_traffic_status := 'green'; v_traffic_message := '🚀 ¡Vas un ' || ROUND(((v_total_sales - v_avg_sales_7d) / v_avg_sales_7d * 100), 0) || '% arriba de tu promedio!';
    ELSIF v_total_sales <= (v_avg_sales_7d * 0.95) THEN v_traffic_status := 'red'; v_traffic_message := '🔻 Estás un ' || ROUND(((v_avg_sales_7d - v_total_sales) / v_avg_sales_7d * 100), 0) || '% abajo de tu promedio.';
    ELSE v_traffic_status := 'green'; v_traffic_message := '👍 Ventas estables respecto a tu semana.'; END IF;

    SELECT jsonb_agg(jsonb_build_object('type', 'stock_critical','message', CASE WHEN current_stock <= 0 THEN '❌ Agotado: ' || name ELSE '⚠️ Bajo stock: ' || name END, 'target_id', id, 'stock', current_stock))
    INTO v_alerts FROM products WHERE store_id = p_store_id AND current_stock <= min_stock LIMIT 5;

    IF v_alerts IS NULL THEN v_alerts := '[]'::JSONB; END IF;

    RETURN jsonb_build_object('traffic_light', jsonb_build_object('status', v_traffic_status, 'message', v_traffic_message), 'hero_number', v_total_sales, 'money_breakdown', v_breakdown, 'alerts', v_alerts, 'reminder', jsonb_build_object('message', CASE WHEN v_total_sales = 0 THEN '¡Abre caja para empezar a vender!' ELSE 'Recuerda hacer el cierre de caja al final del turno.' END));
END;
$$;


-- 9. RPC get_smart_supply_report
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
    PERFORM assert_store_access(p_store_id);
    RETURN QUERY
    WITH sales_stats AS (
        SELECT si.product_id, SUM(si.quantity) as total_sold, COUNT(DISTINCT DATE(si.created_at)) as days_sold
        FROM sale_items si JOIN sales s ON si.sale_id = s.id
        WHERE s.store_id = p_store_id AND s.created_at >= (NOW() - (v_window_days || ' days')::INTERVAL)
        GROUP BY si.product_id
    ),
    product_calc AS (
        SELECT p.id, p.name, p.current_stock, p.price, COALESCE(ss.total_sold, 0) as total_sold, COALESCE(ss.total_sold, 0) / NULLIF(v_window_days, 0) as velocity, COALESCE(sup.frequency_days, 7) as frequency_days, COALESCE(sup.lead_time_days, 1) as lead_time_days
        FROM products p LEFT JOIN suppliers sup ON p.supplier_id = sup.id LEFT JOIN sales_stats ss ON p.id = ss.product_id
        WHERE p.store_id = p_store_id
    )
    SELECT pc.id, pc.name, pc.current_stock, pc.velocity, CASE WHEN pc.velocity > 0 THEN pc.current_stock / pc.velocity ELSE 999 END as doi,
    CASE WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days THEN (pc.lead_time_days - (COALESCE(pc.current_stock, 0) / pc.velocity)) * pc.velocity * COALESCE(pc.price, 0) ELSE 0 END as revenue_at_risk,
    CASE WHEN pc.velocity = 0 THEN 'UNKNOWN' WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days THEN 'CRITICAL' WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < (pc.lead_time_days + pc.frequency_days) THEN 'WARNING' ELSE 'OK' END::text as status,
    CASE WHEN pc.velocity = 0 THEN 'Recopilando datos...' WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days THEN 'Pedir urgente: se agotará antes de la próxima entrega.' WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < (pc.lead_time_days + pc.frequency_days) THEN 'Incluir en próximo pedido.' ELSE 'Stock suficiente por ahora.' END::text as suggestion
    FROM product_calc pc;
END;
$$;


-- 10. RPC get_history_ventas
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
    PERFORM assert_store_access(p_store_id);
    SELECT COALESCE(jsonb_agg(row_data ORDER BY created_at DESC), '[]'::jsonb) INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', s.id, 'ticket_number', s.ticket_number, 'total', s.total, 'payment_method', s.payment_method,
            'employee_name', COALESCE(e.name, 'Administrador'), 'employee_id', s.employee_id, 'client_name', c.name,
            'items_count', (SELECT COUNT(*) FROM sale_items si WHERE si.sale_id = s.id),
            'is_voided', COALESCE(s.is_voided, false), 'void_reason', s.void_reason, 'created_at', s.created_at
        ) as row_data, s.created_at
        FROM sales s LEFT JOIN employees e ON e.id = s.employee_id LEFT JOIN clients c ON c.id = s.client_id
        WHERE s.store_id = p_store_id AND s.created_at >= p_start_date::timestamptz AND s.created_at < (p_end_date + 1)::timestamptz AND (p_employee_id IS NULL OR s.employee_id = p_employee_id)
        LIMIT 200
    ) sub;
    RETURN v_result;
END;
$$;


-- 11. RPC get_history_compras
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


-- 12. RPC get_history_caja
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


-- 13. PERFORMANCE INDEXES 
CREATE INDEX IF NOT EXISTS idx_sales_analytics ON public.sales(store_id, created_at) WHERE is_voided = false;
CREATE INDEX IF NOT EXISTS idx_inventory_movements_perf ON public.inventory_movements(product_id, movement_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clients_debtors ON public.clients(store_id, balance) WHERE balance > 0 AND is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_sale_items_product ON public.sale_items(product_id);


-- 14. RPC get_top_products_by_units
CREATE OR REPLACE FUNCTION get_top_products_by_units(
    p_store_id UUID,
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    product_id UUID,
    product_name TEXT,
    units_sold NUMERIC,
    dias_rotacion INTEGER,
    stock_actual NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_start_ts TIMESTAMPTZ;
    v_end_ts TIMESTAMPTZ;
BEGIN
    v_start_ts := p_start_date::TIMESTAMPTZ;
    v_end_ts := (p_end_date + INTERVAL '1 day')::TIMESTAMPTZ;

    RETURN QUERY
    WITH ventas_agrupadas AS (
        SELECT si.product_id, SUM(si.quantity) as total_units, MAX(s.created_at) as last_sale_at
        FROM public.sale_items si JOIN public.sales s ON si.sale_id = s.id
        WHERE s.store_id = p_store_id AND s.created_at >= v_start_ts AND s.created_at < v_end_ts AND s.is_voided = FALSE
        GROUP BY si.product_id ORDER BY total_units DESC LIMIT p_limit
    )
    SELECT p.id AS product_id, p.name AS product_name, va.total_units AS units_sold,
        (SELECT ROUND(EXTRACT(EPOCH FROM (va.last_sale_at - im.created_at)) / 86400, 0)::INTEGER
         FROM public.inventory_movements im WHERE im.product_id = p.id AND im.movement_type = 'entrada' ORDER BY im.created_at DESC LIMIT 1) AS dias_rotacion,
        p.current_stock AS stock_actual
    FROM ventas_agrupadas va JOIN public.products p ON va.product_id = p.id ORDER BY va.total_units DESC;
END;
$$;


-- 15. RPC get_inventory_health
CREATE OR REPLACE FUNCTION get_inventory_health(p_store_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_valor_total NUMERIC DEFAULT 0; v_cogs_promedio NUMERIC DEFAULT 0; v_dias_inventario INTEGER DEFAULT NULL; v_estado TEXT;
    v_rapida_count INTEGER DEFAULT 0; v_rapida_valor NUMERIC DEFAULT 0; v_normal_count INTEGER DEFAULT 0; v_normal_valor NUMERIC DEFAULT 0; v_lenta_count INTEGER DEFAULT 0; v_lenta_valor NUMERIC DEFAULT 0;
    v_total_count INTEGER DEFAULT 0;
BEGIN
    SELECT COALESCE(SUM(current_stock * cost_price), 0), COUNT(id) INTO v_valor_total, v_total_count FROM public.products WHERE store_id = p_store_id AND current_stock > 0;
    SELECT COALESCE(AVG(daily_cogs), 0) INTO v_cogs_promedio FROM (SELECT DATE(s.created_at) as day, SUM(si.unit_cost * si.quantity) as daily_cogs FROM public.sales s JOIN public.sale_items si ON si.sale_id = s.id WHERE s.store_id = p_store_id AND s.created_at >= CURRENT_DATE - INTERVAL '30 days' AND s.is_voided = FALSE GROUP BY DATE(s.created_at)) daily_stats;
    v_dias_inventario := ROUND(v_valor_total / NULLIF(v_cogs_promedio, 0), 0)::INTEGER;

    IF v_dias_inventario IS NULL THEN v_estado := 'desconocido'; ELSIF v_dias_inventario < 7 THEN v_estado := 'riesgo'; ELSIF v_dias_inventario <= 15 THEN v_estado := 'optimo'; ELSIF v_dias_inventario <= 30 THEN v_estado := 'saludable'; ELSE v_estado := 'sobre_inventario'; END IF;

    WITH product_last_sales AS (
         SELECT p.id, (p.current_stock * p.cost_price) as val, EXTRACT(DAY FROM (CURRENT_TIMESTAMP - COALESCE(MAX(s.created_at), p.created_at))) as days_since_sale
         FROM public.products p LEFT JOIN public.sale_items si ON si.product_id = p.id LEFT JOIN public.sales s ON si.sale_id = s.id AND s.is_voided = FALSE
         WHERE p.store_id = p_store_id AND p.current_stock > 0
         GROUP BY p.id, p.current_stock, p.cost_price, p.created_at
    )
    SELECT COUNT(CASE WHEN days_since_sale < 7 THEN 1 END), COALESCE(SUM(CASE WHEN days_since_sale < 7 THEN val ELSE 0 END), 0), COUNT(CASE WHEN days_since_sale >= 7 AND days_since_sale <= 30 THEN 1 END), COALESCE(SUM(CASE WHEN days_since_sale >= 7 AND days_since_sale <= 30 THEN val ELSE 0 END), 0), COUNT(CASE WHEN days_since_sale > 30 THEN 1 END), COALESCE(SUM(CASE WHEN days_since_sale > 30 THEN val ELSE 0 END), 0)
    INTO v_rapida_count, v_rapida_valor, v_normal_count, v_normal_valor, v_lenta_count, v_lenta_valor FROM product_last_sales;

    RETURN jsonb_build_object('valor_total', v_valor_total, 'dias_inventario', v_dias_inventario, 'estado', v_estado, 'distribucion_rotacion', jsonb_build_object('rapida', jsonb_build_object('count', v_rapida_count, 'valor', v_rapida_valor, 'porcentaje', CASE v_valor_total WHEN 0 THEN 0 ELSE ROUND((v_rapida_valor / v_valor_total) * 100, 1) END), 'normal', jsonb_build_object('count', v_normal_count, 'valor', v_normal_valor, 'porcentaje', CASE v_valor_total WHEN 0 THEN 0 ELSE ROUND((v_normal_valor / v_valor_total) * 100, 1) END), 'lenta', jsonb_build_object('count', v_lenta_count, 'valor', v_lenta_valor, 'porcentaje', CASE v_valor_total WHEN 0 THEN 0 ELSE ROUND((v_lenta_valor / v_valor_total) * 100, 1) END)));
END;
$$;


-- 16. RPC get_client_ledger_summary
CREATE OR REPLACE FUNCTION get_client_ledger_summary(p_store_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_cartera_total NUMERIC DEFAULT 0; v_cartera_vencida NUMERIC DEFAULT 0; v_clientes_con_deuda INTEGER DEFAULT 0; v_clientes_morosos INTEGER DEFAULT 0; v_top_deudores JSONB;
BEGIN
    SELECT COALESCE(SUM(balance), 0), COALESCE(SUM(CASE WHEN updated_at < CURRENT_DATE - INTERVAL '30 days' THEN balance ELSE 0 END), 0), COUNT(id), COUNT(CASE WHEN updated_at < CURRENT_DATE - INTERVAL '30 days' THEN 1 END)
    INTO v_cartera_total, v_cartera_vencida, v_clientes_con_deuda, v_clientes_morosos FROM public.clients WHERE store_id = p_store_id AND balance > 0 AND (is_deleted = false OR is_deleted IS NULL);

    SELECT COALESCE(jsonb_agg(jsonb_build_object('client_id', id, 'client_name', name, 'balance', balance, 'dias_sin_pagar', EXTRACT(DAY FROM (CURRENT_TIMESTAMP - updated_at))::INTEGER, 'ultima_compra', DATE(updated_at))), '[]'::jsonb)
    INTO v_top_deudores FROM (SELECT id, name, balance, updated_at FROM public.clients WHERE store_id = p_store_id AND balance > 0 AND (is_deleted = false OR is_deleted IS NULL) ORDER BY balance DESC LIMIT 5) top_clients;

    RETURN jsonb_build_object('cartera_total', v_cartera_total, 'cartera_vencida', v_cartera_vencida, 'clientes_con_deuda', v_clientes_con_deuda, 'clientes_morosos', v_clientes_morosos, 'top_deudores', v_top_deudores);
END;
$$;

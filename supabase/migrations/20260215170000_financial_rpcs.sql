-- ==============================================================================
-- MIGRATION: PHASE 2 - FINANCIAL INTELLIGENCE RPCs
-- Date: 2026-02-15
-- Ref: FRD_Reportes_Historiales_v1.0 (Sección 6.2)
-- Description: Create 3 RPCs for financial dashboard intelligence
-- ==============================================================================

-- ==============================================================================
-- RPC #1: get_financial_summary
-- Purpose: Dashboard Ejecutivo - Ventas, Costos, Ganancia Neta, Margen
-- ==============================================================================
CREATE OR REPLACE FUNCTION get_financial_summary(
    p_store_id UUID,
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
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
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- ==============================================================================
-- RPC #2: get_top_selling_products
-- Purpose: Ranking de productos por unidades vendidas con ganancia
-- ==============================================================================
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
AS $$
DECLARE
    v_start_ts TIMESTAMPTZ;
    v_end_ts TIMESTAMPTZ;
BEGIN
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


-- ==============================================================================
-- RPC #3: get_stagnant_products
-- Purpose: Identificar productos sin ventas en X días (Capital inmovilizado)
-- ==============================================================================
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
AS $$
BEGIN
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

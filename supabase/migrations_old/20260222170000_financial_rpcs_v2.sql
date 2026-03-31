-- ==============================================================================
-- MIGRATION: PHASE 3 - FINANCIAL INTELLIGENCE RPCs (Reportes v2.0)
-- Date: 2026-02-22
-- Ref: FRD_Modulo_Reportes_v2.0 / qa_report.md
-- Description: Create 3 RPCs for financial dashboard limits and performance indexes
-- ==============================================================================

-- ==============================================================================
-- 1. PERFORMANCE INDEXES (QA Requisites)
-- ==============================================================================
-- 1.1 Analytics Index on Sales
CREATE INDEX IF NOT EXISTS idx_sales_analytics 
    ON public.sales(store_id, created_at) 
    WHERE is_voided = false;

-- 1.2 Inventory Movements Index for Lateral Join Rotations
CREATE INDEX IF NOT EXISTS idx_inventory_movements_perf 
    ON public.inventory_movements(product_id, movement_type, created_at DESC);

-- 1.3 Partial Index for Client Debtors
CREATE INDEX IF NOT EXISTS idx_clients_debtors 
    ON public.clients(store_id, balance) 
    WHERE balance > 0 AND is_deleted = false;

-- 1.4 Sales Items Product Index
CREATE INDEX IF NOT EXISTS idx_sale_items_product 
    ON public.sale_items(product_id);


-- ==============================================================================
-- RPC #3: get_top_products_by_units (Rotación y Ventas por Unidad)
-- Purpose: Ranking de productos por unidades vendidas + días de rotación 
-- ==============================================================================
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
        SELECT 
            si.product_id,
            SUM(si.quantity) as total_units,
            MAX(s.created_at) as last_sale_at
        FROM public.sale_items si
        JOIN public.sales s ON si.sale_id = s.id
        WHERE s.store_id = p_store_id
          AND s.created_at >= v_start_ts
          AND s.created_at < v_end_ts
          AND s.is_voided = FALSE
        GROUP BY si.product_id
        ORDER BY total_units DESC
        LIMIT p_limit
    )
    SELECT
        p.id AS product_id,
        p.name AS product_name,
        va.total_units AS units_sold,
        -- Mitigación QA: Lateral Join / Subquery con Limit 1 en lugar de Max() group by
        (
            SELECT ROUND(EXTRACT(EPOCH FROM (va.last_sale_at - im.created_at)) / 86400, 0)::INTEGER
            FROM public.inventory_movements im
            WHERE im.product_id = p.id
              AND im.movement_type = 'entrada'
            ORDER BY im.created_at DESC
            LIMIT 1
        ) AS dias_rotacion,
        p.current_stock AS stock_actual
    FROM ventas_agrupadas va
    JOIN public.products p ON va.product_id = p.id
    ORDER BY va.total_units DESC;
END;
$$;


-- ==============================================================================
-- RPC #5: get_inventory_health
-- Purpose: Métricas de salud del inventario (días para agotar, distribución)
-- ==============================================================================
CREATE OR REPLACE FUNCTION get_inventory_health(
    p_store_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_valor_total NUMERIC DEFAULT 0;
    v_cogs_promedio NUMERIC DEFAULT 0;
    v_dias_inventario INTEGER DEFAULT NULL;
    v_estado TEXT;
    
    v_rapida_count INTEGER DEFAULT 0;
    v_rapida_valor NUMERIC DEFAULT 0;
    v_normal_count INTEGER DEFAULT 0;
    v_normal_valor NUMERIC DEFAULT 0;
    v_lenta_count INTEGER DEFAULT 0;
    v_lenta_valor NUMERIC DEFAULT 0;
    
    v_total_count INTEGER DEFAULT 0;
BEGIN
    -- 1. Valor total del inventario actual
    SELECT COALESCE(SUM(current_stock * cost_price), 0), COUNT(id)
    INTO v_valor_total, v_total_count
    FROM public.products
    WHERE store_id = p_store_id
      AND current_stock > 0;

    -- 2. COGS (Costo de Mercancía Vendida) promedio diario (últimos 30 días)
    SELECT COALESCE(AVG(daily_cogs), 0)
    INTO v_cogs_promedio
    FROM (
        SELECT DATE(s.created_at) as day, 
               SUM(si.unit_cost * si.quantity) as daily_cogs
        FROM public.sales s
        JOIN public.sale_items si ON si.sale_id = s.id
        WHERE s.store_id = p_store_id
          AND s.created_at >= CURRENT_DATE - INTERVAL '30 days'
          AND s.is_voided = FALSE
        GROUP BY DATE(s.created_at)
    ) daily_stats;

    -- 3. Calcular Días de Inventario (Mitigación QA: NULLIF)
    v_dias_inventario := ROUND(v_valor_total / NULLIF(v_cogs_promedio, 0), 0)::INTEGER;

    -- 4. Asignar Estado de Salud Global
    IF v_dias_inventario IS NULL THEN
        v_estado := 'desconocido'; -- No hay data de ventas para predecir
    ELSIF v_dias_inventario < 7 THEN
        v_estado := 'riesgo';
    ELSIF v_dias_inventario <= 15 THEN
        v_estado := 'optimo';
    ELSIF v_dias_inventario <= 30 THEN
        v_estado := 'saludable';
    ELSE
        v_estado := 'sobre_inventario';
    END IF;

    -- 5. Calcular Distribución de Rotación 
    -- Para hacer esto de manera eficiente sin timeouts, 
    -- determinamos la "rotación" basada en días sin vender para simplificar el cálculo iterativo
    -- Rápida (última venta < 7 días y vendió más del 20% de stock) ... es muy pesado on-the-fly a nivel unitario.
    -- Como proxy eficiente usamos los días desde la última venta:
    WITH product_last_sales AS (
         SELECT 
             p.id, 
             (p.current_stock * p.cost_price) as val,
             EXTRACT(DAY FROM (CURRENT_TIMESTAMP - COALESCE(MAX(s.created_at), p.created_at))) as days_since_sale
         FROM public.products p
         LEFT JOIN public.sale_items si ON si.product_id = p.id
         LEFT JOIN public.sales s ON si.sale_id = s.id AND s.is_voided = FALSE
         WHERE p.store_id = p_store_id AND p.current_stock > 0
         GROUP BY p.id, p.current_stock, p.cost_price, p.created_at
    )
    SELECT 
        COUNT(CASE WHEN days_since_sale < 7 THEN 1 END),
        COALESCE(SUM(CASE WHEN days_since_sale < 7 THEN val ELSE 0 END), 0),
        COUNT(CASE WHEN days_since_sale >= 7 AND days_since_sale <= 30 THEN 1 END),
        COALESCE(SUM(CASE WHEN days_since_sale >= 7 AND days_since_sale <= 30 THEN val ELSE 0 END), 0),
        COUNT(CASE WHEN days_since_sale > 30 THEN 1 END),
        COALESCE(SUM(CASE WHEN days_since_sale > 30 THEN val ELSE 0 END), 0)
    INTO 
        v_rapida_count, v_rapida_valor, 
        v_normal_count, v_normal_valor, 
        v_lenta_count, v_lenta_valor
    FROM product_last_sales;

    -- 6. Construir y Retornar JSON
    RETURN jsonb_build_object(
        'valor_total', v_valor_total,
        'dias_inventario', v_dias_inventario,
        'estado', v_estado,
        'distribucion_rotacion', jsonb_build_object(
            'rapida', jsonb_build_object(
                'count', v_rapida_count,
                'valor', v_rapida_valor,
                'porcentaje', CASE v_valor_total WHEN 0 THEN 0 ELSE ROUND((v_rapida_valor / v_valor_total) * 100, 1) END
            ),
            'normal', jsonb_build_object(
                'count', v_normal_count,
                'valor', v_normal_valor,
                'porcentaje', CASE v_valor_total WHEN 0 THEN 0 ELSE ROUND((v_normal_valor / v_valor_total) * 100, 1) END
            ),
            'lenta', jsonb_build_object(
                'count', v_lenta_count,
                'valor', v_lenta_valor,
                'porcentaje', CASE v_valor_total WHEN 0 THEN 0 ELSE ROUND((v_lenta_valor / v_valor_total) * 100, 1) END
            )
        )
    );
END;
$$;


-- ==============================================================================
-- RPC #6: get_client_ledger_summary
-- Purpose: Resumen general de la mora por clientes ("Fiado")
-- ==============================================================================
CREATE OR REPLACE FUNCTION get_client_ledger_summary(
    p_store_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_cartera_total NUMERIC DEFAULT 0;
    v_cartera_vencida NUMERIC DEFAULT 0;
    v_clientes_con_deuda INTEGER DEFAULT 0;
    v_clientes_morosos INTEGER DEFAULT 0;
    v_top_deudores JSONB;
BEGIN
    -- Obtenemos totales globales (utiliza el idx_clients_debtors)
    SELECT 
        COALESCE(SUM(balance), 0),
        COALESCE(SUM(CASE WHEN updated_at < CURRENT_DATE - INTERVAL '30 days' THEN balance ELSE 0 END), 0),
        COUNT(id),
        COUNT(CASE WHEN updated_at < CURRENT_DATE - INTERVAL '30 days' THEN 1 END)
    INTO 
        v_cartera_total, v_cartera_vencida, v_clientes_con_deuda, v_clientes_morosos
    FROM public.clients
    WHERE store_id = p_store_id AND balance > 0 AND (is_deleted = false OR is_deleted IS NULL);

    -- Obtenemos el Top 5
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
        'client_id', id,
        'client_name', name,
        'balance', balance,
        'dias_sin_pagar', EXTRACT(DAY FROM (CURRENT_TIMESTAMP - updated_at))::INTEGER,
        'ultima_compra', DATE(updated_at)
    )), '[]'::jsonb)
    INTO v_top_deudores
    FROM (
        SELECT id, name, balance, updated_at
        FROM public.clients
        WHERE store_id = p_store_id AND balance > 0 AND (is_deleted = false OR is_deleted IS NULL)
        ORDER BY balance DESC
        LIMIT 5
    ) top_clients;

    RETURN jsonb_build_object(
        'cartera_total', v_cartera_total,
        'cartera_vencida', v_cartera_vencida,
        'clientes_con_deuda', v_clientes_con_deuda,
        'clientes_morosos', v_clientes_morosos,
        'top_deudores', v_top_deudores
    );
END;
$$;

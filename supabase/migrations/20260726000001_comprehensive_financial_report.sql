-- Migration: Comprehensive Financial Report RPC
-- Date: 2026-07-26
-- FRD-018 v1.0 — Motor Financiero Backend (Fase 1: P&L Real)

CREATE OR REPLACE FUNCTION rpc_get_comprehensive_financial_report(
    p_store_id   UUID,
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date   DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
    v_start_ts          TIMESTAMPTZ;
    v_end_ts            TIMESTAMPTZ;
    v_revenue           NUMERIC DEFAULT 0;
    v_cogs              NUMERIC DEFAULT 0;
    v_gross_profit      NUMERIC DEFAULT 0;
    v_gross_margin      NUMERIC DEFAULT 0;
    v_op_expenses       NUMERIC DEFAULT 0;
    v_net_profit        NUMERIC DEFAULT 0;
    v_inventory_value   NUMERIC DEFAULT 0;
    v_payment_breakdown JSONB;
    v_fiado_pendiente   NUMERIC DEFAULT 0;
    v_avg_sales_7d      NUMERIC DEFAULT 0;
    v_traffic_status    TEXT;
    v_traffic_message   TEXT;
BEGIN
    -- Validar acceso al store (RLS guard compartido)
    PERFORM assert_store_access(p_store_id);

    v_start_ts := p_start_date::TIMESTAMPTZ;
    v_end_ts   := (p_end_date + INTERVAL '1 day')::TIMESTAMPTZ;

    -- 1. INGRESOS NETOS (ventas no anuladas del período)
    SELECT COALESCE(SUM(total), 0)
    INTO v_revenue
    FROM public.sales
    WHERE store_id  = p_store_id
      AND created_at >= v_start_ts
      AND created_at <  v_end_ts
      AND is_voided  = FALSE;

    -- 2. COSTO DE VENTAS — COGS FIFO REAL
    --    Fuente: sale_item_batches (costo exacto por lote consumido)
    --    Nota: sale_items.unit_cost puede ser 0; el costo real está en sale_item_batches.
    SELECT COALESCE(SUM(sib.quantity_consumed * sib.unit_cost), 0)
    INTO v_cogs
    FROM public.sale_item_batches sib
    JOIN public.sale_items si ON sib.sale_item_id = si.id
    JOIN public.sales s       ON si.sale_id       = s.id
    WHERE s.store_id  = p_store_id
      AND s.created_at >= v_start_ts
      AND s.created_at <  v_end_ts
      AND s.is_voided  = FALSE;

    -- 3. UTILIDAD BRUTA Y MARGEN
    v_gross_profit := v_revenue - v_cogs;
    IF v_revenue > 0 THEN
        v_gross_margin := ROUND((v_gross_profit / v_revenue) * 100, 2);
    END IF;

    -- 4. GASTOS OPERATIVOS (cash_movements tipo 'gasto' dentro del período)
    SELECT COALESCE(SUM(cm.amount), 0)
    INTO v_op_expenses
    FROM public.cash_movements cm
    JOIN public.cash_sessions  cs ON cm.session_id = cs.id
    WHERE cs.store_id      = p_store_id
      AND cm.movement_type = 'gasto'
      AND cm.created_at   >= v_start_ts
      AND cm.created_at   <  v_end_ts;

    -- 5. UTILIDAD NETA
    v_net_profit := v_gross_profit - v_op_expenses;

    -- 6. VALOR DE INVENTARIO (capital en stock al momento actual — FUERA del rango de fechas)
    --    Costo FIFO de todos los lotes activos con stock disponible
    SELECT COALESCE(SUM(ib.quantity_remaining * ib.cost_unit), 0)
    INTO v_inventory_value
    FROM public.inventory_batches ib
    JOIN public.products p ON ib.product_id = p.id
    WHERE p.store_id              = p_store_id
      AND ib.is_active            = TRUE
      AND ib.quantity_remaining   > 0;

    -- 7. DESGLOSE POR MÉTODO DE PAGO
    SELECT jsonb_build_object(
        'cash',     COALESCE(SUM(total) FILTER (
                        WHERE payment_method NOT IN ('nequi','daviplata','fiado')
                    ), 0),
        'transfer', COALESCE(SUM(total) FILTER (
                        WHERE payment_method IN ('nequi','daviplata')
                    ), 0),
        'credit',   COALESCE(SUM(total) FILTER (
                        WHERE payment_method = 'fiado'
                    ), 0)
    )
    INTO v_payment_breakdown
    FROM public.sales
    WHERE store_id  = p_store_id
      AND created_at >= v_start_ts
      AND created_at <  v_end_ts
      AND is_voided  = FALSE;

    -- 8. FIADO PENDIENTE TOTAL (cartera vigente, sin filtro de fecha)
    SELECT COALESCE(SUM(balance), 0)
    INTO v_fiado_pendiente
    FROM public.clients
    WHERE store_id  = p_store_id
      AND (is_deleted = FALSE OR is_deleted IS NULL)
      AND balance    > 0;

    -- 9. SEMÁFORO DE RENDIMIENTO (vs. promedio de los 7 días anteriores al período)
    SELECT COALESCE(AVG(daily_total), 0)
    INTO v_avg_sales_7d
    FROM (
        SELECT DATE(created_at) AS day, SUM(total) AS daily_total
        FROM public.sales
        WHERE store_id  = p_store_id
          AND created_at >= (v_start_ts - INTERVAL '7 days')
          AND created_at <   v_start_ts
          AND is_voided  = FALSE
        GROUP BY 1
    ) past;

    IF v_avg_sales_7d = 0 THEN
        v_traffic_status  := 'gray';
        v_traffic_message := 'Recopilando datos históricos...';
    ELSIF v_revenue >= (v_avg_sales_7d * 1.05) THEN
        v_traffic_status  := 'green';
        v_traffic_message := '🚀 ¡Vas un '
            || ROUND(((v_revenue - v_avg_sales_7d) / v_avg_sales_7d * 100), 0)
            || '% arriba de tu promedio!';
    ELSIF v_revenue <= (v_avg_sales_7d * 0.95) THEN
        v_traffic_status  := 'red';
        v_traffic_message := '🔻 Estás un '
            || ROUND(((v_avg_sales_7d - v_revenue) / v_avg_sales_7d * 100), 0)
            || '% abajo de tu promedio.';
    ELSE
        v_traffic_status  := 'green';
        v_traffic_message := '👍 Ventas estables respecto a tu semana.';
    END IF;

    -- 10. PAYLOAD DE RESPUESTA
    RETURN jsonb_build_object(
        'period', jsonb_build_object(
            'start', p_start_date,
            'end',   p_end_date
        ),
        'revenue',               v_revenue,
        'cogs',                  v_cogs,
        'gross_profit',          v_gross_profit,
        'gross_margin',          v_gross_margin,
        'operational_expenses',  v_op_expenses,
        'net_profit',            v_net_profit,
        'inventory_value',       v_inventory_value,
        'payment_breakdown',     v_payment_breakdown,
        'fiado_pendiente',       v_fiado_pendiente,
        'traffic_light', jsonb_build_object(
            'status',  v_traffic_status,
            'message', v_traffic_message
        )
    );

EXCEPTION WHEN OTHERS THEN
    -- Relanzar el error para que el cliente lo capture en 'rpcError'
    -- en lugar de devolver un JSON de falso éxito.
    RAISE EXCEPTION 'Error interno al generar reporte financiero: %', SQLERRM
        USING ERRCODE = SQLSTATE;
END;
$$;

-- Solo usuarios autenticados (no anon)
GRANT EXECUTE ON FUNCTION rpc_get_comprehensive_financial_report(UUID, DATE, DATE) TO authenticated;

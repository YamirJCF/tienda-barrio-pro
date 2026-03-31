/**
 * Fix: Change get_daily_summary to SECURITY INVOKER
 * Impact: Enforces RLS policies on 'sales' and 'products' tables, preventing
 * unauthorized cross-store data access.
 */
CREATE OR REPLACE FUNCTION get_daily_summary(
    p_store_id UUID,
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER -- CHANGED FROM DEFINER TO INVOKER FOR RLS
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
    -- Definir rango de tiempo para el día consultado (asumiendo UTC por ahora, idealmente adaptar a timezone de tienda)
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

    -- 2. Money Breakdown (Desglose por método de pago)
    -- Mapeo: efectivo->cash, nequi/daviplata->transfer, fiado->credit
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

    -- Garantizar estructura aunque sea cero
    v_breakdown := jsonb_build_object(
        'cash', COALESCE((v_breakdown->>'cash')::NUMERIC, 0),
        'transfer', COALESCE((v_breakdown->>'transfer')::NUMERIC, 0),
        'credit', COALESCE((v_breakdown->>'credit')::NUMERIC, 0)
    );

    -- 3. Traffic Light (Comparativo vs Promedio 7 días anteriores)
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

    -- Lógica del Semáforo
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
        v_traffic_status := 'green'; -- Yellow a veces se percibe negativo, usamos green para "estable"
        v_traffic_message := '👍 Ventas estables respecto a tu semana.';
    END IF;

    -- 4. Alertas (Prioridad: Stock Crítico)
    -- Top 5 productos con stock bajo o agotado
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
        -- Placeholder para recordatorios futuros
        'reminder', jsonb_build_object('message', CASE WHEN v_total_sales = 0 THEN '¡Abre caja para empezar a vender!' ELSE 'Recuerda hacer el cierre de caja al final del turno.' END)
    );
END;
$$;

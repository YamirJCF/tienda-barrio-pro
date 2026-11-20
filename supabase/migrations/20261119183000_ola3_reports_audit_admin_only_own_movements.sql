-- =============================================================================
-- FASE 3 - OLA 3: Reportes y Auditoría 100% Admin-Only + Mis Movimientos del Turno
-- SDDs: SDD-005, SDD-008, SDD-021, SDD-027-01, SDD-003-01 (Contrato Marco)
-- Átomos: CHK-301, CHK-302, CHK-303, CHK-304, CHK-305, CHK-306
-- Reglas: AGENTS.md Reglas 2, 3, 4, 6, 8
-- =============================================================================

-- -----------------------------------------------------------------------------
-- [CHK-301] SDD-008: get_daily_summary 100% Admin-only + filtros reales
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_daily_summary(p_store_id uuid, p_date date DEFAULT CURRENT_DATE)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
    PERFORM public.assert_store_admin(p_store_id);

    v_start_date := p_date::TIMESTAMPTZ;
    v_end_date := v_start_date + INTERVAL '1 day';

    SELECT COALESCE(SUM(total), 0) INTO v_total_sales
    FROM public.sales
    WHERE store_id = p_store_id
      AND created_at >= v_start_date
      AND created_at < v_end_date
      AND is_voided = FALSE
      AND payment_method <> 'consumo_personal';

    SELECT jsonb_object_agg(method_group, amount) INTO v_breakdown
    FROM (
        SELECT
            CASE
                WHEN payment_method IN ('nequi', 'llave_bre') THEN 'transfer'
                WHEN payment_method = 'fiado' THEN 'credit'
                WHEN payment_method = 'efectivo' THEN 'cash'
                ELSE 'other'
            END AS method_group,
            SUM(total) AS amount
        FROM public.sales
        WHERE store_id = p_store_id
          AND created_at >= v_start_date
          AND created_at < v_end_date
          AND is_voided = FALSE
          AND payment_method <> 'consumo_personal'
        GROUP BY 1
    ) sub;

    v_breakdown := jsonb_build_object(
        'cash', COALESCE((v_breakdown->>'cash')::NUMERIC, 0),
        'transfer', COALESCE((v_breakdown->>'transfer')::NUMERIC, 0),
        'credit', COALESCE((v_breakdown->>'credit')::NUMERIC, 0),
        'nequi', COALESCE((
            SELECT SUM(total) FROM public.sales
            WHERE store_id = p_store_id
              AND created_at >= v_start_date
              AND created_at < v_end_date
              AND is_voided = FALSE
              AND payment_method = 'nequi'
        ), 0),
        'llave_bre', COALESCE((
            SELECT SUM(total) FROM public.sales
            WHERE store_id = p_store_id
              AND created_at >= v_start_date
              AND created_at < v_end_date
              AND is_voided = FALSE
              AND payment_method = 'llave_bre'
        ), 0)
    );

    SELECT COALESCE(AVG(daily_total), 0) INTO v_avg_sales_7d
    FROM (
        SELECT DATE(created_at) AS day, SUM(total) AS daily_total
        FROM public.sales
        WHERE store_id = p_store_id
          AND created_at >= (v_start_date - INTERVAL '7 days')
          AND created_at < v_start_date
          AND is_voided = FALSE
          AND payment_method <> 'consumo_personal'
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

    SELECT jsonb_agg(jsonb_build_object(
        'type', 'stock_critical',
        'message', CASE WHEN current_stock <= 0 THEN '❌ Agotado: ' || name ELSE '⚠️ Bajo stock: ' || name END,
        'target_id', id,
        'stock', current_stock
    ))
    INTO v_alerts
    FROM public.products
    WHERE store_id = p_store_id
      AND is_active = true
      AND current_stock <= min_stock
    LIMIT 5;

    IF v_alerts IS NULL THEN v_alerts := '[]'::JSONB; END IF;

    RETURN jsonb_build_object(
        'traffic_light', jsonb_build_object('status', v_traffic_status, 'message', v_traffic_message),
        'hero_number', v_total_sales,
        'money_breakdown', v_breakdown,
        'alerts', v_alerts,
        'reminder', jsonb_build_object('message', CASE WHEN v_total_sales = 0 THEN '¡Abre caja para empezar a vender!' ELSE 'Recuerda hacer el cierre de caja al final del turno.' END)
    );
END;
$function$;

-- -----------------------------------------------------------------------------
-- [CHK-301] SDD-008: get_smart_supply_report 100% Admin-only
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_smart_supply_report(p_store_id uuid)
RETURNS TABLE(product_id uuid, product_name text, current_stock numeric, velocity numeric, doi numeric, revenue_at_risk numeric, status text, suggestion text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_window_days INT := 30;
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

    RETURN QUERY
    WITH sales_stats AS (
        SELECT
            si.product_id,
            SUM(si.quantity) AS total_sold,
            COUNT(DISTINCT DATE(si.created_at)) AS days_sold
        FROM public.sale_items si
        JOIN public.sales s ON si.sale_id = s.id
        WHERE s.store_id = p_store_id
          AND s.created_at >= (NOW() - (v_window_days || ' days')::INTERVAL)
          AND s.is_voided = false
          AND s.payment_method <> 'consumo_personal'
        GROUP BY si.product_id
    ),
    product_calc AS (
        SELECT
            p.id,
            p.name,
            p.current_stock,
            p.price,
            p.created_at AS product_created_at,
            COALESCE(ss.total_sold, 0) AS total_sold,
            COALESCE(ss.total_sold, 0) / NULLIF(v_window_days, 0) AS velocity,
            COALESCE(sup.frequency_days, 7) AS frequency_days,
            COALESCE(sup.lead_time_days, 1) AS lead_time_days
        FROM public.products p
        LEFT JOIN public.suppliers sup ON p.supplier_id = sup.id
        LEFT JOIN sales_stats ss ON p.id = ss.product_id
        WHERE p.store_id = p_store_id
          AND p.is_active = true
    )
    SELECT
        pc.id,
        pc.name,
        pc.current_stock,
        pc.velocity,
        CASE
            WHEN pc.velocity > 0 THEN ROUND(pc.current_stock / pc.velocity, 1)
            ELSE 999
        END AS doi,
        CASE
            WHEN pc.product_created_at > (NOW() - INTERVAL '15 days') THEN 0
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days
                THEN ROUND((pc.lead_time_days - (COALESCE(pc.current_stock, 0) / pc.velocity)) * pc.velocity * COALESCE(pc.price, 0))
            ELSE 0
        END AS revenue_at_risk,
        CASE
            -- RN-008-02: Umbral de Silencio (Productos con < 15 días de creación)
            WHEN pc.product_created_at > (NOW() - INTERVAL '15 days') THEN 'LEARNING'
            WHEN pc.velocity = 0 THEN 'UNKNOWN'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days THEN 'CRITICAL'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < (pc.lead_time_days + pc.frequency_days) THEN 'WARNING'
            ELSE 'OK'
        END::TEXT AS status,
        CASE
            WHEN pc.product_created_at > (NOW() - INTERVAL '15 days') THEN 'Aprendiendo de tus ventas...'
            WHEN pc.velocity = 0 THEN 'Recopilando datos...'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days THEN 'Pedir urgente: se agotará antes de la próxima entrega.'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < (pc.lead_time_days + pc.frequency_days) THEN 'Incluir en próximo pedido.'
            ELSE 'Stock suficiente por ahora.'
        END::TEXT AS suggestion
    FROM product_calc pc;
END;
$function$;

-- -----------------------------------------------------------------------------
-- [CHK-301] SDD-008: rpc_asignar_proveedor_masivo con assert_store_admin
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_asignar_proveedor_masivo(p_store_id uuid, p_supplier_id uuid, p_product_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_updated_count INTEGER;
BEGIN
    -- 1. Regla 4: Exclusividad Admin centralizada (owner | manager)
    PERFORM public.assert_store_admin(p_store_id);

    -- 2. Validar lista no vacía
    IF p_product_ids IS NULL OR cardinality(p_product_ids) = 0 THEN
        RAISE EXCEPTION 'La lista de productos no puede estar vacía (EMPTY_PRODUCT_LIST)' USING ERRCODE = 'P0001';
    END IF;

    -- 3. Validar existencia del proveedor en la tienda
    IF NOT EXISTS (SELECT 1 FROM public.suppliers WHERE id = p_supplier_id AND store_id = p_store_id) THEN
        RAISE EXCEPTION 'Proveedor no encontrado en esta tienda (SUPPLIER_NOT_FOUND)' USING ERRCODE = 'P0001';
    END IF;

    -- 4. Actualizar productos
    UPDATE public.products
    SET supplier_id = p_supplier_id,
        updated_at = NOW()
    WHERE store_id = p_store_id
      AND id = ANY(p_product_ids);

    GET DIAGNOSTICS v_updated_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', true,
        'updated_count', v_updated_count
    );
END;
$function$;

-- -----------------------------------------------------------------------------
-- [CHK-301 / CHK-302] Blindaje Admin-Only del resto de RPCs Analíticos/Reportes
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_inventory_health(p_store_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
    PERFORM public.assert_store_admin(p_store_id);

    SELECT COALESCE(SUM(current_stock * cost_price), 0), COUNT(id)
    INTO v_valor_total, v_total_count
    FROM public.products
    WHERE store_id = p_store_id AND is_active = true AND current_stock > 0;

    SELECT COALESCE(AVG(daily_cogs), 0)
    INTO v_cogs_promedio
    FROM (
        SELECT DATE(s.created_at) AS day, SUM(si.unit_cost * si.quantity) AS daily_cogs
        FROM public.sales s
        JOIN public.sale_items si ON si.sale_id = s.id
        WHERE s.store_id = p_store_id
          AND s.created_at >= CURRENT_DATE - INTERVAL '30 days'
          AND s.is_voided = FALSE
        GROUP BY DATE(s.created_at)
    ) daily_stats;

    v_dias_inventario := ROUND(v_valor_total / NULLIF(v_cogs_promedio, 0), 0)::INTEGER;

    IF v_dias_inventario IS NULL THEN v_estado := 'desconocido';
    ELSIF v_dias_inventario < 7 THEN v_estado := 'riesgo';
    ELSIF v_dias_inventario <= 15 THEN v_estado := 'optimo';
    ELSIF v_dias_inventario <= 30 THEN v_estado := 'saludable';
    ELSE v_estado := 'sobre_inventario';
    END IF;

    WITH product_last_sales AS (
        SELECT p.id, (p.current_stock * p.cost_price) AS val,
               EXTRACT(DAY FROM (CURRENT_TIMESTAMP - COALESCE(MAX(s.created_at), p.created_at))) AS days_since_sale
        FROM public.products p
        LEFT JOIN public.sale_items si ON si.product_id = p.id
        LEFT JOIN public.sales s ON si.sale_id = s.id AND s.is_voided = FALSE
        WHERE p.store_id = p_store_id AND p.is_active = true AND p.current_stock > 0
        GROUP BY p.id, p.current_stock, p.cost_price, p.created_at
    )
    SELECT
        COUNT(CASE WHEN days_since_sale < 7 THEN 1 END),
        COALESCE(SUM(CASE WHEN days_since_sale < 7 THEN val ELSE 0 END), 0),
        COUNT(CASE WHEN days_since_sale >= 7 AND days_since_sale <= 30 THEN 1 END),
        COALESCE(SUM(CASE WHEN days_since_sale >= 7 AND days_since_sale <= 30 THEN val ELSE 0 END), 0),
        COUNT(CASE WHEN days_since_sale > 30 THEN 1 END),
        COALESCE(SUM(CASE WHEN days_since_sale > 30 THEN val ELSE 0 END), 0)
    INTO v_rapida_count, v_rapida_valor, v_normal_count, v_normal_valor, v_lenta_count, v_lenta_valor
    FROM product_last_sales;

    RETURN jsonb_build_object(
        'valor_total', v_valor_total,
        'dias_inventario', v_dias_inventario,
        'estado', v_estado,
        'distribucion_rotacion', jsonb_build_object(
            'rapida', jsonb_build_object('count', v_rapida_count, 'valor', v_rapida_valor, 'porcentaje', CASE v_valor_total WHEN 0 THEN 0 ELSE ROUND((v_rapida_valor / v_valor_total) * 100, 1) END),
            'normal', jsonb_build_object('count', v_normal_count, 'valor', v_normal_valor, 'porcentaje', CASE v_valor_total WHEN 0 THEN 0 ELSE ROUND((v_normal_valor / v_valor_total) * 100, 1) END),
            'lenta', jsonb_build_object('count', v_lenta_count, 'valor', v_lenta_valor, 'porcentaje', CASE v_valor_total WHEN 0 THEN 0 ELSE ROUND((v_lenta_valor / v_valor_total) * 100, 1) END)
        )
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_client_ledger_summary(p_store_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_cartera_total numeric DEFAULT 0;
    v_cartera_vencida numeric DEFAULT 0;
    v_clientes_con_deuda integer DEFAULT 0;
    v_clientes_morosos integer DEFAULT 0;
    v_top_deudores jsonb;
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

    SELECT COALESCE(SUM(balance), 0),
           COALESCE(SUM(CASE WHEN updated_at < CURRENT_DATE - INTERVAL '30 days' THEN balance ELSE 0 END), 0),
           COUNT(id),
           COUNT(CASE WHEN updated_at < CURRENT_DATE - INTERVAL '30 days' THEN 1 END)
    INTO v_cartera_total, v_cartera_vencida, v_clientes_con_deuda, v_clientes_morosos
    FROM public.clients
    WHERE store_id = p_store_id
      AND balance > 0
      AND COALESCE(is_deleted, false) = false;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'client_id', id,
                'client_name', name,
                'balance', balance,
                'dias_sin_pagar', EXTRACT(DAY FROM (CURRENT_TIMESTAMP - updated_at))::integer,
                'ultima_compra', DATE(updated_at)
            )
        ),
        '[]'::jsonb
    ) INTO v_top_deudores
    FROM (
        SELECT id, name, balance, updated_at
        FROM public.clients
        WHERE store_id = p_store_id
          AND balance > 0
          AND COALESCE(is_deleted, false) = false
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
$function$;

CREATE OR REPLACE FUNCTION public.get_stagnant_products(p_store_id uuid, p_days_threshold integer DEFAULT 30)
RETURNS TABLE(product_id uuid, product_name text, last_sale_date date, days_stagnant integer, stock_value numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

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
      AND p.is_active = true
      AND p.current_stock > 0
    GROUP BY p.id, p.name, p.current_stock, p.cost_price, p.created_at
    HAVING MAX(s.created_at) IS NULL
        OR MAX(s.created_at) < (CURRENT_TIMESTAMP - (p_days_threshold || ' days')::INTERVAL)
    ORDER BY days_stagnant DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_top_products_by_units(p_store_id uuid, p_start_date date DEFAULT CURRENT_DATE, p_end_date date DEFAULT CURRENT_DATE, p_limit integer DEFAULT 10)
RETURNS TABLE(product_id uuid, product_name text, units_sold numeric, dias_rotacion integer, stock_actual numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_start_ts TIMESTAMPTZ;
    v_end_ts TIMESTAMPTZ;
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

    v_start_ts := p_start_date::TIMESTAMPTZ;
    v_end_ts := (p_end_date + INTERVAL '1 day')::TIMESTAMPTZ;

    RETURN QUERY
    WITH ventas_agrupadas AS (
        SELECT si.product_id, SUM(si.quantity) AS total_units, MAX(s.created_at) AS last_sale_at
        FROM public.sale_items si
        JOIN public.sales s ON si.sale_id = s.id
        WHERE s.store_id = p_store_id
          AND s.created_at >= v_start_ts
          AND s.created_at < v_end_ts
          AND s.is_voided = FALSE
          AND s.payment_method <> 'consumo_personal'
        GROUP BY si.product_id
        ORDER BY total_units DESC
        LIMIT p_limit
    )
    SELECT p.id AS product_id,
           p.name AS product_name,
           va.total_units AS units_sold,
           (SELECT ROUND(EXTRACT(EPOCH FROM (va.last_sale_at - im.created_at)) / 86400, 0)::INTEGER
            FROM public.inventory_movements im
            WHERE im.product_id = p.id AND im.movement_type = 'entrada'
            ORDER BY im.created_at DESC LIMIT 1) AS dias_rotacion,
           p.current_stock AS stock_actual
    FROM ventas_agrupadas va
    JOIN public.products p ON va.product_id = p.id
    ORDER BY va.total_units DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_top_selling_products(p_store_id uuid, p_start_date date DEFAULT CURRENT_DATE, p_end_date date DEFAULT CURRENT_DATE, p_limit integer DEFAULT 10)
RETURNS TABLE(product_id uuid, product_name text, units_sold numeric, revenue numeric, profit numeric, stock_remaining numeric, stock_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_start_ts TIMESTAMPTZ;
    v_end_ts TIMESTAMPTZ;
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

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
      AND s.payment_method <> 'consumo_personal'
    GROUP BY p.id, p.name, p.current_stock, p.min_stock
    ORDER BY units_sold DESC
    LIMIT p_limit;
END;
$function$;

-- -----------------------------------------------------------------------------
-- [CHK-302] SDD-027-01 / SDD-018: get_history_caja & rpc_get_comprehensive_financial_report
-- + historiales restantes 100% Admin-only
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_history_caja(p_store_id uuid, p_start_date date, p_end_date date)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_result JSONB;
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION 'INVALID_DATE_RANGE: La fecha inicial no puede ser posterior a la fecha final.'
            USING ERRCODE = '22023';
    END IF;

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
            'closing_attempts', COALESCE(cs.closing_attempts, 0),
            'forced_close_without_count', COALESCE(cs.forced_close_without_count, false),
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
            'opened_by_name', COALESCE(cs.opened_by_name, eo.name, ap_open.id::text, 'Desconocido'),
            'opened_by_role', cs.opened_by_role,
            'closed_by_name', COALESCE(cs.closed_by_name, ec.name, ap_close.id::text, NULL),
            'closed_by_role', cs.closed_by_role,
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
            'total_supplier_payments', (
                SELECT COALESCE(SUM(cm.amount), 0)
                FROM public.cash_movements cm
                WHERE cm.session_id = cs.id AND cm.movement_type = 'pago_proveedor'
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
            'income_llave_bre', (
                SELECT COALESCE(SUM(cm.amount), 0)
                FROM public.cash_movements cm
                WHERE cm.session_id = cs.id AND cm.movement_type = 'ingreso' AND cm.payment_method = 'llave_bre'
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
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_get_comprehensive_financial_report(
    p_store_id uuid,
    p_start_date date DEFAULT CURRENT_DATE,
    p_end_date date DEFAULT CURRENT_DATE,
    p_employee_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
    PERFORM public.assert_store_admin(p_store_id);

    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION 'La fecha de inicio no puede ser posterior a la fecha de fin (INVALID_DATE_RANGE)' USING ERRCODE = 'P0001';
    END IF;

    IF (p_end_date - p_start_date) > 366 THEN
        RAISE EXCEPTION 'El rango máximo permitido para el reporte financiero es de 366 días (RANGE_EXCEEDS_MAX_LIMIT)' USING ERRCODE = 'P0001';
    END IF;

    IF p_employee_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.employees WHERE id = p_employee_id AND store_id = p_store_id) THEN
            RAISE EXCEPTION 'El colaborador seleccionado no pertenece a este establecimiento (EMPLOYEE_NOT_FOUND)' USING ERRCODE = 'P0001';
        END IF;
    END IF;

    v_start_ts := p_start_date::TIMESTAMPTZ;
    v_end_ts   := (p_end_date + INTERVAL '1 day')::TIMESTAMPTZ;

    SELECT COALESCE(SUM(total), 0)
    INTO v_revenue
    FROM public.sales
    WHERE store_id  = p_store_id
      AND created_at >= v_start_ts
      AND created_at <  v_end_ts
      AND is_voided  = FALSE
      AND payment_method <> 'consumo_personal'
      AND (p_employee_id IS NULL OR employee_id = p_employee_id);

    SELECT COALESCE(SUM(sib.quantity_consumed * sib.unit_cost), 0)
    INTO v_cogs
    FROM public.sale_item_batches sib
    JOIN public.sale_items si ON sib.sale_item_id = si.id
    JOIN public.sales s       ON si.sale_id       = s.id
    WHERE s.store_id  = p_store_id
      AND s.created_at >= v_start_ts
      AND s.created_at <  v_end_ts
      AND s.is_voided  = FALSE
      AND s.payment_method <> 'consumo_personal'
      AND (p_employee_id IS NULL OR s.employee_id = p_employee_id);

    v_gross_profit := v_revenue - v_cogs;
    IF v_revenue > 0 THEN
        v_gross_margin := ROUND((v_gross_profit / v_revenue) * 100, 2);
    END IF;

    SELECT COALESCE(SUM(cm.amount), 0)
    INTO v_op_expenses
    FROM public.cash_movements cm
    JOIN public.cash_sessions  cs ON cm.session_id = cs.id
    WHERE cs.store_id      = p_store_id
      AND cm.movement_type = 'gasto'
      AND COALESCE(cm.category, '') NOT IN ('anulacion_venta', 'reembolso', 'devolucion')
      AND cm.created_at   >= v_start_ts
      AND cm.created_at   <  v_end_ts
      AND (p_employee_id IS NULL OR cm.actor_id = p_employee_id);

    v_net_profit := v_gross_profit - v_op_expenses;

    SELECT COALESCE(SUM(ib.quantity_remaining * ib.cost_unit), 0)
    INTO v_inventory_value
    FROM public.inventory_batches ib
    JOIN public.products p ON ib.product_id = p.id
    WHERE p.store_id              = p_store_id
      AND p.is_active             = TRUE
      AND ib.is_active            = TRUE
      AND ib.quantity_remaining   > 0;

    SELECT jsonb_build_object(
        'cash',      COALESCE(SUM(total) FILTER (WHERE payment_method = 'efectivo'), 0),
        'transfer',  COALESCE(SUM(total) FILTER (WHERE payment_method IN ('nequi', 'llave_bre')), 0),
        'credit',    COALESCE(SUM(total) FILTER (WHERE payment_method = 'fiado'), 0),
        'nequi',     COALESCE(SUM(total) FILTER (WHERE payment_method = 'nequi'), 0),
        'llave_bre', COALESCE(SUM(total) FILTER (WHERE payment_method = 'llave_bre'), 0)
    )
    INTO v_payment_breakdown
    FROM public.sales
    WHERE store_id  = p_store_id
      AND created_at >= v_start_ts
      AND created_at <  v_end_ts
      AND is_voided  = FALSE
      AND payment_method <> 'consumo_personal'
      AND (p_employee_id IS NULL OR employee_id = p_employee_id);

    SELECT COALESCE(SUM(balance), 0)
    INTO v_fiado_pendiente
    FROM public.clients
    WHERE store_id  = p_store_id
      AND (is_deleted = FALSE OR is_deleted IS NULL)
      AND balance    > 0;

    SELECT COALESCE(AVG(daily_total), 0)
    INTO v_avg_sales_7d
    FROM (
        SELECT DATE(created_at) AS day, SUM(total) AS daily_total
        FROM public.sales
        WHERE store_id  = p_store_id
          AND created_at >= (v_start_ts - INTERVAL '7 days')
          AND created_at <   v_start_ts
          AND is_voided  = FALSE
          AND payment_method <> 'consumo_personal'
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
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_history_ventas(p_store_id uuid, p_start_date date, p_end_date date, p_employee_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_result JSONB;
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

    SELECT COALESCE(jsonb_agg(row_data ORDER BY created_at DESC), '[]'::jsonb) INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', s.id,
            'ticket_number', s.ticket_number,
            'total', s.total,
            'payment_method', s.payment_method,
            'employee_name', COALESCE(s.actor_name, e.name, 'Administrador'),
            'actor_name', COALESCE(s.actor_name, e.name, 'Administrador'),
            'actor_role', COALESCE(s.actor_role, CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END),
            'employee_id', s.employee_id,
            'client_name', c.name,
            'items_count', (SELECT COUNT(*) FROM public.sale_items si WHERE si.sale_id = s.id),
            'is_voided', COALESCE(s.is_voided, false),
            'void_reason', s.void_reason,
            'voided_by_name', s.voided_by_name,
            'created_at', s.created_at
        ) AS row_data, s.created_at
        FROM public.sales s
        LEFT JOIN public.employees e ON e.id = s.employee_id
        LEFT JOIN public.clients c ON c.id = s.client_id
        WHERE s.store_id = p_store_id
          AND s.created_at >= p_start_date::timestamptz
          AND s.created_at < (p_end_date + 1)::timestamptz
          AND (p_employee_id IS NULL OR s.employee_id = p_employee_id)
        LIMIT 200
    ) sub;
    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_history_compras(p_store_id uuid, p_start_date date, p_end_date date)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_result JSONB;
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

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
            'created_by_name', COALESCE(im.actor_name, e.name, 'Administrador'),
            'actor_name', COALESCE(im.actor_name, e.name, 'Administrador'),
            'actor_role', COALESCE(im.actor_role, CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END),
            'created_at', im.created_at
        ) AS row_data,
        im.created_at
        FROM public.inventory_movements im
        JOIN public.products p ON p.id = im.product_id
        LEFT JOIN public.suppliers sup ON sup.id = im.supplier_id
        LEFT JOIN public.employees e ON e.id = im.created_by
        WHERE p.store_id = p_store_id
          AND im.created_at >= p_start_date::timestamptz
          AND im.created_at < (p_end_date + 1)::timestamptz
          AND im.movement_type = 'entrada'
        LIMIT 200
    ) sub;

    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_history_creditos(
    p_store_id uuid,
    p_start_date timestamp with time zone DEFAULT (now() - '30 days'::interval),
    p_end_date timestamp with time zone DEFAULT now()
)
RETURNS TABLE(id uuid, client_name text, transaction_type text, amount numeric, previous_balance numeric, new_balance numeric, description text, employee_name text, created_at timestamp with time zone)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

    RETURN QUERY
    SELECT
        cl.id,
        c.name AS client_name,
        cl.transaction_type,
        cl.amount,
        cl.previous_balance,
        cl.new_balance,
        CASE
            WHEN cl.transaction_type = 'venta_fiado' THEN 'Venta fiado'
            WHEN cl.transaction_type = 'abono' THEN 'Abono a deuda'
            WHEN cl.transaction_type = 'anulacion_fiado' THEN 'Anulación de venta fiado'
            ELSE cl.transaction_type
        END AS description,
        COALESCE(cl.actor_name, e.name, 'Administrador') AS employee_name,
        cl.created_at
    FROM public.client_ledger cl
    JOIN public.clients c ON c.id = cl.client_id
    LEFT JOIN public.employees e ON e.id = cl.created_by
    WHERE cl.store_id = p_store_id
      AND cl.created_at >= p_start_date
      AND cl.created_at <= p_end_date
    ORDER BY cl.created_at DESC;
END;
$function$;

-- -----------------------------------------------------------------------------
-- [CHK-303 / CHK-304] Triggers de auditoría con snapshot + rpc_marcar_auditoria_revisada
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_audit_sale_voided()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
    IF (OLD.is_voided IS DISTINCT FROM NEW.is_voided) AND NEW.is_voided = true THEN
        INSERT INTO public.audit_ventas (
            sale_id, store_id, event_type, actor_id, actor_name, actor_role, metadata
        ) VALUES (
            NEW.id,
            NEW.store_id,
            'ANULACION',
            NEW.voided_by,
            COALESCE(NEW.voided_by_name, 'Administrador'),
            COALESCE(NEW.voided_by_role, 'owner'),
            jsonb_build_object(
                'total', NEW.total,
                'void_reason', NEW.void_reason,
                'sale_number', NEW.ticket_number
            )
        );
    END IF;
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_audit_price_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_employee_id UUID;
    v_actor_name TEXT := 'Administrador';
    v_actor_role TEXT := 'owner';
    v_snap RECORD;
BEGIN
    IF (OLD.cost_price IS DISTINCT FROM NEW.cost_price)
       OR (OLD.price IS DISTINCT FROM NEW.price) THEN
        SELECT * INTO v_snap FROM public.resolve_actor_snapshot(NEW.store_id);
        v_actor_name := COALESCE(NULLIF(TRIM(v_snap.actor_name), ''), 'Administrador');
        v_actor_role := COALESCE(NULLIF(TRIM(v_snap.actor_role), ''), 'owner');

        SELECT id INTO v_employee_id
        FROM public.employees
        WHERE id = v_snap.actor_id AND store_id = NEW.store_id
        LIMIT 1;

        INSERT INTO public.audit_precios (
            product_id, store_id, old_cost, new_cost, old_price, new_price, changed_by, actor_name, actor_role
        ) VALUES (
            NEW.id,
            NEW.store_id,
            OLD.cost_price,
            NEW.cost_price,
            OLD.price,
            NEW.price,
            v_employee_id,
            v_actor_name,
            v_actor_role
        );
    END IF;
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_marcar_auditoria_revisada(p_audit_id uuid, p_notes text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_store_id uuid;
    v_audit RECORD;
    v_snap RECORD;
BEGIN
    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED' USING ERRCODE = '42501';
    END IF;
    PERFORM public.assert_store_admin(v_store_id);

    SELECT * INTO v_audit
    FROM public.audit_logs
    WHERE id = p_audit_id AND store_id = v_store_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Registro de auditoría no encontrado (AUDIT_NOT_FOUND)' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_store_id);

    UPDATE public.audit_logs
    SET reviewed_by = auth.uid(),
        reviewed_at = NOW(),
        review_notes = p_notes,
        metadata = jsonb_set(
            COALESCE(metadata, '{}'::jsonb),
            '{status}',
            '"reviewed"'
        ) || jsonb_build_object('reviewed_by_name', v_snap.actor_name)
    WHERE id = p_audit_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'audit_id', p_audit_id,
            'reviewed_at', NOW(),
            'reviewed_by', auth.uid(),
            'reviewed_by_name', v_snap.actor_name
        )
    );
END;
$function$;

-- -----------------------------------------------------------------------------
-- [CHK-304] Catálogo extendido audit_seguridad + rpc_log_security_event
-- -----------------------------------------------------------------------------
ALTER TABLE public.audit_seguridad
    DROP CONSTRAINT IF EXISTS audit_seguridad_event_type_check;

ALTER TABLE public.audit_seguridad
    ADD CONSTRAINT audit_seguridad_event_type_check CHECK (
        event_type = ANY (ARRAY[
            'LOGIN_SUCCESS', 'LOGIN_FAILED', 'PIN_CHANGE', 'UNAUTHORIZED_ACCESS',
            'UNAUTHORIZED_SHIFT_CLOSE', 'CASH_DISCREPANCY_ALERT', 'CASH_DISCREPANCY',
            'FORCED_CLOSE_24H', 'FORCED_CLOSE_NO_COUNT', 'ADMIN_FORCED_CLOSE_NO_COUNT',
            'FORCE_SALE', 'SESSION_EXPIRED', 'ROLE_CHANGE', 'EMPLOYEE_DEACTIVATED',
            'DEVICE_ACCESS_APPROVE', 'DEVICE_ACCESS_REJECT', 'DEVICE_ACCESS_REVOKE',
            'CONCURRENT_MUTATION_BLOCKED', 'INVENTORY_COUNT_ADJUSTMENT',
            'BUSINESS_CONSUMPTION', 'PERSONAL_WITHDRAWAL', 'REFUND_MERMA',
            'SALE_VOIDED', 'CORRECTION', 'TRANSACTION_CORRECTION'
        ])
    );

CREATE OR REPLACE FUNCTION public.rpc_log_security_event(
    p_event_type text,
    p_store_id uuid DEFAULT NULL::uuid,
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_event TEXT := UPPER(TRIM(COALESCE(p_event_type, '')));
    v_employee_id UUID;
    v_actor_name TEXT := 'Sistema';
    v_actor_role TEXT := 'employee';
    v_snap RECORD;
    v_ip TEXT;
    v_user_agent TEXT;
    v_headers JSONB;
    v_severity TEXT;
BEGIN
    IF v_event NOT IN (
        'LOGIN_SUCCESS', 'LOGIN_FAILED', 'PIN_CHANGE', 'UNAUTHORIZED_ACCESS',
        'UNAUTHORIZED_SHIFT_CLOSE', 'CASH_DISCREPANCY_ALERT', 'CASH_DISCREPANCY',
        'FORCED_CLOSE_24H', 'FORCED_CLOSE_NO_COUNT', 'ADMIN_FORCED_CLOSE_NO_COUNT',
        'FORCE_SALE', 'SESSION_EXPIRED', 'ROLE_CHANGE', 'EMPLOYEE_DEACTIVATED',
        'DEVICE_ACCESS_APPROVE', 'DEVICE_ACCESS_REJECT', 'DEVICE_ACCESS_REVOKE',
        'CONCURRENT_MUTATION_BLOCKED', 'INVENTORY_COUNT_ADJUSTMENT',
        'BUSINESS_CONSUMPTION', 'PERSONAL_WITHDRAWAL', 'REFUND_MERMA',
        'SALE_VOIDED', 'CORRECTION', 'TRANSACTION_CORRECTION'
    ) THEN
        RAISE EXCEPTION 'INVALID_SECURITY_EVENT_TYPE: Evento de seguridad (%) no reconocido.', p_event_type
            USING ERRCODE = '22023';
    END IF;

    IF p_store_id IS NOT NULL THEN
        PERFORM public.assert_store_access(p_store_id);

        SELECT * INTO v_snap FROM public.resolve_actor_snapshot(p_store_id);
        v_actor_name := COALESCE(NULLIF(TRIM(v_snap.actor_name), ''), 'Sistema');
        v_actor_role := COALESCE(NULLIF(TRIM(v_snap.actor_role), ''), 'employee');

        SELECT e.id INTO v_employee_id
        FROM public.employees e
        WHERE e.id = v_snap.actor_id AND e.store_id = p_store_id
        LIMIT 1;
    END IF;

    BEGIN
        v_headers := NULLIF(current_setting('request.headers', true), '')::jsonb;
        v_ip := v_headers->>'x-forwarded-for';
        v_user_agent := v_headers->>'user-agent';
    EXCEPTION WHEN OTHERS THEN
        v_ip := NULL;
        v_user_agent := NULL;
    END;

    v_severity := COALESCE(
        NULLIF(LOWER(TRIM(COALESCE(p_metadata->>'severity', ''))), ''),
        CASE
            WHEN v_event IN (
                'UNAUTHORIZED_ACCESS', 'UNAUTHORIZED_SHIFT_CLOSE', 'CASH_DISCREPANCY_ALERT',
                'FORCED_CLOSE_NO_COUNT', 'ADMIN_FORCED_CLOSE_NO_COUNT', 'CONCURRENT_MUTATION_BLOCKED'
            ) THEN 'critical'
            WHEN v_event IN (
                'LOGIN_FAILED', 'FORCE_SALE', 'FORCED_CLOSE_24H', 'CASH_DISCREPANCY',
                'INVENTORY_COUNT_ADJUSTMENT', 'REFUND_MERMA', 'SALE_VOIDED', 'CORRECTION', 'TRANSACTION_CORRECTION'
            ) THEN 'warning'
            ELSE 'info'
        END
    );

    INSERT INTO public.audit_seguridad (
        actor_id, actor_name, actor_role, store_id, event_type, ip_address, user_agent, metadata
    ) VALUES (
        v_employee_id,
        v_actor_name,
        v_actor_role,
        p_store_id,
        v_event,
        v_ip,
        v_user_agent,
        COALESCE(p_metadata, '{}'::jsonb) || jsonb_build_object('severity', v_severity)
    );

    IF p_store_id IS NOT NULL THEN
        INSERT INTO public.audit_logs (
            actor_id, actor_name, actor_role, store_id, event_type, resource_id, metadata, severity
        ) VALUES (
            v_employee_id,
            v_actor_name,
            v_actor_role,
            p_store_id,
            v_event,
            COALESCE(p_metadata->>'resource_id', p_metadata->>'session_id', p_metadata->>'permission_key', p_store_id::text),
            COALESCE(p_metadata, '{}'::jsonb),
            v_severity
        );

        IF v_event = 'UNAUTHORIZED_SHIFT_CLOSE' THEN
            INSERT INTO public.notifications (
                store_id, type, title, message, audience, is_read, metadata
            ) VALUES (
                p_store_id,
                'security',
                'Intento Bloqueado de Cierre de Caja',
                format('%s intentó cerrar un turno abierto por otro usuario.', COALESCE(v_actor_name, 'Un colaborador')),
                'admin',
                false,
                jsonb_build_object(
                    'event_type', 'UNAUTHORIZED_SHIFT_CLOSE',
                    'session_id', p_metadata->>'session_id',
                    'actor_name', v_actor_name,
                    'actor_role', v_actor_role
                ) || COALESCE(p_metadata, '{}'::jsonb)
            );
        END IF;
    END IF;
END;
$function$;

-- -----------------------------------------------------------------------------
-- [CHK-303] SDD-005: rpc_obtener_auditoria_evidence_hub (100% Admin-only)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_obtener_auditoria_evidence_hub(
    p_store_id uuid,
    p_domain text DEFAULT 'todos'::text,
    p_event_type text DEFAULT NULL::text,
    p_severity text DEFAULT NULL::text,
    p_start_date timestamptz DEFAULT (NOW() - INTERVAL '7 days'),
    p_end_date timestamptz DEFAULT NOW(),
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_domain TEXT := LOWER(TRIM(COALESCE(p_domain, 'todos')));
    v_start TIMESTAMPTZ := COALESCE(p_start_date, NOW() - INTERVAL '7 days');
    v_end TIMESTAMPTZ := COALESCE(p_end_date, NOW());
    v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
    v_offset INT := GREATEST(COALESCE(p_offset, 0), 0);
    v_data JSONB;
    v_count INT;
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

    IF v_domain = 'all' THEN
        v_domain := 'todos';
    END IF;

    IF v_domain NOT IN ('todos', 'caja', 'ventas', 'inventario', 'seguridad', 'precios', 'creditos') THEN
        RAISE EXCEPTION 'INVALID_DOMAIN: Dominio de auditoría (%) no válido.', p_domain
            USING ERRCODE = '22023';
    END IF;

    IF v_start > v_end THEN
        RAISE EXCEPTION 'INVALID_DATE_RANGE: La fecha inicial no puede ser posterior a la fecha final.'
            USING ERRCODE = '22023';
    END IF;

    WITH unified AS (
        -- 1. Seguridad
        SELECT
            s.id,
            'seguridad'::text AS domain,
            s.event_type,
            COALESCE(
                NULLIF(s.metadata->>'severity', ''),
                CASE
                    WHEN s.event_type IN ('UNAUTHORIZED_ACCESS', 'UNAUTHORIZED_SHIFT_CLOSE', 'CASH_DISCREPANCY_ALERT', 'FORCED_CLOSE_NO_COUNT', 'ADMIN_FORCED_CLOSE_NO_COUNT', 'CONCURRENT_MUTATION_BLOCKED') THEN 'critical'
                    WHEN s.event_type IN ('LOGIN_FAILED', 'FORCE_SALE', 'FORCED_CLOSE_24H', 'CASH_DISCREPANCY', 'INVENTORY_COUNT_ADJUSTMENT', 'REFUND_MERMA', 'SALE_VOIDED', 'CORRECTION', 'TRANSACTION_CORRECTION') THEN 'warning'
                    ELSE 'info'
                END
            ) AS severity,
            COALESCE(s.metadata->>'resource_id', s.metadata->>'session_id', s.id::text) AS resource_id,
            s.actor_id,
            COALESCE(NULLIF(TRIM(s.actor_name), ''), e.name, 'Sistema') AS actor_name,
            COALESCE(NULLIF(TRIM(s.actor_role), ''), CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END) AS actor_role,
            s.ip_address,
            s.created_at,
            COALESCE(s.metadata, '{}'::jsonb) AS metadata
        FROM public.audit_seguridad s
        LEFT JOIN public.employees e ON e.id = s.actor_id
        WHERE s.store_id = p_store_id
          AND s.created_at >= v_start
          AND s.created_at <= v_end
          AND v_domain IN ('todos', 'seguridad')

        UNION ALL

        -- 2. Caja
        SELECT
            ac.id,
            'caja'::text AS domain,
            ac.event_type,
            CASE
                WHEN COALESCE((ac.metadata->>'forced_close_without_count')::boolean, false) = true THEN 'critical'
                WHEN COALESCE((ac.metadata->>'forced_close')::boolean, false) = true THEN 'warning'
                WHEN (ac.metadata->>'difference') IS NOT NULL AND (ac.metadata->>'difference')::numeric <> 0 THEN 'warning'
                ELSE 'info'
            END AS severity,
            ac.session_id::text AS resource_id,
            ac.actor_id,
            COALESCE(NULLIF(TRIM(ac.actor_name), ''), e.name, 'Sistema') AS actor_name,
            COALESCE(NULLIF(TRIM(ac.actor_role), ''), CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END) AS actor_role,
            NULL::text AS ip_address,
            ac.created_at,
            COALESCE(ac.metadata, '{}'::jsonb) AS metadata
        FROM public.audit_caja ac
        LEFT JOIN public.employees e ON e.id = ac.actor_id
        WHERE ac.store_id = p_store_id
          AND ac.created_at >= v_start
          AND ac.created_at <= v_end
          AND v_domain IN ('todos', 'caja')

        UNION ALL

        -- 3. Ventas
        SELECT
            av.id,
            'ventas'::text AS domain,
            av.event_type,
            CASE WHEN av.event_type = 'ANULACION' THEN 'warning' ELSE 'info' END AS severity,
            av.sale_id::text AS resource_id,
            av.actor_id,
            COALESCE(NULLIF(TRIM(av.actor_name), ''), e.name, 'Administrador') AS actor_name,
            COALESCE(NULLIF(TRIM(av.actor_role), ''), CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END) AS actor_role,
            NULL::text AS ip_address,
            av.created_at,
            COALESCE(av.metadata, '{}'::jsonb) AS metadata
        FROM public.audit_ventas av
        LEFT JOIN public.employees e ON e.id = av.actor_id
        WHERE av.store_id = p_store_id
          AND av.created_at >= v_start
          AND av.created_at <= v_end
          AND v_domain IN ('todos', 'ventas')

        UNION ALL

        -- 4. Precios
        SELECT
            ap.id,
            'precios'::text AS domain,
            'PRICE_CHANGE'::text AS event_type,
            CASE WHEN COALESCE(ap.new_price, 0) < COALESCE(ap.new_cost, ap.old_cost, 0) THEN 'warning' ELSE 'info' END AS severity,
            ap.product_id::text AS resource_id,
            ap.changed_by AS actor_id,
            COALESCE(NULLIF(TRIM(ap.actor_name), ''), e.name, 'Administrador') AS actor_name,
            COALESCE(NULLIF(TRIM(ap.actor_role), ''), CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END) AS actor_role,
            NULL::text AS ip_address,
            ap.created_at,
            jsonb_build_object(
                'product_name', COALESCE(p.name, 'Producto'),
                'old_cost', ap.old_cost,
                'new_cost', ap.new_cost,
                'old_price', ap.old_price,
                'new_price', ap.new_price
            ) AS metadata
        FROM public.audit_precios ap
        LEFT JOIN public.products p ON p.id = ap.product_id
        LEFT JOIN public.employees e ON e.id = ap.changed_by
        WHERE ap.store_id = p_store_id
          AND ap.created_at >= v_start
          AND ap.created_at <= v_end
          AND v_domain IN ('todos', 'precios')

        UNION ALL

        -- 5. Inventario (Kardex inmutable)
        SELECT
            im.id,
            'inventario'::text AS domain,
            UPPER(im.movement_type) AS event_type,
            CASE WHEN im.movement_type IN ('merma', 'CORRECCION_SISTEMA', 'ajuste') THEN 'warning' ELSE 'info' END AS severity,
            im.product_id::text AS resource_id,
            im.created_by AS actor_id,
            COALESCE(NULLIF(TRIM(im.actor_name), ''), e.name, 'Administrador') AS actor_name,
            COALESCE(NULLIF(TRIM(im.actor_role), ''), CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END) AS actor_role,
            NULL::text AS ip_address,
            im.created_at,
            jsonb_build_object(
                'product_name', COALESCE(p.name, 'Producto'),
                'quantity', im.quantity,
                'unit_cost', im.unit_cost,
                'reason', im.reason,
                'invoice_reference', im.invoice_reference,
                'payment_type', im.payment_type
            ) AS metadata
        FROM public.inventory_movements im
        JOIN public.products p ON p.id = im.product_id
        LEFT JOIN public.employees e ON e.id = im.created_by
        WHERE p.store_id = p_store_id
          AND im.created_at >= v_start
          AND im.created_at <= v_end
          AND v_domain IN ('todos', 'inventario')

        UNION ALL

        -- 6a. Créditos (Ciclo de vida de clientes)
        SELECT
            cla.id,
            'creditos'::text AS domain,
            cla.event_type,
            CASE WHEN cla.event_type IN ('DELETED', 'SOFT_DELETED') THEN 'warning' ELSE 'info' END AS severity,
            cla.client_id::text AS resource_id,
            cla.actor_id,
            COALESCE(NULLIF(TRIM(cla.actor_name), ''), e.name, 'Administrador') AS actor_name,
            COALESCE(NULLIF(TRIM(cla.actor_role), ''), CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END) AS actor_role,
            NULL::text AS ip_address,
            cla.created_at,
            jsonb_build_object('client_name', COALESCE(c.name, 'Cliente'), 'source', 'client_lifecycle_audit') AS metadata
        FROM public.client_lifecycle_audit cla
        LEFT JOIN public.clients c ON c.id = cla.client_id
        LEFT JOIN public.employees e ON e.id = cla.actor_id
        WHERE cla.store_id = p_store_id
          AND cla.created_at >= v_start
          AND cla.created_at <= v_end
          AND v_domain IN ('todos', 'creditos')

        UNION ALL

        -- 6b. Créditos (Ledger contable)
        SELECT
            cl.id,
            'creditos'::text AS domain,
            UPPER(cl.transaction_type) AS event_type,
            CASE WHEN cl.transaction_type = 'anulacion_fiado' THEN 'warning' ELSE 'info' END AS severity,
            cl.client_id::text AS resource_id,
            cl.created_by AS actor_id,
            COALESCE(NULLIF(TRIM(cl.actor_name), ''), e.name, 'Administrador') AS actor_name,
            COALESCE(NULLIF(TRIM(cl.actor_role), ''), CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END) AS actor_role,
            NULL::text AS ip_address,
            cl.created_at,
            jsonb_build_object(
                'client_name', COALESCE(c.name, 'Cliente'),
                'amount', cl.amount,
                'previous_balance', cl.previous_balance,
                'new_balance', cl.new_balance,
                'reference_id', cl.reference_id
            ) AS metadata
        FROM public.client_ledger cl
        LEFT JOIN public.clients c ON c.id = cl.client_id
        LEFT JOIN public.employees e ON e.id = cl.created_by
        WHERE cl.store_id = p_store_id
          AND cl.created_at >= v_start
          AND cl.created_at <= v_end
          AND v_domain IN ('todos', 'creditos')

        UNION ALL

        -- 7. Eventos críticos/operativos de audit_logs no duplicados en audit_seguridad
        SELECT
            al.id,
            CASE
                WHEN al.event_type IN ('CASH_DISCREPANCY', 'CASH_DISCREPANCY_ALERT', 'FORCED_CLOSE_24H', 'FORCED_CLOSE_NO_COUNT', 'ADMIN_FORCED_CLOSE_NO_COUNT', 'UNAUTHORIZED_SHIFT_CLOSE') THEN 'caja'
                WHEN al.event_type IN ('SALE_VOIDED', 'FORCE_SALE') THEN 'ventas'
                WHEN al.event_type IN ('INVENTORY_COUNT_ADJUSTMENT', 'BUSINESS_CONSUMPTION', 'PERSONAL_WITHDRAWAL', 'REFUND_MERMA') THEN 'inventario'
                WHEN al.event_type IN ('CLIENT_BALANCE_OVERRIDE', 'TRANSACTION_CORRECTION') THEN 'creditos'
                ELSE 'seguridad'
            END AS domain,
            al.event_type,
            COALESCE(NULLIF(al.severity, ''), 'warning') AS severity,
            COALESCE(al.resource_id, al.id::text) AS resource_id,
            al.actor_id,
            COALESCE(NULLIF(TRIM(al.actor_name), ''), e.name, 'Sistema') AS actor_name,
            COALESCE(NULLIF(TRIM(al.actor_role), ''), CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END) AS actor_role,
            al.ip_address,
            al.created_at,
            COALESCE(al.metadata, '{}'::jsonb) || CASE WHEN al.reviewed_at IS NOT NULL THEN jsonb_build_object('reviewed_at', al.reviewed_at, 'review_notes', al.review_notes) ELSE '{}'::jsonb END AS metadata
        FROM public.audit_logs al
        LEFT JOIN public.employees e ON e.id = al.actor_id
        WHERE al.store_id = p_store_id
          AND al.created_at >= v_start
          AND al.created_at <= v_end
          AND NOT EXISTS (
              SELECT 1
              FROM public.audit_seguridad seg
              WHERE seg.store_id = al.store_id
                AND seg.event_type = al.event_type
                AND ABS(EXTRACT(EPOCH FROM (seg.created_at - al.created_at))) < 2
          )
          AND (
              v_domain = 'todos'
              OR v_domain = CASE
                  WHEN al.event_type IN ('CASH_DISCREPANCY', 'CASH_DISCREPANCY_ALERT', 'FORCED_CLOSE_24H', 'FORCED_CLOSE_NO_COUNT', 'ADMIN_FORCED_CLOSE_NO_COUNT', 'UNAUTHORIZED_SHIFT_CLOSE') THEN 'caja'
                  WHEN al.event_type IN ('SALE_VOIDED', 'FORCE_SALE') THEN 'ventas'
                  WHEN al.event_type IN ('INVENTORY_COUNT_ADJUSTMENT', 'BUSINESS_CONSUMPTION', 'PERSONAL_WITHDRAWAL', 'REFUND_MERMA') THEN 'inventario'
                  WHEN al.event_type IN ('CLIENT_BALANCE_OVERRIDE', 'TRANSACTION_CORRECTION') THEN 'creditos'
                  ELSE 'seguridad'
              END
          )
    ),
    filtered AS (
        SELECT *
        FROM unified u
        WHERE (p_event_type IS NULL OR UPPER(TRIM(p_event_type)) IN ('', 'ALL') OR u.event_type = UPPER(TRIM(p_event_type)))
          AND (p_severity IS NULL OR LOWER(TRIM(p_severity)) IN ('', 'all') OR LOWER(u.severity) = LOWER(TRIM(p_severity)))
    )
    SELECT
        (SELECT COUNT(*)::int FROM filtered),
        COALESCE(
            (SELECT jsonb_agg(row_to_json(paged))
             FROM (
                 SELECT *
                 FROM filtered
                 ORDER BY created_at DESC, id DESC
                 LIMIT v_limit OFFSET v_offset
             ) paged),
            '[]'::jsonb
        )
    INTO v_count, v_data;

    RETURN jsonb_build_object(
        'data', v_data,
        'count', v_count
    );
END;
$function$;

-- -----------------------------------------------------------------------------
-- [CHK-303] RLS unificada a public.is_store_admin(store_id) + GRANT ALL (Regla 8)
-- -----------------------------------------------------------------------------
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_caja ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_ventas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_precios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_seguridad ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_lifecycle_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_logs;
DROP POLICY IF EXISTS "System can insert audit logs" ON public.audit_logs;
DROP POLICY IF EXISTS "audit_logs_select_admin" ON public.audit_logs;
CREATE POLICY "audit_logs_select_admin" ON public.audit_logs
    FOR SELECT USING (public.is_store_admin(store_id));

DROP POLICY IF EXISTS "audit_caja_select" ON public.audit_caja;
DROP POLICY IF EXISTS "audit_caja_select_admin" ON public.audit_caja;
CREATE POLICY "audit_caja_select_admin" ON public.audit_caja
    FOR SELECT USING (public.is_store_admin(store_id));

DROP POLICY IF EXISTS "audit_ventas_select" ON public.audit_ventas;
DROP POLICY IF EXISTS "audit_ventas_select_admin" ON public.audit_ventas;
CREATE POLICY "audit_ventas_select_admin" ON public.audit_ventas
    FOR SELECT USING (public.is_store_admin(store_id));

DROP POLICY IF EXISTS "audit_precios_select" ON public.audit_precios;
DROP POLICY IF EXISTS "audit_precios_select_admin" ON public.audit_precios;
CREATE POLICY "audit_precios_select_admin" ON public.audit_precios
    FOR SELECT USING (public.is_store_admin(store_id));

DROP POLICY IF EXISTS "audit_seguridad_select_admin" ON public.audit_seguridad;
CREATE POLICY "audit_seguridad_select_admin" ON public.audit_seguridad
    FOR SELECT USING (public.is_store_admin(store_id));

DROP POLICY IF EXISTS "client_lifecycle_audit_select_admin" ON public.client_lifecycle_audit;
CREATE POLICY "client_lifecycle_audit_select_admin" ON public.client_lifecycle_audit
    FOR SELECT USING (public.is_store_admin(store_id));

GRANT ALL ON TABLE public.audit_logs TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.audit_caja TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.audit_ventas TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.audit_precios TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.audit_seguridad TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.client_lifecycle_audit TO anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- [CHK-305] SDD-021 / SDD-027-01 / SDD-003-01 §5.3:
--   1. rpc_obtener_mis_movimientos_turno (Cajero ve SOLO sus propios movimientos del turno abierto)
--   2. rpc_obtener_historial_caja_multicanal (100% Admin-only)
--   3. RLS estricta en cash_sessions (solo Admin SELECT directo) y cash_movements
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_obtener_mis_movimientos_turno(
    p_store_id uuid,
    p_payment_method text DEFAULT 'all'::text,
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_method TEXT := LOWER(TRIM(COALESCE(p_payment_method, 'all')));
    v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
    v_offset INT := GREATEST(COALESCE(p_offset, 0), 0);
    v_snap RECORD;
    v_is_admin BOOLEAN;
    v_emp_id UUID;
    v_emp_active BOOLEAN := false;
    v_has_valid_pass BOOLEAN := false;
    v_today DATE := (NOW() AT TIME ZONE 'America/Bogota')::date;
    v_session RECORD;
    v_data JSONB;
    v_count INT;
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    IF v_method NOT IN ('all', 'efectivo', 'digitales', 'nequi', 'llave_bre', 'fiado', 'consumo_personal') THEN
        RAISE EXCEPTION 'INVALID_PAYMENT_METHOD: Método de pago (%) no soportado.', p_payment_method
            USING ERRCODE = '22023';
    END IF;

    v_is_admin := public.is_store_admin(p_store_id);
    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(p_store_id);

    IF NOT v_is_admin THEN
        v_emp_id := COALESCE(public.get_employee_id_from_session(), v_snap.actor_id);

        SELECT e.id, COALESCE(e.is_active, false)
        INTO v_emp_id, v_emp_active
        FROM public.employees e
        WHERE e.id = v_emp_id
          AND e.store_id = p_store_id
        LIMIT 1;

        IF v_emp_id IS NOT NULL AND v_emp_active IS TRUE THEN
            SELECT EXISTS (
                SELECT 1
                FROM public.daily_passes dp
                WHERE dp.employee_id = v_emp_id
                  AND dp.store_id = p_store_id
                  AND dp.status = 'approved'
                  AND (
                      dp.pass_date = v_today
                      OR (
                          dp.pass_date = v_today - 1
                          AND EXISTS (
                              SELECT 1
                              FROM public.cash_sessions cs
                              WHERE cs.store_id = p_store_id
                                AND cs.status = 'open'
                                AND cs.opened_at >= (NOW() - INTERVAL '24 hours')
                          )
                      )
                  )
            ) INTO v_has_valid_pass;
        END IF;

        IF v_emp_id IS NULL OR v_emp_active IS NOT TRUE OR v_has_valid_pass IS NOT TRUE THEN
            RAISE EXCEPTION 'PERMISSION_DENIED: Colaborador inactivo o sin pase diario vigente (<24h).'
                USING ERRCODE = '42501';
        END IF;
    ELSE
        SELECT e.id INTO v_emp_id
        FROM public.employees e
        WHERE e.id = v_snap.actor_id AND e.store_id = p_store_id
        LIMIT 1;
    END IF;

    SELECT id, opened_at, opened_by_name
    INTO v_session
    FROM public.cash_sessions
    WHERE store_id = p_store_id
      AND status = 'open'
    ORDER BY opened_at DESC
    LIMIT 1;

    IF v_session.id IS NULL THEN
        RETURN jsonb_build_object(
            'data', '[]'::jsonb,
            'count', 0,
            'has_open_shift', false,
            'shift_id', NULL,
            'shift_opened_at', NULL
        );
    END IF;

    WITH own_movements AS (
        -- 1. Ventas / Fiados / Retiro Personal propios durante el turno abierto actual
        SELECT
            s.id,
            CASE
                WHEN s.payment_method = 'consumo_personal' THEN 'personal_withdrawal'::text
                ELSE 'sale'::text
            END AS source,
            s.payment_method,
            s.total AS amount,
            'Venta #' || s.ticket_number
                || CASE WHEN s.is_voided THEN ' (Anulada)' ELSE '' END
                || COALESCE(' · ' || c.name, '') AS description,
            CASE
                WHEN s.is_voided THEN 'Anulada'
                WHEN s.payment_method = 'fiado' THEN 'Fiado'
                WHEN s.payment_method = 'consumo_personal' THEN 'Retiro Personal'
                ELSE 'Venta POS'
            END AS category,
            s.created_at,
            COALESCE(NULLIF(TRIM(s.actor_name), ''), v_snap.actor_name) AS actor_name,
            COALESCE(NULLIF(TRIM(s.actor_role), ''), v_snap.actor_role) AS actor_role,
            s.ticket_number,
            NULL::text AS voucher_ref
        FROM public.sales s
        LEFT JOIN public.clients c ON c.id = s.client_id
        WHERE s.store_id = p_store_id
          AND s.created_at >= v_session.opened_at
          AND (
              (v_emp_id IS NOT NULL AND s.employee_id = v_emp_id)
              OR (v_emp_id IS NULL AND v_is_admin AND s.employee_id IS NULL)
          )

        UNION ALL

        -- 2. Movimientos de caja propios del turno abierto actual (excluye ingresos duplicados de venta regular)
        SELECT
            cm.id,
            CASE
                WHEN cm.category IN ('reembolso', 'devolucion', 'anulacion_venta')
                  OR cm.description ILIKE 'DEVOLUCIÓN%'
                  OR cm.description ILIKE '[ANULACION_VENTA%' THEN 'refund'::text
                WHEN cm.movement_type = 'gasto' THEN 'expense'::text
                WHEN cm.movement_type = 'pago_proveedor' THEN 'payment'::text
                ELSE 'payment'::text
            END AS source,
            COALESCE(cm.payment_method, 'efectivo') AS payment_method,
            cm.amount,
            cm.description,
            COALESCE(cm.category, CASE
                WHEN cm.movement_type = 'pago_proveedor' THEN 'Pago a Proveedor'
                WHEN cm.movement_type = 'gasto' THEN 'Gasto'
                ELSE 'Abono / Ingreso'
            END) AS category,
            cm.created_at,
            COALESCE(NULLIF(TRIM(cm.actor_name), ''), v_snap.actor_name) AS actor_name,
            COALESCE(NULLIF(TRIM(cm.actor_role), ''), v_snap.actor_role) AS actor_role,
            NULL::int AS ticket_number,
            cm.voucher_ref
        FROM public.cash_movements cm
        WHERE cm.session_id = v_session.id
          AND (cm.sale_id IS NULL OR cm.movement_type <> 'ingreso')
          AND (
              (v_emp_id IS NOT NULL AND cm.actor_id = v_emp_id)
              OR (v_emp_id IS NULL AND v_is_admin AND cm.actor_id IS NULL)
          )
    ),
    filtered AS (
        SELECT *
        FROM own_movements m
        WHERE (
            v_method = 'all'
            OR (v_method = 'digitales' AND m.payment_method IN ('nequi', 'llave_bre'))
            OR m.payment_method = v_method
        )
    )
    SELECT
        (SELECT COUNT(*)::int FROM filtered),
        COALESCE(
            (SELECT jsonb_agg(row_to_json(paged))
             FROM (
                 SELECT id, source, payment_method, amount, description, category, created_at, actor_name, actor_role, ticket_number, voucher_ref
                 FROM filtered
                 ORDER BY created_at DESC, id DESC
                 LIMIT v_limit OFFSET v_offset
             ) paged),
            '[]'::jsonb
        )
    INTO v_count, v_data;

    RETURN jsonb_build_object(
        'data', v_data,
        'count', v_count,
        'has_open_shift', true,
        'shift_id', v_session.id,
        'shift_opened_at', v_session.opened_at
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_obtener_historial_caja_multicanal(
    p_store_id uuid,
    p_session_id uuid DEFAULT NULL::uuid,
    p_payment_method text DEFAULT 'all'::text,
    p_start_date timestamptz DEFAULT NULL::timestamptz,
    p_end_date timestamptz DEFAULT NULL::timestamptz,
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_method TEXT := LOWER(TRIM(COALESCE(p_payment_method, 'all')));
    v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
    v_offset INT := GREATEST(COALESCE(p_offset, 0), 0);
    v_data JSONB;
    v_count INT;
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

    IF p_start_date IS NOT NULL AND p_end_date IS NOT NULL AND p_start_date > p_end_date THEN
        RAISE EXCEPTION 'INVALID_DATE_RANGE: La fecha inicial no puede ser posterior a la fecha final.'
            USING ERRCODE = '22023';
    END IF;

    IF v_method NOT IN ('all', 'efectivo', 'digitales', 'nequi', 'llave_bre') THEN
        RAISE EXCEPTION 'INVALID_PAYMENT_METHOD: Método de pago (%) no soportado.', p_payment_method
            USING ERRCODE = '22023';
    END IF;

    WITH scoped AS (
        SELECT
            cm.id,
            cm.session_id,
            cm.movement_type,
            CASE
                WHEN cm.category IN ('reembolso', 'devolucion', 'anulacion_venta')
                  OR cm.description ILIKE 'DEVOLUCIÓN%'
                  OR cm.description ILIKE '[ANULACION_VENTA%' THEN 'reembolso'::text
                WHEN cm.movement_type = 'pago_proveedor' THEN 'abono_proveedor'::text
                WHEN cm.movement_type = 'gasto' THEN 'gasto_opex'::text
                WHEN cm.sale_id IS NOT NULL THEN 'venta'::text
                ELSE 'abono'::text
            END AS origin_type,
            cm.amount,
            COALESCE(cm.payment_method, 'efectivo') AS payment_method,
            cm.description,
            cm.category,
            cm.voucher_ref,
            cm.sale_id,
            s.ticket_number,
            COALESCE(NULLIF(TRIM(cm.actor_name), ''), e.name, 'Administrador') AS actor_name,
            COALESCE(NULLIF(TRIM(cm.actor_role), ''), CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END) AS actor_role,
            cm.created_at
        FROM public.cash_movements cm
        JOIN public.cash_sessions cs ON cs.id = cm.session_id
        LEFT JOIN public.sales s ON s.id = cm.sale_id
        LEFT JOIN public.employees e ON e.id = cm.actor_id
        WHERE cs.store_id = p_store_id
          AND (p_session_id IS NULL OR cm.session_id = p_session_id)
          AND (p_start_date IS NULL OR cm.created_at >= p_start_date)
          AND (p_end_date IS NULL OR cm.created_at <= p_end_date)
          AND (
              v_method = 'all'
              OR (v_method = 'digitales' AND COALESCE(cm.payment_method, 'efectivo') IN ('nequi', 'llave_bre'))
              OR COALESCE(cm.payment_method, 'efectivo') = v_method
          )
    )
    SELECT
        (SELECT COUNT(*)::int FROM scoped),
        COALESCE(
            (SELECT jsonb_agg(row_to_json(paged))
             FROM (
                 SELECT *
                 FROM scoped
                 ORDER BY created_at DESC, id DESC
                 LIMIT v_limit OFFSET v_offset
             ) paged),
            '[]'::jsonb
        )
    INTO v_count, v_data;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_data,
        'count', v_count
    );
END;
$function$;

-- Cerrar lectura directa cruzada en cash_sessions (empleados usan get_active_cash_session / rpc_obtener_mis_movimientos_turno)
DROP POLICY IF EXISTS "cash_sessions_select_store" ON public.cash_sessions;
DROP POLICY IF EXISTS "cash_sessions_insert_store" ON public.cash_sessions;
DROP POLICY IF EXISTS "cash_sessions_update_store" ON public.cash_sessions;
DROP POLICY IF EXISTS "cash_sessions_select_admin" ON public.cash_sessions;
DROP POLICY IF EXISTS "cash_sessions_insert_admin" ON public.cash_sessions;
DROP POLICY IF EXISTS "cash_sessions_update_admin" ON public.cash_sessions;

CREATE POLICY "cash_sessions_select_admin" ON public.cash_sessions
    FOR SELECT USING (public.is_store_admin(store_id));
CREATE POLICY "cash_sessions_insert_admin" ON public.cash_sessions
    FOR INSERT WITH CHECK (public.is_store_admin(store_id));
CREATE POLICY "cash_sessions_update_admin" ON public.cash_sessions
    FOR UPDATE USING (public.is_store_admin(store_id)) WITH CHECK (public.is_store_admin(store_id));

-- En cash_movements, helper SECURITY DEFINER evita cascada RLS sobre cash_sessions:
-- Admin ve toda la tienda; colaborador solo ve sus movimientos propios en el turno abierto actual.
CREATE OR REPLACE FUNCTION public.can_read_cash_movement(p_session_id uuid, p_actor_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_store_id uuid := public.get_current_store_id();
    v_sess RECORD;
BEGIN
    IF v_store_id IS NULL THEN
        RETURN false;
    END IF;

    SELECT store_id, status
    INTO v_sess
    FROM public.cash_sessions
    WHERE id = p_session_id;

    IF NOT FOUND OR v_sess.store_id <> v_store_id THEN
        RETURN false;
    END IF;

    IF public.is_store_admin(v_sess.store_id) THEN
        RETURN true;
    END IF;

    RETURN v_sess.status = 'open'
       AND p_actor_id IS NOT NULL
       AND p_actor_id = COALESCE(public.get_employee_id_from_session(), auth.uid());
END;
$function$;

DROP POLICY IF EXISTS "cash_movements_select_store" ON public.cash_movements;
CREATE POLICY "cash_movements_select_store" ON public.cash_movements
    FOR SELECT USING (public.can_read_cash_movement(session_id, actor_id));

-- -----------------------------------------------------------------------------
-- [CHK-306] SDD-027-01 §5.3: rpc_get_comprehensive_shift_report (100% Admin-only)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_get_comprehensive_shift_report(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_session RECORD;
    v_window_end TIMESTAMPTZ;
    v_sales_cash NUMERIC := 0;
    v_sales_nequi NUMERIC := 0;
    v_sales_llave_bre NUMERIC := 0;
    v_sales_credit NUMERIC := 0;
    v_client_abonos NUMERIC := 0;
    v_opex_expenses NUMERIC := 0;
    v_refunds NUMERIC := 0;
    v_supplier_payments NUMERIC := 0;
    v_movements JSONB;
    v_voided_sales JSONB;
    v_security_alerts JSONB;
BEGIN
    SELECT cs.*,
           COALESCE(cs.opened_by_name, eo.name, 'Administrador') AS eff_opened_by_name,
           COALESCE(cs.opened_by_role, CASE WHEN eo.id IS NOT NULL THEN 'employee' ELSE 'owner' END) AS eff_opened_by_role,
           COALESCE(cs.closed_by_name, ec.name, NULL) AS eff_closed_by_name,
           cs.closed_by_role AS eff_closed_by_role
    INTO v_session
    FROM public.cash_sessions cs
    LEFT JOIN public.employees eo ON eo.id = cs.opened_by
    LEFT JOIN public.employees ec ON ec.id = cs.closed_by
    WHERE cs.id = p_session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'SESSION_NOT_FOUND: Sesión de caja (%) no encontrada.', p_session_id
            USING ERRCODE = 'P0001';
    END IF;

    PERFORM public.assert_store_admin(v_session.store_id);

    v_window_end := COALESCE(v_session.closed_at, NOW());

    SELECT
        COALESCE(SUM(cm.amount) FILTER (WHERE cm.movement_type = 'ingreso' AND cm.sale_id IS NOT NULL AND cm.payment_method = 'efectivo'), 0),
        COALESCE(SUM(cm.amount) FILTER (WHERE cm.movement_type = 'ingreso' AND cm.sale_id IS NOT NULL AND cm.payment_method = 'nequi'), 0),
        COALESCE(SUM(cm.amount) FILTER (WHERE cm.movement_type = 'ingreso' AND cm.sale_id IS NOT NULL AND cm.payment_method = 'llave_bre'), 0),
        COALESCE(SUM(cm.amount) FILTER (WHERE cm.movement_type = 'ingreso' AND cm.sale_id IS NULL), 0),
        COALESCE(SUM(cm.amount) FILTER (
            WHERE cm.movement_type = 'gasto'
              AND NOT (
                  COALESCE(cm.category, '') IN ('reembolso', 'devolucion', 'anulacion_venta')
                  OR cm.description ILIKE 'DEVOLUCIÓN%'
                  OR cm.description ILIKE '[ANULACION_VENTA%'
              )
        ), 0),
        COALESCE(SUM(cm.amount) FILTER (
            WHERE cm.movement_type = 'gasto'
              AND (
                  COALESCE(cm.category, '') IN ('reembolso', 'devolucion', 'anulacion_venta')
                  OR cm.description ILIKE 'DEVOLUCIÓN%'
                  OR cm.description ILIKE '[ANULACION_VENTA%'
              )
        ), 0),
        COALESCE(SUM(cm.amount) FILTER (WHERE cm.movement_type = 'pago_proveedor'), 0)
    INTO v_sales_cash, v_sales_nequi, v_sales_llave_bre, v_client_abonos, v_opex_expenses, v_refunds, v_supplier_payments
    FROM public.cash_movements cm
    WHERE cm.session_id = p_session_id;

    SELECT COALESCE(SUM(s.total), 0)
    INTO v_sales_credit
    FROM public.sales s
    WHERE s.store_id = v_session.store_id
      AND s.payment_method = 'fiado'
      AND s.is_voided = false
      AND s.created_at >= v_session.opened_at
      AND s.created_at <= v_window_end;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', cm.id,
                'movement_type', cm.movement_type,
                'payment_method', COALESCE(cm.payment_method, 'efectivo'),
                'category', cm.category,
                'voucher_ref', cm.voucher_ref,
                'amount', cm.amount,
                'description', cm.description,
                'actor_name', COALESCE(NULLIF(TRIM(cm.actor_name), ''), e.name, 'Administrador'),
                'actor_role', COALESCE(NULLIF(TRIM(cm.actor_role), ''), CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END),
                'created_at', cm.created_at
            )
            ORDER BY cm.created_at ASC, cm.id ASC
        ),
        '[]'::jsonb
    )
    INTO v_movements
    FROM public.cash_movements cm
    LEFT JOIN public.employees e ON e.id = cm.actor_id
    WHERE cm.session_id = p_session_id;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'sale_id', s.id,
                'ticket_number', s.ticket_number,
                'total', s.total,
                'payment_method', s.payment_method,
                'void_reason', s.void_reason,
                'voided_by_name', COALESCE(s.voided_by_name, 'Administrador'),
                'voided_by_role', COALESCE(s.voided_by_role, 'owner'),
                'voided_at', s.voided_at
            )
            ORDER BY s.voided_at DESC NULLS LAST, s.created_at DESC
        ),
        '[]'::jsonb
    )
    INTO v_voided_sales
    FROM public.sales s
    WHERE s.store_id = v_session.store_id
      AND s.is_voided = true
      AND (
          s.void_session_id = p_session_id
          OR (s.created_at >= v_session.opened_at AND s.created_at <= v_window_end)
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', al.id,
                'event_type', al.event_type,
                'severity', al.severity,
                'actor_name', COALESCE(NULLIF(TRIM(al.actor_name), ''), 'Sistema'),
                'actor_role', COALESCE(NULLIF(TRIM(al.actor_role), ''), 'employee'),
                'created_at', al.created_at,
                'metadata', al.metadata
            )
            ORDER BY al.created_at DESC
        ),
        '[]'::jsonb
    )
    INTO v_security_alerts
    FROM public.audit_logs al
    WHERE al.store_id = v_session.store_id
      AND (
          al.resource_id = p_session_id::text
          OR al.metadata->>'session_id' = p_session_id::text
          OR (al.created_at >= v_session.opened_at AND al.created_at <= v_window_end)
      );

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'session', jsonb_build_object(
                'id', v_session.id,
                'store_id', v_session.store_id,
                'status', v_session.status,
                'forced_close', COALESCE(v_session.forced_close, false),
                'forced_close_without_count', COALESCE(v_session.forced_close_without_count, false),
                'closing_attempts', COALESCE(v_session.closing_attempts, 0),
                'opened_at', v_session.opened_at,
                'closed_at', v_session.closed_at,
                'opened_by_name', v_session.eff_opened_by_name,
                'opened_by_role', v_session.eff_opened_by_role,
                'closed_by_name', v_session.eff_closed_by_name,
                'closed_by_role', v_session.eff_closed_by_role,
                'opening_balance', v_session.opening_balance,
                'expected_balance', v_session.expected_balance,
                'actual_balance', v_session.actual_balance,
                'difference', v_session.difference
            ),
            'financial_summary', jsonb_build_object(
                'total_sales_cash', v_sales_cash,
                'total_sales_nequi', v_sales_nequi,
                'total_sales_llave_bre', v_sales_llave_bre,
                'total_sales_transfer', v_sales_nequi + v_sales_llave_bre,
                'total_credit_sales', v_sales_credit,
                'total_client_abonos', v_client_abonos,
                'total_opex_expenses', v_opex_expenses,
                'total_refunds', v_refunds,
                'total_supplier_payments', v_supplier_payments,
                'net_cash_flow', (v_sales_cash + v_sales_nequi + v_sales_llave_bre + v_client_abonos) - (v_opex_expenses + v_refunds + v_supplier_payments)
            ),
            'movements', v_movements,
            'operational_noise', jsonb_build_object(
                'voided_sales', v_voided_sales,
                'security_alerts', v_security_alerts
            )
        )
    );
END;
$function$;

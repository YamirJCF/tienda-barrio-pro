-- Migration: 20261017133000_wave4_histories_audit_and_smart_reports.sql
-- Description: Wave 4 - Historiales Multicanal, Auditoría Forense y Reportes Inteligentes
-- SDDs Certified: SDD_005_AUDITORIA_TRAZABILIDAD, SDD_008_REPORTES, SDD_018_CONTROL_OPERACIONAL, SDD_021_HISTORIALES_MULTICANAL, SDD_027_01_REPORTES_CAJA

-- 1. Modificación de esquema en public.audit_logs
ALTER TABLE public.audit_logs 
    ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS review_notes TEXT;

-- Privilegios base (Regla 8)
GRANT ALL ON TABLE public.audit_logs TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.suppliers TO anon, authenticated, service_role;

-- 2. Limpieza preventiva de firmas
DROP FUNCTION IF EXISTS public.rpc_marcar_auditoria_revisada(UUID, TEXT);
DROP FUNCTION IF EXISTS public.get_history_creditos(UUID, TIMESTAMPTZ, TIMESTAMPTZ);
DROP FUNCTION IF EXISTS public.get_history_caja(UUID, DATE, DATE);
DROP FUNCTION IF EXISTS public.get_smart_supply_report(UUID);
DROP FUNCTION IF EXISTS public.rpc_asignar_proveedor_masivo(UUID, UUID, UUID[]);
DROP FUNCTION IF EXISTS public.rpc_bulk_assign_supplier(UUID, UUID, UUID[]);
DROP FUNCTION IF EXISTS public.rpc_get_comprehensive_financial_report(UUID, DATE, DATE);
DROP FUNCTION IF EXISTS public.rpc_get_comprehensive_financial_report(UUID, DATE, DATE, UUID);
DROP FUNCTION IF EXISTS public.get_financial_Summary(UUID, DATE, DATE);
DROP FUNCTION IF EXISTS public.get_financial_Summary(UUID, DATE, DATE, UUID);

-- 3. rpc_marcar_auditoria_revisada (Visado Forense de Auditoría Administrativa)
CREATE OR REPLACE FUNCTION public.rpc_marcar_auditoria_revisada(
    p_audit_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_audit RECORD;
    v_role TEXT;
BEGIN
    SELECT * INTO v_audit FROM public.audit_logs WHERE id = p_audit_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Registro de auditoría no encontrado (AUDIT_NOT_FOUND)' USING ERRCODE = 'P0001';
    END IF;

    -- Regla 4: Aislamiento Multi-Tenant
    PERFORM public.assert_store_access(v_audit.store_id);

    -- Validación de Rol Administrativo
    SELECT role INTO v_role 
    FROM public.admin_profiles 
    WHERE id = auth.uid() AND store_id = v_audit.store_id;

    IF v_role IS NULL OR v_role NOT IN ('admin', 'owner') THEN
        RAISE EXCEPTION 'Solo administradores pueden visar auditorías (UNAUTHORIZED)' USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.audit_logs
    SET reviewed_by = auth.uid(),
        reviewed_at = NOW(),
        review_notes = p_notes,
        metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{status}', '"reviewed"')
    WHERE id = p_audit_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'audit_id', p_audit_id,
            'reviewed_at', NOW(),
            'reviewed_by', auth.uid()
        )
    );
END;
$function$;

-- 4. get_history_creditos (Corrección de Bug 42703 cl.description)
CREATE OR REPLACE FUNCTION public.get_history_creditos(
    p_store_id UUID,
    p_start_date TIMESTAMPTZ DEFAULT (now() - '30 days'::interval),
    p_end_date TIMESTAMPTZ DEFAULT now()
)
RETURNS TABLE(
    id UUID,
    client_name TEXT,
    transaction_type TEXT,
    amount NUMERIC,
    previous_balance NUMERIC,
    new_balance NUMERIC,
    description TEXT,
    employee_name TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
    PERFORM public.assert_store_access(p_store_id);

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
        COALESCE(e.name, 'Administrador') AS employee_name,
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

-- 5. get_history_caja (Enriquecimiento Multicanal con 12 Columnas Escalares)
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
    PERFORM public.assert_store_access(p_store_id);

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
                WHERE cm.session_id = cs.id AND cm.movement_type = 'gasto'
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
        ) as row_data,
        cs.opened_at
        FROM public.cash_sessions cs
        LEFT JOIN public.employees eo ON eo.id = cs.opened_by
        LEFT JOIN public.employees ec ON ec.id = cs.closed_by
        LEFT JOIN public.admin_profiles ap_open ON ap_open.id = cs.opened_by
        LEFT JOIN public.admin_profiles ap_close ON ap_close.id = cs.closed_by
        WHERE cs.store_id = p_store_id
          AND cs.opened_at >= p_start_date::TIMESTAMPTZ
          AND cs.opened_at < (p_end_date + 1)::TIMESTAMPTZ
        LIMIT 100
    ) sub;

    RETURN v_result;
END;
$function$;

-- 6. get_smart_supply_report (Filtro is_active, Umbral de Silencio 15 días y Saturación)
CREATE OR REPLACE FUNCTION public.get_smart_supply_report(p_store_id UUID)
RETURNS TABLE(
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
SET search_path TO 'public'
AS $function$
DECLARE
    v_window_days INT := 30;
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    RETURN QUERY
    WITH sales_stats AS (
        SELECT 
            si.product_id, 
            SUM(si.quantity) as total_sold, 
            COUNT(DISTINCT DATE(si.created_at)) as days_sold
        FROM public.sale_items si 
        JOIN public.sales s ON si.sale_id = s.id
        WHERE s.store_id = p_store_id 
          AND s.created_at >= (NOW() - (v_window_days || ' days')::INTERVAL)
          AND s.is_voided = false
        GROUP BY si.product_id
    ),
    product_calc AS (
        SELECT 
            p.id, 
            p.name, 
            p.current_stock, 
            p.price,
            p.created_at as product_created_at,
            COALESCE(ss.total_sold, 0) as total_sold, 
            COALESCE(ss.total_sold, 0) / NULLIF(v_window_days, 0) as velocity, 
            COALESCE(sup.frequency_days, 7) as frequency_days, 
            COALESCE(sup.lead_time_days, 1) as lead_time_days
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
        END as doi,
        CASE 
            WHEN pc.product_created_at > (NOW() - INTERVAL '15 days') THEN 0
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days 
                THEN ROUND((pc.lead_time_days - (COALESCE(pc.current_stock, 0) / pc.velocity)) * pc.velocity * COALESCE(pc.price, 0)) 
            ELSE 0 
        END as revenue_at_risk,
        CASE 
            -- RN-008-02: Umbral de Silencio (Productos con < 15 días de creación)
            WHEN pc.product_created_at > (NOW() - INTERVAL '15 days') THEN 'LEARNING'
            WHEN pc.velocity = 0 THEN 'UNKNOWN' 
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days THEN 'CRITICAL' 
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < (pc.lead_time_days + pc.frequency_days) THEN 'WARNING' 
            ELSE 'OK' 
        END::TEXT as status,
        CASE 
            WHEN pc.product_created_at > (NOW() - INTERVAL '15 days') THEN 'Aprendiendo de tus ventas...'
            WHEN pc.velocity = 0 THEN 'Recopilando datos...' 
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days THEN 'Pedir urgente: se agotará antes de la próxima entrega.' 
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < (pc.lead_time_days + pc.frequency_days) THEN 'Incluir en próximo pedido.' 
            ELSE 'Stock suficiente por ahora.' 
        END::TEXT as suggestion
    FROM product_calc pc;
END;
$function$;

-- 7. rpc_asignar_proveedor_masivo (Asignación Atómica de Proveedor a Lote de Productos)
CREATE OR REPLACE FUNCTION public.rpc_asignar_proveedor_masivo(
    p_store_id UUID,
    p_supplier_id UUID,
    p_product_ids UUID[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_role TEXT;
    v_updated_count INTEGER;
BEGIN
    -- 1. Regla 4: Aislamiento Multi-Tenant
    PERFORM public.assert_store_access(p_store_id);

    -- 2. Permiso Administrador
    SELECT role INTO v_role 
    FROM public.admin_profiles 
    WHERE id = auth.uid() AND store_id = p_store_id;

    IF v_role IS NULL OR v_role NOT IN ('admin', 'owner') THEN
        RAISE EXCEPTION 'Solo administradores pueden reasignar proveedores (UNAUTHORIZED_ROLE)' USING ERRCODE = 'P0001';
    END IF;

    -- 3. Validar lista no vacía
    IF p_product_ids IS NULL OR cardinality(p_product_ids) = 0 THEN
        RAISE EXCEPTION 'La lista de productos no puede estar vacía (EMPTY_PRODUCT_LIST)' USING ERRCODE = 'P0001';
    END IF;

    -- 4. Validar existencia del proveedor en la tienda
    IF NOT EXISTS (SELECT 1 FROM public.suppliers WHERE id = p_supplier_id AND store_id = p_store_id) THEN
        RAISE EXCEPTION 'Proveedor no encontrado en esta tienda (SUPPLIER_NOT_FOUND)' USING ERRCODE = 'P0001';
    END IF;

    -- 5. Actualizar productos
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

-- Alias
CREATE OR REPLACE FUNCTION public.rpc_bulk_assign_supplier(
    p_store_id UUID,
    p_supplier_id UUID,
    p_product_ids UUID[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
    RETURN public.rpc_asignar_proveedor_masivo(p_store_id, p_supplier_id, p_product_ids);
END;
$function$;

-- 8. rpc_get_comprehensive_financial_report (Guarda Anti-DoS 366 Días y Soporte de p_employee_id)
CREATE OR REPLACE FUNCTION public.rpc_get_comprehensive_financial_report(
    p_store_id UUID,
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_employee_id UUID DEFAULT NULL
)
RETURNS JSONB
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
    -- 1. Regla 4: Aislamiento Multi-Tenant
    PERFORM public.assert_store_access(p_store_id);

    -- 2. Guardas Anti-DoS y Validación de Rango (CL-018-07 & CL-018-08)
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION 'La fecha de inicio no puede ser posterior a la fecha de fin (INVALID_DATE_RANGE)' USING ERRCODE = 'P0001';
    END IF;

    IF (p_end_date - p_start_date) > 366 THEN
        RAISE EXCEPTION 'El rango máximo permitido para el reporte financiero es de 366 días (RANGE_EXCEEDS_MAX_LIMIT)' USING ERRCODE = 'P0001';
    END IF;

    -- Validar empleado opcional si se suministra (CL-018-09)
    IF p_employee_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.employees WHERE id = p_employee_id AND store_id = p_store_id) THEN
            RAISE EXCEPTION 'El colaborador seleccionado no pertenece a este establecimiento (EMPLOYEE_NOT_FOUND)' USING ERRCODE = 'P0001';
        END IF;
    END IF;

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

    -- 6. VALOR DE INVENTARIO (capital en stock al momento actual)
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
                        WHERE payment_method NOT IN ('nequi','daviplata','fiado','bre')
                    ), 0),
        'transfer', COALESCE(SUM(total) FILTER (
                        WHERE payment_method IN ('nequi','daviplata','bre')
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

    -- 8. FIADO PENDIENTE TOTAL
    SELECT COALESCE(SUM(balance), 0)
    INTO v_fiado_pendiente
    FROM public.clients
    WHERE store_id  = p_store_id
      AND (is_deleted = FALSE OR is_deleted IS NULL)
      AND balance    > 0;

    -- 9. SEMÁFORO DE RENDIMIENTO
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
END;
$function$;

-- Alias get_financial_Summary
CREATE OR REPLACE FUNCTION public.get_financial_Summary(
    p_store_id UUID,
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_employee_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
    RETURN public.rpc_get_comprehensive_financial_report(p_store_id, p_start_date, p_end_date, p_employee_id);
END;
$function$;

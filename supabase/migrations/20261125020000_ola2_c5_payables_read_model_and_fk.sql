-- WO-OLA2-C5-001 (UX-ADR-005): Read Model de Cuentas por Pagar, FK de Proveedor y Directorio con Deuda SQL
-- Regla 2: Verificado contra esquema real de public.suppliers (9 cols) y public.supplier_invoices (8 cols).
-- Regla 4: Todos los RPCs ejecutan assert_store_access(p_store_id) + assert_store_admin(p_store_id).
-- Regla 8: Privilegios explícitos REVOKE anon/PUBLIC + GRANT authenticated/service_role.

CREATE OR REPLACE FUNCTION public.rpc_obtener_cuentas_por_pagar(
    p_store_id UUID,
    p_status TEXT DEFAULT NULL::TEXT,
    p_supplier_id UUID DEFAULT NULL::UUID,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
    v_status_filter TEXT := NULLIF(LOWER(TRIM(COALESCE(p_status, ''))), '');
    v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
    v_offset INTEGER := GREATEST(COALESCE(p_offset, 0), 0);
    v_total_count INTEGER := 0;
    v_summary JSONB;
    v_rows JSONB;
BEGIN
    PERFORM public.assert_store_access(p_store_id);
    PERFORM public.assert_store_admin(p_store_id);

    WITH base AS (
        SELECT
            si.id,
            si.store_id,
            si.supplier_id,
            s.name AS supplier_name,
            si.invoice_number,
            si.total_amount,
            si.amount_paid,
            GREATEST(0, si.total_amount - si.amount_paid) AS pending_balance,
            si.due_date,
            si.created_at,
            CASE
                WHEN si.amount_paid >= si.total_amount THEN 'pagada'
                WHEN si.due_date IS NOT NULL AND si.due_date < v_today THEN 'vencida'
                ELSE 'pendiente'
            END AS computed_status
        FROM public.supplier_invoices si
        LEFT JOIN public.suppliers s ON s.id = si.supplier_id
        WHERE si.store_id = p_store_id
          AND (p_supplier_id IS NULL OR si.supplier_id = p_supplier_id)
    ),
    summary_agg AS (
        SELECT
            COALESCE(SUM(pending_balance) FILTER (WHERE computed_status <> 'pagada'), 0) AS total_debt,
            COALESCE(SUM(pending_balance) FILTER (WHERE computed_status = 'vencida'), 0) AS total_overdue,
            COUNT(*) FILTER (WHERE computed_status = 'pendiente') AS pending_count,
            COUNT(*) FILTER (WHERE computed_status = 'vencida') AS overdue_count
        FROM base
    ),
    filtered AS (
        SELECT *
        FROM base
        WHERE v_status_filter IS NULL
           OR v_status_filter = 'todos'
           OR computed_status = v_status_filter
    ),
    paged AS (
        SELECT *
        FROM filtered
        ORDER BY
            CASE computed_status
                WHEN 'vencida' THEN 0
                WHEN 'pendiente' THEN 1
                ELSE 2
            END ASC,
            due_date ASC NULLS LAST,
            created_at DESC
        LIMIT v_limit
        OFFSET v_offset
    )
    SELECT
        jsonb_build_object(
            'total_debt', sa.total_debt,
            'total_overdue', sa.total_overdue,
            'pending_count', sa.pending_count,
            'overdue_count', sa.overdue_count
        ),
        (SELECT COUNT(*) FROM filtered),
        COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', p.id,
                        'store_id', p.store_id,
                        'supplier_id', p.supplier_id,
                        'supplier', jsonb_build_object('name', COALESCE(p.supplier_name, 'Desconocido')),
                        'invoice_number', p.invoice_number,
                        'total_amount', p.total_amount,
                        'amount_paid', p.amount_paid,
                        'pending_balance', p.pending_balance,
                        'due_date', p.due_date,
                        'status', p.computed_status,
                        'created_at', p.created_at
                    )
                    ORDER BY
                        CASE p.computed_status
                            WHEN 'vencida' THEN 0
                            WHEN 'pendiente' THEN 1
                            ELSE 2
                        END ASC,
                        p.due_date ASC NULLS LAST,
                        p.created_at DESC
                )
                FROM paged p
            ),
            '[]'::jsonb
        )
    INTO v_summary, v_total_count, v_rows
    FROM summary_agg sa;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_rows,
        'count', v_total_count,
        'summary', v_summary
    );
END;
$function$;

DROP FUNCTION IF EXISTS public.rpc_crear_factura_proveedor(UUID, TEXT, NUMERIC, DATE, TEXT);

CREATE OR REPLACE FUNCTION public.rpc_crear_factura_proveedor(
    p_store_id UUID,
    p_supplier_id UUID DEFAULT NULL::UUID,
    p_supplier_name TEXT DEFAULT NULL::TEXT,
    p_total_amount NUMERIC DEFAULT NULL::NUMERIC,
    p_due_date DATE DEFAULT NULL::DATE,
    p_invoice_number TEXT DEFAULT NULL::TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_supplier_clean TEXT;
    v_supplier_id UUID;
    v_invoice RECORD;
    v_ref_clean TEXT := NULLIF(TRIM(COALESCE(p_invoice_number, '')), '');
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
BEGIN
    PERFORM public.assert_store_access(p_store_id);
    PERFORM public.assert_store_admin(p_store_id);

    IF p_total_amount IS NULL OR p_total_amount <= 0 THEN
        RAISE EXCEPTION 'INVALID_AMOUNT: El valor total de la factura debe ser mayor a cero.'
            USING ERRCODE = '22023';
    END IF;

    IF p_supplier_id IS NOT NULL THEN
        SELECT id, name
        INTO v_supplier_id, v_supplier_clean
        FROM public.suppliers
        WHERE id = p_supplier_id
          AND store_id = p_store_id
        LIMIT 1;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'SUPPLIER_NOT_FOUND: El proveedor seleccionado no existe en esta tienda.'
                USING ERRCODE = 'P0002';
        END IF;
    ELSE
        v_supplier_clean := initcap(regexp_replace(trim(COALESCE(p_supplier_name, '')), '\s+', ' ', 'g'));
        IF length(v_supplier_clean) < 2 THEN
            RAISE EXCEPTION 'INVALID_SUPPLIER_NAME: El nombre del proveedor es obligatorio (mínimo 2 caracteres).'
                USING ERRCODE = '22023';
        END IF;

        SELECT id, name
        INTO v_supplier_id, v_supplier_clean
        FROM public.suppliers
        WHERE store_id = p_store_id
          AND LOWER(TRIM(name)) = LOWER(v_supplier_clean)
        LIMIT 1;

        IF v_supplier_id IS NULL THEN
            INSERT INTO public.suppliers (store_id, name, frequency_days, lead_time_days, is_default)
            VALUES (p_store_id, v_supplier_clean, 15, 1, false)
            RETURNING id, name INTO v_supplier_id, v_supplier_clean;
        END IF;
    END IF;

    INSERT INTO public.supplier_invoices (
        store_id, supplier_id, total_amount, amount_paid, due_date, invoice_number
    ) VALUES (
        p_store_id, v_supplier_id, p_total_amount, 0, p_due_date, v_ref_clean
    ) RETURNING * INTO v_invoice;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'invoice', jsonb_build_object(
                'id', v_invoice.id,
                'store_id', v_invoice.store_id,
                'supplier_id', v_invoice.supplier_id,
                'supplier', jsonb_build_object('id', v_supplier_id, 'name', v_supplier_clean),
                'invoice_number', v_invoice.invoice_number,
                'total_amount', v_invoice.total_amount,
                'amount_paid', v_invoice.amount_paid,
                'pending_balance', GREATEST(0, v_invoice.total_amount - v_invoice.amount_paid),
                'due_date', v_invoice.due_date,
                'status', CASE
                    WHEN v_invoice.due_date IS NOT NULL AND v_invoice.due_date < v_today THEN 'vencida'
                    ELSE 'pendiente'
                END,
                'created_at', v_invoice.created_at
            )
        )
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_obtener_proveedores_con_cxp(
    p_store_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_rows JSONB;
BEGIN
    PERFORM public.assert_store_access(p_store_id);
    PERFORM public.assert_store_admin(p_store_id);

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', s.id,
                'store_id', s.store_id,
                'name', s.name,
                'delivery_day', s.delivery_day,
                'frequency_days', s.frequency_days,
                'lead_time_days', s.lead_time_days,
                'is_default', s.is_default,
                'created_at', s.created_at,
                'updated_at', s.updated_at,
                'pending_debt', COALESCE(cxp.pending_debt, 0),
                'open_invoices_count', COALESCE(cxp.open_invoices_count, 0)
            )
            ORDER BY s.is_default DESC, s.name ASC
        ),
        '[]'::jsonb
    )
    INTO v_rows
    FROM public.suppliers s
    LEFT JOIN LATERAL (
        SELECT
            COALESCE(SUM(GREATEST(0, si.total_amount - si.amount_paid)) FILTER (WHERE si.total_amount > si.amount_paid), 0) AS pending_debt,
            COUNT(si.id) FILTER (WHERE si.total_amount > si.amount_paid)::INTEGER AS open_invoices_count
        FROM public.supplier_invoices si
        WHERE si.store_id = p_store_id
          AND si.supplier_id = s.id
    ) cxp ON TRUE
    WHERE s.store_id = p_store_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_rows
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_obtener_cuentas_por_pagar(UUID, TEXT, UUID, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_obtener_cuentas_por_pagar(UUID, TEXT, UUID, INTEGER, INTEGER) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_crear_factura_proveedor(UUID, UUID, TEXT, NUMERIC, DATE, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_crear_factura_proveedor(UUID, UUID, TEXT, NUMERIC, DATE, TEXT) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_obtener_proveedores_con_cxp(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_obtener_proveedores_con_cxp(UUID) TO authenticated, service_role;

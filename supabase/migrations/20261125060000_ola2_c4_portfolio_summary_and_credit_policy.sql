-- WO-OLA2-C4-001 (UX-ADR-006): Resumen global de cartera en SQL y política de cupo global
-- Regla 2: Verificado contra esquema real de public.clients (11 cols) y public.stores.default_credit_limit (numeric).
-- Regla 4: rpc_admin_get_clients conserva assert_store_access + assert_employee_permission('canFiar') para Admin y canFiar;
--          rpc_actualizar_cupo_credito_global exige assert_store_access + assert_store_admin.
-- Regla 8: Privilegios explícitos REVOKE PUBLIC/anon + GRANT authenticated/service_role.

CREATE OR REPLACE FUNCTION public.rpc_admin_get_clients(
    p_store_id UUID,
    p_filter_debt TEXT DEFAULT 'todos'::TEXT,
    p_search_query TEXT DEFAULT NULL::TEXT,
    p_order_by TEXT DEFAULT 'name_asc'::TEXT,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_total_count INTEGER := 0;
    v_total_portfolio_debt NUMERIC := 0;
    v_debtors_count INTEGER := 0;
    v_clients JSONB;
    v_filter TEXT := COALESCE(NULLIF(trim(p_filter_debt), ''), 'todos');
    v_search TEXT := NULLIF(trim(COALESCE(p_search_query, '')), '');
BEGIN
    PERFORM public.assert_store_access(p_store_id);
    PERFORM public.assert_employee_permission(p_store_id, 'canFiar');

    -- Totales globales autoritativos sobre TODOS los clientes activos de la tienda (nunca truncados por paginación/filtro)
    SELECT
        COALESCE(SUM(GREATEST(c.balance, 0)), 0),
        COUNT(*) FILTER (WHERE c.balance > 0)::INTEGER
    INTO v_total_portfolio_debt, v_debtors_count
    FROM public.clients c
    WHERE c.store_id = p_store_id
      AND COALESCE(c.is_deleted, false) = false;

    SELECT COUNT(*) INTO v_total_count
    FROM public.clients c
    WHERE c.store_id = p_store_id
      AND COALESCE(c.is_deleted, false) = false
      AND (
          v_filter = 'todos'
          OR (v_filter = 'con_deuda' AND c.balance > 0)
          OR (v_filter IN ('sin_deuda', 'al_dia') AND c.balance <= 0)
      )
      AND (
          v_search IS NULL
          OR c.name ILIKE '%' || v_search || '%'
          OR c.id_number ILIKE '%' || v_search || '%'
          OR c.phone ILIKE '%' || v_search || '%'
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', c.id,
                'store_id', c.store_id,
                'name', c.name,
                'id_number', c.id_number,
                'phone', c.phone,
                'credit_limit', c.credit_limit,
                'balance', c.balance,
                'credit_available', GREATEST(0, c.credit_limit - c.balance),
                'credit_usage_pct', CASE WHEN c.credit_limit > 0 THEN ROUND((c.balance / c.credit_limit) * 100, 1) ELSE 0 END,
                'created_at', c.created_at
            ) ORDER BY
                CASE WHEN p_order_by = 'balance_desc' THEN c.balance END DESC NULLS LAST,
                CASE WHEN p_order_by = 'balance_asc' THEN c.balance END ASC NULLS LAST,
                CASE WHEN p_order_by = 'name_asc' THEN c.name END ASC,
                CASE WHEN p_order_by = 'name_desc' THEN c.name END DESC,
                c.created_at DESC
        ),
        '[]'::jsonb
    ) INTO v_clients
    FROM (
        SELECT c.*
        FROM public.clients c
        WHERE c.store_id = p_store_id
          AND COALESCE(c.is_deleted, false) = false
          AND (
              v_filter = 'todos'
              OR (v_filter = 'con_deuda' AND c.balance > 0)
              OR (v_filter IN ('sin_deuda', 'al_dia') AND c.balance <= 0)
          )
          AND (
              v_search IS NULL
              OR c.name ILIKE '%' || v_search || '%'
              OR c.id_number ILIKE '%' || v_search || '%'
              OR c.phone ILIKE '%' || v_search || '%'
          )
        ORDER BY
            CASE WHEN p_order_by = 'balance_desc' THEN c.balance END DESC NULLS LAST,
            CASE WHEN p_order_by = 'balance_asc' THEN c.balance END ASC NULLS LAST,
            CASE WHEN p_order_by = 'name_asc' THEN c.name END ASC,
            CASE WHEN p_order_by = 'name_desc' THEN c.name END DESC,
            c.created_at DESC
        LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    ) c;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_clients,
        'count', v_total_count,
        'total_portfolio_debt', v_total_portfolio_debt,
        'debtors_count', v_debtors_count
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_actualizar_cupo_credito_global(
    p_store_id UUID,
    p_default_credit_limit NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    PERFORM public.assert_store_access(p_store_id);
    PERFORM public.assert_store_admin(p_store_id);

    IF p_default_credit_limit IS NULL OR p_default_credit_limit < 0 THEN
        RAISE EXCEPTION 'INVALID_CREDIT_LIMIT: El cupo por defecto debe ser mayor o igual a cero.'
            USING ERRCODE = '22023';
    END IF;

    UPDATE public.stores
    SET default_credit_limit = p_default_credit_limit,
        updated_at = NOW()
    WHERE id = p_store_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'STORE_NOT_FOUND: Tienda no encontrada.' USING ERRCODE = 'P0002';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'store_id', p_store_id,
            'default_credit_limit', p_default_credit_limit
        )
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_admin_get_clients(UUID, TEXT, TEXT, TEXT, INTEGER, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_admin_get_clients(UUID, TEXT, TEXT, TEXT, INTEGER, INTEGER) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_actualizar_cupo_credito_global(UUID, NUMERIC) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_actualizar_cupo_credito_global(UUID, NUMERIC) TO authenticated, service_role;

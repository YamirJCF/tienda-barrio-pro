-- ============================================================================
-- Migración: WO-OLA2-C6-001 — Enlaces Contextuales en get_sale_detail (C6-H2)
-- Fecha: 2026-11-25
-- Alcance:
--   Actualiza public.get_sale_detail(p_sale_id UUID) para:
--     1) Preservar PERFORM public.assert_store_access(v_sale.store_id) y exigir assert_store_admin(v_sale.store_id) (POL-AUD-02)
--     2) Incluir client_id en la raíz y dentro de data
--     3) Incluir product_id en cada elemento de items[]
--   Aplica privilegios explícitos (Regla 8): REVOKE anon/PUBLIC; GRANT authenticated/service_role.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_sale_detail(p_sale_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_sale RECORD;
    v_items JSONB;
BEGIN
    SELECT
        s.id, s.store_id, s.ticket_number, s.total, s.rounding_difference,
        s.payment_method, s.amount_received, s.change_given,
        s.is_voided, s.void_reason, s.void_session_id, s.voided_at, s.created_at,
        s.client_id,
        COALESCE(e.name, 'Administrador') AS employee_name,
        c.name AS client_name
    INTO v_sale
    FROM public.sales s
    LEFT JOIN public.employees e ON e.id = s.employee_id
    LEFT JOIN public.clients c ON c.id = s.client_id
    WHERE s.id = p_sale_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venta no encontrada (SALE_NOT_FOUND)' USING ERRCODE = 'P0001';
    END IF;

    -- Regla 4 + POL-AUD-02: Aislamiento Multi-Tenant y acceso exclusivo Admin
    PERFORM public.assert_store_access(v_sale.store_id);
    PERFORM public.assert_store_admin(v_sale.store_id);

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'product_id', si.product_id,
            'product_name', p.name,
            'quantity', si.quantity,
            'unit_price', si.unit_price,
            'subtotal', si.subtotal
        ) ORDER BY si.created_at
    ), '[]'::jsonb)
    INTO v_items
    FROM public.sale_items si
    JOIN public.products p ON p.id = si.product_id
    WHERE si.sale_id = p_sale_id;

    RETURN jsonb_build_object(
        'success', true,
        'ticket_number', v_sale.ticket_number,
        'total', v_sale.total,
        'rounding_difference', COALESCE(v_sale.rounding_difference, 0),
        'payment_method', v_sale.payment_method,
        'amount_received', v_sale.amount_received,
        'change_given', v_sale.change_given,
        'employee_name', v_sale.employee_name,
        'client_id', v_sale.client_id,
        'client_name', v_sale.client_name,
        'is_voided', COALESCE(v_sale.is_voided, false),
        'void_reason', v_sale.void_reason,
        'void_session_id', v_sale.void_session_id,
        'voided_at', v_sale.voided_at,
        'created_at', v_sale.created_at,
        'items', v_items,
        'items_count', jsonb_array_length(v_items),
        'data', jsonb_build_object(
            'id', v_sale.id,
            'ticket_number', v_sale.ticket_number,
            'total', v_sale.total,
            'rounding_difference', COALESCE(v_sale.rounding_difference, 0),
            'payment_method', v_sale.payment_method,
            'amount_received', v_sale.amount_received,
            'change_given', v_sale.change_given,
            'employee_name', v_sale.employee_name,
            'client_id', v_sale.client_id,
            'client_name', v_sale.client_name,
            'is_voided', COALESCE(v_sale.is_voided, false),
            'void_reason', v_sale.void_reason,
            'void_session_id', v_sale.void_session_id,
            'voided_at', v_sale.voided_at,
            'created_at', v_sale.created_at,
            'items', v_items,
            'items_count', jsonb_array_length(v_items)
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_sale_detail(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_sale_detail(UUID) TO authenticated, service_role;

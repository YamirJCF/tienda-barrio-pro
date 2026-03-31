-- ==============================================================================
-- MIGRATION: RPC get_sale_detail
-- Date: 2026-02-16
-- Ref: FRD_Reportes_Historiales_v1.0.md — Feature F4.3 (AC-12)
-- Description:
--   Returns complete sale detail including line items for the detail modal.
--   Uses assert_store_access for ownership validation.
-- ==============================================================================

CREATE OR REPLACE FUNCTION get_sale_detail(p_sale_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_sale RECORD;
    v_items JSONB;
    v_store_id UUID;
BEGIN
    -- 1. Get the sale and its store_id
    SELECT
        s.id, s.store_id, s.ticket_number, s.total,
        s.payment_method, s.amount_received, s.change_given,
        s.is_voided, s.void_reason, s.created_at,
        COALESCE(e.name, 'Administrador') AS employee_name,
        c.name AS client_name
    INTO v_sale
    FROM sales s
    LEFT JOIN employees e ON e.id = s.employee_id
    LEFT JOIN clients c ON c.id = s.client_id
    WHERE s.id = p_sale_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Venta no encontrada');
    END IF;

    -- 2. SECURITY: Validate store ownership
    PERFORM assert_store_access(v_sale.store_id);

    -- 3. Get line items
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'product_name', p.name,
            'quantity', si.quantity,
            'unit_price', si.unit_price,
            'subtotal', si.subtotal
        ) ORDER BY si.created_at
    ), '[]'::jsonb)
    INTO v_items
    FROM sale_items si
    JOIN products p ON p.id = si.product_id
    WHERE si.sale_id = p_sale_id;

    -- 4. Return complete payload
    RETURN jsonb_build_object(
        'success', true,
        'ticket_number', v_sale.ticket_number,
        'total', v_sale.total,
        'payment_method', v_sale.payment_method,
        'amount_received', v_sale.amount_received,
        'change_given', v_sale.change_given,
        'employee_name', v_sale.employee_name,
        'client_name', v_sale.client_name,
        'is_voided', COALESCE(v_sale.is_voided, false),
        'void_reason', v_sale.void_reason,
        'created_at', v_sale.created_at,
        'items', v_items,
        'items_count', jsonb_array_length(v_items)
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Error interno del servidor');
END;
$$;

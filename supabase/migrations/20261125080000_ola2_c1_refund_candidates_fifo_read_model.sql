-- ============================================================================
-- Migración: WO-OLA2-C1-001 — Read Model FIFO en Reembolsos (C1-H4)
-- Fecha: 2026-11-25
-- Alcance:
--   Actualiza public.rpc_buscar_ventas_para_reembolso para exponer fifo_batches
--   (lotes originales desde sale_item_batches + inventory_batches) por ítem.
--   Preserva assert_store_access(p_store_id) y assert_employee_permission('canManageRefunds').
--   Prohibido tocar LF-001 (procesar_venta) o C8 (Regla 11).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_buscar_ventas_para_reembolso(
    p_store_id UUID,
    p_query TEXT DEFAULT NULL::TEXT,
    p_limit INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_clean TEXT := TRIM(COALESCE(p_query, ''));
    v_is_num BOOLEAN := (v_clean ~ '^[0-9]+$');
    v_lim INT := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
    v_data JSONB;
BEGIN
    PERFORM public.assert_store_access(p_store_id);
    PERFORM public.assert_employee_permission(p_store_id, 'canManageRefunds');

    WITH matching_sales AS (
        SELECT s.id, s.ticket_number, s.created_at, s.total, s.payment_method,
               COALESCE(NULLIF(TRIM(s.actor_name), ''), 'Administrador') AS actor_name
        FROM public.sales s
        WHERE s.store_id = p_store_id
          AND s.is_voided = false
          AND s.payment_method <> 'consumo_personal'
          AND (
              v_clean = ''
              OR (v_is_num AND s.ticket_number::text = v_clean)
              OR EXISTS (
                  SELECT 1
                  FROM public.sale_items si
                  JOIN public.products p ON p.id = si.product_id
                  WHERE si.sale_id = s.id
                    AND (
                        p.name ILIKE ('%' || v_clean || '%')
                        OR COALESCE(p.plu, '') ILIKE ('%' || v_clean || '%')
                    )
              )
          )
        ORDER BY s.created_at DESC
        LIMIT v_lim
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'sale_id', ms.id,
                'ticket_number', ms.ticket_number,
                'created_at', ms.created_at,
                'total', ms.total,
                'payment_method', ms.payment_method,
                'actor_name', ms.actor_name,
                'items', (
                    SELECT COALESCE(
                        jsonb_agg(
                            jsonb_build_object(
                                'sale_item_id', si.id,
                                'product_id', si.product_id,
                                'product_name', COALESCE(p.name, 'Producto'),
                                'plu', p.plu,
                                'current_stock', COALESCE(p.current_stock, 0),
                                'is_weighable', COALESCE(p.is_weighable, false),
                                'measurement_unit', p.measurement_unit,
                                'quantity', si.quantity,
                                'refunded_quantity', COALESCE(si.refunded_quantity, 0),
                                'remaining_quantity', GREATEST(0, si.quantity - COALESCE(si.refunded_quantity, 0)),
                                'unit_price', si.unit_price,
                                'subtotal', si.subtotal,
                                'fifo_batches', (
                                    SELECT COALESCE(
                                        jsonb_agg(
                                            jsonb_build_object(
                                                'batch_id', sib.batch_id,
                                                'quantity', sib.quantity_consumed,
                                                'unit_cost', COALESCE(sib.unit_cost, ib.cost_unit, 0),
                                                'created_at', COALESCE(ib.created_at, sib.created_at)
                                            )
                                            ORDER BY COALESCE(ib.created_at, sib.created_at) ASC, sib.id ASC
                                        ),
                                        '[]'::jsonb
                                    )
                                    FROM public.sale_item_batches sib
                                    LEFT JOIN public.inventory_batches ib ON ib.id = sib.batch_id
                                    WHERE sib.sale_item_id = si.id
                                )
                            )
                            ORDER BY si.created_at ASC
                        ),
                        '[]'::jsonb
                    )
                    FROM public.sale_items si
                    JOIN public.products p ON p.id = si.product_id
                    WHERE si.sale_id = ms.id
                )
            )
            ORDER BY ms.created_at DESC
        ),
        '[]'::jsonb
    )
    INTO v_data
    FROM matching_sales ms;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_data
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

REVOKE ALL ON FUNCTION public.rpc_buscar_ventas_para_reembolso(UUID, TEXT, INTEGER) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_buscar_ventas_para_reembolso(UUID, TEXT, INTEGER) TO authenticated, service_role;

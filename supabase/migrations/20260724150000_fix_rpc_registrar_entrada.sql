-- Fix: rpc_registrar_entrada — Soporte para admins y validación de cantidad
-- Autor: Antigravity
-- Ref: Auditoría QA 2026-07-24 | Bug: stock_inicial = 0 al crear producto
-- Causa: movements_insert_store RLS policy eliminada en migración FIFO (20260723221255)

-- 3. Functions/Triggers

CREATE OR REPLACE FUNCTION public.rpc_registrar_entrada(
    p_product_id    UUID,
    p_quantity      DECIMAL,
    p_purchase_price DECIMAL,
    p_sale_price    DECIMAL,
    p_reason        TEXT DEFAULT 'Entrada de mercancía'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_actor_id       UUID;
    v_store_id       UUID;
    v_is_authorized  BOOLEAN := FALSE;
BEGIN
    -- Guard: sesión autenticada
    v_actor_id := auth.uid();
    IF v_actor_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No autorizado',
            'code', 'UNAUTHORIZED'
        );
    END IF;

    -- Guard: quantity debe ser positiva
    IF p_quantity <= 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'La cantidad debe ser mayor a 0',
            'code', 'INVALID_QUANTITY'
        );
    END IF;

    -- Guard: el producto debe existir y obtener su store_id
    SELECT store_id INTO v_store_id
    FROM public.products
    WHERE id = p_product_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Producto no encontrado',
            'code', 'NOT_FOUND'
        );
    END IF;

    -- Verificar acceso: OPCIÓN A — empleado de la misma tienda
    SELECT TRUE INTO v_is_authorized
    FROM public.employees
    WHERE id = v_actor_id AND store_id = v_store_id;

    -- Verificar acceso: OPCIÓN B — admin/owner (si no fue autorizado antes)
    IF NOT FOUND OR NOT v_is_authorized THEN
        SELECT TRUE INTO v_is_authorized
        FROM public.admin_profiles
        WHERE id = v_actor_id AND role IN ('admin', 'owner');
    END IF;

    IF NOT v_is_authorized THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Acceso denegado a este producto',
            'code', 'FORBIDDEN'
        );
    END IF;

    -- 1. Registrar movimiento de tipo 'entrada'
    --    (El trigger bridge_movement_to_batch ignora 'entrada' para no crear lote doble)
    INSERT INTO public.inventory_movements (
        product_id, movement_type, quantity, reason, created_by
    ) VALUES (
        p_product_id, 'entrada', p_quantity, p_reason, v_actor_id
    );

    -- 2. Crear lote FIFO con precios exactos proporcionados por el frontend
    INSERT INTO public.inventory_batches (
        product_id, quantity_initial, quantity_remaining,
        cost_unit, sale_price, created_by
    ) VALUES (
        p_product_id, p_quantity, p_quantity,
        p_purchase_price, p_sale_price, v_actor_id
    );

    RETURN jsonb_build_object('success', true);

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM,
        'code', SQLSTATE
    );
END;
$$;

-- ============================================================================
-- HOTFIX: product_price_history.created_by FK (23503) para Empleados (Pase Diario)
-- Fecha: 2026-11-20
-- Causa raíz:
--   product_price_history.created_by tiene FK a auth.users(id) (product_price_history_created_by_fkey),
--   mientras que rpc_registrar_entrada y rpc_registrar_entrada_masiva le pasaban v_emp_fk_id (employees.id).
--   Cuando opera un empleado autenticado vía Pase Diario (sesión anónima en auth.users),
--   su employees.id no existe en auth.users(id) y dispara SQLSTATE 23503.
-- Solución:
--   Pasar auth.uid() a product_price_history.created_by (válido tanto para Admin como para
--   empleados con sesión anónima en auth.users, y NULL en contexto service_role), manteniendo
--   v_emp_fk_id (employees.id) en inventory_movements.created_by.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_registrar_entrada(
    p_product_id uuid,
    p_quantity numeric,
    p_purchase_price numeric,
    p_sale_price numeric,
    p_reason text DEFAULT 'Compra'::text,
    p_supplier_id uuid DEFAULT NULL::uuid,
    p_payment_type text DEFAULT NULL::text,
    p_invoice_reference text DEFAULT NULL::text,
    p_reference_invoice_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_store_id UUID;
    v_product RECORD;
    v_snap RECORD;
    v_emp_fk_id UUID;
    v_clean_reason TEXT := TRIM(COALESCE(p_reason, 'Compra'));
    v_movement_id UUID;
    v_new_stock NUMERIC;
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'INVALID_QUANTITY: La cantidad de entrada debe ser mayor a cero.'
            USING ERRCODE = '22023';
    END IF;

    IF p_purchase_price IS NULL OR p_purchase_price < 0 OR p_sale_price IS NULL OR p_sale_price <= 0 THEN
        RAISE EXCEPTION 'INVALID_PRICE: El costo debe ser >= 0 y el precio de venta > 0.'
            USING ERRCODE = '22023';
    END IF;

    -- CHK-505: Rechazar motivos de ajuste positivo o devolución de cliente en Entradas
    IF v_clean_reason = ''
       OR translate(lower(v_clean_reason), 'áéíóúü', 'aeiouu') ~ '(ajuste\s*positivo|devolucion\s*cliente|^\s*ajuste\b|^\s*devolucion\b)' THEN
        RAISE EXCEPTION 'INVALID_REASON: Las entradas solo aceptan motivos de Compra o Reposición. Use Salidas Logísticas o Reembolsos.'
            USING ERRCODE = '22023';
    END IF;

    SELECT id, store_id, price, cost_price, current_stock
    INTO v_product
    FROM public.products
    WHERE id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PRODUCT_NOT_FOUND: El producto (%) no existe.', p_product_id
            USING ERRCODE = 'P0002';
    END IF;

    v_store_id := v_product.store_id;

    PERFORM public.assert_store_access(v_store_id);
    PERFORM public.assert_employee_permission(v_store_id, 'canManageInventory');

    IF p_supplier_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.suppliers WHERE id = p_supplier_id AND store_id = v_store_id) THEN
            RAISE EXCEPTION 'SUPPLIER_NOT_FOUND: El proveedor no pertenece a la tienda activa.'
                USING ERRCODE = 'P0002';
        END IF;
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_store_id);
    SELECT e.id INTO v_emp_fk_id
    FROM public.employees e
    WHERE e.id = COALESCE(public.get_employee_id_from_session(), v_snap.actor_id)
      AND e.store_id = v_store_id
    LIMIT 1;

    -- Actualizar catálogo e historial si el precio o costo variaron
    IF v_product.price IS DISTINCT FROM p_sale_price OR v_product.cost_price IS DISTINCT FROM p_purchase_price THEN
        INSERT INTO public.product_price_history (product_id, purchase_price, sale_price, created_by)
        VALUES (p_product_id, p_purchase_price, p_sale_price, auth.uid());

        UPDATE public.products
        SET price = p_sale_price,
            cost_price = p_purchase_price,
            updated_at = NOW()
        WHERE id = p_product_id;
    END IF;

    -- Registrar movimiento (sin referencia a CxP / reference_invoice_id = NULL)
    INSERT INTO public.inventory_movements (
        product_id, movement_type, quantity, reason, created_by,
        actor_name, actor_role, unit_cost, reference_sale_price,
        supplier_id, payment_type, invoice_reference, reference_invoice_id
    ) VALUES (
        p_product_id, 'entrada', p_quantity, v_clean_reason, v_emp_fk_id,
        v_snap.actor_name, v_snap.actor_role, p_purchase_price, p_sale_price,
        p_supplier_id, NULLIF(TRIM(COALESCE(p_payment_type, '')), ''), NULLIF(TRIM(COALESCE(p_invoice_reference, '')), ''), NULL
    ) RETURNING id INTO v_movement_id;

    SELECT current_stock INTO v_new_stock FROM public.products WHERE id = p_product_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'movement_id', v_movement_id,
            'product_id', p_product_id,
            'new_stock', v_new_stock,
            'unit_cost', p_purchase_price,
            'sale_price', p_sale_price,
            'actor_name', v_snap.actor_name,
            'actor_role', v_snap.actor_role
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_registrar_entrada_masiva(
    p_store_id uuid,
    p_entries jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_snap RECORD;
    v_emp_fk_id UUID;
    v_entry JSONB;
    v_product_id UUID;
    v_quantity NUMERIC;
    v_purchase_price NUMERIC;
    v_sale_price NUMERIC;
    v_reason TEXT;
    v_processed_count INTEGER := 0;
BEGIN
    PERFORM public.assert_store_access(p_store_id);
    PERFORM public.assert_employee_permission(p_store_id, 'canManageInventory');

    IF p_entries IS NULL OR jsonb_array_length(p_entries) = 0 THEN
        RAISE EXCEPTION 'EMPTY_ENTRIES: La lista de entradas no puede estar vacía.'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(p_store_id);
    SELECT e.id INTO v_emp_fk_id
    FROM public.employees e
    WHERE e.id = COALESCE(public.get_employee_id_from_session(), v_snap.actor_id)
      AND e.store_id = p_store_id
    LIMIT 1;

    FOR v_entry IN SELECT * FROM jsonb_array_elements(p_entries) LOOP
        v_product_id := (v_entry->>'product_id')::UUID;
        v_quantity := (v_entry->>'quantity')::NUMERIC;
        v_purchase_price := (v_entry->>'purchase_price')::NUMERIC;
        v_sale_price := (v_entry->>'sale_price')::NUMERIC;
        v_reason := COALESCE(NULLIF(TRIM(v_entry->>'reason'), ''), 'Compra masiva');

        IF v_quantity IS NULL OR v_quantity <= 0 THEN
            RAISE EXCEPTION 'INVALID_QUANTITY: La cantidad para el producto % debe ser mayor a cero.', v_product_id
                USING ERRCODE = '22023';
        END IF;

        IF v_purchase_price IS NULL OR v_purchase_price < 0 OR v_sale_price IS NULL OR v_sale_price <= 0 THEN
            RAISE EXCEPTION 'INVALID_PRICE: El costo debe ser >= 0 y el precio de venta > 0.'
                USING ERRCODE = '22023';
        END IF;

        IF translate(lower(v_reason), 'áéíóúü', 'aeiouu') ~ '(ajuste\s*positivo|devolucion\s*cliente)' THEN
            RAISE EXCEPTION 'INVALID_REASON: Motivo (%) no permitido en entrada de mercancía.', v_reason
                USING ERRCODE = '22023';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.products WHERE id = v_product_id AND store_id = p_store_id) THEN
            RAISE EXCEPTION 'PRODUCT_NOT_FOUND: El producto % no pertenece a la tienda especificada.', v_product_id
                USING ERRCODE = 'P0002';
        END IF;

        IF EXISTS (SELECT 1 FROM public.products WHERE id = v_product_id AND (price IS DISTINCT FROM v_sale_price OR cost_price IS DISTINCT FROM v_purchase_price)) THEN
            INSERT INTO public.product_price_history (product_id, purchase_price, sale_price, created_by)
            VALUES (v_product_id, v_purchase_price, v_sale_price, auth.uid());

            UPDATE public.products
            SET price = v_sale_price,
                cost_price = v_purchase_price,
                updated_at = NOW()
            WHERE id = v_product_id;
        END IF;

        INSERT INTO public.inventory_movements (
            product_id, movement_type, quantity, reason, created_by, actor_name, actor_role, unit_cost, reference_sale_price
        ) VALUES (
            v_product_id, 'entrada', v_quantity, v_reason, v_emp_fk_id, v_snap.actor_name, v_snap.actor_role, v_purchase_price, v_sale_price
        );

        v_processed_count := v_processed_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'processed_count', v_processed_count,
            'actor_name', v_snap.actor_name,
            'timestamp', NOW()
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

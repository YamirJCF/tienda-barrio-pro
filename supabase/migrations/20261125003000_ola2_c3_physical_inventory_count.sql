-- ============================================================================
-- MIGRACIÓN: WO-OLA2-C3-002 (UX-ADR-004 / SDD-006-01-02 §9)
-- Contexto C3 Parte 2 — Inventariado Físico Masivo con Caja Cerrada:
--   1. public.rpc_obtener_lotes_activos_tienda(p_store_id uuid)
--   2. public.rpc_aplicar_inventariado_fisico(p_store_id uuid, p_items jsonb, p_notes text DEFAULT NULL)
-- ============================================================================

-- 1. Lectura única consolidada de lotes activos y estado de caja abierta
CREATE OR REPLACE FUNCTION public.rpc_obtener_lotes_activos_tienda(p_store_id UUID)
 RETURNS JSONB
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_has_open_cash BOOLEAN := false;
    v_batches JSONB := '[]'::jsonb;
BEGIN
    -- Seguridad centralizada (Regla 4)
    PERFORM public.assert_store_access(p_store_id);
    PERFORM public.assert_employee_permission(p_store_id, 'canManageInventory');

    SELECT EXISTS (
        SELECT 1
        FROM public.cash_sessions cs
        WHERE cs.store_id = p_store_id
          AND cs.status = 'open'
    ) INTO v_has_open_cash;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', ib.id,
                'product_id', ib.product_id,
                'quantity_initial', ib.quantity_initial,
                'quantity_remaining', ib.quantity_remaining,
                'cost_unit', ib.cost_unit,
                'sale_price', ib.sale_price,
                'is_active', ib.is_active,
                'created_at', ib.created_at,
                'expiration_date', ib.expiration_date
            )
            ORDER BY ib.product_id, ib.created_at ASC
        ),
        '[]'::jsonb
    )
    INTO v_batches
    FROM public.inventory_batches ib
    JOIN public.products p ON p.id = ib.product_id
    WHERE p.store_id = p_store_id
      AND p.is_active = true
      AND ib.quantity_remaining > 0;

    RETURN jsonb_build_object(
        'success', true,
        'has_open_cash_session', v_has_open_cash,
        'batches', v_batches
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.rpc_obtener_lotes_activos_tienda(UUID)
    TO anon, authenticated, service_role;

-- 2. Aplicación atómica todo-o-nada de inventariado físico con caja cerrada
CREATE OR REPLACE FUNCTION public.rpc_aplicar_inventariado_fisico(
    p_store_id UUID,
    p_items JSONB,
    p_notes TEXT DEFAULT NULL
)
 RETURNS JSONB
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_snap RECORD;
    v_emp_fk_id UUID;
    v_clean_notes TEXT := NULLIF(TRIM(COALESCE(p_notes, '')), '');
    v_reason TEXT;
    v_item JSONB;
    v_product RECORD;
    v_batch RECORD;
    v_fifo RECORD;
    v_product_id UUID;
    v_counted NUMERIC;
    v_batch_id UUID;
    v_delta NUMERIC;
    v_abs NUMERIC;
    v_take NUMERIC;
    v_rem NUMERIC;
    v_total_val NUMERIC(14,4);
    v_movement_id UUID;
    v_verified_total INTEGER := 0;
    v_unchanged_count INTEGER := 0;
    v_adjusted_count INTEGER := 0;
    v_shortages_count INTEGER := 0;
    v_surpluses_count INTEGER := 0;
BEGIN
    -- Seguridad centralizada (Regla 4)
    PERFORM public.assert_store_access(p_store_id);
    PERFORM public.assert_employee_permission(p_store_id, 'canManageInventory');

    -- Candado estricto de Caja Cerrada
    IF EXISTS (
        SELECT 1
        FROM public.cash_sessions cs
        WHERE cs.store_id = p_store_id
          AND cs.status = 'open'
    ) THEN
        RAISE EXCEPTION 'CASH_REGISTER_MUST_BE_CLOSED: Debes cerrar el turno de caja antes de aplicar un inventariado físico.'
            USING ERRCODE = 'P0001';
    END IF;

    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'EMPTY_ITEMS: Debes incluir al menos un producto contado.'
            USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(p_items) elem
        GROUP BY NULLIF(TRIM(COALESCE(elem->>'product_id', '')), '')
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'DUPLICATE_PRODUCT_IN_COUNT: El inventariado contiene productos duplicados.'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(p_store_id);
    SELECT e.id INTO v_emp_fk_id
    FROM public.employees e
    WHERE e.id = COALESCE(public.get_employee_id_from_session(), v_snap.actor_id)
      AND e.store_id = p_store_id
    LIMIT 1;

    v_reason := CASE
        WHEN v_clean_notes IS NOT NULL THEN 'Inventariado físico: ' || v_clean_notes
        ELSE 'Inventariado físico de estantería'
    END;

    -- Recorrer ordenado por product_id UUID para prevenir deadlocks ante concurrencia
    FOR v_item IN
        SELECT elem
        FROM jsonb_array_elements(p_items) AS elem
        ORDER BY NULLIF(TRIM(COALESCE(elem->>'product_id', '')), '')::UUID ASC NULLS LAST
    LOOP
        v_product_id := NULLIF(TRIM(COALESCE(v_item->>'product_id', '')), '')::UUID;
        v_counted := (v_item->>'counted_quantity')::NUMERIC;
        v_batch_id := NULLIF(TRIM(COALESCE(v_item->>'batch_id', '')), '')::UUID;

        IF v_product_id IS NULL THEN
            RAISE EXCEPTION 'INVALID_PRODUCT: Todo ítem contado debe especificar product_id.'
                USING ERRCODE = '22023';
        END IF;

        IF v_counted IS NULL OR v_counted < 0 THEN
            RAISE EXCEPTION 'INVALID_COUNTED_QUANTITY: La cantidad contada para el producto % debe ser mayor o igual a cero.', v_product_id
                USING ERRCODE = '22023';
        END IF;

        SELECT id, store_id, name, current_stock, cost_price, price, is_active
        INTO v_product
        FROM public.products
        WHERE id = v_product_id
          AND store_id = p_store_id
          AND is_active = true
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'PRODUCT_NOT_FOUND: El producto % no existe o no está activo en la tienda.', v_product_id
                USING ERRCODE = 'P0002';
        END IF;

        v_verified_total := v_verified_total + 1;
        v_delta := v_counted - COALESCE(v_product.current_stock, 0);

        IF v_delta = 0 THEN
            v_unchanged_count := v_unchanged_count + 1;
            CONTINUE;
        END IF;

        IF v_delta < 0 THEN
            -- Faltante físico: descontar de lote elegido + FIFO si hay remanente, o FIFO estándar
            v_abs := ABS(v_delta);

            IF v_batch_id IS NOT NULL THEN
                SELECT id, product_id, quantity_remaining, cost_unit, sale_price
                INTO v_batch
                FROM public.inventory_batches
                WHERE id = v_batch_id
                  AND product_id = v_product_id
                FOR UPDATE;

                IF NOT FOUND THEN
                    RAISE EXCEPTION 'BATCH_NOT_FOUND: El lote (%) no pertenece al producto (%).', v_batch_id, v_product_id
                        USING ERRCODE = 'P0002';
                END IF;

                v_take := LEAST(v_abs, COALESCE(v_batch.quantity_remaining, 0));
                v_rem := v_abs - v_take;
                v_total_val := 0;

                IF v_take > 0 THEN
                    UPDATE public.inventory_batches
                    SET quantity_remaining = quantity_remaining - v_take
                    WHERE id = v_batch_id;

                    v_total_val := v_total_val + (v_take * v_batch.cost_unit);
                END IF;

                PERFORM set_config('app.skip_bridge_movement_to_batch', 'true', true);
                INSERT INTO public.inventory_movements (
                    product_id, movement_type, quantity, reason, created_by,
                    actor_name, actor_role, unit_cost, reference_sale_price
                ) VALUES (
                    v_product_id,
                    'ajuste_conteo',
                    -v_abs,
                    v_reason,
                    v_emp_fk_id,
                    v_snap.actor_name,
                    v_snap.actor_role,
                    NULL,
                    NULL
                ) RETURNING id INTO v_movement_id;
                PERFORM set_config('app.skip_bridge_movement_to_batch', 'false', true);

                IF v_take > 0 THEN
                    INSERT INTO public.inventory_movement_batches (movement_id, batch_id, quantity_consumed, unit_cost)
                    VALUES (v_movement_id, v_batch_id, v_take, v_batch.cost_unit);
                END IF;

                IF v_rem > 0 THEN
                    FOR v_fifo IN SELECT * FROM public.consume_stock_fifo(v_product_id, v_rem) LOOP
                        INSERT INTO public.inventory_movement_batches (movement_id, batch_id, quantity_consumed, unit_cost)
                        VALUES (v_movement_id, v_fifo.batch_id, v_fifo.quantity_taken, v_fifo.cost_unit);

                        v_total_val := v_total_val + (v_fifo.quantity_taken * v_fifo.cost_unit);
                    END LOOP;
                END IF;

                IF v_abs > 0 THEN
                    UPDATE public.inventory_movements
                    SET unit_cost = ROUND(v_total_val / v_abs, 4)
                    WHERE id = v_movement_id;
                END IF;
            ELSE
                INSERT INTO public.inventory_movements (
                    product_id, movement_type, quantity, reason, created_by,
                    actor_name, actor_role, unit_cost, reference_sale_price
                ) VALUES (
                    v_product_id,
                    'ajuste_conteo',
                    -v_abs,
                    v_reason,
                    v_emp_fk_id,
                    v_snap.actor_name,
                    v_snap.actor_role,
                    NULL,
                    NULL
                );
            END IF;

            v_adjusted_count := v_adjusted_count + 1;
            v_shortages_count := v_shortages_count + 1;
        ELSE
            -- Sobrante físico: sumar a lote puntual, lote activo más reciente o crear capa FIFO si stock=0
            IF v_batch_id IS NOT NULL THEN
                SELECT id, product_id, quantity_remaining, cost_unit, sale_price
                INTO v_batch
                FROM public.inventory_batches
                WHERE id = v_batch_id
                  AND product_id = v_product_id
                FOR UPDATE;

                IF NOT FOUND THEN
                    RAISE EXCEPTION 'BATCH_NOT_FOUND: El lote (%) no pertenece al producto (%).', v_batch_id, v_product_id
                        USING ERRCODE = 'P0002';
                END IF;

                UPDATE public.inventory_batches
                SET quantity_remaining = quantity_remaining + v_delta,
                    quantity_initial = quantity_initial + v_delta
                WHERE id = v_batch_id;

                PERFORM set_config('app.skip_bridge_movement_to_batch', 'true', true);
                INSERT INTO public.inventory_movements (
                    product_id, movement_type, quantity, reason, created_by,
                    actor_name, actor_role, unit_cost, reference_sale_price
                ) VALUES (
                    v_product_id,
                    'ajuste_conteo',
                    v_delta,
                    v_reason,
                    v_emp_fk_id,
                    v_snap.actor_name,
                    v_snap.actor_role,
                    v_batch.cost_unit,
                    v_batch.sale_price
                );
                PERFORM set_config('app.skip_bridge_movement_to_batch', 'false', true);
            ELSE
                SELECT id, cost_unit, sale_price
                INTO v_batch
                FROM public.inventory_batches
                WHERE product_id = v_product_id
                  AND quantity_remaining > 0
                ORDER BY created_at DESC
                LIMIT 1
                FOR UPDATE;

                IF FOUND THEN
                    UPDATE public.inventory_batches
                    SET quantity_remaining = quantity_remaining + v_delta,
                        quantity_initial = quantity_initial + v_delta
                    WHERE id = v_batch.id;

                    PERFORM set_config('app.skip_bridge_movement_to_batch', 'true', true);
                    INSERT INTO public.inventory_movements (
                        product_id, movement_type, quantity, reason, created_by,
                        actor_name, actor_role, unit_cost, reference_sale_price
                    ) VALUES (
                        v_product_id,
                        'ajuste_conteo',
                        v_delta,
                        v_reason,
                        v_emp_fk_id,
                        v_snap.actor_name,
                        v_snap.actor_role,
                        v_batch.cost_unit,
                        v_batch.sale_price
                    );
                    PERFORM set_config('app.skip_bridge_movement_to_batch', 'false', true);
                ELSE
                    INSERT INTO public.inventory_movements (
                        product_id, movement_type, quantity, reason, created_by,
                        actor_name, actor_role, unit_cost, reference_sale_price
                    ) VALUES (
                        v_product_id,
                        'ajuste_conteo',
                        v_delta,
                        v_reason,
                        v_emp_fk_id,
                        v_snap.actor_name,
                        v_snap.actor_role,
                        COALESCE(v_product.cost_price, 0),
                        COALESCE(v_product.price, 0)
                    );
                END IF;
            END IF;

            v_adjusted_count := v_adjusted_count + 1;
            v_surpluses_count := v_surpluses_count + 1;
        END IF;
    END LOOP;

    -- 1 sola notificación resumen para el Admin cuando existieron ajustes reales
    IF v_adjusted_count > 0 THEN
        INSERT INTO public.notifications (
            store_id, type, title, message, audience, is_read, metadata
        ) VALUES (
            p_store_id,
            'inventory',
            'Resumen de Inventariado Físico',
            format('%s aplicó inventariado físico (%s verificados: %s ajustados — %s faltantes, %s sobrantes).',
                v_snap.actor_name, v_verified_total, v_adjusted_count, v_shortages_count, v_surpluses_count),
            'admin',
            false,
            jsonb_build_object(
                'event_type', 'INVENTORY_COUNT_SUMMARY',
                'verified_total', v_verified_total,
                'unchanged_count', v_unchanged_count,
                'adjusted_count', v_adjusted_count,
                'shortages_count', v_shortages_count,
                'surpluses_count', v_surpluses_count,
                'actor_name', v_snap.actor_name,
                'actor_role', v_snap.actor_role,
                'notes', v_clean_notes
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'verified_total', v_verified_total,
            'unchanged_count', v_unchanged_count,
            'adjusted_count', v_adjusted_count,
            'shortages_count', v_shortages_count,
            'surpluses_count', v_surpluses_count,
            'timestamp', NOW()
        )
    );
EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.skip_bridge_movement_to_batch', 'false', true);
    RAISE;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.rpc_aplicar_inventariado_fisico(UUID, JSONB, TEXT)
    TO anon, authenticated, service_role;

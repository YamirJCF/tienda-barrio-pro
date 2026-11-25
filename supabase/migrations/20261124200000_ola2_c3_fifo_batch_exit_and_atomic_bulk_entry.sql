-- ============================================================================
-- MIGRACIÓN: WO-OLA2-C3-001 (UX-ADR-003 / SDD-006-01-02)
-- Contexto C3 Parte 1:
--   1. Columna estructurada inventory_batches.expiration_date (DATE)
--   2. Guardia transaccional app.skip_bridge_movement_to_batch en bridge_movement_to_batch() [LF-009]
--   3. Entrada masiva atómica todo-o-nada rpc_registrar_entrada_masiva (con total_entry_cost servidor)
--   4. Salidas logísticas rpc_registrar_salida_logistica con p_batch_id UUID DEFAULT NULL
--      y permiso único canManageInventory para los 4 tipos de salida/ajuste
-- ============================================================================

-- 1. Columna estructurada de vencimiento en lotes FIFO
ALTER TABLE public.inventory_batches
    ADD COLUMN IF NOT EXISTS expiration_date DATE;

-- 2. Trigger puente FIFO con guardia transaccional explícita (LF-009)
CREATE OR REPLACE FUNCTION public.bridge_movement_to_batch()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_cost DECIMAL;
    v_sale_price DECIMAL;
    v_batch_record RECORD;
    v_total_value DECIMAL(14,4) := 0;
BEGIN
    -- Cuando un RPC autorizado ya ajustó explícitamente un lote puntual (p_batch_id)
    -- y registró su enlace en inventory_movement_batches, se omite el puente automático
    -- dentro de la transacción actual para impedir doble consumo o creación de lote duplicado.
    IF current_setting('app.skip_bridge_movement_to_batch', true) = 'true' THEN
        RETURN NEW;
    END IF;

    CASE NEW.movement_type
        WHEN 'entrada', 'devolucion' THEN
            -- 'entrada' (compra/reposición) y 'devolucion' (reembolso cliente vendible) crean capa FIFO
            v_cost := COALESCE(
                NEW.unit_cost,
                (SELECT cost_price FROM public.products WHERE id = NEW.product_id),
                0
            );
            v_sale_price := COALESCE(
                NEW.reference_sale_price,
                (SELECT price FROM public.products WHERE id = NEW.product_id),
                0
            );

            INSERT INTO public.inventory_batches (
                product_id, quantity_initial, quantity_remaining, cost_unit, sale_price, created_by, source_movement_id
            ) VALUES (
                NEW.product_id, NEW.quantity, NEW.quantity, v_cost, v_sale_price, NEW.created_by, NEW.id
            );

        WHEN 'merma' THEN
            -- Si proviene de un reembolso "merma" ([REEMBOLSO-MERMA]%), la mercancía dañada nunca
            -- reingresa a stock vendible ni consume inventario actual (opera incluso con stock = 0).
            IF COALESCE(NEW.reason, '') LIKE '[REEMBOLSO-MERMA]%' THEN
                NULL;
            ELSE
                FOR v_batch_record IN SELECT * FROM public.consume_stock_fifo(NEW.product_id, ABS(NEW.quantity)) LOOP
                    INSERT INTO public.inventory_movement_batches (movement_id, batch_id, quantity_consumed, unit_cost)
                    VALUES (NEW.id, v_batch_record.batch_id, v_batch_record.quantity_taken, v_batch_record.cost_unit);

                    v_total_value := v_total_value + (v_batch_record.quantity_taken * v_batch_record.cost_unit);
                END LOOP;

                IF NEW.unit_cost IS NULL AND ABS(NEW.quantity) > 0 THEN
                    UPDATE public.inventory_movements
                    SET unit_cost = ROUND(v_total_value / ABS(NEW.quantity), 4)
                    WHERE id = NEW.id;
                END IF;
            END IF;

        WHEN 'consumo_negocio', 'devolucion_proveedor', 'salida' THEN
            FOR v_batch_record IN SELECT * FROM public.consume_stock_fifo(NEW.product_id, ABS(NEW.quantity)) LOOP
                INSERT INTO public.inventory_movement_batches (movement_id, batch_id, quantity_consumed, unit_cost)
                VALUES (NEW.id, v_batch_record.batch_id, v_batch_record.quantity_taken, v_batch_record.cost_unit);

                v_total_value := v_total_value + (v_batch_record.quantity_taken * v_batch_record.cost_unit);
            END LOOP;

            IF NEW.unit_cost IS NULL AND ABS(NEW.quantity) > 0 THEN
                UPDATE public.inventory_movements
                SET unit_cost = ROUND(v_total_value / ABS(NEW.quantity), 4)
                WHERE id = NEW.id;
            END IF;

        WHEN 'ajuste', 'ajuste_conteo', 'CORRECCION_SISTEMA' THEN
            IF NEW.quantity > 0 THEN
                v_cost := COALESCE(
                    NEW.unit_cost,
                    (SELECT cost_price FROM public.products WHERE id = NEW.product_id),
                    0
                );
                v_sale_price := COALESCE(
                    NEW.reference_sale_price,
                    (SELECT price FROM public.products WHERE id = NEW.product_id),
                    0
                );

                INSERT INTO public.inventory_batches (
                    product_id, quantity_initial, quantity_remaining, cost_unit, sale_price, created_by, source_movement_id
                ) VALUES (
                    NEW.product_id, NEW.quantity, NEW.quantity, v_cost, v_sale_price, NEW.created_by, NEW.id
                );
            ELSIF NEW.quantity < 0 THEN
                FOR v_batch_record IN SELECT * FROM public.consume_stock_fifo(NEW.product_id, ABS(NEW.quantity)) LOOP
                    INSERT INTO public.inventory_movement_batches (movement_id, batch_id, quantity_consumed, unit_cost)
                    VALUES (NEW.id, v_batch_record.batch_id, v_batch_record.quantity_taken, v_batch_record.cost_unit);

                    v_total_value := v_total_value + (v_batch_record.quantity_taken * v_batch_record.cost_unit);
                END LOOP;

                IF NEW.unit_cost IS NULL AND ABS(NEW.quantity) > 0 THEN
                    UPDATE public.inventory_movements
                    SET unit_cost = ROUND(v_total_value / ABS(NEW.quantity), 4)
                    WHERE id = NEW.id;
                END IF;
            END IF;

        WHEN 'venta', 'consumo_personal' THEN
            -- El consumo FIFO de ventas POS y consumos personales lo ejecuta atómicamente rpc_procesar_venta_v3
            NULL;

        ELSE
            NULL;
    END CASE;

    -- Independencia total: cero mutaciones a supplier_invoices (CxP) desde inventario
    RETURN NEW;
END;
$function$;

-- 3. Entrada masiva atómica todo-o-nada (firma canónica única)
DROP FUNCTION IF EXISTS public.rpc_registrar_entrada_masiva(UUID, JSONB);

CREATE OR REPLACE FUNCTION public.rpc_registrar_entrada_masiva(
    p_store_id UUID,
    p_items JSONB,
    p_reason TEXT DEFAULT 'Compra masiva',
    p_supplier_id UUID DEFAULT NULL,
    p_invoice_ref TEXT DEFAULT NULL
)
 RETURNS JSONB
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_snap RECORD;
    v_emp_fk_id UUID;
    v_clean_header_reason TEXT := COALESCE(NULLIF(TRIM(p_reason), ''), 'Compra masiva');
    v_clean_invoice_ref TEXT := NULLIF(TRIM(COALESCE(p_invoice_ref, '')), '');
    v_item JSONB;
    v_product RECORD;
    v_product_id UUID;
    v_quantity NUMERIC;
    v_unit_cost NUMERIC;
    v_sale_price NUMERIC;
    v_item_reason TEXT;
    v_exp_text TEXT;
    v_exp_date DATE;
    v_movement_id UUID;
    v_batch_id UUID;
    v_processed_count INTEGER := 0;
    v_total_units NUMERIC := 0;
    v_total_entry_cost NUMERIC := 0;
    v_created_batch_ids UUID[] := ARRAY[]::UUID[];
BEGIN
    -- Seguridad centralizada (Regla 4)
    PERFORM public.assert_store_access(p_store_id);
    PERFORM public.assert_employee_permission(p_store_id, 'canManageInventory');

    IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'EMPTY_ENTRIES: La lista de entradas no puede estar vacía.'
            USING ERRCODE = '22023';
    END IF;

    IF translate(lower(v_clean_header_reason), 'áéíóúü', 'aeiouu') ~ '(ajuste\s*positivo|devolucion\s*cliente)' THEN
        RAISE EXCEPTION 'INVALID_REASON: Motivo (%) no permitido en entrada de mercancía.', v_clean_header_reason
            USING ERRCODE = '22023';
    END IF;

    IF p_supplier_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.suppliers WHERE id = p_supplier_id AND store_id = p_store_id) THEN
            RAISE EXCEPTION 'SUPPLIER_NOT_FOUND: El proveedor no pertenece a la tienda especificada.'
                USING ERRCODE = 'P0002';
        END IF;
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(p_store_id);
    SELECT e.id INTO v_emp_fk_id
    FROM public.employees e
    WHERE e.id = COALESCE(public.get_employee_id_from_session(), v_snap.actor_id)
      AND e.store_id = p_store_id
    LIMIT 1;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := NULLIF(TRIM(COALESCE(v_item->>'product_id', '')), '')::UUID;
        v_quantity := (v_item->>'quantity')::NUMERIC;
        v_unit_cost := COALESCE((v_item->>'unit_cost')::NUMERIC, (v_item->>'purchase_price')::NUMERIC);
        v_sale_price := (v_item->>'sale_price')::NUMERIC;
        v_item_reason := COALESCE(NULLIF(TRIM(COALESCE(v_item->>'reason', '')), ''), v_clean_header_reason);
        v_exp_text := NULLIF(TRIM(COALESCE(v_item->>'expiration_date', '')), '');
        v_exp_date := CASE WHEN v_exp_text IS NOT NULL THEN v_exp_text::DATE ELSE NULL END;

        IF v_product_id IS NULL THEN
            RAISE EXCEPTION 'INVALID_PRODUCT: Cada ítem de la entrada debe especificar product_id.'
                USING ERRCODE = '22023';
        END IF;

        IF v_quantity IS NULL OR v_quantity <= 0 THEN
            RAISE EXCEPTION 'INVALID_QUANTITY: La cantidad para el producto % debe ser mayor a cero.', v_product_id
                USING ERRCODE = '22023';
        END IF;

        IF v_unit_cost IS NULL OR v_unit_cost < 0 OR v_sale_price IS NULL OR v_sale_price <= 0 THEN
            RAISE EXCEPTION 'INVALID_PRICE: El costo debe ser >= 0 y el precio de venta > 0 para el producto %.', v_product_id
                USING ERRCODE = '22023';
        END IF;

        IF translate(lower(v_item_reason), 'áéíóúü', 'aeiouu') ~ '(ajuste\s*positivo|devolucion\s*cliente)' THEN
            RAISE EXCEPTION 'INVALID_REASON: Motivo (%) no permitido en entrada de mercancía.', v_item_reason
                USING ERRCODE = '22023';
        END IF;

        SELECT id, store_id, price, cost_price, current_stock
        INTO v_product
        FROM public.products
        WHERE id = v_product_id
          AND store_id = p_store_id
          AND is_active = true
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'PRODUCT_NOT_FOUND: El producto % no existe o no pertenece a la tienda activa.', v_product_id
                USING ERRCODE = 'P0002';
        END IF;

        -- Actualizar historial de precios y precio de venta de catálogo cuando cambian;
        -- el cost_price activo sigue la regla FIFO en sync_product_stock_from_batches().
        IF v_product.price IS DISTINCT FROM v_sale_price OR v_product.cost_price IS DISTINCT FROM v_unit_cost THEN
            INSERT INTO public.product_price_history (product_id, purchase_price, sale_price, created_by)
            VALUES (v_product_id, v_unit_cost, v_sale_price, auth.uid());
        END IF;

        IF v_product.price IS DISTINCT FROM v_sale_price THEN
            UPDATE public.products
            SET price = v_sale_price,
                updated_at = NOW()
            WHERE id = v_product_id;
        END IF;

        -- Insertar movimiento de entrada: trg_bridge_movement_to_batch crea el lote FIFO
        -- y trg_sync_batches sincroniza products.current_stock y products.cost_price.
        INSERT INTO public.inventory_movements (
            product_id, movement_type, quantity, reason, created_by,
            actor_name, actor_role, supplier_id, invoice_reference,
            unit_cost, reference_sale_price
        ) VALUES (
            v_product_id,
            'entrada',
            v_quantity,
            v_item_reason,
            v_emp_fk_id,
            v_snap.actor_name,
            v_snap.actor_role,
            p_supplier_id,
            v_clean_invoice_ref,
            v_unit_cost,
            v_sale_price
        ) RETURNING id INTO v_movement_id;

        UPDATE public.inventory_batches
        SET expiration_date = v_exp_date
        WHERE source_movement_id = v_movement_id
        RETURNING id INTO v_batch_id;

        IF v_batch_id IS NULL THEN
            RAISE EXCEPTION 'BATCH_CREATION_FAILED: No se pudo registrar el lote FIFO para el movimiento %.', v_movement_id
                USING ERRCODE = 'P0001';
        END IF;

        v_processed_count := v_processed_count + 1;
        v_total_units := v_total_units + v_quantity;
        v_total_entry_cost := v_total_entry_cost + (v_quantity * v_unit_cost);
        v_created_batch_ids := array_append(v_created_batch_ids, v_batch_id);
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'items_processed', v_processed_count,
            'processed_count', v_processed_count,
            'total_units', v_total_units,
            'total_entry_cost', ROUND(v_total_entry_cost, 2),
            'created_batch_ids', to_jsonb(v_created_batch_ids),
            'actor_name', v_snap.actor_name,
            'timestamp', NOW()
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.rpc_registrar_entrada_masiva(UUID, JSONB, TEXT, UUID, TEXT)
    TO anon, authenticated, service_role;

-- 4. Salidas logísticas ($0 POS) con selección explícita de lote (p_batch_id) y permiso único canManageInventory
DROP FUNCTION IF EXISTS public.rpc_registrar_salida_logistica(UUID, TEXT, NUMERIC, TEXT, TEXT, UUID);

CREATE OR REPLACE FUNCTION public.rpc_registrar_salida_logistica(
    p_product_id UUID,
    p_movement_type TEXT,
    p_quantity NUMERIC,
    p_reason TEXT,
    p_direction TEXT DEFAULT 'negative',
    p_supplier_id UUID DEFAULT NULL,
    p_batch_id UUID DEFAULT NULL
)
 RETURNS JSONB
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_product RECORD;
    v_batch RECORD;
    v_store_id UUID;
    v_snap RECORD;
    v_emp_fk_id UUID;
    v_clean_type TEXT := LOWER(TRIM(COALESCE(p_movement_type, '')));
    v_clean_dir TEXT := LOWER(TRIM(COALESCE(p_direction, 'negative')));
    v_clean_reason TEXT := TRIM(COALESCE(p_reason, ''));
    v_signed_qty NUMERIC;
    v_movement_id UUID;
    v_target_batch_id UUID := p_batch_id;
    v_recorded_cost NUMERIC;
    v_new_stock NUMERIC;
BEGIN
    IF p_product_id IS NULL THEN
        RAISE EXCEPTION 'INVALID_PRODUCT: El producto es obligatorio.' USING ERRCODE = '22023';
    END IF;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'INVALID_QUANTITY: La cantidad debe ser mayor a cero.' USING ERRCODE = '22023';
    END IF;

    IF v_clean_type NOT IN ('merma', 'consumo_negocio', 'ajuste_conteo', 'devolucion_proveedor') THEN
        RAISE EXCEPTION 'INVALID_MOVEMENT_TYPE: Tipo (%) no permitido para salida logística.', p_movement_type
            USING ERRCODE = '22023';
    END IF;

    IF v_clean_dir NOT IN ('positive', 'negative') THEN
        RAISE EXCEPTION 'INVALID_DIRECTION: Dirección (%) no válida.', p_direction USING ERRCODE = '22023';
    END IF;

    IF v_clean_type <> 'ajuste_conteo' AND v_clean_dir <> 'negative' THEN
        RAISE EXCEPTION 'INVALID_DIRECTION: Solo ajuste_conteo admite dirección positiva.' USING ERRCODE = '22023';
    END IF;

    IF LENGTH(v_clean_reason) < 3 THEN
        RAISE EXCEPTION 'EMPTY_REASON: El motivo debe tener al menos 3 caracteres.' USING ERRCODE = '22023';
    END IF;

    SELECT id, store_id, name, current_stock, cost_price, price, is_active
    INTO v_product
    FROM public.products
    WHERE id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PRODUCT_NOT_FOUND: El producto (%) no existe.', p_product_id USING ERRCODE = 'P0002';
    END IF;

    v_store_id := v_product.store_id;

    -- Seguridad centralizada (Regla 4) + Permiso único C3 (canManageInventory / Admin)
    PERFORM public.assert_store_access(v_store_id);
    PERFORM public.assert_employee_permission(v_store_id, 'canManageInventory');

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_store_id);
    SELECT e.id INTO v_emp_fk_id
    FROM public.employees e
    WHERE e.id = COALESCE(public.get_employee_id_from_session(), v_snap.actor_id)
      AND e.store_id = v_store_id
    LIMIT 1;

    IF p_supplier_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.suppliers WHERE id = p_supplier_id AND store_id = v_store_id) THEN
            RAISE EXCEPTION 'SUPPLIER_NOT_FOUND: El proveedor no pertenece a la tienda activa.'
                USING ERRCODE = 'P0002';
        END IF;
    END IF;

    IF v_clean_type = 'ajuste_conteo' THEN
        v_signed_qty := CASE WHEN v_clean_dir = 'positive' THEN p_quantity ELSE -p_quantity END;
    ELSE
        v_signed_qty := p_quantity;
    END IF;

    IF v_clean_dir = 'negative' THEN
        IF p_batch_id IS NOT NULL THEN
            -- Baja sobre un lote puntual (Arquetipo D) con bloqueo FOR UPDATE
            SELECT id, product_id, quantity_remaining, cost_unit, sale_price
            INTO v_batch
            FROM public.inventory_batches
            WHERE id = p_batch_id
              AND product_id = p_product_id
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'BATCH_NOT_FOUND: El lote (%) no existe o no pertenece al producto.', p_batch_id
                    USING ERRCODE = 'P0002';
            END IF;

            IF v_batch.quantity_remaining < p_quantity THEN
                RAISE EXCEPTION 'BATCH_STOCK_INSUFFICIENT: Stock insuficiente en el lote seleccionado (disponible: %, solicitado: %).',
                    v_batch.quantity_remaining, p_quantity
                    USING ERRCODE = 'P0001';
            END IF;

            UPDATE public.inventory_batches
            SET quantity_remaining = quantity_remaining - p_quantity
            WHERE id = p_batch_id;

            PERFORM set_config('app.skip_bridge_movement_to_batch', 'true', true);
            INSERT INTO public.inventory_movements (
                product_id, movement_type, quantity, reason, created_by,
                actor_name, actor_role, supplier_id,
                unit_cost, reference_sale_price
            ) VALUES (
                p_product_id,
                v_clean_type,
                v_signed_qty,
                v_clean_reason,
                v_emp_fk_id,
                v_snap.actor_name,
                v_snap.actor_role,
                CASE WHEN v_clean_type = 'devolucion_proveedor' THEN p_supplier_id ELSE NULL END,
                v_batch.cost_unit,
                v_batch.sale_price
            ) RETURNING id INTO v_movement_id;
            PERFORM set_config('app.skip_bridge_movement_to_batch', 'false', true);

            INSERT INTO public.inventory_movement_batches (movement_id, batch_id, quantity_consumed, unit_cost)
            VALUES (v_movement_id, p_batch_id, p_quantity, v_batch.cost_unit);

            v_target_batch_id := p_batch_id;
        ELSE
            -- Baja FIFO automática vía trigger bridge_movement_to_batch()
            INSERT INTO public.inventory_movements (
                product_id, movement_type, quantity, reason, created_by,
                actor_name, actor_role, supplier_id,
                unit_cost, reference_sale_price
            ) VALUES (
                p_product_id,
                v_clean_type,
                v_signed_qty,
                v_clean_reason,
                v_emp_fk_id,
                v_snap.actor_name,
                v_snap.actor_role,
                CASE WHEN v_clean_type = 'devolucion_proveedor' THEN p_supplier_id ELSE NULL END,
                NULL,
                NULL
            ) RETURNING id INTO v_movement_id;
        END IF;
    ELSE
        -- ajuste_conteo positivo (sobrante físico)
        IF p_batch_id IS NOT NULL THEN
            SELECT id, product_id, quantity_remaining, cost_unit, sale_price
            INTO v_batch
            FROM public.inventory_batches
            WHERE id = p_batch_id
              AND product_id = p_product_id
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'BATCH_NOT_FOUND: El lote (%) no existe o no pertenece al producto.', p_batch_id
                    USING ERRCODE = 'P0002';
            END IF;

            UPDATE public.inventory_batches
            SET quantity_remaining = quantity_remaining + p_quantity,
                quantity_initial = quantity_initial + p_quantity
            WHERE id = p_batch_id;

            PERFORM set_config('app.skip_bridge_movement_to_batch', 'true', true);
            INSERT INTO public.inventory_movements (
                product_id, movement_type, quantity, reason, created_by,
                actor_name, actor_role, supplier_id,
                unit_cost, reference_sale_price
            ) VALUES (
                p_product_id,
                v_clean_type,
                v_signed_qty,
                v_clean_reason,
                v_emp_fk_id,
                v_snap.actor_name,
                v_snap.actor_role,
                NULL,
                v_batch.cost_unit,
                v_batch.sale_price
            ) RETURNING id INTO v_movement_id;
            PERFORM set_config('app.skip_bridge_movement_to_batch', 'false', true);

            v_target_batch_id := p_batch_id;
        ELSE
            -- Sin lote explícito: usar lote activo más reciente si existe; si stock=0, crear nuevo lote al último costo conocido
            SELECT id, cost_unit, sale_price
            INTO v_batch
            FROM public.inventory_batches
            WHERE product_id = p_product_id
              AND quantity_remaining > 0
            ORDER BY created_at DESC
            LIMIT 1
            FOR UPDATE;

            IF FOUND THEN
                UPDATE public.inventory_batches
                SET quantity_remaining = quantity_remaining + p_quantity,
                    quantity_initial = quantity_initial + p_quantity
                WHERE id = v_batch.id;

                PERFORM set_config('app.skip_bridge_movement_to_batch', 'true', true);
                INSERT INTO public.inventory_movements (
                    product_id, movement_type, quantity, reason, created_by,
                    actor_name, actor_role, supplier_id,
                    unit_cost, reference_sale_price
                ) VALUES (
                    p_product_id,
                    v_clean_type,
                    v_signed_qty,
                    v_clean_reason,
                    v_emp_fk_id,
                    v_snap.actor_name,
                    v_snap.actor_role,
                    NULL,
                    v_batch.cost_unit,
                    v_batch.sale_price
                ) RETURNING id INTO v_movement_id;
                PERFORM set_config('app.skip_bridge_movement_to_batch', 'false', true);

                v_target_batch_id := v_batch.id;
            ELSE
                INSERT INTO public.inventory_movements (
                    product_id, movement_type, quantity, reason, created_by,
                    actor_name, actor_role, supplier_id,
                    unit_cost, reference_sale_price
                ) VALUES (
                    p_product_id,
                    v_clean_type,
                    v_signed_qty,
                    v_clean_reason,
                    v_emp_fk_id,
                    v_snap.actor_name,
                    v_snap.actor_role,
                    NULL,
                    COALESCE(v_product.cost_price, 0),
                    COALESCE(v_product.price, 0)
                ) RETURNING id INTO v_movement_id;

                SELECT id INTO v_target_batch_id
                FROM public.inventory_batches
                WHERE source_movement_id = v_movement_id
                LIMIT 1;
            END IF;
        END IF;
    END IF;

    SELECT current_stock INTO v_new_stock FROM public.products WHERE id = p_product_id;
    SELECT unit_cost INTO v_recorded_cost FROM public.inventory_movements WHERE id = v_movement_id;

    IF v_clean_type = 'ajuste_conteo' THEN
        INSERT INTO public.notifications (
            store_id, type, title, message, audience, is_read, metadata
        ) VALUES (
            v_store_id,
            'inventory',
            'Ajuste por Conteo Físico',
            format('%s ajustó "%s" (%s%s unid.). Motivo: %s',
                v_snap.actor_name, v_product.name,
                CASE WHEN v_signed_qty > 0 THEN '+' ELSE '' END,
                v_signed_qty, v_clean_reason),
            'admin',
            false,
            jsonb_build_object(
                'event_type', 'INVENTORY_COUNT_ADJUSTMENT',
                'movement_id', v_movement_id,
                'product_id', p_product_id,
                'batch_id', v_target_batch_id,
                'quantity', v_signed_qty,
                'actor_name', v_snap.actor_name,
                'actor_role', v_snap.actor_role
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'movement_id', v_movement_id,
            'product_id', p_product_id,
            'batch_id', v_target_batch_id,
            'movement_type', v_clean_type,
            'quantity', v_signed_qty,
            'new_stock', v_new_stock,
            'unit_cost', v_recorded_cost,
            'actor_name', v_snap.actor_name,
            'actor_role', v_snap.actor_role,
            'created_at', NOW()
        )
    );
EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('app.skip_bridge_movement_to_batch', 'false', true);
    RAISE;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.rpc_registrar_salida_logistica(UUID, TEXT, NUMERIC, TEXT, TEXT, UUID, UUID)
    TO anon, authenticated, service_role;

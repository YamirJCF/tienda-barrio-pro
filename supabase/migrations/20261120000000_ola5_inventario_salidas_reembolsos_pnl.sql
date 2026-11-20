-- ============================================================================
-- FASE 3 · OLA 5: Inventario Completo (canManageInventory), Salidas Logísticas $0,
-- Reembolsos "merma" y P&L de 4 Pilares (CHK-501 .. CHK-512)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CHK-501: Columna reversed_movement_id, refunded_quantity, constraints y GRANTs
-- ----------------------------------------------------------------------------
ALTER TABLE public.inventory_movements
    ADD COLUMN IF NOT EXISTS reversed_movement_id UUID REFERENCES public.inventory_movements(id);

CREATE INDEX IF NOT EXISTS idx_inventory_movements_reversed_id
    ON public.inventory_movements (reversed_movement_id)
    WHERE reversed_movement_id IS NOT NULL;

ALTER TABLE public.sale_items
    ADD COLUMN IF NOT EXISTS refunded_quantity NUMERIC NOT NULL DEFAULT 0;

-- Regla 8: Privilegios explícitos para tablas de inventario / auditoría de precios
GRANT ALL ON TABLE public.inventory_movements TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.inventory_batches TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.inventory_movement_batches TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.product_price_history TO anon, authenticated, service_role;

-- CHK-508: Ampliar cash_movements_movement_type_check para admitir 'reembolso'
ALTER TABLE public.cash_movements
    DROP CONSTRAINT IF EXISTS cash_movements_movement_type_check;

ALTER TABLE public.cash_movements
    ADD CONSTRAINT cash_movements_movement_type_check
    CHECK (movement_type = ANY (ARRAY['ingreso'::text, 'gasto'::text, 'pago_proveedor'::text, 'reembolso'::text]));

-- ----------------------------------------------------------------------------
-- 2. CHK-502: Desacoplar Trigger bridge_movement_to_batch y validate_payment_type
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_payment_type()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    -- Independencia Logística/CxP (CHK-502 / SDD-006-01-01):
    -- El proveedor en entradas es puramente informativo; no obliga payment_type ni genera facturas.
    RETURN NEW;
END;
$function$;

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

-- ----------------------------------------------------------------------------
-- 3. CHK-505: rpc_registrar_entrada (Drop sobrecarga 5 args, exigir canManageInventory)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.rpc_registrar_entrada(uuid, numeric, numeric, numeric, text);

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
        VALUES (p_product_id, p_purchase_price, p_sale_price, v_emp_fk_id);

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

CREATE OR REPLACE FUNCTION public.rpc_registrar_entrada_masiva(p_store_id uuid, p_entries jsonb)
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
            VALUES (v_product_id, v_purchase_price, v_sale_price, v_emp_fk_id);

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

-- ----------------------------------------------------------------------------
-- 4. CHK-506: rpc_actualizar_precio_lote (Drop 2 args, habilitar canManageInventory),
--    rpc_soft_delete_product y rpc_actualizar_producto_catalogo
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.rpc_actualizar_precio_lote(uuid, numeric);

CREATE OR REPLACE FUNCTION public.rpc_actualizar_precio_lote(
    p_batch_id uuid,
    p_cost_unit numeric,
    p_sale_price numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_batch RECORD;
    v_snap RECORD;
    v_emp_fk_id UUID;
BEGIN
    IF p_cost_unit IS NULL OR p_cost_unit < 0 OR p_sale_price IS NULL OR p_sale_price <= 0 THEN
        RAISE EXCEPTION 'INVALID_PRICE: El costo debe ser >= 0 y el precio de venta > 0.'
            USING ERRCODE = '22023';
    END IF;

    SELECT b.*, p.store_id
    INTO v_batch
    FROM public.inventory_batches b
    JOIN public.products p ON b.product_id = p.id
    WHERE b.id = p_batch_id
    FOR UPDATE OF b;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'BATCH_NOT_FOUND: El lote especificado (%) no existe.', p_batch_id
            USING ERRCODE = 'P0002';
    END IF;

    PERFORM public.assert_store_access(v_batch.store_id);
    PERFORM public.assert_employee_permission(v_batch.store_id, 'canManageInventory');

    IF COALESCE(v_batch.quantity_remaining, 0) <= 0 THEN
        RAISE EXCEPTION 'BATCH_DEPLETED: Solo se pueden editar precios de lotes activos con existencias.'
            USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_batch.store_id);
    SELECT e.id INTO v_emp_fk_id
    FROM public.employees e
    WHERE e.id = COALESCE(public.get_employee_id_from_session(), v_snap.actor_id)
      AND e.store_id = v_batch.store_id
    LIMIT 1;

    UPDATE public.inventory_batches
    SET cost_unit = p_cost_unit,
        sale_price = p_sale_price
    WHERE id = p_batch_id;

    INSERT INTO public.audit_logs (
        store_id, actor_id, actor_name, actor_role, event_type, resource_id, metadata, severity
    ) VALUES (
        v_batch.store_id,
        v_emp_fk_id,
        v_snap.actor_name,
        v_snap.actor_role,
        'INVENTORY_BATCH_UPDATE',
        p_batch_id::TEXT,
        jsonb_build_object(
            'old_cost', v_batch.cost_unit,
            'new_cost', p_cost_unit,
            'old_price', v_batch.sale_price,
            'new_price', p_sale_price,
            'product_id', v_batch.product_id
        ),
        'info'
    );

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'batch_id', p_batch_id,
            'cost_unit', p_cost_unit,
            'sale_price', p_sale_price,
            'actor_name', v_snap.actor_name
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_soft_delete_product(p_product_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_current_stock NUMERIC;
    v_store_id UUID;
    v_product_name TEXT;
    v_snap RECORD;
    v_emp_fk_id UUID;
BEGIN
    SELECT current_stock, store_id, name
    INTO v_current_stock, v_store_id, v_product_name
    FROM public.products
    WHERE id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PRODUCT_NOT_FOUND: El producto especificado (%) no existe.', p_product_id
            USING ERRCODE = 'P0002';
    END IF;

    PERFORM public.assert_store_access(v_store_id);
    PERFORM public.assert_employee_permission(v_store_id, 'canManageInventory');

    IF COALESCE(v_current_stock, 0) > 0 THEN
        RAISE EXCEPTION 'STOCK_REMAINING: El producto tiene existencias (%). Debe registrar un Ajuste de Salida o Merma antes de darlo de baja.', v_current_stock
            USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_store_id);
    SELECT e.id INTO v_emp_fk_id
    FROM public.employees e
    WHERE e.id = COALESCE(public.get_employee_id_from_session(), v_snap.actor_id)
      AND e.store_id = v_store_id
    LIMIT 1;

    UPDATE public.products
    SET is_active = false,
        plu = 'DEL-' || substr(id::text, 1, 8),
        name = CASE WHEN name LIKE '[ELIMINADO] %' THEN name ELSE '[ELIMINADO] ' || v_product_name END,
        updated_at = NOW()
    WHERE id = p_product_id;

    INSERT INTO public.audit_logs (
        store_id, actor_id, actor_name, actor_role, event_type, resource_id, metadata, severity
    ) VALUES (
        v_store_id,
        v_emp_fk_id,
        v_snap.actor_name,
        v_snap.actor_role,
        'PRODUCT_SOFT_DELETED',
        p_product_id::text,
        jsonb_build_object('product_name', v_product_name),
        'warning'
    );

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'product_id', p_product_id,
            'is_active', false,
            'status', 'deleted',
            'actor_name', v_snap.actor_name
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_actualizar_producto_catalogo(
    p_product_id uuid,
    p_name text,
    p_price numeric,
    p_expected_old_price numeric,
    p_expected_name text,
    p_cost numeric DEFAULT NULL::numeric,
    p_min_stock numeric DEFAULT 0,
    p_plu text DEFAULT NULL::text,
    p_category text DEFAULT NULL::text,
    p_expected_old_cost numeric DEFAULT NULL::numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_user_id UUID := COALESCE(public.get_employee_id_from_session(), auth.uid());
    v_employee_id UUID;
    v_snap RECORD;
    v_store_id UUID;
    v_current_name TEXT;
    v_current_price NUMERIC;
    v_current_cost NUMERIC;
    v_current_min_stock NUMERIC;
    v_current_plu TEXT;
    v_current_category TEXT;
    v_is_active BOOLEAN;
    v_last_price_change TIMESTAMPTZ;
    v_last_my_change TIMESTAMPTZ;
    v_ip TEXT;
    v_user_agent TEXT;
BEGIN
    IF p_product_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'code', 'INVALID_PARAMS', 'error', 'p_product_id es obligatorio');
    END IF;

    IF p_name IS NULL OR length(trim(p_name)) < 2 THEN
        RETURN jsonb_build_object('success', false, 'code', 'INVALID_NAME', 'error', 'El nombre debe tener al menos 2 caracteres');
    END IF;

    IF p_price IS NULL OR p_price < 50 THEN
        RETURN jsonb_build_object('success', false, 'code', 'INVALID_PRICE', 'error', 'El precio debe ser mayor o igual a $50 COP');
    END IF;

    IF p_expected_old_price IS NULL OR p_expected_name IS NULL THEN
        RETURN jsonb_build_object('success', false, 'code', 'MISSING_SNAPSHOT_SEAL', 'error', 'El sello de estado base (Escudo 2) es obligatorio');
    END IF;

    SELECT store_id, name, price, cost_price, min_stock, plu, category, is_active
    INTO v_store_id, v_current_name, v_current_price, v_current_cost, v_current_min_stock, v_current_plu, v_current_category, v_is_active
    FROM public.products
    WHERE id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'code', 'PRODUCT_NOT_FOUND', 'error', 'El producto especificado no existe');
    END IF;

    PERFORM public.assert_store_access(v_store_id);
    PERFORM public.assert_employee_permission(v_store_id, 'canManageInventory');

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_store_id);
    SELECT id INTO v_employee_id
    FROM public.employees
    WHERE id = COALESCE(public.get_employee_id_from_session(), v_snap.actor_id, v_user_id)
      AND store_id = v_store_id
      AND is_active = true
    LIMIT 1;

    BEGIN
        v_ip := current_setting('request.headers', true)::json->>'x-forwarded-for';
        v_user_agent := current_setting('request.headers', true)::json->>'user-agent';
    EXCEPTION WHEN OTHERS THEN
        v_ip := NULL;
        v_user_agent := NULL;
    END;

    IF (p_price IS DISTINCT FROM v_current_price) OR (p_cost IS DISTINCT FROM v_current_cost) THEN
        SELECT max(created_at) INTO v_last_price_change
        FROM public.audit_precios
        WHERE product_id = p_product_id;

        IF v_last_price_change IS NOT NULL AND (now() - v_last_price_change) < interval '3 seconds' THEN
            INSERT INTO public.audit_seguridad (
                actor_id, store_id, event_type, ip_address, user_agent, metadata
            ) VALUES (
                v_employee_id, v_store_id, 'CONCURRENT_MUTATION_BLOCKED', v_ip, v_user_agent,
                jsonb_build_object(
                    'reason', 'MUTATION_COOLDOWN_ACTIVE',
                    'product_id', p_product_id,
                    'last_change', v_last_price_change,
                    'attempted_price', p_price,
                    'user_id', v_user_id
                )
            );

            RETURN jsonb_build_object(
                'success', false,
                'code', 'MUTATION_COOLDOWN_ACTIVE',
                'error', 'Operación bloqueada temporalmente por cooldown de seguridad (3 segundos).'
            );
        END IF;
    END IF;

    IF (v_current_price IS DISTINCT FROM p_expected_old_price)
       OR (v_current_name IS DISTINCT FROM trim(p_expected_name)) THEN
        IF (v_current_price = p_price) AND (v_current_name = trim(p_name)) THEN
            SELECT max(created_at) INTO v_last_my_change
            FROM public.audit_precios
            WHERE product_id = p_product_id
              AND (changed_by = v_employee_id OR (changed_by IS NULL AND v_employee_id IS NULL));

            IF v_last_my_change IS NOT NULL AND (now() - v_last_my_change) < interval '10 seconds' THEN
                RETURN jsonb_build_object(
                    'success', true,
                    'code', 'ALREADY_APPLIED_IDEMPOTENT',
                    'message', 'Actualización ya aplicada en reintento previo.'
                );
            END IF;
        END IF;

        INSERT INTO public.audit_seguridad (
            actor_id, store_id, event_type, ip_address, user_agent, metadata
        ) VALUES (
            v_employee_id, v_store_id, 'CONCURRENT_MUTATION_BLOCKED', v_ip, v_user_agent,
            jsonb_build_object(
                'reason', 'STALE_VECTOR_SNAPSHOT',
                'product_id', p_product_id,
                'expected_price', p_expected_old_price,
                'current_price', v_current_price,
                'expected_name', p_expected_name,
                'current_name', v_current_name,
                'attempted_price', p_price,
                'attempted_name', trim(p_name),
                'user_id', v_user_id
            )
        );

        RETURN jsonb_build_object(
            'success', false,
            'code', 'CONCURRENT_MUTATION_BLOCKED',
            'error', 'Operación bloqueada. El producto fue modificado concurrentemente desde otro dispositivo.'
        );
    END IF;

    IF p_plu IS NOT NULL AND trim(p_plu) != '' AND (v_current_plu IS DISTINCT FROM trim(p_plu)) THEN
        IF EXISTS (
            SELECT 1 FROM public.products
            WHERE store_id = v_store_id
              AND plu = trim(p_plu)
              AND id != p_product_id
              AND is_active = true
        ) THEN
            RETURN jsonb_build_object(
                'success', false,
                'code', 'PLU_ALREADY_EXISTS',
                'error', 'El código PLU ya se encuentra asignado a otro producto activo'
            );
        END IF;
    END IF;

    UPDATE public.products
    SET name = trim(p_name),
        price = p_price,
        cost_price = p_cost,
        min_stock = COALESCE(p_min_stock, 0),
        plu = NULLIF(trim(p_plu), ''),
        category = NULLIF(trim(p_category), ''),
        updated_at = now()
    WHERE id = p_product_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'product_id', p_product_id,
            'name', trim(p_name),
            'price', p_price,
            'cost_price', p_cost,
            'min_stock', COALESCE(p_min_stock, 0),
            'plu', NULLIF(trim(p_plu), ''),
            'category', NULLIF(trim(p_category), '')
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 5. CHK-503: rpc_registrar_salida_logistica y rpc_registrar_contra_movimiento
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_registrar_salida_logistica(
    p_product_id uuid,
    p_movement_type text,
    p_quantity numeric,
    p_reason text,
    p_direction text DEFAULT 'negative'::text,
    p_supplier_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_product RECORD;
    v_store_id UUID;
    v_is_admin BOOLEAN := false;
    v_can_manage_inv BOOLEAN := false;
    v_can_see_cost BOOLEAN := false;
    v_snap RECORD;
    v_emp_fk_id UUID;
    v_today DATE := (NOW() AT TIME ZONE 'America/Bogota')::date;
    v_has_valid_pass BOOLEAN := false;
    v_clean_type TEXT := LOWER(TRIM(COALESCE(p_movement_type, '')));
    v_clean_dir TEXT := LOWER(TRIM(COALESCE(p_direction, 'negative')));
    v_clean_reason TEXT := TRIM(COALESCE(p_reason, ''));
    v_signed_qty NUMERIC;
    v_movement_id UUID;
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
    PERFORM public.assert_store_access(v_store_id);

    v_is_admin := public.is_store_admin(v_store_id);
    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_store_id);

    IF NOT v_is_admin THEN
        SELECT e.id, COALESCE((e.permissions->>'canManageInventory')::boolean, false)
        INTO v_emp_fk_id, v_can_manage_inv
        FROM public.employees e
        WHERE e.id = COALESCE(public.get_employee_id_from_session(), v_snap.actor_id)
          AND e.store_id = v_store_id
          AND e.is_active = true
        LIMIT 1;

        IF v_emp_fk_id IS NULL THEN
            RAISE EXCEPTION 'PERMISSION_DENIED: Colaborador inactivo o no autorizado en la tienda.'
                USING ERRCODE = '42501';
        END IF;

        -- Verificar pase diario vigente (<24h) SIN exigir caja abierta
        SELECT EXISTS (
            SELECT 1
            FROM public.daily_passes dp
            WHERE dp.employee_id = v_emp_fk_id
              AND dp.store_id = v_store_id
              AND dp.status = 'approved'
              AND (
                  dp.pass_date = v_today
                  OR (
                      dp.pass_date = v_today - 1
                      AND EXISTS (
                          SELECT 1
                          FROM public.cash_sessions cs
                          WHERE cs.store_id = v_store_id
                            AND cs.status = 'open'
                            AND cs.opened_at >= (NOW() - INTERVAL '24 hours')
                      )
                  )
              )
        ) INTO v_has_valid_pass;

        IF NOT v_has_valid_pass THEN
            RAISE EXCEPTION 'PERMISSION_DENIED: Requiere pase diario vigente (<24h) para registrar salidas logísticas.'
                USING ERRCODE = '42501';
        END IF;

        IF v_clean_type IN ('ajuste_conteo', 'devolucion_proveedor') AND NOT v_can_manage_inv THEN
            PERFORM public.assert_employee_permission(v_store_id, 'canManageInventory');
        END IF;
    ELSE
        v_can_manage_inv := true;
        SELECT e.id INTO v_emp_fk_id
        FROM public.employees e
        WHERE e.id = COALESCE(public.get_employee_id_from_session(), v_snap.actor_id)
          AND e.store_id = v_store_id
        LIMIT 1;
    END IF;

    v_can_see_cost := v_is_admin OR v_can_manage_inv;

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
        CASE WHEN v_clean_type = 'ajuste_conteo' AND v_signed_qty > 0 THEN COALESCE(v_product.cost_price, 0) ELSE NULL END,
        CASE WHEN v_clean_type = 'ajuste_conteo' AND v_signed_qty > 0 THEN COALESCE(v_product.price, 0) ELSE NULL END
    ) RETURNING id INTO v_movement_id;

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
            'movement_type', v_clean_type,
            'quantity', v_signed_qty,
            'new_stock', v_new_stock,
            'unit_cost', CASE WHEN v_can_see_cost THEN v_recorded_cost ELSE NULL END,
            'actor_name', v_snap.actor_name,
            'actor_role', v_snap.actor_role,
            'created_at', NOW()
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_registrar_contra_movimiento(
    p_original_movement_id uuid,
    p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_orig RECORD;
    v_snap RECORD;
    v_emp_fk_id UUID;
    v_clean_reason TEXT := TRIM(COALESCE(p_reason, ''));
    v_comp_qty NUMERIC;
    v_counter_id UUID;
    v_new_stock NUMERIC;
BEGIN
    IF p_original_movement_id IS NULL THEN
        RAISE EXCEPTION 'INVALID_MOVEMENT_ID: El movimiento original es obligatorio.' USING ERRCODE = '22023';
    END IF;

    IF LENGTH(v_clean_reason) < 5 THEN
        RAISE EXCEPTION 'EMPTY_REASON: El motivo del contra-movimiento debe tener al menos 5 caracteres.' USING ERRCODE = '22023';
    END IF;

    SELECT im.*, p.store_id, p.name AS product_name, p.cost_price AS current_cost, p.price AS current_price
    INTO v_orig
    FROM public.inventory_movements im
    JOIN public.products p ON p.id = im.product_id
    WHERE im.id = p_original_movement_id
    FOR UPDATE OF im, p;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'MOVEMENT_NOT_FOUND: El movimiento (%) no existe.', p_original_movement_id USING ERRCODE = 'P0002';
    END IF;

    PERFORM public.assert_store_access(v_orig.store_id);
    PERFORM public.assert_employee_permission(v_orig.store_id, 'canManageInventory');

    IF v_orig.movement_type IN ('venta', 'consumo_personal') THEN
        RAISE EXCEPTION 'UNREVERSIBLE_MOVEMENT_TYPE: Las ventas o retiros POS se revierten mediante anulación o reembolso, no por contra-movimiento directo.'
            USING ERRCODE = 'P0001';
    END IF;

    IF v_orig.movement_type = 'merma' AND COALESCE(v_orig.reason, '') LIKE '[REEMBOLSO-MERMA]%' THEN
        RAISE EXCEPTION 'UNREVERSIBLE_REFUND_MERMA: Un reembolso asentado como merma no ingresó inventario vendible.'
            USING ERRCODE = 'P0001';
    END IF;

    IF v_orig.reversed_movement_id IS NOT NULL OR EXISTS (
        SELECT 1 FROM public.inventory_movements WHERE reversed_movement_id = p_original_movement_id
    ) THEN
        RAISE EXCEPTION 'DOUBLE_REVERSAL_BLOCKED: Este movimiento ya cuenta con un contra-movimiento compensatorio.'
            USING ERRCODE = 'P0001';
    END IF;

    -- Signo compensatorio respecto al efecto real en existencias
    IF v_orig.movement_type IN ('entrada', 'devolucion') THEN
        v_comp_qty := -ABS(v_orig.quantity);
    ELSIF v_orig.movement_type IN ('salida', 'merma', 'consumo_negocio', 'devolucion_proveedor') THEN
        v_comp_qty := ABS(v_orig.quantity);
    ELSIF v_orig.movement_type IN ('ajuste', 'ajuste_conteo', 'CORRECCION_SISTEMA') THEN
        v_comp_qty := -(v_orig.quantity);
    ELSE
        RAISE EXCEPTION 'UNREVERSIBLE_MOVEMENT_TYPE: Tipo (%) no reversible.', v_orig.movement_type
            USING ERRCODE = 'P0001';
    END IF;

    IF v_comp_qty = 0 THEN
        RAISE EXCEPTION 'INVALID_QUANTITY: Cantidad compensatoria igual a cero.' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_orig.store_id);
    SELECT e.id INTO v_emp_fk_id
    FROM public.employees e
    WHERE e.id = COALESCE(public.get_employee_id_from_session(), v_snap.actor_id)
      AND e.store_id = v_orig.store_id
    LIMIT 1;

    INSERT INTO public.inventory_movements (
        product_id, movement_type, quantity, reason, created_by,
        actor_name, actor_role, unit_cost, reference_sale_price, reversed_movement_id
    ) VALUES (
        v_orig.product_id,
        'ajuste_conteo',
        v_comp_qty,
        '[CONTRA-MOV] ' || v_clean_reason,
        v_emp_fk_id,
        v_snap.actor_name,
        v_snap.actor_role,
        COALESCE(v_orig.unit_cost, v_orig.current_cost, 0),
        COALESCE(v_orig.reference_sale_price, v_orig.current_price, 0),
        p_original_movement_id
    ) RETURNING id INTO v_counter_id;

    SELECT current_stock INTO v_new_stock FROM public.products WHERE id = v_orig.product_id;

    INSERT INTO public.notifications (
        store_id, type, title, message, audience, is_read, metadata
    ) VALUES (
        v_orig.store_id,
        'inventory',
        'Contra-movimiento en Kardex',
        format('%s registró contra-movimiento sobre "%s" (%s%s). Motivo: %s',
            v_snap.actor_name, v_orig.product_name,
            CASE WHEN v_comp_qty > 0 THEN '+' ELSE '' END,
            v_comp_qty, v_clean_reason),
        'admin',
        false,
        jsonb_build_object(
            'event_type', 'INVENTORY_COUNTER_MOVEMENT',
            'counter_movement_id', v_counter_id,
            'original_movement_id', p_original_movement_id,
            'quantity', v_comp_qty,
            'actor_name', v_snap.actor_name
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'counter_movement_id', v_counter_id,
            'original_movement_id', p_original_movement_id,
            'product_id', v_orig.product_id,
            'quantity', v_comp_qty,
            'new_stock', v_new_stock,
            'actor_name', v_snap.actor_name,
            'actor_role', v_snap.actor_role
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 6. CHK-508 / CHK-509: Reembolsos por Ítem, Búsqueda stock = 0 y Cajas sincronizadas
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_procesar_reembolso_item(
    p_sale_item_id uuid,
    p_quantity numeric,
    p_refund_channel text,
    p_original_channel text,
    p_reason text,
    p_is_merma boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_item RECORD;
    v_sale RECORD;
    v_product RECORD;
    v_session RECORD;
    v_snap RECORD;
    v_emp_fk_id UUID;
    v_refund_chan TEXT := LOWER(TRIM(COALESCE(p_refund_channel, '')));
    v_orig_chan TEXT := LOWER(TRIM(COALESCE(p_original_channel, '')));
    v_clean_reason TEXT := TRIM(COALESCE(p_reason, ''));
    v_remaining_qty NUMERIC;
    v_refund_amount NUMERIC;
    v_ingresos NUMERIC := 0;
    v_egresos NUMERIC := 0;
    v_available NUMERIC := 0;
    v_cash_mov_id UUID;
    v_inv_mov_id UUID;
    v_cost_unit NUMERIC;
    v_new_stock NUMERIC;
BEGIN
    IF p_sale_item_id IS NULL THEN
        RAISE EXCEPTION 'INVALID_ITEM: El ítem de venta es obligatorio.' USING ERRCODE = '22023';
    END IF;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'INVALID_QUANTITY: La cantidad a reembolsar debe ser mayor a cero.' USING ERRCODE = '22023';
    END IF;

    IF v_refund_chan NOT IN ('efectivo', 'nequi', 'llave_bre') THEN
        RAISE EXCEPTION 'INVALID_REFUND_CHANNEL: Canal de egreso (%) no válido. Use efectivo, nequi o llave_bre.', p_refund_channel
            USING ERRCODE = '22023';
    END IF;

    IF v_orig_chan NOT IN ('efectivo', 'nequi', 'llave_bre', 'fiado', 'transferencia') THEN
        RAISE EXCEPTION 'INVALID_ORIGINAL_CHANNEL: Canal original (%) no reconocido.', p_original_channel
            USING ERRCODE = '22023';
    END IF;

    IF LENGTH(v_clean_reason) < 5 THEN
        RAISE EXCEPTION 'EMPTY_REASON: El motivo del reembolso debe tener al menos 5 caracteres.' USING ERRCODE = '22023';
    END IF;

    SELECT si.*
    INTO v_item
    FROM public.sale_items si
    WHERE si.id = p_sale_item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'SALE_ITEM_NOT_FOUND: El ítem de venta (%) no existe.', p_sale_item_id USING ERRCODE = 'P0002';
    END IF;

    SELECT * INTO v_sale
    FROM public.sales
    WHERE id = v_item.sale_id
    FOR UPDATE;

    PERFORM public.assert_store_access(v_sale.store_id);
    PERFORM public.assert_employee_permission(v_sale.store_id, 'canManageRefunds');

    IF v_sale.is_voided THEN
        RAISE EXCEPTION 'SALE_ALREADY_VOIDED: No se pueden reembolsar ítems de una venta anulada.'
            USING ERRCODE = 'P0001';
    END IF;

    IF v_sale.payment_method = 'consumo_personal' THEN
        RAISE EXCEPTION 'CONSUMO_PERSONAL_NO_REFUND: Un retiro personal ($0) no admite reembolso monetario.'
            USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_product
    FROM public.products
    WHERE id = v_item.product_id
    FOR UPDATE;

    v_remaining_qty := COALESCE(v_item.quantity, 0) - COALESCE(v_item.refunded_quantity, 0);
    IF p_quantity > v_remaining_qty THEN
        RAISE EXCEPTION 'QUANTITY_EXCEEDED: Cantidad solicitada (%) excede el remanente reembolsable (%) de la venta #%s.',
            p_quantity, v_remaining_qty, v_sale.ticket_number
            USING ERRCODE = 'P0001';
    END IF;

    -- Autoridad financiera inmutable en servidor
    v_refund_amount := ROUND((COALESCE(v_item.subtotal, 0) / NULLIF(v_item.quantity, 0)) * p_quantity, 0);
    IF COALESCE(v_refund_amount, 0) <= 0 THEN
        v_refund_amount := ROUND(COALESCE(v_item.unit_price, v_product.price, 0) * p_quantity, 0);
    END IF;
    IF COALESCE(v_refund_amount, 0) <= 0 THEN
        RAISE EXCEPTION 'INVALID_REFUND_AMOUNT: No se pudo calcular un monto positivo de reembolso.'
            USING ERRCODE = 'P0001';
    END IF;

    -- Verificar caja abierta vigente (<24h)
    SELECT * INTO v_session
    FROM public.cash_sessions
    WHERE store_id = v_sale.store_id
      AND status = 'open'
    ORDER BY opened_at DESC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'NO_OPEN_CASH_SESSION: Debe existir una sesión de caja abierta para procesar reembolsos.'
            USING ERRCODE = 'P0001';
    END IF;

    IF (NOW() - v_session.opened_at) > INTERVAL '24 hours' THEN
        RAISE EXCEPTION 'SHIFT_EXPIRED_24H: El turno abierto superó 24 horas y debe cerrarse antes de continuar.'
            USING ERRCODE = 'P0001';
    END IF;

    -- Verificar liquidez exacta por canal sin compensación cruzada (POL-FIN-02)
    SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
    FROM public.cash_movements
    WHERE session_id = v_session.id
      AND movement_type = 'ingreso'
      AND payment_method = v_refund_chan;

    SELECT COALESCE(SUM(amount), 0) INTO v_egresos
    FROM public.cash_movements
    WHERE session_id = v_session.id
      AND movement_type IN ('gasto', 'pago_proveedor', 'reembolso')
      AND payment_method = v_refund_chan;

    v_available := (CASE WHEN v_refund_chan = 'efectivo' THEN COALESCE(v_session.opening_balance, 0) ELSE 0 END)
                   + v_ingresos - v_egresos;

    IF v_refund_amount > v_available THEN
        RAISE EXCEPTION 'INSUFFICIENT_FUNDS_IN_CHANNEL: Fondos insuficientes en % (Disponible: $%, Requerido: $%).',
            v_refund_chan, v_available, v_refund_amount
            USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_sale.store_id);
    SELECT e.id INTO v_emp_fk_id
    FROM public.employees e
    WHERE e.id = COALESCE(public.get_employee_id_from_session(), v_snap.actor_id)
      AND e.store_id = v_sale.store_id
    LIMIT 1;

    -- 1. Registrar egreso de reembolso en cash_movements
    INSERT INTO public.cash_movements (
        session_id, movement_type, amount, description, sale_id, payment_method, category,
        actor_id, actor_name, actor_role
    ) VALUES (
        v_session.id,
        'reembolso',
        v_refund_amount,
        '[REEMBOLSO' || CASE WHEN COALESCE(p_is_merma, false) THEN '-MERMA' ELSE '' END || '] #'
            || v_sale.ticket_number || ' · CanalOrig:' || v_orig_chan || ' · ' || v_clean_reason,
        v_sale.id,
        v_refund_chan,
        CASE WHEN COALESCE(p_is_merma, false) THEN 'reembolso_merma' ELSE 'reembolso' END,
        v_emp_fk_id,
        v_snap.actor_name,
        v_snap.actor_role
    ) RETURNING id INTO v_cash_mov_id;

    -- 2. Acumular cantidad reembolsada sobre el ítem vendido
    UPDATE public.sale_items
    SET refunded_quantity = COALESCE(refunded_quantity, 0) + p_quantity
    WHERE id = p_sale_item_id;

    -- 3. Bifurcación física: "merma" vs devolución vendible
    v_cost_unit := COALESCE(NULLIF(v_item.unit_cost, 0), v_product.cost_price, 0);

    IF COALESCE(p_is_merma, false) IS TRUE THEN
        -- Producto dañado / no apto: NO reingresa a stock ni lotes; asienta directo a merma en P&L
        INSERT INTO public.inventory_movements (
            product_id, movement_type, quantity, reason, created_by,
            actor_name, actor_role, unit_cost, session_id
        ) VALUES (
            v_item.product_id,
            'merma',
            p_quantity,
            '[REEMBOLSO-MERMA] #' || v_sale.ticket_number || ' [ITEM:' || p_sale_item_id::text || '] ' || v_clean_reason,
            v_emp_fk_id,
            v_snap.actor_name,
            v_snap.actor_role,
            v_cost_unit,
            v_session.id
        ) RETURNING id INTO v_inv_mov_id;

        INSERT INTO public.notifications (
            store_id, type, title, message, audience, is_read, metadata
        ) VALUES (
            v_sale.store_id,
            'finance',
            'Reembolso Asentado como Merma',
            format('%s reembolsó $%s por %s unid. dañadas de "%s" (Ticket #%s).',
                v_snap.actor_name, v_refund_amount, p_quantity, v_product.name, v_sale.ticket_number),
            'admin',
            false,
            jsonb_build_object(
                'event_type', 'REFUND_MERMA',
                'sale_id', v_sale.id,
                'sale_item_id', p_sale_item_id,
                'product_id', v_item.product_id,
                'amount_refunded', v_refund_amount,
                'cost_loss', ROUND(p_quantity * v_cost_unit, 2),
                'actor_name', v_snap.actor_name
            )
        );
    ELSE
        -- Devolución apta para reventa: reingresa nueva capa FIFO vendible
        INSERT INTO public.inventory_movements (
            product_id, movement_type, quantity, reason, created_by,
            actor_name, actor_role, unit_cost, reference_sale_price, session_id
        ) VALUES (
            v_item.product_id,
            'devolucion',
            p_quantity,
            '[REEMBOLSO] #' || v_sale.ticket_number || ' [ITEM:' || p_sale_item_id::text || '] ' || v_clean_reason,
            v_emp_fk_id,
            v_snap.actor_name,
            v_snap.actor_role,
            v_cost_unit,
            COALESCE(v_item.unit_price, v_product.price, 0),
            v_session.id
        ) RETURNING id INTO v_inv_mov_id;
    END IF;

    SELECT current_stock INTO v_new_stock FROM public.products WHERE id = v_item.product_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'cash_movement_id', v_cash_mov_id,
            'inventory_movement_id', v_inv_mov_id,
            'sale_id', v_sale.id,
            'sale_item_id', p_sale_item_id,
            'ticket_number', v_sale.ticket_number,
            'amount_refunded', v_refund_amount,
            'quantity_refunded', p_quantity,
            'refund_channel', v_refund_chan,
            'original_channel', v_orig_chan,
            'is_merma', COALESCE(p_is_merma, false),
            'new_stock', v_new_stock,
            'actor_name', v_snap.actor_name,
            'actor_role', v_snap.actor_role
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_buscar_ventas_para_reembolso(
    p_store_id uuid,
    p_query text DEFAULT NULL::text,
    p_limit integer DEFAULT 20
)
RETURNS jsonb
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
                                'subtotal', si.subtotal
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

DROP FUNCTION IF EXISTS public.buscar_producto_pos(uuid, text, integer, integer);

CREATE OR REPLACE FUNCTION public.buscar_producto_pos(
    p_store_id uuid,
    p_term text,
    p_limit integer DEFAULT 10,
    p_offset integer DEFAULT 0,
    p_include_zero_stock boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_clean_term TEXT := TRIM(p_term);
    v_is_numeric BOOLEAN;
    v_exact RECORD;
    v_results JSONB;
    v_count INTEGER;
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    IF v_clean_term IS NULL OR LENGTH(v_clean_term) = 0 THEN
        RETURN jsonb_build_object('data', '[]'::jsonb, 'count', 0, 'match_type', 'none');
    END IF;

    v_is_numeric := (v_clean_term ~ '^[0-9]+$');

    SELECT id, name, plu, price, current_stock, measurement_unit, is_weighable
    INTO v_exact
    FROM public.products
    WHERE store_id = p_store_id
      AND is_active = true
      AND plu = v_clean_term
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object(
                'id', v_exact.id,
                'name', v_exact.name,
                'plu', v_exact.plu,
                'price', v_exact.price,
                'current_stock', v_exact.current_stock,
                'measurement_unit', v_exact.measurement_unit,
                'is_weighable', v_exact.is_weighable
            )),
            'count', 1,
            'match_type', 'exact_plu'
        );
    END IF;

    IF v_is_numeric THEN
        RETURN jsonb_build_object('data', '[]'::jsonb, 'count', 0, 'match_type', 'not_found');
    END IF;

    IF LENGTH(v_clean_term) < 2 THEN
        RAISE EXCEPTION 'TERM_TOO_SHORT: Ingrese al menos 2 caracteres para buscar por nombre.'
            USING ERRCODE = '22023';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM public.products
    WHERE store_id = p_store_id
      AND is_active = true
      AND (COALESCE(p_include_zero_stock, false) = true OR current_stock > 0)
      AND name ILIKE ('%' || v_clean_term || '%');

    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb) INTO v_results
    FROM (
        SELECT id, name, plu, price, current_stock, measurement_unit, is_weighable
        FROM public.products
        WHERE store_id = p_store_id
          AND is_active = true
          AND (COALESCE(p_include_zero_stock, false) = true OR current_stock > 0)
          AND name ILIKE ('%' || v_clean_term || '%')
        ORDER BY name ASC
        LIMIT LEAST(p_limit, 50)
        OFFSET p_offset
    ) sub;

    RETURN jsonb_build_object(
        'data', v_results,
        'count', v_count,
        'match_type', 'partial_name'
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_anular_venta(p_sale_id uuid, p_reason text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_store_id UUID;
    v_sale RECORD;
    v_item RECORD;
    v_employee_id UUID;
    v_snap RECORD;
    v_client_balance NUMERIC;
    v_client_deleted BOOLEAN;
    v_session_id UUID;
    v_session_opened_at TIMESTAMPTZ;
    v_opening NUMERIC := 0;
    v_ingresos NUMERIC := 0;
    v_egresos NUMERIC := 0;
    v_available NUMERIC := 0;
BEGIN
    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED' USING ERRCODE = '42501';
    END IF;
    PERFORM public.assert_store_admin(v_store_id);

    SELECT * INTO v_sale
    FROM public.sales
    WHERE id = p_sale_id
      AND store_id = v_store_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venta no encontrada (SALE_NOT_FOUND)' USING ERRCODE = 'P0001';
    END IF;

    IF length(trim(COALESCE(p_reason, ''))) < 10 THEN
        RAISE EXCEPTION 'El motivo de anulación debe tener al menos 10 caracteres (REASON_TOO_SHORT)' USING ERRCODE = 'P0001';
    END IF;

    IF v_sale.is_voided THEN
        RAISE EXCEPTION 'Esta venta ya fue anulada previamente (SALE_ALREADY_VOIDED)' USING ERRCODE = 'P0001';
    END IF;

    -- CHK-508: Bloqueo si la venta tiene reembolsos parciales previos
    IF EXISTS (
        SELECT 1 FROM public.cash_movements
        WHERE sale_id = p_sale_id AND movement_type = 'reembolso'
    ) OR EXISTS (
        SELECT 1 FROM public.sale_items
        WHERE sale_id = p_sale_id AND COALESCE(refunded_quantity, 0) > 0
    ) THEN
        RAISE EXCEPTION 'SALE_HAS_PARTIAL_REFUNDS: No es posible anular una venta que ya registra reembolsos parciales.'
            USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_store_id);
    SELECT id INTO v_employee_id
    FROM public.employees
    WHERE id = COALESCE(public.get_employee_id_from_session(), v_snap.actor_id, auth.uid())
      AND store_id = v_store_id
    LIMIT 1;

    IF v_sale.payment_method IN ('efectivo', 'nequi', 'llave_bre') THEN
        SELECT id, opened_at INTO v_session_id, v_session_opened_at
        FROM public.cash_sessions
        WHERE store_id = v_sale.store_id AND status = 'open'
        ORDER BY opened_at DESC LIMIT 1
        FOR UPDATE;

        IF v_session_id IS NULL THEN
            RAISE EXCEPTION 'Para anular una venta de contado se requiere un turno de caja abierto (NO_OPEN_CASH_SESSION)' USING ERRCODE = 'P0001';
        END IF;

        IF v_sale.payment_method = 'efectivo' THEN
            SELECT COALESCE(opening_balance, 0) INTO v_opening
            FROM public.cash_sessions
            WHERE id = v_session_id;
        END IF;

        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
        FROM public.cash_movements
        WHERE session_id = v_session_id AND payment_method = v_sale.payment_method AND movement_type = 'ingreso';

        SELECT COALESCE(SUM(amount), 0) INTO v_egresos
        FROM public.cash_movements
        WHERE session_id = v_session_id AND payment_method = v_sale.payment_method AND movement_type IN ('gasto', 'pago_proveedor', 'reembolso');

        v_available := (v_opening + v_ingresos) - v_egresos;

        IF v_available < v_sale.total THEN
            RAISE EXCEPTION 'Fondos insuficientes en canal % para revertir la venta (disponible: %, requerido: %) (INSUFFICIENT_CHANNEL_FUNDS)',
                v_sale.payment_method, v_available, v_sale.total USING ERRCODE = 'P0001';
        END IF;

        INSERT INTO public.cash_movements (
            session_id, movement_type, amount, description, sale_id, payment_method, category, actor_id, actor_name, actor_role
        ) VALUES (
            v_session_id, 'gasto', v_sale.total, '[ANULACION_VENTA #' || v_sale.ticket_number || '] ' || p_reason, p_sale_id, v_sale.payment_method, 'anulacion_venta', v_employee_id, v_snap.actor_name, v_snap.actor_role
        );

    ELSIF v_sale.payment_method = 'fiado' AND v_sale.client_id IS NOT NULL THEN
        SELECT balance, COALESCE(is_deleted, false)
        INTO v_client_balance, v_client_deleted
        FROM public.clients
        WHERE id = v_sale.client_id
          AND store_id = v_sale.store_id
        FOR UPDATE;

        IF NOT FOUND OR v_client_deleted THEN
            RAISE EXCEPTION 'No es posible revertir deuda de un cliente archivado contablemente (CLIENT_NOT_FOUND)'
                USING ERRCODE = 'P0001';
        END IF;

        IF COALESCE(v_client_balance, 0) < v_sale.total THEN
            RAISE EXCEPTION 'La venta fiada ya fue abonada o saldada y no admite reversión negativa sobre el saldo ($% < $%) (CREDIT_REVERSAL_BLOCKED)',
                v_client_balance, v_sale.total USING ERRCODE = 'P0001';
        END IF;

        UPDATE public.clients
        SET balance = balance - v_sale.total, updated_at = NOW()
        WHERE id = v_sale.client_id;

        INSERT INTO public.client_ledger (
            client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by, actor_name, actor_role
        ) VALUES (
            v_sale.client_id, v_sale.store_id, -v_sale.total, v_client_balance, p_sale_id, 'anulacion_fiado', v_employee_id, v_snap.actor_name, v_snap.actor_role
        );
    END IF;

    FOR v_item IN SELECT * FROM public.sale_items WHERE sale_id = p_sale_id LOOP
        INSERT INTO public.inventory_movements (
            product_id, movement_type, quantity, reason, created_by, actor_name, actor_role, unit_cost
        ) VALUES (
            v_item.product_id,
            'CORRECCION_SISTEMA',
            v_item.quantity,
            'ANULACION VENTA #' || v_sale.ticket_number || ': ' || p_reason,
            v_employee_id,
            v_snap.actor_name,
            v_snap.actor_role,
            v_item.unit_cost
        );
    END LOOP;

    UPDATE public.sales
    SET is_voided = true,
        void_reason = p_reason,
        voided_by = v_employee_id,
        voided_by_name = v_snap.actor_name,
        voided_by_role = v_snap.actor_role,
        void_session_id = v_session_id,
        voided_at = NOW()
    WHERE id = p_sale_id;

    INSERT INTO public.audit_logs (store_id, actor_id, actor_name, actor_role, event_type, resource_id, metadata, severity)
    VALUES (
        v_sale.store_id,
        v_employee_id,
        v_snap.actor_name,
        v_snap.actor_role,
        'SALE_VOIDED',
        p_sale_id::text,
        jsonb_build_object(
            'ticket_number', v_sale.ticket_number,
            'total', v_sale.total,
            'reason', p_reason,
            'payment_method', v_sale.payment_method
        ),
        'warning'
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Venta anulada correctamente',
        'data', jsonb_build_object(
            'sale_id', p_sale_id,
            'ticket_number', v_sale.ticket_number,
            'is_voided', true,
            'void_session_id', v_session_id
        )
    );
END;
$function$;

-- Sincronizar funciones de caja/arqueo/CxP para que reconozcan movement_type = 'reembolso' (Regla 6)
CREATE OR REPLACE FUNCTION public.rpc_pay_supplier_invoice(
    p_invoice_id uuid,
    p_amount numeric,
    p_payment_method text,
    p_description text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_store_id UUID;
    v_invoice RECORD;
    v_snap RECORD;
    v_emp_fk_id UUID;
    v_session RECORD;
    v_origin_type TEXT;
    v_clean_desc TEXT;
    v_channel_balance NUMERIC := 0;
    v_cash_movement_id UUID;
    v_payment_id UUID;
    v_new_amount_paid NUMERIC;
    v_remaining NUMERIC;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'INVALID_AMOUNT: El abono debe ser mayor a cero.' USING ERRCODE = 'P0001';
    END IF;

    IF p_payment_method IS NULL OR p_payment_method NOT IN ('efectivo', 'nequi', 'llave_bre', 'externo') THEN
        RAISE EXCEPTION 'INVALID_PAYMENT_METHOD: Método no permitido (%). Use efectivo, nequi, llave_bre o externo.',
            COALESCE(p_payment_method, 'NULL') USING ERRCODE = 'P0001';
    END IF;

    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED: Sesión sin tienda activa.' USING ERRCODE = '42501';
    END IF;
    PERFORM public.assert_store_admin(v_store_id);

    SELECT si.*, COALESCE(s.name, 'Proveedor') AS supplier_name
    INTO v_invoice
    FROM public.supplier_invoices si
    LEFT JOIN public.suppliers s ON s.id = si.supplier_id
    WHERE si.id = p_invoice_id
      AND si.store_id = v_store_id
    FOR UPDATE OF si;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'INVOICE_NOT_FOUND: La factura no existe en la tienda activa.' USING ERRCODE = 'P0002';
    END IF;

    IF p_amount > (v_invoice.total_amount - v_invoice.amount_paid) THEN
        RAISE EXCEPTION 'AMOUNT_EXCEEDS_PENDING: El monto ($%) supera el saldo pendiente ($%).',
            p_amount, (v_invoice.total_amount - v_invoice.amount_paid) USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_store_id);
    SELECT e.id INTO v_emp_fk_id
    FROM public.employees e
    WHERE e.id = COALESCE(public.get_employee_id_from_session(), v_snap.actor_id, auth.uid())
      AND e.store_id = v_store_id
    LIMIT 1;

    v_clean_desc := NULLIF(TRIM(COALESCE(p_description, '')), '');

    IF p_payment_method = 'externo' THEN
        v_origin_type := 'EXTERNO';
        v_cash_movement_id := NULL;
        v_clean_desc := COALESCE(v_clean_desc, 'Pago externo / fuera de caja');
    ELSE
        v_origin_type := 'INTERNO';

        IF v_clean_desc IS NULL THEN
            RAISE EXCEPTION 'DESCRIPTION_REQUIRED: Ingrese una descripción del egreso para pagos desde caja/canal interno.'
                USING ERRCODE = 'P0001';
        END IF;

        SELECT id, opened_at, opening_balance
        INTO v_session
        FROM public.cash_sessions
        WHERE store_id = v_store_id
          AND status = 'open'
        ORDER BY opened_at DESC
        LIMIT 1
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'NO_OPEN_CASH_SESSION: Debe abrir turno de caja o registrar el pago como externo.'
                USING ERRCODE = 'P0001';
        END IF;

        IF v_session.opened_at < NOW() - INTERVAL '24 hours' THEN
            RAISE EXCEPTION 'SHIFT_EXPIRED_24H: El turno abierto superó 24 horas y debe cerrarse antes de pagar desde caja.'
                USING ERRCODE = 'P0001';
        END IF;

        SELECT
            CASE WHEN p_payment_method = 'efectivo' THEN COALESCE(v_session.opening_balance, 0) ELSE 0 END
            + COALESCE(SUM(CASE WHEN movement_type = 'ingreso' AND payment_method = p_payment_method THEN amount ELSE 0 END), 0)
            - COALESCE(SUM(CASE WHEN movement_type IN ('gasto', 'pago_proveedor', 'reembolso') AND payment_method = p_payment_method THEN amount ELSE 0 END), 0)
        INTO v_channel_balance
        FROM public.cash_movements
        WHERE session_id = v_session.id;

        IF p_amount > v_channel_balance THEN
            RAISE EXCEPTION 'INSUFFICIENT_CHANNEL_BALANCE: Saldo insuficiente en % (Disponible: $%, Solicitado: $%).',
                p_payment_method, v_channel_balance, p_amount USING ERRCODE = 'P0001';
        END IF;

        INSERT INTO public.cash_movements (
            session_id, movement_type, amount, description, payment_method, category, actor_id, actor_name, actor_role
        ) VALUES (
            v_session.id,
            'pago_proveedor',
            p_amount,
            '[CxP ' || v_invoice.supplier_name || '] ' || v_clean_desc,
            p_payment_method,
            'proveedores',
            v_emp_fk_id,
            v_snap.actor_name,
            v_snap.actor_role
        ) RETURNING id INTO v_cash_movement_id;
    END IF;

    v_new_amount_paid := v_invoice.amount_paid + p_amount;
    v_remaining := GREATEST(0, v_invoice.total_amount - v_new_amount_paid);

    UPDATE public.supplier_invoices
    SET amount_paid = v_new_amount_paid
    WHERE id = p_invoice_id;

    INSERT INTO public.supplier_payments (
        store_id, invoice_id, supplier_id, amount, payment_method, origin_type,
        cash_movement_id, description, actor_id, actor_name, actor_role
    ) VALUES (
        v_store_id, p_invoice_id, v_invoice.supplier_id, p_amount, p_payment_method, v_origin_type,
        v_cash_movement_id, v_clean_desc, v_emp_fk_id, v_snap.actor_name, v_snap.actor_role
    ) RETURNING id INTO v_payment_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'payment_id', v_payment_id,
            'invoice_id', p_invoice_id,
            'amount_paid', p_amount,
            'new_amount_paid', v_new_amount_paid,
            'remaining_balance', v_remaining,
            'payment_method', p_payment_method,
            'origin_type', v_origin_type,
            'cash_movement_id', v_cash_movement_id,
            'actor_name', v_snap.actor_name,
            'actor_role', v_snap.actor_role
        )
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_get_comprehensive_shift_report(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_session RECORD;
    v_window_end TIMESTAMPTZ;
    v_sales_cash NUMERIC := 0;
    v_sales_nequi NUMERIC := 0;
    v_sales_llave_bre NUMERIC := 0;
    v_sales_credit NUMERIC := 0;
    v_client_abonos NUMERIC := 0;
    v_opex_expenses NUMERIC := 0;
    v_refunds NUMERIC := 0;
    v_supplier_payments NUMERIC := 0;
    v_movements JSONB;
    v_voided_sales JSONB;
    v_security_alerts JSONB;
BEGIN
    SELECT cs.*,
           COALESCE(cs.opened_by_name, eo.name, 'Administrador') AS eff_opened_by_name,
           COALESCE(cs.opened_by_role, CASE WHEN eo.id IS NOT NULL THEN 'employee' ELSE 'owner' END) AS eff_opened_by_role,
           COALESCE(cs.closed_by_name, ec.name, NULL) AS eff_closed_by_name,
           cs.closed_by_role AS eff_closed_by_role
    INTO v_session
    FROM public.cash_sessions cs
    LEFT JOIN public.employees eo ON eo.id = cs.opened_by
    LEFT JOIN public.employees ec ON ec.id = cs.closed_by
    WHERE cs.id = p_session_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'SESSION_NOT_FOUND: Sesión de caja (%) no encontrada.', p_session_id USING ERRCODE = 'P0001';
    END IF;

    PERFORM public.assert_store_admin(v_session.store_id);

    v_window_end := COALESCE(v_session.closed_at, NOW());

    SELECT
        COALESCE(SUM(cm.amount) FILTER (WHERE cm.movement_type = 'ingreso' AND cm.sale_id IS NOT NULL AND cm.payment_method = 'efectivo'), 0),
        COALESCE(SUM(cm.amount) FILTER (WHERE cm.movement_type = 'ingreso' AND cm.sale_id IS NOT NULL AND cm.payment_method = 'nequi'), 0),
        COALESCE(SUM(cm.amount) FILTER (WHERE cm.movement_type = 'ingreso' AND cm.sale_id IS NOT NULL AND cm.payment_method = 'llave_bre'), 0),
        COALESCE(SUM(cm.amount) FILTER (WHERE cm.movement_type = 'ingreso' AND cm.sale_id IS NULL), 0),
        COALESCE(SUM(cm.amount) FILTER (
            WHERE cm.movement_type = 'gasto'
              AND NOT (
                  COALESCE(cm.category, '') IN ('reembolso', 'reembolso_merma', 'devolucion', 'anulacion_venta')
                  OR cm.description ILIKE 'DEVOLUCIÓN%'
                  OR cm.description ILIKE '[ANULACION_VENTA%'
              )
        ), 0),
        COALESCE(SUM(cm.amount) FILTER (
            WHERE cm.movement_type = 'reembolso'
               OR (
                   cm.movement_type = 'gasto'
                   AND (
                       COALESCE(cm.category, '') IN ('reembolso', 'reembolso_merma', 'devolucion', 'anulacion_venta')
                       OR cm.description ILIKE 'DEVOLUCIÓN%'
                       OR cm.description ILIKE '[ANULACION_VENTA%'
                   )
               )
        ), 0),
        COALESCE(SUM(cm.amount) FILTER (WHERE cm.movement_type = 'pago_proveedor'), 0)
    INTO v_sales_cash, v_sales_nequi, v_sales_llave_bre, v_client_abonos, v_opex_expenses, v_refunds, v_supplier_payments
    FROM public.cash_movements cm
    WHERE cm.session_id = p_session_id;

    SELECT COALESCE(SUM(s.total), 0)
    INTO v_sales_credit
    FROM public.sales s
    WHERE s.store_id = v_session.store_id
      AND s.payment_method = 'fiado'
      AND s.is_voided = false
      AND s.created_at >= v_session.opened_at
      AND s.created_at <= v_window_end;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', cm.id,
                'movement_type', cm.movement_type,
                'payment_method', COALESCE(cm.payment_method, 'efectivo'),
                'category', cm.category,
                'voucher_ref', cm.voucher_ref,
                'amount', cm.amount,
                'description', cm.description,
                'actor_name', COALESCE(NULLIF(TRIM(cm.actor_name), ''), e.name, 'Administrador'),
                'actor_role', COALESCE(NULLIF(TRIM(cm.actor_role), ''), CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END),
                'created_at', cm.created_at
            )
            ORDER BY cm.created_at ASC, cm.id ASC
        ),
        '[]'::jsonb
    )
    INTO v_movements
    FROM public.cash_movements cm
    LEFT JOIN public.employees e ON e.id = cm.actor_id
    WHERE cm.session_id = p_session_id;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'sale_id', s.id,
                'ticket_number', s.ticket_number,
                'total', s.total,
                'payment_method', s.payment_method,
                'void_reason', s.void_reason,
                'voided_by_name', COALESCE(s.voided_by_name, 'Administrador'),
                'voided_by_role', COALESCE(s.voided_by_role, 'owner'),
                'voided_at', s.voided_at
            )
            ORDER BY s.voided_at DESC NULLS LAST, s.created_at DESC
        ),
        '[]'::jsonb
    )
    INTO v_voided_sales
    FROM public.sales s
    WHERE s.store_id = v_session.store_id
      AND s.is_voided = true
      AND (
          s.void_session_id = p_session_id
          OR (s.created_at >= v_session.opened_at AND s.created_at <= v_window_end)
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', al.id,
                'event_type', al.event_type,
                'severity', al.severity,
                'actor_name', COALESCE(NULLIF(TRIM(al.actor_name), ''), 'Sistema'),
                'actor_role', COALESCE(NULLIF(TRIM(al.actor_role), ''), 'employee'),
                'created_at', al.created_at,
                'metadata', al.metadata
            )
            ORDER BY al.created_at DESC
        ),
        '[]'::jsonb
    )
    INTO v_security_alerts
    FROM public.audit_logs al
    WHERE al.store_id = v_session.store_id
      AND (
          al.resource_id = p_session_id::text
          OR al.metadata->>'session_id' = p_session_id::text
          OR (al.created_at >= v_session.opened_at AND al.created_at <= v_window_end)
      );

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'session', jsonb_build_object(
                'id', v_session.id,
                'store_id', v_session.store_id,
                'status', v_session.status,
                'forced_close', COALESCE(v_session.forced_close, false),
                'forced_close_without_count', COALESCE(v_session.forced_close_without_count, false),
                'closing_attempts', COALESCE(v_session.closing_attempts, 0),
                'opened_at', v_session.opened_at,
                'closed_at', v_session.closed_at,
                'opened_by_name', v_session.eff_opened_by_name,
                'opened_by_role', v_session.eff_opened_by_role,
                'closed_by_name', v_session.eff_closed_by_name,
                'closed_by_role', v_session.eff_closed_by_role,
                'opening_balance', v_session.opening_balance,
                'expected_balance', v_session.expected_balance,
                'actual_balance', v_session.actual_balance,
                'difference', v_session.difference
            ),
            'financial_summary', jsonb_build_object(
                'total_sales_cash', v_sales_cash,
                'total_sales_nequi', v_sales_nequi,
                'total_sales_llave_bre', v_sales_llave_bre,
                'total_sales_transfer', v_sales_nequi + v_sales_llave_bre,
                'total_credit_sales', v_sales_credit,
                'total_client_abonos', v_client_abonos,
                'total_opex_expenses', v_opex_expenses,
                'total_refunds', v_refunds,
                'total_supplier_payments', v_supplier_payments,
                'net_cash_flow', (v_sales_cash + v_sales_nequi + v_sales_llave_bre + v_client_abonos) - (v_opex_expenses + v_refunds + v_supplier_payments)
            ),
            'movements', v_movements,
            'operational_noise', jsonb_build_object(
                'voided_sales', v_voided_sales,
                'security_alerts', v_security_alerts
            )
        )
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_obtener_historial_caja_multicanal(
    p_store_id uuid,
    p_session_id uuid DEFAULT NULL::uuid,
    p_payment_method text DEFAULT 'all'::text,
    p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone,
    p_end_date timestamp with time zone DEFAULT NULL::timestamp with time zone,
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_method TEXT := LOWER(TRIM(COALESCE(p_payment_method, 'all')));
    v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
    v_offset INT := GREATEST(COALESCE(p_offset, 0), 0);
    v_data JSONB;
    v_count INT;
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

    IF p_start_date IS NOT NULL AND p_end_date IS NOT NULL AND p_start_date > p_end_date THEN
        RAISE EXCEPTION 'INVALID_DATE_RANGE: La fecha inicial no puede ser posterior a la fecha final.'
            USING ERRCODE = '22023';
    END IF;

    IF v_method NOT IN ('all', 'efectivo', 'digitales', 'nequi', 'llave_bre') THEN
        RAISE EXCEPTION 'INVALID_PAYMENT_METHOD: Método de pago (%) no soportado.', p_payment_method
            USING ERRCODE = '22023';
    END IF;

    WITH scoped AS (
        SELECT
            cm.id,
            cm.session_id,
            cm.movement_type,
            CASE
                WHEN cm.movement_type = 'reembolso'
                  OR cm.category IN ('reembolso', 'reembolso_merma', 'devolucion', 'anulacion_venta')
                  OR cm.description ILIKE 'DEVOLUCIÓN%'
                  OR cm.description ILIKE '[ANULACION_VENTA%' THEN 'reembolso'::text
                WHEN cm.movement_type = 'pago_proveedor' THEN 'abono_proveedor'::text
                WHEN cm.movement_type = 'gasto' THEN 'gasto_opex'::text
                WHEN cm.sale_id IS NOT NULL THEN 'venta'::text
                ELSE 'abono'::text
            END AS origin_type,
            cm.amount,
            COALESCE(cm.payment_method, 'efectivo') AS payment_method,
            cm.description,
            cm.category,
            cm.voucher_ref,
            cm.sale_id,
            s.ticket_number,
            COALESCE(NULLIF(TRIM(cm.actor_name), ''), e.name, 'Administrador') AS actor_name,
            COALESCE(NULLIF(TRIM(cm.actor_role), ''), CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END) AS actor_role,
            cm.created_at
        FROM public.cash_movements cm
        JOIN public.cash_sessions cs ON cs.id = cm.session_id
        LEFT JOIN public.sales s ON s.id = cm.sale_id
        LEFT JOIN public.employees e ON e.id = cm.actor_id
        WHERE cs.store_id = p_store_id
          AND (p_session_id IS NULL OR cm.session_id = p_session_id)
          AND (p_start_date IS NULL OR cm.created_at >= p_start_date)
          AND (p_end_date IS NULL OR cm.created_at <= p_end_date)
          AND (
              v_method = 'all'
              OR (v_method = 'digitales' AND COALESCE(cm.payment_method, 'efectivo') IN ('nequi', 'llave_bre'))
              OR COALESCE(cm.payment_method, 'efectivo') = v_method
          )
    )
    SELECT
        (SELECT COUNT(*)::int FROM scoped),
        COALESCE(
            (SELECT jsonb_agg(row_to_json(paged))
             FROM (
                 SELECT *
                 FROM scoped
                 ORDER BY created_at DESC, id DESC
                 LIMIT v_limit OFFSET v_offset
             ) paged),
            '[]'::jsonb
        )
    INTO v_count, v_data;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_data,
        'count', v_count
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_obtener_mis_movimientos_turno(
    p_store_id uuid,
    p_payment_method text DEFAULT 'all'::text,
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_method TEXT := LOWER(TRIM(COALESCE(p_payment_method, 'all')));
    v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
    v_offset INT := GREATEST(COALESCE(p_offset, 0), 0);
    v_snap RECORD;
    v_is_admin BOOLEAN;
    v_emp_id UUID;
    v_emp_active BOOLEAN := false;
    v_has_valid_pass BOOLEAN := false;
    v_today DATE := (NOW() AT TIME ZONE 'America/Bogota')::date;
    v_session RECORD;
    v_data JSONB;
    v_count INT;
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    IF v_method NOT IN ('all', 'efectivo', 'digitales', 'nequi', 'llave_bre', 'fiado', 'consumo_personal') THEN
        RAISE EXCEPTION 'INVALID_PAYMENT_METHOD: Método de pago (%) no soportado.', p_payment_method
            USING ERRCODE = '22023';
    END IF;

    v_is_admin := public.is_store_admin(p_store_id);
    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(p_store_id);

    IF NOT v_is_admin THEN
        v_emp_id := COALESCE(public.get_employee_id_from_session(), v_snap.actor_id);

        SELECT e.id, COALESCE(e.is_active, false)
        INTO v_emp_id, v_emp_active
        FROM public.employees e
        WHERE e.id = v_emp_id
          AND e.store_id = p_store_id
        LIMIT 1;

        IF v_emp_id IS NOT NULL AND v_emp_active IS TRUE THEN
            SELECT EXISTS (
                SELECT 1
                FROM public.daily_passes dp
                WHERE dp.employee_id = v_emp_id
                  AND dp.store_id = p_store_id
                  AND dp.status = 'approved'
                  AND (
                      dp.pass_date = v_today
                      OR (
                          dp.pass_date = v_today - 1
                          AND EXISTS (
                              SELECT 1
                              FROM public.cash_sessions cs
                              WHERE cs.store_id = p_store_id
                                AND cs.status = 'open'
                                AND cs.opened_at >= (NOW() - INTERVAL '24 hours')
                          )
                      )
                  )
            ) INTO v_has_valid_pass;
        END IF;

        IF v_emp_id IS NULL OR v_emp_active IS NOT TRUE OR v_has_valid_pass IS NOT TRUE THEN
            RAISE EXCEPTION 'PERMISSION_DENIED: Colaborador inactivo o sin pase diario vigente (<24h).'
                USING ERRCODE = '42501';
        END IF;
    ELSE
        SELECT e.id INTO v_emp_id
        FROM public.employees e
        WHERE e.id = v_snap.actor_id AND e.store_id = p_store_id
        LIMIT 1;
    END IF;

    SELECT id, opened_at, opened_by_name
    INTO v_session
    FROM public.cash_sessions
    WHERE store_id = p_store_id
      AND status = 'open'
    ORDER BY opened_at DESC
    LIMIT 1;

    IF v_session.id IS NULL THEN
        RETURN jsonb_build_object(
            'data', '[]'::jsonb,
            'count', 0,
            'has_open_shift', false,
            'shift_id', NULL,
            'shift_opened_at', NULL
        );
    END IF;

    WITH own_movements AS (
        SELECT
            s.id,
            CASE
                WHEN s.payment_method = 'consumo_personal' THEN 'personal_withdrawal'::text
                ELSE 'sale'::text
            END AS source,
            s.payment_method,
            s.total AS amount,
            'Venta #' || s.ticket_number
                || CASE WHEN s.is_voided THEN ' (Anulada)' ELSE '' END
                || COALESCE(' · ' || c.name, '') AS description,
            CASE
                WHEN s.is_voided THEN 'Anulada'
                WHEN s.payment_method = 'fiado' THEN 'Fiado'
                WHEN s.payment_method = 'consumo_personal' THEN 'Retiro Personal'
                ELSE 'Venta POS'
            END AS category,
            s.created_at,
            COALESCE(NULLIF(TRIM(s.actor_name), ''), v_snap.actor_name) AS actor_name,
            COALESCE(NULLIF(TRIM(s.actor_role), ''), v_snap.actor_role) AS actor_role,
            s.ticket_number,
            NULL::text AS voucher_ref
        FROM public.sales s
        LEFT JOIN public.clients c ON c.id = s.client_id
        WHERE s.store_id = p_store_id
          AND s.created_at >= v_session.opened_at
          AND (
              (v_emp_id IS NOT NULL AND s.employee_id = v_emp_id)
              OR (v_emp_id IS NULL AND v_is_admin AND s.employee_id IS NULL)
          )

        UNION ALL

        SELECT
            cm.id,
            CASE
                WHEN cm.movement_type = 'reembolso'
                  OR cm.category IN ('reembolso', 'reembolso_merma', 'devolucion', 'anulacion_venta')
                  OR cm.description ILIKE 'DEVOLUCIÓN%'
                  OR cm.description ILIKE '[ANULACION_VENTA%' THEN 'refund'::text
                WHEN cm.movement_type = 'gasto' THEN 'expense'::text
                WHEN cm.movement_type = 'pago_proveedor' THEN 'payment'::text
                ELSE 'payment'::text
            END AS source,
            COALESCE(cm.payment_method, 'efectivo') AS payment_method,
            cm.amount,
            cm.description,
            COALESCE(cm.category, CASE
                WHEN cm.movement_type = 'reembolso' THEN 'Reembolso'
                WHEN cm.movement_type = 'pago_proveedor' THEN 'Pago a Proveedor'
                WHEN cm.movement_type = 'gasto' THEN 'Gasto'
                ELSE 'Abono / Ingreso'
            END) AS category,
            cm.created_at,
            COALESCE(NULLIF(TRIM(cm.actor_name), ''), v_snap.actor_name) AS actor_name,
            COALESCE(NULLIF(TRIM(cm.actor_role), ''), v_snap.actor_role) AS actor_role,
            NULL::int AS ticket_number,
            cm.voucher_ref
        FROM public.cash_movements cm
        WHERE cm.session_id = v_session.id
          AND (cm.sale_id IS NULL OR cm.movement_type <> 'ingreso')
          AND (
              (v_emp_id IS NOT NULL AND cm.actor_id = v_emp_id)
              OR (v_emp_id IS NULL AND v_is_admin AND cm.actor_id IS NULL)
          )
    ),
    filtered AS (
        SELECT *
        FROM own_movements m
        WHERE (
            v_method = 'all'
            OR (v_method = 'digitales' AND m.payment_method IN ('nequi', 'llave_bre'))
            OR m.payment_method = v_method
        )
    )
    SELECT
        (SELECT COUNT(*)::int FROM filtered),
        COALESCE(
            (SELECT jsonb_agg(row_to_json(paged))
             FROM (
                 SELECT id, source, payment_method, amount, description, category, created_at, actor_name, actor_role, ticket_number, voucher_ref
                 FROM filtered
                 ORDER BY created_at DESC, id DESC
                 LIMIT v_limit OFFSET v_offset
             ) paged),
            '[]'::jsonb
        )
    INTO v_count, v_data;

    RETURN jsonb_build_object(
        'data', v_data,
        'count', v_count,
        'has_open_shift', true,
        'shift_id', v_session.id,
        'shift_opened_at', v_session.opened_at
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 7. CHK-510: get_inventory_kardex con filtro por nuevos tipos, actor y snapshot
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_inventory_kardex(
    p_product_id uuid,
    p_movement_type text DEFAULT NULL::text,
    p_actor_filter text DEFAULT NULL::text,
    p_start_date timestamptz DEFAULT NULL::timestamptz,
    p_end_date timestamptz DEFAULT NULL::timestamptz,
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_store_id UUID;
    v_clean_type TEXT := NULLIF(LOWER(TRIM(COALESCE(p_movement_type, ''))), '');
    v_clean_actor TEXT := NULLIF(TRIM(COALESCE(p_actor_filter, '')), '');
    v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
    v_offset INT := GREATEST(COALESCE(p_offset, 0), 0);
    v_data JSONB;
    v_count INT;
    v_actors JSONB;
BEGIN
    SELECT store_id INTO v_store_id
    FROM public.products
    WHERE id = p_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PRODUCT_NOT_FOUND: El producto (%) no existe.', p_product_id USING ERRCODE = 'P0002';
    END IF;

    PERFORM public.assert_store_access(v_store_id);
    PERFORM public.assert_employee_permission(v_store_id, 'canManageInventory');

    WITH scoped AS (
        SELECT
            im.id,
            im.product_id,
            im.movement_type,
            im.quantity,
            im.reason,
            im.unit_cost,
            im.reference_sale_price,
            im.created_by,
            COALESCE(NULLIF(TRIM(im.actor_name), ''), e.name, 'Administrador') AS actor_name,
            COALESCE(NULLIF(TRIM(im.actor_role), ''), CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END) AS actor_role,
            im.supplier_id,
            s.name AS supplier_name,
            im.invoice_reference,
            im.session_id,
            im.beneficiary_employee_id,
            im.reversed_movement_id,
            EXISTS (
                SELECT 1 FROM public.inventory_movements rev
                WHERE rev.reversed_movement_id = im.id
            ) AS is_reversed,
            im.created_at
        FROM public.inventory_movements im
        LEFT JOIN public.employees e ON e.id = im.created_by
        LEFT JOIN public.suppliers s ON s.id = im.supplier_id
        WHERE im.product_id = p_product_id
          AND (
              v_clean_type IS NULL
              OR v_clean_type = 'all'
              OR LOWER(im.movement_type) = v_clean_type
          )
          AND (
              v_clean_actor IS NULL
              OR v_clean_actor = 'all'
              OR (v_clean_actor = 'admin' AND im.created_by IS NULL)
              OR im.created_by::text = v_clean_actor
          )
          AND (p_start_date IS NULL OR im.created_at >= p_start_date)
          AND (p_end_date IS NULL OR im.created_at <= p_end_date)
    )
    SELECT
        (SELECT COUNT(*)::int FROM scoped),
        COALESCE(
            (SELECT jsonb_agg(row_to_json(paged))
             FROM (
                 SELECT * FROM scoped
                 ORDER BY created_at DESC, id DESC
                 LIMIT v_limit OFFSET v_offset
             ) paged),
            '[]'::jsonb
        )
    INTO v_count, v_data;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object('actor_key', actor_key, 'actor_name', actor_name, 'actor_role', actor_role)
            ORDER BY actor_name ASC
        ),
        '[]'::jsonb
    )
    INTO v_actors
    FROM (
        SELECT DISTINCT
            COALESCE(im.created_by::text, 'admin') AS actor_key,
            COALESCE(NULLIF(TRIM(im.actor_name), ''), e.name, 'Administrador') AS actor_name,
            COALESCE(NULLIF(TRIM(im.actor_role), ''), CASE WHEN e.id IS NOT NULL THEN 'employee' ELSE 'owner' END) AS actor_role
        FROM public.inventory_movements im
        LEFT JOIN public.employees e ON e.id = im.created_by
        WHERE im.product_id = p_product_id
    ) distinct_actors;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_data,
        'count', v_count,
        'actors', v_actors
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 8. CHK-511: rpc_get_comprehensive_financial_report (P&L 4 Pilares + OPEX Breakdown + Consumos Personales)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_get_comprehensive_financial_report(
    p_store_id uuid,
    p_start_date date DEFAULT CURRENT_DATE,
    p_end_date date DEFAULT CURRENT_DATE,
    p_employee_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_start_ts              TIMESTAMPTZ;
    v_end_ts                TIMESTAMPTZ;
    v_gross_sales           NUMERIC := 0;
    v_refunds_total         NUMERIC := 0;
    v_revenue               NUMERIC := 0;
    v_cogs                  NUMERIC := 0;
    v_gross_profit          NUMERIC := 0;
    v_gross_margin          NUMERIC := 0;

    v_cash_servicios        NUMERIC := 0;
    v_cash_nomina           NUMERIC := 0;
    v_cash_transporte       NUMERIC := 0;
    v_cash_mantenimiento    NUMERIC := 0;
    v_cash_insumos          NUMERIC := 0;
    v_cash_otros            NUMERIC := 0;
    v_cash_opex             NUMERIC := 0;

    v_merma_cost            NUMERIC := 0;
    v_consumo_negocio_cost  NUMERIC := 0;
    v_consumo_personal_cost NUMERIC := 0;
    v_consumo_personal_ref  NUMERIC := 0;
    v_consumo_personal_cnt  INT := 0;
    v_personal_by_profile   JSONB := '[]'::jsonb;

    v_op_expenses           NUMERIC := 0;
    v_net_profit            NUMERIC := 0;
    v_inventory_value       NUMERIC := 0;
    v_payment_breakdown     JSONB;
    v_fiado_pendiente       NUMERIC := 0;
    v_avg_sales_7d          NUMERIC := 0;
    v_traffic_status        TEXT;
    v_traffic_message       TEXT;
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION 'La fecha de inicio no puede ser posterior a la fecha de fin (INVALID_DATE_RANGE)'
            USING ERRCODE = 'P0001';
    END IF;

    IF (p_end_date - p_start_date) > 366 THEN
        RAISE EXCEPTION 'El rango máximo permitido para el reporte financiero es de 366 días (RANGE_EXCEEDS_MAX_LIMIT)'
            USING ERRCODE = 'P0001';
    END IF;

    IF p_employee_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.employees WHERE id = p_employee_id AND store_id = p_store_id) THEN
            RAISE EXCEPTION 'El colaborador seleccionado no pertenece a este establecimiento (EMPLOYEE_NOT_FOUND)'
                USING ERRCODE = 'P0001';
        END IF;
    END IF;

    v_start_ts := (p_start_date::timestamp AT TIME ZONE 'America/Bogota');
    v_end_ts   := ((p_end_date + 1)::timestamp AT TIME ZONE 'America/Bogota');

    -- 1. Ventas Brutas (excluye ventas anuladas y consumo_personal $0)
    SELECT COALESCE(SUM(total), 0)
    INTO v_gross_sales
    FROM public.sales
    WHERE store_id  = p_store_id
      AND created_at >= v_start_ts
      AND created_at <  v_end_ts
      AND is_voided  = FALSE
      AND payment_method <> 'consumo_personal'
      AND (p_employee_id IS NULL OR employee_id = p_employee_id);

    -- 2. Reembolsos en caja del período (se deducen de Ingresos Netos, NUNCA de OPEX para evitar doble conteo)
    SELECT COALESCE(SUM(cm.amount), 0)
    INTO v_refunds_total
    FROM public.cash_movements cm
    JOIN public.cash_sessions cs ON cm.session_id = cs.id
    WHERE cs.store_id = p_store_id
      AND cm.created_at >= v_start_ts
      AND cm.created_at <  v_end_ts
      AND (
          cm.movement_type = 'reembolso'
          OR (cm.movement_type = 'gasto' AND COALESCE(cm.category, '') IN ('reembolso', 'reembolso_merma', 'devolucion'))
      )
      AND (p_employee_id IS NULL OR cm.actor_id = p_employee_id);

    v_revenue := v_gross_sales - v_refunds_total;

    -- 3. COGS FIFO exacto de ventas regulares
    SELECT COALESCE(SUM(sib.quantity_consumed * sib.unit_cost), 0)
    INTO v_cogs
    FROM public.sale_item_batches sib
    JOIN public.sale_items si ON sib.sale_item_id = si.id
    JOIN public.sales s       ON si.sale_id       = s.id
    WHERE s.store_id  = p_store_id
      AND s.created_at >= v_start_ts
      AND s.created_at <  v_end_ts
      AND s.is_voided  = FALSE
      AND s.payment_method <> 'consumo_personal'
      AND (p_employee_id IS NULL OR s.employee_id = p_employee_id);

    v_gross_profit := v_revenue - v_cogs;
    IF v_revenue > 0 THEN
        v_gross_margin := ROUND((v_gross_profit / v_revenue) * 100, 2);
    END IF;

    -- 4. Gastos OPEX monetarios en caja (excluye anulaciones y reembolsos)
    SELECT
        COALESCE(SUM(cm.amount) FILTER (WHERE LOWER(COALESCE(cm.category, '')) = 'servicios'), 0),
        COALESCE(SUM(cm.amount) FILTER (WHERE LOWER(COALESCE(cm.category, '')) IN ('nomina', 'nómina')), 0),
        COALESCE(SUM(cm.amount) FILTER (WHERE LOWER(COALESCE(cm.category, '')) = 'transporte'), 0),
        COALESCE(SUM(cm.amount) FILTER (WHERE LOWER(COALESCE(cm.category, '')) = 'mantenimiento'), 0),
        COALESCE(SUM(cm.amount) FILTER (WHERE LOWER(COALESCE(cm.category, '')) = 'insumos'), 0),
        COALESCE(SUM(cm.amount) FILTER (
            WHERE LOWER(COALESCE(cm.category, '')) NOT IN ('servicios', 'nomina', 'nómina', 'transporte', 'mantenimiento', 'insumos')
        ), 0),
        COALESCE(SUM(cm.amount), 0)
    INTO
        v_cash_servicios, v_cash_nomina, v_cash_transporte, v_cash_mantenimiento, v_cash_insumos, v_cash_otros, v_cash_opex
    FROM public.cash_movements cm
    JOIN public.cash_sessions cs ON cm.session_id = cs.id
    WHERE cs.store_id = p_store_id
      AND cm.movement_type = 'gasto'
      AND COALESCE(cm.category, '') NOT IN ('anulacion_venta', 'reembolso', 'reembolso_merma', 'devolucion')
      AND cm.description NOT ILIKE '[ANULACION_VENTA%'
      AND cm.created_at >= v_start_ts
      AND cm.created_at <  v_end_ts
      AND (p_employee_id IS NULL OR cm.actor_id = p_employee_id);

    -- 5. Gastos OPEX en especie (netos de contra-movimientos; costo de adquisición FIFO)
    SELECT COALESCE(SUM(ABS(im.quantity) * COALESCE(im.unit_cost, p.cost_price, 0)), 0)
    INTO v_merma_cost
    FROM public.inventory_movements im
    JOIN public.products p ON p.id = im.product_id
    WHERE p.store_id = p_store_id
      AND im.movement_type = 'merma'
      AND im.created_at >= v_start_ts
      AND im.created_at <  v_end_ts
      AND NOT EXISTS (
          SELECT 1 FROM public.inventory_movements rev WHERE rev.reversed_movement_id = im.id
      )
      AND (p_employee_id IS NULL OR im.created_by = p_employee_id);

    SELECT COALESCE(SUM(ABS(im.quantity) * COALESCE(im.unit_cost, p.cost_price, 0)), 0)
    INTO v_consumo_negocio_cost
    FROM public.inventory_movements im
    JOIN public.products p ON p.id = im.product_id
    WHERE p.store_id = p_store_id
      AND im.movement_type = 'consumo_negocio'
      AND im.created_at >= v_start_ts
      AND im.created_at <  v_end_ts
      AND NOT EXISTS (
          SELECT 1 FROM public.inventory_movements rev WHERE rev.reversed_movement_id = im.id
      )
      AND (p_employee_id IS NULL OR im.created_by = p_employee_id);

    WITH personal_rows AS (
        SELECT
            COALESCE(im.beneficiary_employee_id::text, 'admin') AS profile_key,
            im.beneficiary_employee_id AS profile_id,
            COALESCE(e.name, NULLIF(TRIM(im.actor_name), ''), 'Administrador') AS profile_name,
            CASE WHEN im.beneficiary_employee_id IS NOT NULL THEN 'employee' ELSE 'owner' END AS profile_role,
            ABS(im.quantity) AS qty,
            ABS(im.quantity) * COALESCE(im.unit_cost, p.cost_price, 0) AS row_cost,
            ABS(im.quantity) * COALESCE(im.reference_sale_price, p.price, 0) AS row_ref_price
        FROM public.inventory_movements im
        JOIN public.products p ON p.id = im.product_id
        LEFT JOIN public.employees e ON e.id = im.beneficiary_employee_id
        WHERE p.store_id = p_store_id
          AND im.movement_type = 'consumo_personal'
          AND im.created_at >= v_start_ts
          AND im.created_at <  v_end_ts
          AND (p_employee_id IS NULL OR im.beneficiary_employee_id = p_employee_id OR im.created_by = p_employee_id)
    ),
    grouped_profiles AS (
        SELECT
            profile_key,
            MAX(profile_id::text) AS profile_id,
            MAX(profile_name) AS profile_name,
            MAX(profile_role) AS profile_role,
            COALESCE(SUM(row_cost), 0) AS total_cost,
            COALESCE(SUM(row_ref_price), 0) AS total_reference_sale_price,
            COUNT(*)::int AS movements_count,
            COALESCE(SUM(qty), 0) AS items_count
        FROM personal_rows
        GROUP BY profile_key
    )
    SELECT
        COALESCE(SUM(total_cost), 0),
        COALESCE(SUM(total_reference_sale_price), 0),
        COALESCE(SUM(movements_count), 0)::int,
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'profile_id', profile_id,
                    'profile_key', profile_key,
                    'profile_name', profile_name,
                    'profile_role', profile_role,
                    'total_cost', total_cost,
                    'total_reference_sale_price', total_reference_sale_price,
                    'movements_count', movements_count,
                    'items_count', items_count
                )
                ORDER BY total_cost DESC, profile_name ASC
            ),
            '[]'::jsonb
        )
    INTO v_consumo_personal_cost, v_consumo_personal_ref, v_consumo_personal_cnt, v_personal_by_profile
    FROM grouped_profiles;

    v_op_expenses := v_cash_opex + v_merma_cost + v_consumo_negocio_cost + v_consumo_personal_cost;
    v_net_profit  := v_gross_profit - v_op_expenses;

    -- 6. Valor del Inventario Activo FIFO
    SELECT COALESCE(SUM(ib.quantity_remaining * ib.cost_unit), 0)
    INTO v_inventory_value
    FROM public.inventory_batches ib
    JOIN public.products p ON ib.product_id = p.id
    WHERE p.store_id = p_store_id
      AND p.is_active = TRUE
      AND ib.is_active = TRUE
      AND ib.quantity_remaining > 0;

    -- 7. Recaudos por canal unificados
    SELECT jsonb_build_object(
        'cash',      COALESCE(SUM(total) FILTER (WHERE payment_method = 'efectivo'), 0),
        'efectivo',  COALESCE(SUM(total) FILTER (WHERE payment_method = 'efectivo'), 0),
        'transfer',  COALESCE(SUM(total) FILTER (WHERE payment_method IN ('nequi', 'llave_bre')), 0),
        'credit',    COALESCE(SUM(total) FILTER (WHERE payment_method = 'fiado'), 0),
        'fiado',     COALESCE(SUM(total) FILTER (WHERE payment_method = 'fiado'), 0),
        'nequi',     COALESCE(SUM(total) FILTER (WHERE payment_method = 'nequi'), 0),
        'llave_bre', COALESCE(SUM(total) FILTER (WHERE payment_method = 'llave_bre'), 0)
    )
    INTO v_payment_breakdown
    FROM public.sales
    WHERE store_id  = p_store_id
      AND created_at >= v_start_ts
      AND created_at <  v_end_ts
      AND is_voided  = FALSE
      AND payment_method <> 'consumo_personal'
      AND (p_employee_id IS NULL OR employee_id = p_employee_id);

    -- 8. Cartera pendiente (Fiado)
    SELECT COALESCE(SUM(balance), 0)
    INTO v_fiado_pendiente
    FROM public.clients
    WHERE store_id = p_store_id
      AND (is_deleted = FALSE OR is_deleted IS NULL)
      AND balance > 0;

    -- 9. Semáforo comparativo vs 7 días previos
    SELECT COALESCE(AVG(daily_total), 0)
    INTO v_avg_sales_7d
    FROM (
        SELECT DATE(created_at AT TIME ZONE 'America/Bogota') AS day, SUM(total) AS daily_total
        FROM public.sales
        WHERE store_id  = p_store_id
          AND created_at >= (v_start_ts - INTERVAL '7 days')
          AND created_at <   v_start_ts
          AND is_voided  = FALSE
          AND payment_method <> 'consumo_personal'
        GROUP BY 1
    ) past;

    IF v_avg_sales_7d = 0 THEN
        v_traffic_status  := 'gray';
        v_traffic_message := 'Recopilando datos históricos...';
    ELSIF v_revenue >= (v_avg_sales_7d * 1.05) THEN
        v_traffic_status  := 'green';
        v_traffic_message := '🚀 ¡Vas un '
            || ROUND(((v_revenue - v_avg_sales_7d) / NULLIF(v_avg_sales_7d, 0) * 100), 0)
            || '% arriba de tu promedio!';
    ELSIF v_revenue <= (v_avg_sales_7d * 0.95) THEN
        v_traffic_status  := 'red';
        v_traffic_message := '📉 Estás un '
            || ROUND(((v_avg_sales_7d - v_revenue) / NULLIF(v_avg_sales_7d, 0) * 100), 0)
            || '% abajo de tu promedio.';
    ELSE
        v_traffic_status  := 'green';
        v_traffic_message := '👍 Ventas estables respecto a tu semana.';
    END IF;

    RETURN jsonb_build_object(
        'period', jsonb_build_object(
            'start', p_start_date,
            'end',   p_end_date
        ),
        'gross_sales',           v_gross_sales,
        'refunds_total',         v_refunds_total,
        'revenue',               v_revenue,
        'cogs',                  v_cogs,
        'gross_profit',          v_gross_profit,
        'gross_margin',          v_gross_margin,
        'operational_expenses',  v_op_expenses,
        'net_profit',            v_net_profit,
        'opex_breakdown', jsonb_build_object(
            'cash_expenses',        v_cash_opex,
            'servicios',            v_cash_servicios,
            'nomina',               v_cash_nomina,
            'transporte',           v_cash_transporte,
            'mantenimiento',        v_cash_mantenimiento,
            'insumos',              v_cash_insumos,
            'otros',                v_cash_otros,
            'merma_cost',           v_merma_cost,
            'consumo_negocio_cost', v_consumo_negocio_cost,
            'consumo_personal_cost', v_consumo_personal_cost,
            'total',                v_op_expenses
        ),
        'personal_consumptions_summary', jsonb_build_object(
            'total_cost',                 v_consumo_personal_cost,
            'total_reference_sale_price', v_consumo_personal_ref,
            'movements_count',            v_consumo_personal_cnt,
            'by_profile',                 v_personal_by_profile
        ),
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

GRANT EXECUTE ON FUNCTION public.rpc_registrar_salida_logistica(uuid, text, numeric, text, text, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_registrar_contra_movimiento(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_procesar_reembolso_item(uuid, numeric, text, text, text, boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_buscar_ventas_para_reembolso(uuid, text, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.buscar_producto_pos(uuid, text, integer, integer, boolean) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_inventory_kardex(uuid, text, text, timestamptz, timestamptz, integer, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_actualizar_precio_lote(uuid, numeric, numeric) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_registrar_entrada(uuid, numeric, numeric, numeric, text, uuid, text, text, uuid) TO authenticated, service_role;

-- Descripción del cambio: Actualización de lógica RPC para FIFO Pricing
-- Autor: Antigravity

-- 1. Actualizar consume_stock_fifo para retornar sale_price
DROP FUNCTION IF EXISTS public.consume_stock_fifo(UUID, DECIMAL);

CREATE OR REPLACE FUNCTION public.consume_stock_fifo(
    p_product_id UUID,
    p_quantity_needed DECIMAL
)
RETURNS TABLE (batch_id UUID, quantity_taken DECIMAL, cost_unit DECIMAL, sale_price DECIMAL) AS $$
DECLARE
    v_qty_left DECIMAL := p_quantity_needed;
    v_batch RECORD;
    v_take DECIMAL;
BEGIN
    IF (SELECT current_stock FROM public.products WHERE id = p_product_id) < p_quantity_needed THEN
        RAISE EXCEPTION 'Stock insuficiente (FIFO Check)';
    END IF;

    FOR v_batch IN 
        SELECT ib.id, ib.quantity_remaining, ib.cost_unit, ib.sale_price 
        FROM public.inventory_batches ib
        WHERE ib.product_id = p_product_id AND ib.quantity_remaining > 0
        ORDER BY ib.created_at ASC
        FOR UPDATE
    LOOP
        IF v_qty_left <= 0 THEN EXIT; END IF;

        v_take := LEAST(v_qty_left, v_batch.quantity_remaining);
        
        UPDATE public.inventory_batches 
        SET quantity_remaining = quantity_remaining - v_take
        WHERE id = v_batch.id;

        batch_id := v_batch.id;
        quantity_taken := v_take;
        cost_unit := v_batch.cost_unit;
        sale_price := v_batch.sale_price;
        RETURN NEXT;

        v_qty_left := v_qty_left - v_take;
    END LOOP;

    IF v_qty_left > 0 THEN
        RAISE EXCEPTION 'Inconsistencia de Inventario: Stock en Products no coincide con Lotes.';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';


-- 2. Modificar el trigger bridge_movement_to_batch para NO crear lote en 'entrada' automáticamente (se hará vía RPC)
CREATE OR REPLACE FUNCTION public.bridge_movement_to_batch()
RETURNS TRIGGER AS $$
DECLARE
    v_cost DECIMAL;
BEGIN
    CASE NEW.movement_type
        WHEN 'salida' THEN
            PERFORM public.consume_stock_fifo(NEW.product_id, NEW.quantity);
        WHEN 'CORRECCION_SISTEMA' THEN
            IF NEW.quantity < 0 THEN
                PERFORM public.consume_stock_fifo(NEW.product_id, ABS(NEW.quantity));
            ELSE
                -- Si es correccion positiva sin RPC, creamos el lote con precio actual
                v_cost := COALESCE((SELECT cost_price FROM public.products WHERE id = NEW.product_id), 0);
                INSERT INTO public.inventory_batches (
                    product_id, quantity_initial, quantity_remaining, cost_unit, sale_price, created_by
                ) VALUES (
                    NEW.product_id, NEW.quantity, NEW.quantity, v_cost, COALESCE((SELECT price FROM public.products WHERE id = NEW.product_id), 0), NEW.created_by
                );
            END IF;
        ELSE
            -- 'entrada', 'venta', 'devolucion' se manejan explícitamente en los RPCs
            NULL;
    END CASE;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';


-- 3. Crear rpc_registrar_entrada (Gatekeeper)
CREATE OR REPLACE FUNCTION public.rpc_registrar_entrada(
    p_product_id UUID,
    p_quantity DECIMAL,
    p_purchase_price DECIMAL,
    p_sale_price DECIMAL,
    p_reason TEXT DEFAULT 'Entrada de mercancía'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_employee_id UUID;
    v_store_id UUID;
BEGIN
    v_employee_id := auth.uid();
    IF v_employee_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No autorizado');
    END IF;

    SELECT store_id INTO v_store_id FROM public.products WHERE id = p_product_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Producto no encontrado');
    END IF;

    -- Validar que el empleado pertenece a la misma tienda
    IF NOT EXISTS (SELECT 1 FROM public.employees WHERE id = v_employee_id AND store_id = v_store_id) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Acceso denegado a este producto');
    END IF;

    -- Modificar catálogo si los precios son diferentes
    IF EXISTS (SELECT 1 FROM public.products WHERE id = p_product_id AND (price != p_sale_price OR cost_price != p_purchase_price)) THEN
        INSERT INTO public.product_price_history (product_id, purchase_price, sale_price, created_by)
        VALUES (p_product_id, p_purchase_price, p_sale_price, v_employee_id);

        UPDATE public.products 
        SET price = p_sale_price, cost_price = p_purchase_price 
        WHERE id = p_product_id;
    END IF;

    -- 1. Insertar movimiento (Trigger ignorará 'entrada' para crear lote)
    INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by)
    VALUES (p_product_id, 'entrada', p_quantity, p_reason, v_employee_id);

    -- 2. Insertar lote directamente con los precios exactos
    INSERT INTO public.inventory_batches (
        product_id, quantity_initial, quantity_remaining, cost_unit, sale_price, created_by
    ) VALUES (
        p_product_id, p_quantity, p_quantity, p_purchase_price, p_sale_price, v_employee_id
    );

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- 4. Crear rpc_actualizar_precio_lote
CREATE OR REPLACE FUNCTION public.rpc_actualizar_precio_lote(
    p_batch_id UUID,
    p_new_sale_price DECIMAL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_employee_id UUID;
    v_product_id UUID;
BEGIN
    v_employee_id := auth.uid();
    
    SELECT product_id INTO v_product_id FROM public.inventory_batches WHERE id = p_batch_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Lote no encontrado');
    END IF;

    UPDATE public.inventory_batches 
    SET sale_price = p_new_sale_price 
    WHERE id = p_batch_id;

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- 5. Actualizar rpc_procesar_venta_v2 para usar lotes FIFO con precios dinámicos
CREATE OR REPLACE FUNCTION public.rpc_procesar_venta_v2(
    p_store_id uuid,
    p_client_id uuid,
    p_payment_method text,
    p_amount_received numeric,
    p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_sale_id UUID; v_ticket_number INTEGER; v_total_calculated DECIMAL(12, 0) := 0; v_change DECIMAL(12, 0) := 0;
    v_item JSONB; v_product_id UUID; v_quantity DECIMAL; v_product_name TEXT; 
    v_item_subtotal DECIMAL; v_sale_item_id UUID;
    v_client_balance DECIMAL; v_client_limit DECIMAL; v_employee_id UUID;
    v_pm_exists BOOLEAN; v_pm_allows_change BOOLEAN; v_pm_requires_ref BOOLEAN; v_pm_is_active BOOLEAN;
    v_batch RECORD;
BEGIN
    PERFORM assert_store_access(p_store_id);

    SELECT is_active, allows_change, requires_reference
    INTO v_pm_is_active, v_pm_allows_change, v_pm_requires_ref
    FROM public.payment_methods WHERE code = p_payment_method;

    IF NOT FOUND AND p_payment_method = 'efectivo' THEN
        SELECT is_active, allows_change, requires_reference
        INTO v_pm_is_active, v_pm_allows_change, v_pm_requires_ref
        FROM public.payment_methods WHERE code = 'cash';
    END IF;

    IF v_pm_is_active IS NULL OR v_pm_is_active = FALSE THEN
        RETURN jsonb_build_object('success', false, 'error', 'Método de pago no válido o inactivo: ' || p_payment_method, 'code', 'INVALID_PAYMENT_METHOD');
    END IF;

    v_employee_id := public.get_employee_id_from_session();
    IF v_employee_id IS NULL THEN
        IF EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()) THEN
            v_employee_id := auth.uid();
        ELSE
            RETURN jsonb_build_object('success', false, 'error', 'Usuario no autorizado', 'code', 'UNAUTHORIZED');
        END IF;
    END IF;

    -- Primera pasada: Pre-calcular disponibilidad (ya no podemos pre-calcular total exacto tan fácilmente sin consumir, 
    -- pero el frontend ya lo pre-calculó. Calcularemos el total real durante el consumo).
    IF p_payment_method = 'fiado' THEN
        IF p_client_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Se requiere cliente para fiado');
        END IF;
        SELECT balance, credit_limit INTO v_client_balance, v_client_limit
        FROM public.clients WHERE id = p_client_id FOR UPDATE;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'Cliente no encontrado');
        END IF;
        -- Validaremos el límite de crédito DESPUÉS de calcular el total exacto.
    END IF;

    SELECT COALESCE(MAX(ticket_number), 0) + 1 INTO v_ticket_number FROM public.sales WHERE store_id = p_store_id;

    -- Insertar Cabecera Venta (Total se actualizará luego)
    INSERT INTO public.sales (store_id, ticket_number, employee_id, client_id, total, payment_method, amount_received, change_given, sync_status)
    VALUES (p_store_id, v_ticket_number, v_employee_id, p_client_id, 0, p_payment_method, p_amount_received, 0, 'synced')
    RETURNING id INTO v_sale_id;

    -- Segunda pasada: Procesar items con FIFO y precios
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_quantity := (v_item->>'quantity')::DECIMAL;
        v_item_subtotal := 0;
        
        -- Insert dummy sale_item to get ID, we update it later
        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, subtotal)
        VALUES (v_sale_id, v_product_id, v_quantity, 0, 0)
        RETURNING id INTO v_sale_item_id;

        -- Consumir lotes FIFO y calcular subtotal
        FOR v_batch IN SELECT * FROM public.consume_stock_fifo(v_product_id, v_quantity)
        LOOP
            v_item_subtotal := v_item_subtotal + (v_batch.quantity_taken * v_batch.sale_price);
            
            INSERT INTO public.sale_item_batches (sale_item_id, batch_id, quantity_consumed, unit_cost, unit_price)
            VALUES (v_sale_item_id, v_batch.batch_id, v_batch.quantity_taken, v_batch.cost_unit, v_batch.sale_price);
        END LOOP;

        -- Actualizar sale_item con total real
        UPDATE public.sale_items 
        SET subtotal = v_item_subtotal, 
            unit_price = CASE WHEN v_quantity > 0 THEN v_item_subtotal / v_quantity ELSE 0 END
        WHERE id = v_sale_item_id;

        v_total_calculated := v_total_calculated + v_item_subtotal;

        INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by)
        VALUES (v_product_id, 'venta', v_quantity, 'Venta #' || v_ticket_number, v_employee_id);
    END LOOP;

    -- Validar cupo de crédito (ahora que sabemos el total exacto)
    IF p_payment_method = 'fiado' THEN
        IF (v_client_balance + v_total_calculated) > v_client_limit THEN
            -- Hacer rollback si excede! 
            RAISE EXCEPTION 'Cupo excedido. Saldo Nuevo: %', (v_client_balance + v_total_calculated) USING ERRCODE = 'P0001';
        END IF;
    END IF;

    -- Calcular Vuelto
    IF v_pm_allows_change THEN
        v_change := GREATEST(0, p_amount_received - v_total_calculated);
    ELSE
        v_change := 0;
    END IF;

    -- Actualizar Cabecera de Venta
    UPDATE public.sales 
    SET total = v_total_calculated, change_given = v_change
    WHERE id = v_sale_id;

    -- Cash Session Move
    IF v_pm_allows_change OR p_payment_method IN ('cash', 'efectivo') THEN
        DECLARE v_session_id UUID;
        BEGIN
            SELECT id INTO v_session_id FROM public.cash_sessions
            WHERE store_id = p_store_id AND status = 'open'
            ORDER BY opened_at DESC LIMIT 1;
            IF v_session_id IS NOT NULL THEN
                INSERT INTO public.cash_movements (session_id, movement_type, amount, description, sale_id)
                VALUES (v_session_id, 'ingreso', v_total_calculated, 'Venta #' || v_ticket_number, v_sale_id);
            END IF;
        END;
    END IF;

    -- Client Ledger
    IF p_payment_method = 'fiado' THEN
        UPDATE public.clients SET balance = balance + v_total_calculated WHERE id = p_client_id;
        INSERT INTO public.client_ledger (client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by)
        VALUES (p_client_id, p_store_id, v_total_calculated, v_client_balance, v_sale_id, 'venta_fiado', v_employee_id);
    END IF;

    RETURN jsonb_build_object('success', true, 'sale_id', v_sale_id, 'ticket_number', v_ticket_number, 'total', v_total_calculated, 'change', v_change);

EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = 'P0001' THEN
        RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'code', 'CREDIT_LIMIT_EXCEEDED');
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Error interno: ' || SQLERRM, 'code', SQLSTATE);
    END IF;
END;
$function$;

-- FIXES PARA FIFO PRICING Y CREACIÓN DE EDICIÓN DE LOTES

-- 1. Actualizar rpc_procesar_venta_v2 para saltar inserts de caja en 0$ y usar COALESCE
CREATE OR REPLACE FUNCTION public.rpc_procesar_venta_v2(p_store_id uuid, p_client_id uuid, p_payment_method text, p_amount_received numeric, p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_sale_id UUID; v_ticket_number INTEGER; v_total_calculated DECIMAL(12, 0) := 0;
    v_change DECIMAL(12, 0) := 0; v_item JSONB; v_product_id UUID; v_quantity DECIMAL;
    v_product_price DECIMAL; v_product_name TEXT; v_item_subtotal DECIMAL;
    v_client_balance DECIMAL; v_client_limit DECIMAL; v_employee_id UUID;
    v_pm_allows_change BOOLEAN; v_batch RECORD; v_qty_left DECIMAL; v_take DECIMAL;
    v_sale_item_id UUID;
BEGIN
    v_employee_id := public.get_employee_id_from_session();
    IF v_employee_id IS NULL THEN
        IF EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()) THEN
            v_employee_id := auth.uid();
        ELSE
            RETURN jsonb_build_object('success', false, 'error', 'Usuario no autorizado', 'code', 'UNAUTHORIZED');
        END IF;
    END IF;
    
    v_pm_allows_change := p_payment_method IN ('efectivo', 'cash');
    
    SELECT COALESCE(MAX(ticket_number), 0) + 1 INTO v_ticket_number FROM public.sales WHERE store_id = p_store_id;
    
    -- Insertar Cabecera Venta (Total se actualizará luego)
    INSERT INTO public.sales (store_id, ticket_number, employee_id, client_id, total, payment_method, amount_received, change_given, sync_status)
    VALUES (p_store_id, v_ticket_number, v_employee_id, p_client_id, 0, p_payment_method, p_amount_received, 0, 'synced')
    RETURNING id INTO v_sale_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_quantity := (v_item->>'quantity')::DECIMAL;
        
        -- Validar producto
        SELECT name INTO v_product_name FROM public.products WHERE id = v_product_id AND store_id = p_store_id;
        IF NOT FOUND THEN 
            RAISE EXCEPTION 'Producto no encontrado: %', v_product_id;
        END IF;
        
        v_item_subtotal := 0;
        
        -- Insert dummy sale_item to get ID, we update it later
        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, subtotal)
        VALUES (v_sale_id, v_product_id, v_quantity, 0, 0)
        RETURNING id INTO v_sale_item_id;

        -- Consumir lotes FIFO y calcular subtotal
        FOR v_batch IN SELECT * FROM public.consume_stock_fifo(v_product_id, v_quantity)
        LOOP
            -- FIX: usar COALESCE para evitar propagación de nulos
            v_item_subtotal := v_item_subtotal + (v_batch.quantity_taken * COALESCE(v_batch.sale_price, 0));
            
            -- Registrar de qué lote salió para historial de utilidades
            INSERT INTO public.sale_item_batches (sale_item_id, batch_id, quantity_taken, cost_unit, sale_price)
            VALUES (v_sale_item_id, v_batch.batch_id, v_batch.quantity_taken, v_batch.cost_unit, COALESCE(v_batch.sale_price, 0));
        END LOOP;
        
        -- Actualizar el sale_item con el verdadero subtotal y unit_price ponderado
        UPDATE public.sale_items 
        SET subtotal = v_item_subtotal,
            unit_price = CASE WHEN v_quantity > 0 THEN v_item_subtotal / v_quantity ELSE 0 END
        WHERE id = v_sale_item_id;

        -- Registrar movimiento genérico de venta (El trigger ignora crear lote, porque ya lo consumimos arriba)
        INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by) 
        VALUES (v_product_id, 'venta', v_quantity, 'Venta #' || v_ticket_number, v_employee_id);
        
        v_total_calculated := v_total_calculated + v_item_subtotal;
    END LOOP;
    
    -- Validar Fiado
    IF p_payment_method = 'fiado' THEN
        IF p_client_id IS NULL THEN 
            RAISE EXCEPTION 'Se requiere cliente para fiado'; 
        END IF;
        SELECT balance, credit_limit INTO v_client_balance, v_client_limit FROM public.clients WHERE id = p_client_id FOR UPDATE;
        IF NOT FOUND THEN 
            RAISE EXCEPTION 'Cliente no encontrado'; 
        END IF;
        IF (v_client_balance + v_total_calculated) > v_client_limit THEN
            RAISE EXCEPTION 'Cupo excedido';
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
    IF v_pm_allows_change THEN
        DECLARE v_session_id UUID;
        BEGIN
            SELECT id INTO v_session_id FROM public.cash_sessions WHERE store_id = p_store_id AND status = 'open' ORDER BY opened_at DESC LIMIT 1;
            -- FIX: Solo registrar movimiento de caja si el total > 0 para evitar fallar constraint amount > 0
            IF v_session_id IS NOT NULL AND v_total_calculated > 0 THEN
                INSERT INTO public.cash_movements (session_id, movement_type, amount, description, sale_id) 
                VALUES (v_session_id, 'ingreso', v_total_calculated, 'Venta #' || v_ticket_number, v_sale_id);
            END IF;
        END;
    END IF;
    
    -- Fiado Ledger
    IF p_payment_method = 'fiado' THEN
        UPDATE public.clients SET balance = balance + v_total_calculated WHERE id = p_client_id;
        IF v_total_calculated > 0 THEN
            INSERT INTO public.client_ledger (client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by)
            VALUES (p_client_id, p_store_id, v_total_calculated, v_client_balance, v_sale_id, 'venta_fiado', v_employee_id);
        END IF;
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

-- 2. Arreglar rpc_force_sale para agrupar ítems
CREATE OR REPLACE FUNCTION public.rpc_force_sale(
    p_store_id uuid,
    p_client_id uuid,
    p_payment_method text,
    p_items jsonb,
    p_justification text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
DECLARE
    v_role TEXT;
    v_item JSONB;
    v_product_id UUID;
    v_qty NUMERIC;
    v_current_stock NUMERIC;
    v_deficit NUMERIC;
    v_sale_result JSONB;
    v_sale_id UUID;
    v_affected_count INT := 0;
    v_grouped_items JSONB;
BEGIN
    SELECT role INTO v_role FROM public.admin_profiles WHERE id = auth.uid();
    IF v_role IS NULL OR v_role NOT IN ('admin', 'owner') THEN
        RAISE EXCEPTION 'Access Denied: FRD-007 Enforced.';
    END IF;

    IF length(p_justification) < 10 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Justificación muy corta (min 10 caracteres).');
    END IF;

    -- FIX: Agrupar por product_id para evitar inyectar stock insuficiente
    SELECT jsonb_agg(jsonb_build_object('product_id', pid, 'quantity', qty)) INTO v_grouped_items
    FROM (
        SELECT (item->>'product_id')::UUID as pid, SUM((item->>'quantity')::NUMERIC) as qty
        FROM jsonb_array_elements(p_items) AS item
        GROUP BY 1
    ) agg;

    FOR v_item IN SELECT * FROM jsonb_array_elements(v_grouped_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_qty := (v_item->>'quantity')::NUMERIC;
        SELECT current_stock INTO v_current_stock FROM public.products WHERE id = v_product_id;
        v_deficit := v_qty - COALESCE(v_current_stock, 0);
        
        IF v_deficit > 0 THEN
            INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by)
            VALUES (v_product_id, 'CORRECCION_SISTEMA', v_deficit, 'AUTO-CORRECCION: ' || p_justification, public.get_employee_id_from_session());
            v_affected_count := v_affected_count + 1;
        END IF;
    END LOOP;

    -- Pass original p_items to rpc_procesar_venta_v2, preserving original frontend split prices if any
    SELECT public.rpc_procesar_venta_v2(p_store_id, p_client_id, p_payment_method, 0, p_items) INTO v_sale_result;
    
    IF (v_sale_result->>'success')::boolean IS NOT TRUE THEN
        RAISE EXCEPTION 'Venta falló tras ajuste: %', v_sale_result->>'error';
    END IF;

    v_sale_id := (v_sale_result->>'sale_id')::UUID;

    INSERT INTO public.audit_logs (store_id, actor_id, event_type, resource_id, metadata, severity)
    VALUES (
        p_store_id,
        auth.uid(),
        'FORCE_SALE',
        v_sale_id::TEXT,
        jsonb_build_object('reason', p_justification, 'items_adjusted', v_affected_count, 'original_items', p_items),
        'warning'
    );

    RETURN jsonb_build_object('success', true, 'sale_id', v_sale_id, 'adjusted_items', v_affected_count);
END;
$function$;

-- 3. Crear rpc_actualizar_precio_lote
CREATE OR REPLACE FUNCTION public.rpc_actualizar_precio_lote(
    p_batch_id uuid,
    p_cost_unit numeric,
    p_sale_price numeric
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE
    v_role TEXT;
    v_batch RECORD;
    v_user_id UUID := auth.uid();
BEGIN
    SELECT role INTO v_role FROM public.admin_profiles WHERE id = v_user_id;
    IF v_role IS NULL OR v_role NOT IN ('admin', 'owner') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Permisos insuficientes para editar lotes.');
    END IF;

    SELECT b.*, p.store_id INTO v_batch 
    FROM public.inventory_batches b 
    JOIN public.products p ON b.product_id = p.id
    WHERE b.id = p_batch_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Lote no encontrado.');
    END IF;

    IF v_batch.quantity_remaining <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solo se pueden editar precios de lotes activos (con stock).');
    END IF;

    -- Actualizar Lote
    UPDATE public.inventory_batches
    SET cost_unit = p_cost_unit,
        sale_price = p_sale_price
    WHERE id = p_batch_id;

    -- Registrar Auditoría
    INSERT INTO public.audit_logs (store_id, actor_id, event_type, resource_id, metadata, severity)
    VALUES (
        v_batch.store_id,
        v_user_id,
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

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Error interno: ' || SQLERRM);
END;
$$;

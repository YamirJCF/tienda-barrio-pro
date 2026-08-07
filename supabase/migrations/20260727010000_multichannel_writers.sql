-- Migration: Phase 2.1 - Multichannel Writers (Escritores)
-- Date: 2026-07-27

-- ==============================================================================
-- 1. rpc_procesar_venta_v2 (Ventas Activas y Offline V2)
-- ==============================================================================
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
    
    -- Insertar Cabecera Venta
    INSERT INTO public.sales (store_id, ticket_number, employee_id, client_id, total, payment_method, amount_received, change_given, sync_status)
    VALUES (p_store_id, v_ticket_number, v_employee_id, p_client_id, 0, p_payment_method, p_amount_received, 0, 'synced')
    RETURNING id INTO v_sale_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_quantity := (v_item->>'quantity')::DECIMAL;
        
        SELECT name INTO v_product_name FROM public.products WHERE id = v_product_id AND store_id = p_store_id;
        IF NOT FOUND THEN 
            RAISE EXCEPTION 'Producto no encontrado: %', v_product_id;
        END IF;
        
        v_item_subtotal := 0;
        
        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, subtotal)
        VALUES (v_sale_id, v_product_id, v_quantity, 0, 0)
        RETURNING id INTO v_sale_item_id;

        FOR v_batch IN SELECT * FROM public.consume_stock_fifo(v_product_id, v_quantity)
        LOOP
            v_item_subtotal := v_item_subtotal + (v_batch.quantity_taken * COALESCE(v_batch.sale_price, 0));
            
            INSERT INTO public.sale_item_batches (sale_item_id, batch_id, quantity_taken, cost_unit, sale_price)
            VALUES (v_sale_item_id, v_batch.batch_id, v_batch.quantity_taken, v_batch.cost_unit, COALESCE(v_batch.sale_price, 0));
        END LOOP;
        
        UPDATE public.sale_items 
        SET subtotal = v_item_subtotal,
            unit_price = CASE WHEN v_quantity > 0 THEN v_item_subtotal / v_quantity ELSE 0 END
        WHERE id = v_sale_item_id;

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

    -- Actualizar Cabecera
    UPDATE public.sales 
    SET total = v_total_calculated, change_given = v_change
    WHERE id = v_sale_id;

    -- Cash Session Move (NUEVO: Insertar para cualquier método que NO sea fiado, guardando el canal multicanal)
    IF p_payment_method != 'fiado' THEN
        DECLARE v_session_id UUID;
        BEGIN
            SELECT id INTO v_session_id FROM public.cash_sessions WHERE store_id = p_store_id AND status = 'open' ORDER BY opened_at DESC LIMIT 1;
            IF v_session_id IS NOT NULL AND v_total_calculated > 0 THEN
                INSERT INTO public.cash_movements (session_id, movement_type, amount, description, sale_id, payment_method) 
                VALUES (v_session_id, 'ingreso', v_total_calculated, 'Venta #' || v_ticket_number, v_sale_id, p_payment_method);
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

-- ==============================================================================
-- 2. procesar_venta (Legacy/Offline Sync Fallback)
-- ==============================================================================
CREATE OR REPLACE FUNCTION procesar_venta(
    p_store_id UUID,
    p_employee_id UUID,
    p_items JSONB,
    p_total NUMERIC,
    p_payment_method TEXT,
    p_amount_received NUMERIC DEFAULT NULL,
    p_client_id UUID DEFAULT NULL,
    p_local_id TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_sale_id UUID;
    v_ticket_number INTEGER;
    v_item JSONB;
    v_change DECIMAL;
    v_session_id UUID;
BEGIN
    PERFORM assert_store_access(p_store_id);

    IF jsonb_array_length(p_items) > 50 THEN
        RETURN json_build_object('success', false, 'error', 'Máximo 50 productos por venta', 'code', 'MAX_ITEMS_EXCEEDED');
    END IF;

    SELECT COALESCE(MAX(ticket_number), 0) + 1 INTO v_ticket_number FROM public.sales WHERE store_id = p_store_id;

    IF p_payment_method IN ('efectivo', 'cash') AND p_amount_received IS NOT NULL THEN
        v_change := p_amount_received - p_total;
    ELSE
        v_change := 0;
    END IF;

    INSERT INTO public.sales (store_id, ticket_number, employee_id, client_id, total, payment_method, amount_received, change_given, local_id, sync_status)
    VALUES (p_store_id, v_ticket_number, p_employee_id, p_client_id, p_total, p_payment_method, p_amount_received, v_change, p_local_id, 'synced')
    RETURNING id INTO v_sale_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, subtotal)
        VALUES (v_sale_id, (v_item->>'product_id')::UUID, (v_item->>'quantity')::DECIMAL, (v_item->>'unit_price')::DECIMAL, (v_item->>'subtotal')::DECIMAL);

        INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by)
        VALUES ((v_item->>'product_id')::UUID, 'venta', (v_item->>'quantity')::DECIMAL, 'Venta #' || v_ticket_number, p_employee_id);
    END LOOP;

    -- NUEVO: En la función legacy también registramos el cash_movement para multicanal
    IF p_payment_method != 'fiado' THEN
        SELECT id INTO v_session_id FROM public.cash_sessions WHERE store_id = p_store_id AND status = 'open' ORDER BY opened_at DESC LIMIT 1;
        IF v_session_id IS NOT NULL AND p_total > 0 THEN
            INSERT INTO public.cash_movements (session_id, movement_type, amount, description, sale_id, payment_method) 
            VALUES (v_session_id, 'ingreso', p_total, 'Venta Offline #' || v_ticket_number, v_sale_id, p_payment_method);
        END IF;
    END IF;

    RETURN json_build_object('success', true, 'sale_id', v_sale_id, 'ticket_number', v_ticket_number);

EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', 'Error interno del servidor', 'code', 'SALE_PROCESSING_ERROR');
END;
$$;


-- ==============================================================================
-- 3. registrar_abono (Abonos de Crédito - Regla innegociable y Multicanal)
-- ==============================================================================
-- Nota: Dado que cambimos la firma de la función (añadiendo p_payment_method), debemos hacer DROP a la antigua
DROP FUNCTION IF EXISTS public.registrar_abono(uuid, numeric);

CREATE OR REPLACE FUNCTION public.registrar_abono(p_client_id uuid, p_amount numeric, p_payment_method text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_client public.clients%ROWTYPE;
  v_new_balance DECIMAL;
  v_session_id UUID;
BEGIN
  IF p_amount <= 0 THEN
    RETURN json_build_object('success', false, 'error', 'El monto del abono debe ser mayor a cero', 'code', 'INVALID_AMOUNT');
  END IF;

  SELECT * INTO v_client FROM public.clients WHERE id = p_client_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Cliente no encontrado', 'code', 'CLIENT_NOT_FOUND');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.employees WHERE store_id = v_client.store_id AND id = auth.uid()) 
     AND NOT EXISTS (SELECT 1 FROM public.admin_profiles WHERE store_id = v_client.store_id AND id = auth.uid()) THEN
      RAISE EXCEPTION 'IDOR Detectado: Acceso denegado a cliente.' USING ERRCODE = 'P0001';
  END IF;

  -- NUEVO: Bloqueo innegociable si la caja está cerrada
  SELECT id INTO v_session_id FROM public.cash_sessions WHERE store_id = v_client.store_id AND status = 'open' ORDER BY opened_at DESC LIMIT 1;
  IF v_session_id IS NULL THEN
      RETURN json_build_object('success', false, 'error', 'No hay una caja abierta para registrar el dinero del abono', 'code', 'NO_OPEN_CASH_SESSION');
  END IF;

  IF p_amount > v_client.balance THEN
    RETURN json_build_object('success', false, 'error', format('El abono ($%s) supera la deuda actual ($%s)', p_amount, v_client.balance), 'code', 'AMOUNT_EXCEEDS_BALANCE');
  END IF;
  
  v_new_balance := v_client.balance - p_amount;
  
  UPDATE public.clients SET balance = v_new_balance WHERE id = p_client_id;
  
  -- Registrar en el Ledger (con valor negativo)
  INSERT INTO public.client_ledger (client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by)
  VALUES (p_client_id, v_client.store_id, -p_amount, v_client.balance, NULL, 'abono', auth.uid());

  -- NUEVO: Registrar ingreso en caja con el método de pago (multicanal)
  INSERT INTO public.cash_movements (session_id, movement_type, amount, description, payment_method) 
  VALUES (v_session_id, 'ingreso', p_amount, 'Abono de deuda - Cliente: ' || v_client.name, p_payment_method);
  
  RETURN json_build_object('success', true, 'new_balance', v_new_balance, 'data', json_build_object('new_balance', v_new_balance));
END;
$function$;

ALTER FUNCTION public.registrar_abono(uuid, numeric, text) OWNER TO postgres;


-- ==============================================================================
-- 4. rpc_pay_supplier_invoice (Pago a Proveedores - Seguro y Multicanal)
-- ==============================================================================
DROP FUNCTION IF EXISTS public.rpc_pay_supplier_invoice(UUID, DECIMAL);

CREATE OR REPLACE FUNCTION public.rpc_pay_supplier_invoice(
    p_invoice_id UUID,
    p_amount DECIMAL(12,0),
    p_payment_method TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_invoice RECORD;
    v_active_cash_session UUID;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'El monto del abono debe ser mayor a cero.';
    END IF;

    SELECT * INTO v_invoice FROM public.supplier_invoices WHERE id = p_invoice_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Factura no encontrada.';
    END IF;

    -- [SEGURIDAD NIVEL 1]
    PERFORM public.assert_store_access(v_invoice.store_id);

    -- [SEGURIDAD NIVEL 2]
    IF NOT EXISTS (
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid() AND store_id = v_invoice.store_id
    ) THEN
        RAISE EXCEPTION 'No tienes permisos de Administrador para registrar pagos a proveedores.';
    END IF;
    
    SELECT id INTO v_active_cash_session 
    FROM public.cash_sessions 
    WHERE store_id = v_invoice.store_id AND status = 'open'
    LIMIT 1;

    IF v_active_cash_session IS NULL THEN
        RAISE EXCEPTION 'No hay un turno de caja abierto para registrar el egreso.';
    END IF;

    IF p_amount > (v_invoice.total_amount - v_invoice.amount_paid) THEN
        RAISE EXCEPTION 'El abono supera el saldo pendiente de la factura.';
    END IF;

    UPDATE public.supplier_invoices
    SET amount_paid = amount_paid + p_amount
    WHERE id = p_invoice_id;

    -- NUEVO: Egreso con payment_method
    INSERT INTO public.cash_movements (
        session_id, movement_type, amount, description, payment_method
    ) VALUES (
        v_active_cash_session,
        'pago_proveedor',
        p_amount,
        'Abono a factura de proveedor (ID: ' || p_invoice_id || ')',
        p_payment_method
    );
END;
$$;

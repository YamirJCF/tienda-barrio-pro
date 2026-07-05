-- Migración de Seguridad: Parcheo de Funciones SECURITY DEFINER (Anti-IDOR)
-- Añadiendo comprobaciones estrictas de auth.uid()

-- 1. abrir_caja
CREATE OR REPLACE FUNCTION "public"."abrir_caja"("p_store_id" "uuid", "p_employee_id" "uuid", "p_opening_balance" numeric) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_existing_session UUID;
  v_session_id UUID;
BEGIN
  -- Mitigación IDOR: Validar que el p_employee_id sea el llamador, o sea admin
  IF auth.uid() != p_employee_id AND NOT EXISTS (SELECT 1 FROM public.admin_profiles WHERE store_id = p_store_id AND id = auth.uid()) THEN
      RAISE EXCEPTION 'IDOR Detectado: Acceso denegado a caja.' USING ERRCODE = 'P0001';
  END IF;

  -- Verificar que no hay sesión abierta
  SELECT id INTO v_existing_session
  FROM public.cash_sessions
  WHERE store_id = p_store_id AND status = 'open';
  
  IF FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Ya existe una caja abierta',
      'code', 'CASH_ALREADY_OPEN'
    );
  END IF;
  
  -- Crear nueva sesión
  INSERT INTO public.cash_sessions (store_id, opened_by, opening_balance)
  VALUES (p_store_id, p_employee_id, p_opening_balance)
  RETURNING id INTO v_session_id;
  
  RETURN json_build_object(
    'success', true,
    'session_id', v_session_id
  );
END;
$$;

-- 2. cerrar_caja
CREATE OR REPLACE FUNCTION "public"."cerrar_caja"("p_session_id" "uuid", "p_employee_id" "uuid", "p_actual_balance" numeric) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_session public.cash_sessions%ROWTYPE;
  v_expected DECIMAL;
  v_ingresos DECIMAL;
  v_gastos DECIMAL;
  v_difference DECIMAL;
BEGIN
  -- Obtener sesión
  SELECT * INTO v_session FROM public.cash_sessions WHERE id = p_session_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Sesión no encontrada', 'code', 'SESSION_NOT_FOUND');
  END IF;

  -- Mitigación IDOR
  IF auth.uid() != p_employee_id AND NOT EXISTS (SELECT 1 FROM public.admin_profiles WHERE store_id = v_session.store_id AND id = auth.uid()) THEN
      RAISE EXCEPTION 'IDOR Detectado: Acceso denegado a caja.' USING ERRCODE = 'P0001';
  END IF;
  
  IF v_session.status = 'closed' THEN
    RETURN json_build_object('success', false, 'error', 'La caja ya está cerrada', 'code', 'ALREADY_CLOSED');
  END IF;
  
  -- Calcular ingresos
  SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
  FROM public.cash_movements
  WHERE session_id = p_session_id AND movement_type = 'ingreso';
  
  -- Calcular gastos
  SELECT COALESCE(SUM(amount), 0) INTO v_gastos
  FROM public.cash_movements
  WHERE session_id = p_session_id AND movement_type = 'gasto';
  
  -- Fórmula de conciliación
  v_expected := v_session.opening_balance + v_ingresos - v_gastos;
  v_difference := v_expected - p_actual_balance;
  
  -- Cerrar sesión
  UPDATE public.cash_sessions
  SET 
    closed_by = p_employee_id,
    expected_balance = v_expected,
    actual_balance = p_actual_balance,
    difference = v_difference,
    status = 'closed',
    closed_at = now()
  WHERE id = p_session_id;
  
  RETURN json_build_object(
    'success', true,
    'expected_balance', v_expected,
    'actual_balance', p_actual_balance,
    'difference', v_difference
  );
END;
$$;

-- 3. procesar_venta
CREATE OR REPLACE FUNCTION "public"."procesar_venta"("p_store_id" "uuid", "p_employee_id" "uuid", "p_items" "jsonb", "p_total" numeric, "p_payment_method" "text", "p_amount_received" numeric DEFAULT NULL::numeric, "p_client_id" "uuid" DEFAULT NULL::"uuid", "p_local_id" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_sale_id UUID;
  v_ticket_number INTEGER;
  v_item JSONB;
  v_change DECIMAL;
  v_rounding_diff DECIMAL := 0;
BEGIN
  -- Mitigación IDOR
  IF auth.uid() != p_employee_id AND NOT EXISTS (SELECT 1 FROM public.admin_profiles WHERE store_id = p_store_id AND id = auth.uid()) THEN
      RAISE EXCEPTION 'IDOR Detectado: Operación de venta no autorizada.' USING ERRCODE = 'P0001';
  END IF;

  -- Validar límite de 50 items
  IF jsonb_array_length(p_items) > 50 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Máximo 50 productos por venta',
      'code', 'MAX_ITEMS_EXCEEDED'
    );
  END IF;
  
  -- Generar ticket_number secuencial para esta tienda
  SELECT COALESCE(MAX(ticket_number), 0) + 1 INTO v_ticket_number
  FROM public.sales
  WHERE store_id = p_store_id;
  
  -- Calcular vueltas si es efectivo
  IF p_payment_method = 'efectivo' AND p_amount_received IS NOT NULL THEN
    v_change := p_amount_received - p_total;
  END IF;
  
  -- Crear la venta
  INSERT INTO public.sales (
    store_id, ticket_number, employee_id, client_id,
    total, rounding_difference, payment_method,
    amount_received, change_given, local_id, sync_status
  )
  VALUES (
    p_store_id, v_ticket_number, p_employee_id, p_client_id,
    p_total, v_rounding_diff, p_payment_method,
    p_amount_received, v_change, p_local_id, 'synced'
  )
  RETURNING id INTO v_sale_id;
  
  -- Insertar items y crear movimientos de inventario
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    -- Insertar item
    INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, subtotal)
    VALUES (
      v_sale_id,
      (v_item->>'product_id')::UUID,
      (v_item->>'quantity')::DECIMAL,
      (v_item->>'unit_price')::DECIMAL,
      (v_item->>'subtotal')::DECIMAL
    );
    
    -- Crear movimiento de inventario (trigger actualizará stock)
    INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by)
    VALUES (
      (v_item->>'product_id')::UUID,
      'venta',
      (v_item->>'quantity')::DECIMAL,
      'Venta #' || v_ticket_number,
      p_employee_id
    );
  END LOOP;
  
  RETURN json_build_object(
    'success', true,
    'sale_id', v_sale_id,
    'ticket_number', v_ticket_number
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM,
    'code', 'SALE_PROCESSING_ERROR'
  );
END;
$$;

-- 4. registrar_abono
CREATE OR REPLACE FUNCTION "public"."registrar_abono"("p_client_id" "uuid", "p_amount" numeric) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $_$
DECLARE
  v_client public.clients%ROWTYPE;
  v_new_balance DECIMAL;
BEGIN
  -- Obtener cliente
  SELECT * INTO v_client FROM public.clients WHERE id = p_client_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Cliente no encontrado', 'code', 'CLIENT_NOT_FOUND');
  END IF;

  -- Mitigación IDOR
  IF NOT EXISTS (SELECT 1 FROM public.employees WHERE store_id = v_client.store_id AND id = auth.uid()) 
     AND NOT EXISTS (SELECT 1 FROM public.admin_profiles WHERE store_id = v_client.store_id AND id = auth.uid()) THEN
      RAISE EXCEPTION 'IDOR Detectado: Acceso denegado a cliente.' USING ERRCODE = 'P0001';
  END IF;
  
  -- Validar monto no excede balance
  IF p_amount > v_client.balance THEN
    RETURN json_build_object(
      'success', false,
      'error', format('El abono ($%s) supera la deuda actual ($%s)', p_amount, v_client.balance),
      'code', 'AMOUNT_EXCEEDS_BALANCE'
    );
  END IF;
  
  v_new_balance := v_client.balance - p_amount;
  
  -- Actualizar balance del cliente
  UPDATE public.clients SET balance = v_new_balance WHERE id = p_client_id;
  
  -- Registrar transacción
  INSERT INTO public.client_transactions (client_id, transaction_type, amount, description)
  VALUES (p_client_id, 'pago', p_amount, 'Abono efectivo');
  
  RETURN json_build_object(
    'success', true,
    'new_balance', v_new_balance
  );
END;
$_$;

-- 5. crear_empleado
CREATE OR REPLACE FUNCTION "public"."crear_empleado"("p_store_id" "uuid", "p_name" "text", "p_username" "text", "p_pin" "text", "p_permissions" "jsonb" DEFAULT '{}'::"jsonb") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_count INTEGER;
  v_employee_id UUID;
BEGIN
  -- Mitigación IDOR
  IF NOT EXISTS (SELECT 1 FROM public.admin_profiles WHERE store_id = p_store_id AND id = auth.uid()) THEN
      RAISE EXCEPTION 'IDOR Detectado: Solo administradores autorizados pueden crear.' USING ERRCODE = 'P0001';
  END IF;

  -- Validar límite de 5 empleados activos
  SELECT COUNT(*) INTO v_count
  FROM public.employees
  WHERE store_id = p_store_id AND is_active = true;
  
  IF v_count >= 5 THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Límite de 5 empleados activos alcanzado',
      'code', 'EMPLOYEE_LIMIT_REACHED'
    );
  END IF;
  
  -- Crear empleado con PIN hasheado
  INSERT INTO public.employees (store_id, name, username, pin_hash, permissions)
  VALUES (
    p_store_id,
    p_name,
    p_username,
    crypt(p_pin, gen_salt('bf')),
    p_permissions
  )
  RETURNING id INTO v_employee_id;
  
  RETURN json_build_object(
    'success', true,
    'employee_id', v_employee_id
  );
END;
$$;

-- 6. solicitar_pase_diario
CREATE OR REPLACE FUNCTION "public"."solicitar_pase_diario"("p_employee_id" "uuid", "p_device_fingerprint" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_existing_pass public.daily_passes%ROWTYPE;
  v_pass_id UUID;
BEGIN
  -- Mitigación IDOR
  IF auth.uid() != p_employee_id THEN
      RAISE EXCEPTION 'IDOR Detectado: Solo puedes pedir tu propio pase.' USING ERRCODE = 'P0001';
  END IF;

  -- Verificar si ya existe pase para hoy
  SELECT * INTO v_existing_pass
  FROM public.daily_passes
  WHERE employee_id = p_employee_id AND pass_date = CURRENT_DATE;
  
  IF FOUND THEN
    IF v_existing_pass.status = 'approved' THEN
      RETURN json_build_object('success', true, 'status', 'approved', 'pass_id', v_existing_pass.id);
    END IF;
    
    IF v_existing_pass.status = 'pending' THEN
      IF v_existing_pass.retry_count >= 3 THEN
        RETURN json_build_object('success', false, 'error', 'Límite de intentos alcanzado', 'code', 'MAX_RETRIES');
      END IF;
      
      UPDATE public.daily_passes
      SET retry_count = retry_count + 1, device_fingerprint = p_device_fingerprint
      WHERE id = v_existing_pass.id;
      
      RETURN json_build_object('success', true, 'status', 'pending', 'pass_id', v_existing_pass.id, 'retry_count', v_existing_pass.retry_count + 1);
    END IF;
    
    RETURN json_build_object('success', false, 'error', 'Pase ya procesado para hoy', 'code', 'ALREADY_PROCESSED');
  END IF;
  
  INSERT INTO public.daily_passes (employee_id, device_fingerprint)
  VALUES (p_employee_id, p_device_fingerprint)
  RETURNING id INTO v_pass_id;
  
  RETURN json_build_object('success', true, 'status', 'pending', 'pass_id', v_pass_id);
END;
$$;

-- 7. aprobar_pase_diario
CREATE OR REPLACE FUNCTION "public"."aprobar_pase_diario"("p_pass_id" "uuid", "p_admin_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  -- Mitigación IDOR
  IF auth.uid() != p_admin_id THEN
      RAISE EXCEPTION 'IDOR Detectado: No autorizado.' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.daily_passes
  SET status = 'approved', resolved_at = now(), resolved_by = p_admin_id
  WHERE id = p_pass_id AND status = 'pending';
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Pase no encontrado o ya procesado', 'code', 'NOT_FOUND');
  END IF;
  
  RETURN json_build_object('success', true);
END;
$$;

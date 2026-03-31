


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;




ALTER SCHEMA "public" OWNER TO "postgres";


CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."abrir_caja"("p_store_id" "uuid", "p_employee_id" "uuid", "p_opening_balance" numeric) RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_existing_session UUID;
  v_session_id UUID;
BEGIN
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


ALTER FUNCTION "public"."abrir_caja"("p_store_id" "uuid", "p_employee_id" "uuid", "p_opening_balance" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."aprobar_pase_diario"("p_pass_id" "uuid", "p_admin_id" "uuid") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE public.daily_passes
  SET status = 'approved', resolved_at = now(), resolved_by = p_admin_id
  WHERE id = p_pass_id AND status = 'pending';
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Pase no encontrado o ya procesado', 'code', 'NOT_FOUND');
  END IF;
  
  RETURN json_build_object('success', true);
END;
$$;


ALTER FUNCTION "public"."aprobar_pase_diario"("p_pass_id" "uuid", "p_admin_id" "uuid") OWNER TO "postgres";


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


ALTER FUNCTION "public"."cerrar_caja"("p_session_id" "uuid", "p_employee_id" "uuid", "p_actual_balance" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."crear_empleado"("p_store_id" "uuid", "p_name" "text", "p_username" "text", "p_pin" "text", "p_permissions" "jsonb" DEFAULT '{}'::"jsonb") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_count INTEGER;
  v_employee_id UUID;
BEGIN
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


ALTER FUNCTION "public"."crear_empleado"("p_store_id" "uuid", "p_name" "text", "p_username" "text", "p_pin" "text", "p_permissions" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_default_supplier"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.suppliers (store_id, name, frequency_days, lead_time_days, is_default)
  VALUES (NEW.id, 'Proveedor General', 7, 1, TRUE);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."create_default_supplier"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."expire_daily_passes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.status = 'closed' AND OLD.status = 'open' THEN
    UPDATE public.daily_passes dp
    SET status = 'expired'
    FROM public.employees e
    WHERE dp.employee_id = e.id
      AND e.store_id = NEW.store_id
      AND dp.status = 'approved'
      AND dp.pass_date = CURRENT_DATE;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."expire_daily_passes"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_current_store_id"() RETURNS "uuid"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
BEGIN
  RETURN (auth.jwt() ->> 'store_id')::UUID;
END;
$$;


ALTER FUNCTION "public"."get_current_store_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_smart_supply_report"("p_store_id" "uuid") RETURNS TABLE("product_id" "uuid", "product_name" "text", "current_stock" numeric, "velocity" numeric, "doi" numeric, "revenue_at_risk" numeric, "status" "text", "suggestion" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_window_days INT := 30;
BEGIN
    -- Authorization check using employee id
    IF NOT EXISTS (
        SELECT 1 FROM public.employees 
        WHERE store_id = p_store_id AND id = auth.uid()
    ) AND NOT EXISTS (
        SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Acceso no autorizado a store_id: %', p_store_id;
    END IF;

    RETURN QUERY
    WITH sales_stats AS (
        SELECT 
            si.product_id,
            SUM(si.quantity) as total_sold,
            COUNT(DISTINCT DATE(si.created_at)) as days_sold
        FROM sale_items si
        JOIN sales s ON si.sale_id = s.id
        WHERE s.store_id = p_store_id
        AND s.created_at >= (NOW() - (v_window_days || ' days')::INTERVAL)
        GROUP BY si.product_id
    ),
    product_calc AS (
        SELECT 
            p.id,
            p.name,
            p.current_stock,
            p.price,
            COALESCE(ss.total_sold, 0) as total_sold,
            COALESCE(ss.total_sold, 0) / NULLIF(v_window_days, 0) as velocity,
            COALESCE(sup.frequency_days, 7) as frequency_days,
            COALESCE(sup.lead_time_days, 1) as lead_time_days
        FROM products p
        LEFT JOIN suppliers sup ON p.supplier_id = sup.id
        LEFT JOIN sales_stats ss ON p.id = ss.product_id
        WHERE p.store_id = p_store_id
    )
    SELECT 
        pc.id,
        pc.name,
        pc.current_stock,
        pc.velocity,
        CASE WHEN pc.velocity > 0 THEN pc.current_stock / pc.velocity ELSE 999 END as doi,
        CASE 
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days 
            THEN (pc.lead_time_days - (COALESCE(pc.current_stock, 0) / pc.velocity)) * pc.velocity * COALESCE(pc.price, 0)
            ELSE 0 
        END as revenue_at_risk,
        CASE
            WHEN pc.velocity = 0 THEN 'UNKNOWN'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days THEN 'CRITICAL'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < (pc.lead_time_days + pc.frequency_days) THEN 'WARNING'
            ELSE 'OK'
        END::text as status,
        CASE
            WHEN pc.velocity = 0 THEN 'Recopilando datos...'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < pc.lead_time_days 
                THEN 'Pedir urgente: se agotará antes de la próxima entrega.'
            WHEN (COALESCE(pc.current_stock, 0) / NULLIF(pc.velocity, 0)) < (pc.lead_time_days + pc.frequency_days) 
                THEN 'Incluir en próximo pedido.'
            ELSE 'Stock suficiente por ahora.'
        END::text as suggestion
    FROM product_calc pc;

EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Error en Smart Supply Report: %', SQLERRM;
    RETURN;
END;
$$;


ALTER FUNCTION "public"."get_smart_supply_report"("p_store_id" "uuid") OWNER TO "postgres";


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


ALTER FUNCTION "public"."procesar_venta"("p_store_id" "uuid", "p_employee_id" "uuid", "p_items" "jsonb", "p_total" numeric, "p_payment_method" "text", "p_amount_received" numeric, "p_client_id" "uuid", "p_local_id" "text") OWNER TO "postgres";


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


ALTER FUNCTION "public"."registrar_abono"("p_client_id" "uuid", "p_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_anular_venta"("p_sale_id" "uuid", "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_sale RECORD;
    v_item RECORD;
    v_user_role TEXT;
    v_store_id UUID;
BEGIN
    -- 1. Validar Permisos (Solo Admin/Owner puede anular)
    IF NOT EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solo administradores pueden anular ventas', 'code', 'UNAUTHORIZED');
    END IF;

    -- 2. Obtener Venta
    SELECT * INTO v_sale FROM public.sales WHERE id = p_sale_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Venta no encontrada');
    END IF;

    IF v_sale.is_voided THEN
        RETURN jsonb_build_object('success', false, 'error', 'Esta venta ya fue anulada');
    END IF;
    
    v_store_id := v_sale.store_id;

    -- 3. Revertir Inventario (Loop items)
    FOR v_item IN SELECT * FROM public.sale_items WHERE sale_id = p_sale_id
    LOOP
        INSERT INTO public.inventory_movements (
            product_id, movement_type, quantity, reason, created_by
        ) VALUES (
            v_item.product_id,
            'devolucion', -- Esto activará el trigger update_product_stock sumando stock
            v_item.quantity,
            'ANULACION VENTA #' || v_sale.ticket_number,
            auth.uid()
        );
    END LOOP;

    -- 4. Revertir Dinero (Depende del método original)
    -- Si fue EFECTIVO -> Registrar salida de caja
    IF v_sale.payment_method = 'efectivo' OR v_sale.payment_method = 'cash' THEN
         -- Opcional: Insertar movimiento negativo en caja si existiera tabla de movimientos detallados linkeados
         -- Por ahora, asumimos que el cierre de caja reflejará la anulación si se recalcula, 
         -- pero para cash_movements lo ideal es un contra-asiento.
         INSERT INTO public.cash_movements (
            session_id, movement_type, amount, description, sale_id
         ) 
         SELECT id, 'salida', v_sale.total, 'REVERSO VENTA #' || v_sale.ticket_number, p_sale_id
         FROM public.cash_sessions 
         WHERE store_id = v_store_id AND status = 'open'
         LIMIT 1;
    END IF;

    -- Si fue FIADO -> Registrar abono en Ledger y Cliente
    IF v_sale.payment_method = 'fiado' AND v_sale.client_id IS NOT NULL THEN
        -- Insertar en Ledger (Abono por anulación)
        INSERT INTO public.client_ledger (
            client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by
        )
        SELECT 
            v_sale.client_id,
            v_store_id,
            -v_sale.total, -- Negativo para restar deuda
            c.balance,
            p_sale_id,
            'anulacion_fiado',
            auth.uid()
        FROM public.clients c WHERE c.id = v_sale.client_id;
        
        -- Actualizar balance cliente
        UPDATE public.clients 
        SET balance = balance - v_sale.total 
        WHERE id = v_sale.client_id;
    END IF;

    -- 5. Marcar Venta como Anulada
    UPDATE public.sales 
    SET is_voided = true, 
        void_reason = p_reason, 
        voided_by = auth.uid()
    WHERE id = p_sale_id;

    RETURN jsonb_build_object('success', true, 'message', 'Venta anulada correctamente');

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."rpc_anular_venta"("p_sale_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."rpc_procesar_venta_v2"("p_store_id" "uuid", "p_client_id" "uuid", "p_payment_method" "text", "p_amount_received" numeric, "p_items" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_sale_id UUID;
    v_ticket_number INTEGER;
    v_total_calculated DECIMAL(12, 0) := 0;
    v_change DECIMAL(12, 0) := 0;
    v_item JSONB;
    v_product_id UUID;
    v_quantity DECIMAL;
    v_product_price DECIMAL;
    v_product_name TEXT;
    v_subtotal DECIMAL;
    v_client_balance DECIMAL;
    v_client_limit DECIMAL;
    v_employee_id UUID := auth.uid();
BEGIN
    -- 1. Validar Permisos Básicos
    IF NOT EXISTS (SELECT 1 FROM public.employees WHERE id = v_employee_id AND is_active = true) THEN
         -- Fallback si es admin
         IF NOT EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = v_employee_id) THEN
            RETURN jsonb_build_object('success', false, 'error', 'Usuario no autorizado', 'code', 'UNAUTHORIZED');
         END IF;
    END IF;

    -- 2. Calcular Total Real (Iterar items simulados)
    -- Nota: Hacemos un loop prevuelo para calcular total y validar stock antes de insertar nada
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_quantity := (v_item->>'quantity')::DECIMAL;
        
        -- Buscar Precio Oficial
        SELECT price, name INTO v_product_price, v_product_name
        FROM public.products 
        WHERE id = v_product_id AND store_id = p_store_id;
        
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'Producto no encontrado: ' || v_product_id);
        END IF;
        
        v_total_calculated := v_total_calculated + (v_product_price * v_quantity);
    END LOOP;

    -- 3. Validar FIADO
    IF p_payment_method = 'fiado' THEN
        IF p_client_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Se requiere cliente para fiado');
        END IF;
        
        -- Locking Client Row
        SELECT balance, credit_limit INTO v_client_balance, v_client_limit 
        FROM public.clients 
        WHERE id = p_client_id FOR UPDATE;
        
        IF NOT FOUND THEN
             RETURN jsonb_build_object('success', false, 'error', 'Cliente no encontrado');
        END IF;

        IF (v_client_balance + v_total_calculated) > v_client_limit THEN
            RETURN jsonb_build_object(
                'success', false, 
                'error', 'Cupo excedido. Cupo: ' || v_client_limit || '. Saldo Nuevo: ' || (v_client_balance + v_total_calculated),
                'code', 'CREDIT_LIMIT_EXCEEDED'
            );
        END IF;
    END IF;

    -- 4. Generar Ticket
    SELECT COALESCE(MAX(ticket_number), 0) + 1 INTO v_ticket_number 
    FROM public.sales WHERE store_id = p_store_id;

    -- 5. Insertar Venta
    v_change := CASE WHEN p_payment_method = 'efectivo' THEN GREATEST(0, p_amount_received - v_total_calculated) ELSE 0 END;

    INSERT INTO public.sales (
        store_id, ticket_number, employee_id, client_id, 
        total, payment_method, amount_received, change_given, 
        sync_status
    ) VALUES (
        p_store_id, v_ticket_number, v_employee_id, p_client_id,
        v_total_calculated, p_payment_method, p_amount_received, v_change,
        'synced'
    ) RETURNING id INTO v_sale_id;

    -- 6. Procesar Items (Stock Check implícito en Trigger update_product_stock)
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_quantity := (v_item->>'quantity')::DECIMAL;
        
        SELECT price INTO v_product_price FROM public.products WHERE id = v_product_id;
        v_subtotal := v_quantity * v_product_price;
        
        -- Insertar Item
        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, subtotal)
        VALUES (v_sale_id, v_product_id, v_quantity, v_product_price, v_subtotal);
        
        -- Insertar Movimiento Inventario (Esto dispara el Trigger que valida stock negativo)
        INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by)
        VALUES (v_product_id, 'venta', v_quantity, 'Venta #' || v_ticket_number, v_employee_id);
    END LOOP;

    -- 7. Actualizar Ledger si es Fiado
    IF p_payment_method = 'fiado' THEN
        INSERT INTO public.client_ledger (
            client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by
        ) VALUES (
            p_client_id, p_store_id, v_total_calculated, v_client_balance, v_sale_id, 'venta_fiado', v_employee_id
        );
        
        UPDATE public.clients 
        SET balance = balance + v_total_calculated 
        WHERE id = p_client_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true, 
        'sale_id', v_sale_id, 
        'ticket_number', v_ticket_number,
        'total', v_total_calculated
    );

EXCEPTION 
    WHEN OTHERS THEN
        -- El Rollback es automático en PostgreSQL functions si hay error
        RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."rpc_procesar_venta_v2"("p_store_id" "uuid", "p_client_id" "uuid", "p_payment_method" "text", "p_amount_received" numeric, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."solicitar_pase_diario"("p_employee_id" "uuid", "p_device_fingerprint" "text" DEFAULT NULL::"text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_existing_pass public.daily_passes%ROWTYPE;
  v_pass_id UUID;
BEGIN
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


ALTER FUNCTION "public"."solicitar_pase_diario"("p_employee_id" "uuid", "p_device_fingerprint" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_sale_to_cash"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_session_id UUID;
BEGIN
  -- Solo si es efectivo (Nequi/Fiado no entra al cajón físico)
  IF NEW.payment_method = 'efectivo' THEN
    -- Buscar sesión abierta para esta tienda
    SELECT id INTO v_session_id
    FROM public.cash_sessions
    WHERE store_id = NEW.store_id AND status = 'open'
    LIMIT 1;
    
    -- Si hay caja, registrar ingreso
    IF FOUND THEN
      INSERT INTO public.cash_movements (
        session_id,
        movement_type,
        amount,
        description,
        sale_id
      ) VALUES (
        v_session_id,
        'ingreso',
        NEW.total, -- Asumimos total como ingreso efectivo
        'Venta #' || NEW.ticket_number,
        NEW.id
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."sync_sale_to_cash"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_product_stock"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_new_stock DECIMAL(10,2);
  v_product public.products%ROWTYPE;
BEGIN
  -- Calcular nuevo stock según tipo de movimiento
  SELECT * INTO v_product FROM public.products WHERE id = NEW.product_id;
  
  CASE NEW.movement_type
    WHEN 'entrada', 'devolucion' THEN
      v_new_stock := v_product.current_stock + NEW.quantity;
    WHEN 'salida', 'venta' THEN
      v_new_stock := v_product.current_stock - NEW.quantity;
      -- Validar stock no negativo
      IF v_new_stock < 0 THEN
        RAISE EXCEPTION 'Stock insuficiente. Disponible: % %', 
          v_product.current_stock, v_product.measurement_unit;
      END IF;
    WHEN 'ajuste' THEN
      -- Ajuste puede ser positivo o negativo
      v_new_stock := v_product.current_stock + NEW.quantity;
      IF v_new_stock < 0 THEN
        RAISE EXCEPTION 'El ajuste resultaría en stock negativo';
      END IF;
  END CASE;
  
  -- Actualizar stock del producto
  UPDATE public.products
  SET current_stock = v_new_stock,
      -- Resetear alerta si stock vuelve a nivel normal
      low_stock_alerted = CASE 
        WHEN v_new_stock >= min_stock THEN false 
        ELSE low_stock_alerted 
      END
  WHERE id = NEW.product_id;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_product_stock"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validar_pin_empleado"("p_username" "text", "p_pin" "text") RETURNS json
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_employee public.employees%ROWTYPE;
  v_store_id UUID;
BEGIN
  SELECT * INTO v_employee
  FROM public.employees
  WHERE username = p_username AND is_active = true;
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Usuario no encontrado o inactivo', 'code', 'USER_NOT_FOUND');
  END IF;
  
  IF v_employee.pin_hash != crypt(p_pin, v_employee.pin_hash) THEN
    RETURN json_build_object('success', false, 'error', 'PIN incorrecto', 'code', 'INVALID_PIN');
  END IF;
  
  v_store_id := v_employee.store_id;
  
  RETURN json_build_object(
    'success', true,
    'employee', json_build_object(
      'id', v_employee.id,
      'name', v_employee.name,
      'username', v_employee.username,
      'permissions', v_employee.permissions,
      'store_id', v_store_id
    )
  );
END;
$$;


ALTER FUNCTION "public"."validar_pin_empleado"("p_username" "text", "p_pin" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_payment_type"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Solo movimientos tipo "entrada" con proveedor requieren payment_type
    IF NEW.movement_type = 'entrada' AND NEW.supplier_id IS NOT NULL THEN
        IF NEW.payment_type IS NULL THEN
            RAISE EXCEPTION 'Las entradas con proveedor requieren especificar tipo de pago (contado/credito)';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."validate_payment_type"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."admin_profiles" (
    "id" "uuid" NOT NULL,
    "store_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'owner'::"text" NOT NULL,
    "is_verified" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "admin_profiles_role_check" CHECK (("role" = ANY (ARRAY['owner'::"text", 'manager'::"text"])))
);


ALTER TABLE "public"."admin_profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cash_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "session_id" "uuid" NOT NULL,
    "movement_type" "text" NOT NULL,
    "amount" numeric(12,0) NOT NULL,
    "description" "text" NOT NULL,
    "sale_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "cash_movements_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "cash_movements_movement_type_check" CHECK (("movement_type" = ANY (ARRAY['ingreso'::"text", 'gasto'::"text"])))
);


ALTER TABLE "public"."cash_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cash_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "store_id" "uuid" NOT NULL,
    "opened_by" "uuid" NOT NULL,
    "closed_by" "uuid",
    "opening_balance" numeric(12,0) NOT NULL,
    "expected_balance" numeric(12,0),
    "actual_balance" numeric(12,0),
    "difference" numeric(12,0),
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "opened_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "closed_at" timestamp with time zone,
    CONSTRAINT "cash_sessions_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'closed'::"text"])))
);


ALTER TABLE "public"."cash_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."client_ledger" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "uuid" NOT NULL,
    "store_id" "uuid" NOT NULL,
    "amount" numeric(12,0) NOT NULL,
    "previous_balance" numeric(12,0) DEFAULT 0 NOT NULL,
    "new_balance" numeric(12,0) GENERATED ALWAYS AS (("previous_balance" + "amount")) STORED NOT NULL,
    "reference_id" "uuid" NOT NULL,
    "transaction_type" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    CONSTRAINT "client_ledger_transaction_type_check" CHECK (("transaction_type" = ANY (ARRAY['venta_fiado'::"text", 'abono'::"text", 'anulacion_fiado'::"text"])))
);


ALTER TABLE "public"."client_ledger" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."client_transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "client_id" "uuid" NOT NULL,
    "transaction_type" "text" NOT NULL,
    "amount" numeric(12,0) NOT NULL,
    "description" "text",
    "sale_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "client_transactions_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "client_transactions_transaction_type_check" CHECK (("transaction_type" = ANY (ARRAY['compra'::"text", 'pago'::"text"])))
);


ALTER TABLE "public"."client_transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clients" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "store_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "id_number" "text" NOT NULL,
    "phone" "text",
    "credit_limit" numeric(12,0) DEFAULT 100000 NOT NULL,
    "balance" numeric(12,0) DEFAULT 0,
    "is_deleted" boolean DEFAULT false,
    "deleted_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "clients_balance_check" CHECK (("balance" >= (0)::numeric)),
    CONSTRAINT "clients_name_check" CHECK (("length"("name") >= 3))
);


ALTER TABLE "public"."clients" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."daily_passes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "employee_id" "uuid" NOT NULL,
    "pass_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "device_fingerprint" "text",
    "retry_count" integer DEFAULT 0,
    "requested_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "resolved_at" timestamp with time zone,
    "resolved_by" "uuid",
    CONSTRAINT "daily_passes_retry_count_check" CHECK ((("retry_count" >= 0) AND ("retry_count" <= 3))),
    CONSTRAINT "daily_passes_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text", 'expired'::"text"])))
);


ALTER TABLE "public"."daily_passes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."employees" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "store_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "username" "text" NOT NULL,
    "pin_hash" "text" NOT NULL,
    "is_active" boolean DEFAULT true,
    "permissions" "jsonb" DEFAULT '{"canFiar": false, "canViewReports": false, "canOpenCloseCash": false, "canViewInventory": false}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."employees" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventory_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid" NOT NULL,
    "movement_type" "text" NOT NULL,
    "quantity" numeric(10,2) NOT NULL,
    "reason" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "supplier_id" "uuid",
    "invoice_reference" "text",
    "payment_type" "text",
    CONSTRAINT "inventory_movements_movement_type_check" CHECK (("movement_type" = ANY (ARRAY['entrada'::"text", 'salida'::"text", 'ajuste'::"text", 'venta'::"text", 'devolucion'::"text"]))),
    CONSTRAINT "inventory_movements_payment_type_check" CHECK (("payment_type" = ANY (ARRAY['contado'::"text", 'credito'::"text"])))
);


ALTER TABLE "public"."inventory_movements" OWNER TO "postgres";


COMMENT ON TABLE "public"."inventory_movements" IS 'Inventory movements with supplier tracking - refreshed at 2026-02-09';



COMMENT ON COLUMN "public"."inventory_movements"."payment_type" IS 'Tipo de pago para ENTRADAS de inventario: contado o credito. 
NULL para salidas/ajustes/ventas donde no aplica.';



CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "store_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "plu" "text",
    "price" numeric(12,0) NOT NULL,
    "cost_price" numeric(12,0),
    "current_stock" numeric(10,2) DEFAULT 0,
    "min_stock" numeric(10,2) DEFAULT 5,
    "category" "text",
    "measurement_unit" "text" DEFAULT 'unidad'::"text",
    "is_weighable" boolean DEFAULT false,
    "low_stock_alerted" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "supplier_id" "uuid",
    CONSTRAINT "products_current_stock_check" CHECK (("current_stock" >= (0)::numeric)),
    CONSTRAINT "products_measurement_unit_check" CHECK (("measurement_unit" = ANY (ARRAY['unidad'::"text", 'kg'::"text", 'lb'::"text", 'g'::"text"]))),
    CONSTRAINT "products_name_check" CHECK (("length"("name") >= 2)),
    CONSTRAINT "products_price_check" CHECK (("price" > (0)::numeric))
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sale_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "sale_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "quantity" numeric(10,2) NOT NULL,
    "unit_price" numeric(12,0) NOT NULL,
    "subtotal" numeric(12,0) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."sale_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "store_id" "uuid" NOT NULL,
    "ticket_number" integer NOT NULL,
    "employee_id" "uuid" NOT NULL,
    "client_id" "uuid",
    "total" numeric(12,0) NOT NULL,
    "rounding_difference" numeric(10,2) DEFAULT 0,
    "payment_method" "text" NOT NULL,
    "amount_received" numeric(12,0),
    "change_given" numeric(12,0),
    "sync_status" "text" DEFAULT 'pending'::"text",
    "local_id" "text",
    "is_voided" boolean DEFAULT false,
    "voided_by" "uuid",
    "void_reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "sales_payment_method_check" CHECK (("payment_method" = ANY (ARRAY['efectivo'::"text", 'nequi'::"text", 'daviplata'::"text", 'fiado'::"text"]))),
    CONSTRAINT "sales_sync_status_check" CHECK (("sync_status" = ANY (ARRAY['synced'::"text", 'pending'::"text", 'failed'::"text"])))
);


ALTER TABLE "public"."sales" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "subscription_plan" "text" DEFAULT 'free'::"text",
    "store_pin_hash" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "stores_subscription_plan_check" CHECK (("subscription_plan" = ANY (ARRAY['free'::"text", 'pro'::"text", 'enterprise'::"text"])))
);


ALTER TABLE "public"."stores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."suppliers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "store_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "delivery_day" integer,
    "frequency_days" integer DEFAULT 7 NOT NULL,
    "lead_time_days" integer DEFAULT 1 NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "suppliers_delivery_day_check" CHECK ((("delivery_day" >= 1) AND ("delivery_day" <= 7)))
);


ALTER TABLE "public"."suppliers" OWNER TO "postgres";


ALTER TABLE ONLY "public"."admin_profiles"
    ADD CONSTRAINT "admin_profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cash_movements"
    ADD CONSTRAINT "cash_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cash_sessions"
    ADD CONSTRAINT "cash_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_ledger"
    ADD CONSTRAINT "client_ledger_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_transactions"
    ADD CONSTRAINT "client_transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clients"
    ADD CONSTRAINT "clients_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clients"
    ADD CONSTRAINT "clients_store_id_id_number_key" UNIQUE ("store_id", "id_number");



ALTER TABLE ONLY "public"."daily_passes"
    ADD CONSTRAINT "daily_passes_employee_id_pass_date_key" UNIQUE ("employee_id", "pass_date");



ALTER TABLE ONLY "public"."daily_passes"
    ADD CONSTRAINT "daily_passes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."employees"
    ADD CONSTRAINT "employees_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."employees"
    ADD CONSTRAINT "employees_username_key" UNIQUE ("username");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "inventory_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_store_id_plu_key" UNIQUE ("store_id", "plu");



ALTER TABLE ONLY "public"."sale_items"
    ADD CONSTRAINT "sale_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_store_id_ticket_number_key" UNIQUE ("store_id", "ticket_number");



ALTER TABLE ONLY "public"."stores"
    ADD CONSTRAINT "stores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stores"
    ADD CONSTRAINT "stores_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."suppliers"
    ADD CONSTRAINT "suppliers_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_admin_profiles_store" ON "public"."admin_profiles" USING "btree" ("store_id");



CREATE INDEX "idx_cash_movements_session" ON "public"."cash_movements" USING "btree" ("session_id");



CREATE UNIQUE INDEX "idx_cash_sessions_one_open" ON "public"."cash_sessions" USING "btree" ("store_id") WHERE ("status" = 'open'::"text");



CREATE INDEX "idx_cash_sessions_store" ON "public"."cash_sessions" USING "btree" ("store_id");



CREATE INDEX "idx_client_transactions_pending_sync" ON "public"."client_transactions" USING "btree" ("client_id", "created_at") WHERE (("sale_id" IS NULL) AND ("transaction_type" = 'compra'::"text"));



COMMENT ON INDEX "public"."idx_client_transactions_pending_sync" IS 'Index for finding purchase transactions pending sale_id reconciliation after offline sync';



CREATE INDEX "idx_client_tx_client" ON "public"."client_transactions" USING "btree" ("client_id");



CREATE INDEX "idx_clients_store" ON "public"."clients" USING "btree" ("store_id") WHERE (NOT "is_deleted");



CREATE INDEX "idx_daily_passes_date" ON "public"."daily_passes" USING "btree" ("pass_date");



CREATE INDEX "idx_daily_passes_employee" ON "public"."daily_passes" USING "btree" ("employee_id");



CREATE INDEX "idx_daily_passes_status" ON "public"."daily_passes" USING "btree" ("status") WHERE ("status" = 'pending'::"text");



CREATE INDEX "idx_employees_active" ON "public"."employees" USING "btree" ("store_id", "is_active");



CREATE INDEX "idx_employees_store" ON "public"."employees" USING "btree" ("store_id");



CREATE INDEX "idx_employees_username" ON "public"."employees" USING "btree" ("username");



CREATE INDEX "idx_inventory_movements_payment_type" ON "public"."inventory_movements" USING "btree" ("payment_type") WHERE ("payment_type" IS NOT NULL);



CREATE INDEX "idx_inventory_movements_supplier_payment" ON "public"."inventory_movements" USING "btree" ("supplier_id", "payment_type", "created_at") WHERE ("supplier_id" IS NOT NULL);



CREATE INDEX "idx_ledger_client" ON "public"."client_ledger" USING "btree" ("client_id");



CREATE INDEX "idx_ledger_store" ON "public"."client_ledger" USING "btree" ("store_id");



CREATE INDEX "idx_movements_product" ON "public"."inventory_movements" USING "btree" ("product_id");



CREATE INDEX "idx_movements_supplier" ON "public"."inventory_movements" USING "btree" ("supplier_id") WHERE ("supplier_id" IS NOT NULL);



CREATE INDEX "idx_products_plu" ON "public"."products" USING "btree" ("store_id", "plu");



CREATE INDEX "idx_products_store" ON "public"."products" USING "btree" ("store_id");



CREATE INDEX "idx_sale_items_product_date" ON "public"."sale_items" USING "btree" ("product_id", "created_at" DESC);



CREATE INDEX "idx_sale_items_sale" ON "public"."sale_items" USING "btree" ("sale_id");



CREATE INDEX "idx_sales_created" ON "public"."sales" USING "btree" ("store_id", "created_at");



CREATE INDEX "idx_sales_employee" ON "public"."sales" USING "btree" ("employee_id");



CREATE INDEX "idx_sales_store" ON "public"."sales" USING "btree" ("store_id");



CREATE INDEX "idx_stores_slug" ON "public"."stores" USING "btree" ("slug");



CREATE UNIQUE INDEX "idx_suppliers_unique_default" ON "public"."suppliers" USING "btree" ("store_id") WHERE ("is_default" = true);



CREATE OR REPLACE TRIGGER "enforce_payment_type_on_entries" BEFORE INSERT OR UPDATE ON "public"."inventory_movements" FOR EACH ROW EXECUTE FUNCTION "public"."validate_payment_type"();



CREATE OR REPLACE TRIGGER "trg_clients_updated" BEFORE UPDATE ON "public"."clients" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "trg_create_default_supplier" AFTER INSERT ON "public"."stores" FOR EACH ROW EXECUTE FUNCTION "public"."create_default_supplier"();



CREATE OR REPLACE TRIGGER "trg_employees_updated" BEFORE UPDATE ON "public"."employees" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "trg_expire_passes_on_cash_close" AFTER UPDATE ON "public"."cash_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."expire_daily_passes"();



CREATE OR REPLACE TRIGGER "trg_products_updated" BEFORE UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "trg_sales_to_cash" AFTER INSERT ON "public"."sales" FOR EACH ROW EXECUTE FUNCTION "public"."sync_sale_to_cash"();



CREATE OR REPLACE TRIGGER "trg_stores_updated" BEFORE UPDATE ON "public"."stores" FOR EACH ROW EXECUTE FUNCTION "public"."update_timestamp"();



CREATE OR REPLACE TRIGGER "trg_update_stock" AFTER INSERT ON "public"."inventory_movements" FOR EACH ROW EXECUTE FUNCTION "public"."update_product_stock"();



ALTER TABLE ONLY "public"."admin_profiles"
    ADD CONSTRAINT "admin_profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."admin_profiles"
    ADD CONSTRAINT "admin_profiles_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."cash_movements"
    ADD CONSTRAINT "cash_movements_sale_id_fkey" FOREIGN KEY ("sale_id") REFERENCES "public"."sales"("id");



ALTER TABLE ONLY "public"."cash_movements"
    ADD CONSTRAINT "cash_movements_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."cash_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."cash_sessions"
    ADD CONSTRAINT "cash_sessions_closed_by_fkey" FOREIGN KEY ("closed_by") REFERENCES "public"."employees"("id");



ALTER TABLE ONLY "public"."cash_sessions"
    ADD CONSTRAINT "cash_sessions_opened_by_fkey" FOREIGN KEY ("opened_by") REFERENCES "public"."employees"("id");



ALTER TABLE ONLY "public"."cash_sessions"
    ADD CONSTRAINT "cash_sessions_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."client_ledger"
    ADD CONSTRAINT "client_ledger_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id");



ALTER TABLE ONLY "public"."client_ledger"
    ADD CONSTRAINT "client_ledger_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."employees"("id");



ALTER TABLE ONLY "public"."client_ledger"
    ADD CONSTRAINT "client_ledger_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id");



ALTER TABLE ONLY "public"."client_transactions"
    ADD CONSTRAINT "client_transactions_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."client_transactions"
    ADD CONSTRAINT "client_transactions_sale_id_fkey" FOREIGN KEY ("sale_id") REFERENCES "public"."sales"("id");



ALTER TABLE ONLY "public"."clients"
    ADD CONSTRAINT "clients_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."daily_passes"
    ADD CONSTRAINT "daily_passes_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "public"."employees"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."daily_passes"
    ADD CONSTRAINT "daily_passes_resolved_by_fkey" FOREIGN KEY ("resolved_by") REFERENCES "public"."employees"("id");



ALTER TABLE ONLY "public"."employees"
    ADD CONSTRAINT "employees_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "inventory_movements_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."employees"("id");



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "inventory_movements_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventory_movements"
    ADD CONSTRAINT "inventory_movements_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."sale_items"
    ADD CONSTRAINT "sale_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."sale_items"
    ADD CONSTRAINT "sale_items_sale_id_fkey" FOREIGN KEY ("sale_id") REFERENCES "public"."sales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "public"."employees"("id");



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_voided_by_fkey" FOREIGN KEY ("voided_by") REFERENCES "public"."employees"("id");



ALTER TABLE ONLY "public"."suppliers"
    ADD CONSTRAINT "suppliers_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "public"."stores"("id") ON DELETE CASCADE;



CREATE POLICY "Only admins can manage suppliers" ON "public"."suppliers" USING ((EXISTS ( SELECT 1
   FROM "public"."admin_profiles"
  WHERE (("admin_profiles"."id" = "auth"."uid"()) AND ("admin_profiles"."store_id" = "suppliers"."store_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."admin_profiles"
  WHERE (("admin_profiles"."id" = "auth"."uid"()) AND ("admin_profiles"."store_id" = "suppliers"."store_id")))));



CREATE POLICY "Users can view suppliers of their store" ON "public"."suppliers" FOR SELECT USING (("store_id" IN ( SELECT "employees"."store_id"
   FROM "public"."employees"
  WHERE ("employees"."id" = "auth"."uid"()))));



ALTER TABLE "public"."admin_profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "admin_profiles_select_own" ON "public"."admin_profiles" FOR SELECT USING (("store_id" = "public"."get_current_store_id"()));



CREATE POLICY "admin_profiles_update_self" ON "public"."admin_profiles" FOR UPDATE USING (("id" = "auth"."uid"()));



ALTER TABLE "public"."cash_movements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "cash_movements_insert_store" ON "public"."cash_movements" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."cash_sessions" "cs"
  WHERE (("cs"."id" = "cash_movements"."session_id") AND ("cs"."store_id" = "public"."get_current_store_id"())))));



CREATE POLICY "cash_movements_select_store" ON "public"."cash_movements" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."cash_sessions" "cs"
  WHERE (("cs"."id" = "cash_movements"."session_id") AND ("cs"."store_id" = "public"."get_current_store_id"())))));



ALTER TABLE "public"."cash_sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "cash_sessions_insert_store" ON "public"."cash_sessions" FOR INSERT WITH CHECK (("store_id" = "public"."get_current_store_id"()));



CREATE POLICY "cash_sessions_select_store" ON "public"."cash_sessions" FOR SELECT USING (("store_id" = "public"."get_current_store_id"()));



CREATE POLICY "cash_sessions_update_store" ON "public"."cash_sessions" FOR UPDATE USING (("store_id" = "public"."get_current_store_id"()));



ALTER TABLE "public"."client_ledger" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."client_transactions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "client_tx_insert_store" ON "public"."client_transactions" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."clients" "c"
  WHERE (("c"."id" = "client_transactions"."client_id") AND ("c"."store_id" = "public"."get_current_store_id"())))));



CREATE POLICY "client_tx_select_store" ON "public"."client_transactions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."clients" "c"
  WHERE (("c"."id" = "client_transactions"."client_id") AND ("c"."store_id" = "public"."get_current_store_id"())))));



ALTER TABLE "public"."clients" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "clients_insert_store" ON "public"."clients" FOR INSERT WITH CHECK (("store_id" = "public"."get_current_store_id"()));



CREATE POLICY "clients_select_store" ON "public"."clients" FOR SELECT USING ((("store_id" = "public"."get_current_store_id"()) AND (NOT "is_deleted")));



CREATE POLICY "clients_update_store" ON "public"."clients" FOR UPDATE USING (("store_id" = "public"."get_current_store_id"()));



ALTER TABLE "public"."daily_passes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "daily_passes_insert_own" ON "public"."daily_passes" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."employees" "e"
  WHERE (("e"."id" = "daily_passes"."employee_id") AND ("e"."store_id" = "public"."get_current_store_id"())))));



CREATE POLICY "daily_passes_select_store" ON "public"."daily_passes" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."employees" "e"
  WHERE (("e"."id" = "daily_passes"."employee_id") AND ("e"."store_id" = "public"."get_current_store_id"())))));



CREATE POLICY "daily_passes_update_store" ON "public"."daily_passes" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."employees" "e"
  WHERE (("e"."id" = "daily_passes"."employee_id") AND ("e"."store_id" = "public"."get_current_store_id"())))));



ALTER TABLE "public"."employees" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "employees_insert_store" ON "public"."employees" FOR INSERT WITH CHECK (("store_id" = "public"."get_current_store_id"()));



CREATE POLICY "employees_select_store" ON "public"."employees" FOR SELECT USING (("store_id" = "public"."get_current_store_id"()));



CREATE POLICY "employees_update_store" ON "public"."employees" FOR UPDATE USING (("store_id" = "public"."get_current_store_id"()));



ALTER TABLE "public"."inventory_movements" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ledger_read_store" ON "public"."client_ledger" FOR SELECT USING (("store_id" = "public"."get_current_store_id"()));



CREATE POLICY "movements_insert_store" ON "public"."inventory_movements" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."products" "p"
  WHERE (("p"."id" = "inventory_movements"."product_id") AND ("p"."store_id" = "public"."get_current_store_id"())))));



CREATE POLICY "movements_select_store" ON "public"."inventory_movements" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."products" "p"
  WHERE (("p"."id" = "inventory_movements"."product_id") AND ("p"."store_id" = "public"."get_current_store_id"())))));



ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "products_delete_admin_only" ON "public"."products" FOR DELETE USING ((("store_id" = "public"."get_current_store_id"()) AND ((EXISTS ( SELECT 1
   FROM "public"."admin_profiles"
  WHERE ("admin_profiles"."id" = "auth"."uid"()))) OR (("auth"."jwt"() ->> 'role'::"text") = 'service_role'::"text"))));



CREATE POLICY "products_insert_store" ON "public"."products" FOR INSERT WITH CHECK (("store_id" = "public"."get_current_store_id"()));



CREATE POLICY "products_select_store" ON "public"."products" FOR SELECT USING (("store_id" = "public"."get_current_store_id"()));



CREATE POLICY "products_update_store" ON "public"."products" FOR UPDATE USING (("store_id" = "public"."get_current_store_id"()));



ALTER TABLE "public"."sale_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sale_items_insert_store" ON "public"."sale_items" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."sales" "s"
  WHERE (("s"."id" = "sale_items"."sale_id") AND ("s"."store_id" = "public"."get_current_store_id"())))));



CREATE POLICY "sale_items_select_store" ON "public"."sale_items" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."sales" "s"
  WHERE (("s"."id" = "sale_items"."sale_id") AND ("s"."store_id" = "public"."get_current_store_id"())))));



ALTER TABLE "public"."sales" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sales_insert_store" ON "public"."sales" FOR INSERT WITH CHECK (("store_id" = "public"."get_current_store_id"()));



CREATE POLICY "sales_select_store" ON "public"."sales" FOR SELECT USING (("store_id" = "public"."get_current_store_id"()));



ALTER TABLE "public"."stores" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "stores_insert_auth" ON "public"."stores" FOR INSERT WITH CHECK (("auth"."uid"() IS NOT NULL));



CREATE POLICY "stores_select_own" ON "public"."stores" FOR SELECT USING (("id" = "public"."get_current_store_id"()));



CREATE POLICY "stores_update_own" ON "public"."stores" FOR UPDATE USING (("id" = "public"."get_current_store_id"()));



ALTER TABLE "public"."suppliers" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


REVOKE USAGE ON SCHEMA "public" FROM PUBLIC;
GRANT ALL ON SCHEMA "public" TO "anon";
GRANT ALL ON SCHEMA "public" TO "authenticated";
GRANT ALL ON SCHEMA "public" TO "service_role";








































































































































































































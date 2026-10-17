-- ============================================================================
-- MIGRACIÓN: 20261017135000_wave6_remediation_debts_and_offline.sql
-- DESCRIPCIÓN: Subsanación de Deudas Técnicas SQL identificadas en PAC-UXD:
--   1. D-5 (SDD_001): Alineación a zona horaria 'America/Bogota' en helpers RLS.
--   2. D-4 (SDD_003): Exclusión del propietario (admin_profiles) del cupo de 5 empleados.
--   3. D-6 (SDD_012): Idempotencia extendida (local_id/DUPLICATE_RESOLVED), precio histórico
--                     y turno flexible en rpc_procesar_venta_v3 durante sincronización offline.
-- ============================================================================

-- 1. Helper RLS: get_current_store_id (Alineación horaria Colombia UTC-5)
CREATE OR REPLACE FUNCTION public.get_current_store_id()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_store_id UUID;
  v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
BEGIN
  -- 1. Intentar obtener desde App Metadata (JWT)
  v_store_id := (auth.jwt() -> 'app_metadata' ->> 'store_id')::uuid;
  
  IF v_store_id IS NOT NULL THEN
    RETURN v_store_id;
  END IF;

  -- 2. Fallback: Buscar en admin_profiles (Dueño/Admin)
  SELECT store_id INTO v_store_id
  FROM public.admin_profiles
  WHERE id = auth.uid();
  
  IF v_store_id IS NOT NULL THEN
    RETURN v_store_id;
  END IF;

  -- 3. Fallback: Buscar en employees (Usuario de sistema con auth real)
  SELECT store_id INTO v_store_id
  FROM public.employees
  WHERE id = auth.uid();

  IF v_store_id IS NOT NULL THEN
    RETURN v_store_id;
  END IF;

  -- 4. Fallback: Buscar en daily_passes (Empleados Anónimos con Pase Aprobado hoy en Bogotá)
  SELECT store_id INTO v_store_id
  FROM public.daily_passes
  WHERE auth_user_id = auth.uid() 
    AND status = 'approved' 
    AND pass_date = v_today;

  RETURN v_store_id;
END;
$$;

-- 2. Helper RLS: get_employee_id_from_session (Alineación horaria Colombia UTC-5)
CREATE OR REPLACE FUNCTION public.get_employee_id_from_session()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_employee_id UUID;
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
BEGIN
    SELECT id INTO v_employee_id 
    FROM public.employees 
    WHERE id = v_user_id AND is_active = true;
    
    IF v_employee_id IS NOT NULL THEN
        RETURN v_employee_id;
    END IF;
    
    SELECT employee_id INTO v_employee_id
    FROM public.daily_passes
    WHERE auth_user_id = v_user_id
      AND status = 'approved'
      AND pass_date = v_today;
    
    RETURN v_employee_id;
END;
$$;

-- 3. Helper RLS: is_authorized_employee
CREATE OR REPLACE FUNCTION public.is_authorized_employee()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_employee_id UUID;
BEGIN
    v_employee_id := public.get_employee_id_from_session();
    IF v_employee_id IS NOT NULL THEN RETURN TRUE; END IF;
    IF EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()) THEN RETURN TRUE; END IF;
    RETURN FALSE;
END;
$$;

-- 4. RPC: crear_empleado (Exclusión de admin_profiles del conteo de 5 activos)
CREATE OR REPLACE FUNCTION public.crear_empleado(
    p_store_id UUID,
    p_name TEXT,
    p_username TEXT,
    p_pin TEXT,
    p_permissions JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INTEGER;
    v_employee_id UUID;
BEGIN
    -- 1. Aislamiento multi-tenant
    PERFORM public.assert_store_access(p_store_id);

    -- 2. Validar que el actor sea administrador (si viene autenticado)
    IF auth.uid() IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid() AND store_id = p_store_id
    ) THEN
        RAISE EXCEPTION 'UNAUTHORIZED: Solo el administrador puede crear empleados'
            USING ERRCODE = '42501';
    END IF;

    -- 3. Validar formato estricto de PIN de 4 dígitos
    IF p_pin !~ '^[0-9]{4}$' THEN
        RAISE EXCEPTION 'INVALID_PIN_FORMAT: El PIN debe ser numérico de exactamente 4 dígitos'
            USING ERRCODE = '22023';
    END IF;

    -- 4. Validar límite estricto de 5 empleados activos simultáneos (excluyendo al dueño/admin)
    SELECT COUNT(*) INTO v_count
    FROM public.employees e
    WHERE e.store_id = p_store_id 
      AND e.is_active = true
      AND NOT EXISTS (
          SELECT 1 FROM public.admin_profiles ap 
          WHERE ap.id = e.id
      );

    IF v_count >= 5 THEN
        RAISE EXCEPTION 'EMPLOYEE_LIMIT_REACHED: Límite de 5 empleados activos alcanzado para la tienda'
            USING ERRCODE = 'P0001';
    END IF;

    -- 5. Validar unicidad global del alias
    IF EXISTS (SELECT 1 FROM public.employees WHERE LOWER(username) = LOWER(p_username)) THEN
        RAISE EXCEPTION 'USERNAME_ALREADY_EXISTS: El alias ya está registrado en el sistema'
            USING ERRCODE = '23505';
    END IF;

    -- 6. Inserción segura con PIN hasheado (Blowfish)
    INSERT INTO public.employees (
        store_id,
        name,
        username,
        pin_hash,
        permissions,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        p_store_id,
        TRIM(p_name),
        TRIM(p_username),
        crypt(p_pin, gen_salt('bf')),
        COALESCE(p_permissions, '{}'::JSONB),
        true,
        now(),
        now()
    )
    RETURNING id INTO v_employee_id;

    -- 7. Auditoría
    INSERT INTO public.audit_logs (
        actor_id, event_type, resource_id, metadata, store_id, severity
    ) VALUES (
        auth.uid(),
        'EMPLOYEE_CREATED',
        v_employee_id::text,
        jsonb_build_object('name', p_name, 'username', p_username),
        p_store_id,
        'info'
    );

    RETURN jsonb_build_object(
        'success', true,
        'employee_id', v_employee_id
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

-- 5. RPC: toggle_empleado_activo (Exclusión de admin_profiles del conteo de 5 activos)
CREATE OR REPLACE FUNCTION public.toggle_empleado_activo(
    p_employee_id UUID,
    p_new_status BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_emp RECORD;
    v_count INTEGER;
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
BEGIN
    -- 1. Bloquear fila del empleado
    SELECT * INTO v_emp
    FROM public.employees
    WHERE id = p_employee_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'EMPLOYEE_NOT_FOUND: Empleado especificado no existe.'
            USING ERRCODE = 'P0002';
    END IF;

    -- 2. Aislamiento multi-tenant
    PERFORM public.assert_store_access(v_emp.store_id);

    -- 3. Validar administrador
    IF auth.uid() IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid() AND store_id = v_emp.store_id
    ) THEN
        RAISE EXCEPTION 'UNAUTHORIZED: Solo el administrador puede modificar el estado de colaboradores'
            USING ERRCODE = '42501';
    END IF;

    -- 4. Si se va a reactivar, validar cupo de 5 activos (excluyendo al dueño/admin)
    IF p_new_status IS TRUE THEN
        SELECT COUNT(*) INTO v_count
        FROM public.employees e
        WHERE e.store_id = v_emp.store_id 
          AND e.is_active = true 
          AND e.id <> p_employee_id
          AND NOT EXISTS (
              SELECT 1 FROM public.admin_profiles ap 
              WHERE ap.id = e.id
          );

        IF v_count >= 5 THEN
            RAISE EXCEPTION 'LIMIT_REACHED: Límite de 5 empleados activos alcanzado para la tienda'
                USING ERRCODE = 'P0001';
        END IF;
    END IF;

    -- 5. Si se va a desactivar, revocar de inmediato cualquier pase diario aprobado hoy
    IF p_new_status IS FALSE THEN
        UPDATE public.daily_passes
        SET status = 'rejected',
            resolved_at = now(),
            resolved_by = auth.uid(),
            updated_at = now()
        WHERE employee_id = p_employee_id
          AND pass_date = v_today
          AND status = 'approved';
    END IF;

    -- 6. Actualizar estado
    UPDATE public.employees
    SET is_active = p_new_status,
        updated_at = now()
    WHERE id = p_employee_id;

    -- 7. Registro de auditoría
    INSERT INTO public.audit_logs (
        actor_id, event_type, resource_id, metadata, store_id, severity
    ) VALUES (
        auth.uid(),
        'EMPLOYEE_STATUS_CHANGED',
        p_employee_id::text,
        jsonb_build_object(
            'is_active', p_new_status,
            'previous_status', v_emp.is_active
        ),
        v_emp.store_id,
        'warning'
    );

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object('new_status', p_new_status)
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

-- 6. RPC: rpc_procesar_venta_v3 (Soporte Offline, Idempotencia ampliada y Precio Histórico)
DROP FUNCTION IF EXISTS public.rpc_procesar_venta_v3(UUID, UUID, TEXT, NUMERIC, JSONB, UUID, TEXT);
CREATE OR REPLACE FUNCTION public.rpc_procesar_venta_v3(
    p_store_id UUID,
    p_client_id UUID,
    p_payment_method TEXT,
    p_amount_received NUMERIC,
    p_items JSONB,
    p_idempotency_key UUID DEFAULT NULL,
    p_local_id TEXT DEFAULT NULL,
    p_is_offline_sync BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_sale_id UUID;
    v_ticket_number INTEGER;
    v_total_calculated NUMERIC := 0;
    v_total_raw NUMERIC := 0;
    v_rounding_difference NUMERIC := 0;
    v_change NUMERIC := 0;
    v_item JSONB;
    v_product_id UUID;
    v_quantity NUMERIC;
    v_product_price NUMERIC;
    v_product_cost NUMERIC;
    v_product_name TEXT;
    v_is_weighable BOOLEAN;
    v_item_subtotal NUMERIC;
    v_raw_subtotal NUMERIC;
    v_client_balance NUMERIC;
    v_client_limit NUMERIC;
    v_employee_id UUID;
    v_pm_allows_change BOOLEAN;
    v_batch RECORD;
    v_sale_item_id UUID;
    v_session_id UUID;
    v_session_opened_at TIMESTAMPTZ;
    v_items_count INTEGER := 0;
    v_existing_sale RECORD;
    v_historical_price NUMERIC;
BEGIN
    -- 1. Regla 4: Aislamiento Multi-Tenant obligatorio en instrucción #1
    PERFORM public.assert_store_access(p_store_id);

    -- 2. Resolución de Empleado / Cajero desde sesión
    v_employee_id := public.get_employee_id_from_session();
    IF v_employee_id IS NULL THEN
        IF EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()) THEN
            v_employee_id := auth.uid();
        ELSE
            RAISE EXCEPTION 'Usuario no autorizado para vender (STORE_ACCESS_DENIED)' USING ERRCODE = 'P0001';
        END IF;
    END IF;

    -- 3. Idempotencia: Verificar si la transacción ya fue procesada por idempotency_key o local_id
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id, ticket_number, total, change_given, rounding_difference, payment_method, created_at
        INTO v_existing_sale
        FROM public.sales
        WHERE store_id = p_store_id AND idempotency_key = p_idempotency_key;

        IF FOUND THEN
            SELECT COUNT(*) INTO v_items_count FROM public.sale_items WHERE sale_id = v_existing_sale.id;
            RETURN jsonb_build_object(
                'success', true,
                'code', 'DUPLICATE_RESOLVED',
                'data', jsonb_build_object(
                    'sale_id', v_existing_sale.id,
                    'ticket_number', v_existing_sale.ticket_number,
                    'total', v_existing_sale.total,
                    'rounding_difference', v_existing_sale.rounding_difference,
                    'amount_received', p_amount_received,
                    'change_given', v_existing_sale.change_given,
                    'payment_method', v_existing_sale.payment_method,
                    'items_count', v_items_count,
                    'created_at', v_existing_sale.created_at,
                    'is_idempotent_replay', true,
                    'code', 'DUPLICATE_RESOLVED'
                )
            );
        END IF;
    END IF;

    IF p_local_id IS NOT NULL THEN
        SELECT id, ticket_number, total, change_given, rounding_difference, payment_method, created_at
        INTO v_existing_sale
        FROM public.sales
        WHERE store_id = p_store_id AND local_id = p_local_id;

        IF FOUND THEN
            SELECT COUNT(*) INTO v_items_count FROM public.sale_items WHERE sale_id = v_existing_sale.id;
            RETURN jsonb_build_object(
                'success', true,
                'code', 'DUPLICATE_RESOLVED',
                'data', jsonb_build_object(
                    'sale_id', v_existing_sale.id,
                    'ticket_number', v_existing_sale.ticket_number,
                    'total', v_existing_sale.total,
                    'rounding_difference', v_existing_sale.rounding_difference,
                    'amount_received', p_amount_received,
                    'change_given', v_existing_sale.change_given,
                    'payment_method', v_existing_sale.payment_method,
                    'items_count', v_items_count,
                    'created_at', v_existing_sale.created_at,
                    'is_idempotent_replay', true,
                    'code', 'DUPLICATE_RESOLVED'
                )
            );
        END IF;
    END IF;

    -- 4. Validación de Carrito
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'El carrito no puede estar vacío (EMPTY_CART)' USING ERRCODE = 'P0001';
    END IF;

    IF jsonb_array_length(p_items) > 50 THEN
        RAISE EXCEPTION 'El carrito no puede superar 50 ítems (CART_LIMIT_EXCEEDED)' USING ERRCODE = 'P0001';
    END IF;

    -- 5. Validación de Medio de Pago
    IF p_payment_method NOT IN ('efectivo', 'nequi', 'daviplata', 'fiado', 'bre') THEN
        RAISE EXCEPTION 'Método de pago inválido: % (INVALID_PAYMENT_METHOD)', p_payment_method USING ERRCODE = 'P0001';
    END IF;

    v_pm_allows_change := (p_payment_method = 'efectivo');

    -- 6. Verificación de Turno de Caja (si es de contado)
    IF p_payment_method IN ('efectivo', 'nequi', 'daviplata', 'bre') THEN
        SELECT id, opened_at INTO v_session_id, v_session_opened_at
        FROM public.cash_sessions
        WHERE store_id = p_store_id AND status = 'open'
        ORDER BY opened_at DESC LIMIT 1;

        IF v_session_id IS NULL THEN
            IF p_is_offline_sync THEN
                -- En sincronización diferida offline, enlazar con la última sesión disponible de la tienda
                SELECT id, opened_at INTO v_session_id, v_session_opened_at
                FROM public.cash_sessions
                WHERE store_id = p_store_id
                ORDER BY opened_at DESC LIMIT 1;
            END IF;

            IF v_session_id IS NULL THEN
                RAISE EXCEPTION 'No hay turno de caja abierto (NO_OPEN_CASH_SESSION)' USING ERRCODE = 'P0001';
            END IF;
        END IF;

        IF NOT p_is_offline_sync AND v_session_opened_at < NOW() - INTERVAL '24 hours' THEN
            RAISE EXCEPTION 'El turno de caja ha superado las 24 horas y debe ser cerrado (SHIFT_EXPIRED_24H)' USING ERRCODE = 'P0001';
        END IF;
    END IF;

    -- 7. Generación de Consecutivo Seguro
    SELECT COALESCE(MAX(ticket_number), 0) + 1 INTO v_ticket_number 
    FROM public.sales 
    WHERE store_id = p_store_id;

    -- 8. Inserción de Cabecera Provisional
    INSERT INTO public.sales (
        store_id, ticket_number, employee_id, client_id, total,
        rounding_difference, payment_method, amount_received, change_given,
        sync_status, local_id, idempotency_key
    ) VALUES (
        p_store_id, v_ticket_number, v_employee_id, p_client_id, 0,
        0, p_payment_method, COALESCE(p_amount_received, 0), 0,
        'synced', p_local_id, p_idempotency_key
    ) RETURNING id INTO v_sale_id;

    -- 9. Procesamiento de Ítems (FIFO + Preservación Histórica Offline + Redondeo $50 COP)
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_quantity := (v_item->>'quantity')::NUMERIC;

        IF v_quantity <= 0 THEN
            RAISE EXCEPTION 'Cantidad de producto inválida: % (INVALID_QUANTITY)', v_quantity USING ERRCODE = 'P0001';
        END IF;

        SELECT name, price, cost_price, COALESCE(is_weighable, false)
        INTO v_product_name, v_product_price, v_product_cost, v_is_weighable
        FROM public.products 
        WHERE id = v_product_id AND store_id = p_store_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto no encontrado: % (PRODUCT_NOT_FOUND)', v_product_id USING ERRCODE = 'P0001';
        END IF;

        -- Regla RN-012-04: Si es sincronización offline y viene un precio histórico congelado, honrarlo
        v_historical_price := COALESCE(
            (v_item->>'historical_unit_price')::NUMERIC,
            (v_item->>'unit_price')::NUMERIC
        );
        IF p_is_offline_sync AND v_historical_price IS NOT NULL AND v_historical_price > 0 THEN
            v_product_price := v_historical_price;
        END IF;

        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, subtotal, unit_cost)
        VALUES (v_sale_id, v_product_id, v_quantity, 0, 0, 0)
        RETURNING id INTO v_sale_item_id;

        v_item_subtotal := 0;
        v_raw_subtotal := 0;

        -- Consumo FIFO de lotes
        FOR v_batch IN SELECT * FROM public.consume_stock_fifo(v_product_id, v_quantity)
        LOOP
            v_raw_subtotal := v_raw_subtotal + (v_batch.quantity_taken * COALESCE(v_batch.sale_price, v_product_price, 0));

            INSERT INTO public.sale_item_batches (sale_item_id, batch_id, quantity_consumed, unit_cost, unit_price)
            VALUES (v_sale_item_id, v_batch.batch_id, v_batch.quantity_taken, v_batch.cost_unit, COALESCE(v_batch.sale_price, v_product_price, 0));
        END LOOP;

        -- Redondeo comercial a $50 COP si es pesable (SPEC-010)
        IF v_is_weighable THEN
            v_item_subtotal := FLOOR(v_raw_subtotal / 50.0) * 50;
            v_rounding_difference := v_rounding_difference + (v_raw_subtotal - v_item_subtotal);
        ELSE
            v_item_subtotal := v_raw_subtotal;
        END IF;

        UPDATE public.sale_items
        SET subtotal = v_item_subtotal,
            unit_price = CASE WHEN v_quantity > 0 THEN v_item_subtotal / v_quantity ELSE 0 END,
            unit_cost = COALESCE(v_product_cost, 0)
        WHERE id = v_sale_item_id;

        -- Asentar movimiento de inventario por venta (actualiza kardex)
        INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by)
        VALUES (v_product_id, 'venta', v_quantity, 'Venta #' || v_ticket_number, v_employee_id);

        v_total_calculated := v_total_calculated + v_item_subtotal;
        v_items_count := v_items_count + 1;
    END LOOP;

    -- 10. Validación de Fiado y Cupo de Crédito
    IF p_payment_method = 'fiado' THEN
        IF p_client_id IS NULL THEN
            RAISE EXCEPTION 'Se requiere especificar el cliente para venta a crédito / fiado (CLIENT_REQUIRED)' USING ERRCODE = 'P0001';
        END IF;

        SELECT balance, credit_limit INTO v_client_balance, v_client_limit
        FROM public.clients 
        WHERE id = p_client_id AND store_id = p_store_id 
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Cliente no encontrado (CLIENT_NOT_FOUND)' USING ERRCODE = 'P0001';
        END IF;

        IF (v_client_balance + v_total_calculated) > v_client_limit THEN
            RAISE EXCEPTION 'Cupo de crédito excedido. Disponible: %, Total venta: % (CREDIT_LIMIT_EXCEEDED)', 
                (v_client_limit - v_client_balance), v_total_calculated USING ERRCODE = 'P0001';
        END IF;
    END IF;

    -- 11. Cálculo de Cambio / Vueltas
    IF v_pm_allows_change THEN
        IF p_amount_received < v_total_calculated THEN
            RAISE EXCEPTION 'El monto recibido ($%) es inferior al total a pagar ($%) (INSUFFICIENT_PAYMENT)',
                p_amount_received, v_total_calculated USING ERRCODE = 'P0001';
        END IF;
        v_change := p_amount_received - v_total_calculated;
    ELSE
        v_change := 0;
    END IF;

    -- 12. Actualización Final de la Venta
    UPDATE public.sales
    SET total = v_total_calculated,
        rounding_difference = v_rounding_difference,
        change_given = v_change
    WHERE id = v_sale_id;

    -- 13. Contrapartida Financiera (Caja o Cartera)
    IF p_payment_method IN ('efectivo', 'nequi', 'daviplata', 'bre') THEN
        INSERT INTO public.cash_movements (
            session_id, movement_type, amount, description, sale_id, payment_method, category
        ) VALUES (
            v_session_id, 'ingreso', v_total_calculated, 'Venta #' || v_ticket_number, v_sale_id, p_payment_method, 'venta'
        );
    ELSIF p_payment_method = 'fiado' THEN
        UPDATE public.clients 
        SET balance = balance + v_total_calculated, updated_at = NOW() 
        WHERE id = p_client_id;

        -- new_balance es columna GENERATED ALWAYS en client_ledger
        INSERT INTO public.client_ledger (
            client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by
        ) VALUES (
            p_client_id, p_store_id, v_total_calculated, v_client_balance, v_sale_id, 'venta_fiado', v_employee_id
        );
    END IF;

    -- 14. Respuesta Canónica Exitosa
    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'sale_id', v_sale_id,
            'ticket_number', v_ticket_number,
            'total', v_total_calculated,
            'rounding_difference', v_rounding_difference,
            'amount_received', COALESCE(p_amount_received, v_total_calculated),
            'change_given', v_change,
            'payment_method', p_payment_method,
            'items_count', v_items_count,
            'created_at', NOW()
        )
    );
END;
$function$;

-- 7. Wrapper rpc_procesar_venta_v2 adaptado a V3 con 8 parámetros
CREATE OR REPLACE FUNCTION public.rpc_procesar_venta_v2(
    p_store_id UUID,
    p_client_id UUID,
    p_payment_method TEXT,
    p_amount_received NUMERIC,
    p_items JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_res JSONB;
    v_data JSONB;
BEGIN
    v_res := public.rpc_procesar_venta_v3(
        p_store_id,
        p_client_id,
        p_payment_method,
        p_amount_received,
        p_items,
        NULL,
        NULL,
        false
    );

    v_data := v_res->'data';

    RETURN jsonb_build_object(
        'success', true,
        'sale_id', (v_data->>'sale_id')::UUID,
        'ticket_number', (v_data->>'ticket_number')::INT,
        'total', (v_data->>'total')::NUMERIC,
        'change', (v_data->>'change_given')::NUMERIC,
        'data', v_data
    );
END;
$function$;

-- 8. Otorgamiento de Permisos Base (Regla 8)
GRANT EXECUTE ON FUNCTION public.get_current_store_id() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_employee_id_from_session() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.is_authorized_employee() TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.crear_empleado(UUID, TEXT, TEXT, TEXT, JSONB) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.toggle_empleado_activo(UUID, BOOLEAN) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_procesar_venta_v3(UUID, UUID, TEXT, NUMERIC, JSONB, UUID, TEXT, BOOLEAN) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_procesar_venta_v2(UUID, UUID, TEXT, NUMERIC, JSONB) TO authenticated, anon, service_role;

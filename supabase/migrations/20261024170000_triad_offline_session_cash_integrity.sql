-- ==============================================================================
-- Migración: 20261024170000_triad_offline_session_cash_integrity.sql
-- Módulo: Tríada Offline, Sesiones de Seguridad y Ciclo Contable de Caja
-- Versión: 3.0.0
-- Documentos de Soporte: FRD-012-01, FRD-013 (v2.0), FRD-017 (v4.0), SDD-012, SDD-013, SDD-017
-- Deudas Técnicas Resueltas: D-1 (audit_logs), D-2 (cash_movements), D-6 (rpc_procesar_venta_v3), D-7 (abrir_caja)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. RESOLUCIÓN DE DEUDA D-1: Saneamiento de Restricción Dual en audit_logs
-- Permite que empleados operativos (sin cuenta auth.users) registren eventos de auditoría.
-- ------------------------------------------------------------------------------
ALTER TABLE public.audit_logs DROP CONSTRAINT IF EXISTS fk_audit_user;

-- Asegurar que actor_id referencie a public.employees
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'audit_logs_actor_id_fkey' AND conrelid = 'public.audit_logs'::regclass
    ) THEN
        ALTER TABLE public.audit_logs 
        ADD CONSTRAINT audit_logs_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.employees(id);
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 2. RESOLUCIÓN DE DEUDA D-2: Agregar columna actor_id en cash_movements
-- Registra qué cajero/empleado originó cada movimiento de caja específico.
-- ------------------------------------------------------------------------------
ALTER TABLE public.cash_movements 
ADD COLUMN IF NOT EXISTS actor_id UUID REFERENCES public.employees(id);

CREATE INDEX IF NOT EXISTS idx_cash_movements_actor_id ON public.cash_movements(actor_id);

GRANT ALL ON TABLE public.cash_movements TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.audit_logs TO anon, authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 3. RESOLUCIÓN RN-017-01: Vigencia Unificada de Pase Diario y Cruce de Medianoche
-- get_current_store_id() y get_employee_id_from_session() reconocen el pase de ayer
-- si existe un turno de caja nocturno abierto (< 24h) en la tienda.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_current_store_id()
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  -- 4. Fallback: Buscar en daily_passes
  -- Soporta turnos nocturnos (pass_date = hoy O pass_date = ayer con turno abierto < 24h)
  SELECT store_id INTO v_store_id
  FROM public.daily_passes
  WHERE auth_user_id = auth.uid() 
    AND status = 'approved' 
    AND (
      pass_date = v_today
      OR (
        pass_date = v_today - 1
        AND EXISTS (
          SELECT 1 FROM public.cash_sessions cs
          WHERE cs.store_id = daily_passes.store_id
            AND cs.status = 'open'
            AND cs.opened_at >= (now() - interval '24 hours')
        )
      )
    )
  ORDER BY pass_date DESC
  LIMIT 1;

  RETURN v_store_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_employee_id_from_session()
 RETURNS uuid
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    
    -- Fallback en daily_passes con tolerancia de cruce de medianoche en turno nocturno
    SELECT employee_id INTO v_employee_id
    FROM public.daily_passes
    WHERE auth_user_id = v_user_id
      AND status = 'approved'
      AND (
        pass_date = v_today
        OR (
          pass_date = v_today - 1
          AND EXISTS (
            SELECT 1 FROM public.cash_sessions cs
            WHERE cs.store_id = daily_passes.store_id
              AND cs.status = 'open'
              AND cs.opened_at >= (now() - interval '24 hours')
          )
        )
      )
    ORDER BY pass_date DESC
    LIMIT 1;
    
    RETURN v_employee_id;
END;
$function$;

-- ------------------------------------------------------------------------------
-- 4. RESOLUCIÓN DE DEUDA D-7: Compuerta de Seguridad en abrir_caja
-- Impide la apertura de una nueva caja si existe un turno cerrado forzosamente
-- sin reconciliar (forced_close = true AND actual_balance IS NULL).
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.abrir_caja(p_store_id uuid, p_employee_id uuid, p_opening_balance numeric)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_existing_session UUID;
  v_session_id UUID;
BEGIN
  -- 1. Regla 4: Aislamiento Multi-Tenant obligatorio en instrucción #1
  PERFORM public.assert_store_access(p_store_id);

  -- 2. Validación de apertura positiva o cero
  IF p_opening_balance IS NULL OR p_opening_balance < 0 THEN
    RAISE EXCEPTION 'INVALID_OPENING_BALANCE: El monto de apertura debe ser mayor o igual a cero.'
      USING ERRCODE = '22023';
  END IF;

  -- 3. Deuda D-7 / RN-017-03: Bloquear si existe turno cerrado forzosamente pendiente de reconciliación
  IF EXISTS (
    SELECT 1 FROM public.cash_sessions
    WHERE store_id = p_store_id
      AND status = 'closed'
      AND COALESCE(forced_close, false) = true
      AND actual_balance IS NULL
  ) THEN
    RAISE EXCEPTION 'RECONCILIATION_REQUIRED: Existe un turno cerrado forzosamente pendiente de reconciliación. Debe reconciliarlo antes de abrir un nuevo turno.'
      USING ERRCODE = 'P0001';
  END IF;

  -- 4. Verificar que no haya otra sesión ya abierta
  SELECT id INTO v_existing_session
  FROM public.cash_sessions
  WHERE store_id = p_store_id AND status = 'open';
  
  IF FOUND THEN
    RAISE EXCEPTION 'CASH_ALREADY_OPEN: Ya existe una caja abierta en esta tienda.'
      USING ERRCODE = 'P0001';
  END IF;
  
  -- 5. Crear nueva sesión
  INSERT INTO public.cash_sessions (store_id, opened_by, opening_balance, status, opened_at, forced_close)
  VALUES (p_store_id, p_employee_id, p_opening_balance, 'open', NOW(), false)
  RETURNING id INTO v_session_id;
  
  RETURN json_build_object(
    'success', true,
    'session_id', v_session_id
  );
END;
$function$;

-- ------------------------------------------------------------------------------
-- 5. AJUSTE EN rpc_reconciliar_cierre_forzado: Remoción de traba auth.users
-- Permite que un empleado con permiso canOpenCloseCash reconcilie sin exigir cuenta auth.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_reconciliar_cierre_forzado(p_session_id uuid, p_employee_id uuid, p_actual_balance numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_session     public.cash_sessions%ROWTYPE;
    v_permissions JSONB;
    v_role        TEXT;
    v_difference  NUMERIC;
BEGIN
    IF p_actual_balance IS NULL OR p_actual_balance < 0 THEN
        RAISE EXCEPTION 'INVALID_BALANCE: El balance real debe ser mayor o igual a cero.'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_session
    FROM public.cash_sessions
    WHERE id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'SESSION_NOT_FOUND: La sesión de caja (%) no existe.', p_session_id
            USING ERRCODE = 'P0002';
    END IF;

    PERFORM public.assert_store_access(v_session.store_id);

    SELECT e.permissions INTO v_permissions
    FROM public.employees e
    WHERE e.id = p_employee_id
      AND e.store_id = v_session.store_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'EMPLOYEE_NOT_FOUND: El empleado no existe en la tienda de la sesión.'
            USING ERRCODE = 'P0002';
    END IF;

    SELECT ap.role INTO v_role
    FROM public.admin_profiles ap
    WHERE ap.id = auth.uid()
      AND ap.store_id = v_session.store_id;

    IF (v_role IS NULL OR v_role NOT IN ('admin', 'owner'))
       AND NOT COALESCE((v_permissions ->> 'canOpenCloseCash')::boolean, false) THEN
        RAISE EXCEPTION 'INSUFFICIENT_PERMISSIONS: Sin permiso para reconciliar cierres de caja.'
            USING ERRCODE = 'P0001';
    END IF;

    IF v_session.status <> 'closed'
       OR COALESCE(v_session.forced_close, false) = false
       OR v_session.actual_balance IS NOT NULL THEN
        RAISE EXCEPTION 'SESSION_NOT_RECONCILABLE: La sesión no fue cerrada forzosamente o ya fue reconciliada.'
            USING ERRCODE = 'P0001';
    END IF;

    v_difference := p_actual_balance - v_session.expected_balance;

    UPDATE public.cash_sessions
    SET actual_balance = p_actual_balance,
        difference     = v_difference,
        closed_by      = p_employee_id
    WHERE id = p_session_id;

    -- Asentamiento en bitácora inmutable usando las columnas reales de audit_logs
    INSERT INTO public.audit_logs (
        actor_id, store_id, event_type, resource_id, metadata, severity, created_at
    ) VALUES (
        p_employee_id,
        v_session.store_id,
        'FORCED_CLOSE_RECONCILED',
        p_session_id::text,
        jsonb_build_object(
            'reconciled_by',    p_employee_id,
            'actual_balance',   p_actual_balance,
            'expected_balance', v_session.expected_balance,
            'difference',       v_difference,
            'reconciled_at',    NOW()
        ),
        CASE WHEN v_difference = 0 THEN 'info' ELSE 'warning' END,
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'session_id',       p_session_id,
            'expected_balance', v_session.expected_balance,
            'actual_balance',   p_actual_balance,
            'difference',       v_difference
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$function$;

-- ------------------------------------------------------------------------------
-- 6. RESOLUCIÓN DE DEUDA D-6: rpc_procesar_venta_v3 con Firma Extendida e Imputación
-- Añade p_origin_session_id y p_sold_by con DEFAULT NULL.
-- Si es offline_sync y la sesión histórica está cerrada, asienta en ella,
-- recalcula expected_balance y genera evento LATE_SYNC_UPDATE en audit_logs.
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.rpc_procesar_venta_v3(uuid, uuid, text, numeric, jsonb, uuid, text, boolean);

CREATE OR REPLACE FUNCTION public.rpc_procesar_venta_v3(
    p_store_id uuid,
    p_client_id uuid,
    p_payment_method text,
    p_amount_received numeric,
    p_items jsonb,
    p_idempotency_key uuid DEFAULT NULL::uuid,
    p_local_id text DEFAULT NULL::text,
    p_is_offline_sync boolean DEFAULT false,
    p_origin_session_id uuid DEFAULT NULL::uuid,
    p_sold_by uuid DEFAULT NULL::uuid
)
 RETURNS jsonb
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
    v_session_status TEXT;
    v_session_opened_at TIMESTAMPTZ;
    v_items_count INTEGER := 0;
    v_existing_sale RECORD;
    v_historical_price NUMERIC;
    v_is_late_sync BOOLEAN := false;
BEGIN
    -- 1. Regla 4: Aislamiento Multi-Tenant obligatorio en instrucción #1
    PERFORM public.assert_store_access(p_store_id);

    -- 2. Resolución de Empleado / Cajero
    IF p_is_offline_sync AND p_sold_by IS NOT NULL THEN
        -- Si viene de sincronización diferida y el empleado existe en la tienda, honrar autoría original
        IF EXISTS (SELECT 1 FROM public.employees WHERE id = p_sold_by AND store_id = p_store_id) THEN
            v_employee_id := p_sold_by;
        END IF;
    END IF;

    IF v_employee_id IS NULL THEN
        v_employee_id := public.get_employee_id_from_session();
    END IF;

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
        IF p_is_offline_sync AND p_origin_session_id IS NOT NULL THEN
            -- Intentar anclar a la sesión de origen histórica
            SELECT id, status, opened_at INTO v_session_id, v_session_status, v_session_opened_at
            FROM public.cash_sessions
            WHERE id = p_origin_session_id AND store_id = p_store_id;

            IF v_session_id IS NOT NULL AND v_session_status = 'closed' THEN
                v_is_late_sync := true;
            END IF;
        END IF;

        IF v_session_id IS NULL THEN
            SELECT id, status, opened_at INTO v_session_id, v_session_status, v_session_opened_at
            FROM public.cash_sessions
            WHERE store_id = p_store_id AND status = 'open'
            ORDER BY opened_at DESC LIMIT 1;
        END IF;

        IF v_session_id IS NULL THEN
            IF p_is_offline_sync THEN
                -- En sincronización diferida offline sin sesión abierta, enlazar con la última sesión registrada
                SELECT id, status, opened_at INTO v_session_id, v_session_status, v_session_opened_at
                FROM public.cash_sessions
                WHERE store_id = p_store_id
                ORDER BY opened_at DESC LIMIT 1;

                IF v_session_id IS NOT NULL AND v_session_status = 'closed' THEN
                    v_is_late_sync := true;
                END IF;
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

    -- 13. Contrapartida Financiera (Caja o Cartera) con Trazabilidad actor_id
    IF p_payment_method IN ('efectivo', 'nequi', 'daviplata', 'bre') THEN
        INSERT INTO public.cash_movements (
            session_id, movement_type, amount, description, sale_id, payment_method, category, actor_id
        ) VALUES (
            v_session_id, 'ingreso', v_total_calculated, 'Venta #' || v_ticket_number, v_sale_id, p_payment_method, 'venta', v_employee_id
        );

        -- Imputación contable a sesión cerrada si fue sincronización tardía (Deuda D-6)
        IF v_is_late_sync THEN
            IF p_payment_method = 'efectivo' THEN
                UPDATE public.cash_sessions
                SET expected_balance = COALESCE(expected_balance, 0) + v_total_calculated
                WHERE id = v_session_id;
            END IF;

            INSERT INTO public.audit_logs (
                actor_id, store_id, event_type, resource_id, metadata, severity, created_at
            ) VALUES (
                v_employee_id,
                p_store_id,
                'LATE_SYNC_UPDATE',
                v_sale_id::text,
                jsonb_build_object(
                    'session_id', v_session_id,
                    'sale_id', v_sale_id,
                    'ticket_number', v_ticket_number,
                    'amount', v_total_calculated,
                    'payment_method', p_payment_method,
                    'local_id', p_local_id,
                    'reason', 'Venta offline imputada a turno cerrado histórico'
                ),
                'warning',
                NOW()
            );
        END IF;
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

-- ------------------------------------------------------------------------------
-- 7. ASIGNACIÓN UNIVERSAL DE PRIVILEGIOS (Regla 8 AGENTS.md)
-- ------------------------------------------------------------------------------
GRANT ALL ON FUNCTION public.get_current_store_id() TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.get_employee_id_from_session() TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.abrir_caja(uuid, uuid, numeric) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.rpc_reconciliar_cierre_forzado(uuid, uuid, numeric) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.rpc_procesar_venta_v3(uuid, uuid, text, numeric, jsonb, uuid, text, boolean, uuid, uuid) TO anon, authenticated, service_role;

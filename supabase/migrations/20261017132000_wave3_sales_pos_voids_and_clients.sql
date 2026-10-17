-- Migration: 20261017132000_wave3_sales_pos_voids_and_clients.sql
-- Description: Wave 3 - Ventas POS v3, Idempotencia, Anulaciones Multicanal, Venta Forzada y Clientes/Fiados
-- SDDs Certified: SDD_007_NUCLEO_VENTAS_PADRE, SDD_007_01_NUCLEO_POS, SDD_007_02_TICKET_DE_VENTA, SDD_009_CLIENTES, SDD_014_VENTA_FORZADA_Y_AUDITORIA, SDD_024_POLITICA_FIADOS

-- 1. Modificación de esquema en public.sales
ALTER TABLE public.sales 
    ADD COLUMN IF NOT EXISTS idempotency_key UUID,
    ADD COLUMN IF NOT EXISTS void_session_id UUID REFERENCES public.cash_sessions(id),
    ADD COLUMN IF NOT EXISTS voided_at TIMESTAMPTZ;

-- Actualizar sales_payment_method_check para incluir 'bre'
ALTER TABLE public.sales DROP CONSTRAINT IF EXISTS sales_payment_method_check;
ALTER TABLE public.sales ADD CONSTRAINT sales_payment_method_check 
    CHECK (payment_method IN ('efectivo', 'nequi', 'daviplata', 'fiado', 'bre'));

-- Índice parcial único para idempotency_key por tienda
CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_store_idempotency_key 
    ON public.sales (store_id, idempotency_key) 
    WHERE idempotency_key IS NOT NULL;

-- 2. Privilegios base en tablas de ventas y clientes (Regla 8)
GRANT ALL ON TABLE public.sales TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.sale_items TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.clients TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.client_ledger TO anon, authenticated, service_role;

-- Limpieza preventiva de firmas anteriores
DROP FUNCTION IF EXISTS public.rpc_force_sale(UUID, UUID, TEXT, JSONB, TEXT);
DROP FUNCTION IF EXISTS public.rpc_force_sale(UUID, UUID, TEXT, JSONB, TEXT, NUMERIC);
DROP FUNCTION IF EXISTS public.rpc_anular_venta(UUID, TEXT);
DROP FUNCTION IF EXISTS public.registrar_abono(UUID, NUMERIC);
DROP FUNCTION IF EXISTS public.rpc_registrar_abono(UUID, NUMERIC, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.get_sale_detail(UUID);
DROP FUNCTION IF EXISTS public.rpc_procesar_venta_v3(UUID, UUID, TEXT, NUMERIC, JSONB, UUID, TEXT);

-- 3. rpc_procesar_venta_v3 (Contrato Canónico POS Atómico)
CREATE OR REPLACE FUNCTION public.rpc_procesar_venta_v3(
    p_store_id UUID,
    p_client_id UUID,
    p_payment_method TEXT,
    p_amount_received NUMERIC,
    p_items JSONB,
    p_idempotency_key UUID DEFAULT NULL,
    p_local_id TEXT DEFAULT NULL
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

    -- 3. Idempotencia: Verificar si la transacción ya fue procesada previamente
    IF p_idempotency_key IS NOT NULL THEN
        SELECT id, ticket_number, total, change_given, rounding_difference, payment_method, created_at
        INTO v_existing_sale
        FROM public.sales
        WHERE store_id = p_store_id AND idempotency_key = p_idempotency_key;

        IF FOUND THEN
            SELECT COUNT(*) INTO v_items_count FROM public.sale_items WHERE sale_id = v_existing_sale.id;
            RETURN jsonb_build_object(
                'success', true,
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
                    'is_idempotent_replay', true
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

    -- 6. Verificación de Turno de Caja (si es de contado: efectivo, nequi, daviplata, bre)
    IF p_payment_method IN ('efectivo', 'nequi', 'daviplata', 'bre') THEN
        SELECT id, opened_at INTO v_session_id, v_session_opened_at
        FROM public.cash_sessions
        WHERE store_id = p_store_id AND status = 'open'
        ORDER BY opened_at DESC LIMIT 1;

        IF v_session_id IS NULL THEN
            RAISE EXCEPTION 'No hay turno de caja abierto (NO_OPEN_CASH_SESSION)' USING ERRCODE = 'P0001';
        END IF;

        IF v_session_opened_at < NOW() - INTERVAL '24 hours' THEN
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

    -- 9. Procesamiento de Ítems (FIFO + Redondeo $50 COP)
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

        -- Deuda D-4: new_balance es GENERATED ALWAYS, NO incluir en INSERT
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

-- 4. rpc_procesar_venta_v2 (Capa de Compatibilidad Retroactiva)
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
        NULL
    );

    v_data := v_res->'data';

    -- Retorna envoltorio compatible tanto con legacy (raíz plana) como canónico (data)
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

-- 5. rpc_force_sale (Venta Forzada con Auto-corrección e Inyección de Lote Técnico)
CREATE OR REPLACE FUNCTION public.rpc_force_sale(
    p_store_id UUID,
    p_client_id UUID,
    p_payment_method TEXT,
    p_items JSONB,
    p_justification TEXT,
    p_amount_received NUMERIC DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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
    v_employee_id UUID;
    v_data JSONB;
BEGIN
    -- 1. Regla 4: Aislamiento de Tienda
    PERFORM public.assert_store_access(p_store_id);

    -- 2. Validación de Rol Administrativo (RN-014-01)
    SELECT role INTO v_role 
    FROM public.admin_profiles 
    WHERE id = auth.uid() AND store_id = p_store_id;

    IF v_role IS NULL OR v_role NOT IN ('admin', 'owner') THEN
        RAISE EXCEPTION 'Access Denied: Se requiere rol de Administrador para forzar ventas (STORE_ACCESS_DENIED)' USING ERRCODE = 'P0001';
    END IF;

    -- 3. Justificación Forense Obligatoria (RN-014-02)
    IF length(trim(COALESCE(p_justification, ''))) < 10 THEN
        RAISE EXCEPTION 'La justificación forense debe tener al menos 10 caracteres legibles (JUSTIFICATION_TOO_SHORT)' USING ERRCODE = 'P0001';
    END IF;

    v_employee_id := public.get_employee_id_from_session();
    IF v_employee_id IS NULL THEN
        v_employee_id := auth.uid();
    END IF;

    -- 4. Agrupar por product_id para evaluar déficit pesimista
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
        
        SELECT current_stock INTO v_current_stock 
        FROM public.products 
        WHERE id = v_product_id AND store_id = p_store_id 
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto no encontrado: % (PRODUCT_NOT_FOUND)', v_product_id USING ERRCODE = 'P0001';
        END IF;

        v_deficit := v_qty - COALESCE(v_current_stock, 0);
        
        IF v_deficit > 0 THEN
            -- Inyección de lote técnico de autocorrección (RN-014-03, RN-014-04: supplier_id = NULL)
            INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by)
            VALUES (v_product_id, 'CORRECCION_SISTEMA', v_deficit, 'AUTO-CORRECCION: ' || p_justification, v_employee_id);
            
            v_affected_count := v_affected_count + 1;
        END IF;
    END LOOP;

    -- 5. Procesamiento Transaccional Ordinario mediante V3 (RN-014-06)
    v_sale_result := public.rpc_procesar_venta_v3(
        p_store_id,
        p_client_id,
        p_payment_method,
        p_amount_received,
        p_items,
        NULL,
        NULL
    );

    v_data := v_sale_result->'data';
    v_sale_id := (v_data->>'sale_id')::UUID;

    -- 6. Asentamiento Forense en audit_logs (RN-014-07)
    INSERT INTO public.audit_logs (store_id, actor_id, event_type, resource_id, metadata, severity)
    VALUES (
        p_store_id,
        auth.uid(),
        'FORCE_SALE',
        v_sale_id::TEXT,
        jsonb_build_object(
            'reason', p_justification,
            'items_adjusted', v_affected_count,
            'original_items', p_items,
            'status', 'pending'
        ),
        'warning'
    );

    RETURN jsonb_build_object(
        'success', true,
        'sale_id', v_sale_id,
        'adjusted_items', v_affected_count,
        'data', jsonb_build_object(
            'sale_id', v_sale_id,
            'ticket_number', (v_data->>'ticket_number')::INT,
            'total', (v_data->>'total')::NUMERIC,
            'change_given', (v_data->>'change_given')::NUMERIC,
            'payment_method', p_payment_method,
            'adjusted_items', v_affected_count,
            'audit_logged', true,
            'created_at', NOW()
        )
    );
END;
$function$;

-- 6. rpc_anular_venta (Anulación Contable, Multicanal y Reversión de Lotes)
CREATE OR REPLACE FUNCTION public.rpc_anular_venta(p_sale_id UUID, p_reason TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_sale RECORD;
    v_item RECORD;
    v_role TEXT;
    v_employee_id UUID;
    v_session_id UUID;
    v_session_opened_at TIMESTAMPTZ;
    v_client_balance NUMERIC;
    v_opening NUMERIC := 0;
    v_ingresos NUMERIC := 0;
    v_egresos NUMERIC := 0;
    v_available NUMERIC := 0;
BEGIN
    -- 1. Obtener Venta
    SELECT * INTO v_sale FROM public.sales WHERE id = p_sale_id FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venta no encontrada (SALE_NOT_FOUND)' USING ERRCODE = 'P0001';
    END IF;

    -- 2. Regla 4: Aislamiento Multi-Tenant
    PERFORM public.assert_store_access(v_sale.store_id);

    -- 3. Validación de Rol Administrativo (Solo Admin/Owner puede anular)
    SELECT role INTO v_role 
    FROM public.admin_profiles 
    WHERE id = auth.uid() AND store_id = v_sale.store_id;

    IF v_role IS NULL OR v_role NOT IN ('admin', 'owner') THEN
        RAISE EXCEPTION 'Solo administradores pueden anular ventas (UNAUTHORIZED)' USING ERRCODE = 'P0001';
    END IF;

    -- 4. Validación de Motivo (mínimo 10 caracteres)
    IF length(trim(COALESCE(p_reason, ''))) < 10 THEN
        RAISE EXCEPTION 'El motivo de anulación debe tener al menos 10 caracteres (REASON_TOO_SHORT)' USING ERRCODE = 'P0001';
    END IF;

    -- 5. Validar si ya está anulada
    IF v_sale.is_voided THEN
        RAISE EXCEPTION 'Esta venta ya fue anulada previamente (SALE_ALREADY_VOIDED)' USING ERRCODE = 'P0001';
    END IF;

    v_employee_id := public.get_employee_id_from_session();
    IF v_employee_id IS NULL THEN
        v_employee_id := auth.uid();
    END IF;

    -- 6. Reversión Financiera Multicanal
    IF v_sale.payment_method IN ('efectivo', 'nequi', 'daviplata', 'bre') THEN
        -- Requiere sesión de caja activa
        SELECT id, opened_at INTO v_session_id, v_session_opened_at
        FROM public.cash_sessions
        WHERE store_id = v_sale.store_id AND status = 'open'
        ORDER BY opened_at DESC LIMIT 1;

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
        WHERE session_id = v_session_id AND payment_method = v_sale.payment_method AND movement_type = 'gasto';

        v_available := (v_opening + v_ingresos) - v_egresos;

        IF v_available < v_sale.total THEN
            RAISE EXCEPTION 'Fondos insuficientes en canal % para revertir la venta (disponible: %, requerido: %) (INSUFFICIENT_CHANNEL_FUNDS)',
                v_sale.payment_method, v_available, v_sale.total USING ERRCODE = 'P0001';
        END IF;

        -- Registrar salida de dinero
        INSERT INTO public.cash_movements (
            session_id, movement_type, amount, description, sale_id, payment_method, category
        ) VALUES (
            v_session_id, 'gasto', v_sale.total, '[ANULACION_VENTA #' || v_sale.ticket_number || '] ' || p_reason, p_sale_id, v_sale.payment_method, 'anulacion_venta'
        );

    ELSIF v_sale.payment_method = 'fiado' AND v_sale.client_id IS NOT NULL THEN
        -- Revertir deuda del cliente
        SELECT balance INTO v_client_balance 
        FROM public.clients 
        WHERE id = v_sale.client_id 
        FOR UPDATE;

        UPDATE public.clients 
        SET balance = balance - v_sale.total, updated_at = NOW() 
        WHERE id = v_sale.client_id;

        -- Deuda D-4: new_balance es GENERATED ALWAYS, NO incluir en INSERT
        INSERT INTO public.client_ledger (
            client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by
        ) VALUES (
            v_sale.client_id, v_sale.store_id, -v_sale.total, v_client_balance, p_sale_id, 'anulacion_fiado', v_employee_id
        );
    END IF;

    -- 7. Reversión Logística (Reingreso de existencias por lote técnico)
    FOR v_item IN SELECT * FROM public.sale_items WHERE sale_id = p_sale_id LOOP
        INSERT INTO public.inventory_movements (
            product_id, movement_type, quantity, reason, created_by
        ) VALUES (
            v_item.product_id,
            'CORRECCION_SISTEMA',
            v_item.quantity,
            'ANULACION VENTA #' || v_sale.ticket_number || ': ' || p_reason,
            v_employee_id
        );
    END LOOP;

    -- 8. Sellado Inmutable de la Venta
    UPDATE public.sales
    SET is_voided = true,
        void_reason = p_reason,
        voided_by = v_employee_id,
        void_session_id = v_session_id,
        voided_at = NOW()
    WHERE id = p_sale_id;

    -- 9. Registro de Auditoría
    INSERT INTO public.audit_logs (store_id, actor_id, event_type, resource_id, metadata, severity)
    VALUES (
        v_sale.store_id,
        auth.uid(),
        'SALE_VOIDED',
        p_sale_id::TEXT,
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

-- 7. rpc_registrar_abono (Abono a Cartera y Asiento de Ingreso Multicanal en Caja)
CREATE OR REPLACE FUNCTION public.rpc_registrar_abono(
    p_client_id UUID,
    p_amount NUMERIC,
    p_payment_method TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_client RECORD;
    v_employee_id UUID;
    v_session_id UUID;
    v_session_opened_at TIMESTAMPTZ;
    v_new_balance NUMERIC;
    v_cash_movement_id UUID;
    v_ledger_id UUID;
BEGIN
    -- 1. Validar Monto
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'El monto del abono debe ser mayor a cero (INVALID_AMOUNT)' USING ERRCODE = 'P0001';
    END IF;

    -- 2. Validar Cliente
    SELECT * INTO v_client 
    FROM public.clients 
    WHERE id = p_client_id 
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cliente no encontrado (CLIENT_NOT_FOUND)' USING ERRCODE = 'P0001';
    END IF;

    -- 3. Regla 4: Aislamiento Multi-Tenant
    PERFORM public.assert_store_access(v_client.store_id);

    -- 4. Validar Método de Pago
    IF p_payment_method NOT IN ('efectivo', 'nequi', 'daviplata', 'bre') THEN
        RAISE EXCEPTION 'Método de pago no válido para abono: % (INVALID_PAYMENT_METHOD)', p_payment_method USING ERRCODE = 'P0001';
    END IF;

    -- 5. Validar Deuda Pendiente
    IF v_client.balance <= 0 THEN
        RAISE EXCEPTION 'El cliente no tiene saldo deudor pendiente (NO_OUTSTANDING_DEBT)' USING ERRCODE = 'P0001';
    END IF;

    IF p_amount > v_client.balance THEN
        RAISE EXCEPTION 'El abono ($%) supera la deuda actual ($%) (AMOUNT_EXCEEDS_DEBT)', 
            p_amount, v_client.balance USING ERRCODE = 'P0001';
    END IF;

    -- 6. Validar Turno de Caja Abierto
    SELECT id, opened_at INTO v_session_id, v_session_opened_at
    FROM public.cash_sessions
    WHERE store_id = v_client.store_id AND status = 'open'
    ORDER BY opened_at DESC LIMIT 1;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION 'No hay turno de caja abierto para registrar el abono (NO_OPEN_CASH_SESSION)' USING ERRCODE = 'P0001';
    END IF;

    IF v_session_opened_at < NOW() - INTERVAL '24 hours' THEN
        RAISE EXCEPTION 'El turno de caja ha superado las 24 horas y debe ser cerrado (SHIFT_EXPIRED_24H)' USING ERRCODE = 'P0001';
    END IF;

    v_employee_id := public.get_employee_id_from_session();
    IF v_employee_id IS NULL THEN
        v_employee_id := auth.uid();
    END IF;

    -- 7. Actualizar Saldo del Cliente
    v_new_balance := v_client.balance - p_amount;
    UPDATE public.clients 
    SET balance = v_new_balance, updated_at = NOW() 
    WHERE id = p_client_id;

    -- 8. Asentar en Cartera (Deuda D-4: new_balance es GENERATED ALWAYS)
    INSERT INTO public.client_ledger (
        client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by
    ) VALUES (
        p_client_id, v_client.store_id, -p_amount, v_client.balance, NULL, 'abono', v_employee_id
    ) RETURNING id INTO v_ledger_id;

    -- 9. Asentar Ingreso Multicanal en Caja Abierta
    INSERT INTO public.cash_movements (
        session_id, movement_type, amount, description, payment_method, category
    ) VALUES (
        v_session_id, 'ingreso', p_amount, '[ABONO_CLIENTE: ' || v_client.name || '] ' || COALESCE(p_notes, ''), p_payment_method, 'abono_cliente'
    ) RETURNING id INTO v_cash_movement_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'client_id', p_client_id,
            'previous_balance', v_client.balance,
            'amount_paid', p_amount,
            'new_balance', v_new_balance,
            'payment_method', p_payment_method,
            'cash_movement_id', v_cash_movement_id,
            'session_id', v_session_id,
            'ledger_id', v_ledger_id,
            'created_at', NOW()
        )
    );
END;
$function$;

-- Alias retrocompatible para registrar_abono
CREATE OR REPLACE FUNCTION public.registrar_abono(p_client_id UUID, p_amount NUMERIC)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_res JSONB;
BEGIN
    v_res := public.rpc_registrar_abono(p_client_id, p_amount, 'efectivo', 'Abono registrado vía endpoint legacy');
    RETURN (v_res)::JSON;
END;
$function$;

-- 8. rpc_admin_get_clients (Consulta Administrativa Filtrada con Conteo Oficial)
CREATE OR REPLACE FUNCTION public.rpc_admin_get_clients(
    p_store_id UUID,
    p_filter_debt TEXT DEFAULT 'todos',
    p_include_deleted BOOLEAN DEFAULT false,
    p_search_query TEXT DEFAULT NULL,
    p_order_by TEXT DEFAULT 'name_asc',
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_total_count INTEGER;
    v_clients JSONB;
BEGIN
    -- 1. Regla 4: Aislamiento Multi-Tenant
    PERFORM public.assert_store_access(p_store_id);

    -- 2. Conteo de Total de Registros para Paginación (Sección 4.1 de Reglas Globales)
    SELECT COUNT(*) INTO v_total_count
    FROM public.clients c
    WHERE c.store_id = p_store_id
      AND (p_include_deleted = true OR c.is_deleted = false)
      AND (
          p_filter_debt = 'todos' OR
          (p_filter_debt = 'con_deuda' AND c.balance > 0) OR
          (p_filter_debt = 'sin_deuda' AND c.balance <= 0)
      )
      AND (
          p_search_query IS NULL OR
          c.name ILIKE '%' || p_search_query || '%' OR
          c.id_number ILIKE '%' || p_search_query || '%' OR
          c.phone ILIKE '%' || p_search_query || '%'
      );

    -- 3. Obtención Paginada y Mapeada
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', c.id,
            'name', c.name,
            'id_number', c.id_number,
            'phone', c.phone,
            'credit_limit', c.credit_limit,
            'balance', c.balance,
            'credit_available', GREATEST(0, c.credit_limit - c.balance),
            'credit_usage_pct', CASE WHEN c.credit_limit > 0 THEN ROUND((c.balance / c.credit_limit) * 100, 1) ELSE 0 END,
            'is_deleted', c.is_deleted,
            'deleted_at', c.deleted_at,
            'created_at', c.created_at
        ) ORDER BY
            CASE WHEN p_order_by = 'balance_desc' THEN c.balance END DESC NULLS LAST,
            CASE WHEN p_order_by = 'balance_asc' THEN c.balance END ASC NULLS LAST,
            CASE WHEN p_order_by = 'name_asc' THEN c.name END ASC,
            CASE WHEN p_order_by = 'name_desc' THEN c.name END DESC,
            c.created_at DESC
    ), '[]'::jsonb)
    INTO v_clients
    FROM (
        SELECT *
        FROM public.clients c
        WHERE c.store_id = p_store_id
          AND (p_include_deleted = true OR c.is_deleted = false)
          AND (
              p_filter_debt = 'todos' OR
              (p_filter_debt = 'con_deuda' AND c.balance > 0) OR
              (p_filter_debt = 'sin_deuda' AND c.balance <= 0)
          )
          AND (
              p_search_query IS NULL OR
              c.name ILIKE '%' || p_search_query || '%' OR
              c.id_number ILIKE '%' || p_search_query || '%' OR
              c.phone ILIKE '%' || p_search_query || '%'
          )
        ORDER BY
            CASE WHEN p_order_by = 'balance_desc' THEN c.balance END DESC NULLS LAST,
            CASE WHEN p_order_by = 'balance_asc' THEN c.balance END ASC NULLS LAST,
            CASE WHEN p_order_by = 'name_asc' THEN c.name END ASC,
            CASE WHEN p_order_by = 'name_desc' THEN c.name END DESC,
            c.created_at DESC
        LIMIT p_limit OFFSET p_offset
    ) c;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_clients,
        'count', v_total_count
    );
END;
$function$;

-- 9. get_sale_detail (Enriquecimiento Canónico con rounding_difference y void_session_id)
CREATE OR REPLACE FUNCTION public.get_sale_detail(p_sale_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_sale RECORD;
    v_items JSONB;
BEGIN
    SELECT
        s.id, s.store_id, s.ticket_number, s.total, s.rounding_difference,
        s.payment_method, s.amount_received, s.change_given,
        s.is_voided, s.void_reason, s.void_session_id, s.voided_at, s.created_at,
        COALESCE(e.name, 'Administrador') AS employee_name,
        c.name AS client_name
    INTO v_sale
    FROM public.sales s
    LEFT JOIN public.employees e ON e.id = s.employee_id
    LEFT JOIN public.clients c ON c.id = s.client_id
    WHERE s.id = p_sale_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venta no encontrada (SALE_NOT_FOUND)' USING ERRCODE = 'P0001';
    END IF;

    -- Regla 4: Aislamiento Multi-Tenant
    PERFORM public.assert_store_access(v_sale.store_id);

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'product_name', p.name,
            'quantity', si.quantity,
            'unit_price', si.unit_price,
            'subtotal', si.subtotal
        ) ORDER BY si.created_at
    ), '[]'::jsonb)
    INTO v_items
    FROM public.sale_items si
    JOIN public.products p ON p.id = si.product_id
    WHERE si.sale_id = p_sale_id;

    RETURN jsonb_build_object(
        'success', true,
        'ticket_number', v_sale.ticket_number,
        'total', v_sale.total,
        'rounding_difference', COALESCE(v_sale.rounding_difference, 0),
        'payment_method', v_sale.payment_method,
        'amount_received', v_sale.amount_received,
        'change_given', v_sale.change_given,
        'employee_name', v_sale.employee_name,
        'client_name', v_sale.client_name,
        'is_voided', COALESCE(v_sale.is_voided, false),
        'void_reason', v_sale.void_reason,
        'void_session_id', v_sale.void_session_id,
        'voided_at', v_sale.voided_at,
        'created_at', v_sale.created_at,
        'items', v_items,
        'items_count', jsonb_array_length(v_items),
        'data', jsonb_build_object(
            'id', v_sale.id,
            'ticket_number', v_sale.ticket_number,
            'total', v_sale.total,
            'rounding_difference', COALESCE(v_sale.rounding_difference, 0),
            'payment_method', v_sale.payment_method,
            'amount_received', v_sale.amount_received,
            'change_given', v_sale.change_given,
            'employee_name', v_sale.employee_name,
            'client_name', v_sale.client_name,
            'is_voided', COALESCE(v_sale.is_voided, false),
            'void_reason', v_sale.void_reason,
            'void_session_id', v_sale.void_session_id,
            'voided_at', v_sale.voided_at,
            'created_at', v_sale.created_at,
            'items', v_items,
            'items_count', jsonb_array_length(v_items)
        )
    );
END;
$function$;

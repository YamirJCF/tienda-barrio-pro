-- ============================================================================
-- FASE 3 — OLA 4: POS, Retiro Personal ($0), Clientes (canFiar) y CxP Admin-Only
-- Átomos: CHK-401 .. CHK-410
-- SDDs: SDD-007-01, SDD-009, SDD-019, SDD-024, SDD-030 (+ Contrato Marco SDD-003-01)
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. DDL ADITIVO Y CONSTRAINTS VERIFICADOS (CHK-401, CHK-406, CHK-409, CHK-410)
-- ----------------------------------------------------------------------------

-- CHK-401: Beneficiario en sales (nullable; NULL salvo consumo_personal con empleado asignado)
ALTER TABLE public.sales
    ADD COLUMN IF NOT EXISTS beneficiary_employee_id UUID REFERENCES public.employees(id);

-- CHK-401: Campos de trazabilidad operativa para Retiro Personal y futuras salidas $0
ALTER TABLE public.inventory_movements
    ADD COLUMN IF NOT EXISTS session_id UUID REFERENCES public.cash_sessions(id),
    ADD COLUMN IF NOT EXISTS beneficiary_employee_id UUID REFERENCES public.employees(id),
    ADD COLUMN IF NOT EXISTS reference_sale_price NUMERIC;

-- CHK-401: Ampliar CHECK constraint de inventory_movements.movement_type
ALTER TABLE public.inventory_movements
    DROP CONSTRAINT IF EXISTS inventory_movements_movement_type_check;

ALTER TABLE public.inventory_movements
    ADD CONSTRAINT inventory_movements_movement_type_check
    CHECK (
        movement_type IN (
            'entrada',
            'salida',
            'devolucion',
            'merma',
            'ajuste',
            'CORRECCION_SISTEMA',
            'venta',
            'consumo_personal',
            'consumo_negocio',
            'devolucion_proveedor',
            'ajuste_conteo'
        )
    );

-- CHK-406: Cupo global por defecto en stores (NO modifica clientes existentes)
ALTER TABLE public.stores
    ADD COLUMN IF NOT EXISTS default_credit_limit NUMERIC(12,2) NOT NULL DEFAULT 0;

ALTER TABLE public.stores
    DROP CONSTRAINT IF EXISTS stores_default_credit_limit_check;

ALTER TABLE public.stores
    ADD CONSTRAINT stores_default_credit_limit_check
    CHECK (default_credit_limit >= 0);

-- CHK-410: supplier_invoices.due_date pasa a ser nullable
ALTER TABLE public.supplier_invoices
    ALTER COLUMN due_date DROP NOT NULL;

-- CHK-410: Endurecer RLS de supplier_invoices estrictamente a Administrador (is_store_admin)
DROP POLICY IF EXISTS "Users can view invoices from their store" ON public.supplier_invoices;
DROP POLICY IF EXISTS "Admins can manage invoices" ON public.supplier_invoices;
DROP POLICY IF EXISTS "supplier_invoices_admin_only" ON public.supplier_invoices;

CREATE POLICY "supplier_invoices_admin_only"
    ON public.supplier_invoices
    FOR ALL
    USING (public.is_store_admin(store_id))
    WITH CHECK (public.is_store_admin(store_id));

GRANT ALL ON TABLE public.supplier_invoices TO anon, authenticated, service_role;

-- CHK-409: Tabla historial inmutable de pagos a proveedores (INTERNO / EXTERNO)
CREATE TABLE IF NOT EXISTS public.supplier_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    invoice_id UUID NOT NULL REFERENCES public.supplier_invoices(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL REFERENCES public.suppliers(id) ON DELETE RESTRICT,
    amount NUMERIC NOT NULL CHECK (amount > 0),
    payment_method TEXT NOT NULL CHECK (payment_method IN ('efectivo', 'nequi', 'llave_bre', 'externo')),
    origin_type TEXT NOT NULL CHECK (origin_type IN ('EXTERNO', 'INTERNO')),
    cash_movement_id UUID REFERENCES public.cash_movements(id),
    description TEXT,
    actor_id UUID REFERENCES public.employees(id),
    actor_name TEXT NOT NULL,
    actor_role TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_supplier_payments_store_invoice
    ON public.supplier_payments (store_id, invoice_id, created_at DESC);

ALTER TABLE public.supplier_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "supplier_payments_admin_only" ON public.supplier_payments;
CREATE POLICY "supplier_payments_admin_only"
    ON public.supplier_payments
    FOR ALL
    USING (public.is_store_admin(store_id))
    WITH CHECK (public.is_store_admin(store_id));

-- Regla 8 obligatoria en tabla nueva
GRANT ALL ON TABLE public.supplier_payments TO anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 2. RPC VENTAS Y RETIRO PERSONAL ($0): rpc_procesar_venta_v3 (CHK-401, CHK-403, CHK-404)
-- ----------------------------------------------------------------------------

-- Eliminar firma previa de 10 args (con defaults) para evitar ambigüedad en PostgREST
DROP FUNCTION IF EXISTS public.rpc_procesar_venta_v3(UUID, UUID, TEXT, NUMERIC, JSONB, UUID, TEXT, BOOLEAN, UUID, UUID);

CREATE OR REPLACE FUNCTION public.rpc_procesar_venta_v3(
    p_store_id UUID,
    p_client_id UUID,
    p_payment_method TEXT,
    p_amount_received NUMERIC,
    p_items JSONB,
    p_idempotency_key UUID DEFAULT NULL::uuid,
    p_local_id TEXT DEFAULT NULL::text,
    p_is_offline_sync BOOLEAN DEFAULT false,
    p_origin_session_id UUID DEFAULT NULL::uuid,
    p_sold_by UUID DEFAULT NULL::uuid,
    p_beneficiary_employee_id UUID DEFAULT NULL::uuid
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
    v_total_sale_persisted NUMERIC := 0;
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
    v_item_cost_total NUMERIC;
    v_item_unit_cost NUMERIC;
    v_item_ref_sale_price NUMERIC;
    v_client_balance NUMERIC;
    v_client_limit NUMERIC;
    v_sale_client_id UUID;
    v_employee_id UUID;
    v_emp_fk_id UUID;
    v_beneficiary_id UUID;
    v_actor_name TEXT;
    v_actor_role TEXT;
    v_snap RECORD;
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
    PERFORM public.assert_store_access(p_store_id);

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(p_store_id);

    IF p_is_offline_sync AND p_sold_by IS NOT NULL THEN
        SELECT e.id, e.name INTO v_employee_id, v_actor_name
        FROM public.employees e
        WHERE e.id = p_sold_by AND e.store_id = p_store_id;
        IF v_employee_id IS NOT NULL THEN
            v_actor_role := 'employee';
        END IF;
    END IF;

    IF v_employee_id IS NULL THEN
        v_employee_id := public.get_employee_id_from_session();
    END IF;

    IF v_employee_id IS NULL THEN
        IF public.is_store_admin(p_store_id) THEN
            v_employee_id := auth.uid();
        ELSE
            RAISE EXCEPTION 'Usuario no autorizado para vender (STORE_ACCESS_DENIED)' USING ERRCODE = 'P0001';
        END IF;
    END IF;

    SELECT e.id INTO v_emp_fk_id
    FROM public.employees e
    WHERE e.id = v_employee_id AND e.store_id = p_store_id
    LIMIT 1;

    v_actor_name := COALESCE(v_actor_name, v_snap.actor_name, 'Administrador');
    v_actor_role := COALESCE(v_actor_role, v_snap.actor_role, 'owner');

    -- Idempotency por p_idempotency_key
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

    -- Idempotency por p_local_id
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

    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'El carrito no puede estar vacío (EMPTY_CART)' USING ERRCODE = 'P0001';
    END IF;

    IF jsonb_array_length(p_items) > 50 THEN
        RAISE EXCEPTION 'El carrito no puede superar 50 ítems (CART_LIMIT_EXCEEDED)' USING ERRCODE = 'P0001';
    END IF;

    IF p_payment_method NOT IN ('efectivo', 'nequi', 'llave_bre', 'fiado', 'consumo_personal') THEN
        RAISE EXCEPTION 'Método de pago inválido: % (INVALID_PAYMENT_METHOD)', p_payment_method USING ERRCODE = 'P0001';
    END IF;

    -- CHK-404: Validación estricta de permiso canFiar para modalidad 'fiado'
    IF p_payment_method = 'fiado' THEN
        PERFORM public.assert_employee_permission(p_store_id, 'canFiar');
    END IF;

    -- CHK-401: Resolución de beneficiario para Consumo / Retiro Personal
    IF p_payment_method = 'consumo_personal' THEN
        IF p_beneficiary_employee_id IS NOT NULL
           AND (v_emp_fk_id IS NULL OR p_beneficiary_employee_id <> v_emp_fk_id) THEN
            IF NOT public.is_store_admin(p_store_id) THEN
                RAISE EXCEPTION 'PERMISSION_DENIED: Solo el Administrador puede registrar un consumo personal a nombre de otro colaborador.'
                    USING ERRCODE = '42501';
            END IF;

            SELECT e.id INTO v_beneficiary_id
            FROM public.employees e
            WHERE e.id = p_beneficiary_employee_id
              AND e.store_id = p_store_id
              AND e.is_active = true
            LIMIT 1;

            IF v_beneficiary_id IS NULL THEN
                RAISE EXCEPTION 'EMPLOYEE_NOT_FOUND: El empleado beneficiario seleccionado no existe o no está activo en la tienda.'
                    USING ERRCODE = 'P0002';
            END IF;
        ELSE
            v_beneficiary_id := COALESCE(p_beneficiary_employee_id, v_emp_fk_id);
        END IF;
    ELSE
        v_beneficiary_id := NULL;
    END IF;

    v_pm_allows_change := (p_payment_method = 'efectivo');
    -- CHK-403: Forzar client_id = NULL en toda modalidad distinta de 'fiado'
    v_sale_client_id := CASE WHEN p_payment_method = 'fiado' THEN p_client_id ELSE NULL END;

    -- Exigencia de turno de caja <24h para efectivo, digitales y consumo_personal
    IF p_payment_method IN ('efectivo', 'nequi', 'llave_bre', 'consumo_personal') THEN
        IF p_is_offline_sync AND p_origin_session_id IS NOT NULL THEN
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

    SELECT COALESCE(MAX(ticket_number), 0) + 1 INTO v_ticket_number
    FROM public.sales
    WHERE store_id = p_store_id;

    INSERT INTO public.sales (
        store_id, ticket_number, employee_id, actor_name, actor_role, client_id, beneficiary_employee_id,
        total, rounding_difference, payment_method, amount_received, change_given,
        sync_status, local_id, idempotency_key
    ) VALUES (
        p_store_id, v_ticket_number, v_emp_fk_id, v_actor_name, v_actor_role, v_sale_client_id, v_beneficiary_id,
        0, 0, p_payment_method,
        CASE WHEN p_payment_method = 'consumo_personal' THEN 0 ELSE COALESCE(p_amount_received, 0) END,
        0, 'synced', p_local_id, p_idempotency_key
    ) RETURNING id INTO v_sale_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::numeric;

        IF v_quantity IS NULL OR v_quantity <= 0 THEN
            RAISE EXCEPTION 'Cantidad de producto inválida: % (INVALID_QUANTITY)', v_quantity USING ERRCODE = 'P0001';
        END IF;

        SELECT name, price, cost_price, COALESCE(is_weighable, false)
        INTO v_product_name, v_product_price, v_product_cost, v_is_weighable
        FROM public.products
        WHERE id = v_product_id AND store_id = p_store_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto no encontrado: % (PRODUCT_NOT_FOUND)', v_product_id USING ERRCODE = 'P0001';
        END IF;

        v_historical_price := COALESCE(
            (v_item->>'historical_unit_price')::numeric,
            (v_item->>'unit_price')::numeric
        );
        IF p_is_offline_sync AND v_historical_price IS NOT NULL AND v_historical_price > 0 THEN
            v_product_price := v_historical_price;
        END IF;

        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, subtotal, unit_cost)
        VALUES (v_sale_id, v_product_id, v_quantity, 0, 0, 0)
        RETURNING id INTO v_sale_item_id;

        v_item_subtotal := 0;
        v_raw_subtotal := 0;
        v_item_cost_total := 0;

        FOR v_batch IN SELECT * FROM public.consume_stock_fifo(v_product_id, v_quantity) LOOP
            v_raw_subtotal := v_raw_subtotal + (v_batch.quantity_taken * COALESCE(v_batch.sale_price, v_product_price, 0));
            v_item_cost_total := v_item_cost_total + (v_batch.quantity_taken * COALESCE(v_batch.cost_unit, v_product_cost, 0));

            INSERT INTO public.sale_item_batches (sale_item_id, batch_id, quantity_consumed, unit_cost, unit_price)
            VALUES (
                v_sale_item_id,
                v_batch.batch_id,
                v_batch.quantity_taken,
                COALESCE(v_batch.cost_unit, v_product_cost, 0),
                COALESCE(v_batch.sale_price, v_product_price, 0)
            );
        END LOOP;

        v_item_unit_cost := CASE WHEN v_quantity > 0 THEN v_item_cost_total / v_quantity ELSE COALESCE(v_product_cost, 0) END;

        IF v_is_weighable THEN
            v_item_subtotal := FLOOR(v_raw_subtotal / 50.0) * 50;
            IF p_payment_method <> 'consumo_personal' THEN
                v_rounding_difference := v_rounding_difference + (v_raw_subtotal - v_item_subtotal);
            END IF;
        ELSE
            v_item_subtotal := v_raw_subtotal;
        END IF;

        v_item_ref_sale_price := CASE WHEN v_quantity > 0 THEN v_item_subtotal / v_quantity ELSE COALESCE(v_product_price, 0) END;

        UPDATE public.sale_items
        SET subtotal = CASE WHEN p_payment_method = 'consumo_personal' THEN 0 ELSE v_item_subtotal END,
            unit_price = CASE WHEN p_payment_method = 'consumo_personal' THEN 0 ELSE v_item_ref_sale_price END,
            unit_cost = v_item_unit_cost
        WHERE id = v_sale_item_id;

        IF p_payment_method = 'consumo_personal' THEN
            INSERT INTO public.inventory_movements (
                product_id, movement_type, quantity, reason, created_by,
                actor_name, actor_role, unit_cost, reference_sale_price,
                session_id, beneficiary_employee_id
            ) VALUES (
                v_product_id, 'consumo_personal', v_quantity, 'Retiro Personal #' || v_ticket_number, v_emp_fk_id,
                v_actor_name, v_actor_role, v_item_unit_cost, v_item_ref_sale_price,
                v_session_id, v_beneficiary_id
            );
        ELSE
            INSERT INTO public.inventory_movements (
                product_id, movement_type, quantity, reason, created_by,
                actor_name, actor_role, unit_cost, session_id
            ) VALUES (
                v_product_id, 'venta', v_quantity, 'Venta #' || v_ticket_number, v_emp_fk_id,
                v_actor_name, v_actor_role, v_item_unit_cost, v_session_id
            );
        END IF;

        v_total_calculated := v_total_calculated + v_item_subtotal;
        v_items_count := v_items_count + 1;
    END LOOP;

    IF p_payment_method = 'fiado' THEN
        IF v_sale_client_id IS NULL THEN
            RAISE EXCEPTION 'Se requiere especificar el cliente para venta a crédito / fiado (CLIENT_REQUIRED)' USING ERRCODE = 'P0001';
        END IF;

        SELECT balance, credit_limit INTO v_client_balance, v_client_limit
        FROM public.clients
        WHERE id = v_sale_client_id
          AND store_id = p_store_id
          AND COALESCE(is_deleted, false) = false
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Cliente no encontrado (CLIENT_NOT_FOUND)' USING ERRCODE = 'P0001';
        END IF;

        IF (v_client_balance + v_total_calculated) > v_client_limit THEN
            RAISE EXCEPTION 'Cupo de crédito excedido. Disponible: %, Total venta: % (CREDIT_LIMIT_EXCEEDED)',
                (v_client_limit - v_client_balance), v_total_calculated USING ERRCODE = 'P0001';
        END IF;
    END IF;

    IF v_pm_allows_change THEN
        IF COALESCE(p_amount_received, 0) < v_total_calculated THEN
            RAISE EXCEPTION 'El monto recibido ($%) es inferior al total a pagar ($%) (INSUFFICIENT_PAYMENT)',
                p_amount_received, v_total_calculated USING ERRCODE = 'P0001';
        END IF;
        v_change := p_amount_received - v_total_calculated;
    ELSE
        v_change := 0;
    END IF;

    v_total_sale_persisted := CASE WHEN p_payment_method = 'consumo_personal' THEN 0 ELSE v_total_calculated END;

    UPDATE public.sales
    SET total = v_total_sale_persisted,
        rounding_difference = CASE WHEN p_payment_method = 'consumo_personal' THEN 0 ELSE v_rounding_difference END,
        change_given = v_change
    WHERE id = v_sale_id;

    -- En consumo_personal NO se inserta en cash_movements ($0 en Caja Dedicada POS) ni se toca deuda cliente
    IF p_payment_method IN ('efectivo', 'nequi', 'llave_bre') THEN
        INSERT INTO public.cash_movements (
            session_id, movement_type, amount, description, sale_id, payment_method, category, actor_id, actor_name, actor_role
        ) VALUES (
            v_session_id, 'ingreso', v_total_calculated, 'Venta #' || v_ticket_number, v_sale_id, p_payment_method, 'venta', v_emp_fk_id, v_actor_name, v_actor_role
        );

        IF v_is_late_sync THEN
            IF p_payment_method = 'efectivo' THEN
                UPDATE public.cash_sessions
                SET expected_balance = COALESCE(expected_balance, 0) + v_total_calculated
                WHERE id = v_session_id;
            END IF;

            INSERT INTO public.audit_logs (
                actor_id, actor_name, actor_role, store_id, event_type, resource_id, metadata, severity, created_at
            ) VALUES (
                v_emp_fk_id,
                v_actor_name,
                v_actor_role,
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
        WHERE id = v_sale_client_id;

        INSERT INTO public.client_ledger (
            client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by, actor_name, actor_role
        ) VALUES (
            v_sale_client_id, p_store_id, v_total_calculated, v_client_balance, v_sale_id, 'venta_fiado', v_emp_fk_id, v_actor_name, v_actor_role
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'sale_id', v_sale_id,
            'ticket_number', v_ticket_number,
            'total', v_total_sale_persisted,
            'reference_retail_total', v_total_calculated,
            'rounding_difference', CASE WHEN p_payment_method = 'consumo_personal' THEN 0 ELSE v_rounding_difference END,
            'amount_received', CASE WHEN p_payment_method = 'consumo_personal' THEN 0 ELSE COALESCE(p_amount_received, v_total_calculated) END,
            'change_given', v_change,
            'payment_method', p_payment_method,
            'beneficiary_employee_id', v_beneficiary_id,
            'items_count', v_items_count,
            'created_at', NOW(),
            'actor_name', v_actor_name,
            'actor_role', v_actor_role
        )
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 3. CLIENTES & FIADOS: PERMISO canFiar, CUPO GLOBAL Y PAGINACIÓN (CHK-404..407)
-- ----------------------------------------------------------------------------

-- CHK-404: rpc_registrar_abono exige canFiar (via assert_employee_permission) y maneja Admin sin FK en employees
CREATE OR REPLACE FUNCTION public.rpc_registrar_abono(
    p_client_id UUID,
    p_amount NUMERIC,
    p_payment_method TEXT,
    p_notes TEXT DEFAULT NULL::text
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_store_id UUID;
    v_client public.clients%ROWTYPE;
    v_employee_id UUID;
    v_snap RECORD;
    v_session_id UUID;
    v_session_opened_at TIMESTAMPTZ;
    v_new_balance NUMERIC;
    v_cash_movement_id UUID;
    v_ledger_id UUID;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'El monto del abono debe ser mayor a cero (INVALID_AMOUNT)' USING ERRCODE = 'P0001';
    END IF;

    IF p_payment_method NOT IN ('efectivo', 'nequi', 'llave_bre') THEN
        RAISE EXCEPTION 'Método de pago no válido para abono: % (INVALID_PAYMENT_METHOD)', p_payment_method USING ERRCODE = 'P0001';
    END IF;

    -- 1. Guardias Multi-Tenant y Permiso canFiar ANTES de bloqueo FOR UPDATE (Regla 4)
    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED' USING ERRCODE = '42501';
    END IF;
    PERFORM public.assert_store_access(v_store_id);
    PERFORM public.assert_employee_permission(v_store_id, 'canFiar');

    SELECT * INTO v_client
    FROM public.clients
    WHERE id = p_client_id
      AND store_id = v_store_id
      AND COALESCE(is_deleted, false) = false
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cliente no encontrado o inactivo (CLIENT_NOT_FOUND)' USING ERRCODE = 'P0002';
    END IF;

    IF v_client.balance <= 0 THEN
        RAISE EXCEPTION 'El cliente no tiene saldo deudor pendiente (NO_OUTSTANDING_DEBT)' USING ERRCODE = 'P0001';
    END IF;

    IF p_amount > v_client.balance THEN
        RAISE EXCEPTION 'El abono ($%) supera la deuda actual ($%) (AMOUNT_EXCEEDS_DEBT)',
            p_amount, v_client.balance USING ERRCODE = 'P0001';
    END IF;

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

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_store_id);

    -- Solo poblar created_by / actor_id FK cuando exista fila real en employees (NULL cuando opera Admin)
    SELECT e.id INTO v_employee_id
    FROM public.employees e
    WHERE e.id = COALESCE(public.get_employee_id_from_session(), auth.uid())
      AND e.store_id = v_store_id
    LIMIT 1;

    v_new_balance := v_client.balance - p_amount;
    UPDATE public.clients
    SET balance = v_new_balance, updated_at = NOW()
    WHERE id = p_client_id;

    INSERT INTO public.client_ledger (
        client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by, actor_name, actor_role
    ) VALUES (
        p_client_id, v_client.store_id, -p_amount, v_client.balance, NULL, 'abono', v_employee_id, v_snap.actor_name, v_snap.actor_role
    ) RETURNING id INTO v_ledger_id;

    INSERT INTO public.cash_movements (
        session_id, movement_type, amount, description, payment_method, category, actor_id, actor_name, actor_role
    ) VALUES (
        v_session_id, 'ingreso', p_amount, '[ABONO_CLIENTE: ' || v_client.name || '] ' || COALESCE(p_notes, ''), p_payment_method, 'abono_cliente', v_employee_id, v_snap.actor_name, v_snap.actor_role
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
            'actor_name', v_snap.actor_name,
            'actor_role', v_snap.actor_role,
            'created_at', NOW()
        )
    );
END;
$function$;

-- CHK-404: rpc_obtener_estado_cuenta_cliente exige assert_employee_permission(..., 'canFiar') + is_deleted = false
CREATE OR REPLACE FUNCTION public.rpc_obtener_estado_cuenta_cliente(
    p_client_id UUID,
    p_limit INTEGER DEFAULT 20,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_store_id UUID;
    v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 500);
    v_offset INTEGER := GREATEST(COALESCE(p_offset, 0), 0);
    v_client public.clients%ROWTYPE;
    v_movements JSONB;
    v_total_count INTEGER := 0;
BEGIN
    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED: Sesión sin tienda activa asociada.'
            USING ERRCODE = '42501';
    END IF;
    PERFORM public.assert_store_access(v_store_id);
    PERFORM public.assert_employee_permission(v_store_id, 'canFiar');

    SELECT * INTO v_client
    FROM public.clients c
    WHERE c.id = p_client_id
      AND c.store_id = v_store_id
      AND COALESCE(c.is_deleted, false) = false;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'CLIENT_NOT_FOUND: El cliente no existe o no se encuentra activo en la tienda.'
            USING ERRCODE = 'P0002';
    END IF;

    SELECT COUNT(*) INTO v_total_count
    FROM public.client_ledger cl
    WHERE cl.client_id = p_client_id
      AND cl.store_id = v_store_id;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', sub.id,
                'transaction_type', sub.transaction_type,
                'amount', sub.amount,
                'previous_balance', sub.previous_balance,
                'new_balance', sub.new_balance,
                'reference_id', sub.reference_id,
                'ticket_number', sub.ticket_number,
                'created_at', sub.created_at
            )
            ORDER BY sub.created_at DESC, sub.id DESC
        ),
        '[]'::jsonb
    ) INTO v_movements
    FROM (
        SELECT cl.id,
               cl.transaction_type,
               cl.amount,
               cl.previous_balance,
               cl.new_balance,
               cl.reference_id,
               s.ticket_number,
               cl.created_at
        FROM public.client_ledger cl
        LEFT JOIN public.sales s ON s.id = cl.reference_id
        WHERE cl.client_id = p_client_id
          AND cl.store_id = v_store_id
        ORDER BY cl.created_at DESC, cl.id DESC
        LIMIT v_limit OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'client', jsonb_build_object(
                'id', v_client.id,
                'store_id', v_client.store_id,
                'name', v_client.name,
                'id_number', v_client.id_number,
                'phone', v_client.phone,
                'credit_limit', v_client.credit_limit,
                'balance', v_client.balance,
                'credit_available', GREATEST(0, v_client.credit_limit - COALESCE(v_client.balance, 0))
            ),
            'movements', v_movements,
            'generated_at', now()
        ),
        'count', v_total_count
    );
END;
$function$;

-- CHK-406: RPC Admin-only para actualizar default_credit_limit global (no toca clientes existentes)
CREATE OR REPLACE FUNCTION public.rpc_actualizar_cupo_credito_global(
    p_store_id UUID,
    p_default_credit_limit NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

    IF p_default_credit_limit IS NULL OR p_default_credit_limit < 0 THEN
        RAISE EXCEPTION 'INVALID_CREDIT_LIMIT: El cupo por defecto debe ser mayor o igual a cero.'
            USING ERRCODE = '22023';
    END IF;

    UPDATE public.stores
    SET default_credit_limit = p_default_credit_limit,
        updated_at = NOW()
    WHERE id = p_store_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'STORE_NOT_FOUND: Tienda no encontrada.' USING ERRCODE = 'P0002';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'store_id', p_store_id,
            'default_credit_limit', p_default_credit_limit
        )
    );
END;
$function$;

-- CHK-405 & CHK-406: Reforzar rpc_crear_cliente_fiado con assert_store_admin y precarga desde stores.default_credit_limit
CREATE OR REPLACE FUNCTION public.rpc_crear_cliente_fiado(
    p_store_id UUID,
    p_name TEXT,
    p_id_number TEXT,
    p_phone TEXT DEFAULT NULL::text,
    p_credit_limit NUMERIC DEFAULT NULL::numeric
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
DECLARE
    v_name TEXT := trim(COALESCE(p_name, ''));
    v_id_number TEXT := trim(COALESCE(p_id_number, ''));
    v_phone TEXT := NULLIF(trim(COALESCE(p_phone, '')), '');
    v_effective_credit_limit NUMERIC;
    v_admin_role TEXT;
    v_actor_id UUID;
    v_actor_name TEXT;
    v_snap RECORD;
    v_existing public.clients%ROWTYPE;
    v_client public.clients%ROWTYPE;
    v_conf_id UUID;
    v_now TIMESTAMPTZ := now();
BEGIN
    -- 1. Aislamiento Multi-Tenant y Rol Admin centralizado (D-ARCO-01)
    PERFORM public.assert_store_admin(p_store_id);

    SELECT role INTO v_admin_role
    FROM public.admin_profiles
    WHERE id = auth.uid() AND store_id = p_store_id
    LIMIT 1;
    v_admin_role := COALESCE(v_admin_role, 'owner');

    -- 2. Validación de Datos de Entrada
    IF length(v_name) < 3 THEN
        RAISE EXCEPTION 'INVALID_CLIENT_NAME: El nombre del cliente debe tener al menos 3 caracteres.'
            USING ERRCODE = '22023';
    END IF;

    IF v_id_number = '' THEN
        RAISE EXCEPTION 'INVALID_ID_NUMBER: El número de identificación es obligatorio.'
            USING ERRCODE = '22023';
    END IF;

    IF p_credit_limit IS NULL THEN
        SELECT COALESCE(default_credit_limit, 0) INTO v_effective_credit_limit
        FROM public.stores
        WHERE id = p_store_id;
        v_effective_credit_limit := COALESCE(v_effective_credit_limit, 0);
    ELSE
        v_effective_credit_limit := p_credit_limit;
    END IF;

    IF v_effective_credit_limit < 0 THEN
        RAISE EXCEPTION 'INVALID_CREDIT_LIMIT: El límite de crédito debe ser mayor o igual a cero.'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(p_store_id);
    v_actor_id := COALESCE(public.get_employee_id_from_session(), auth.uid());
    v_actor_name := COALESCE(v_snap.actor_name, 'Administrador');

    -- 3. Búsqueda y bloqueo pesimista por (store_id, id_number)
    SELECT * INTO v_existing
    FROM public.clients
    WHERE store_id = p_store_id
      AND id_number = v_id_number
    FOR UPDATE;

    IF FOUND THEN
        IF COALESCE(v_existing.is_deleted, false) = false THEN
            RAISE EXCEPTION 'DUPLICATE_CLIENT_ID_NUMBER: Ya existe un cliente activo con esa cédula en la tienda.'
                USING ERRCODE = '23505';
        END IF;

        -- Re-alta silenciosa desde Archivo Contable
        UPDATE public.clients
        SET name = v_name,
            phone = v_phone,
            credit_limit = v_effective_credit_limit,
            is_deleted = false,
            deleted_at = NULL
        WHERE id = v_existing.id
        RETURNING * INTO v_client;

        INSERT INTO public.client_registration_confirmations (
            store_id, client_id, created_by_user_id, created_by_name, confirmed_at
        ) VALUES (
            p_store_id, v_client.id, v_actor_id, v_actor_name, v_now
        ) RETURNING id INTO v_conf_id;

        INSERT INTO public.client_lifecycle_audit (
            store_id, client_id, event_type, actor_id, actor_name, actor_role, created_at
        ) VALUES (
            p_store_id, v_client.id, 'REACTIVATED', v_actor_id, v_actor_name, v_admin_role, v_now
        );
    ELSE
        BEGIN
            INSERT INTO public.clients (
                store_id, name, id_number, phone, credit_limit, balance, is_deleted, deleted_at
            ) VALUES (
                p_store_id, v_name, v_id_number, v_phone, v_effective_credit_limit, 0, false, NULL
            ) RETURNING * INTO v_client;
        EXCEPTION
            WHEN unique_violation THEN
                RAISE EXCEPTION 'DUPLICATE_CLIENT_ID_NUMBER: Cédula duplicada en la tienda.'
                    USING ERRCODE = '23505';
        END;

        INSERT INTO public.client_registration_confirmations (
            store_id, client_id, created_by_user_id, created_by_name, confirmed_at
        ) VALUES (
            p_store_id, v_client.id, v_actor_id, v_actor_name, v_now
        ) RETURNING id INTO v_conf_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'client', jsonb_build_object(
                'id', v_client.id,
                'store_id', v_client.store_id,
                'name', v_client.name,
                'id_number', v_client.id_number,
                'phone', v_client.phone,
                'credit_limit', v_client.credit_limit,
                'balance', v_client.balance,
                'created_at', v_client.created_at,
                'updated_at', v_client.updated_at
            ),
            'confirmation_id', v_conf_id,
            'confirmed_at', v_now
        )
    );
END;
$function$;

-- CHK-405: Homologar assert_store_admin en rpc_actualizar_cliente y rpc_eliminar_cliente
CREATE OR REPLACE FUNCTION public.rpc_actualizar_cliente(
    p_client_id UUID,
    p_name TEXT,
    p_id_number TEXT,
    p_phone TEXT DEFAULT NULL::text,
    p_credit_limit NUMERIC DEFAULT 100000
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_store_id UUID;
    v_client public.clients%ROWTYPE;
    v_name TEXT := trim(COALESCE(p_name, ''));
    v_id_number TEXT := trim(COALESCE(p_id_number, ''));
    v_phone TEXT := NULLIF(trim(COALESCE(p_phone, '')), '');
    v_updated public.clients%ROWTYPE;
BEGIN
    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED: Sesión sin tienda activa asociada.'
            USING ERRCODE = '42501';
    END IF;
    PERFORM public.assert_store_admin(v_store_id);

    IF length(v_name) < 3 THEN
        RAISE EXCEPTION 'INVALID_CLIENT_NAME: El nombre del cliente debe tener al menos 3 caracteres.'
            USING ERRCODE = '22023';
    END IF;

    IF v_id_number = '' THEN
        RAISE EXCEPTION 'INVALID_ID_NUMBER: El número de identificación es obligatorio.'
            USING ERRCODE = '22023';
    END IF;

    IF p_credit_limit IS NULL OR p_credit_limit < 0 THEN
        RAISE EXCEPTION 'INVALID_CREDIT_LIMIT: El límite de crédito debe ser mayor o igual a cero.'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_client
    FROM public.clients
    WHERE id = p_client_id
      AND store_id = v_store_id
    FOR UPDATE;

    IF NOT FOUND OR COALESCE(v_client.is_deleted, false) = true THEN
        RAISE EXCEPTION 'CLIENT_NOT_FOUND: El cliente no existe o no se encuentra activo.'
            USING ERRCODE = 'P0002';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.clients c
        WHERE c.store_id = v_store_id
          AND c.id_number = v_id_number
          AND c.id <> p_client_id
    ) THEN
        RAISE EXCEPTION 'DUPLICATE_CLIENT_ID_NUMBER: La cédula ingresada ya pertenece a otro registro de esta tienda.'
            USING ERRCODE = '23505';
    END IF;

    UPDATE public.clients
    SET name = v_name,
        id_number = v_id_number,
        phone = v_phone,
        credit_limit = p_credit_limit
    WHERE id = p_client_id
      AND store_id = v_store_id
    RETURNING * INTO v_updated;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'client', jsonb_build_object(
                'id', v_updated.id,
                'store_id', v_updated.store_id,
                'name', v_updated.name,
                'id_number', v_updated.id_number,
                'phone', v_updated.phone,
                'credit_limit', v_updated.credit_limit,
                'balance', v_updated.balance,
                'updated_at', v_updated.updated_at
            )
        )
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.rpc_eliminar_cliente(p_client_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
DECLARE
    v_store_id UUID;
    v_admin_role TEXT;
    v_client public.clients%ROWTYPE;
    v_has_history BOOLEAN := false;
    v_actor_id UUID;
    v_actor_name TEXT;
    v_snap RECORD;
    v_now TIMESTAMPTZ := now();
BEGIN
    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED: Sesión sin tienda activa asociada.'
            USING ERRCODE = '42501';
    END IF;
    PERFORM public.assert_store_admin(v_store_id);

    SELECT role INTO v_admin_role
    FROM public.admin_profiles
    WHERE id = auth.uid() AND store_id = v_store_id
    LIMIT 1;
    v_admin_role := COALESCE(v_admin_role, 'owner');

    SELECT * INTO v_client
    FROM public.clients
    WHERE id = p_client_id
      AND store_id = v_store_id
    FOR UPDATE;

    IF NOT FOUND OR COALESCE(v_client.is_deleted, false) = true THEN
        RAISE EXCEPTION 'CLIENT_NOT_FOUND: El cliente no existe en la tienda activa.'
            USING ERRCODE = 'P0002';
    END IF;

    IF COALESCE(v_client.balance, 0) > 0 THEN
        RAISE EXCEPTION 'CLIENT_HAS_DEBT: El cliente tiene un saldo pendiente de $% y no puede eliminarse.', v_client.balance
            USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_store_id);
    v_actor_id := COALESCE(public.get_employee_id_from_session(), auth.uid());
    v_actor_name := COALESCE(v_snap.actor_name, 'Administrador');

    SELECT (
        EXISTS (SELECT 1 FROM public.client_ledger cl WHERE cl.client_id = p_client_id)
        OR EXISTS (SELECT 1 FROM public.sales s WHERE s.client_id = p_client_id)
    ) INTO v_has_history;

    IF v_has_history THEN
        UPDATE public.clients
        SET phone = NULL,
            credit_limit = 0,
            is_deleted = true,
            deleted_at = v_now
        WHERE id = p_client_id
          AND store_id = v_store_id;

        INSERT INTO public.client_lifecycle_audit (
            store_id, client_id, event_type, actor_id, actor_name, actor_role, created_at
        ) VALUES (
            v_store_id, p_client_id, 'ARCHIVED_ACCOUNTING', v_actor_id, v_actor_name, v_admin_role, v_now
        );
    ELSE
        DELETE FROM public.clients
        WHERE id = p_client_id
          AND store_id = v_store_id;

        INSERT INTO public.client_lifecycle_audit (
            store_id, client_id, event_type, actor_id, actor_name, actor_role, created_at
        ) VALUES (
            v_store_id, p_client_id, 'HARD_DELETED', v_actor_id, v_actor_name, v_admin_role, v_now
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'client_id', p_client_id,
            'deleted', true,
            'deleted_at', v_now
        )
    );
END;
$function$;

-- CHK-407: rpc_admin_get_clients abierto a empleados con canFiar (o Admin), cero p_include_deleted / is_deleted / deleted_at
CREATE OR REPLACE FUNCTION public.rpc_admin_get_clients(
    p_store_id UUID,
    p_filter_debt TEXT DEFAULT 'todos'::text,
    p_search_query TEXT DEFAULT NULL::text,
    p_order_by TEXT DEFAULT 'name_asc'::text,
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
    v_filter TEXT := COALESCE(NULLIF(trim(p_filter_debt), ''), 'todos');
    v_search TEXT := NULLIF(trim(COALESCE(p_search_query, '')), '');
BEGIN
    PERFORM public.assert_store_access(p_store_id);
    PERFORM public.assert_employee_permission(p_store_id, 'canFiar');

    SELECT COUNT(*) INTO v_total_count
    FROM public.clients c
    WHERE c.store_id = p_store_id
      AND COALESCE(c.is_deleted, false) = false
      AND (
          v_filter = 'todos'
          OR (v_filter = 'con_deuda' AND c.balance > 0)
          OR (v_filter IN ('sin_deuda', 'al_dia') AND c.balance <= 0)
      )
      AND (
          v_search IS NULL
          OR c.name ILIKE '%' || v_search || '%'
          OR c.id_number ILIKE '%' || v_search || '%'
          OR c.phone ILIKE '%' || v_search || '%'
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', c.id,
                'store_id', c.store_id,
                'name', c.name,
                'id_number', c.id_number,
                'phone', c.phone,
                'credit_limit', c.credit_limit,
                'balance', c.balance,
                'credit_available', GREATEST(0, c.credit_limit - c.balance),
                'credit_usage_pct', CASE WHEN c.credit_limit > 0 THEN ROUND((c.balance / c.credit_limit) * 100, 1) ELSE 0 END,
                'created_at', c.created_at
            ) ORDER BY
                CASE WHEN p_order_by = 'balance_desc' THEN c.balance END DESC NULLS LAST,
                CASE WHEN p_order_by = 'balance_asc' THEN c.balance END ASC NULLS LAST,
                CASE WHEN p_order_by = 'name_asc' THEN c.name END ASC,
                CASE WHEN p_order_by = 'name_desc' THEN c.name END DESC,
                c.created_at DESC
        ),
        '[]'::jsonb
    ) INTO v_clients
    FROM (
        SELECT c.*
        FROM public.clients c
        WHERE c.store_id = p_store_id
          AND COALESCE(c.is_deleted, false) = false
          AND (
              v_filter = 'todos'
              OR (v_filter = 'con_deuda' AND c.balance > 0)
              OR (v_filter IN ('sin_deuda', 'al_dia') AND c.balance <= 0)
          )
          AND (
              v_search IS NULL
              OR c.name ILIKE '%' || v_search || '%'
              OR c.id_number ILIKE '%' || v_search || '%'
              OR c.phone ILIKE '%' || v_search || '%'
          )
        ORDER BY
            CASE WHEN p_order_by = 'balance_desc' THEN c.balance END DESC NULLS LAST,
            CASE WHEN p_order_by = 'balance_asc' THEN c.balance END ASC NULLS LAST,
            CASE WHEN p_order_by = 'name_asc' THEN c.name END ASC,
            CASE WHEN p_order_by = 'name_desc' THEN c.name END DESC,
            c.created_at DESC
        LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    ) c;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_clients,
        'count', v_total_count
    );
END;
$function$;

-- ----------------------------------------------------------------------------
-- 4. CUENTAS POR PAGAR Y PROVEEDORES (100% ADMIN-ONLY): CHK-409 y CHK-410
-- ----------------------------------------------------------------------------

-- Eliminar ambas sobrecargas legacy de rpc_pay_supplier_invoice para evitar ambigüedad
DROP FUNCTION IF EXISTS public.rpc_pay_supplier_invoice(UUID, NUMERIC);
DROP FUNCTION IF EXISTS public.rpc_pay_supplier_invoice(UUID, NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.rpc_pay_supplier_invoice(UUID, NUMERIC, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.rpc_pay_supplier_invoice(
    p_invoice_id UUID,
    p_amount NUMERIC,
    p_payment_method TEXT,
    p_description TEXT DEFAULT NULL::text
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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
        RAISE EXCEPTION 'INVALID_AMOUNT: El abono debe ser mayor a cero.'
            USING ERRCODE = 'P0001';
    END IF;

    IF p_payment_method IS NULL OR p_payment_method NOT IN ('efectivo', 'nequi', 'llave_bre', 'externo') THEN
        RAISE EXCEPTION 'INVALID_PAYMENT_METHOD: Método no permitido (%). Use efectivo, nequi, llave_bre o externo.',
            COALESCE(p_payment_method, 'NULL') USING ERRCODE = 'P0001';
    END IF;

    -- Guardia Multi-Tenant y Admin-Only ANTES de FOR UPDATE (Regla 4)
    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED: Sesión sin tienda activa.'
            USING ERRCODE = '42501';
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
        RAISE EXCEPTION 'INVOICE_NOT_FOUND: La factura no existe en la tienda activa.'
            USING ERRCODE = 'P0002';
    END IF;

    IF p_amount > (v_invoice.total_amount - v_invoice.amount_paid) THEN
        RAISE EXCEPTION 'AMOUNT_EXCEEDS_PENDING: El monto ($%) supera el saldo pendiente ($%).',
            p_amount, (v_invoice.total_amount - v_invoice.amount_paid) USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_store_id);
    SELECT e.id INTO v_emp_fk_id
    FROM public.employees e
    WHERE e.id = COALESCE(public.get_employee_id_from_session(), auth.uid())
      AND e.store_id = v_store_id
    LIMIT 1;

    v_clean_desc := NULLIF(TRIM(COALESCE(p_description, '')), '');

    IF p_payment_method = 'externo' THEN
        -- Pago externo / fuera de caja: $0 en cash_movements y no requiere turno abierto
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
            - COALESCE(SUM(CASE WHEN movement_type IN ('gasto', 'pago_proveedor') AND payment_method = p_payment_method THEN amount ELSE 0 END), 0)
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

-- CHK-410: Crear factura proveedor (Admin-only, proveedor normalizado y due_date opcional)
CREATE OR REPLACE FUNCTION public.rpc_crear_factura_proveedor(
    p_store_id UUID,
    p_supplier_name TEXT,
    p_total_amount NUMERIC,
    p_due_date DATE DEFAULT NULL::date,
    p_invoice_number TEXT DEFAULT NULL::text
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_supplier_clean TEXT;
    v_supplier_id UUID;
    v_invoice RECORD;
    v_ref_clean TEXT := NULLIF(TRIM(COALESCE(p_invoice_number, '')), '');
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

    v_supplier_clean := initcap(regexp_replace(trim(COALESCE(p_supplier_name, '')), '\s+', ' ', 'g'));
    IF length(v_supplier_clean) < 2 THEN
        RAISE EXCEPTION 'INVALID_SUPPLIER_NAME: El nombre del proveedor es obligatorio (mínimo 2 caracteres).'
            USING ERRCODE = '22023';
    END IF;

    IF p_total_amount IS NULL OR p_total_amount <= 0 THEN
        RAISE EXCEPTION 'INVALID_AMOUNT: El valor total de la factura debe ser mayor a cero.'
            USING ERRCODE = '22023';
    END IF;

    SELECT id INTO v_supplier_id
    FROM public.suppliers
    WHERE store_id = p_store_id
      AND LOWER(TRIM(name)) = LOWER(v_supplier_clean)
    LIMIT 1;

    IF v_supplier_id IS NULL THEN
        INSERT INTO public.suppliers (store_id, name, frequency_days, lead_time_days, is_default)
        VALUES (p_store_id, v_supplier_clean, 15, 1, false)
        RETURNING id INTO v_supplier_id;
    END IF;

    INSERT INTO public.supplier_invoices (
        store_id, supplier_id, total_amount, amount_paid, due_date, invoice_number
    ) VALUES (
        p_store_id, v_supplier_id, p_total_amount, 0, p_due_date, v_ref_clean
    ) RETURNING * INTO v_invoice;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'invoice', jsonb_build_object(
                'id', v_invoice.id,
                'store_id', v_invoice.store_id,
                'supplier_id', v_invoice.supplier_id,
                'supplier', jsonb_build_object('id', v_supplier_id, 'name', v_supplier_clean),
                'invoice_number', v_invoice.invoice_number,
                'total_amount', v_invoice.total_amount,
                'amount_paid', v_invoice.amount_paid,
                'pending_balance', v_invoice.total_amount - v_invoice.amount_paid,
                'due_date', v_invoice.due_date,
                'status', CASE
                    WHEN v_invoice.due_date IS NOT NULL AND v_invoice.due_date < v_today THEN 'vencida'
                    ELSE 'pendiente'
                END,
                'created_at', v_invoice.created_at
            )
        )
    );
END;
$function$;

-- CHK-410: Lectura paginada de Cuentas por Pagar (Admin-only, { data, count })
CREATE OR REPLACE FUNCTION public.rpc_obtener_cuentas_por_pagar(
    p_store_id UUID,
    p_status TEXT DEFAULT NULL::text,
    p_supplier_id UUID DEFAULT NULL::uuid,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
    v_status_filter TEXT := NULLIF(LOWER(TRIM(COALESCE(p_status, ''))), '');
    v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
    v_offset INTEGER := GREATEST(COALESCE(p_offset, 0), 0);
    v_total_count INTEGER := 0;
    v_rows JSONB;
BEGIN
    PERFORM public.assert_store_admin(p_store_id);

    WITH base AS (
        SELECT
            si.id,
            si.store_id,
            si.supplier_id,
            s.name AS supplier_name,
            si.invoice_number,
            si.total_amount,
            si.amount_paid,
            GREATEST(0, si.total_amount - si.amount_paid) AS pending_balance,
            si.due_date,
            si.created_at,
            CASE
                WHEN si.amount_paid >= si.total_amount THEN 'pagada'
                WHEN si.due_date IS NOT NULL AND si.due_date < v_today THEN 'vencida'
                ELSE 'pendiente'
            END AS computed_status
        FROM public.supplier_invoices si
        LEFT JOIN public.suppliers s ON s.id = si.supplier_id
        WHERE si.store_id = p_store_id
          AND (p_supplier_id IS NULL OR si.supplier_id = p_supplier_id)
    ),
    filtered AS (
        SELECT *
        FROM base
        WHERE v_status_filter IS NULL
           OR v_status_filter = 'todos'
           OR computed_status = v_status_filter
    )
    SELECT COUNT(*) INTO v_total_count FROM filtered;

    WITH base AS (
        SELECT
            si.id,
            si.store_id,
            si.supplier_id,
            s.name AS supplier_name,
            si.invoice_number,
            si.total_amount,
            si.amount_paid,
            GREATEST(0, si.total_amount - si.amount_paid) AS pending_balance,
            si.due_date,
            si.created_at,
            CASE
                WHEN si.amount_paid >= si.total_amount THEN 'pagada'
                WHEN si.due_date IS NOT NULL AND si.due_date < v_today THEN 'vencida'
                ELSE 'pendiente'
            END AS computed_status
        FROM public.supplier_invoices si
        LEFT JOIN public.suppliers s ON s.id = si.supplier_id
        WHERE si.store_id = p_store_id
          AND (p_supplier_id IS NULL OR si.supplier_id = p_supplier_id)
    ),
    filtered AS (
        SELECT *
        FROM base
        WHERE v_status_filter IS NULL
           OR v_status_filter = 'todos'
           OR computed_status = v_status_filter
        ORDER BY
            CASE computed_status
                WHEN 'vencida' THEN 0
                WHEN 'pendiente' THEN 1
                ELSE 2
            END ASC,
            due_date ASC NULLS LAST,
            created_at DESC
        LIMIT v_limit
        OFFSET v_offset
    )
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', f.id,
                'store_id', f.store_id,
                'supplier_id', f.supplier_id,
                'supplier', jsonb_build_object('name', COALESCE(f.supplier_name, 'Desconocido')),
                'invoice_number', f.invoice_number,
                'total_amount', f.total_amount,
                'amount_paid', f.amount_paid,
                'pending_balance', f.pending_balance,
                'due_date', f.due_date,
                'status', f.computed_status,
                'created_at', f.created_at
            )
            ORDER BY
                CASE f.computed_status
                    WHEN 'vencida' THEN 0
                    WHEN 'pendiente' THEN 1
                    ELSE 2
                END ASC,
                f.due_date ASC NULLS LAST,
                f.created_at DESC
        ),
        '[]'::jsonb
    ) INTO v_rows
    FROM filtered f;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_rows,
        'count', v_total_count
    );
END;
$function$;

COMMIT;

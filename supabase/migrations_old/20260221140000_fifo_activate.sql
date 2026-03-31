-- =============================================
-- FIFO PHASE 2: ACTIVACIÓN
-- =============================================
-- Descripción: Integra consume_stock_fifo() en rpc_procesar_venta_v2,
--   crea Lotes Génesis para productos existentes, y verifica integridad.
-- Dependencia: 20260221130000_fifo_reorganize.sql
-- Autor: @[/data]

-- =========================================
-- 1. MODIFY: rpc_procesar_venta_v2 — Integrar FIFO
-- =========================================
-- Se agrega PERFORM consume_stock_fifo() ANTES del INSERT de movimiento venta.
-- consume_stock_fifo() descuenta lotes del más antiguo al más nuevo.
-- El INSERT de inventory_movements tipo 'venta' ya NO afecta stock 
-- (bridge_movement_to_batch lo ignora con NULL).

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
    v_item JSONB; v_product_id UUID; v_quantity DECIMAL; v_product_price DECIMAL; v_product_name TEXT; v_subtotal DECIMAL;
    v_client_balance DECIMAL; v_client_limit DECIMAL; v_employee_id UUID;
    v_pm_exists BOOLEAN; v_pm_allows_change BOOLEAN; v_pm_requires_ref BOOLEAN; v_pm_is_active BOOLEAN;
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

    -- Primera pasada: Calcular total y validar productos
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_quantity := (v_item->>'quantity')::DECIMAL;
        SELECT price, name INTO v_product_price, v_product_name
        FROM public.products WHERE id = v_product_id AND store_id = p_store_id;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'Producto no encontrado: ' || v_product_id);
        END IF;
        v_total_calculated := v_total_calculated + (v_product_price * v_quantity);
    END LOOP;

    IF p_payment_method = 'fiado' THEN
        IF p_client_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Se requiere cliente para fiado');
        END IF;
        SELECT balance, credit_limit INTO v_client_balance, v_client_limit
        FROM public.clients WHERE id = p_client_id FOR UPDATE;
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'Cliente no encontrado');
        END IF;
        IF (v_client_balance + v_total_calculated) > v_client_limit THEN
            RETURN jsonb_build_object('success', false, 'error', 'Cupo excedido. Cupo: ' || v_client_limit || '. Saldo Nuevo: ' || (v_client_balance + v_total_calculated), 'code', 'CREDIT_LIMIT_EXCEEDED');
        END IF;
    END IF;

    SELECT COALESCE(MAX(ticket_number), 0) + 1 INTO v_ticket_number FROM public.sales WHERE store_id = p_store_id;
    IF v_pm_allows_change THEN
        v_change := GREATEST(0, p_amount_received - v_total_calculated);
    ELSE
        v_change := 0;
    END IF;

    INSERT INTO public.sales (store_id, ticket_number, employee_id, client_id, total, payment_method, amount_received, change_given, sync_status)
    VALUES (p_store_id, v_ticket_number, v_employee_id, p_client_id, v_total_calculated, p_payment_method, p_amount_received, v_change, 'synced')
    RETURNING id INTO v_sale_id;

    -- Segunda pasada: Procesar items con FIFO
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_quantity := (v_item->>'quantity')::DECIMAL;
        SELECT price INTO v_product_price FROM public.products WHERE id = v_product_id;
        v_subtotal := v_quantity * v_product_price;

        -- ★ FIFO: Consumir lotes del más antiguo al más nuevo
        PERFORM public.consume_stock_fifo(v_product_id, v_quantity);

        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, subtotal)
        VALUES (v_sale_id, v_product_id, v_quantity, v_product_price, v_subtotal);
        INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by)
        VALUES (v_product_id, 'venta', v_quantity, 'Venta #' || v_ticket_number, v_employee_id);
    END LOOP;

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

    IF p_payment_method = 'fiado' THEN
        UPDATE public.clients SET balance = balance + v_total_calculated WHERE id = p_client_id;
        INSERT INTO public.client_ledger (client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by)
        VALUES (p_client_id, p_store_id, v_total_calculated, v_client_balance, v_sale_id, 'venta_fiado', v_employee_id);
    END IF;

    RETURN jsonb_build_object('success', true, 'sale_id', v_sale_id, 'ticket_number', v_ticket_number, 'total', v_total_calculated, 'change', v_change);

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Error interno: ' || SQLERRM, 'code', SQLSTATE);
END;
$function$;

-- =========================================
-- 2. SEED: Lotes Génesis para stock existente
-- =========================================
-- Convierte el stock plano actual en el primer lote de cada producto.
-- NOT EXISTS previene duplicados si se re-ejecuta.

INSERT INTO public.inventory_batches (product_id, quantity_initial, quantity_remaining, cost_unit)
SELECT id, current_stock, current_stock, COALESCE(NULLIF(cost_price, 0), price * 0.7)
FROM public.products
WHERE current_stock > 0
  AND NOT EXISTS (
      SELECT 1 FROM public.inventory_batches b WHERE b.product_id = products.id
  );

-- =========================================
-- 3. VERIFY: Integridad automática
-- =========================================

DO $$
DECLARE 
    v_mismatch INTEGER;
    v_batch_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_batch_count FROM public.inventory_batches;
    RAISE NOTICE 'FIFO SEED: % batches created', v_batch_count;

    SELECT COUNT(*) INTO v_mismatch
    FROM public.products p
    WHERE p.current_stock > 0
      AND p.current_stock != (
          SELECT COALESCE(SUM(b.quantity_remaining), 0)
          FROM public.inventory_batches b WHERE b.product_id = p.id
      );

    IF v_mismatch > 0 THEN
        RAISE WARNING 'FIFO INTEGRITY: % products have stock mismatch with batches', v_mismatch;
    ELSE
        RAISE NOTICE 'FIFO INTEGRITY: ✅ All stocks match between products.current_stock and inventory_batches';
    END IF;
END $$;

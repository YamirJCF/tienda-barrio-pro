-- =============================================
-- MIGRACIÓN A INVENTARIO FIFO (LOTES)
-- =============================================
-- Descripción: Creación de la tabla inventory_batches y funciones asociadas
-- que fueron omitidas en la consolidación inicial.
-- Impacto: Transición de stock plano a modelo de lotes FIFO.

BEGIN;

-- 1. CREACIÓN DE TABLA DE LOTES
CREATE TABLE IF NOT EXISTS public.inventory_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    quantity_initial DECIMAL(10,2) NOT NULL CHECK (quantity_initial > 0),
    quantity_remaining DECIMAL(10,2) NOT NULL CHECK (quantity_remaining >= 0),
    cost_unit DECIMAL(12,0) NOT NULL CHECK (cost_unit >= 0),
    is_active BOOLEAN GENERATED ALWAYS AS (quantity_remaining > 0) STORED,
    
    -- Auditoría
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    created_by UUID REFERENCES public.employees(id),
    
    -- Constraint: Remaining no puede superar Initial
    CONSTRAINT chk_remaining_valid CHECK (quantity_remaining <= quantity_initial)
);

-- Índices para búsqueda rápida FIFO
CREATE INDEX IF NOT EXISTS idx_batches_fifo 
ON public.inventory_batches(product_id, created_at ASC) 
WHERE quantity_remaining > 0;

-- RLS: Seguridad Primero
ALTER TABLE public.inventory_batches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "batches_select_store" ON public.inventory_batches
FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.products p WHERE p.id = product_id AND p.store_id = get_current_store_id())
);

-- 2. FUNCIÓN DE CONSUMO FIFO (Lógica Core)
CREATE OR REPLACE FUNCTION public.consume_stock_fifo(
    p_product_id UUID,
    p_quantity_needed DECIMAL
)
RETURNS TABLE (batch_id UUID, quantity_taken DECIMAL, cost_unit DECIMAL) AS $$
DECLARE
    v_qty_left DECIMAL := p_quantity_needed;
    v_batch RECORD;
    v_take DECIMAL;
BEGIN
    -- Validar stock total suficiente (Quick check)
    IF (SELECT current_stock FROM public.products WHERE id = p_product_id) < p_quantity_needed THEN
        RAISE EXCEPTION 'Stock insuficiente (FIFO Check)';
    END IF;

    -- Iterar lotes activos por antigüedad
    FOR v_batch IN 
        SELECT ib.id, ib.quantity_remaining, ib.cost_unit 
        FROM public.inventory_batches ib
        WHERE ib.product_id = p_product_id AND ib.quantity_remaining > 0
        ORDER BY ib.created_at ASC
        FOR UPDATE -- Lock rows to prevent race conditions
    LOOP
        IF v_qty_left <= 0 THEN EXIT; END IF;

        -- Calcular cuánto tomar de este lote
        v_take := LEAST(v_qty_left, v_batch.quantity_remaining);
        
        -- Actualizar lote
        UPDATE public.inventory_batches 
        SET quantity_remaining = quantity_remaining - v_take
        WHERE id = v_batch.id;

        -- Retornar info para costeo de venta
        batch_id := v_batch.id;
        quantity_taken := v_take;
        cost_unit := v_batch.cost_unit;
        RETURN NEXT;

        v_qty_left := v_qty_left - v_take;
    END LOOP;

    IF v_qty_left > 0 THEN
        RAISE EXCEPTION 'Inconsistencia de Inventario: Stock en Products no coincide con Lotes.';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. MIGRACIÓN DE DATOS (SEEDING INICIAL)
-- Convierte el stock actual "plano" en el "Lote Génesis"
INSERT INTO public.inventory_batches (product_id, quantity_initial, quantity_remaining, cost_unit, created_at)
SELECT 
    id, 
    current_stock, 
    current_stock, 
    COALESCE(cost_price, price * 0.7), -- Fallback si no hay costo: 70% del precio venta
    now()
FROM public.products
WHERE current_stock > 0
  AND NOT EXISTS (
      SELECT 1 FROM public.inventory_batches b WHERE b.product_id = products.id
  );

-- 4. TRIGGER DE SINCRONIZACIÓN (Products <-> Batches)
-- Mantiene products.current_stock actualizado automáticamente
CREATE OR REPLACE FUNCTION public.sync_product_stock_from_batches()
RETURNS TRIGGER AS $$
DECLARE
    v_product_id UUID;
    v_total_stock DECIMAL;
    v_active_cost DECIMAL;
BEGIN
    -- Handle DELETE (NEW is null, use OLD)
    v_product_id := COALESCE(NEW.product_id, OLD.product_id);

    -- 1. Calculate Total Stock from all batches
    SELECT COALESCE(SUM(quantity_remaining), 0)
    INTO v_total_stock
    FROM public.inventory_batches
    WHERE product_id = v_product_id;

    -- 2. Find Oldest Active Batch Cost (FIFO: we sell the oldest first)
    SELECT cost_unit
    INTO v_active_cost
    FROM public.inventory_batches
    WHERE product_id = v_product_id AND quantity_remaining > 0
    ORDER BY created_at ASC
    LIMIT 1;

    -- 3. Update Product
    IF v_active_cost IS NOT NULL THEN
        UPDATE public.products
        SET current_stock = v_total_stock,
            cost_price = v_active_cost
        WHERE id = v_product_id;
    ELSE
        -- No active batches (out of stock) — preserve last known cost
        UPDATE public.products
        SET current_stock = v_total_stock
        WHERE id = v_product_id;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';

-- 5. TRIGGER DE PUENTE (Movements -> Batches)
CREATE OR REPLACE FUNCTION public.bridge_movement_to_batch()
RETURNS TRIGGER AS $$
DECLARE
    v_cost DECIMAL;
BEGIN
    CASE NEW.movement_type
        -- ENTRADA / DEVOLUCIÓN: Crear nuevo lote
        WHEN 'entrada', 'devolucion' THEN
            v_cost := COALESCE(
                (SELECT cost_price FROM public.products WHERE id = NEW.product_id),
                0
            );

            INSERT INTO public.inventory_batches (
                product_id, quantity_initial, quantity_remaining,
                cost_unit, created_by
            ) VALUES (
                NEW.product_id, NEW.quantity, NEW.quantity,
                v_cost, NEW.created_by
            );

        -- SALIDA: Consumir lotes FIFO
        WHEN 'salida' THEN
            PERFORM public.consume_stock_fifo(NEW.product_id, NEW.quantity);

        -- CORRECCIÓN SISTEMA: Positivo=crear lote, Negativo=consumir FIFO
        WHEN 'CORRECCION_SISTEMA' THEN
            IF NEW.quantity > 0 THEN
                v_cost := COALESCE(
                    (SELECT cost_price FROM public.products WHERE id = NEW.product_id),
                    0
                );
                INSERT INTO public.inventory_batches (
                    product_id, quantity_initial, quantity_remaining,
                    cost_unit, created_by
                ) VALUES (
                    NEW.product_id, NEW.quantity, NEW.quantity,
                    v_cost, NEW.created_by
                );
            ELSE
                PERFORM public.consume_stock_fifo(NEW.product_id, ABS(NEW.quantity));
            END IF;

        -- VENTA: NO-OP (ya se procesó en rpc_procesar_venta_v2)
        WHEN 'venta' THEN
            NULL;

        -- OTROS: No-op
        ELSE
            NULL;
    END CASE;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';

-- 6. APLICAR TRIGGERS
DROP TRIGGER IF EXISTS trg_update_stock ON public.inventory_movements;
DROP FUNCTION IF EXISTS public.update_product_stock();

CREATE TRIGGER trg_sync_batches
AFTER INSERT OR UPDATE OR DELETE ON public.inventory_batches
FOR EACH ROW EXECUTE FUNCTION public.sync_product_stock_from_batches();

CREATE TRIGGER trg_bridge_movement_to_batch
AFTER INSERT ON public.inventory_movements
FOR EACH ROW EXECUTE FUNCTION public.bridge_movement_to_batch();

-- 7. ACTUALIZAR RPC_PROCESAR_VENTA_V2 (Agregar PERFORM consume_stock_fifo)
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

-- 8. PERMISOS
GRANT SELECT, INSERT, UPDATE, DELETE ON public.inventory_batches TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.inventory_batches TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.inventory_batches TO anon;

COMMIT;

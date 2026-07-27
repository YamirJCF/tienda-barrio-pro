-- Fix: Colisión FIFO y Cuentas por Pagar (FRD-019)
-- Autor: Antigravity
-- Ref: Auditoría QA 2026-07-26 | Bug: Fuga silenciosa de deuda y competencia por lotes

-- 1. Modificar tabla inventory_movements para guardar costo transaccional real
ALTER TABLE public.inventory_movements
ADD COLUMN IF NOT EXISTS unit_cost NUMERIC(12,0) DEFAULT NULL;

-- 2. Modificar RPC rpc_registrar_entrada para delegar Lotes al Trigger
CREATE OR REPLACE FUNCTION public.rpc_registrar_entrada(
    p_product_id    UUID,
    p_quantity      DECIMAL,
    p_purchase_price DECIMAL,
    p_sale_price    DECIMAL,
    p_reason        TEXT DEFAULT 'Entrada de mercancía',
    -- Nuevos parámetros (FRD-019), añadidos al final para mantener compatibilidad de posición
    p_supplier_id          UUID DEFAULT NULL,
    p_payment_type         TEXT DEFAULT NULL,
    p_invoice_reference    TEXT DEFAULT NULL,
    p_reference_invoice_id UUID DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_store_id UUID;
    v_actor_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
BEGIN
    -- Validar autenticación
    IF v_actor_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No autorizado',
            'code', 'UNAUTHORIZED'
        );
    END IF;

    -- Validar cantidad
    IF p_quantity <= 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'La cantidad debe ser mayor a 0',
            'code', 'INVALID_QUANTITY'
        );
    END IF;

    -- Obtener store_id
    SELECT store_id INTO v_store_id
    FROM public.products
    WHERE id = p_product_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Producto no encontrado',
            'code', 'NOT_FOUND'
        );
    END IF;

    -- Verificar acceso Empleado
    SELECT TRUE INTO v_is_authorized
    FROM public.employees
    WHERE id = v_actor_id AND store_id = v_store_id;

    -- Verificar acceso Admin (si empleado falla)
    IF NOT FOUND OR NOT v_is_authorized THEN
        SELECT TRUE INTO v_is_authorized
        FROM public.admin_profiles
        WHERE id = v_actor_id AND role IN ('admin', 'owner');
    END IF;

    IF NOT v_is_authorized THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Acceso denegado a este producto',
            'code', 'FORBIDDEN'
        );
    END IF;

    -- Registrar movimiento (ahora inyectando los datos del proveedor y costo real)
    INSERT INTO public.inventory_movements (
        product_id, movement_type, quantity, reason, created_by,
        unit_cost, supplier_id, payment_type, invoice_reference, reference_invoice_id
    ) VALUES (
        p_product_id, 'entrada', p_quantity, p_reason, v_actor_id,
        p_purchase_price, p_supplier_id, p_payment_type, p_invoice_reference, p_reference_invoice_id
    );

    -- NOTA CRÍTICA: Se ELIMINÓ el INSERT a public.inventory_batches aquí.
    -- El responsable de crear el lote y la factura es el TRIGGER bridge_movement_to_batch.

    RETURN jsonb_build_object('success', true);

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM,
        'code', SQLSTATE
    );
END;
$$;

-- 3. Modificar Trigger bridge_movement_to_batch para leer costo de la transacción
CREATE OR REPLACE FUNCTION public.bridge_movement_to_batch()
RETURNS TRIGGER AS $FUNC$
DECLARE
    v_cost DECIMAL;
    v_batch_record RECORD;
    v_total_value DECIMAL(12,0) := 0;
    v_supplier_freq INT;
    v_remaining_deduction DECIMAL(12,0);
    v_store_id UUID;
    v_invoice RECORD;
BEGIN
    SELECT store_id INTO v_store_id FROM public.products WHERE id = NEW.product_id;

    CASE NEW.movement_type
        WHEN 'entrada' THEN
            -- Leer el costo REAL de la transacción inyectado por el RPC, con fallback
            v_cost := COALESCE(NEW.unit_cost, (SELECT cost_price FROM public.products WHERE id = NEW.product_id), 0);
            
            INSERT INTO public.inventory_batches (product_id, quantity_initial, quantity_remaining, cost_unit, created_by, source_movement_id) 
            VALUES (NEW.product_id, NEW.quantity, NEW.quantity, v_cost, NEW.created_by, NEW.id);
            
            v_total_value := NEW.quantity * v_cost;

        WHEN 'devolucion', 'salida' THEN
            FOR v_batch_record IN SELECT * FROM public.consume_stock_fifo(NEW.product_id, NEW.quantity) LOOP
                INSERT INTO public.inventory_movement_batches (movement_id, batch_id, quantity_consumed, unit_cost)
                VALUES (NEW.id, v_batch_record.batch_id, v_batch_record.quantity_taken, v_batch_record.cost_unit);
                
                v_total_value := v_total_value + (v_batch_record.quantity_taken * v_batch_record.cost_unit);
            END LOOP;

        WHEN 'CORRECCION_SISTEMA' THEN
            IF NEW.quantity > 0 THEN
                v_cost := COALESCE((SELECT cost_price FROM public.products WHERE id = NEW.product_id), 0);
                INSERT INTO public.inventory_batches (product_id, quantity_initial, quantity_remaining, cost_unit, created_by, source_movement_id) 
                VALUES (NEW.product_id, NEW.quantity, NEW.quantity, v_cost, NEW.created_by, NEW.id);
            ELSE
                PERFORM public.consume_stock_fifo(NEW.product_id, ABS(NEW.quantity));
            END IF;
            
        WHEN 'venta' THEN
            NULL;

        ELSE NULL;
    END CASE;

    IF NEW.supplier_id IS NOT NULL THEN
        IF NEW.movement_type = 'entrada' AND NEW.payment_type = 'credito' THEN
            SELECT frequency_days INTO v_supplier_freq FROM public.suppliers WHERE id = NEW.supplier_id;
            INSERT INTO public.supplier_invoices (store_id, supplier_id, total_amount, due_date)
            VALUES (
                v_store_id,
                NEW.supplier_id, v_total_value, CURRENT_DATE + COALESCE(v_supplier_freq, 15)
            );
            
        ELSIF NEW.movement_type IN ('devolucion', 'salida') THEN
            v_remaining_deduction := v_total_value; 
            
            IF NEW.reference_invoice_id IS NOT NULL THEN
                SELECT * INTO v_invoice FROM public.supplier_invoices WHERE id = NEW.reference_invoice_id FOR UPDATE;
                IF NOT FOUND THEN
                    RAISE EXCEPTION 'Factura referenciada no existe.';
                END IF;

                IF v_invoice.supplier_id != NEW.supplier_id THEN
                    RAISE EXCEPTION 'La factura referenciada pertenece a otro proveedor.';
                END IF;

                IF v_invoice.amount_paid >= v_invoice.total_amount THEN
                    RAISE EXCEPTION 'La factura seleccionada ya se encuentra pagada.';
                END IF;
                
                IF v_remaining_deduction <= (v_invoice.total_amount - v_invoice.amount_paid) THEN
                    UPDATE public.supplier_invoices 
                    SET amount_paid = amount_paid + v_remaining_deduction
                    WHERE id = v_invoice.id;
                    v_remaining_deduction := 0;
                ELSE
                    v_remaining_deduction := v_remaining_deduction - (v_invoice.total_amount - v_invoice.amount_paid);
                    UPDATE public.supplier_invoices 
                    SET amount_paid = total_amount
                    WHERE id = v_invoice.id;
                END IF;
            END IF;

            IF v_remaining_deduction > 0 THEN
                FOR v_invoice IN 
                    SELECT * FROM public.supplier_invoices 
                    WHERE supplier_id = NEW.supplier_id 
                      AND store_id = v_store_id
                      AND amount_paid < total_amount
                    ORDER BY due_date ASC, created_at ASC
                    FOR UPDATE
                LOOP
                    IF v_remaining_deduction <= (v_invoice.total_amount - v_invoice.amount_paid) THEN
                        UPDATE public.supplier_invoices 
                        SET amount_paid = amount_paid + v_remaining_deduction
                        WHERE id = v_invoice.id;
                        v_remaining_deduction := 0;
                        EXIT;
                    ELSE
                        v_remaining_deduction := v_remaining_deduction - (v_invoice.total_amount - v_invoice.amount_paid);
                        UPDATE public.supplier_invoices 
                        SET amount_paid = total_amount
                        WHERE id = v_invoice.id;
                    END IF;
                END LOOP;
                
                IF v_remaining_deduction > 0 THEN
                    INSERT INTO public.notifications (store_id, title, message, type, audience, metadata)
                    VALUES (
                        v_store_id, 
                        'Remanente a favor de Devolución', 
                        'Una devolución reciente generó un saldo a favor de ' || v_remaining_deduction || ' ya que superaba las deudas pendientes.', 
                        'finance', 
                        'admin',
                        jsonb_build_object(
                            'supplier_id', NEW.supplier_id,
                            'remaining_amount', v_remaining_deduction
                        )
                    );
                END IF;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$FUNC$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';

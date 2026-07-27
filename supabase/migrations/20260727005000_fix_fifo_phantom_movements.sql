-- Fix: Triggers FIFO ignorando movimientos fantasma y perdiendo trazabilidad
-- Autor: Antigravity
-- Ref: Auditoría QA - Reparación de la función bridge_movement_to_batch

CREATE OR REPLACE FUNCTION public.bridge_movement_to_batch()
RETURNS TRIGGER AS $FUNC$
DECLARE
    v_cost DECIMAL;
    v_sale_price DECIMAL;
    v_batch_record RECORD;
    v_total_value DECIMAL(12,0) := 0;
    v_supplier_freq INT;
    v_remaining_deduction DECIMAL(12,0);
    v_store_id UUID;
    v_invoice RECORD;
BEGIN
    SELECT store_id INTO v_store_id FROM public.products WHERE id = NEW.product_id;

    -- FASE 1: GESTIÓN DE LOTES (FIFO)
    CASE NEW.movement_type
        WHEN 'entrada' THEN
            v_cost := COALESCE(NEW.unit_cost, (SELECT cost_price FROM public.products WHERE id = NEW.product_id), 0);
            v_sale_price := COALESCE((SELECT price FROM public.products WHERE id = NEW.product_id), 0);
            
            INSERT INTO public.inventory_batches (product_id, quantity_initial, quantity_remaining, cost_unit, sale_price, created_by, source_movement_id) 
            VALUES (NEW.product_id, NEW.quantity, NEW.quantity, v_cost, v_sale_price, NEW.created_by, NEW.id);
            
            v_total_value := NEW.quantity * v_cost;

        -- Se añade 'merma' para asegurar que consuma stock físico de los lotes
        WHEN 'devolucion', 'salida', 'merma' THEN
            FOR v_batch_record IN SELECT * FROM public.consume_stock_fifo(NEW.product_id, NEW.quantity) LOOP
                INSERT INTO public.inventory_movement_batches (movement_id, batch_id, quantity_consumed, unit_cost)
                VALUES (NEW.id, v_batch_record.batch_id, v_batch_record.quantity_taken, v_batch_record.cost_unit);
                
                v_total_value := v_total_value + (v_batch_record.quantity_taken * v_batch_record.cost_unit);
            END LOOP;

        -- Se unifica 'ajuste' con 'CORRECCION_SISTEMA' y se arregla la trazabilidad en consumos negativos
        WHEN 'ajuste', 'CORRECCION_SISTEMA' THEN
            IF NEW.quantity > 0 THEN
                v_cost := COALESCE((SELECT cost_price FROM public.products WHERE id = NEW.product_id), 0);
                v_sale_price := COALESCE((SELECT price FROM public.products WHERE id = NEW.product_id), 0);
                
                INSERT INTO public.inventory_batches (product_id, quantity_initial, quantity_remaining, cost_unit, sale_price, created_by, source_movement_id) 
                VALUES (NEW.product_id, NEW.quantity, NEW.quantity, v_cost, v_sale_price, NEW.created_by, NEW.id);
            ELSE
                FOR v_batch_record IN SELECT * FROM public.consume_stock_fifo(NEW.product_id, ABS(NEW.quantity)) LOOP
                    INSERT INTO public.inventory_movement_batches (movement_id, batch_id, quantity_consumed, unit_cost)
                    VALUES (NEW.id, v_batch_record.batch_id, v_batch_record.quantity_taken, v_batch_record.cost_unit);
                    
                    v_total_value := v_total_value + (v_batch_record.quantity_taken * v_batch_record.cost_unit);
                END LOOP;
            END IF;
            
        WHEN 'venta' THEN
            NULL; -- La venta tiene su propio flujo a través de rpc_procesar_venta_v2

        ELSE NULL;
    END CASE;

    -- FASE 2: CUENTAS POR PAGAR (Solo aplica si hay proveedor involucrado)
    IF NEW.supplier_id IS NOT NULL THEN
        IF NEW.movement_type = 'entrada' AND NEW.payment_type = 'credito' THEN
            SELECT frequency_days INTO v_supplier_freq FROM public.suppliers WHERE id = NEW.supplier_id;
            INSERT INTO public.supplier_invoices (store_id, supplier_id, total_amount, due_date)
            VALUES (
                v_store_id,
                NEW.supplier_id, v_total_value, CURRENT_DATE + COALESCE(v_supplier_freq, 15)
            );
            
        -- CRÍTICO: Aquí NO se incluye 'merma' ni 'ajuste' porque no deben reducir la deuda al proveedor. 
        -- Las mermas son pérdidas internas, no devoluciones.
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

-- DDL
CREATE TABLE IF NOT EXISTS public.supplier_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    supplier_id UUID NOT NULL REFERENCES public.suppliers(id) ON DELETE RESTRICT,
    total_amount DECIMAL(12,0) NOT NULL CHECK (total_amount >= 0),
    amount_paid DECIMAL(12,0) NOT NULL DEFAULT 0 CHECK (amount_paid >= 0),
    due_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    
    CHECK (amount_paid <= total_amount)
);

ALTER TABLE public.inventory_movements 
ADD COLUMN IF NOT EXISTS reference_invoice_id UUID REFERENCES public.supplier_invoices(id) ON DELETE RESTRICT;

ALTER TABLE public.inventory_batches
ADD COLUMN IF NOT EXISTS source_movement_id UUID REFERENCES public.inventory_movements(id) ON DELETE RESTRICT;

DO $$ BEGIN
    ALTER TABLE public.inventory_movements
    ADD CONSTRAINT chk_correccion_no_supplier 
    CHECK (movement_type != 'CORRECCION_SISTEMA' OR supplier_id IS NULL);
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_supplier_invoices_supplier_id ON public.supplier_invoices(supplier_id);
CREATE INDEX IF NOT EXISTS idx_supplier_invoices_due_date ON public.supplier_invoices(due_date);
CREATE INDEX IF NOT EXISTS idx_supplier_invoices_store_id ON public.supplier_invoices(store_id);
CREATE INDEX IF NOT EXISTS idx_products_store_id ON public.products(store_id);

DO $$ BEGIN
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
        ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}'::jsonb;
    END IF;
END $$;

ALTER TABLE public.supplier_invoices ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Users can view invoices from their store"
    ON public.supplier_invoices
    FOR SELECT
    USING (store_id IN (
        SELECT s.id FROM public.stores s 
        INNER JOIN public.employees e ON e.store_id = s.id 
        WHERE e.id = auth.uid()
    ));
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;

DO $$ BEGIN
    CREATE POLICY "Admins can manage invoices"
    ON public.supplier_invoices
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.employees 
            WHERE id = auth.uid() AND (permissions->>'isAdmin')::boolean = true AND store_id = supplier_invoices.store_id
        )
    );
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.inventory_movement_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    movement_id UUID NOT NULL REFERENCES public.inventory_movements(id) ON DELETE CASCADE,
    batch_id UUID NOT NULL REFERENCES public.inventory_batches(id) ON DELETE RESTRICT,
    quantity_consumed DECIMAL(10,2) NOT NULL,
    unit_cost DECIMAL(12,0) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_movement_batches_mov ON public.inventory_movement_batches(movement_id);

ALTER TABLE public.inventory_movement_batches ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "movement_batches_select_store" ON public.inventory_movement_batches
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.inventory_movements m 
            INNER JOIN public.products p ON p.id = m.product_id
            INNER JOIN public.employees e ON e.store_id = p.store_id
            WHERE m.id = movement_id AND e.id = auth.uid()
        )
    );
EXCEPTION WHEN duplicate_object THEN
    NULL;
END $$;

-- TRIGGER
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
            v_cost := COALESCE((SELECT cost_price FROM public.products WHERE id = NEW.product_id), 0);
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
            END IF;

            IF v_remaining_deduction > 0 THEN
                INSERT INTO public.notifications (store_id, type, title, message, audience, is_read, created_at, metadata)
                VALUES (
                    v_store_id,
                    'finance',
                    'Saldo a favor con Proveedor',
                    'Se ha generado un saldo a favor con el proveedor por devolución de mercancía.',
                    'admin',
                    FALSE,
                    NOW(),
                    jsonb_build_object('supplier_id', NEW.supplier_id, 'remanente', v_remaining_deduction)
                );
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$FUNC$ LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public';


-- RPC
CREATE OR REPLACE FUNCTION public.rpc_pay_supplier_invoice(
    p_invoice_id UUID,
    p_amount DECIMAL(12,0)
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $FUNC$
DECLARE
    v_invoice RECORD;
    v_active_cash_session UUID;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'El monto del abono debe ser mayor a cero.';
    END IF;

    SELECT * INTO v_invoice FROM public.supplier_invoices WHERE id = p_invoice_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Factura no encontrada.';
    END IF;

    PERFORM public.assert_store_access(v_invoice.store_id);
    
    IF p_amount > (v_invoice.total_amount - v_invoice.amount_paid) THEN
        RAISE EXCEPTION 'El abono supera el saldo pendiente de la factura.';
    END IF;

    SELECT id INTO v_active_cash_session FROM public.cash_sessions 
    WHERE store_id = v_invoice.store_id AND status = 'open' LIMIT 1;
    
    IF v_active_cash_session IS NULL THEN
        RAISE EXCEPTION 'No hay un turno de caja abierto para registrar el egreso.';
    END IF;

    INSERT INTO public.cash_movements (session_id, movement_type, amount, reason, created_by)
    VALUES (v_active_cash_session, 'pago_proveedor', p_amount, 'Abono Factura ' || v_invoice.id, auth.uid());

    UPDATE public.supplier_invoices 
    SET amount_paid = amount_paid + p_amount
    WHERE id = p_invoice_id;
END;
$FUNC$;

GRANT EXECUTE ON FUNCTION public.rpc_pay_supplier_invoice TO authenticated;

-- Modificación rpc_check_and_force_close_shifts
CREATE OR REPLACE FUNCTION rpc_check_and_force_close_shifts()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $FUNC$
DECLARE
    r RECORD;
    v_ingresos DECIMAL;
    v_gastos DECIMAL;
    v_expected DECIMAL;
    closed_count INT := 0;
BEGIN
    FOR r IN 
        SELECT id, store_id, opening_balance, opened_at 
        FROM public.cash_sessions 
        WHERE status = 'open' 
          AND opened_at < (NOW() - INTERVAL '24 hours')
    LOOP
        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type = 'ingreso';
        
        SELECT COALESCE(SUM(amount), 0) INTO v_gastos
        FROM public.cash_movements
        WHERE session_id = r.id AND movement_type IN ('gasto', 'pago_proveedor');
        
        v_expected := r.opening_balance + v_ingresos - v_gastos;

        UPDATE public.cash_sessions 
        SET status         = 'closed',
            forced_close   = true,
            expected_balance = v_expected,
            actual_balance = NULL,
            difference     = NULL,
            closed_at      = NOW()
        WHERE id = r.id;

        INSERT INTO public.audit_logs (
            store_id, action, entity, entity_id, payload, created_at
        ) VALUES (
            r.store_id,
            'FORCED_CLOSE_24H',
            'cash_sessions',
            r.id,
            jsonb_build_object(
                'reason',           'Shift exceeded 24 hours without manual closure',
                'opened_at',        r.opened_at,
                'forced_at',        NOW(),
                'expected_balance', v_expected
            ),
            NOW()
        );

        INSERT INTO public.notifications (
            store_id, type, title, message, audience, is_read, created_at
        ) VALUES (
            r.store_id,
            'finance',
            '⚠️ Cierre Forzado de Caja (24 Horas)',
            'Una caja fue cerrada automáticamente por el sistema tras cumplir 24 horas abierta. Se requiere verificación de saldo antes de iniciar nuevo turno.',
            'admin',
            FALSE,
            NOW()
        );

        closed_count := closed_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', true, 'closed_shifts', closed_count);
END;
$FUNC$;

GRANT EXECUTE ON FUNCTION rpc_check_and_force_close_shifts() TO authenticated;

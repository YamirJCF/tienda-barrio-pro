-- ==============================================================================
-- MIGRATION: FINANCIAL CORE (ARCH-004)
-- Description: Implement Atomic Sales, Client Ledger, and Strict Permissions.
-- ==============================================================================

-- 1. CLIENT LEDGER (El 'Block' de la Deuda)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.client_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.clients(id),
    store_id UUID NOT NULL REFERENCES public.stores(id),
    amount DECIMAL(12, 0) NOT NULL, -- Positivo = Cargo (Deuda), Negativo = Abono (Pago)
    previous_balance DECIMAL(12, 0) NOT NULL DEFAULT 0,
    new_balance DECIMAL(12, 0) NOT NULL GENERATED ALWAYS AS (previous_balance + amount) STORED,
    reference_id UUID NOT NULL, -- ID de Venta o ID de Pago
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('venta_fiado', 'abono', 'anulacion_fiado')),
    created_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID REFERENCES public.employees(id)
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_ledger_client ON public.client_ledger(client_id);
CREATE INDEX IF NOT EXISTS idx_ledger_store ON public.client_ledger(store_id);

-- RLS: Read Only for Employees, No Update/Delete EVER
ALTER TABLE public.client_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ledger_read_store" ON public.client_ledger
    FOR SELECT USING (store_id = public.get_current_store_id());

-- 2. HARDENED PRODUCTS RLS (Fix Audit 006)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "products_delete_store" ON public.products;

CREATE POLICY "products_delete_admin_only" ON public.products
    FOR DELETE
    USING (
        store_id = public.get_current_store_id() 
        AND (
            EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()) OR
            auth.jwt() ->> 'role' = 'service_role'
        )
    );

-- 3. RPC: ANULAR VENTA (Fix Audit 007)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_anular_venta(
    p_sale_id UUID,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
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

-- 4. RPC: PROCESAR VENTA V2 (TRUST NO ONE - ATOMIC)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_procesar_venta_v2(
    p_store_id UUID,
    p_client_id UUID,        -- Puede ser NULL
    p_payment_method TEXT,   -- 'efectivo', 'nequi', 'fiado'
    p_amount_received DECIMAL, -- Solo informativo para frontend, backend recalcula
    p_items JSONB            -- [{product_id, quantity}] precio NO se recibe
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
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

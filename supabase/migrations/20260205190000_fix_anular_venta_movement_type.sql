-- ==============================================================================
-- MIGRATION: Fix rpc_anular_venta movement_type
-- Date: 2026-02-05
-- Issue: Uses 'salida' but constraint only allows 'ingreso' or 'gasto'
-- DICT: DICT-001 Cash Movements (official terminology)
-- ==============================================================================

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
            'devolucion',
            v_item.quantity,
            'ANULACION VENTA #' || v_sale.ticket_number,
            auth.uid()
        );
    END LOOP;

    -- 4. Revertir Dinero: FIXED - Changed 'salida' to 'gasto' per DICT-001
    IF v_sale.payment_method = 'efectivo' OR v_sale.payment_method = 'cash' THEN
         INSERT INTO public.cash_movements (
            session_id, movement_type, amount, description, sale_id
         ) 
         SELECT id, 'gasto', v_sale.total, 'REVERSO VENTA #' || v_sale.ticket_number, p_sale_id
         FROM public.cash_sessions 
         WHERE store_id = v_store_id AND status = 'open'
         LIMIT 1;
    END IF;

    -- 5. Si fue FIADO → Registrar abono en Ledger y Cliente
    IF v_sale.payment_method = 'fiado' AND v_sale.client_id IS NOT NULL THEN
        INSERT INTO public.client_ledger (
            client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by
        )
        SELECT 
            v_sale.client_id,
            v_store_id,
            -1 * v_sale.total, -- Negativo porque reduce la deuda
            (SELECT balance FROM public.clients WHERE id = v_sale.client_id),
            p_sale_id,
            'anulacion_fiado',
            auth.uid();
        
        UPDATE public.clients 
        SET balance = balance - v_sale.total 
        WHERE id = v_sale.client_id;
    END IF;

    -- 6. Marcar Venta como Anulada
    UPDATE public.sales 
    SET is_voided = true, 
        voided_by = auth.uid(), 
        void_reason = p_reason 
    WHERE id = p_sale_id;

    RETURN jsonb_build_object('success', true, 'message', 'Venta anulada exitosamente');

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

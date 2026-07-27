-- ==============================================================================
-- MIGRATION: SECURE RPC PAY SUPPLIER INVOICE
-- Añade validación estricta de seguridad al RPC para requerir rol de Administrador.
-- Actualiza el constraint de movement_type para permitir 'pago_proveedor'.
-- Cierra la vulnerabilidad detectada en UXD/QA (SECURITY DEFINER sin check de rol).
-- ==============================================================================

ALTER TABLE public.cash_movements DROP CONSTRAINT IF EXISTS cash_movements_movement_type_check;
ALTER TABLE public.cash_movements ADD CONSTRAINT cash_movements_movement_type_check CHECK (movement_type IN ('ingreso', 'gasto', 'pago_proveedor'));

CREATE OR REPLACE FUNCTION public.rpc_pay_supplier_invoice(
    p_invoice_id UUID,
    p_amount DECIMAL(12,0)
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_invoice RECORD;
    v_active_cash_session UUID;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'El monto del abono debe ser mayor a cero.';
    END IF;

    -- Validar Factura y saldo
    SELECT * INTO v_invoice FROM public.supplier_invoices WHERE id = p_invoice_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Factura no encontrada.';
    END IF;

    -- [SEGURIDAD NIVEL 1] Validar que el usuario pertenece a la tienda
    PERFORM public.assert_store_access(v_invoice.store_id);

    -- [SEGURIDAD NIVEL 2] Validar rol de Administrador (Mitigación del agujero de seguridad)
    IF NOT EXISTS (
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid() AND store_id = v_invoice.store_id
    ) THEN
        RAISE EXCEPTION 'No tienes permisos de Administrador para registrar pagos a proveedores.';
    END IF;
    
    -- Validar turno de caja abierto
    SELECT id INTO v_active_cash_session 
    FROM public.cash_sessions 
    WHERE store_id = v_invoice.store_id AND status = 'open'
    LIMIT 1;

    IF v_active_cash_session IS NULL THEN
        RAISE EXCEPTION 'No hay un turno de caja abierto para registrar el egreso.';
    END IF;

    -- Validar monto máximo a abonar
    IF p_amount > (v_invoice.total_amount - v_invoice.amount_paid) THEN
        RAISE EXCEPTION 'El abono supera el saldo pendiente de la factura.';
    END IF;

    -- 1. Actualizar Factura
    UPDATE public.supplier_invoices
    SET amount_paid = amount_paid + p_amount
    WHERE id = p_invoice_id;

    -- 2. Registrar movimiento de caja (Egreso: pago_proveedor)
    INSERT INTO public.cash_movements (
        session_id, movement_type, amount, description
    ) VALUES (
        v_active_cash_session,
        'pago_proveedor',
        p_amount,
        'Abono a factura de proveedor (ID: ' || p_invoice_id || ')'
    );
END;
$$;

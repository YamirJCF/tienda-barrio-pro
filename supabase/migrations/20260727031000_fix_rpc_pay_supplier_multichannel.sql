-- ==============================================================================
-- MIGRATION: FIX RPC PAY SUPPLIER INVOICE (MULTICHANNEL)
-- Añade soporte para 'p_payment_method' para alinear con el frontend.
-- Protege la caja física: solo descuenta efectivo de la caja.
-- ==============================================================================

-- 1. Eliminar la versión antigua de 2 parámetros para evitar ambigüedades
DROP FUNCTION IF EXISTS public.rpc_pay_supplier_invoice(UUID, DECIMAL);

-- 2. Crear la nueva versión de 3 parámetros
CREATE OR REPLACE FUNCTION public.rpc_pay_supplier_invoice(
    p_invoice_id UUID,
    p_amount DECIMAL(12,0),
    p_payment_method TEXT
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

    -- [SEGURIDAD NIVEL 2] Validar rol de Administrador
    IF NOT EXISTS (
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid() AND store_id = v_invoice.store_id
    ) THEN
        RAISE EXCEPTION 'No tienes permisos de Administrador para registrar pagos a proveedores.';
    END IF;

    -- Validar monto máximo a abonar
    IF p_amount > (v_invoice.total_amount - v_invoice.amount_paid) THEN
        RAISE EXCEPTION 'El abono supera el saldo pendiente de la factura.';
    END IF;

    -- Lógica de caja física: solo se requiere caja abierta si el pago es en EFECTIVO
    IF p_payment_method IN ('efectivo', 'cash') THEN
        -- Validar turno de caja abierto
        SELECT id INTO v_active_cash_session 
        FROM public.cash_sessions 
        WHERE store_id = v_invoice.store_id AND status = 'open'
        LIMIT 1;

        IF v_active_cash_session IS NULL THEN
            RAISE EXCEPTION 'No hay un turno de caja abierto para registrar el egreso en efectivo.';
        END IF;

        -- Registrar movimiento de caja (Egreso: pago_proveedor)
        INSERT INTO public.cash_movements (
            session_id, movement_type, amount, description
        ) VALUES (
            v_active_cash_session,
            'pago_proveedor',
            p_amount,
            'Abono a factura de proveedor (ID: ' || p_invoice_id || ') [Efectivo]'
        );
    END IF;

    -- Actualizar Factura
    UPDATE public.supplier_invoices
    SET amount_paid = amount_paid + p_amount
    WHERE id = p_invoice_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_pay_supplier_invoice TO authenticated;

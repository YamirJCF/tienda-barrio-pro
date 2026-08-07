-- Implementación de Soft Delete y mutación de PLU para productos
-- Autor: Antigravity

-- 1. Agregar columna is_active
ALTER TABLE public.products ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT true;

-- 2. Eliminar constraint existente y crear índice parcial para PLU
ALTER TABLE public.products DROP CONSTRAINT IF EXISTS products_store_id_plu_key;
CREATE UNIQUE INDEX products_plu_active_idx ON public.products (store_id, plu) WHERE is_active = true;

-- 3. Crear RPC para borrado lógico y mutación
CREATE OR REPLACE FUNCTION public.rpc_soft_delete_product(p_product_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_stock NUMERIC;
    v_pending_invoices BOOLEAN;
    v_store_id UUID;
    v_product_name TEXT;
BEGIN
    -- Validar que el producto existe y obtener su información
    SELECT current_stock, store_id, name 
    INTO v_current_stock, v_store_id, v_product_name
    FROM public.products 
    WHERE id = p_product_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Producto no encontrado.'
        );
    END IF;

    -- Regla 1: Validar si existen deudas vinculadas a este producto a través de inventory_movements
    -- Esto verifica movimientos de entrada atados a supplier_invoices con saldo pendiente
    SELECT EXISTS (
        SELECT 1 
        FROM public.inventory_movements im
        JOIN public.supplier_invoices si ON im.reference_invoice_id = si.id
        WHERE im.product_id = p_product_id
          AND LOWER(im.movement_type) = 'entrada'
          AND si.amount_paid < si.total_amount
    ) INTO v_pending_invoices;

    IF v_pending_invoices THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'El producto está vinculado a una cuenta por pagar pendiente. Debe saldar la deuda con el proveedor antes de eliminarlo.',
            'code', 'PENDING_PAYABLES'
        );
    END IF;

    -- Regla 2: Validar si hay existencias (Stock)
    IF v_current_stock > 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'El producto tiene existencias. Debe registrar un Ajuste de Salida manualmente para contabilizar la pérdida en el Kardex antes de eliminarlo.',
            'code', 'STOCK_REMAINING'
        );
    END IF;

    -- Regla 3 y 4: Mutación de Naturaleza y Liberación de PLU
    UPDATE public.products 
    SET 
        is_active = false,
        plu = 'DEL-' || substr(id::text, 1, 8),
        name = '[ELIMINADO] ' || v_product_name
    WHERE id = p_product_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', p_product_id,
        'error', NULL
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

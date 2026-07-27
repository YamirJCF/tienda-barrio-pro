-- Fix: RLS en Salidas y Ajustes de Inventario
-- Autor: Antigravity
-- Ref: QA identificó violación de RLS 42501 al hacer 'salida' o 'ajuste'
-- Razón: La política INSERT en inventory_movements fue eliminada previamente.

CREATE OR REPLACE FUNCTION public.rpc_registrar_movimiento_inventario(
    p_product_id    UUID,
    p_movement_type TEXT,
    p_quantity      DECIMAL,
    p_reason        TEXT DEFAULT NULL,
    p_supplier_id   UUID DEFAULT NULL,
    p_payment_type  TEXT DEFAULT NULL,
    p_invoice_reference TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $FUNC$
DECLARE
    v_store_id UUID;
    v_actor_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
BEGIN
    IF v_actor_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No autorizado', 'code', 'UNAUTHORIZED');
    END IF;

    -- Validar que la cantidad no sea nula y tenga sentido (para ajustes puede ser negativa)
    IF p_quantity = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'La cantidad no puede ser cero', 'code', 'INVALID_QUANTITY');
    END IF;

    -- Validar que el tipo de movimiento sea correcto
    IF p_movement_type NOT IN ('salida', 'devolucion', 'merma', 'ajuste', 'CORRECCION_SISTEMA') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Tipo de movimiento no válido para esta función', 'code', 'INVALID_MOVEMENT_TYPE');
    END IF;

    -- Obtener la tienda del producto
    SELECT store_id INTO v_store_id FROM public.products WHERE id = p_product_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Producto no encontrado', 'code', 'NOT_FOUND');
    END IF;

    -- Verificar permisos (empleado de la tienda o admin/owner)
    SELECT TRUE INTO v_is_authorized FROM public.employees WHERE id = v_actor_id AND store_id = v_store_id;
    IF NOT FOUND OR NOT v_is_authorized THEN
        SELECT TRUE INTO v_is_authorized FROM public.admin_profiles WHERE id = v_actor_id AND role IN ('admin', 'owner');
    END IF;

    IF NOT v_is_authorized THEN
        RETURN jsonb_build_object('success', false, 'error', 'Acceso denegado a este producto', 'code', 'FORBIDDEN');
    END IF;

    -- Registrar el movimiento
    INSERT INTO public.inventory_movements (
        product_id, movement_type, quantity, reason, created_by,
        supplier_id, payment_type, invoice_reference
    ) VALUES (
        p_product_id, p_movement_type, p_quantity, p_reason, v_actor_id,
        p_supplier_id, p_payment_type, p_invoice_reference
    );

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM, 'code', SQLSTATE);
END;
$FUNC$;

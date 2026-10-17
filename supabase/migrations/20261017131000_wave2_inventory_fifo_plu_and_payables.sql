-- Migration: Wave 2 - Inventory, FIFO Batch Traceability, PLU POS Search, and Soft Delete
-- Author: Data Architect (@[/data]) & Tech Lead (@[/orchestrator])
-- Certified SDDs: SDD_006_PADRE, SDD_006_01_01, SDD_006_02, SDD_006_03, SDD_010, SDD_010_016, SDD_019

-- ==============================================================================
-- 1. Permisos Base en Tablas de Inventario y Lotes FIFO (Regla 8 AGENTS.md)
-- ==============================================================================

GRANT ALL ON TABLE public.products TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.inventory_batches TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.sale_item_batches TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.inventory_movements TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.supplier_invoices TO anon, authenticated, service_role;

-- ==============================================================================
-- 2. RPC: buscar_producto_pos (Búsqueda Unificada de Alta Velocidad para POS)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.buscar_producto_pos(
    p_store_id UUID,
    p_term TEXT,
    p_limit INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_clean_term TEXT := TRIM(p_term);
    v_is_numeric BOOLEAN;
    v_exact RECORD;
    v_results JSONB;
    v_count INTEGER;
BEGIN
    -- 1. Validación obligatoria de aislamiento multi-tenant (Regla 4 AGENTS.md)
    PERFORM public.assert_store_access(p_store_id);

    IF v_clean_term IS NULL OR LENGTH(v_clean_term) = 0 THEN
        RETURN jsonb_build_object('data', '[]'::jsonb, 'count', 0, 'match_type', 'none');
    END IF;

    -- Verificar si es numérico puro (código PLU o código de barras)
    v_is_numeric := (v_clean_term ~ '^[0-9]+$');

    -- 2. Coincidencia exacta por PLU (prioritaria O(1) con índice parcial)
    SELECT id, name, plu, price, current_stock, measurement_unit, is_weighable
    INTO v_exact
    FROM public.products
    WHERE store_id = p_store_id
      AND is_active = true
      AND plu = v_clean_term
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'data', jsonb_build_array(jsonb_build_object(
                'id', v_exact.id,
                'name', v_exact.name,
                'plu', v_exact.plu,
                'price', v_exact.price,
                'current_stock', v_exact.current_stock,
                'measurement_unit', v_exact.measurement_unit,
                'is_weighable', v_exact.is_weighable
            )),
            'count', 1,
            'match_type', 'exact_plu'
        );
    END IF;

    -- Si el término fue numérico pero no hubo match de PLU
    IF v_is_numeric THEN
        RETURN jsonb_build_object('data', '[]'::jsonb, 'count', 0, 'match_type', 'not_found');
    END IF;

    -- 3. Coincidencia parcial por nombre (mínimo 2 caracteres)
    IF LENGTH(v_clean_term) < 2 THEN
        RAISE EXCEPTION 'TERM_TOO_SHORT: Ingrese al menos 2 caracteres para buscar por nombre.'
            USING ERRCODE = '22023';
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM public.products
    WHERE store_id = p_store_id
      AND is_active = true
      AND current_stock > 0
      AND name ILIKE ('%' || v_clean_term || '%');

    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb) INTO v_results
    FROM (
        SELECT id, name, plu, price, current_stock, measurement_unit, is_weighable
        FROM public.products
        WHERE store_id = p_store_id
          AND is_active = true
          AND current_stock > 0
          AND name ILIKE ('%' || v_clean_term || '%')
        ORDER BY name ASC
        LIMIT LEAST(p_limit, 50)
        OFFSET p_offset
    ) sub;

    RETURN jsonb_build_object(
        'data', v_results,
        'count', v_count,
        'match_type', 'partial_name'
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.buscar_producto_pos TO authenticated, service_role;

-- ==============================================================================
-- 3. RPC: rpc_soft_delete_product (Baja Lógica y Liberación de PLU Saneada)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.rpc_soft_delete_product(p_product_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_current_stock NUMERIC;
    v_store_id UUID;
    v_product_name TEXT;
    v_pending_invoices BOOLEAN;
BEGIN
    SELECT current_stock, store_id, name 
    INTO v_current_stock, v_store_id, v_product_name
    FROM public.products 
    WHERE id = p_product_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PRODUCT_NOT_FOUND: El producto especificado (%) no existe.', p_product_id
            USING ERRCODE = 'P0002';
    END IF;

    -- Validación multi-tenant obligatoria (Regla 4)
    PERFORM public.assert_store_access(v_store_id);

    -- Regla 1: Validar si existen deudas vinculadas con saldo pendiente
    SELECT EXISTS (
        SELECT 1 
        FROM public.inventory_movements im
        JOIN public.supplier_invoices si ON im.reference_invoice_id = si.id
        WHERE im.product_id = p_product_id
          AND LOWER(im.movement_type) = 'entrada'
          AND si.amount_paid < si.total_amount
    ) INTO v_pending_invoices;

    IF v_pending_invoices THEN
        RAISE EXCEPTION 'PENDING_PAYABLES: El producto está vinculado a una cuenta por pagar pendiente. Debe saldar la deuda con el proveedor antes de eliminarlo.'
            USING ERRCODE = 'P0001';
    END IF;

    -- Regla 2: Validar si hay existencias físicas en stock
    IF v_current_stock > 0 THEN
        RAISE EXCEPTION 'STOCK_REMAINING: El producto tiene existencias (%). Debe registrar un Ajuste de Salida o Merma antes de darlo de baja.', v_current_stock
            USING ERRCODE = 'P0001';
    END IF;

    -- Regla 3: Mutación de Naturaleza y Liberación de PLU para reciclaje
    UPDATE public.products 
    SET is_active = false,
        plu = 'DEL-' || substr(id::text, 1, 8),
        name = '[ELIMINADO] ' || v_product_name,
        updated_at = now()
    WHERE id = p_product_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'product_id', p_product_id,
            'is_active', false,
            'status', 'deleted'
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_soft_delete_product TO authenticated, service_role;

-- ==============================================================================
-- 4. RPC: rpc_registrar_entrada_masiva (Carga Masiva de Mercancía con Precios)
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.rpc_registrar_entrada_masiva(
    p_store_id UUID,
    p_entries JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_actor_id UUID := auth.uid();
    v_entry JSONB;
    v_product_id UUID;
    v_quantity NUMERIC;
    v_purchase_price NUMERIC;
    v_sale_price NUMERIC;
    v_reason TEXT;
    v_processed_count INTEGER := 0;
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    IF p_entries IS NULL OR jsonb_array_length(p_entries) = 0 THEN
        RAISE EXCEPTION 'EMPTY_ENTRIES: La lista de entradas no puede estar vacía.'
            USING ERRCODE = '22023';
    END IF;

    FOR v_entry IN SELECT * FROM jsonb_array_elements(p_entries) LOOP
        v_product_id := (v_entry->>'product_id')::UUID;
        v_quantity := (v_entry->>'quantity')::NUMERIC;
        v_purchase_price := (v_entry->>'purchase_price')::NUMERIC;
        v_sale_price := (v_entry->>'sale_price')::NUMERIC;
        v_reason := COALESCE(TRIM(v_entry->>'reason'), 'Entrada masiva de mercancía');

        IF v_quantity <= 0 THEN
            RAISE EXCEPTION 'INVALID_QUANTITY: La cantidad para el producto % debe ser mayor a cero.', v_product_id
                USING ERRCODE = '22023';
        END IF;

        IF v_purchase_price < 0 OR v_sale_price < 0 THEN
            RAISE EXCEPTION 'INVALID_PRICE: Los precios de compra y venta deben ser mayores o iguales a cero.'
                USING ERRCODE = '22023';
        END IF;

        -- Validar pertenencia del producto a la tienda
        IF NOT EXISTS (SELECT 1 FROM public.products WHERE id = v_product_id AND store_id = p_store_id) THEN
            RAISE EXCEPTION 'PRODUCT_NOT_FOUND: El producto % no pertenece a la tienda especificada.', v_product_id
                USING ERRCODE = 'P0002';
        END IF;

        -- 1. Actualizar catálogo y registrar en histórico si los precios variaron
        IF EXISTS (SELECT 1 FROM public.products WHERE id = v_product_id AND (price != v_sale_price OR cost_price != v_purchase_price)) THEN
            INSERT INTO public.product_price_history (product_id, purchase_price, sale_price, created_by)
            VALUES (v_product_id, v_purchase_price, v_sale_price, v_actor_id);

            UPDATE public.products 
            SET price = v_sale_price,
                cost_price = v_purchase_price,
                updated_at = now()
            WHERE id = v_product_id;
        END IF;

        -- 2. Registrar movimiento en Kardex
        INSERT INTO public.inventory_movements (
            product_id, movement_type, quantity, reason, created_by, unit_cost
        ) VALUES (
            v_product_id, 'entrada', v_quantity, v_reason, v_actor_id, v_purchase_price
        );

        -- 3. Crear lote FIFO
        INSERT INTO public.inventory_batches (
            product_id, quantity_initial, quantity_remaining, cost_unit, sale_price, created_by
        ) VALUES (
            v_product_id, v_quantity, v_quantity, v_purchase_price, v_sale_price, v_actor_id
        );

        v_processed_count := v_processed_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'processed_count', v_processed_count,
            'timestamp', now()
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_registrar_entrada_masiva TO authenticated, service_role;

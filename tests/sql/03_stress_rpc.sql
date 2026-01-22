-- =============================================
-- 03_stress_rpc.sql
-- Objetivo: Estrés de RPC "Procesar Venta" (WO-5)
-- Descripción: Ejecuta una venta compleja y valida transaccionalidad completa.
-- =============================================

DO $$
DECLARE
    v_store_id UUID;
    v_employee_id UUID;
    v_client_id UUID;
    v_prod1_id UUID;
    v_prod2_id UUID;
    
    v_sale_result JSON;
    v_sale_id UUID;
    
    v_client_balance_before DECIMAL;
    v_client_balance_after DECIMAL;
    v_stock1_before DECIMAL;
    v_stock1_after DECIMAL;
BEGIN
    RAISE NOTICE '=== INICIANDO TEST: Estrés RPC procesar_venta ===';

    -- 1. Setup Datos
    SELECT id INTO v_store_id FROM stores LIMIT 1;
    SELECT id INTO v_employee_id FROM employees WHERE username = 'admin';
    SELECT id, balance INTO v_client_id, v_client_balance_before FROM clients WHERE cedula = 'C002'; -- Cliente Fiador
    
    -- Seleccionar 2 productos con suficiente stock
    SELECT id, current_stock INTO v_prod1_id, v_stock1_before FROM products WHERE current_stock > 10 LIMIT 1;
    SELECT id INTO v_prod2_id FROM products WHERE id != v_prod1_id AND current_stock > 10 LIMIT 1;
    
    IF v_prod1_id IS NULL OR v_prod2_id IS NULL THEN
        RAISE EXCEPTION 'No hay suficientes productos para el test. Ejecuta 00_seed_data.sql primero.';
    END IF;

    RAISE NOTICE 'Cliente Saldo Inicial: %', v_client_balance_before;
    RAISE NOTICE 'Stock Producto 1 Inicial: %', v_stock1_before;

    -- 2. Ejecutar RPC (Simulando Payload JSON del Frontend)
    -- Venta Fiada de 2 items
    
    SELECT procesar_venta(
        v_store_id,
        json_build_array(
            json_build_object(
                'product_id', v_prod1_id,
                'quantity', 5,
                'price', 1000,
                'subtotal', 5000
            ),
            json_build_object(
                'product_id', v_prod2_id,
                'quantity', 2,
                'price', 2000,
                'subtotal', 4000
            )
        )::jsonb, -- Cast a jsonb si la firma lo requiere (schema dice jsonb)
        'fiado', -- Metodo pago
        0, -- Amount received (0 si es fiado)
        v_client_id,
        v_employee_id
    ) INTO v_sale_result;

    RAISE NOTICE 'Resultado RPC: %', v_sale_result;

    -- Validar éxito
    IF (v_sale_result->>'success')::boolean = false THEN
        RAISE EXCEPTION 'RPC Falló: %', v_sale_result;
    END IF;
    
    v_sale_id := (v_sale_result->>'sale_id')::UUID;
    
    -- 3. Validaciones Post-Transaction

    -- A. Verificar Saldo Cliente (Debe haber aumentado en 9000)
    SELECT balance INTO v_client_balance_after FROM clients WHERE id = v_client_id;
    
    IF v_client_balance_after != (v_client_balance_before + 9000) THEN
        RAISE EXCEPTION 'FALLO SALDO: Esperado %, Obtenido %', (v_client_balance_before + 9000), v_client_balance_after;
    ELSE
        RAISE NOTICE '✅ Saldo Cliente actualizado correctamente (Mas deuda).';
    END IF;

    -- B. Verificar Stock Producto 1 (Debe haber disminuido en 5)
    SELECT current_stock INTO v_stock1_after FROM products WHERE id = v_prod1_id;
    
    IF v_stock1_after != (v_stock1_before - 5) THEN
        RAISE EXCEPTION 'FALLO STOCK: Esperado %, Obtenido %', (v_stock1_before - 5), v_stock1_after;
    ELSE
        RAISE NOTICE '✅ Stock descontado correctamente.';
    END IF;

    -- C. Verificar registros creados
    IF NOT EXISTS (SELECT 1 FROM sales WHERE id = v_sale_id) THEN
        RAISE EXCEPTION 'No se creó registro en tabla sales';
    END IF;

    IF (SELECT count(*) FROM sale_items WHERE sale_id = v_sale_id) != 2 THEN
        RAISE EXCEPTION 'No se crearon los 2 items de venta';
    END IF;
    
    IF (SELECT count(*) FROM inventory_movements WHERE sale_id = v_sale_id) != 2 THEN
        RAISE EXCEPTION 'No se crearon los 2 movimientos de inventario';
    END IF;

    RAISE NOTICE '=== TEST RPC VENTA EXITOSO ===';

END $$;

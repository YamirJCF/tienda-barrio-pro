-- =============================================
-- VERIFICACIÓN TÉCNICA FIFO (Server-Side)
-- Ejecutar via MCP execute_sql
-- =============================================

DO $$
DECLARE
    v_store_id UUID;
    v_product_id UUID;
    v_batch1 UUID;
    v_batch2 UUID;
    v_result RECORD;
    v_total_cost DECIMAL := 0;
    v_total_qty DECIMAL := 0;
BEGIN
    RAISE NOTICE '🧪 Iniciando Test FIFO...';
    
    -- 1. Crear Tienda Dummy (o usar existente)
    INSERT INTO public.stores (name, slug, subscription_plan)
    VALUES ('Testers Store', 'test-store-' || gen_random_uuid(), 'free')
    RETURNING id INTO v_store_id;
    
    RAISE NOTICE '✅ Store: %', v_store_id;

    -- 2. Crear Producto
    INSERT INTO public.products (store_id, name, price, cost_price, current_stock, plu)
    VALUES (v_store_id, 'FIFA PROD', 1000, 500, 0, 'TEST-' || gen_random_uuid())
    RETURNING id INTO v_product_id;

    RAISE NOTICE '✅ Product: %', v_product_id;

    -- 3. Crear Lotes (Batches)
    -- Lote A: 10 uds @ $500
    INSERT INTO public.inventory_batches (product_id, quantity_initial, quantity_remaining, cost_unit, created_at)
    VALUES (v_product_id, 10, 10, 500, now() - interval '1 day') -- Older
    RETURNING id INTO v_batch1;

    -- Lote B: 10 uds @ $800
    INSERT INTO public.inventory_batches (product_id, quantity_initial, quantity_remaining, cost_unit, created_at)
    VALUES (v_product_id, 10, 10, 800, now()) -- Newer
    RETURNING id INTO v_batch2;
    
    RAISE NOTICE '✅ Batches Created';

    -- Check Trigger Sync
    IF (SELECT current_stock FROM public.products WHERE id = v_product_id) != 20 THEN
        RAISE EXCEPTION '❌ Trigger de Sincronización Falló (Stock != 20)';
    END IF;
    
    RAISE NOTICE '✅ Trigger OK';

    -- 4. Ejecutar Consumo FIFO (15 unidades)
    FOR v_result IN 
        SELECT * FROM public.consume_stock_fifo(v_product_id, 15)
    LOOP
        v_total_qty := v_total_qty + v_result.quantity_taken;
        v_total_cost := v_total_cost + (v_result.quantity_taken * v_result.cost_unit);
        RAISE NOTICE '   -> Consumed: % from Batch % @ $%', v_result.quantity_taken, v_result.batch_id, v_result.cost_unit;
    END LOOP;

    -- 5. Validaciones
    IF v_total_qty != 15 THEN
        RAISE EXCEPTION '❌ Error Qty: Esperado 15, Real %', v_total_qty;
    END IF;

    -- Costo esperado: (10 * 500) + (5 * 800) = 5000 + 4000 = 9000
    IF v_total_cost != 9000 THEN
        RAISE EXCEPTION '❌ Error Costo FIFO: Esperado $9000, Real $%', v_total_cost;
    END IF;

    RAISE NOTICE '🎉 ÉXITO: La lógica FIFO funciona correctamente.';
    
    -- Limpieza (Rollback user data to keep staging clean-ish, but for now we commit context)
    -- Actually, raise exception to rollback? No, user wants confirmation.
    -- We can delete testing data.
    DELETE FROM public.stores WHERE id = v_store_id; -- Cascade deletes products/batches
    RAISE NOTICE '🧹 Limpieza completada.';

END $$;

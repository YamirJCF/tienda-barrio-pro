-- =============================================
-- 01_inventory_triggers.sql
-- Objetivo: Verificar integridad de inventario (WO-3)
-- Descripción: Inserta movimientos y valida que el stock en 'products' cambie automáticamente.
-- =============================================

DO $$
DECLARE
    v_store_id UUID;
    v_product_id UUID;
    v_employee_id UUID;
    v_initial_stock DECIMAL;
    v_current_stock DECIMAL;
BEGIN
    RAISE NOTICE '=== INICIANDO TEST: Triggers de Inventario ===';

    -- 1. Setup: Obtener IDs de prueba (del script de seeding)
    SELECT id INTO v_store_id FROM stores LIMIT 1;
    SELECT id INTO v_employee_id FROM employees WHERE username = 'admin';
    
    -- Crear un producto nuevo para aislar la prueba
    INSERT INTO products (store_id, name, plu, price, current_stock)
    VALUES (v_store_id, 'Producto Test Trigger', 'TEST001', 1000, 0)
    RETURNING id INTO v_product_id;

    RAISE NOTICE 'Producto creado: %', v_product_id;

    -- =============================================
    -- CASO 1: ENTRADA DE MERCANCÍA (+10)
    -- =============================================
    INSERT INTO inventory_movements (product_id, movement_type, quantity, reason, created_by)
    VALUES (v_product_id, 'entrada', 10, 'Compra Proveedor', v_employee_id);

    -- Verificar
    SELECT current_stock INTO v_current_stock FROM products WHERE id = v_product_id;
    
    IF v_current_stock != 10 THEN
        RAISE EXCEPTION 'FALLO CASO 1: Stock esperado 10, obtenido %', v_current_stock;
    ELSE
        RAISE NOTICE '✅ CASO 1 (Entrada) EXITOSO. Stock: 10';
    END IF;

    -- =============================================
    -- CASO 2: VENTA/SALIDA (-2)
    -- =============================================
    INSERT INTO inventory_movements (product_id, movement_type, quantity, reason, created_by)
    VALUES (v_product_id, 'venta', 2, 'Venta Mostrador', v_employee_id);

    -- Verificar
    SELECT current_stock INTO v_current_stock FROM products WHERE id = v_product_id;
    
    IF v_current_stock != 8 THEN
        RAISE EXCEPTION 'FALLO CASO 2: Stock esperado 8, obtenido %', v_current_stock;
    ELSE
        RAISE NOTICE '✅ CASO 2 (Venta) EXITOSO. Stock: 8';
    END IF;

    -- =============================================
    -- CASO 3: DEVOLUCIÓN CLIENTE (+1)
    -- =============================================
    INSERT INTO inventory_movements (product_id, movement_type, quantity, reason, created_by)
    VALUES (v_product_id, 'devolucion', 1, 'Producto devuelto', v_employee_id);

    -- Verificar
    SELECT current_stock INTO v_current_stock FROM products WHERE id = v_product_id;
    
    IF v_current_stock != 9 THEN
        RAISE EXCEPTION 'FALLO CASO 3: Stock esperado 9, obtenido %', v_current_stock;
    ELSE
        RAISE NOTICE '✅ CASO 3 (Devolución) EXITOSO. Stock: 9';
    END IF;

    -- =============================================
    -- CASO 4: AJUSTE DE INVENTARIO (Absoluto)
    -- Nota: Según el schema actual, 'ajuste' suma algebraicamente la cantidad.
    -- Si paso -5, resta 5. Si paso 5, suma 5.
    -- =============================================
    INSERT INTO inventory_movements (product_id, movement_type, quantity, reason, created_by)
    VALUES (v_product_id, 'ajuste', -5, 'Merma / Daño', v_employee_id);

    -- Verificar
    SELECT current_stock INTO v_current_stock FROM products WHERE id = v_product_id;
    
    IF v_current_stock != 4 THEN
        RAISE EXCEPTION 'FALLO CASO 4: Stock esperado 4, obtenido %', v_current_stock;
    ELSE
        RAISE NOTICE '✅ CASO 4 (Ajuste Negativo) EXITOSO. Stock: 4';
    END IF;

    RAISE NOTICE '=== TODOS LOS TESTS DE INVENTARIO PASARON ===';
    
    -- Limpieza (Opcional, para no ensuciar DB de test, pero en desarrollo útil verlos)
    -- DELETE FROM inventory_movements WHERE product_id = v_product_id;
    -- DELETE FROM products WHERE id = v_product_id;

END $$;

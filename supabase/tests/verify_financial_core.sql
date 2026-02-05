-- VERIFICATION SCRIPT FOR ARCH-004
-- Variables replaced with findings from Step 693

DO $$
DECLARE
    v_store_id UUID := '22222222-2222-2222-2222-222222222222';
    v_employee_id UUID := '533e7fff-b52f-4319-9698-51019d24951c';
    v_product_id UUID := '33333333-3333-3333-3333-333333333333';
    v_client_id UUID := '38a5f332-f10e-4b88-8ae0-69877eaee1be';
    
    v_initial_stock DECIMAL;
    v_initial_balance DECIMAL;
    v_mid_stock DECIMAL;
    v_mid_balance DECIMAL;
    v_final_stock DECIMAL;
    v_final_balance DECIMAL;
    
    v_sale_result JSONB;
    v_sale_id UUID;
    v_void_result JSONB;
BEGIN
    -- 0. Mock Auth (Asume que ejecutamos con permisos suficientes o como postgres/service_role)
    -- En SQL Editor real, auth.uid() sería null. Los RPCs tienen fallbacks o SECURITY DEFINER.
    -- rpc_procesar_venta_v2 usa auth.uid() por defecto, pero si es null puede fallar si no hay lógica de fallback.
    -- El RPC V2 tiene: v_employee_id := auth.uid();
    -- Y valida: IF NOT EXISTS (SELECT 1 FROM employees WHERE id = v_employee_id...)
    -- Esto FALLARÁ si lo corremos directo desde aquí sin setear auth.
    -- Hack para Verification: Asignaremos v_employee_id como parámetro de session o modificamos el script para usar "set_config".
    -- Pero set_config('request.jwt.claim.sub', ...) solo funciona si la función usa auth.jwt().
    -- La función usa auth.uid().
    
    -- Para esta prueba, vamos a asumir que el RPC funciona si le pasamos tokens reales.
    -- Dado que estoy en SQL directo, voy a invocar la función asumiendo soy SU.
    -- Pero la función V2 valida internamente que el empleado exista.
    -- Voy a tener que confiar en que `auth.uid()` retornará NULL y la función fallará.
    -- WAIT: En el RPC V2 puse: v_employee_id := auth.uid();
    -- Si es NULL, la query `SELECT 1 FROM employees WHERE id = NULL` da false.
    -- Retornará "Usuario no autorizado".
    
    -- SOLUCION: En SQL puro de Supabase (Editor), no puedo simular auth.uid fácilmente sin extensiones.
    -- PERO, puedo hacer un "Login" falso si tuviera las credenciales.
    -- Alternativa: Modificar temporalmente el RPC para aceptar p_employee_id como parámetro explícito DEPURACION.
    -- O usar `set_config('request.jwt.claims', '{"sub": "533e7fff-b52f-4319-9698-51019d24951c", "role": "authenticated"}', true);`
    
    PERFORM set_config('request.jwt.claims', json_build_object(
        'sub', v_employee_id,
        'role', 'authenticated',
        'app_metadata', json_build_object('store_id', v_store_id)
    )::text, true);

    -- 1. SNAPSHOT INICIAL
    SELECT current_stock INTO v_initial_stock FROM products WHERE id = v_product_id;
    SELECT balance INTO v_initial_balance FROM clients WHERE id = v_client_id;
    
    RAISE NOTICE 'Initial Stock: %, Initial Balance: %', v_initial_stock, v_initial_balance;

    -- 2. EJECUTAR VENTA (2 Unidades, Fiado)
    -- p_items: [{product_id, quantity}]
    SELECT rpc_procesar_venta_v2(
        v_store_id,
        v_client_id,
        'fiado',
        0, -- amount_received
        jsonb_build_array(
            jsonb_build_object('product_id', v_product_id, 'quantity', 2)
        )
    ) INTO v_sale_result;
    
    RAISE NOTICE 'Sale Result: %', v_sale_result;
    
    IF (v_sale_result->>'success')::boolean IS NOT true THEN
        RAISE EXCEPTION 'Venta Fallida: %', v_sale_result;
    END IF;
    
    v_sale_id := (v_sale_result->>'sale_id')::UUID;

    -- 3. CHECK MID STATE
    SELECT current_stock INTO v_mid_stock FROM products WHERE id = v_product_id;
    SELECT balance INTO v_mid_balance FROM clients WHERE id = v_client_id;
    
    RAISE NOTICE 'Mid Stock: % (Expected %)', v_mid_stock, v_initial_stock - 2;
    RAISE NOTICE 'Mid Balance: % (Expected > %)', v_mid_balance, v_initial_balance;

    -- Validar Ledger Entry
    PERFORM * FROM client_ledger WHERE reference_id = v_sale_id AND transaction_type = 'venta_fiado';
    IF NOT FOUND THEN RAISE EXCEPTION 'No Ledger Entry Created'; END IF;

    -- 4. ANULAR VENTA
    SELECT rpc_anular_venta(v_sale_id, 'Test Verification') INTO v_void_result;
    RAISE NOTICE 'Void Result: %', v_void_result;

    -- 5. CHECK FINAL STATE
    SELECT current_stock INTO v_final_stock FROM products WHERE id = v_product_id;
    SELECT balance INTO v_final_balance FROM clients WHERE id = v_client_id;
    
    RAISE NOTICE 'Final Stock: % (Expected %)', v_final_stock, v_initial_stock;
    RAISE NOTICE 'Final Balance: % (Expected %)', v_final_balance, v_initial_balance;
    
    -- Validar Ledger Reversal
    PERFORM * FROM client_ledger WHERE reference_id = v_sale_id AND transaction_type = 'anulacion_fiado';
    IF NOT FOUND THEN RAISE EXCEPTION 'No Ledger Reversal Created'; END IF;

END $$;

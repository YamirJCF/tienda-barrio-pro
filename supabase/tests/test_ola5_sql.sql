-- ============================================================================
-- SUITE DE VERIFICACIÓN SQL — FASE 3 · OLA 5 (CHK-501 .. CHK-512)
-- Ejecución transaccional limpia (BEGIN; ... ROLLBACK;) sin ensuciar datos reales.
-- ============================================================================
\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE
    v_store_id UUID := gen_random_uuid();
    v_owner_id UUID := gen_random_uuid();
    v_emp_inv_id UUID := gen_random_uuid();
    v_emp_basic_id UUID := gen_random_uuid();
    v_emp_refund_id UUID := gen_random_uuid();
    v_supplier_id UUID := gen_random_uuid();
    v_invoice_id UUID := gen_random_uuid();
    v_prod_a UUID := gen_random_uuid();
    v_prod_b UUID := gen_random_uuid();
    v_session_id UUID := gen_random_uuid();
    v_sale_id UUID := gen_random_uuid();
    v_sale_item_a UUID := gen_random_uuid();
    v_sale_item_b UUID := gen_random_uuid();
    v_batch_id UUID;
    v_mov_id UUID;
    v_res JSONB;
    v_count INT;
    v_err TEXT;
    v_stock NUMERIC;
    v_inv_paid NUMERIC;
    v_report JSONB;
BEGIN
    -- 0. Semilla base multi-tenant aislada
    INSERT INTO auth.users (id, email, raw_user_meta_data, raw_app_meta_data, aud, role) VALUES
        (v_owner_id, 'ola5-owner-' || v_owner_id || '@test.local', '{"full_name":"Dueño Ola5"}', '{"provider":"email","account_kind":"store_member"}', 'authenticated', 'authenticated'),
        (v_emp_inv_id, 'ola5-inv-' || v_emp_inv_id || '@test.local', '{"full_name":"Bodeguero Inv"}', '{"provider":"email","account_kind":"store_member"}', 'authenticated', 'authenticated'),
        (v_emp_basic_id, 'ola5-basic-' || v_emp_basic_id || '@test.local', '{"full_name":"Cajero Básico"}', '{"provider":"email","account_kind":"store_member"}', 'authenticated', 'authenticated'),
        (v_emp_refund_id, 'ola5-ref-' || v_emp_refund_id || '@test.local', '{"full_name":"Supervisor Reembolsos"}', '{"provider":"email","account_kind":"store_member"}', 'authenticated', 'authenticated');

    INSERT INTO public.stores (id, name, slug) VALUES (v_store_id, 'Tienda Test Ola 5', 'tienda-ola5-' || substring(v_store_id::text, 1, 6));
    INSERT INTO public.admin_profiles (id, store_id, role, is_verified) VALUES (v_owner_id, v_store_id, 'owner', true);

    INSERT INTO public.employees (id, store_id, name, username, pin_hash, is_active, permissions) VALUES
    (v_emp_inv_id, v_store_id, 'Bodeguero Inv', 'bod_ola5', 'x', true,
        '{"canManageInventory": true, "canFiar": false, "canOpenCloseCash": false, "canManageRefunds": false}'::jsonb),
    (v_emp_basic_id, v_store_id, 'Cajero Básico', 'caj_ola5', 'x', true,
        '{"canManageInventory": false, "canFiar": false, "canOpenCloseCash": false, "canManageRefunds": false}'::jsonb),
    (v_emp_refund_id, v_store_id, 'Supervisor Reembolsos', 'sup_ola5', 'x', true,
        '{"canManageInventory": false, "canFiar": false, "canOpenCloseCash": false, "canManageRefunds": true}'::jsonb);

    INSERT INTO public.daily_passes (store_id, employee_id, pass_date, status) VALUES
    (v_store_id, v_emp_inv_id, (NOW() AT TIME ZONE 'America/Bogota')::date, 'approved'),
    (v_store_id, v_emp_basic_id, (NOW() AT TIME ZONE 'America/Bogota')::date, 'approved'),
    (v_store_id, v_emp_refund_id, (NOW() AT TIME ZONE 'America/Bogota')::date, 'approved');

    INSERT INTO public.suppliers (id, store_id, name) VALUES (v_supplier_id, v_store_id, 'Distribuidora Alfa');
    INSERT INTO public.supplier_invoices (id, store_id, supplier_id, invoice_number, total_amount, amount_paid, due_date)
    VALUES (v_invoice_id, v_store_id, v_supplier_id, 'FAC-999', 50000, 0, CURRENT_DATE + 15);

    INSERT INTO public.products (id, store_id, name, plu, price, cost_price, current_stock, is_active) VALUES
    (v_prod_a, v_store_id, 'Arroz Test Ola5', '9901', 2000, 1000, 0, true),
    (v_prod_b, v_store_id, 'Leche Zero Stock Ola5', '9902', 3000, 1500, 0, true);

    -- ========================================================================
    -- TEST 1 (CHK-505 & CHK-502): Entradas con canManageInventory, sin CxP, rechaza Ajuste/Dev
    -- ========================================================================
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_basic_id, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.headers', json_build_object('x-employee-id', v_emp_basic_id::text)::text, true);
    BEGIN
        PERFORM public.rpc_registrar_entrada(v_prod_a, 10, 1000, 2000, 'Compra', v_supplier_id, NULL, 'REM-1', v_invoice_id);
        RAISE EXCEPTION 'TEST_FAIL: Empleado sin canManageInventory pudo registrar entrada';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%PERMISSION_DENIED%' THEN RAISE; END IF;
    END;

    -- Actuar como emp con canManageInventory
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_inv_id, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.headers', json_build_object('x-employee-id', v_emp_inv_id::text)::text, true);

    -- Rechaza motivo Ajuste Positivo o Devolución Cliente
    BEGIN
        PERFORM public.rpc_registrar_entrada(v_prod_a, 5, 1000, 2000, 'Ajuste Positivo', NULL, NULL, NULL, NULL);
        RAISE EXCEPTION 'TEST_FAIL: rpc_registrar_entrada aceptó Ajuste Positivo';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%INVALID_REASON%' THEN RAISE; END IF;
    END;

    BEGIN
        PERFORM public.rpc_registrar_entrada(v_prod_a, 5, 1000, 2000, 'Devolución Cliente', NULL, NULL, NULL, NULL);
        RAISE EXCEPTION 'TEST_FAIL: rpc_registrar_entrada aceptó Devolución Cliente';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%INVALID_REASON%' THEN RAISE; END IF;
    END;

    -- Camino feliz: Entrada válida con proveedor NO toca supplier_invoices
    v_res := public.rpc_registrar_entrada(v_prod_a, 10, 1000, 2200, 'Compra', v_supplier_id, 'credito', 'FAC-NEW', v_invoice_id);
    ASSERT (v_res->>'success')::boolean = true, 'Entrada válida debe tener success=true';
    ASSERT (v_res->'data'->>'new_stock')::numeric = 10, 'Stock de prod_a debe ser 10';

    SELECT COUNT(*) INTO v_count FROM public.supplier_invoices WHERE store_id = v_store_id;
    ASSERT v_count = 1, 'trigger bridge_movement_to_batch NO debe crear nuevas facturas CxP';
    SELECT amount_paid INTO v_inv_paid FROM public.supplier_invoices WHERE id = v_invoice_id;
    ASSERT v_inv_paid = 0, 'Entrada no debe alterar facturas existentes';

    -- ========================================================================
    -- TEST 2 (CHK-503 & CHK-504 + Enmienda UX-ADR-003): Salidas Logísticas ($0) exigen canManageInventory
    -- ========================================================================
    -- Cajero Básico (SIN canManageInventory): rechazado con SQLSTATE 42501 en los 4 tipos de salida logística
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_basic_id, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.headers', json_build_object('x-employee-id', v_emp_basic_id::text)::text, true);

    BEGIN
        PERFORM public.rpc_registrar_salida_logistica(v_prod_a, 'merma', 1, 'Empaque roto en estantería');
        RAISE EXCEPTION 'TEST_FAIL: Cajero básico sin canManageInventory pudo registrar merma';
    EXCEPTION WHEN SQLSTATE '42501' THEN
        NULL;
    END;

    BEGIN
        PERFORM public.rpc_registrar_salida_logistica(v_prod_a, 'consumo_negocio', 1, 'Aseo de mostrador');
        RAISE EXCEPTION 'TEST_FAIL: Cajero básico sin canManageInventory pudo registrar consumo_negocio';
    EXCEPTION WHEN SQLSTATE '42501' THEN
        NULL;
    END;

    BEGIN
        PERFORM public.rpc_registrar_salida_logistica(v_prod_a, 'ajuste_conteo', 1, 'Conteo manual', 'negative', NULL);
        RAISE EXCEPTION 'TEST_FAIL: Cajero básico pudo ejecutar ajuste_conteo';
    EXCEPTION WHEN SQLSTATE '42501' THEN
        NULL;
    END;

    BEGIN
        PERFORM public.rpc_registrar_salida_logistica(v_prod_a, 'devolucion_proveedor', 1, 'Cambio proveedor', 'negative', v_supplier_id);
        RAISE EXCEPTION 'TEST_FAIL: Cajero básico pudo ejecutar devolucion_proveedor';
    EXCEPTION WHEN SQLSTATE '42501' THEN
        NULL;
    END;

    -- Bodeguero CON canManageInventory (sin caja abierta): merma + consumo_negocio + devolucion_proveedor ($0) + ajuste_conteo (+/-) + contra-movimiento
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_inv_id, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.headers', json_build_object('x-employee-id', v_emp_inv_id::text)::text, true);

    v_res := public.rpc_registrar_salida_logistica(v_prod_a, 'merma', 1, 'Empaque roto en estantería');
    ASSERT (v_res->>'success')::boolean = true, 'Usuario con canManageInventory debe poder registrar merma sin caja';
    ASSERT (v_res->'data'->>'unit_cost')::numeric = 1000, 'Con canManageInventory sí expone unit_cost = 1000';

    v_res := public.rpc_registrar_salida_logistica(v_prod_a, 'consumo_negocio', 1, 'Aseo de mostrador');
    ASSERT (v_res->>'success')::boolean = true, 'Usuario con canManageInventory debe poder registrar consumo_negocio sin caja';
    ASSERT (v_res->'data'->>'new_stock')::numeric = 8, 'Stock tras merma(1)+consumo_negocio(1) debe ser 8';

    v_res := public.rpc_registrar_salida_logistica(v_prod_a, 'devolucion_proveedor', 1, 'Producto próximo a vencer', 'negative', v_supplier_id);
    ASSERT (v_res->'data'->>'unit_cost')::numeric = 1000, 'Con canManageInventory sí expone unit_cost = 1000';
    SELECT amount_paid INTO v_inv_paid FROM public.supplier_invoices WHERE id = v_invoice_id;
    ASSERT v_inv_paid = 0, 'Devolución a proveedor logística ($0) NO debe descontar amount_paid de CxP';

    v_res := public.rpc_registrar_salida_logistica(v_prod_a, 'ajuste_conteo', 2, 'Sobrante detectado en conteo físico', 'positive', NULL);
    v_mov_id := (v_res->'data'->>'movement_id')::uuid;
    ASSERT (v_res->'data'->>'new_stock')::numeric = 9, 'Stock tras +2 ajuste_conteo debe ser 9';

    SELECT COUNT(*) INTO v_count FROM public.notifications
    WHERE store_id = v_store_id AND metadata->>'event_type' = 'INVENTORY_COUNT_ADJUSTMENT';
    ASSERT v_count = 1, 'ajuste_conteo debe emitir notificación Admin INVENTORY_COUNT_ADJUSTMENT';

    -- Contra-movimiento revierte +2 a 7 y bloquea doble reversión
    v_res := public.rpc_registrar_contra_movimiento(v_mov_id, 'Error de digitación en conteo');
    ASSERT (v_res->'data'->>'new_stock')::numeric = 7, 'Contra-movimiento debe restar +2 y dejar stock en 7';

    BEGIN
        PERFORM public.rpc_registrar_contra_movimiento(v_mov_id, 'Segundo intento ilegal');
        RAISE EXCEPTION 'TEST_FAIL: Permitió doble contra-movimiento';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%DOUBLE_REVERSAL_BLOCKED%' THEN RAISE; END IF;
    END;

    -- ========================================================================
    -- TEST 3 (CHK-506): Lote, Catálogo y Soft Delete con canManageInventory
    -- ========================================================================
    SELECT id INTO v_batch_id FROM public.inventory_batches WHERE product_id = v_prod_a AND quantity_remaining > 0 LIMIT 1;
    v_res := public.rpc_actualizar_precio_lote(v_batch_id, 1100, 2400);
    ASSERT (v_res->>'success')::boolean = true, 'Empleado con canManageInventory debe poder editar precio de lote';

    -- Simular >3s tras el cambio de precio de rpc_registrar_entrada para no disparar cooldown Escudo 1
    UPDATE public.audit_precios SET created_at = NOW() - INTERVAL '10 seconds' WHERE product_id = v_prod_a;
    v_res := public.rpc_actualizar_producto_catalogo(v_prod_a, 'Arroz Test Actualizado', 2400, 2200, 'Arroz Test Ola5', 1100, 3, '9901', 'Granos', 1000);
    ASSERT (v_res->>'success')::boolean = true, 'Empleado con canManageInventory debe poder editar producto';

    -- Soft delete rechazado cuando stock > 0, permitido con stock = 0
    BEGIN
        PERFORM public.rpc_soft_delete_product(v_prod_a);
        RAISE EXCEPTION 'TEST_FAIL: Permitió soft delete con stock > 0';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%STOCK_REMAINING%' THEN RAISE; END IF;
    END;

    -- ========================================================================
    -- TEST 4 (CHK-508, CHK-509, CHK-510): Reembolso "merma" con stock=0, devolución vendible, búsqueda, guard anulación y Kardex
    -- ========================================================================
    -- Verificar buscar_producto_pos con p_include_zero_stock=true encuentra v_prod_b (stock=0)
    v_res := public.buscar_producto_pos(v_store_id, 'Leche Zero', 10, 0, false);
    ASSERT (v_res->>'count')::int = 0, 'POS regular no debe mostrar stock=0 por nombre';
    v_res := public.buscar_producto_pos(v_store_id, 'Leche Zero', 10, 0, true);
    ASSERT (v_res->>'count')::int = 1, 'Reembolsos con p_include_zero_stock=true sí encuentra stock=0';

    -- Abrir turno vigente y crear venta base con 2 items (uno prod_b en stock=0, otro prod_a)
    INSERT INTO public.cash_sessions (id, store_id, opened_by, opened_by_name, opened_by_role, status, opening_balance, opened_at)
    VALUES (v_session_id, v_store_id, v_owner_id, 'Admin Test', 'owner', 'open', 5000, NOW());

    INSERT INTO public.sales (id, store_id, ticket_number, employee_id, total, payment_method, is_voided, created_at)
    VALUES (v_sale_id, v_store_id, 501, v_emp_refund_id, 10000, 'efectivo', false, NOW());

    INSERT INTO public.cash_movements (session_id, movement_type, amount, description, sale_id, payment_method, category)
    VALUES (v_session_id, 'ingreso', 10000, 'Venta #501', v_sale_id, 'efectivo', 'venta');

    INSERT INTO public.sale_items (id, sale_id, product_id, quantity, unit_price, subtotal, unit_cost) VALUES
    (v_sale_item_b, v_sale_id, v_prod_b, 2, 3000, 6000, 1500),
    (v_sale_item_a, v_sale_id, v_prod_a, 2, 2000, 4000, 1000);

    -- Consumir OPEX caja 500 y costo en venta para P&L más adelante
    INSERT INTO public.cash_movements (session_id, movement_type, amount, description, payment_method, category)
    VALUES (v_session_id, 'gasto', 500, 'Pago luz prueba', 'efectivo', 'Servicios');

    -- Sin permiso canManageRefunds debe fallar
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_inv_id, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.headers', json_build_object('x-employee-id', v_emp_inv_id::text)::text, true);
    BEGIN
        PERFORM public.rpc_procesar_reembolso_item(v_sale_item_b, 1, 'efectivo', 'efectivo', 'Producto dañado', true);
        RAISE EXCEPTION 'TEST_FAIL: Bodeguero sin canManageRefunds pudo reembolsar';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%PERMISSION_DENIED%' THEN RAISE; END IF;
    END;

    -- Actuar como Supervisor con canManageRefunds
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_refund_id, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.headers', json_build_object('x-employee-id', v_emp_refund_id::text)::text, true);

    -- Canal Nequi con $0 debe fallar con INSUFFICIENT_FUNDS_IN_CHANNEL
    BEGIN
        PERFORM public.rpc_procesar_reembolso_item(v_sale_item_b, 1, 'nequi', 'efectivo', 'Producto dañado', true);
        RAISE EXCEPTION 'TEST_FAIL: Permitió reembolso sin fondos en Nequi';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%INSUFFICIENT_FUNDS_IN_CHANNEL%' THEN RAISE; END IF;
    END;

    -- Reembolso MERMA sobre v_prod_b (que tiene stock=0!): NO debe tocar current_stock ni fallar por stock=0
    v_res := public.rpc_procesar_reembolso_item(v_sale_item_b, 1, 'efectivo', 'efectivo', 'Bolsa rota cliente', true);
    ASSERT (v_res->>'success')::boolean = true, 'Reembolso merma en stock=0 debe funcionar';
    ASSERT (v_res->'data'->>'amount_refunded')::numeric = 3000, 'Monto servidor debe ser $3000';
    SELECT current_stock INTO v_stock FROM public.products WHERE id = v_prod_b;
    ASSERT v_stock = 0, 'Reembolso merma NO debe reingresar ni alterar current_stock (=0)';

    -- Reembolso VENDIBLE (p_is_merma = false) sobre v_prod_a: SÍ suma +1 a current_stock y crea lote
    v_res := public.rpc_procesar_reembolso_item(v_sale_item_a, 1, 'efectivo', 'efectivo', 'Cliente llevó referencia equivocada', false);
    ASSERT (v_res->>'success')::boolean = true, 'Reembolso vendible debe funcionar';
    SELECT current_stock INTO v_stock FROM public.products WHERE id = v_prod_a;
    ASSERT v_stock = 8, 'Reembolso vendible de 1 unid sobre stock 7 debe subirlo a 8';

    -- Exceder cantidad restante debe fallar con QUANTITY_EXCEEDED
    BEGIN
        PERFORM public.rpc_procesar_reembolso_item(v_sale_item_b, 2, 'efectivo', 'efectivo', 'Intento exceso', true);
        RAISE EXCEPTION 'TEST_FAIL: Permitió reembolsar más de la cantidad restante';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%QUANTITY_EXCEEDED%' THEN RAISE; END IF;
    END;

    -- Anular venta con reembolsos parciales debe fallar con SALE_HAS_PARTIAL_REFUNDS (como Admin)
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.headers', '{}'::text, true);
    BEGIN
        PERFORM public.rpc_anular_venta(v_sale_id, 'Intento anular venta ya reembolsada');
        RAISE EXCEPTION 'TEST_FAIL: Permitió anular venta con reembolso parcial';
    EXCEPTION WHEN OTHERS THEN
        IF SQLERRM NOT LIKE '%SALE_HAS_PARTIAL_REFUNDS%' THEN RAISE; END IF;
    END;

    -- Validar get_inventory_kardex (filtra merma y actor, con canManageInventory/Admin)
    v_res := public.get_inventory_kardex(v_prod_a, 'merma', NULL, NULL, NULL, 20, 0);
    ASSERT (v_res->>'count')::int = 1, 'Kardex prod_a filtrado por merma debe tener 1 fila';
    ASSERT ((v_res->'data'->0->>'actor_name') = 'Bodeguero Inv'), 'Kardex debe preservar actor_name del Bodeguero Inv';

    -- ========================================================================
    -- TEST 5 (CHK-511 & CHK-512): Reporte P&L 4 Pilares y cero doble conteo
    -- ========================================================================
    -- Agregar 1 consumo_personal (excl. de ventas, suma al costo en OPEX + resumen)
    INSERT INTO public.sales (store_id, ticket_number, employee_id, beneficiary_employee_id, total, payment_method, is_voided)
    VALUES (v_store_id, 502, v_emp_basic_id, v_emp_basic_id, 0, 'consumo_personal', false);

    INSERT INTO public.inventory_movements (
        product_id, movement_type, quantity, reason, created_by, actor_name, actor_role, unit_cost, reference_sale_price, beneficiary_employee_id, session_id
    ) VALUES (
        v_prod_a, 'consumo_personal', 1, 'Retiro Personal #502', v_emp_basic_id, 'Cajero Básico', 'employee', 1000, 2400, v_emp_basic_id, v_session_id
    );

    v_report := public.rpc_get_comprehensive_financial_report(v_store_id, (NOW() AT TIME ZONE 'America/Bogota')::date, (NOW() AT TIME ZONE 'America/Bogota')::date, NULL);

    -- Cálculos exactos esperados:
    -- gross_sales = 10000
    -- refunds_total = 3000 + 2000 = 5000 (cash_movements 'reembolso') -> revenue = 5000
    -- opex cash_expenses = 500 (solo 'Servicios', SIN reembolsos -> cero doble conteo!)
    -- opex merma_cost = prod_a(1*1000) + prod_b reembolso-merma(1*1500) = 2500
    -- opex consumo_negocio_cost = prod_a(1*1000) = 1000
    -- opex consumo_personal_cost = prod_a(1*1000) = 1000
    -- total OPEX = 500 + 2500 + 1000 + 1000 = 5000
    ASSERT (v_report->>'gross_sales')::numeric = 10000, 'gross_sales debe ser 10000 (sin consumo_personal)';
    ASSERT (v_report->>'refunds_total')::numeric = 5000, 'refunds_total debe ser 5000';
    ASSERT (v_report->>'revenue')::numeric = 5000, 'revenue neto debe ser 5000';
    ASSERT (v_report->'opex_breakdown'->>'cash_expenses')::numeric = 500, 'OPEX caja debe ser 500 (cero doble conteo con reembolsos)';
    ASSERT (v_report->'opex_breakdown'->>'merma_cost')::numeric = 2500, 'merma_cost debe ser 2500 (1000 física + 1500 reembolso-merma)';
    ASSERT (v_report->'opex_breakdown'->>'consumo_negocio_cost')::numeric = 1000, 'consumo_negocio_cost debe ser 1000';
    ASSERT (v_report->'opex_breakdown'->>'consumo_personal_cost')::numeric = 1000, 'consumo_personal_cost debe ser 1000';
    ASSERT (v_report->>'operational_expenses')::numeric = 5000, 'operational_expenses total debe ser 5000';
    ASSERT (v_report->'personal_consumptions_summary'->>'total_cost')::numeric = 1000, 'Consumos personales al costo = 1000';
    ASSERT (v_report->'personal_consumptions_summary'->>'total_reference_sale_price')::numeric = 2400, 'Valor ref retail consumos = 2400';

    -- ========================================================================
    -- TEST 6 (B5-2): Unicidad pg_proc, GRANTs Regla 8, Rechazos 42501 y Caminos Felices Faltantes
    -- ========================================================================
    -- 6.1 Unicidad de firmas en pg_proc (sin sobrecargas legacy zombis)
    SELECT COUNT(*) INTO v_count FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_registrar_entrada';
    ASSERT v_count = 1, 'rpc_registrar_entrada debe tener firma única (COUNT=1)';

    SELECT COUNT(*) INTO v_count FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_actualizar_precio_lote';
    ASSERT v_count = 1, 'rpc_actualizar_precio_lote debe tener firma única (COUNT=1)';

    SELECT COUNT(*) INTO v_count FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'buscar_producto_pos';
    ASSERT v_count = 1, 'buscar_producto_pos debe tener firma única (COUNT=1)';

    SELECT COUNT(*) INTO v_count FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_registrar_entrada_masiva';
    ASSERT v_count = 1, 'rpc_registrar_entrada_masiva debe tener firma única (COUNT=1)';

    SELECT COUNT(*) INTO v_count FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'rpc_registrar_salida_logistica';
    ASSERT v_count = 1, 'rpc_registrar_salida_logistica debe tener firma única (COUNT=1)';

    -- 6.2 Privilegios explícitos para authenticated (Regla 8)
    ASSERT has_table_privilege('authenticated', 'public.inventory_movements', 'SELECT'), 'Falta SELECT para authenticated en inventory_movements';
    ASSERT has_table_privilege('authenticated', 'public.inventory_batches', 'SELECT'), 'Falta SELECT para authenticated en inventory_batches';
    ASSERT has_table_privilege('authenticated', 'public.inventory_movement_batches', 'SELECT'), 'Falta SELECT para authenticated en inventory_movement_batches';
    ASSERT has_table_privilege('authenticated', 'public.product_price_history', 'SELECT'), 'Falta SELECT para authenticated en product_price_history';

    -- 6.3 Camino feliz rpc_buscar_ventas_para_reembolso encontrando ticket #501 por producto con stock = 0
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_refund_id, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.headers', json_build_object('x-employee-id', v_emp_refund_id::text)::text, true);
    v_res := public.rpc_buscar_ventas_para_reembolso(v_store_id, 'Leche Zero', 10);
    ASSERT (v_res->>'success')::boolean = true AND jsonb_array_length(v_res->'data') = 1,
        'rpc_buscar_ventas_para_reembolso debe hallar venta #501 para producto con stock=0';
    ASSERT (v_res->'data'->0->>'ticket_number')::int = 501, 'Ticket hallado debe ser #501';

    -- 6.4 Batería de rechazos SQLSTATE 42501 para empleado básico (sin canManageInventory ni canManageRefunds)
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_basic_id, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.headers', json_build_object('x-employee-id', v_emp_basic_id::text)::text, true);

    BEGIN
        PERFORM public.rpc_registrar_entrada_masiva(v_store_id, jsonb_build_array(jsonb_build_object(
            'product_id', v_prod_a, 'quantity', 2, 'purchase_price', 1000, 'sale_price', 2400, 'reason', 'Compra'
        )));
        RAISE EXCEPTION 'TEST_FAIL: Permitió rpc_registrar_entrada_masiva sin canManageInventory';
    EXCEPTION WHEN SQLSTATE '42501' THEN
        NULL;
    END;

    BEGIN
        PERFORM public.rpc_actualizar_precio_lote(v_batch_id, 1000, 2500);
        RAISE EXCEPTION 'TEST_FAIL: Permitió rpc_actualizar_precio_lote sin canManageInventory';
    EXCEPTION WHEN SQLSTATE '42501' THEN
        NULL;
    END;

    BEGIN
        PERFORM public.rpc_actualizar_producto_catalogo(v_prod_a, 'Hack', 2500, 2400, 'Arroz Test Actualizado');
        RAISE EXCEPTION 'TEST_FAIL: Permitió rpc_actualizar_producto_catalogo sin canManageInventory';
    EXCEPTION WHEN SQLSTATE '42501' THEN
        NULL;
    END;

    BEGIN
        PERFORM public.rpc_soft_delete_product(v_prod_b);
        RAISE EXCEPTION 'TEST_FAIL: Permitió rpc_soft_delete_product sin canManageInventory';
    EXCEPTION WHEN SQLSTATE '42501' THEN
        NULL;
    END;

    BEGIN
        PERFORM public.rpc_registrar_contra_movimiento(v_mov_id, 'Intento no autorizado');
        RAISE EXCEPTION 'TEST_FAIL: Permitió rpc_registrar_contra_movimiento sin canManageInventory';
    EXCEPTION WHEN SQLSTATE '42501' THEN
        NULL;
    END;

    BEGIN
        PERFORM public.get_inventory_kardex(v_prod_a, NULL, NULL, NULL, NULL, 20, 0);
        RAISE EXCEPTION 'TEST_FAIL: Permitió get_inventory_kardex sin canManageInventory';
    EXCEPTION WHEN SQLSTATE '42501' THEN
        NULL;
    END;

    BEGIN
        PERFORM public.rpc_buscar_ventas_para_reembolso(v_store_id, '501', 10);
        RAISE EXCEPTION 'TEST_FAIL: Permitió rpc_buscar_ventas_para_reembolso sin canManageRefunds';
    EXCEPTION WHEN SQLSTATE '42501' THEN
        NULL;
    END;

    -- 6.5 Caminos felices con canManageInventory: entrada masiva y soft delete en stock = 0
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_inv_id, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.headers', json_build_object('x-employee-id', v_emp_inv_id::text)::text, true);

    v_res := public.rpc_registrar_entrada_masiva(v_store_id, jsonb_build_array(jsonb_build_object(
        'product_id', v_prod_a, 'quantity', 2, 'purchase_price', 1100, 'sale_price', 2400, 'reason', 'Reposición masiva'
    )));
    ASSERT (v_res->>'success')::boolean = true AND (v_res->'data'->>'processed_count')::int = 1,
        'rpc_registrar_entrada_masiva debe procesar 1 entrada con canManageInventory';

    v_res := public.rpc_soft_delete_product(v_prod_b);
    ASSERT (v_res->>'success')::boolean = true AND (v_res->'data'->>'is_active')::boolean = false,
        'rpc_soft_delete_product debe archivar v_prod_b cuando stock = 0';

    RAISE NOTICE 'OLA_5_SQL_SUITE_ALL_ASSERTIONS_PASSED';
END $$;

ROLLBACK;

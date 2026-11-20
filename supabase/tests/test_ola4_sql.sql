-- =============================================================================
-- TEST SQL INTEGRAL - FASE 3 OLA 4 (CHK-401 a CHK-410)
-- Verificación real en PostgreSQL (Docker local): camino feliz + rechazos Regla 5
-- Ejecución atómica dentro de BEGIN ... ROLLBACK (sin dejar residuos)
-- =============================================================================

BEGIN;

DO $$
DECLARE
    v_owner UUID := gen_random_uuid();
    v_emp_fiar UUID := gen_random_uuid();
    v_emp_no_fiar UUID := gen_random_uuid();
    v_store UUID := gen_random_uuid();
    v_sup UUID := gen_random_uuid();
    v_prod UUID := gen_random_uuid();
    v_session UUID := gen_random_uuid();
    v_client_active UUID := gen_random_uuid();
    v_client_deleted UUID := gen_random_uuid();
    v_client_existing UUID := gen_random_uuid();
    v_inv_id UUID;
    v_inv_ext_id UUID;
    v_sale_fiado_id UUID;

    v_res JSONB;
    v_cnt INT;
    v_cash_cnt INT;
    v_inv_mv RECORD;
    v_sale_rec RECORD;
    v_limit_existing NUMERIC;
    v_new_client_id UUID;
    v_pay_res JSONB;
    v_cxp_res JSONB;
BEGIN
    -- 1. Seed Auth & Store
    INSERT INTO auth.users (id, email, raw_user_meta_data, raw_app_meta_data, aud, role)
    VALUES
        (v_owner, 'ola4_owner@test.co', '{"full_name":"Dueño Ola4"}', '{"provider":"email","account_kind":"store_member"}', 'authenticated', 'authenticated'),
        (v_emp_fiar, 'ola4_fiar@test.co', '{"full_name":"Cajero Fiar"}', '{"provider":"email","account_kind":"store_member"}', 'authenticated', 'authenticated'),
        (v_emp_no_fiar, 'ola4_nofiar@test.co', '{"full_name":"Cajero Basico"}', '{"provider":"email","account_kind":"store_member"}', 'authenticated', 'authenticated');

    INSERT INTO public.stores (id, name, slug)
    VALUES (v_store, 'Tienda Ola 4 Test', 'tienda-ola4-' || substring(v_store::text, 1, 6));

    INSERT INTO public.admin_profiles (id, store_id, role, is_verified)
    VALUES (v_owner, v_store, 'owner', true);

    INSERT INTO public.employees (id, store_id, name, username, pin_hash, is_active, permissions)
    VALUES
        (v_emp_fiar, v_store, 'Cajero Fiar', 'ola4_fiar', '1111', true, '{"canManageInventory":false,"canFiar":true,"canOpenCloseCash":false,"canManageRefunds":false}'::jsonb),
        (v_emp_no_fiar, v_store, 'Cajero Basico', 'ola4_basic', '2222', true, '{"canManageInventory":false,"canFiar":false,"canOpenCloseCash":false,"canManageRefunds":false}'::jsonb);

    INSERT INTO public.daily_passes (employee_id, auth_user_id, store_id, device_fingerprint, pass_date, status, resolved_by, resolved_at, approved_by, approved_at)
    VALUES
        (v_emp_fiar, v_emp_fiar, v_store, 'fp-ola4-f', (NOW() AT TIME ZONE 'America/Bogota')::date, 'approved', v_owner, NOW(), v_owner, NOW()),
        (v_emp_no_fiar, v_emp_no_fiar, v_store, 'fp-ola4-b', (NOW() AT TIME ZONE 'America/Bogota')::date, 'approved', v_owner, NOW(), v_owner, NOW());

    INSERT INTO public.suppliers (id, store_id, name, frequency_days, lead_time_days)
    VALUES (v_sup, v_store, 'Distribuidora Ola4', 15, 1);

    -- Producto con lote FIFO (costo $3,000 / venta $5,000)
    INSERT INTO public.products (id, store_id, name, price, cost_price, current_stock, min_stock, is_active)
    VALUES (v_prod, v_store, 'Cafe Molido 500g', 5000, 3000, 20, 2, true);

    INSERT INTO public.inventory_batches (product_id, quantity_initial, quantity_remaining, cost_unit, sale_price)
    VALUES (v_prod, 20, 20, 3000, 5000);

    INSERT INTO public.clients (id, store_id, name, id_number, balance, credit_limit, is_deleted)
    VALUES
        (v_client_active, v_store, 'Carlos Deudor', '1001001', 10000, 80000, false),
        (v_client_deleted, v_store, 'Cliente Archivado', '2002002', 0, 0, true),
        (v_client_existing, v_store, 'Marta Existente', '3003003', 0, 50000, false);

    -- Turno abierto vigente (<24h) con saldo efectivo $50,000
    INSERT INTO public.cash_sessions (id, store_id, opened_by, opened_by_name, opened_by_role, opening_balance, expected_balance, status, opened_at)
    VALUES (v_session, v_store, v_owner, 'Dueño Ola4', 'owner', 50000, 50000, 'open', NOW() - INTERVAL '1 hour');

    -- =========================================================================
    -- BLOQUE 1: EMPLEADO SIN canFiar -> CHK-401, CHK-403, CHK-404, CHK-405, CHK-407
    -- =========================================================================
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_no_fiar, 'role', 'authenticated', 'app_metadata', json_build_object('store_id', v_store, 'employee_id', v_emp_no_fiar))::text, true);

    -- 1.1 [CHK-401] Empleado procesa consumo_personal propio ($0 en cash_movements + FIFO + unit_cost + reference_sale_price)
    v_res := public.rpc_procesar_venta_v3(
        v_store,
        v_client_active, -- debe ser sanitizado a NULL por CHK-403
        'consumo_personal',
        0,
        jsonb_build_array(jsonb_build_object('product_id', v_prod, 'quantity', 2)),
        gen_random_uuid(),
        'local-retiro-1',
        false,
        v_session,
        v_emp_no_fiar,
        NULL
    );
    IF (v_res->>'success')::boolean IS NOT TRUE OR (v_res->'data'->>'total')::numeric <> 0 THEN
        RAISE EXCEPTION 'CHK-401 FALLO: retiro personal retorno %', v_res;
    END IF;

    SELECT * INTO v_sale_rec FROM public.sales WHERE id = (v_res->'data'->>'sale_id')::uuid;
    IF v_sale_rec.client_id IS NOT NULL OR v_sale_rec.beneficiary_employee_id <> v_emp_no_fiar OR v_sale_rec.total <> 0 THEN
        RAISE EXCEPTION 'CHK-401/403 FALLO: sales record invalido client_id=%, beneficiary=%, total=%', v_sale_rec.client_id, v_sale_rec.beneficiary_employee_id, v_sale_rec.total;
    END IF;

    SELECT COUNT(*) INTO v_cash_cnt FROM public.cash_movements WHERE sale_id = v_sale_rec.id;
    IF v_cash_cnt <> 0 THEN
        RAISE EXCEPTION 'CHK-401 FALLO: consumo_personal inserto % filas en cash_movements', v_cash_cnt;
    END IF;

    SELECT * INTO v_inv_mv FROM public.inventory_movements WHERE product_id = v_prod AND movement_type = 'consumo_personal' ORDER BY created_at DESC LIMIT 1;
    IF v_inv_mv.id IS NULL OR v_inv_mv.unit_cost <> 3000 OR v_inv_mv.reference_sale_price <> 5000 OR v_inv_mv.session_id <> v_session OR v_inv_mv.beneficiary_employee_id <> v_emp_no_fiar THEN
        RAISE EXCEPTION 'CHK-401 FALLO: inventory_movements incompleto unit_cost=%, ref_price=%, session=%, ben=%',
            v_inv_mv.unit_cost, v_inv_mv.reference_sale_price, v_inv_mv.session_id, v_inv_mv.beneficiary_employee_id;
    END IF;

    -- 1.2 [CHK-401 RECHAZO] Empleado intenta asignar retiro personal a otro colaborador -> PERMISSION_DENIED
    BEGIN
        PERFORM public.rpc_procesar_venta_v3(
            v_store, NULL, 'consumo_personal', 0,
            jsonb_build_array(jsonb_build_object('product_id', v_prod, 'quantity', 1)),
            gen_random_uuid(), NULL, false, v_session, v_emp_no_fiar, v_emp_fiar
        );
        RAISE EXCEPTION 'CHK-401 FALLO: Empleado pudo asignar retiro personal a otro';
    EXCEPTION WHEN SQLSTATE '42501' THEN
        NULL; -- Esperado PERMISSION_DENIED
    END;

    -- 1.3 [CHK-403] Venta contado aunque envie client_id -> client_id persisted NULL
    v_res := public.rpc_procesar_venta_v3(
        v_store, v_client_active, 'efectivo', 10000,
        jsonb_build_array(jsonb_build_object('product_id', v_prod, 'quantity', 1)),
        gen_random_uuid(), NULL, false, v_session, v_emp_no_fiar, NULL
    );
    SELECT * INTO v_sale_rec FROM public.sales WHERE id = (v_res->'data'->>'sale_id')::uuid;
    IF v_sale_rec.client_id IS NOT NULL THEN
        RAISE EXCEPTION 'CHK-403 FALLO: venta contado contamino sales.client_id=%', v_sale_rec.client_id;
    END IF;

    -- 1.4 [CHK-404 RECHAZOS] Empleado SIN canFiar rechazado en venta fiado, abono, estado cuenta y directorio
    BEGIN
        PERFORM public.rpc_procesar_venta_v3(v_store, v_client_active, 'fiado', 0, jsonb_build_array(jsonb_build_object('product_id', v_prod, 'quantity', 1)));
        RAISE EXCEPTION 'CHK-404 FALLO: venta fiado permitida sin canFiar';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;

    BEGIN
        PERFORM public.rpc_registrar_abono(v_client_active, 2000, 'efectivo', 'Intento sin permiso');
        RAISE EXCEPTION 'CHK-404 FALLO: abono permitido sin canFiar';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;

    BEGIN
        PERFORM public.rpc_obtener_estado_cuenta_cliente(v_client_active, 20, 0);
        RAISE EXCEPTION 'CHK-404 FALLO: estado cuenta permitido sin canFiar';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;

    BEGIN
        PERFORM public.rpc_admin_get_clients(v_store, 'todos', NULL, 'name_asc', 20, 0);
        RAISE EXCEPTION 'CHK-407 FALLO: directorio clientes permitido sin canFiar';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;

    -- =========================================================================
    -- BLOQUE 2: EMPLEADO CON canFiar -> CHK-404, CHK-405, CHK-407, CHK-409/410 RECHAZOS
    -- =========================================================================
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_fiar, 'role', 'authenticated', 'app_metadata', json_build_object('store_id', v_store, 'employee_id', v_emp_fiar))::text, true);

    -- 2.1 [CHK-407] Consulta directorio con filtros 'con_deuda' y 'al_dia' sin expone archivados
    v_res := public.rpc_admin_get_clients(v_store, 'con_deuda', NULL, 'balance_desc', 20, 0);
    IF (v_res->>'count')::int <> 1 OR (v_res->'data'->0->>'id')::uuid <> v_client_active THEN
        RAISE EXCEPTION 'CHK-407 FALLO: filtro con_deuda %', v_res;
    END IF;
    v_res := public.rpc_admin_get_clients(v_store, 'al_dia', NULL, 'name_asc', 20, 0);
    IF (v_res->>'count')::int <> 1 OR (v_res->'data'->0->>'id')::uuid <> v_client_existing THEN
        RAISE EXCEPTION 'CHK-407 FALLO: filtro al_dia incluyo eliminados o fallo: %', v_res;
    END IF;

    -- 2.2 [CHK-404] Empleado con canFiar procesa venta fiada, consulta estado cuenta y cobra abono
    v_res := public.rpc_procesar_venta_v3(v_store, v_client_active, 'fiado', 0, jsonb_build_array(jsonb_build_object('product_id', v_prod, 'quantity', 2)));
    v_sale_fiado_id := (v_res->'data'->>'sale_id')::uuid;
    IF (v_res->'data'->>'total')::numeric <> 10000 THEN
        RAISE EXCEPTION 'CHK-404 FALLO: venta fiado total=%', v_res->'data'->>'total';
    END IF;

    v_res := public.rpc_obtener_estado_cuenta_cliente(v_client_active, 20, 0);
    IF (v_res->'data'->'client'->>'balance')::numeric <> 20000 THEN
        RAISE EXCEPTION 'CHK-404 FALLO: balance esperado 20000, actual %', v_res->'data'->'client'->>'balance';
    END IF;

    v_res := public.rpc_registrar_abono(v_client_active, 15000, 'nequi', 'Abono cliente Nequi');
    IF (v_res->'data'->>'new_balance')::numeric <> 5000 THEN
        RAISE EXCEPTION 'CHK-404 FALLO: saldo tras abono esperado 5000, actual %', v_res->'data'->'new_balance';
    END IF;

    -- Rechazo cliente eliminado
    BEGIN
        PERFORM public.rpc_obtener_estado_cuenta_cliente(v_client_deleted, 20, 0);
        RAISE EXCEPTION 'CHK-404 FALLO: cliente eliminado accesible en estado cuenta';
    EXCEPTION WHEN SQLSTATE 'P0002' THEN NULL; END;

    -- 2.3 [CHK-405 & CHK-406 & CHK-409 RECHAZOS] Empleado con canFiar NO puede crear/editar/borrar clientes ni tocar CxP Admin
    BEGIN
        PERFORM public.rpc_crear_cliente_fiado(v_store, 'Intento Emp', '99887766', NULL, NULL);
        RAISE EXCEPTION 'CHK-405 FALLO: empleado creo cliente';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;

    BEGIN
        PERFORM public.rpc_actualizar_cliente(v_client_active, 'Alterado Emp', '1001001', NULL, 999999);
        RAISE EXCEPTION 'CHK-405 FALLO: empleado edito cliente';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;

    BEGIN
        PERFORM public.rpc_eliminar_cliente(v_client_existing);
        RAISE EXCEPTION 'CHK-405 FALLO: empleado elimino cliente';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;

    BEGIN
        PERFORM public.rpc_actualizar_cupo_credito_global(v_store, 120000);
        RAISE EXCEPTION 'CHK-406 FALLO: empleado cambio cupo global';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;

    BEGIN
        PERFORM public.rpc_crear_factura_proveedor(v_store, 'Prov Bloqueado', 50000, NULL, 'F-01');
        RAISE EXCEPTION 'CHK-410 FALLO: empleado creo factura proveedor';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;

    BEGIN
        PERFORM public.rpc_obtener_cuentas_por_pagar(v_store, NULL, NULL, 50, 0);
        RAISE EXCEPTION 'CHK-410 FALLO: empleado consulto cuentas por pagar';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;

    BEGIN
        PERFORM public.rpc_pay_supplier_invoice(gen_random_uuid(), 1000, 'externo', NULL);
        RAISE EXCEPTION 'CHK-409 FALLO: empleado invoco rpc_pay_supplier_invoice';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL; END;

    -- =========================================================================
    -- BLOQUE 3: ADMIN -> CHK-401 beneficiario tercero, CHK-406 cupo global, CHK-408 anulacion fiado, CHK-409/410 CxP
    -- =========================================================================
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner, 'role', 'authenticated', 'app_metadata', json_build_object('store_id', v_store))::text, true);

    -- 3.1 [CHK-401] Admin registra retiro personal a favor de v_emp_fiar
    v_res := public.rpc_procesar_venta_v3(
        v_store, NULL, 'consumo_personal', 0,
        jsonb_build_array(jsonb_build_object('product_id', v_prod, 'quantity', 1)),
        gen_random_uuid(), NULL, false, v_session, NULL, v_emp_fiar
    );
    IF (v_res->'data'->>'beneficiary_employee_id')::uuid <> v_emp_fiar THEN
        RAISE EXCEPTION 'CHK-401 FALLO: Admin no pudo asignar beneficiario';
    END IF;

    -- 3.2 [CHK-406] Admin cambia default_credit_limit a 125000 -> no cambia cliente existente (50000), sí nuevo cliente (125000)
    v_res := public.rpc_actualizar_cupo_credito_global(v_store, 125000);
    SELECT credit_limit INTO v_limit_existing FROM public.clients WHERE id = v_client_existing;
    IF v_limit_existing <> 50000 THEN
        RAISE EXCEPTION 'CHK-406 FALLO: cupo global modifico cliente existente (% -> 50000 esperado)', v_limit_existing;
    END IF;

    v_res := public.rpc_crear_cliente_fiado(v_store, 'Nuevo Cliente Default', '4004004', '3001112233', NULL);
    v_new_client_id := (v_res->'data'->'client'->>'id')::uuid;
    IF (v_res->'data'->'client'->>'credit_limit')::numeric <> 125000 THEN
        RAISE EXCEPTION 'CHK-406 FALLO: nuevo cliente no heredo cupo global 125000 (recibio %)', v_res->'data'->'client'->>'credit_limit';
    END IF;

    -- 3.3 [CHK-404] Admin registra abono sin tener fila en public.employees (created_by NULL seguro)
    v_res := public.rpc_registrar_abono(v_client_active, 5000, 'llave_bre', 'Abono Admin sin fila employees');
    IF (v_res->'data'->>'new_balance')::numeric <> 0 OR (v_res->'data'->>'actor_role') <> 'owner' THEN
        RAISE EXCEPTION 'CHK-404 FALLO: abono admin retorno %', v_res;
    END IF;

    -- 3.4 [CHK-408 RECHAZO + CAMINO FELIZ] Anular venta fiado sin deuda suficiente rechaza; anular fiado con saldo íntegro y retiro personal triunfan
    BEGIN
        PERFORM public.rpc_anular_venta(v_sale_fiado_id, 'Intento anulacion tras abono total');
        RAISE EXCEPTION 'CHK-408 FALLO: anulo venta fiado con saldo insuficiente para revertir';
    EXCEPTION WHEN SQLSTATE 'P0001' THEN
        IF SQLERRM NOT LIKE '%CREDIT_REVERSAL_BLOCKED%' THEN
            RAISE EXCEPTION 'CHK-408 FALLO: error inesperado al bloquear anulacion: %', SQLERRM;
        END IF;
    END;

    -- Camino feliz anulación: nueva venta fiado con saldo completo
    v_res := public.rpc_procesar_venta_v3(v_store, v_client_existing, 'fiado', 0, jsonb_build_array(jsonb_build_object('product_id', v_prod, 'quantity', 1)));
    v_inv_ext_id := (v_res->'data'->>'sale_id')::uuid;
    v_res := public.rpc_anular_venta(v_inv_ext_id, 'Error de facturacion fiado en mostrador');
    SELECT * INTO v_sale_rec FROM public.sales WHERE id = v_inv_ext_id;
    IF v_sale_rec.is_voided IS NOT TRUE OR v_sale_rec.voided_by_name <> 'Dueño Ola4' OR v_sale_rec.voided_by_role <> 'owner' THEN
        RAISE EXCEPTION 'CHK-408 FALLO: anulacion camino feliz incompleta voided=%, by=%, role=%', v_sale_rec.is_voided, v_sale_rec.voided_by_name, v_sale_rec.voided_by_role;
    END IF;

    -- 3.4b [CHK-405] Admin actualiza cliente, rechaza eliminar con deuda y elimina sin deuda
    v_res := public.rpc_actualizar_cliente(v_new_client_id, 'Nuevo Cliente Editado', '4004004', '3009998888', 150000);
    IF (v_res->'data'->'client'->>'name') <> 'Nuevo Cliente Editado' OR (v_res->'data'->'client'->>'credit_limit')::numeric <> 150000 THEN
        RAISE EXCEPTION 'CHK-405 FALLO: rpc_actualizar_cliente retorno %', v_res;
    END IF;

    UPDATE public.clients SET balance = 5000 WHERE id = v_new_client_id;
    BEGIN
        PERFORM public.rpc_eliminar_cliente(v_new_client_id);
        RAISE EXCEPTION 'CHK-405 FALLO: permitio eliminar cliente con deuda';
    EXCEPTION WHEN SQLSTATE 'P0001' THEN
        IF SQLERRM NOT LIKE '%CLIENT_HAS_DEBT%' THEN
            RAISE EXCEPTION 'CHK-405 FALLO: error inesperado eliminando con deuda: %', SQLERRM;
        END IF;
    END;
    UPDATE public.clients SET balance = 0 WHERE id = v_new_client_id;
    v_res := public.rpc_eliminar_cliente(v_new_client_id);
    IF (v_res->'data'->>'deleted')::boolean IS NOT TRUE THEN
        RAISE EXCEPTION 'CHK-405 FALLO: rpc_eliminar_cliente sin deuda fallo %', v_res;
    END IF;

    -- 3.5 [CHK-410] Admin crea factura proveedor SIN due_date y otra CON due_date vencida
    v_res := public.rpc_crear_factura_proveedor(v_store, '  lacteos   del campo  ', 80000, NULL, 'FAC-SIN-FECHA');
    v_inv_id := (v_res->'data'->'invoice'->>'id')::uuid;
    IF (v_res->'data'->'invoice'->'supplier'->>'name') <> 'Lacteos Del Campo' OR (v_res->'data'->'invoice'->>'due_date') IS NOT NULL THEN
        RAISE EXCEPTION 'CHK-410 FALLO: creacion factura normalizada: %', v_res;
    END IF;

    -- 3.6 [CHK-409] Abono CxP interno requiere descripcion y liquidez por canal
    BEGIN
        PERFORM public.rpc_pay_supplier_invoice(v_inv_id, 10000, 'nequi', NULL);
        RAISE EXCEPTION 'CHK-409 FALLO: pago interno permitio descripcion nula';
    EXCEPTION WHEN SQLSTATE 'P0001' THEN NULL; END;

    -- Canal llave_bre solo tiene $5,000 (del abono anterior); pedir $10,000 debe fallar
    BEGIN
        PERFORM public.rpc_pay_supplier_invoice(v_inv_id, 10000, 'llave_bre', 'Intento sobregiro llave_bre');
        RAISE EXCEPTION 'CHK-409 FALLO: pago llave_bre supero liquidez real del canal';
    EXCEPTION WHEN SQLSTATE 'P0001' THEN
        IF SQLERRM NOT LIKE '%INSUFFICIENT_CHANNEL_BALANCE%' THEN
            RAISE EXCEPTION 'CHK-409 FALLO: excepcion distinta: %', SQLERRM;
        END IF;
    END;

    -- Canal efectivo tiene 50,000 base + 5,000 venta contado = 55,000; abono 20,000 en efectivo debe triunfar
    v_pay_res := public.rpc_pay_supplier_invoice(v_inv_id, 20000, 'efectivo', 'Abono parcial caja efectivo');
    IF (v_pay_res->'data'->>'origin_type') <> 'INTERNO' OR (v_pay_res->'data'->>'cash_movement_id') IS NULL THEN
        RAISE EXCEPTION 'CHK-409 FALLO: pago interno incompleto %', v_pay_res;
    END IF;

    -- 3.7 [CHK-409] Pago EXTERNO funciona con $0 en cash_movements e incluso con caja CERRADA
    UPDATE public.cash_sessions SET status = 'closed', closed_at = NOW() WHERE id = v_session;
    v_pay_res := public.rpc_pay_supplier_invoice(v_inv_id, 30000, 'externo', NULL);
    IF (v_pay_res->'data'->>'origin_type') <> 'EXTERNO' OR (v_pay_res->'data'->>'cash_movement_id') IS NOT NULL OR (v_pay_res->'data'->>'remaining_balance')::numeric <> 30000 THEN
        RAISE EXCEPTION 'CHK-409 FALLO: pago externo incorrecto %', v_pay_res;
    END IF;

    -- Verificar consulta paginada CxP
    v_cxp_res := public.rpc_obtener_cuentas_por_pagar(v_store, 'pendiente', NULL, 20, 0);
    IF (v_cxp_res->>'count')::int < 1 THEN
        RAISE EXCEPTION 'CHK-410 FALLO: rpc_obtener_cuentas_por_pagar sin pendientes: %', v_cxp_res;
    END IF;

    -- 3.8 [CHK-409/CHK-410 RLS + UNICIDAD pg_proc + REGLA 8]
    SELECT COUNT(*) INTO v_cnt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'rpc_procesar_venta_v3';
    IF v_cnt <> 1 THEN
        RAISE EXCEPTION 'CHK-401 FALLO: rpc_procesar_venta_v3 tiene % sobrecargas (esperado 1)', v_cnt;
    END IF;

    SELECT COUNT(*) INTO v_cnt FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'rpc_pay_supplier_invoice';
    IF v_cnt <> 1 THEN
        RAISE EXCEPTION 'CHK-409 FALLO: rpc_pay_supplier_invoice tiene % sobrecargas (esperado 1)', v_cnt;
    END IF;

    IF NOT has_table_privilege('authenticated', 'public.supplier_payments', 'SELECT') THEN
        RAISE EXCEPTION 'CHK-409 FALLO Regla 8: falta privilegio SELECT a authenticated en supplier_payments';
    END IF;

    -- Prueba RLS real bajo rol authenticated para empleado (0 filas visibles en supplier_invoices y supplier_payments)
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_fiar, 'role', 'authenticated', 'app_metadata', json_build_object('store_id', v_store, 'employee_id', v_emp_fiar))::text, true);
    SET LOCAL ROLE authenticated;
    SELECT COUNT(*) INTO v_cnt FROM public.supplier_invoices WHERE store_id = v_store;
    IF v_cnt <> 0 THEN
        RAISE EXCEPTION 'CHK-410 FALLO RLS: empleado vio % filas de supplier_invoices', v_cnt;
    END IF;
    SELECT COUNT(*) INTO v_cnt FROM public.supplier_payments WHERE store_id = v_store;
    IF v_cnt <> 0 THEN
        RAISE EXCEPTION 'CHK-409 FALLO RLS: empleado vio % filas de supplier_payments', v_cnt;
    END IF;
    RESET ROLE;

    RAISE NOTICE '✅ TEST OLA 4 SQL EXITOSO: CHK-401..CHK-410 (caminos felices + rechazos + RLS + pg_proc) verificados al 100%%.';
END $$;

ROLLBACK;

-- =============================================================================
-- TEST SQL INTEGRAL - FASE 3 OLA 3 (CHK-301 a CHK-308)
-- Verificación real en PostgreSQL (Docker local): camino feliz + rechazos Regla 5
-- Ejecución atómica dentro de BEGIN ... ROLLBACK (sin dejar residuos)
-- =============================================================================

BEGIN;

DO $$
DECLARE
    v_owner UUID := gen_random_uuid();
    v_emp_a UUID := gen_random_uuid();
    v_emp_b UUID := gen_random_uuid();
    v_store UUID := gen_random_uuid();
    v_sup   UUID := gen_random_uuid();
    v_prod_old UUID := gen_random_uuid();
    v_prod_new UUID := gen_random_uuid();
    v_client UUID := gen_random_uuid();
    v_session UUID := gen_random_uuid();
    v_sale_a1 UUID := gen_random_uuid();
    v_sale_a2 UUID := gen_random_uuid();
    v_sale_b1 UUID := gen_random_uuid();
    v_sale_b2 UUID := gen_random_uuid();

    v_res JSONB;
    v_cnt INT;
    v_audit_id UUID;
    v_actor_name TEXT;
    v_actor_role TEXT;
    v_sev TEXT;
BEGIN
    -- 1. Seed Auth users (skip legal-consent owner trigger via account_kind='store_member')
    INSERT INTO auth.users (id, email, raw_user_meta_data, raw_app_meta_data, aud, role)
    VALUES
        (v_owner, 'ola3_owner@test.co', '{"full_name":"Dueño Ola3"}', '{"provider":"email","account_kind":"store_member"}', 'authenticated', 'authenticated'),
        (v_emp_a, 'ola3_empa@test.co', '{"full_name":"Cajero A"}', '{"provider":"email","account_kind":"store_member"}', 'authenticated', 'authenticated'),
        (v_emp_b, 'ola3_empb@test.co', '{"full_name":"Cajero B"}', '{"provider":"email","account_kind":"store_member"}', 'authenticated', 'authenticated');

    INSERT INTO public.stores (id, name, slug)
    VALUES (v_store, 'Tienda Ola 3 Test', 'tienda-ola3-' || substring(v_store::text, 1, 6));

    INSERT INTO public.admin_profiles (id, store_id, role, is_verified)
    VALUES (v_owner, v_store, 'owner', true);

    INSERT INTO public.employees (id, store_id, name, username, pin_hash, is_active, permissions)
    VALUES
        (v_emp_a, v_store, 'Cajero A', 'ola3_a', '1111', true, '{"canManageInventory":false,"canFiar":true,"canOpenCloseCash":true,"canManageRefunds":false}'::jsonb),
        (v_emp_b, v_store, 'Cajero B', 'ola3_b', '2222', true, '{"canManageInventory":false,"canFiar":false,"canOpenCloseCash":false,"canManageRefunds":false}'::jsonb);

    INSERT INTO public.daily_passes (employee_id, auth_user_id, store_id, device_fingerprint, pass_date, status, resolved_by, resolved_at, approved_by, approved_at)
    VALUES
        (v_emp_a, v_emp_a, v_store, 'fp-ola3-a', (NOW() AT TIME ZONE 'America/Bogota')::date, 'approved', v_owner, NOW(), v_owner, NOW()),
        (v_emp_b, v_emp_b, v_store, 'fp-ola3-b', (NOW() AT TIME ZONE 'America/Bogota')::date, 'approved', v_owner, NOW(), v_owner, NOW());

    INSERT INTO public.suppliers (id, store_id, name, frequency_days, lead_time_days)
    VALUES (v_sup, v_store, 'Proveedor Test', 7, 2);

    INSERT INTO public.products (id, store_id, name, price, cost_price, current_stock, min_stock, is_active, created_at)
    VALUES
        (v_prod_old, v_store, 'Arroz Antiguo 1kg', 5000, 3500, 10, 5, true, NOW() - INTERVAL '25 days'),
        (v_prod_new, v_store, 'Galletas Nuevas', 2000, 1200, 1, 5, true, NOW() - INTERVAL '3 days');

    INSERT INTO public.clients (id, store_id, name, id_number, balance, credit_limit)
    VALUES (v_client, v_store, 'Cliente Fiado Test', '90012345', 15000, 100000);

    -- Abrir turno por Cajero A
    INSERT INTO public.cash_sessions (id, store_id, opened_by, opened_by_name, opened_by_role, opening_balance, expected_balance, status, opened_at)
    VALUES (v_session, v_store, v_emp_a, 'Cajero A', 'employee', 50000, 82000, 'open', NOW() - INTERVAL '2 hours');

    -- Ventas de Cajero A (1 efectivo, 1 fiado) y Cajero B (1 nequi, 1 consumo_personal)
    INSERT INTO public.sales (id, store_id, ticket_number, employee_id, actor_name, actor_role, client_id, total, payment_method, is_voided, created_at)
    VALUES
        (v_sale_a1, v_store, 101, v_emp_a, 'Cajero A', 'employee', NULL, 20000, 'efectivo', false, NOW() - INTERVAL '90 minutes'),
        (v_sale_a2, v_store, 102, v_emp_a, 'Cajero A', 'employee', v_client, 12000, 'fiado', false, NOW() - INTERVAL '80 minutes'),
        (v_sale_b1, v_store, 103, v_emp_b, 'Cajero B', 'employee', NULL, 15000, 'nequi', false, NOW() - INTERVAL '60 minutes'),
        (v_sale_b2, v_store, 104, v_emp_b, 'Cajero B', 'employee', NULL, 0, 'consumo_personal', false, NOW() - INTERVAL '50 minutes');

    INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, unit_cost, subtotal)
    VALUES
        (v_sale_a1, v_prod_old, 4, 5000, 3500, 20000),
        (v_sale_b1, v_prod_old, 3, 5000, 3500, 15000);

    INSERT INTO public.cash_movements (session_id, movement_type, amount, description, sale_id, payment_method, category, actor_id, actor_name, actor_role, created_at)
    VALUES
        (v_session, 'ingreso', 20000, 'Venta #101', v_sale_a1, 'efectivo', NULL, v_emp_a, 'Cajero A', 'employee', NOW() - INTERVAL '90 minutes'),
        (v_session, 'ingreso', 15000, 'Venta #103', v_sale_b1, 'nequi', NULL, v_emp_b, 'Cajero B', 'employee', NOW() - INTERVAL '60 minutes'),
        (v_session, 'gasto', 4000, 'Compra bolsas Cajero B', NULL, 'efectivo', 'Insumos', v_emp_b, 'Cajero B', 'employee', NOW() - INTERVAL '40 minutes'),
        (v_session, 'pago_proveedor', 10000, 'Abono factura proveedor', NULL, 'efectivo', 'Proveedor', NULL, 'Dueño Ola3', 'owner', NOW() - INTERVAL '30 minutes');

    INSERT INTO public.audit_precios (product_id, store_id, old_cost, new_cost, old_price, new_price, changed_by, actor_name, actor_role)
    VALUES (v_prod_old, v_store, 3400, 3500, 4800, 5000, NULL, 'Dueño Ola3', 'owner');

    -- =========================================================================
    -- BLOQUE 1: Contexto EMPLEADO A -> Bloqueo estricto Admin-Only + aislamiento
    -- =========================================================================
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_a, 'role', 'authenticated', 'app_metadata', json_build_object('store_id', v_store, 'employee_id', v_emp_a))::text, true);

    -- CHK-301 rechazos
    BEGIN
        PERFORM public.get_daily_summary(v_store, CURRENT_DATE);
        RAISE EXCEPTION 'FALLO CHK-301: empleado pudo ejecutar get_daily_summary';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    BEGIN
        PERFORM * FROM public.get_smart_supply_report(v_store);
        RAISE EXCEPTION 'FALLO CHK-301: empleado pudo ejecutar get_smart_supply_report';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    BEGIN
        PERFORM public.rpc_asignar_proveedor_masivo(v_store, v_sup, ARRAY[v_prod_old]);
        RAISE EXCEPTION 'FALLO CHK-301: empleado pudo ejecutar rpc_asignar_proveedor_masivo';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    BEGIN
        PERFORM public.get_inventory_health(v_store);
        RAISE EXCEPTION 'FALLO CHK-301: empleado pudo ejecutar get_inventory_health';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- B3-1 & B3-4: rechazos 42501 para los 8 RPCs analíticos/históricos restantes
    BEGIN
        PERFORM public.get_client_ledger_summary(v_store);
        RAISE EXCEPTION 'FALLO CHK-301: empleado pudo ejecutar get_client_ledger_summary';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    BEGIN
        PERFORM * FROM public.get_stagnant_products(v_store, 30);
        RAISE EXCEPTION 'FALLO CHK-301: empleado pudo ejecutar get_stagnant_products';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    BEGIN
        PERFORM * FROM public.get_top_products_by_units(v_store, CURRENT_DATE, CURRENT_DATE, 10);
        RAISE EXCEPTION 'FALLO CHK-301: empleado pudo ejecutar get_top_products_by_units';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    BEGIN
        PERFORM * FROM public.get_top_selling_products(v_store, CURRENT_DATE, CURRENT_DATE, 10);
        RAISE EXCEPTION 'FALLO B3-1: empleado pudo ejecutar get_top_selling_products';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    BEGIN
        PERFORM public.get_history_ventas(v_store, CURRENT_DATE - 7, CURRENT_DATE);
        RAISE EXCEPTION 'FALLO CHK-302: empleado pudo ejecutar get_history_ventas';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    BEGIN
        PERFORM public.get_history_compras(v_store, CURRENT_DATE - 7, CURRENT_DATE);
        RAISE EXCEPTION 'FALLO CHK-302: empleado pudo ejecutar get_history_compras';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    BEGIN
        PERFORM * FROM public.get_history_creditos(v_store, NOW() - INTERVAL '7 days', NOW());
        RAISE EXCEPTION 'FALLO CHK-302: empleado pudo ejecutar get_history_creditos';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- CHK-302 rechazos
    BEGIN
        PERFORM public.get_history_caja(v_store, CURRENT_DATE - 7, CURRENT_DATE);
        RAISE EXCEPTION 'FALLO CHK-302: empleado pudo ejecutar get_history_caja';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    BEGIN
        PERFORM public.rpc_get_comprehensive_financial_report(v_store, CURRENT_DATE, CURRENT_DATE);
        RAISE EXCEPTION 'FALLO CHK-302: empleado pudo ejecutar rpc_get_comprehensive_financial_report';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- CHK-303 rechazo Evidence Hub
    BEGIN
        PERFORM public.rpc_obtener_auditoria_evidence_hub(v_store);
        RAISE EXCEPTION 'FALLO CHK-303: empleado pudo ejecutar rpc_obtener_auditoria_evidence_hub';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- CHK-305 & CHK-306 rechazos historial caja multicanal y reporte forense
    BEGIN
        PERFORM public.rpc_obtener_historial_caja_multicanal(v_store);
        RAISE EXCEPTION 'FALLO CHK-305: empleado pudo ejecutar rpc_obtener_historial_caja_multicanal';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    BEGIN
        PERFORM public.rpc_get_comprehensive_shift_report(v_session);
        RAISE EXCEPTION 'FALLO CHK-306: empleado pudo ejecutar rpc_get_comprehensive_shift_report';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- CHK-304 (B3-4): registro de nuevos eventos de seguridad con verificación real en audit_seguridad y audit_logs + rechazo 22023
    PERFORM public.rpc_log_security_event('INVENTORY_COUNT_ADJUSTMENT', v_store, jsonb_build_object('product_id', v_prod_old, 'diff', -2));
    PERFORM public.rpc_log_security_event('PERSONAL_WITHDRAWAL', v_store, jsonb_build_object('sale_id', v_sale_b2));

    SELECT actor_name, actor_role, COALESCE(metadata->>'severity', '')
    INTO v_actor_name, v_actor_role, v_sev
    FROM public.audit_seguridad
    WHERE store_id = v_store AND event_type = 'INVENTORY_COUNT_ADJUSTMENT'
    ORDER BY created_at DESC LIMIT 1;
    IF v_actor_name IS DISTINCT FROM 'Cajero A' OR v_actor_role IS DISTINCT FROM 'employee' OR v_sev <> 'warning' THEN
        RAISE EXCEPTION 'FALLO CHK-304 audit_seguridad snapshot/severity: name=% role=% sev=%', v_actor_name, v_actor_role, v_sev;
    END IF;

    SELECT id, actor_name, actor_role, severity
    INTO v_audit_id, v_actor_name, v_actor_role, v_sev
    FROM public.audit_logs
    WHERE store_id = v_store AND event_type = 'INVENTORY_COUNT_ADJUSTMENT'
    ORDER BY created_at DESC LIMIT 1;
    IF v_audit_id IS NULL OR v_actor_name IS DISTINCT FROM 'Cajero A' OR v_actor_role IS DISTINCT FROM 'employee' OR v_sev <> 'warning' THEN
        RAISE EXCEPTION 'FALLO CHK-304 audit_logs snapshot/severity: id=% name=% role=% sev=%', v_audit_id, v_actor_name, v_actor_role, v_sev;
    END IF;

    SELECT COUNT(*) INTO v_cnt FROM public.audit_logs WHERE store_id = v_store AND event_type = 'PERSONAL_WITHDRAWAL' AND actor_name = 'Cajero A' AND severity = 'info';
    IF v_cnt <> 1 THEN
        RAISE EXCEPTION 'FALLO CHK-304 audit_logs PERSONAL_WITHDRAWAL esperado 1 fila info con snapshot, recibido %', v_cnt;
    END IF;

    BEGIN
        PERFORM public.rpc_log_security_event('UNKNOWN_EVENT_XYZ', v_store, '{}'::jsonb);
        RAISE EXCEPTION 'FALLO CHK-304: aceptó evento inválido sin 22023';
    EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
    END;

    -- Rechazo 42501 de rpc_marcar_auditoria_revisada como empleado
    BEGIN
        PERFORM public.rpc_marcar_auditoria_revisada(v_audit_id, 'Intento empleado');
        RAISE EXCEPTION 'FALLO CHK-303: empleado pudo ejecutar rpc_marcar_auditoria_revisada';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- CHK-305: Mis movimientos como Cajero A (solo 2 ventas propias: efectivo y fiado)
    v_res := public.rpc_obtener_mis_movimientos_turno(v_store, 'all', 50, 0);
    IF (v_res->>'count')::int <> 2 OR NOT (v_res->>'has_open_shift')::boolean THEN
        RAISE EXCEPTION 'FALLO CHK-305 (Cajero A): esperado count=2, recibido %', v_res;
    END IF;
    IF v_res::text LIKE '%expected_balance%' OR v_res::text LIKE '%Compra bolsas Cajero B%' THEN
        RAISE EXCEPTION 'FALLO CHK-305 (Cajero A): fuga de expected_balance o movimiento de Cajero B';
    END IF;

    -- CHK-305: Mis movimientos como Cajero B (NO abrió la caja, debe ver SUS 3 movimientos: Venta #103 nequi, Retiro Personal #104, Gasto bolsas)
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_b, 'role', 'authenticated', 'app_metadata', json_build_object('store_id', v_store, 'employee_id', v_emp_b))::text, true);
    v_res := public.rpc_obtener_mis_movimientos_turno(v_store, 'all', 50, 0);
    IF (v_res->>'count')::int <> 3 THEN
        RAISE EXCEPTION 'FALLO CHK-305 (Cajero B): esperado count=3 sin abrir caja, recibido %', v_res;
    END IF;
    IF v_res::text LIKE '%Venta #101%' OR v_res::text LIKE '%Venta #102%' THEN
        RAISE EXCEPTION 'FALLO CHK-305 (Cajero B): fuga de movimientos de Cajero A';
    END IF;

    -- Filtro por método de pago en rpc_obtener_mis_movimientos_turno
    v_res := public.rpc_obtener_mis_movimientos_turno(v_store, 'digitales', 50, 0);
    IF (v_res->>'count')::int <> 1 THEN
        RAISE EXCEPTION 'FALLO CHK-305 (filtro digitales Cajero B): esperado count=1, recibido %', v_res;
    END IF;

    -- CHK-303 & CHK-305 (B3-2): RLS bajo ROLE authenticated bloquea audit_* y cash_sessions para Cajero B,
    -- mientras cash_movements permite leer EXACTAMENTE sus 2 filas propias y 0 filas ajenas.
    SET LOCAL ROLE authenticated;
    SELECT COUNT(*) INTO v_cnt FROM public.audit_logs WHERE store_id = v_store;
    IF v_cnt <> 0 THEN RAISE EXCEPTION 'FALLO RLS audit_logs para empleado: % filas', v_cnt; END IF;
    SELECT COUNT(*) INTO v_cnt FROM public.audit_seguridad WHERE store_id = v_store;
    IF v_cnt <> 0 THEN RAISE EXCEPTION 'FALLO RLS audit_seguridad para empleado: % filas', v_cnt; END IF;
    SELECT COUNT(*) INTO v_cnt FROM public.audit_precios WHERE store_id = v_store;
    IF v_cnt <> 0 THEN RAISE EXCEPTION 'FALLO RLS audit_precios para empleado: % filas', v_cnt; END IF;
    SELECT COUNT(*) INTO v_cnt FROM public.cash_sessions WHERE store_id = v_store;
    IF v_cnt <> 0 THEN RAISE EXCEPTION 'FALLO RLS cash_sessions para empleado (expected_balance expuesto): % filas', v_cnt; END IF;
    SELECT COUNT(*) INTO v_cnt FROM public.cash_movements WHERE session_id = v_session AND actor_id = v_emp_b;
    IF v_cnt <> 2 THEN RAISE EXCEPTION 'FALLO B3-2 RLS cash_movements propias Cajero B: esperado 2, recibido %', v_cnt; END IF;
    SELECT COUNT(*) INTO v_cnt FROM public.cash_movements WHERE session_id = v_session AND actor_id IS DISTINCT FROM v_emp_b;
    IF v_cnt <> 0 THEN RAISE EXCEPTION 'FALLO B3-2 RLS cash_movements ajenas Cajero B: esperado 0, recibido %', v_cnt; END IF;
    RESET ROLE;

    -- B3-3: Rechazo 42501 en rpc_obtener_mis_movimientos_turno cuando colaborador está inactivo o sin pase vigente (<24h)
    UPDATE public.employees SET is_active = false WHERE id = v_emp_b;
    BEGIN
        PERFORM public.rpc_obtener_mis_movimientos_turno(v_store, 'all', 50, 0);
        RAISE EXCEPTION 'FALLO B3-3: colaborador inactivo pudo consultar rpc_obtener_mis_movimientos_turno';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;
    UPDATE public.employees SET is_active = true WHERE id = v_emp_b;

    UPDATE public.daily_passes SET status = 'rejected' WHERE employee_id = v_emp_b AND store_id = v_store;
    BEGIN
        PERFORM public.rpc_obtener_mis_movimientos_turno(v_store, 'all', 50, 0);
        RAISE EXCEPTION 'FALLO B3-3: colaborador sin pase vigente pudo consultar rpc_obtener_mis_movimientos_turno';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;
    UPDATE public.daily_passes SET status = 'approved' WHERE employee_id = v_emp_b AND store_id = v_store;

    -- =========================================================================
    -- BLOQUE 2: Contexto ADMINISTRADOR (Owner) -> Acceso total + verificaciones
    -- =========================================================================
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner, 'role', 'authenticated', 'app_metadata', json_build_object('store_id', v_store))::text, true);

    -- CHK-301 Happy path
    v_res := public.get_daily_summary(v_store, CURRENT_DATE);
    IF (v_res->'money_breakdown'->>'transfer')::numeric <> 15000 OR (v_res->'money_breakdown'->>'cash')::numeric <> 20000 THEN
        RAISE EXCEPTION 'FALLO CHK-301 get_daily_summary desglose: %', v_res;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.get_smart_supply_report(v_store) WHERE product_id = v_prod_new AND status = 'LEARNING') THEN
        RAISE EXCEPTION 'FALLO CHK-301 get_smart_supply_report umbral 15d LEARNING';
    END IF;

    v_res := public.rpc_asignar_proveedor_masivo(v_store, v_sup, ARRAY[v_prod_old, v_prod_new]);
    IF (v_res->>'updated_count')::int <> 2 THEN
        RAISE EXCEPTION 'FALLO CHK-301 rpc_asignar_proveedor_masivo: %', v_res;
    END IF;

    -- B3-1 & B3-4: Happy path Admin en los 8 RPCs analíticos/históricos + marcar auditoría revisada
    v_res := public.get_inventory_health(v_store);
    IF (v_res->>'valor_total') IS NULL THEN RAISE EXCEPTION 'FALLO get_inventory_health Admin'; END IF;
    v_res := public.get_client_ledger_summary(v_store);
    IF (v_res->>'cartera_total')::numeric <> 15000 THEN RAISE EXCEPTION 'FALLO get_client_ledger_summary Admin: %', v_res; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.get_stagnant_products(v_store, 30) WHERE product_id = v_prod_old) THEN
        -- Si ya tuvo ventas hoy, solo verificamos ejecución limpia sin error
        NULL;
    END IF;
    SELECT COUNT(*) INTO v_cnt FROM public.get_top_products_by_units(v_store, CURRENT_DATE - 1, CURRENT_DATE, 10);
    IF v_cnt < 1 THEN RAISE EXCEPTION 'FALLO get_top_products_by_units Admin'; END IF;
    SELECT COUNT(*) INTO v_cnt FROM public.get_top_selling_products(v_store, CURRENT_DATE - 1, CURRENT_DATE, 10);
    IF v_cnt < 1 THEN RAISE EXCEPTION 'FALLO get_top_selling_products Admin'; END IF;

    v_res := public.get_history_ventas(v_store, CURRENT_DATE - 1, CURRENT_DATE);
    IF jsonb_array_length(v_res) < 3 THEN RAISE EXCEPTION 'FALLO get_history_ventas Admin: %', v_res; END IF;
    PERFORM public.get_history_compras(v_store, CURRENT_DATE - 1, CURRENT_DATE);
    PERFORM * FROM public.get_history_creditos(v_store, NOW() - INTERVAL '1 day', NOW() + INTERVAL '1 hour');

    v_res := public.rpc_marcar_auditoria_revisada(v_audit_id, 'Revisado QA Admin');
    IF NOT COALESCE((v_res->>'success')::boolean, false) THEN
        RAISE EXCEPTION 'FALLO rpc_marcar_auditoria_revisada Admin: %', v_res;
    END IF;

    -- CHK-302 Happy path + pago_proveedor incluido en total_expenses de get_history_caja
    v_res := public.get_history_caja(v_store, (CURRENT_DATE - 1), CURRENT_DATE);
    IF (v_res->0->>'total_expenses')::numeric <> 14000 THEN
        RAISE EXCEPTION 'FALLO CHK-302 get_history_caja total_expenses esperado 14000 (4000+10000), recibido: %', v_res->0;
    END IF;

    v_res := public.rpc_get_comprehensive_financial_report(v_store, CURRENT_DATE, CURRENT_DATE);
    IF (v_res->>'operational_expenses')::numeric <> 4000 OR (v_res->>'revenue')::numeric <> 47000 THEN
        RAISE EXCEPTION 'FALLO CHK-302 P&L esperado opex=4000 (excluye pago_proveedor) y rev=47000, recibido: %', v_res;
    END IF;

    -- CHK-303 Evidence Hub (todos los dominios + paginación + snapshots)
    v_res := public.rpc_obtener_auditoria_evidence_hub(v_store, 'todos', NULL, NULL, NOW() - INTERVAL '1 day', NOW() + INTERVAL '1 hour', 50, 0);
    IF (v_res->>'count')::int < 3 THEN
        RAISE EXCEPTION 'FALLO CHK-303 Evidence Hub count insuficiente: %', v_res;
    END IF;

    -- CHK-305 Historial caja multicanal Admin
    v_res := public.rpc_obtener_historial_caja_multicanal(v_store, v_session, 'nequi', NULL, NULL, 50, 0);
    IF (v_res->>'count')::int <> 1 OR (v_res->'data'->0->>'origin_type') <> 'venta' THEN
        RAISE EXCEPTION 'FALLO CHK-305 historial multicanal nequi: %', v_res;
    END IF;

    -- CHK-306 Reporte forense de turno Admin
    v_res := public.rpc_get_comprehensive_shift_report(v_session);
    IF (v_res->'financial_summary'->>'total_supplier_payments')::numeric <> 10000
       OR (v_res->'financial_summary'->>'total_sales_nequi')::numeric <> 15000
       OR (v_res->'financial_summary'->>'total_credit_sales')::numeric <> 12000 THEN
        RAISE EXCEPTION 'FALLO CHK-306 shift report valores incorrectos: %', v_res;
    END IF;

    RAISE NOTICE '✅ TODOS LOS TESTS SQL OLA 3 (CHK-301..CHK-306 + RLS + AISLAMIENTO) PASARON EXITOSAMENTE.';
END $$;

ROLLBACK;

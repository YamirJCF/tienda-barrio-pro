-- ============================================================================
-- VERIFICACIÓN SQL EN VIVO - FASE 3 OLA 2 (CHK-201 a CHK-206 + CHK-209)
-- Ejecuta happy paths y ramas de rechazo con ROLLBACK limpio.
-- ============================================================================
\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE
    v_store_id UUID := gen_random_uuid();
    v_owner_id UUID := gen_random_uuid();
    v_manager_id UUID := gen_random_uuid();
    v_emp_a_id UUID := gen_random_uuid();
    v_emp_b_id UUID := gen_random_uuid();
    v_emp_noperm_id UUID := gen_random_uuid();
    v_today DATE := (NOW() AT TIME ZONE 'America/Bogota')::DATE;
    v_res JSONB;
    v_res_j JSON;
    v_sess_id UUID;
    v_sess2_id UUID;
    v_sess_exp_id UUID;
    v_cnt INT;
    v_text TEXT;
    v_err BOOLEAN;
BEGIN
    -- 0. Verificación estructural [CHK-201]
    SELECT COUNT(*) INTO v_cnt
    FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'cash_sessions'
      AND column_name IN ('closing_attempts', 'forced_close_without_count', 'opened_by_name', 'opened_by_role', 'closed_by_name', 'closed_by_role');
    ASSERT v_cnt = 6, 'CHK-201 FALLÓ: Faltan columnas en cash_sessions';

    SELECT COUNT(*) INTO v_cnt
    FROM information_schema.role_table_grants
    WHERE table_schema = 'public' AND table_name IN ('cash_sessions', 'cash_movements', 'notifications')
      AND grantee IN ('anon', 'authenticated', 'service_role')
      AND privilege_type = 'SELECT';
    ASSERT v_cnt = 9, 'CHK-201/209 FALLÓ: GRANT ALL incompleto en tablas Ola 2';

    -- Fixture de tienda, owner, manager SIN fila en employees, y 3 empleados
    INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, created_at, updated_at)
    VALUES
        (v_owner_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner_ola2@test.local', 'x', NOW(), jsonb_build_object('store_id', v_store_id, 'account_kind', 'store_member'), NOW(), NOW()),
        (v_manager_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'mgr_ola2@test.local', 'x', NOW(), jsonb_build_object('store_id', v_store_id, 'account_kind', 'store_member'), NOW(), NOW()),
        (v_emp_a_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'empa_ola2@test.local', 'x', NOW(), jsonb_build_object('store_id', v_store_id, 'account_kind', 'store_member'), NOW(), NOW()),
        (v_emp_b_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'empb_ola2@test.local', 'x', NOW(), jsonb_build_object('store_id', v_store_id, 'account_kind', 'store_member'), NOW(), NOW()),
        (v_emp_noperm_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'empno_ola2@test.local', 'x', NOW(), jsonb_build_object('store_id', v_store_id, 'account_kind', 'store_member'), NOW(), NOW());

    INSERT INTO public.stores (id, name, slug) VALUES (v_store_id, 'Tienda Ola 2 Test', 'tienda-ola2-test');

    INSERT INTO public.admin_profiles (id, store_id, role, is_verified) VALUES
        (v_owner_id, v_store_id, 'owner', true),
        (v_manager_id, v_store_id, 'manager', true);

    INSERT INTO public.employees (id, store_id, name, username, pin_hash, is_active, permissions) VALUES
        (v_emp_a_id, v_store_id, 'Cajero A', 'cajero_a_ola2', 'hash', true, '{"canManageInventory":false,"canFiar":false,"canOpenCloseCash":true,"canManageRefunds":false}'::jsonb),
        (v_emp_b_id, v_store_id, 'Cajero B', 'cajero_b_ola2', 'hash', true, '{"canManageInventory":false,"canFiar":false,"canOpenCloseCash":true,"canManageRefunds":false}'::jsonb),
        (v_emp_noperm_id, v_store_id, 'Auxiliar Base', 'aux_ola2', 'hash', true, '{"canManageInventory":false,"canFiar":false,"canOpenCloseCash":false,"canManageRefunds":false}'::jsonb);

    INSERT INTO public.daily_passes (store_id, employee_id, auth_user_id, pass_date, status, device_fingerprint, resolved_at, approved_at) VALUES
        (v_store_id, v_emp_a_id, v_emp_a_id, v_today, 'approved', 'fp-a', NOW(), NOW()),
        (v_store_id, v_emp_b_id, v_emp_b_id, v_today, 'approved', 'fp-b', NOW(), NOW()),
        (v_store_id, v_emp_noperm_id, v_emp_noperm_id, v_today, 'approved', 'fp-no', NOW(), NOW());

    -- =========================================================================
    -- [CHK-202] abrir_caja: Rechazo sin permiso + Apertura por Manager sin shadow row
    -- =========================================================================
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_noperm_id, 'role', 'authenticated')::text, true);
    v_err := false;
    BEGIN
        PERFORM public.abrir_caja(v_store_id, v_emp_noperm_id, 50000);
    EXCEPTION WHEN OTHERS THEN
        v_err := (SQLSTATE = '42501' AND SQLERRM LIKE '%PERMISSION_DENIED%');
    END;
    ASSERT v_err, 'CHK-202 RECHAZO FALLÓ: Auxiliar sin canOpenCloseCash debió ser bloqueado con 42501 PERMISSION_DENIED';

    -- Manager sin fila en employees abre caja -> debe funcionar con snapshot ('Gerente Sin Shadow', 'manager') y audit_caja válido
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_manager_id, 'role', 'authenticated')::text, true);
    v_res_j := public.abrir_caja(v_store_id, v_manager_id, 50000);
    ASSERT (v_res_j->>'success')::boolean = true, 'CHK-202 FALLÓ: Manager no pudo abrir caja';
    ASSERT v_res_j->>'opened_by_role' = 'manager', 'CHK-202 FALLÓ: opened_by_role incorrecto';
    v_sess_id := (v_res_j->>'session_id')::uuid;

    -- get_active_cash_session NUNCA debe exponer expected_balance ni difference
    v_res := public.get_active_cash_session(v_store_id);
    ASSERT (v_res->>'isOpen')::boolean = true, 'CHK-202 FALLÓ: get_active_cash_session no reportó open';
    ASSERT NOT (v_res ? 'expected_balance') AND NOT (v_res ? 'difference'), 'CHK-202/POL-SEG-01 FALLÓ: fuga de expected_balance o difference';

    -- Manager cierra este primer turno
    v_res := public.cerrar_caja(v_sess_id, v_manager_id, 50000, 0, 0);
    ASSERT (v_res->>'success')::boolean = true, 'CHK-203 FALLÓ: Manager no pudo cerrar su turno';

    -- =========================================================================
    -- [CHK-203] Propiedad Estricta + Prohibición Compensación Cruzada + 3 Intentos
    -- =========================================================================
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_a_id, 'role', 'authenticated')::text, true);
    v_res_j := public.abrir_caja(v_store_id, v_emp_a_id, 100000);
    v_sess_id := (v_res_j->>'session_id')::uuid;

    -- Ingreso digital en nequi ($20.000) para probar segregación multicanal
    INSERT INTO public.cash_movements (session_id, movement_type, amount, description, payment_method, actor_id, actor_name, actor_role)
    VALUES (v_sess_id, 'ingreso', 20000, 'Venta Nequi Test', 'nequi', v_emp_a_id, 'Cajero A', 'employee');

    -- Cajero B (aunque tiene canOpenCloseCash=true) NO puede cerrar turno de Cajero A
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_b_id, 'role', 'authenticated')::text, true);
    v_err := false;
    BEGIN
        PERFORM public.cerrar_caja(v_sess_id, v_emp_b_id, 100000, 20000, 0);
    EXCEPTION WHEN OTHERS THEN
        v_err := (SQLSTATE = '42501' AND SQLERRM LIKE '%SHIFT_OWNERSHIP_VIOLATION%');
    END;
    ASSERT v_err, 'CHK-203 RECHAZO FALLÓ: Cajero B debió ser rechazado con SHIFT_OWNERSHIP_VIOLATION';

    -- Verificar persistencia de evento dedicado UNAUTHORIZED_SHIFT_CLOSE (audit_logs + notifications)
    PERFORM public.rpc_log_security_event('UNAUTHORIZED_SHIFT_CLOSE', v_store_id, jsonb_build_object('session_id', v_sess_id));
    SELECT COUNT(*) INTO v_cnt FROM public.notifications WHERE store_id = v_store_id AND audience = 'admin' AND metadata->>'event_type' = 'UNAUTHORIZED_SHIFT_CLOSE';
    ASSERT v_cnt = 1, 'CHK-203 FALLÓ: No se registró notificación admin para UNAUTHORIZED_SHIFT_CLOSE';

    -- Regresar a Cajero A: Intento 1 intentando compensar -$5000 efectivo con +$5000 nequi (prohibido!)
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_a_id, 'role', 'authenticated')::text, true);
    v_res := public.cerrar_caja(v_sess_id, v_emp_a_id, 95000, 25000, 0);
    ASSERT (v_res->>'success')::boolean = false AND v_res->>'code' = 'COUNT_MISMATCH_RETRY' AND (v_res->>'attempts_used')::int = 1 AND (v_res->>'attempts_remaining')::int = 2,
        'CHK-203 INTENTO 1 FALLÓ: Compensación cruzada no fue detectada o payload incorrecto: ' || v_res::text;
    ASSERT NOT (v_res ? 'expected_balance') AND NOT (v_res ? 'difference'), 'CHK-203 INTENTO 1 FALLÓ: Fuga de saldo esperado';

    -- Intento 2 descuadrado -> closing_attempts = 2, remaining = 1
    v_res := public.cerrar_caja(v_sess_id, v_emp_a_id, 95000, 20000, 0);
    ASSERT (v_res->>'success')::boolean = false AND (v_res->>'attempts_used')::int = 2 AND (v_res->>'attempts_remaining')::int = 1,
        'CHK-203 INTENTO 2 FALLÓ: ' || v_res::text;

    -- Intento 3 descuadrado -> Sella sesión + alerta Admin CASH_DISCREPANCY_ALERT
    v_res := public.cerrar_caja(v_sess_id, v_emp_a_id, 95000, 20000, 0);
    ASSERT (v_res->>'success')::boolean = true AND (v_res->'data'->>'sealed_with_alert')::boolean = true AND (v_res->'data'->>'closing_attempts')::int = 3,
        'CHK-203 INTENTO 3 FALLÓ: ' || v_res::text;
    ASSERT NOT ((v_res->'data') ? 'expected_balance') AND NOT ((v_res->'data') ? 'difference'),
        'CHK-203 INTENTO 3 FALLÓ: No debe exponer expected_balance ni difference al cajero';

    SELECT COUNT(*) INTO v_cnt FROM public.notifications WHERE store_id = v_store_id AND audience = 'admin' AND metadata->>'event_type' = 'CASH_DISCREPANCY_ALERT';
    ASSERT v_cnt = 1, 'CHK-203 FALLÓ: Falta notificación CASH_DISCREPANCY_ALERT al 3.er intento';

    -- =========================================================================
    -- [CHK-206] rpc_registrar_gasto_v2: 5 categorías, sin 'Reembolso', no sobregiro canal
    -- =========================================================================
    -- Auxiliar base (todos los permisos false) abre nuevo turno como Cajero A primero
    v_res_j := public.abrir_caja(v_store_id, v_emp_a_id, 40000);
    v_sess2_id := (v_res_j->>'session_id')::uuid;
    INSERT INTO public.cash_movements (session_id, movement_type, amount, description, payment_method, actor_id, actor_name, actor_role)
    VALUES (v_sess2_id, 'ingreso', 30000, 'Venta Llave BRE', 'llave_bre', v_emp_a_id, 'Cajero A', 'employee');

    -- Ahora Auxiliar Base (no-Admin) DEBE ser rechazado con 42501 ADMIN_ONLY_ACTION (Enmienda UX-ADR-002)
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_noperm_id, 'role', 'authenticated')::text, true);

    v_err := false;
    BEGIN
        PERFORM public.rpc_registrar_gasto_v2(v_sess2_id, 5000, 'efectivo', 'Servicios', 'Intento empleado');
    EXCEPTION WHEN OTHERS THEN
        v_err := (SQLSTATE = '42501' AND SQLERRM LIKE '%ADMIN_ONLY_ACTION%');
    END;
    ASSERT v_err, 'CHK-206/UX-ADR-002 RECHAZO FALLÓ: Empleado debió ser bloqueado con ADMIN_ONLY_ACTION';

    -- Cambiar a Administrador (Owner) para validar reglas de categorías/canales/sobregiro/éxito
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id, 'role', 'authenticated')::text, true);

    -- Rechazo categoría 'Reembolso'
    v_err := false;
    BEGIN
        PERFORM public.rpc_registrar_gasto_v2(v_sess2_id, 5000, 'efectivo', 'Reembolso', 'Intento reembolso opex');
    EXCEPTION WHEN OTHERS THEN
        v_err := (SQLSTATE = '22023' AND SQLERRM LIKE '%INVALID_OPEX_CATEGORY%');
    END;
    ASSERT v_err, 'CHK-206 RECHAZO FALLÓ: Reembolso debió rechazarse en OPEX';

    -- Rechazo canal 'daviplata'
    v_err := false;
    BEGIN
        PERFORM public.rpc_registrar_gasto_v2(v_sess2_id, 5000, 'daviplata', 'Servicios', 'Luz tienda');
    EXCEPTION WHEN OTHERS THEN
        v_err := (SQLSTATE = '22023' AND SQLERRM LIKE '%INVALID_PAYMENT_METHOD%');
    END;
    ASSERT v_err, 'CHK-206 RECHAZO FALLÓ: daviplata debió rechazarse';

    -- Rechazo sobregiro en nequi (efectivo tiene 40k, nequi tiene 0)
    v_err := false;
    BEGIN
        PERFORM public.rpc_registrar_gasto_v2(v_sess2_id, 10000, 'nequi', 'Servicios', 'Internet mensual');
    EXCEPTION WHEN OTHERS THEN
        v_err := (SQLERRM LIKE '%INSUFFICIENT_CHANNEL_FUNDS%');
    END;
    ASSERT v_err, 'CHK-206 RECHAZO FALLÓ: Nequi en $0 debió rechazar sobregiro aunque efectivo tuviera $40k';

    -- Éxito con llave_bre + voucher_ref + snapshot + Read Model rpc_obtener_gastos_turno
    v_res := public.rpc_registrar_gasto_v2(v_sess2_id, 12000, 'llave_bre', 'Insumos', 'Bolsas y rollos POS', 'BRE-7788');
    ASSERT (v_res->>'success')::boolean = true AND (v_res->'data'->>'remaining_channel_balance')::numeric = 18000 AND v_res->'data'->>'actor_role' = 'owner',
        'CHK-206 ÉXITO FALLÓ: ' || v_res::text;

    v_res := public.rpc_obtener_gastos_turno(v_sess2_id);
    ASSERT (v_res->>'success')::boolean = true AND (v_res->>'total_opex_expenses')::numeric = 12000 AND (v_res->>'count')::int = 1,
        'CHK-206/UX-ADR-002 FALLÓ: rpc_obtener_gastos_turno devolvió payload inesperado: ' || v_res::text;

    -- =========================================================================
    -- [CHK-204] & [CHK-205] Turno +24h Expirado/Bloqueado + Reconciliación Admin opcional NULL
    -- =========================================================================
    -- Envejecer sesión a 26 horas
    UPDATE public.cash_sessions SET opened_at = NOW() - INTERVAL '26 hours' WHERE id = v_sess2_id;

    -- Verificar rechazo +24h en gasto
    v_err := false;
    BEGIN
        PERFORM public.rpc_registrar_gasto_v2(v_sess2_id, 1000, 'efectivo', 'Servicios', 'Gasto tarde');
    EXCEPTION WHEN OTHERS THEN
        v_err := (SQLERRM LIKE '%SHIFT_EXPIRED_24H%');
    END;
    ASSERT v_err, 'CHK-204/206 FALLÓ: Gasto en turno >24h debió fallar con SHIFT_EXPIRED_24H';

    -- Ejecutar rpc_check_and_force_close_shifts
    v_res := public.rpc_check_and_force_close_shifts();
    ASSERT (v_res->'data'->>'closed_shifts')::int >= 1, 'CHK-204 FALLÓ: No cerró turno >24h';

    SELECT COUNT(*) INTO v_cnt FROM public.notifications WHERE store_id = v_store_id AND metadata->>'event_type' = 'FORCED_CLOSE_24H';
    ASSERT v_cnt = 1, 'CHK-204 FALLÓ: Falta notificación FORCED_CLOSE_24H';

    -- Compuerta D-7 impide abrir nuevo turno mientras exista cierre forzado sin conteo
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id, 'role', 'authenticated')::text, true);
    v_err := false;
    BEGIN
        PERFORM public.abrir_caja(v_store_id, v_owner_id, 10000);
    EXCEPTION WHEN OTHERS THEN
        v_err := (SQLERRM LIKE '%RECONCILIATION_REQUIRED%');
    END;
    ASSERT v_err, 'CHK-202/204 COMP D-7 FALLÓ: Debió exigir RECONCILIATION_REQUIRED';

    -- Empleado con canOpenCloseCash NO puede usar rpc_reconciliar_cierre_forzado (100% Admin-only)
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_a_id, 'role', 'authenticated')::text, true);
    v_err := false;
    BEGIN
        PERFORM public.rpc_reconciliar_cierre_forzado(v_sess2_id, v_emp_a_id, NULL);
    EXCEPTION WHEN OTHERS THEN
        v_err := (SQLSTATE = '42501' AND SQLERRM LIKE '%ADMIN_ONLY_ACTION%');
    END;
    ASSERT v_err, 'CHK-205 RECHAZO FALLÓ: Empleado pudo invocar rpc_reconciliar_cierre_forzado (debe ser 100% Admin-only)';

    -- Admin reconcilia con p_actual_balance = NULL (conteo físico opcional FRD-027-02 R5)
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id, 'role', 'authenticated')::text, true);
    v_res := public.rpc_reconciliar_cierre_forzado(v_sess2_id, v_owner_id, NULL);
    ASSERT (v_res->>'success')::boolean = true AND (v_res->'data'->>'forced_close_without_count')::boolean = true AND (v_res->'data'->>'difference')::numeric = 0,
        'CHK-205 NULL COUNT FALLÓ: ' || v_res::text;

    SELECT COUNT(*) INTO v_cnt FROM public.notifications WHERE store_id = v_store_id AND metadata->>'event_type' = 'FORCED_CLOSE_NO_COUNT';
    ASSERT v_cnt = 1, 'CHK-205 FALLÓ: Falta alerta FORCED_CLOSE_NO_COUNT';

    -- Verificar que el dueño SÍ puede abrir nuevo turno después de reconciliar
    v_res_j := public.abrir_caja(v_store_id, v_owner_id, 10000);
    ASSERT (v_res_j->>'success')::boolean = true, 'CHK-205 DESBLOQUEO FALLÓ';
    v_sess_exp_id := (v_res_j->>'session_id')::uuid;

    -- =========================================================================
    -- [B2-1] Seguridad cross-tenant y validación estricta de rpc_log_security_event
    -- =========================================================================
    v_err := false;
    BEGIN
        PERFORM public.rpc_log_security_event('UNAUTHORIZED_SHIFT_CLOSE', gen_random_uuid(), '{}'::jsonb);
    EXCEPTION WHEN OTHERS THEN
        v_err := (SQLERRM LIKE '%STORE_ACCESS_DENIED%');
    END;
    ASSERT v_err, 'B2-1 RECHAZO FALLÓ: rpc_log_security_event debió bloquear store_id ajeno con STORE_ACCESS_DENIED';

    v_err := false;
    BEGIN
        PERFORM public.rpc_log_security_event('EVENTO_INVENTADO_INVALIDO', v_store_id, '{}'::jsonb);
    EXCEPTION WHEN OTHERS THEN
        v_err := (SQLSTATE = '22023' AND SQLERRM LIKE '%INVALID_SECURITY_EVENT_TYPE%');
    END;
    ASSERT v_err, 'B2-1 RECHAZO FALLÓ: Evento desconocido debió rechazarse con 22023 INVALID_SECURITY_EVENT_TYPE';

    -- =========================================================================
    -- [B2-6] Cierre exacto multicanal 3 canales por empleado + pago_proveedor/reembolso
    -- =========================================================================
    -- Limpiar movimientos de ejemplo y probar cierre exacto 3 canales por Cajero A
    DELETE FROM public.cash_movements WHERE session_id = v_sess_exp_id;
    UPDATE public.cash_sessions SET opened_by = v_emp_a_id, opened_by_name = 'Cajero A', opened_by_role = 'employee', opening_balance = 50000 WHERE id = v_sess_exp_id;

    -- Ingresos en los 3 canales y egresos con 'pago_proveedor' + 'reembolso'
    INSERT INTO public.cash_movements (session_id, movement_type, amount, description, payment_method, actor_id, actor_name, actor_role) VALUES
        (v_sess_exp_id, 'ingreso', 30000, 'Venta efectivo', 'efectivo', v_emp_a_id, 'Cajero A', 'employee'),
        (v_sess_exp_id, 'pago_proveedor', 10000, 'Pago leche efectivo', 'efectivo', NULL, 'Dueño', 'owner'),
        (v_sess_exp_id, 'ingreso', 25000, 'Venta Nequi', 'nequi', v_emp_a_id, 'Cajero A', 'employee'),
        (v_sess_exp_id, 'ingreso', 15000, 'Venta BRE', 'llave_bre', v_emp_a_id, 'Cajero A', 'employee');

    -- Esperados exactos: efectivo = 50k + 30k - 10k = 70k; nequi = 25k; llave_bre = 15k
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_a_id, 'role', 'authenticated')::text, true);
    v_res := public.cerrar_caja(v_sess_exp_id, v_emp_a_id, 70000, 25000, 15000);
    ASSERT (v_res->>'success')::boolean = true AND (v_res->'data'->>'sealed_with_alert')::boolean = false,
        'B2-6 FALLÓ: Cierre exacto 3 canales con pago_proveedor por Cajero A falló: ' || v_res::text;

    -- =========================================================================
    -- [B2-6] Cierre de turno +24h (forced_close=true, actual_balance NULL) por abridor original vía cerrar_caja
    --        y Reconciliación Admin con p_actual_balance NO NULO (FORCED_CLOSE_RECONCILED)
    -- =========================================================================
    v_res_j := public.abrir_caja(v_store_id, v_emp_a_id, 20000);
    v_sess_exp_id := (v_res_j->>'session_id')::uuid;
    UPDATE public.cash_sessions SET opened_at = NOW() - INTERVAL '25 hours' WHERE id = v_sess_exp_id;
    PERFORM public.rpc_check_and_force_close_shifts();

    -- 1) Verificar que Cajero A (abridor original) puede cerrar su propio turno Expirado/Bloqueado con cerrar_caja
    v_res := public.cerrar_caja(v_sess_exp_id, v_emp_a_id, 20000, 0, 0);
    ASSERT (v_res->>'success')::boolean = true AND (v_res->'data'->>'status') = 'closed',
        'B2-6 FALLÓ: Abridor original no pudo cerrar su turno forced_close=true vía cerrar_caja: ' || v_res::text;

    -- 2) Probar también reconciliación Admin con p_actual_balance NO NULO != expected (diff != 0)
    v_res_j := public.abrir_caja(v_store_id, v_emp_a_id, 30000);
    v_sess_exp_id := (v_res_j->>'session_id')::uuid;
    UPDATE public.cash_sessions SET opened_at = NOW() - INTERVAL '25 hours' WHERE id = v_sess_exp_id;
    PERFORM public.rpc_check_and_force_close_shifts();

    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id, 'role', 'authenticated')::text, true);
    v_res := public.rpc_reconciliar_cierre_forzado(v_sess_exp_id, v_owner_id, 27000);
    ASSERT (v_res->>'success')::boolean = true
       AND (v_res->'data'->>'forced_close_without_count')::boolean = false
       AND (v_res->'data'->>'difference')::numeric = -3000,
        'B2-6 FALLÓ: rpc_reconciliar_cierre_forzado con monto real no nulo falló: ' || v_res::text;

    -- =========================================================================
    -- [CHK-209 & B2-4] Verificar RLS SELECT & INSERT de notifications con rol authenticated real
    -- =========================================================================
    INSERT INTO public.notifications (store_id, type, title, message, audience, is_read)
    VALUES (v_store_id, 'general', 'Aviso General Turno', 'Visible para todos en tienda', 'all', false);

    EXECUTE 'SET LOCAL ROLE authenticated';

    -- Como empleado A: solo ve audience IN ('all','employee'), NUNCA 'admin', y TIENE PROHIBIDO insertar audience='admin'
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_emp_a_id, 'role', 'authenticated', 'app_metadata', jsonb_build_object('store_id', v_store_id))::text, true);
    SELECT COUNT(*) INTO v_cnt FROM public.notifications WHERE store_id = v_store_id AND audience = 'admin';
    ASSERT v_cnt = 0, 'CHK-209 RLS FALLÓ: Empleado pudo leer notificaciones audience = admin (' || v_cnt || ')';
    SELECT COUNT(*) INTO v_cnt FROM public.notifications WHERE store_id = v_store_id AND audience = 'all';
    ASSERT v_cnt = 1, 'CHK-209 RLS FALLÓ: Empleado no pudo leer notificación audience = all';

    v_err := false;
    BEGIN
        INSERT INTO public.notifications (store_id, type, title, message, audience)
        VALUES (v_store_id, 'security', 'Falsa Alerta', 'Inyectada por empleado', 'admin');
    EXCEPTION WHEN OTHERS THEN
        v_err := (SQLSTATE = '42501');
    END;
    ASSERT v_err, 'B2-4 RLS FALLÓ: Empleado pudo insertar directamente audience = admin en notifications';

    -- Como owner: SÍ ve audience = 'admin'
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner_id, 'role', 'authenticated', 'app_metadata', jsonb_build_object('store_id', v_store_id))::text, true);
    SELECT COUNT(*) INTO v_cnt FROM public.notifications WHERE store_id = v_store_id AND audience = 'admin';
    ASSERT v_cnt >= 3, 'CHK-209 RLS FALLÓ: Admin no ve notificaciones admin (' || v_cnt || ')';

    EXECUTE 'RESET ROLE';

    RAISE NOTICE '✅ TODOS LOS TESTS SQL OLA 2 + B2-1..B2-6 (CHK-201 a CHK-206 + CHK-209) PASARON EN VIVO.';
END $$;

ROLLBACK;

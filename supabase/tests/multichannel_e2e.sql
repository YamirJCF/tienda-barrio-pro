-- ==========================================
-- Test E2E de Multicanalidad (Dual-Write)
-- ==========================================
BEGIN;

-- 1. Preparar datos de prueba
DO $$
DECLARE
    v_store_id UUID;
    v_employee_id UUID;
    v_session_id UUID;
    v_sale_id UUID;
    v_client_id UUID;
    v_audit_count INT;
BEGIN
    -- Seleccionar tienda y empleado de prueba
    SELECT id INTO v_store_id FROM public.stores LIMIT 1;
    SELECT id INTO v_employee_id FROM public.employees WHERE store_id = v_store_id LIMIT 1;
    SELECT id INTO v_client_id FROM public.clients WHERE store_id = v_store_id LIMIT 1;

    IF v_store_id IS NULL OR v_employee_id IS NULL THEN
        RAISE EXCEPTION 'No se encontraron datos básicos para la prueba';
    END IF;

    -- ==========================================
    -- TEST 1: Fallback Testing (Cerrar caja legacy)
    -- ==========================================
    -- Simular una caja vieja sin datos en cash_session_balances
    INSERT INTO public.cash_sessions (store_id, opened_by, opening_balance, status, expected_balance, actual_balance, difference)
    VALUES (v_store_id, v_employee_id, 100000, 'open', NULL, NULL, NULL)
    RETURNING id INTO v_session_id;

    -- Cerrar la caja directamente para disparar el trigger legacy
    UPDATE public.cash_sessions 
    SET status = 'closed', expected_balance = 100000, actual_balance = 99000, difference = -1000, closed_at = NOW()
    WHERE id = v_session_id;

    -- Verificar que audit_caja se llenó con el formato legacy
    SELECT count(*) INTO v_audit_count FROM public.audit_caja WHERE session_id = v_session_id;
    IF v_audit_count = 0 THEN
        RAISE EXCEPTION 'TEST 1 FALLÓ: No se insertó registro en audit_caja para sesión legacy';
    END IF;

    RAISE NOTICE '✅ TEST 1 (Legacy Fallback) superado.';

    -- ==========================================
    -- TEST 2: Dual-Write E2E y Cierre Forzado 24h
    -- ==========================================
    -- Abrir una sesión que simularemos superó las 24 horas
    INSERT INTO public.cash_sessions (store_id, opened_by, opening_balance, status, opened_at)
    VALUES (v_store_id, v_employee_id, 50000, 'open', NOW() - INTERVAL '25 hours')
    RETURNING id INTO v_session_id;

    -- Insertar movimientos (simulando rpc_procesar_venta_v2)
    INSERT INTO public.cash_movements (session_id, payment_method, movement_type, amount, description)
    VALUES 
        (v_session_id, 'efectivo', 'ingreso', 20000, 'Venta en efectivo'),
        (v_session_id, 'nequi', 'ingreso', 30000, 'Venta en nequi'),
        (v_session_id, 'efectivo', 'gasto', 10000, 'Pago proveedor');

    -- Ejecutar el cierre forzado
    PERFORM public.rpc_check_and_force_close_shifts();

    -- Verificar que la sesión ahora está cerrada
    IF NOT EXISTS (SELECT 1 FROM public.cash_sessions WHERE id = v_session_id AND status = 'closed' AND forced_close = true) THEN
        RAISE EXCEPTION 'TEST 2 FALLÓ: La sesión no fue cerrada forzosamente';
    END IF;

    -- Verificar que se crearon los balances multicanal correctos
    -- Efectivo: Base(50000) + Ingreso(20000) - Gasto(10000) = 60000
    -- Nequi: Base(0) + Ingreso(30000) = 30000
    IF NOT EXISTS (SELECT 1 FROM public.cash_session_balances WHERE session_id = v_session_id AND payment_method = 'efectivo' AND expected_amount = 60000) THEN
        RAISE EXCEPTION 'TEST 2 FALLÓ: Balance efectivo incorrecto';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.cash_session_balances WHERE session_id = v_session_id AND payment_method = 'nequi' AND expected_amount = 30000) THEN
        RAISE EXCEPTION 'TEST 2 FALLÓ: Balance nequi incorrecto';
    END IF;

    -- Verificar el campo compatibility expected_balance = 90000 (60000 + 30000)
    IF NOT EXISTS (SELECT 1 FROM public.cash_sessions WHERE id = v_session_id AND expected_balance = 90000) THEN
        RAISE EXCEPTION 'TEST 2 FALLÓ: expected_balance legacy incorrecto';
    END IF;

    RAISE NOTICE '✅ TEST 2 (Cierre Forzado Dual-Write) superado.';

    -- Todo salió bien
    RAISE NOTICE '🎉 TODOS LOS TESTS PASARON EXITOSAMENTE.';
END $$;

ROLLBACK;

-- tests/schema_integrity_test.sql
-- Este script valida que las piezas clave de infraestructura 
-- y funciones de negocio existan en la BD.
-- Útil para ejecutar en CI/CD antes o después de aplicar migraciones.

DO $$
DECLARE
  v_missing_functions TEXT[];
  v_missing_tables TEXT[];
  v_fn TEXT;
  v_tbl TEXT;

  v_required_functions TEXT[] := ARRAY[
    'get_active_cash_session', 
    'actualizar_pin_empleado', 
    'toggle_empleado_activo', 
    'get_employee_public_info',
    'request_employee_access', 
    'check_my_pass_status',
    'check_daily_pass_status', 
    'rpc_force_sale',
    'rpc_procesar_venta_v2', 
    'rpc_anular_venta',
    'abrir_caja', 
    'cerrar_caja', 
    'crear_empleado',
    'get_current_store_id', 
    'get_employee_id_from_session',
    'handle_new_user_atomic', 
    'slugify', 
    'validar_pin_empleado'
  ];

  v_required_tables TEXT[] := ARRAY[
    'admin_profiles',
    'audit_logs',
    'cash_movements',
    'cash_sessions',
    'client_ledger',
    'client_transactions',
    'clients',
    'daily_passes',
    'employees',
    'inventory_movements',
    'products',
    'sale_items',
    'sales',
    'stores',
    'suppliers'
  ];

BEGIN
  -- 1. Verificar Tablas Restrictivas
  FOREACH v_tbl IN ARRAY v_required_tables LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.tables 
      WHERE table_schema='public' AND table_name=v_tbl
    ) THEN
      v_missing_tables := array_append(v_missing_tables, v_tbl);
    END IF;
  END LOOP;

  IF array_length(v_missing_tables, 1) > 0 THEN
    RAISE EXCEPTION '❌ SCHEMA_TEST: Faltan las tablas: %', v_missing_tables;
  END IF;

  -- 2. Verificar Funciones (RPCs y Helpers)
  FOREACH v_fn IN ARRAY v_required_functions LOOP
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.routines 
      WHERE routine_schema='public' AND routine_name=v_fn
    ) THEN
      v_missing_functions := array_append(v_missing_functions, v_fn);
    END IF;
  END LOOP;
  
  IF array_length(v_missing_functions, 1) > 0 THEN
    RAISE EXCEPTION '❌ SCHEMA_TEST: Faltan las funciones: %', v_missing_functions;
  END IF;
  
  -- 3. Verificar Política RLS sobre la nueva tabla audit_logs
  IF NOT EXISTS (
      SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' 
      AND c.relname = 'audit_logs' 
      AND c.relrowsecurity = true
  ) THEN
      RAISE EXCEPTION '❌ SCHEMA_TEST: RLS NO ACTIVO en public.audit_logs';
  END IF;

  -- 4. Verificar Trigger de Creación de Perfil en Auth
  IF NOT EXISTS (
      SELECT 1 FROM information_schema.triggers 
      WHERE event_object_schema = 'auth' AND event_object_table = 'users'
      AND trigger_name = 'on_auth_user_created'
  ) THEN
      RAISE EXCEPTION '❌ SCHEMA_TEST: Falta el Trigger on_auth_user_created en auth.users';
  END IF;

  RAISE NOTICE '✅ SCHEMA_TEST PASS: Todo el schema base está intacto.';
END $$;

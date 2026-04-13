-- ==============================================================================
-- MIGRATION: COMPLETE INIT CONSOLIDATION
-- Date: 2026-04-13
-- Description:
--   Restores all missing objects that were omitted during the init.sql 
--   consolidation (commit 11ef936). Source: supabase/migrations_old/
--
-- Missing Objects Restored:
--   A. Columns: products.brand, daily_passes.(store_id,auth_user_id,approved_at,approved_by,updated_at)
--   B. Tables: audit_logs
--   C. Helper Functions: get_employee_id_from_session, is_authorized_employee, slugify
--   D. RPCs: get_active_cash_session, actualizar_pin_empleado, toggle_empleado_activo,
--            get_employee_public_info, request_employee_access, check_my_pass_status,
--            check_daily_pass_status, rpc_force_sale
--   E. Updated RPCs: rpc_procesar_venta_v2 (multi-strategy auth)
--   F. Permissions: GRANT EXECUTE for all new functions
--
-- NOTE: RPCs that referenced 'alias' column have been adapted to use 'username'
--       since init.sql created employees with 'username' (not 'alias').
-- ==============================================================================

-- =============================================
-- SECTION A: MISSING COLUMNS
-- =============================================

-- A1. products.brand (source: 20260130180000_add_brand_column.sql)
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS brand text;
COMMENT ON COLUMN public.products.brand IS 'Marca del producto (opcional)';

-- A2. daily_passes.store_id (source: 20260202160000_implement_zero_auth_strategy.sql)
ALTER TABLE public.daily_passes 
ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores(id);

-- A3. daily_passes.auth_user_id (source: 20260202130000_enable_anon_auth.sql)
ALTER TABLE public.daily_passes 
ADD COLUMN IF NOT EXISTS auth_user_id UUID REFERENCES auth.users(id);

-- A4. daily_passes.approved_at (source: 20260202160000)
ALTER TABLE public.daily_passes 
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

-- A5. daily_passes.approved_by (source: 20260202160000)
ALTER TABLE public.daily_passes 
ADD COLUMN IF NOT EXISTS approved_by UUID;

-- A6. daily_passes.updated_at (source: 20260202192500)
ALTER TABLE public.daily_passes 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

-- A6b. Trigger for updated_at on daily_passes
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_daily_passes_updated_at ON public.daily_passes;
CREATE TRIGGER update_daily_passes_updated_at
    BEFORE UPDATE ON public.daily_passes
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- =============================================
-- SECTION B: MISSING TABLES
-- =============================================

-- B1. audit_logs (source: 20260207183000_force_sale_feature.sql)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL, 
    action TEXT NOT NULL,
    resource_id TEXT,
    details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_logs;
CREATE POLICY "Admins can view audit logs"
ON public.audit_logs FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.admin_profiles 
        WHERE id = auth.uid() 
        AND role IN ('admin', 'owner')
    )
);

DROP POLICY IF EXISTS "System can insert audit logs" ON public.audit_logs;
CREATE POLICY "System can insert audit logs"
ON public.audit_logs FOR INSERT
TO authenticated
WITH CHECK (true);

-- =============================================
-- SECTION C: MISSING HELPER FUNCTIONS
-- =============================================

-- C1. slugify (used by handle_new_user_atomic)
CREATE OR REPLACE FUNCTION public.slugify(text)
RETURNS text
LANGUAGE sql
IMMUTABLE STRICT
AS $$
  SELECT lower(
    regexp_replace(
      regexp_replace(
        translate($1, 'áéíóúñÁÉÍÓÚÑ', 'aeiounAEIOUN'),
        '[^a-zA-Z0-9\s-]', '', 'g'
      ),
      '[\s]+', '-', 'g'
    )
  );
$$;

-- C2. get_employee_id_from_session (source: 20260205160000)
CREATE OR REPLACE FUNCTION public.get_employee_id_from_session()
RETURNS UUID
LANGUAGE plpgsql
STABLE SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_employee_id UUID;
BEGIN
    -- Strategy 1: Permanent Employee
    SELECT id INTO v_employee_id 
    FROM public.employees 
    WHERE id = v_user_id AND is_active = true;
    
    IF v_employee_id IS NOT NULL THEN
        RETURN v_employee_id;
    END IF;
    
    -- Strategy 2: Daily Pass Employee (Zero-Auth)
    SELECT employee_id INTO v_employee_id
    FROM public.daily_passes
    WHERE auth_user_id = v_user_id
      AND status = 'approved'
      AND pass_date = CURRENT_DATE;
    
    RETURN v_employee_id;
END;
$$;

COMMENT ON FUNCTION public.get_employee_id_from_session() IS 
'Resolves employee_id from current session. Supports permanent employees and daily pass employees.';

-- C3. is_authorized_employee (source: 20260205160000)
CREATE OR REPLACE FUNCTION public.is_authorized_employee()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE SECURITY DEFINER
AS $$
DECLARE
    v_employee_id UUID;
BEGIN
    v_employee_id := public.get_employee_id_from_session();
    
    IF v_employee_id IS NOT NULL THEN
        RETURN TRUE;
    END IF;
    
    IF EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()) THEN
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$;

-- =============================================
-- SECTION D: MISSING RPCs
-- =============================================

-- D1. get_active_cash_session (source: 20260203000002_add_missing_cash_rpc.sql)
DROP FUNCTION IF EXISTS public.get_active_cash_session(uuid);

CREATE OR REPLACE FUNCTION public.get_active_cash_session(p_store_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session RECORD;
BEGIN
    SELECT * INTO v_session
    FROM public.cash_sessions
    WHERE store_id = p_store_id
      AND status = 'open'
    ORDER BY opened_at DESC
    LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'isOpen', true,
            'sessionId', v_session.id,
            'openingAmount', v_session.opening_balance,
            'openedBy', v_session.opened_by,
            'openedAt', v_session.opened_at
        );
    ELSE
        RETURN jsonb_build_object('isOpen', false);
    END IF;
END;
$$;

-- D2. actualizar_pin_empleado (source: 20260201170000_add_update_pin_rpc.sql)
CREATE OR REPLACE FUNCTION public.actualizar_pin_empleado(
  p_employee_id UUID,
  p_new_pin TEXT
)
RETURNS JSON AS $$
DECLARE
  v_store_id UUID;
BEGIN
  SELECT store_id INTO v_store_id
  FROM public.employees
  WHERE id = p_employee_id;

  IF NOT FOUND THEN
     RETURN json_build_object('success', false, 'error', 'Empleado no encontrado', 'code', 'EMPLOYEE_NOT_FOUND');
  END IF;

  IF v_store_id != public.get_current_store_id() THEN
     RETURN json_build_object('success', false, 'error', 'No autorizado para modificar empleados de otra tienda', 'code', 'UNAUTHORIZED');
  END IF;

  UPDATE public.employees
  SET 
    pin_hash = crypt(p_new_pin, gen_salt('bf')),
    updated_at = now()
  WHERE id = p_employee_id;

  RETURN json_build_object('success', true);

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM,
    'code', 'UPDATE_PIN_ERROR'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- D3. toggle_empleado_activo (source: 20260201173000_add_toggle_active_rpc.sql)
CREATE OR REPLACE FUNCTION public.toggle_empleado_activo(
  p_employee_id UUID,
  p_new_status BOOLEAN
)
RETURNS JSON AS $$
DECLARE
  v_store_id UUID;
  v_count INTEGER;
  v_current_status BOOLEAN;
BEGIN
  SELECT store_id, is_active INTO v_store_id, v_current_status
  FROM public.employees
  WHERE id = p_employee_id;

  IF NOT FOUND THEN
     RETURN json_build_object('success', false, 'error', 'Empleado no encontrado', 'code', 'EMPLOYEE_NOT_FOUND');
  END IF;

  IF v_store_id != public.get_current_store_id() THEN
     RETURN json_build_object('success', false, 'error', 'No autorizado', 'code', 'UNAUTHORIZED');
  END IF;

  IF p_new_status = true AND v_current_status = false THEN
      SELECT COUNT(*) INTO v_count
      FROM public.employees
      WHERE store_id = v_store_id AND is_active = true;

      IF v_count >= 5 THEN
         RETURN json_build_object(
           'success', false, 
           'error', 'Límite de empleados activos (5) alcanzado. Desactive otro usuario primero.', 
           'code', 'LIMIT_REACHED'
         );
      END IF;
  END IF;

  UPDATE public.employees
  SET 
    is_active = p_new_status,
    updated_at = now()
  WHERE id = p_employee_id;

  RETURN json_build_object('success', true, 'new_status', p_new_status);

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM,
    'code', 'TOGGLE_ERROR'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- D4. get_employee_public_info (source: 20260202175000, ADAPTED: alias → username)
CREATE OR REPLACE FUNCTION public.get_employee_public_info(p_username TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_employee RECORD;
BEGIN
    SELECT e.id, e.name, e.store_id, s.name as store_name
    INTO v_employee
    FROM public.employees e
    JOIN public.stores s ON e.store_id = s.id
    WHERE e.username = p_username 
      AND e.is_active = true;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Empleado no encontrado');
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'employee_id', v_employee.id,
        'name', v_employee.name,
        'store_id', v_employee.store_id,
        'store_name', v_employee.store_name
    );
END;
$$;

-- D5. request_employee_access (source: 20260203000000_auth_v2_stable.sql, ADAPTED: alias → username)
CREATE OR REPLACE FUNCTION public.request_employee_access(
    p_username TEXT,
    p_pin TEXT,
    p_device_fingerprint TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_employee RECORD;
    v_pass_id UUID;
    v_pin_valid BOOLEAN := false;
BEGIN
    -- A. Identify Employee (using username, not alias)
    SELECT e.*, au.email as owner_email 
    INTO v_employee
    FROM public.employees e
    JOIN public.stores s ON e.store_id = s.id
    LEFT JOIN auth.users au ON s.owner_id = au.id
    WHERE e.username = p_username;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'code', 'USER_NOT_FOUND', 'message', 'Usuario no existe');
    END IF;

    -- Validate PIN (hash mode)
    IF v_employee.pin_hash IS NOT NULL AND v_employee.pin_hash = crypt(p_pin, v_employee.pin_hash) THEN
         v_pin_valid := true;
    END IF;

    IF NOT v_pin_valid THEN
         RETURN jsonb_build_object('success', false, 'code', 'INVALID_CREDENTIALS', 'message', 'PIN Incorrecto');
    END IF;

    -- B. Daily Pass Management (UPSERT)
    INSERT INTO public.daily_passes (
        employee_id,
        store_id,
        device_fingerprint,
        status,
        pass_date,
        requested_at,
        resolved_at,
        resolved_by,
        auth_user_id
    ) VALUES (
        v_employee.id,
        v_employee.store_id,
        p_device_fingerprint,
        'approved',
        CURRENT_DATE,
        now(),
        now(),
        v_employee.id,
        auth.uid()
    )
    ON CONFLICT (employee_id, pass_date) 
    DO UPDATE SET 
        auth_user_id = EXCLUDED.auth_user_id,
        device_fingerprint = EXCLUDED.device_fingerprint,
        status = 'approved',
        updated_at = now()
    RETURNING id INTO v_pass_id;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'approved',
        'employee', jsonb_build_object(
            'id', v_employee.id,
            'name', v_employee.name,
            'role', 'employee',
            'store_id', v_employee.store_id,
            'permissions', v_employee.permissions
        )
    );
END;
$$;

-- D6. check_my_pass_status (source: 20260203000001_fix_polling_rpc.sql, ADAPTED: alias → username)
CREATE OR REPLACE FUNCTION public.check_my_pass_status(p_pass_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result RECORD;
BEGIN
    SELECT dp.status as pass_status, e.* 
    INTO v_result
    FROM public.daily_passes dp
    JOIN public.employees e ON dp.employee_id = e.id
    WHERE dp.id = p_pass_id;

    IF NOT FOUND THEN
         RETURN jsonb_build_object('status', 'not_found');
    END IF;

    IF v_result.pass_status = 'approved' THEN
        RETURN jsonb_build_object(
            'status', 'approved',
            'employee', jsonb_build_object(
                'id', v_result.id,
                'name', v_result.name,
                'role', 'employee',
                'store_id', v_result.store_id,
                'username', v_result.username, 
                'permissions', v_result.permissions
            )
        );
    ELSE
        RETURN jsonb_build_object('status', v_result.pass_status);
    END IF;
END;
$$;

-- D7. check_daily_pass_status (source: 20260201210000_fix_approval_reception.sql)
CREATE OR REPLACE FUNCTION public.check_daily_pass_status(
  p_employee_id UUID,
  p_device_fingerprint TEXT
)
RETURNS JSON 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pass public.daily_passes%ROWTYPE;
BEGIN
  SELECT * INTO v_pass 
  FROM public.daily_passes 
  WHERE employee_id = p_employee_id 
    AND requested_at > (now() - interval '24 hours')
  ORDER BY requested_at DESC 
  LIMIT 1;
  
  IF NOT FOUND THEN
    RETURN json_build_object('status', 'none');
  END IF;
  
  RETURN json_build_object(
    'status', v_pass.status,
    'pass_id', v_pass.id,
    'retry_count', v_pass.retry_count
  );
END;
$$;

-- D8. rpc_force_sale (source: 20260207183000_force_sale_feature.sql)
-- First update the movement_type constraint to include CORRECCION_SISTEMA
DO $$
DECLARE
    v_constraint_name TEXT;
BEGIN
    SELECT conname INTO v_constraint_name
    FROM pg_constraint
    WHERE conrelid = 'public.inventory_movements'::regclass
    AND pg_get_constraintdef(oid) LIKE '%movement_type%';

    IF v_constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE public.inventory_movements DROP CONSTRAINT %I', v_constraint_name);
    END IF;

    ALTER TABLE public.inventory_movements
    ADD CONSTRAINT inventory_movements_movement_type_check 
    CHECK (movement_type IN (
        'ingreso', 'gasto', 'venta', 'devolucion', 'ajuste_manual', 
        'entrada', 'salida', 'CORRECCION_SISTEMA'
    ));
END $$;

CREATE OR REPLACE FUNCTION public.rpc_force_sale(
    p_store_id UUID,
    p_client_id UUID,
    p_payment_method TEXT,
    p_items JSONB,
    p_justification TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role TEXT;
    v_item JSONB;
    v_product_id UUID;
    v_qty NUMERIC;
    v_current_stock NUMERIC;
    v_deficit NUMERIC;
    v_sale_result JSONB;
    v_sale_id UUID;
    v_affected_count INT := 0;
BEGIN
    -- 0. Validate Role (Strict)
    SELECT role INTO v_role FROM public.admin_profiles WHERE id = auth.uid();
    
    IF v_role IS NULL OR v_role NOT IN ('admin', 'owner') THEN
        RAISE EXCEPTION 'Access Denied: FRD-007 Enforced. User role % not allowed.', v_role;
    END IF;

    IF length(p_justification) < 10 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Justificación muy corta (min 10 caracteres).');
    END IF;

    -- 1. Inventory Correction
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_qty := (v_item->>'quantity')::NUMERIC;
        
        SELECT current_stock INTO v_current_stock 
        FROM public.products 
        WHERE id = v_product_id;

        v_deficit := v_qty - COALESCE(v_current_stock, 0);

        IF v_deficit > 0 THEN
            INSERT INTO public.inventory_movements (
                product_id, movement_type, quantity, reason, created_by
            ) VALUES (
                v_product_id, 'CORRECCION_SISTEMA', v_deficit,
                'AUTO-CORRECCION (EXCEPCION ADMIN): ' || p_justification,
                public.get_employee_id_from_session()
            );
            v_affected_count := v_affected_count + 1;
        END IF;
    END LOOP;

    -- 2. Process Sale (Call V2)
    SELECT public.rpc_procesar_venta_v2(
        p_store_id, p_client_id, p_payment_method, 0, p_items
    ) INTO v_sale_result;

    IF (v_sale_result->>'success')::boolean IS NOT TRUE THEN
        RAISE EXCEPTION 'Venta falló tras ajuste: %', v_sale_result->>'error';
    END IF;

    v_sale_id := (v_sale_result->>'sale_id')::UUID;

    -- 3. Audit Log
    INSERT INTO public.audit_logs (user_id, action, resource_id, details)
    VALUES (
        auth.uid(), 'FORCE_SALE', v_sale_id::TEXT,
        jsonb_build_object(
            'reason', p_justification,
            'items_adjusted', v_affected_count,
            'original_items', p_items
        )
    );

    RETURN jsonb_build_object('success', true, 'sale_id', v_sale_id, 'adjusted_items', v_affected_count);
END;
$$;

-- =============================================
-- SECTION E: UPDATE rpc_procesar_venta_v2 (Multi-Strategy Auth)
-- Source: 20260205160000_fix_employee_auth_financial_core.sql
-- =============================================

CREATE OR REPLACE FUNCTION public.rpc_procesar_venta_v2(
    p_store_id UUID,
    p_client_id UUID,
    p_payment_method TEXT,
    p_amount_received DECIMAL,
    p_items JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_sale_id UUID;
    v_ticket_number INTEGER;
    v_total_calculated DECIMAL(12, 0) := 0;
    v_change DECIMAL(12, 0) := 0;
    v_item JSONB;
    v_product_id UUID;
    v_quantity DECIMAL;
    v_product_price DECIMAL;
    v_product_name TEXT;
    v_subtotal DECIMAL;
    v_client_balance DECIMAL;
    v_client_limit DECIMAL;
    v_employee_id UUID;
BEGIN
    -- 1. Multi-Strategy Authorization
    v_employee_id := public.get_employee_id_from_session();
    
    IF v_employee_id IS NULL THEN
        IF EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()) THEN
            v_employee_id := auth.uid();
        ELSE
            RETURN jsonb_build_object(
                'success', false, 
                'error', 'Usuario no autorizado', 
                'code', 'UNAUTHORIZED'
            );
        END IF;
    END IF;

    -- 2. Calculate Total
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_quantity := (v_item->>'quantity')::DECIMAL;
        
        SELECT price, name INTO v_product_price, v_product_name
        FROM public.products 
        WHERE id = v_product_id AND store_id = p_store_id;
        
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'Producto no encontrado: ' || v_product_id);
        END IF;
        
        v_total_calculated := v_total_calculated + (v_product_price * v_quantity);
    END LOOP;

    -- 3. Validate FIADO
    IF p_payment_method = 'fiado' THEN
        IF p_client_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Se requiere cliente para fiado');
        END IF;
        
        SELECT balance, credit_limit INTO v_client_balance, v_client_limit 
        FROM public.clients 
        WHERE id = p_client_id FOR UPDATE;
        
        IF NOT FOUND THEN
             RETURN jsonb_build_object('success', false, 'error', 'Cliente no encontrado');
        END IF;

        IF (v_client_balance + v_total_calculated) > v_client_limit THEN
            RETURN jsonb_build_object(
                'success', false, 
                'error', 'Cupo excedido. Cupo: ' || v_client_limit || '. Saldo Nuevo: ' || (v_client_balance + v_total_calculated),
                'code', 'CREDIT_LIMIT_EXCEEDED'
            );
        END IF;
    END IF;

    -- 4. Generate Ticket
    SELECT COALESCE(MAX(ticket_number), 0) + 1 INTO v_ticket_number 
    FROM public.sales WHERE store_id = p_store_id;

    -- 5. Insert Sale
    v_change := CASE WHEN p_payment_method = 'efectivo' THEN GREATEST(0, p_amount_received - v_total_calculated) ELSE 0 END;

    INSERT INTO public.sales (
        store_id, ticket_number, employee_id, client_id, 
        total, payment_method, amount_received, change_given, 
        sync_status
    ) VALUES (
        p_store_id, v_ticket_number, v_employee_id, p_client_id,
        v_total_calculated, p_payment_method, p_amount_received, v_change,
        'synced'
    ) RETURNING id INTO v_sale_id;

    -- 6. Process Items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_quantity := (v_item->>'quantity')::DECIMAL;
        
        SELECT price INTO v_product_price FROM public.products WHERE id = v_product_id;
        v_subtotal := v_quantity * v_product_price;
        
        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, subtotal)
        VALUES (v_sale_id, v_product_id, v_quantity, v_product_price, v_subtotal);
        
        INSERT INTO public.inventory_movements (
            product_id, movement_type, quantity, reason, created_by
        ) VALUES (
            v_product_id, 'venta', v_quantity, 'Venta #' || v_ticket_number, v_employee_id
        );
    END LOOP;

    -- 7. Cash Movement (if cash payment)
    IF p_payment_method = 'efectivo' OR p_payment_method = 'cash' THEN
        DECLARE
            v_session_id UUID;
        BEGIN
            SELECT id INTO v_session_id 
            FROM public.cash_sessions 
            WHERE store_id = p_store_id AND status = 'open' 
            ORDER BY opened_at DESC LIMIT 1;
            
            IF v_session_id IS NOT NULL THEN
                INSERT INTO public.cash_movements (
                    session_id, movement_type, amount, description, sale_id
                ) VALUES (
                    v_session_id, 'entrada', v_total_calculated, 'Venta #' || v_ticket_number, v_sale_id
                );
            END IF;
        END;
    END IF;

    -- 8. Update Client Balance (fiado)
    IF p_payment_method = 'fiado' THEN
        UPDATE public.clients 
        SET balance = balance + v_total_calculated 
        WHERE id = p_client_id;
        
        INSERT INTO public.client_ledger (
            client_id, store_id, amount, previous_balance, reference_id, 
            transaction_type, created_by
        ) VALUES (
            p_client_id, p_store_id, v_total_calculated, v_client_balance, 
            v_sale_id, 'venta_fiado', v_employee_id
        );
    END IF;

    -- 9. Success Response
    RETURN jsonb_build_object(
        'success', true,
        'sale_id', v_sale_id,
        'ticket_number', v_ticket_number,
        'total', v_total_calculated,
        'change', v_change
    );
END;
$$;

-- =============================================
-- SECTION F: PERMISSIONS (GRANT EXECUTE)
-- =============================================

-- Helper Functions
GRANT EXECUTE ON FUNCTION public.get_employee_id_from_session() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_employee_id_from_session() TO anon;
GRANT EXECUTE ON FUNCTION public.get_employee_id_from_session() TO service_role;

GRANT EXECUTE ON FUNCTION public.is_authorized_employee() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_authorized_employee() TO anon;
GRANT EXECUTE ON FUNCTION public.is_authorized_employee() TO service_role;

GRANT EXECUTE ON FUNCTION public.slugify(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.slugify(text) TO anon;
GRANT EXECUTE ON FUNCTION public.slugify(text) TO service_role;

-- RPCs
GRANT EXECUTE ON FUNCTION public.get_active_cash_session(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_cash_session(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.get_active_cash_session(uuid) TO service_role;

GRANT EXECUTE ON FUNCTION public.actualizar_pin_empleado(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.actualizar_pin_empleado(uuid, text) TO service_role;

GRANT EXECUTE ON FUNCTION public.toggle_empleado_activo(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_empleado_activo(uuid, boolean) TO service_role;

GRANT EXECUTE ON FUNCTION public.get_employee_public_info(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_employee_public_info(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_employee_public_info(text) TO service_role;

GRANT EXECUTE ON FUNCTION public.request_employee_access(text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.request_employee_access(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_employee_access(text, text, text) TO service_role;

GRANT EXECUTE ON FUNCTION public.check_my_pass_status(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.check_my_pass_status(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_my_pass_status(uuid) TO service_role;

GRANT EXECUTE ON FUNCTION public.check_daily_pass_status(uuid, text) TO anon;
GRANT EXECUTE ON FUNCTION public.check_daily_pass_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_daily_pass_status(uuid, text) TO service_role;

GRANT EXECUTE ON FUNCTION public.rpc_force_sale(uuid, uuid, text, jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rpc_force_sale(uuid, uuid, text, jsonb, text) TO service_role;

-- =============================================
-- SECTION G: ENSURE pgcrypto EXTENSION
-- =============================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

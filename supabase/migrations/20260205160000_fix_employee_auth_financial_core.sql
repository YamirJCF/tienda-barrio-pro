-- ==============================================================================
-- MIGRATION: FIX EMPLOYEE AUTH IN FINANCIAL CORE
-- Date: 2026-02-05
-- Issue: Employees with daily_passes cannot process sales (Usuario no autorizado)
-- Root Cause: rpc_procesar_venta_v2 only validates employees + admin_profiles,
--             ignores daily_passes auth strategy (Zero-Auth)
-- ==============================================================================

-- ==============================================================================
-- 1. HELPER FUNCTION: Get Employee ID from Current Session
-- ==============================================================================
-- Purpose: Centralize logic to resolve employee_id from auth.uid()
-- Supports 3 auth strategies:
--   A. Permanent employee (auth.uid() = employees.id)
--   B. Daily pass employee (auth.uid() = daily_passes.auth_user_id)
--   C. Admin (returns NULL, requires separate validation)
-- ==============================================================================

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
    -- Direct match: auth.uid() is in employees table
    SELECT id INTO v_employee_id 
    FROM public.employees 
    WHERE id = v_user_id AND is_active = true;
    
    IF v_employee_id IS NOT NULL THEN
        RETURN v_employee_id;
    END IF;
    
    -- Strategy 2: Daily Pass Employee (Zero-Auth)
    -- auth.uid() is anonymous user, linked via daily_passes
    SELECT employee_id INTO v_employee_id
    FROM public.daily_passes
    WHERE auth_user_id = v_user_id
      AND status = 'approved'
      AND pass_date = CURRENT_DATE;
    
    RETURN v_employee_id; -- NULL if not found (could be admin or unauthorized)
END;
$$;

COMMENT ON FUNCTION public.get_employee_id_from_session() IS 
'Resolves employee_id from current session. Supports permanent employees and daily pass employees. Returns NULL if user is admin or unauthorized.';

-- ==============================================================================
-- 2. HELPER FUNCTION: Check if User is Authorized Employee
-- ==============================================================================
-- Purpose: Centralized authorization check for RPC functions
-- Returns TRUE if user is:
--   - Active permanent employee
--   - Approved daily pass employee
--   - Admin
-- Returns FALSE otherwise
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.is_authorized_employee()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE SECURITY DEFINER
AS $$
DECLARE
    v_employee_id UUID;
BEGIN
    -- Check if we can resolve an employee_id
    v_employee_id := public.get_employee_id_from_session();
    
    IF v_employee_id IS NOT NULL THEN
        RETURN TRUE; -- User is employee (permanent or daily pass)
    END IF;
    
    -- Check if user is admin
    IF EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()) THEN
        RETURN TRUE;
    END IF;
    
    RETURN FALSE; -- Unauthorized
END;
$$;

COMMENT ON FUNCTION public.is_authorized_employee() IS 
'Returns TRUE if current user is authorized to perform employee operations (employee or admin).';

-- ==============================================================================
-- 3. UPDATE RPC: Fix Authorization Check in rpc_procesar_venta_v2
-- ==============================================================================

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
    -- =========================================================================
    -- 1. FIXED: Multi-Strategy Authorization Check
    -- =========================================================================
    -- Get employee_id using centralized helper (supports all auth strategies)
    v_employee_id := public.get_employee_id_from_session();
    
    -- If no employee found, check if user is admin
    IF v_employee_id IS NULL THEN
        IF EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()) THEN
            -- Admin can sell without employee link (use auth.uid() as fallback)
            v_employee_id := auth.uid();
        ELSE
            -- Not employee, not admin → Unauthorized
            RETURN jsonb_build_object(
                'success', false, 
                'error', 'Usuario no autorizado', 
                'code', 'UNAUTHORIZED'
            );
        END IF;
    END IF;

    -- 2. Calcular Total Real (Iterar items simulados)
    -- Nota: Hacemos un loop prevuelo para calcular total y validar stock antes de insertar nada
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_quantity := (v_item->>'quantity')::DECIMAL;
        
        -- Buscar Precio Oficial
        SELECT price, name INTO v_product_price, v_product_name
        FROM public.products 
        WHERE id = v_product_id AND store_id = p_store_id;
        
        IF NOT FOUND THEN
            RETURN jsonb_build_object('success', false, 'error', 'Producto no encontrado: ' || v_product_id);
        END IF;
        
        v_total_calculated := v_total_calculated + (v_product_price * v_quantity);
    END LOOP;

    -- 3. Validar FIADO
    IF p_payment_method = 'fiado' THEN
        IF p_client_id IS NULL THEN
            RETURN jsonb_build_object('success', false, 'error', 'Se requiere cliente para fiado');
        END IF;
        
        -- Locking Client Row
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

    -- 4. Generar Ticket
    SELECT COALESCE(MAX(ticket_number), 0) + 1 INTO v_ticket_number 
    FROM public.sales WHERE store_id = p_store_id;

    -- 5. Insertar Venta
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

    -- 6. Procesar Items (Stock Check implícito en Trigger update_product_stock)
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_quantity := (v_item->>'quantity')::DECIMAL;
        
        SELECT price INTO v_product_price FROM public.products WHERE id = v_product_id;
        v_subtotal := v_quantity * v_product_price;
        
        -- Insertar Item
        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, subtotal)
        VALUES (v_sale_id, v_product_id, v_quantity, v_product_price, v_subtotal);
        
        -- Reducir Inventario (via trigger o manual insert)
        INSERT INTO public.inventory_movements (
            product_id, movement_type, quantity, reason, created_by
        ) VALUES (
            v_product_id, 'venta', v_quantity, 'Venta #' || v_ticket_number, v_employee_id
        );
    END LOOP;

    -- 7. Registrar Movimiento de Caja (si aplica)
    IF p_payment_method = 'efectivo' OR p_payment_method = 'cash' THEN
        -- Encontrar sesión activa
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

    -- 8. Actualizar Saldo Cliente (si es fiado)
    IF p_payment_method = 'fiado' THEN
        UPDATE public.clients 
        SET balance = balance + v_total_calculated 
        WHERE id = p_client_id;
        
        -- Registrar en Ledger
        INSERT INTO public.client_ledger (
            client_id, store_id, amount, previous_balance, reference_id, 
            transaction_type, created_by
        ) VALUES (
            p_client_id, p_store_id, v_total_calculated, v_client_balance, 
            v_sale_id, 'venta_fiado', v_employee_id
        );
    END IF;

    -- 9. Respuesta Exitosa
    RETURN jsonb_build_object(
        'success', true,
        'sale_id', v_sale_id,
        'ticket_number', v_ticket_number,
        'total', v_total_calculated,
        'change', v_change
    );
END;
$$;

COMMENT ON FUNCTION public.rpc_procesar_venta_v2 IS 
'Process sale with atomic transaction. FIXED: Now supports all auth strategies (permanent employees, daily passes, admins).';

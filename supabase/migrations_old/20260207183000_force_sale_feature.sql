-- ==============================================================================
-- MIGRATION: Force Sale Feature (FRD-014)
-- Description: Implements Audit Logs, Safe Constraint Update, and Force Sale RPC.
-- Date: 2026-02-07
-- Dependencies: Financial Core (20260204180000_financial_core.sql)
-- ==============================================================================

-- 1. MITIGATION QA R-01: Update Check Constraint for movement_type safely
DO $$
DECLARE
    v_constraint_name TEXT;
BEGIN
    -- Search for existing constraint on movement_type
    SELECT conname INTO v_constraint_name
    FROM pg_constraint
    WHERE conrelid = 'public.inventory_movements'::regclass
    AND pg_get_constraintdef(oid) LIKE '%movement_type%';

    -- Drop it if exists
    IF v_constraint_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE public.inventory_movements DROP CONSTRAINT %I', v_constraint_name);
    END IF;

    -- Add Updated Constraint including 'CORRECCION_SISTEMA'
    ALTER TABLE public.inventory_movements
    ADD CONSTRAINT inventory_movements_movement_type_check 
    CHECK (movement_type IN (
        'ingreso', 
        'gasto', 
        'venta', 
        'devolucion', 
        'ajuste_manual', 
        'entrada', -- Found in DB
        'salida',
        'CORRECCION_SISTEMA' -- New Authorized Type
    ));
END $$;

-- 2. Create Audit Logs Table
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL, 
    action TEXT NOT NULL,
    resource_id TEXT,
    details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

-- 3. RLS for Audit Logs
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
WITH CHECK (true); -- Inserted via Security Definer

-- 4. RPC: Force Sale (Atomic Transaction)
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
SET search_path = public -- Security Hardening QA R-02
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

    -- Validate Justification Length
    IF length(p_justification) < 10 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Justificación muy corta (min 10 caracteres).');
    END IF;

    -- 1. Inventory Correction (Pre-flight)
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_qty := (v_item->>'quantity')::NUMERIC;
        
        -- Get current stock
        SELECT current_stock INTO v_current_stock 
        FROM public.products 
        WHERE id = v_product_id;

        -- Calculate deficit
        v_deficit := v_qty - COALESCE(v_current_stock, 0);

        -- Inject corrective stock if needed
        IF v_deficit > 0 THEN
            INSERT INTO public.inventory_movements (
                product_id,
                movement_type,
                quantity,
                reason,
                created_by
            ) VALUES (
                v_product_id,
                'CORRECCION_SISTEMA',
                v_deficit,
                'AUTO-CORRECCION (EXCEPCION ADMIN): ' || p_justification,
                PUBLIC.get_employee_id_from_session() -- Helper usage
            );
            v_affected_count := v_affected_count + 1;
        END IF;
    END LOOP;

    -- 2. Process Sale (Call V2)
    -- We pass 0 as amount_received because backend calculates change as 0 if effectively exact logic is used,
    -- or we assume admin handles money correctly. 
    -- Alternatively, frontend should send amount_received if available, 
    -- but RPC signature requires it. We default to V_TOTAL inside V2 if needed?
    -- V2 uses GREATEST(0, p_amount_received - total). 
    -- If we pass 0, change is 0. This is safe for 'force' context where speed matters.
    SELECT public.rpc_procesar_venta_v2(
        p_store_id,
        p_client_id,
        p_payment_method,
        0, 
        p_items
    ) INTO v_sale_result;

    -- Validate Sale Result
    IF (v_sale_result->>'success')::boolean IS NOT TRUE THEN
        RAISE EXCEPTION 'Venta falló tras ajuste: %', v_sale_result->>'error';
    END IF;

    v_sale_id := (v_sale_result->>'sale_id')::UUID;

    -- 3. Audit Log
    INSERT INTO public.audit_logs (
        user_id,
        action,
        resource_id,
        details
    ) VALUES (
        auth.uid(),
        'FORCE_SALE',
        v_sale_id::TEXT,
        jsonb_build_object(
            'reason', p_justification,
            'items_adjusted', v_affected_count,
            'original_items', p_items
        )
    );

    RETURN jsonb_build_object('success', true, 'sale_id', v_sale_id, 'adjusted_items', v_affected_count);
END;
$$;

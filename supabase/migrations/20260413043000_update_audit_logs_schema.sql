-- ==============================================================================
-- MIGRATION: ALIGN AUDIT LOGS STRUCTURE
-- Actualiza la estructura de audit_logs para coincidir con la aplicación Vue V2
-- ==============================================================================

TRUNCATE TABLE public.audit_logs;

-- Eliminamos la referencia antigua a auth.users si existe
ALTER TABLE public.audit_logs DROP CONSTRAINT IF EXISTS audit_logs_user_id_fkey;

-- Aplicamos los nombres de columna actualizados que espera AuditRepository.ts
ALTER TABLE public.audit_logs RENAME COLUMN user_id TO actor_id;
ALTER TABLE public.audit_logs RENAME COLUMN action TO event_type;
ALTER TABLE public.audit_logs RENAME COLUMN details TO metadata;

-- Añadimos las columnas faltantes necesarias para el V2 Frontend
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES public.stores(id) ON DELETE CASCADE;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS severity TEXT DEFAULT 'info';
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS ip_address TEXT;

-- Restauramos la relación actor_id hacia attributes de los employees para permitir los JOINs de Supabase UI
ALTER TABLE public.audit_logs ADD CONSTRAINT audit_logs_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.employees(id) ON DELETE SET NULL;


-- Actualizamos rpc_force_sale para que grabe sobre la nueva estructura de audit_logs
CREATE OR REPLACE FUNCTION public.rpc_force_sale(
    p_store_id uuid,
    p_client_id uuid,
    p_payment_method text,
    p_items jsonb,
    p_justification text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $function$
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
    SELECT role INTO v_role FROM public.admin_profiles WHERE id = auth.uid();
    IF v_role IS NULL OR v_role NOT IN ('admin', 'owner') THEN
        RAISE EXCEPTION 'Access Denied: FRD-007 Enforced.';
    END IF;

    IF length(p_justification) < 10 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Justificación muy corta (min 10 caracteres).');
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_qty := (v_item->>'quantity')::NUMERIC;
        SELECT current_stock INTO v_current_stock FROM public.products WHERE id = v_product_id;
        v_deficit := v_qty - COALESCE(v_current_stock, 0);
        
        IF v_deficit > 0 THEN
            INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by)
            VALUES (v_product_id, 'CORRECCION_SISTEMA', v_deficit, 'AUTO-CORRECCION: ' || p_justification, public.get_employee_id_from_session());
            v_affected_count := v_affected_count + 1;
        END IF;
    END LOOP;

    SELECT public.rpc_procesar_venta_v2(p_store_id, p_client_id, p_payment_method, 0, p_items) INTO v_sale_result;
    
    IF (v_sale_result->>'success')::boolean IS NOT TRUE THEN
        RAISE EXCEPTION 'Venta falló tras ajuste: %', v_sale_result->>'error';
    END IF;

    v_sale_id := (v_sale_result->>'sale_id')::UUID;

    -- FIX: Grabado compatible con la nueva estructura V2
    INSERT INTO public.audit_logs (store_id, actor_id, event_type, resource_id, metadata, severity)
    VALUES (
        p_store_id,
        auth.uid(),
        'FORCE_SALE',
        v_sale_id::TEXT,
        jsonb_build_object('reason', p_justification, 'items_adjusted', v_affected_count, 'original_items', p_items),
        'warning'
    );

    RETURN jsonb_build_object('success', true, 'sale_id', v_sale_id, 'adjusted_items', v_affected_count);
END;
$function$;

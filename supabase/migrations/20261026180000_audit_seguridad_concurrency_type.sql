-- ==============================================================================
-- Migración: 20261026180000_audit_seguridad_concurrency_type.sql
-- Propósito: Expandir audit_seguridad_event_type_check y rpc_log_security_event
--            para admitir el evento de seguridad 'CONCURRENT_MUTATION_BLOCKED'
-- Documento: SDD-028 v2.0.0 / SDD-005 (§7.3)
-- ==============================================================================

BEGIN;

-- 1. Modificar el check constraint de audit_seguridad
ALTER TABLE public.audit_seguridad
    DROP CONSTRAINT IF EXISTS audit_seguridad_event_type_check;

ALTER TABLE public.audit_seguridad
    ADD CONSTRAINT audit_seguridad_event_type_check
    CHECK (event_type IN (
        'LOGIN_SUCCESS', 'LOGIN_FAILED', 'PIN_CHANGE',
        'UNAUTHORIZED_ACCESS', 'FORCE_SALE', 'SESSION_EXPIRED',
        'ROLE_CHANGE', 'EMPLOYEE_DEACTIVATED',
        'DEVICE_ACCESS_APPROVE', 'DEVICE_ACCESS_REJECT', 'DEVICE_ACCESS_REVOKE',
        'CONCURRENT_MUTATION_BLOCKED'
    ));

-- 2. Actualizar rpc_log_security_event para permitir el nuevo evento
CREATE OR REPLACE FUNCTION public.rpc_log_security_event(
    p_event_type TEXT,
    p_store_id UUID DEFAULT NULL,
    p_metadata JSONB DEFAULT '{}'::jsonb
) RETURNS void 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_employee_id UUID;
    v_ip TEXT;
    v_user_agent TEXT;
BEGIN
    -- Validar tipo de evento permitido
    IF p_event_type NOT IN (
        'LOGIN_SUCCESS', 'LOGIN_FAILED', 'PIN_CHANGE',
        'UNAUTHORIZED_ACCESS', 'FORCE_SALE', 'SESSION_EXPIRED',
        'ROLE_CHANGE', 'EMPLOYEE_DEACTIVATED',
        'DEVICE_ACCESS_APPROVE', 'DEVICE_ACCESS_REJECT', 'DEVICE_ACCESS_REVOKE',
        'CONCURRENT_MUTATION_BLOCKED'
    ) THEN
        RAISE EXCEPTION 'Tipo de evento de seguridad no válido: %', p_event_type;
    END IF;

    -- Resolver employee_id del usuario autenticado si es empleado
    SELECT id INTO v_employee_id
    FROM public.employees
    WHERE id = auth.uid()
    LIMIT 1;

    -- Capturar datos de red desde headers
    BEGIN
        v_ip := current_setting('request.headers', true)::json->>'x-forwarded-for';
        v_user_agent := current_setting('request.headers', true)::json->>'user-agent';
    EXCEPTION WHEN OTHERS THEN
        v_ip := NULL;
        v_user_agent := NULL;
    END;

    -- Inserción con autoridad de backend (SECURITY DEFINER salta RLS)
    INSERT INTO public.audit_seguridad (
        actor_id, store_id, event_type, ip_address, user_agent, metadata
    ) VALUES (
        v_employee_id,
        p_store_id,
        p_event_type,
        v_ip,
        v_user_agent,
        p_metadata
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_log_security_event(TEXT, UUID, JSONB) TO authenticated;

COMMIT;

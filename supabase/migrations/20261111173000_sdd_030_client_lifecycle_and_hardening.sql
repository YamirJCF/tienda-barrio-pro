-- ============================================================================
-- Migración: SDD-030 — Derechos del Titular, Archivo Contable y Hardening de Cartera
-- FRD Asociado: FRD-030 (POL-PRIV-02, POL-PRIV-01, POL-AUD-01, POL-AUD-02, POL-SEG-03)
-- SDD Asociado: SDD-030 v1.0.0 (D-ARCO-01..D-ARCO-06, Gap B2-01..04, G-7, CONFLICTO-01..06)
-- Fecha: 2026-11-11
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Nueva Bitácora Inmutable de Cartera (Gap B2-01, RN-08)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.client_lifecycle_audit (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    client_id uuid NOT NULL,
    event_type text NOT NULL CHECK (event_type IN ('ARCHIVED_ACCOUNTING', 'HARD_DELETED', 'REACTIVATED')),
    actor_id uuid NOT NULL,
    actor_name text NOT NULL CHECK (length(trim(actor_name)) > 0),
    actor_role text NOT NULL CHECK (actor_role IN ('owner', 'manager', 'employee')),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_client_lifecycle_audit_store_date
    ON public.client_lifecycle_audit (store_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_client_lifecycle_audit_store_client
    ON public.client_lifecycle_audit (store_id, client_id, created_at DESC);

-- Triggers Append-Only (BEFORE UPDATE / DELETE / TRUNCATE)
DROP TRIGGER IF EXISTS trg_client_lifecycle_audit_immutable ON public.client_lifecycle_audit;
CREATE TRIGGER trg_client_lifecycle_audit_immutable
    BEFORE UPDATE OR DELETE ON public.client_lifecycle_audit
    FOR EACH ROW EXECUTE FUNCTION public.fn_block_append_only_table_mutation();

DROP TRIGGER IF EXISTS trg_client_lifecycle_audit_no_truncate ON public.client_lifecycle_audit;
CREATE TRIGGER trg_client_lifecycle_audit_no_truncate
    BEFORE TRUNCATE ON public.client_lifecycle_audit
    FOR EACH STATEMENT EXECUTE FUNCTION public.fn_block_append_only_table_mutation();

-- RLS y privilegios mínimos (Reglas 4 y 8 AGENTS.md)
ALTER TABLE public.client_lifecycle_audit ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.client_lifecycle_audit FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.client_lifecycle_audit TO authenticated;
GRANT ALL ON TABLE public.client_lifecycle_audit TO service_role;

DROP POLICY IF EXISTS "client_lifecycle_audit_select_admin" ON public.client_lifecycle_audit;
CREATE POLICY "client_lifecycle_audit_select_admin"
    ON public.client_lifecycle_audit
    FOR SELECT
    TO authenticated
    USING (
        store_id = public.get_current_store_id()
        AND EXISTS (
            SELECT 1
            FROM public.admin_profiles ap
            WHERE ap.id = auth.uid()
              AND ap.store_id = client_lifecycle_audit.store_id
              AND ap.role IN ('owner', 'manager')
        )
    );

-- ----------------------------------------------------------------------------
-- 2. Endurecimiento de Esquema Existente, Privilegios anon y Cierre RLS (G-7 / B2-04)
-- ----------------------------------------------------------------------------

-- 2.1 Eliminar nulabilidad ambigua en clients.is_deleted y clients.balance
UPDATE public.clients SET is_deleted = false WHERE is_deleted IS NULL;
ALTER TABLE public.clients ALTER COLUMN is_deleted SET DEFAULT false;
ALTER TABLE public.clients ALTER COLUMN is_deleted SET NOT NULL;

UPDATE public.clients SET balance = 0 WHERE balance IS NULL;
ALTER TABLE public.clients ALTER COLUMN balance SET DEFAULT 0;
ALTER TABLE public.clients ALTER COLUMN balance SET NOT NULL;

-- 2.2 Revocación de privilegios anónimos y principio de mínimo privilegio (G-7)
REVOKE ALL ON TABLE public.clients FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.clients TO authenticated;
GRANT ALL ON TABLE public.clients TO service_role;

REVOKE ALL ON TABLE public.admin_profiles FROM PUBLIC, anon, authenticated;
GRANT SELECT, UPDATE ON TABLE public.admin_profiles TO authenticated;
GRANT ALL ON TABLE public.admin_profiles TO service_role;

REVOKE ALL ON TABLE public.client_ledger FROM anon;
REVOKE ALL ON TABLE public.sales FROM anon;
REVOKE ALL ON TABLE public.client_transactions FROM anon;

-- 2.3 Cierre de escritura directa PostgREST sobre clients y acotación de lectura
DROP POLICY IF EXISTS "clients_insert_store" ON public.clients;
DROP POLICY IF EXISTS "clients_update_store" ON public.clients;
DROP POLICY IF EXISTS "clients_select_store" ON public.clients;

CREATE POLICY "clients_select_store"
    ON public.clients
    FOR SELECT
    TO authenticated
    USING (
        store_id = public.get_current_store_id()
        AND COALESCE(is_deleted, false) = false
    );

-- 2.4 Acotar ledger_read_store para no exponer asientos de archivados vía PostgREST
DROP POLICY IF EXISTS "ledger_read_store" ON public.client_ledger;
CREATE POLICY "ledger_read_store"
    ON public.client_ledger
    FOR SELECT
    TO authenticated
    USING (
        store_id = public.get_current_store_id()
        AND EXISTS (
            SELECT 1
            FROM public.clients c
            WHERE c.id = client_ledger.client_id
              AND COALESCE(c.is_deleted, false) = false
        )
    );

-- 2.5 Endurecer admin_profiles_update_self contra escalamiento horizontal de store_id / role (Bloque 3)
DROP POLICY IF EXISTS "admin_profiles_update_self" ON public.admin_profiles;
CREATE POLICY "admin_profiles_update_self"
    ON public.admin_profiles
    FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (
        id = auth.uid()
        AND store_id = (SELECT ap.store_id FROM public.admin_profiles ap WHERE ap.id = auth.uid())
        AND role = (SELECT ap.role FROM public.admin_profiles ap WHERE ap.id = auth.uid())
    );

-- 2.6 Corregir aislamiento multi-tenant y rol 'manager' en políticas SELECT de auditoría (G-7)
DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_logs;
CREATE POLICY "Admins can view audit logs"
    ON public.audit_logs
    FOR SELECT
    TO authenticated
    USING (
        store_id = public.get_current_store_id()
        AND EXISTS (
            SELECT 1
            FROM public.admin_profiles ap
            WHERE ap.id = auth.uid()
              AND ap.store_id = audit_logs.store_id
              AND ap.role IN ('owner', 'manager')
        )
    );

DROP POLICY IF EXISTS "audit_seguridad_select_admin" ON public.audit_seguridad;
CREATE POLICY "audit_seguridad_select_admin"
    ON public.audit_seguridad
    FOR SELECT
    TO authenticated
    USING (
        store_id = public.get_current_store_id()
        AND EXISTS (
            SELECT 1
            FROM public.admin_profiles ap
            WHERE ap.id = auth.uid()
              AND ap.store_id = audit_seguridad.store_id
              AND ap.role IN ('owner', 'manager')
        )
    );

-- ----------------------------------------------------------------------------
-- 3. Helper Interno DRY para Resolución Segura de Nombre de Actor
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public._resolve_store_actor_name(
    p_store_id uuid,
    p_actor_id uuid
)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
    v_name text;
BEGIN
    SELECT COALESCE(
        (
            SELECT NULLIF(trim(e.name), '')
            FROM public.employees e
            WHERE e.id = p_actor_id
              AND e.store_id = p_store_id
            LIMIT 1
        ),
        (
            SELECT NULLIF(trim(u.raw_user_meta_data->>'owner_name'), '')
            FROM auth.users u
            WHERE u.id = auth.uid()
        ),
        (
            SELECT NULLIF(trim(u.raw_user_meta_data->>'full_name'), '')
            FROM auth.users u
            WHERE u.id = auth.uid()
        ),
        (
            SELECT NULLIF(split_part(u.email, '@', 1), '')
            FROM auth.users u
            WHERE u.id = auth.uid()
        ),
        'Administrador'
    ) INTO v_name;

    RETURN v_name;
END;
$$;

REVOKE ALL ON FUNCTION public._resolve_store_actor_name(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public._resolve_store_actor_name(uuid, uuid) TO service_role;

-- ----------------------------------------------------------------------------
-- 4. RPCs Principales de SDD-030 (y Reconciliación con SDD-029)
-- ----------------------------------------------------------------------------

-- 4.1 Alta / Re-alta Silenciosa Atómica de Cliente Fiado (SDD-029 §5.6 + SDD-030 §5.2)
CREATE OR REPLACE FUNCTION public.rpc_crear_cliente_fiado(
    p_store_id uuid,
    p_name text,
    p_id_number text,
    p_phone text DEFAULT NULL,
    p_credit_limit numeric DEFAULT 100000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
    v_name text := trim(COALESCE(p_name, ''));
    v_id_number text := trim(COALESCE(p_id_number, ''));
    v_phone text := NULLIF(trim(COALESCE(p_phone, '')), '');
    v_admin_role text;
    v_actor_id uuid;
    v_actor_name text;
    v_existing public.clients%ROWTYPE;
    v_client public.clients%ROWTYPE;
    v_conf_id uuid;
    v_now timestamptz := now();
BEGIN
    -- 1. Aislamiento Multi-Tenant antes de bloqueos (Regla 4)
    PERFORM public.assert_store_access(p_store_id);

    -- 2. Validación de Rol Administrativo en servidor (D-ARCO-01 / D-LEG-05)
    SELECT role INTO v_admin_role
    FROM public.admin_profiles
    WHERE id = auth.uid() AND store_id = p_store_id;

    IF v_admin_role IS NULL OR v_admin_role NOT IN ('owner', 'manager') THEN
        RAISE EXCEPTION 'UNAUTHORIZED: Solo administradores autorizados pueden registrar o reactivar clientes.'
            USING ERRCODE = '42501';
    END IF;

    -- 3. Validación de Datos de Entrada
    IF length(v_name) < 3 THEN
        RAISE EXCEPTION 'INVALID_CLIENT_NAME: El nombre del cliente debe tener al menos 3 caracteres.'
            USING ERRCODE = '22023';
    END IF;

    IF v_id_number = '' THEN
        RAISE EXCEPTION 'INVALID_ID_NUMBER: El número de identificación es obligatorio.'
            USING ERRCODE = '22023';
    END IF;

    IF p_credit_limit IS NULL OR p_credit_limit < 0 THEN
        RAISE EXCEPTION 'INVALID_CREDIT_LIMIT: El límite de crédito debe ser mayor o igual a cero.'
            USING ERRCODE = '22023';
    END IF;

    -- 4. Resolución de autoría para bitácoras probatorias (RN-15 / RN-08)
    v_actor_id := COALESCE(public.get_employee_id_from_session(), auth.uid());
    v_actor_name := public._resolve_store_actor_name(p_store_id, v_actor_id);

    -- 5. Búsqueda y bloqueo pesimista por (store_id, id_number)
    SELECT * INTO v_existing
    FROM public.clients
    WHERE store_id = p_store_id
      AND id_number = v_id_number
    FOR UPDATE;

    IF FOUND THEN
        IF COALESCE(v_existing.is_deleted, false) = false THEN
            RAISE EXCEPTION 'DUPLICATE_CLIENT_ID_NUMBER: Ya existe un cliente activo con esa cédula en la tienda.'
                USING ERRCODE = '23505';
        END IF;

        -- Re-alta silenciosa desde Archivo Contable (RN-03, RN-05)
        UPDATE public.clients
        SET name = v_name,
            phone = v_phone,
            credit_limit = p_credit_limit,
            is_deleted = false,
            deleted_at = NULL
        WHERE id = v_existing.id
        RETURNING * INTO v_client;

        INSERT INTO public.client_registration_confirmations (
            store_id, client_id, created_by_user_id, created_by_name, confirmed_at
        ) VALUES (
            p_store_id, v_client.id, v_actor_id, v_actor_name, v_now
        ) RETURNING id INTO v_conf_id;

        INSERT INTO public.client_lifecycle_audit (
            store_id, client_id, event_type, actor_id, actor_name, actor_role, created_at
        ) VALUES (
            p_store_id, v_client.id, 'REACTIVATED', v_actor_id, v_actor_name, v_admin_role, v_now
        );
    ELSE
        -- Alta normal nueva
        BEGIN
            INSERT INTO public.clients (
                store_id, name, id_number, phone, credit_limit, balance, is_deleted, deleted_at
            ) VALUES (
                p_store_id, v_name, v_id_number, v_phone, p_credit_limit, 0, false, NULL
            ) RETURNING * INTO v_client;
        EXCEPTION
            WHEN unique_violation THEN
                RAISE EXCEPTION 'DUPLICATE_CLIENT_ID_NUMBER: Cédula duplicada en la tienda.'
                    USING ERRCODE = '23505';
        END;

        INSERT INTO public.client_registration_confirmations (
            store_id, client_id, created_by_user_id, created_by_name, confirmed_at
        ) VALUES (
            p_store_id, v_client.id, v_actor_id, v_actor_name, v_now
        ) RETURNING id INTO v_conf_id;
    END IF;

    -- Respuesta estándar opaca (RN-03: omite is_deleted y deleted_at)
    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'client', jsonb_build_object(
                'id', v_client.id,
                'store_id', v_client.store_id,
                'name', v_client.name,
                'id_number', v_client.id_number,
                'phone', v_client.phone,
                'credit_limit', v_client.credit_limit,
                'balance', v_client.balance,
                'created_at', v_client.created_at,
                'updated_at', v_client.updated_at
            ),
            'confirmation_id', v_conf_id,
            'confirmed_at', v_now
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_crear_cliente_fiado(uuid, text, text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_crear_cliente_fiado(uuid, text, text, text, numeric) TO authenticated, service_role;

-- 4.2 Eliminación Protegida Bifurcada con Resguardo Contable Opaco (SDD-030 §5.1, RN-01..RN-04, RN-08)
CREATE OR REPLACE FUNCTION public.rpc_eliminar_cliente(
    p_client_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
    v_store_id uuid;
    v_admin_role text;
    v_client public.clients%ROWTYPE;
    v_has_history boolean := false;
    v_actor_id uuid;
    v_actor_name text;
    v_now timestamptz := now();
BEGIN
    -- 1. Aislamiento Multi-Tenant ANTES de cualquier lectura/bloqueo en clients (Regla 4)
    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED: Sesión sin tienda activa asociada.'
            USING ERRCODE = '42501';
    END IF;
    PERFORM public.assert_store_access(v_store_id);

    -- 2. RBAC Estricto Administrativo en servidor (RN-02 / Caso B1)
    SELECT role INTO v_admin_role
    FROM public.admin_profiles
    WHERE id = auth.uid() AND store_id = v_store_id;

    IF v_admin_role IS NULL OR v_admin_role NOT IN ('owner', 'manager') THEN
        RAISE EXCEPTION 'UNAUTHORIZED: Solo administradores de la tienda pueden eliminar clientes.'
            USING ERRCODE = '42501';
    END IF;

    -- 3. Bloqueo pesimista exclusivo de fila en la tienda activa
    SELECT * INTO v_client
    FROM public.clients
    WHERE id = p_client_id
      AND store_id = v_store_id
    FOR UPDATE;

    IF NOT FOUND OR COALESCE(v_client.is_deleted, false) = true THEN
        RAISE EXCEPTION 'CLIENT_NOT_FOUND: El cliente no existe en la tienda activa.'
            USING ERRCODE = 'P0002';
    END IF;

    -- 4. Bloqueo por Deuda Pendiente (RN-01 / Caso A)
    IF COALESCE(v_client.balance, 0) > 0 THEN
        RAISE EXCEPTION 'CLIENT_HAS_DEBT: El cliente tiene un saldo pendiente de $% y no puede eliminarse.', v_client.balance
            USING ERRCODE = 'P0001';
    END IF;

    -- 5. Resolución de autoría e inspección de historial contable (client_ledger OR sales)
    v_actor_id := COALESCE(public.get_employee_id_from_session(), auth.uid());
    v_actor_name := public._resolve_store_actor_name(v_store_id, v_actor_id);

    SELECT (
        EXISTS (SELECT 1 FROM public.client_ledger cl WHERE cl.client_id = p_client_id)
        OR EXISTS (SELECT 1 FROM public.sales s WHERE s.client_id = p_client_id)
    ) INTO v_has_history;

    IF v_has_history THEN
        -- Archivo Contable Silencioso (RN-04: limpia teléfono, cupo a 0, conserva identidad contable)
        UPDATE public.clients
        SET phone = NULL,
            credit_limit = 0,
            is_deleted = true,
            deleted_at = v_now
        WHERE id = p_client_id
          AND store_id = v_store_id;

        INSERT INTO public.client_lifecycle_audit (
            store_id, client_id, event_type, actor_id, actor_name, actor_role, created_at
        ) VALUES (
            v_store_id, p_client_id, 'ARCHIVED_ACCOUNTING', v_actor_id, v_actor_name, v_admin_role, v_now
        );
    ELSE
        -- Borrado Físico Definitivo por cero movimientos (RN-04)
        DELETE FROM public.clients
        WHERE id = p_client_id
          AND store_id = v_store_id;

        INSERT INTO public.client_lifecycle_audit (
            store_id, client_id, event_type, actor_id, actor_name, actor_role, created_at
        ) VALUES (
            v_store_id, p_client_id, 'HARD_DELETED', v_actor_id, v_actor_name, v_admin_role, v_now
        );
    END IF;

    -- 6. Retorno Uniforme Opaco (RN-03: jamás expone si fue archivado o borrado físico)
    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'client_id', p_client_id,
            'deleted', true,
            'deleted_at', v_now
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_eliminar_cliente(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_eliminar_cliente(uuid) TO authenticated, service_role;

-- 4.3 Consulta y Base de Exportación Fiel de Estado de Cuenta (SDD-030 §5.3, RN-06, READ-ONLY sin FOR UPDATE)
CREATE OR REPLACE FUNCTION public.rpc_obtener_estado_cuenta_cliente(
    p_client_id uuid,
    p_limit integer DEFAULT 20,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_store_id uuid;
    v_is_admin boolean := false;
    v_is_active_employee boolean := false;
    v_limit integer := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 500);
    v_offset integer := GREATEST(COALESCE(p_offset, 0), 0);
    v_client public.clients%ROWTYPE;
    v_movements jsonb;
    v_total_count integer := 0;
BEGIN
    -- 1. Guardia Multi-Tenant obligatoria
    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED: Sesión sin tienda activa asociada.'
            USING ERRCODE = '42501';
    END IF;
    PERFORM public.assert_store_access(v_store_id);

    -- 2. Autorización dual (Admin O Empleado activo con validación explícita e.is_active = true, D-ARCO-02)
    SELECT EXISTS (
        SELECT 1
        FROM public.admin_profiles ap
        WHERE ap.id = auth.uid()
          AND ap.store_id = v_store_id
          AND ap.role IN ('owner', 'manager')
    ) INTO v_is_admin;

    IF NOT v_is_admin THEN
        SELECT EXISTS (
            SELECT 1
            FROM public.employees e
            WHERE e.store_id = v_store_id
              AND e.is_active = true
              AND (
                  e.id = auth.uid()
                  OR e.id = public.get_employee_id_from_session()
              )
        ) INTO v_is_active_employee;

        IF NOT v_is_active_employee THEN
            RAISE EXCEPTION 'UNAUTHORIZED: Usuario no autorizado o empleado inactivo para consultar estados de cuenta.'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- 3. Lectura consistente de cliente activo SIN bloqueo FOR UPDATE
    SELECT * INTO v_client
    FROM public.clients c
    WHERE c.id = p_client_id
      AND c.store_id = v_store_id
      AND COALESCE(c.is_deleted, false) = false;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'CLIENT_NOT_FOUND: El cliente no existe o no se encuentra activo en la tienda.'
            USING ERRCODE = 'P0002';
    END IF;

    SELECT COUNT(*) INTO v_total_count
    FROM public.client_ledger cl
    WHERE cl.client_id = p_client_id
      AND cl.store_id = v_store_id;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', sub.id,
                'transaction_type', sub.transaction_type,
                'amount', sub.amount,
                'previous_balance', sub.previous_balance,
                'new_balance', sub.new_balance,
                'reference_id', sub.reference_id,
                'ticket_number', sub.ticket_number,
                'created_at', sub.created_at
            )
            ORDER BY sub.created_at DESC, sub.id DESC
        ),
        '[]'::jsonb
    ) INTO v_movements
    FROM (
        SELECT cl.id,
               cl.transaction_type,
               cl.amount,
               cl.previous_balance,
               cl.new_balance,
               cl.reference_id,
               s.ticket_number,
               cl.created_at
        FROM public.client_ledger cl
        LEFT JOIN public.sales s ON s.id = cl.reference_id
        WHERE cl.client_id = p_client_id
          AND cl.store_id = v_store_id
        ORDER BY cl.created_at DESC, cl.id DESC
        LIMIT v_limit OFFSET v_offset
    ) sub;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'client', jsonb_build_object(
                'id', v_client.id,
                'name', v_client.name,
                'id_number', v_client.id_number,
                'phone', v_client.phone,
                'credit_limit', v_client.credit_limit,
                'balance', v_client.balance,
                'credit_available', GREATEST(0, v_client.credit_limit - COALESCE(v_client.balance, 0))
            ),
            'movements', v_movements,
            'generated_at', now()
        ),
        'count', v_total_count
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_obtener_estado_cuenta_cliente(uuid, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_obtener_estado_cuenta_cliente(uuid, integer, integer) TO authenticated, service_role;

-- 4.4 Actualización Segura de Datos Básicos sin Alterar Historia Contable ni Caja (SDD-030 §5.4, RN-07)
CREATE OR REPLACE FUNCTION public.rpc_actualizar_cliente(
    p_client_id uuid,
    p_name text,
    p_id_number text,
    p_phone text DEFAULT NULL,
    p_credit_limit numeric DEFAULT 100000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_store_id uuid;
    v_admin_role text;
    v_client public.clients%ROWTYPE;
    v_name text := trim(COALESCE(p_name, ''));
    v_id_number text := trim(COALESCE(p_id_number, ''));
    v_phone text := NULLIF(trim(COALESCE(p_phone, '')), '');
    v_updated public.clients%ROWTYPE;
BEGIN
    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED: Sesión sin tienda activa asociada.'
            USING ERRCODE = '42501';
    END IF;
    PERFORM public.assert_store_access(v_store_id);

    SELECT role INTO v_admin_role
    FROM public.admin_profiles
    WHERE id = auth.uid() AND store_id = v_store_id;

    IF v_admin_role IS NULL OR v_admin_role NOT IN ('owner', 'manager') THEN
        RAISE EXCEPTION 'UNAUTHORIZED: Solo administradores autorizados pueden editar datos de clientes.'
            USING ERRCODE = '42501';
    END IF;

    IF length(v_name) < 3 THEN
        RAISE EXCEPTION 'INVALID_CLIENT_NAME: El nombre del cliente debe tener al menos 3 caracteres.'
            USING ERRCODE = '22023';
    END IF;

    IF v_id_number = '' THEN
        RAISE EXCEPTION 'INVALID_ID_NUMBER: El número de identificación es obligatorio.'
            USING ERRCODE = '22023';
    END IF;

    IF p_credit_limit IS NULL OR p_credit_limit < 0 THEN
        RAISE EXCEPTION 'INVALID_CREDIT_LIMIT: El límite de crédito debe ser mayor o igual a cero.'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_client
    FROM public.clients
    WHERE id = p_client_id
      AND store_id = v_store_id
    FOR UPDATE;

    IF NOT FOUND OR COALESCE(v_client.is_deleted, false) = true THEN
        RAISE EXCEPTION 'CLIENT_NOT_FOUND: El cliente no existe o no se encuentra activo.'
            USING ERRCODE = 'P0002';
    END IF;

    -- Unicidad en toda la tienda (activos y archivados) para impedir fusionar identidades (CL-030-05)
    IF EXISTS (
        SELECT 1
        FROM public.clients c
        WHERE c.store_id = v_store_id
          AND c.id_number = v_id_number
          AND c.id <> p_client_id
    ) THEN
        RAISE EXCEPTION 'DUPLICATE_CLIENT_ID_NUMBER: La cédula ingresada ya pertenece a otro registro de esta tienda.'
            USING ERRCODE = '23505';
    END IF;

    UPDATE public.clients
    SET name = v_name,
        id_number = v_id_number,
        phone = v_phone,
        credit_limit = p_credit_limit
    WHERE id = p_client_id
      AND store_id = v_store_id
    RETURNING * INTO v_updated;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'client', jsonb_build_object(
                'id', v_updated.id,
                'store_id', v_updated.store_id,
                'name', v_updated.name,
                'id_number', v_updated.id_number,
                'phone', v_updated.phone,
                'credit_limit', v_updated.credit_limit,
                'balance', v_updated.balance,
                'updated_at', v_updated.updated_at
            )
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_actualizar_cliente(uuid, text, text, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_actualizar_cliente(uuid, text, text, text, numeric) TO authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 5. Remediaciones Coordinadas en Funciones Vecinas (SDD-030 §5.5 y §6.3)
-- ----------------------------------------------------------------------------

-- 5.1 Corregir get_employee_id_from_session para validar employees.is_active en pases diarios
CREATE OR REPLACE FUNCTION public.get_employee_id_from_session()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_employee_id uuid;
    v_today date := (now() AT TIME ZONE 'America/Bogota')::date;
BEGIN
    SELECT id INTO v_employee_id
    FROM public.employees
    WHERE id = v_user_id AND is_active = true;

    IF v_employee_id IS NOT NULL THEN
        RETURN v_employee_id;
    END IF;

    SELECT dp.employee_id INTO v_employee_id
    FROM public.daily_passes dp
    JOIN public.employees e ON e.id = dp.employee_id AND e.store_id = dp.store_id
    WHERE dp.auth_user_id = v_user_id
      AND dp.status = 'approved'
      AND e.is_active = true
      AND (
          dp.pass_date = v_today
          OR (
              dp.pass_date = v_today - 1
              AND EXISTS (
                  SELECT 1 FROM public.cash_sessions cs
                  WHERE cs.store_id = dp.store_id
                    AND cs.status = 'open'
                    AND cs.opened_at >= (now() - interval '24 hours')
              )
          )
      )
    ORDER BY dp.pass_date DESC
    LIMIT 1;

    RETURN v_employee_id;
END;
$$;

REVOKE ALL ON FUNCTION public.get_employee_id_from_session() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_employee_id_from_session() TO authenticated, service_role;

-- 5.2 Remediar get_client_ledger_summary (assert_store_access + search_path + revocar PUBLIC/anon)
CREATE OR REPLACE FUNCTION public.get_client_ledger_summary(
    p_store_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_cartera_total numeric DEFAULT 0;
    v_cartera_vencida numeric DEFAULT 0;
    v_clientes_con_deuda integer DEFAULT 0;
    v_clientes_morosos integer DEFAULT 0;
    v_top_deudores jsonb;
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    SELECT COALESCE(SUM(balance), 0),
           COALESCE(SUM(CASE WHEN updated_at < CURRENT_DATE - INTERVAL '30 days' THEN balance ELSE 0 END), 0),
           COUNT(id),
           COUNT(CASE WHEN updated_at < CURRENT_DATE - INTERVAL '30 days' THEN 1 END)
    INTO v_cartera_total, v_cartera_vencida, v_clientes_con_deuda, v_clientes_morosos
    FROM public.clients
    WHERE store_id = p_store_id
      AND balance > 0
      AND COALESCE(is_deleted, false) = false;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'client_id', id,
                'client_name', name,
                'balance', balance,
                'dias_sin_pagar', EXTRACT(DAY FROM (CURRENT_TIMESTAMP - updated_at))::integer,
                'ultima_compra', DATE(updated_at)
            )
        ),
        '[]'::jsonb
    ) INTO v_top_deudores
    FROM (
        SELECT id, name, balance, updated_at
        FROM public.clients
        WHERE store_id = p_store_id
          AND balance > 0
          AND COALESCE(is_deleted, false) = false
        ORDER BY balance DESC
        LIMIT 5
    ) top_clients;

    RETURN jsonb_build_object(
        'cartera_total', v_cartera_total,
        'cartera_vencida', v_cartera_vencida,
        'clientes_con_deuda', v_clientes_con_deuda,
        'clientes_morosos', v_clientes_morosos,
        'top_deudores', v_top_deudores
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_client_ledger_summary(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_client_ledger_summary(uuid) TO authenticated, service_role;

-- 5.3 Endurecer rpc_admin_get_clients (retira p_include_deleted / is_deleted / deleted_at, RN-03/04)
DROP FUNCTION IF EXISTS public.rpc_admin_get_clients(uuid, text, boolean, text, text, integer, integer);
CREATE OR REPLACE FUNCTION public.rpc_admin_get_clients(
    p_store_id uuid,
    p_filter_debt text DEFAULT 'todos'::text,
    p_search_query text DEFAULT NULL::text,
    p_order_by text DEFAULT 'name_asc'::text,
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_role text;
    v_total_count integer;
    v_clients jsonb;
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    SELECT role INTO v_role
    FROM public.admin_profiles
    WHERE id = auth.uid() AND store_id = p_store_id;

    IF v_role IS NULL OR v_role NOT IN ('owner', 'manager') THEN
        RAISE EXCEPTION 'UNAUTHORIZED: Consulta administrativa restringida a administradores.'
            USING ERRCODE = '42501';
    END IF;

    SELECT COUNT(*) INTO v_total_count
    FROM public.clients c
    WHERE c.store_id = p_store_id
      AND COALESCE(c.is_deleted, false) = false
      AND (
          p_filter_debt = 'todos' OR
          (p_filter_debt = 'con_deuda' AND c.balance > 0) OR
          (p_filter_debt = 'sin_deuda' AND c.balance <= 0)
      )
      AND (
          p_search_query IS NULL OR
          c.name ILIKE '%' || p_search_query || '%' OR
          c.id_number ILIKE '%' || p_search_query || '%' OR
          c.phone ILIKE '%' || p_search_query || '%'
      );

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', c.id,
                'name', c.name,
                'id_number', c.id_number,
                'phone', c.phone,
                'credit_limit', c.credit_limit,
                'balance', c.balance,
                'credit_available', GREATEST(0, c.credit_limit - c.balance),
                'credit_usage_pct', CASE WHEN c.credit_limit > 0 THEN ROUND((c.balance / c.credit_limit) * 100, 1) ELSE 0 END,
                'created_at', c.created_at
            ) ORDER BY
                CASE WHEN p_order_by = 'balance_desc' THEN c.balance END DESC NULLS LAST,
                CASE WHEN p_order_by = 'balance_asc' THEN c.balance END ASC NULLS LAST,
                CASE WHEN p_order_by = 'name_asc' THEN c.name END ASC,
                CASE WHEN p_order_by = 'name_desc' THEN c.name END DESC,
                c.created_at DESC
        ),
        '[]'::jsonb
    ) INTO v_clients
    FROM (
        SELECT *
        FROM public.clients c
        WHERE c.store_id = p_store_id
          AND COALESCE(c.is_deleted, false) = false
          AND (
              p_filter_debt = 'todos' OR
              (p_filter_debt = 'con_deuda' AND c.balance > 0) OR
              (p_filter_debt = 'sin_deuda' AND c.balance <= 0)
          )
          AND (
              p_search_query IS NULL OR
              c.name ILIKE '%' || p_search_query || '%' OR
              c.id_number ILIKE '%' || p_search_query || '%' OR
              c.phone ILIKE '%' || p_search_query || '%'
          )
        ORDER BY
            CASE WHEN p_order_by = 'balance_desc' THEN c.balance END DESC NULLS LAST,
            CASE WHEN p_order_by = 'balance_asc' THEN c.balance END ASC NULLS LAST,
            CASE WHEN p_order_by = 'name_asc' THEN c.name END ASC,
            CASE WHEN p_order_by = 'name_desc' THEN c.name END DESC,
            c.created_at DESC
        LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    ) c;

    RETURN jsonb_build_object(
        'success', true,
        'data', v_clients,
        'count', v_total_count
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_admin_get_clients(uuid, text, text, text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_admin_get_clients(uuid, text, text, text, integer, integer) TO authenticated, service_role;

-- 5.4 Remediar rpc_registrar_abono (assert_store_access ANTES de FOR UPDATE + activo + created_by FK seguro)
CREATE OR REPLACE FUNCTION public.rpc_registrar_abono(
    p_client_id uuid,
    p_amount numeric,
    p_payment_method text,
    p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_store_id uuid;
    v_client public.clients%ROWTYPE;
    v_employee_id uuid;
    v_session_id uuid;
    v_session_opened_at timestamptz;
    v_new_balance numeric;
    v_cash_movement_id uuid;
    v_ledger_id uuid;
BEGIN
    -- 1. Validar Monto y Método antes de locks
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'El monto del abono debe ser mayor a cero (INVALID_AMOUNT)' USING ERRCODE = 'P0001';
    END IF;

    IF p_payment_method NOT IN ('efectivo', 'nequi', 'daviplata', 'bre') THEN
        RAISE EXCEPTION 'Método de pago no válido para abono: % (INVALID_PAYMENT_METHOD)', p_payment_method USING ERRCODE = 'P0001';
    END IF;

    -- 2. Regla 4: Aislamiento Multi-Tenant ANTES de FOR UPDATE en clients (G-7)
    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED' USING ERRCODE = '42501';
    END IF;
    PERFORM public.assert_store_access(v_store_id);

    -- 3. Validar y bloquear cliente activo dentro de v_store_id
    SELECT * INTO v_client
    FROM public.clients
    WHERE id = p_client_id
      AND store_id = v_store_id
      AND COALESCE(is_deleted, false) = false
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cliente no encontrado (CLIENT_NOT_FOUND)' USING ERRCODE = 'P0001';
    END IF;

    -- 4. Validar deuda pendiente
    IF v_client.balance <= 0 THEN
        RAISE EXCEPTION 'El cliente no tiene saldo deudor pendiente (NO_OUTSTANDING_DEBT)' USING ERRCODE = 'P0001';
    END IF;

    IF p_amount > v_client.balance THEN
        RAISE EXCEPTION 'El abono ($%) supera la deuda actual ($%) (AMOUNT_EXCEEDS_DEBT)',
            p_amount, v_client.balance USING ERRCODE = 'P0001';
    END IF;

    -- 5. Validar turno de caja abierto
    SELECT id, opened_at INTO v_session_id, v_session_opened_at
    FROM public.cash_sessions
    WHERE store_id = v_client.store_id AND status = 'open'
    ORDER BY opened_at DESC LIMIT 1;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION 'No hay turno de caja abierto para registrar el abono (NO_OPEN_CASH_SESSION)' USING ERRCODE = 'P0001';
    END IF;

    IF v_session_opened_at < NOW() - INTERVAL '24 hours' THEN
        RAISE EXCEPTION 'El turno de caja ha superado las 24 horas y debe ser cerrado (SHIFT_EXPIRED_24H)' USING ERRCODE = 'P0001';
    END IF;

    -- Resolver created_by válido para FK client_ledger.created_by -> employees(id) (NULL seguro si manager sin fila)
    SELECT e.id INTO v_employee_id
    FROM public.employees e
    WHERE e.id = COALESCE(public.get_employee_id_from_session(), auth.uid())
      AND e.store_id = v_store_id
    LIMIT 1;

    -- 6. Actualizar Saldo del Cliente
    v_new_balance := v_client.balance - p_amount;
    UPDATE public.clients
    SET balance = v_new_balance, updated_at = NOW()
    WHERE id = p_client_id;

    -- 7. Asentar en Cartera (new_balance es GENERATED ALWAYS)
    INSERT INTO public.client_ledger (
        client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by
    ) VALUES (
        p_client_id, v_client.store_id, -p_amount, v_client.balance, NULL, 'abono', v_employee_id
    ) RETURNING id INTO v_ledger_id;

    -- 8. Asentar Ingreso Multicanal en Caja Abierta
    INSERT INTO public.cash_movements (
        session_id, movement_type, amount, description, payment_method, category, actor_id
    ) VALUES (
        v_session_id, 'ingreso', p_amount, '[ABONO_CLIENTE: ' || v_client.name || '] ' || COALESCE(p_notes, ''), p_payment_method, 'abono_cliente', v_employee_id
    ) RETURNING id INTO v_cash_movement_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'client_id', p_client_id,
            'previous_balance', v_client.balance,
            'amount_paid', p_amount,
            'new_balance', v_new_balance,
            'payment_method', p_payment_method,
            'cash_movement_id', v_cash_movement_id,
            'session_id', v_session_id,
            'ledger_id', v_ledger_id,
            'created_at', NOW()
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_registrar_abono(uuid, numeric, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_registrar_abono(uuid, numeric, text, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.registrar_abono(uuid, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.registrar_abono(uuid, numeric) TO authenticated, service_role;

-- 5.5 Remediar rpc_procesar_venta_v3 (descarta client_id fuera de 'fiado' + filtra is_deleted en 'fiado')
CREATE OR REPLACE FUNCTION public.rpc_procesar_venta_v3(
    p_store_id uuid,
    p_client_id uuid,
    p_payment_method text,
    p_amount_received numeric,
    p_items jsonb,
    p_idempotency_key uuid DEFAULT NULL::uuid,
    p_local_id text DEFAULT NULL::text,
    p_is_offline_sync boolean DEFAULT false,
    p_origin_session_id uuid DEFAULT NULL::uuid,
    p_sold_by uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_sale_id uuid;
    v_ticket_number integer;
    v_total_calculated numeric := 0;
    v_total_raw numeric := 0;
    v_rounding_difference numeric := 0;
    v_change numeric := 0;
    v_item jsonb;
    v_product_id uuid;
    v_quantity numeric;
    v_product_price numeric;
    v_product_cost numeric;
    v_product_name text;
    v_is_weighable boolean;
    v_item_subtotal numeric;
    v_raw_subtotal numeric;
    v_client_balance numeric;
    v_client_limit numeric;
    v_sale_client_id uuid;
    v_employee_id uuid;
    v_pm_allows_change boolean;
    v_batch RECORD;
    v_sale_item_id uuid;
    v_session_id uuid;
    v_session_status text;
    v_session_opened_at timestamptz;
    v_items_count integer := 0;
    v_existing_sale RECORD;
    v_historical_price numeric;
    v_is_late_sync boolean := false;
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    IF p_is_offline_sync AND p_sold_by IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM public.employees WHERE id = p_sold_by AND store_id = p_store_id) THEN
            v_employee_id := p_sold_by;
        END IF;
    END IF;

    IF v_employee_id IS NULL THEN
        v_employee_id := public.get_employee_id_from_session();
    END IF;

    IF v_employee_id IS NULL THEN
        IF EXISTS (SELECT 1 FROM public.admin_profiles WHERE id = auth.uid() AND store_id = p_store_id) THEN
            v_employee_id := auth.uid();
        ELSE
            RAISE EXCEPTION 'Usuario no autorizado para vender (STORE_ACCESS_DENIED)' USING ERRCODE = 'P0001';
        END IF;
    END IF;

    IF p_idempotency_key IS NOT NULL THEN
        SELECT id, ticket_number, total, change_given, rounding_difference, payment_method, created_at
        INTO v_existing_sale
        FROM public.sales
        WHERE store_id = p_store_id AND idempotency_key = p_idempotency_key;

        IF FOUND THEN
            SELECT COUNT(*) INTO v_items_count FROM public.sale_items WHERE sale_id = v_existing_sale.id;
            RETURN jsonb_build_object(
                'success', true,
                'code', 'DUPLICATE_RESOLVED',
                'data', jsonb_build_object(
                    'sale_id', v_existing_sale.id,
                    'ticket_number', v_existing_sale.ticket_number,
                    'total', v_existing_sale.total,
                    'rounding_difference', v_existing_sale.rounding_difference,
                    'amount_received', p_amount_received,
                    'change_given', v_existing_sale.change_given,
                    'payment_method', v_existing_sale.payment_method,
                    'items_count', v_items_count,
                    'created_at', v_existing_sale.created_at,
                    'is_idempotent_replay', true,
                    'code', 'DUPLICATE_RESOLVED'
                )
            );
        END IF;
    END IF;

    IF p_local_id IS NOT NULL THEN
        SELECT id, ticket_number, total, change_given, rounding_difference, payment_method, created_at
        INTO v_existing_sale
        FROM public.sales
        WHERE store_id = p_store_id AND local_id = p_local_id;

        IF FOUND THEN
            SELECT COUNT(*) INTO v_items_count FROM public.sale_items WHERE sale_id = v_existing_sale.id;
            RETURN jsonb_build_object(
                'success', true,
                'code', 'DUPLICATE_RESOLVED',
                'data', jsonb_build_object(
                    'sale_id', v_existing_sale.id,
                    'ticket_number', v_existing_sale.ticket_number,
                    'total', v_existing_sale.total,
                    'rounding_difference', v_existing_sale.rounding_difference,
                    'amount_received', p_amount_received,
                    'change_given', v_existing_sale.change_given,
                    'payment_method', v_existing_sale.payment_method,
                    'items_count', v_items_count,
                    'created_at', v_existing_sale.created_at,
                    'is_idempotent_replay', true,
                    'code', 'DUPLICATE_RESOLVED'
                )
            );
        END IF;
    END IF;

    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'El carrito no puede estar vacío (EMPTY_CART)' USING ERRCODE = 'P0001';
    END IF;

    IF jsonb_array_length(p_items) > 50 THEN
        RAISE EXCEPTION 'El carrito no puede superar 50 ítems (CART_LIMIT_EXCEEDED)' USING ERRCODE = 'P0001';
    END IF;

    IF p_payment_method NOT IN ('efectivo', 'nequi', 'daviplata', 'fiado', 'bre') THEN
        RAISE EXCEPTION 'Método de pago inválido: % (INVALID_PAYMENT_METHOD)', p_payment_method USING ERRCODE = 'P0001';
    END IF;

    v_pm_allows_change := (p_payment_method = 'efectivo');

    -- Regla RN-16 FRD-029 + CONFLICTO-03 SDD-030: solo 'fiado' puede asociarse a un client_id
    v_sale_client_id := CASE WHEN p_payment_method = 'fiado' THEN p_client_id ELSE NULL END;

    IF p_payment_method IN ('efectivo', 'nequi', 'daviplata', 'bre') THEN
        IF p_is_offline_sync AND p_origin_session_id IS NOT NULL THEN
            SELECT id, status, opened_at INTO v_session_id, v_session_status, v_session_opened_at
            FROM public.cash_sessions
            WHERE id = p_origin_session_id AND store_id = p_store_id;

            IF v_session_id IS NOT NULL AND v_session_status = 'closed' THEN
                v_is_late_sync := true;
            END IF;
        END IF;

        IF v_session_id IS NULL THEN
            SELECT id, status, opened_at INTO v_session_id, v_session_status, v_session_opened_at
            FROM public.cash_sessions
            WHERE store_id = p_store_id AND status = 'open'
            ORDER BY opened_at DESC LIMIT 1;
        END IF;

        IF v_session_id IS NULL THEN
            IF p_is_offline_sync THEN
                SELECT id, status, opened_at INTO v_session_id, v_session_status, v_session_opened_at
                FROM public.cash_sessions
                WHERE store_id = p_store_id
                ORDER BY opened_at DESC LIMIT 1;

                IF v_session_id IS NOT NULL AND v_session_status = 'closed' THEN
                    v_is_late_sync := true;
                END IF;
            END IF;

            IF v_session_id IS NULL THEN
                RAISE EXCEPTION 'No hay turno de caja abierto (NO_OPEN_CASH_SESSION)' USING ERRCODE = 'P0001';
            END IF;
        END IF;

        IF NOT p_is_offline_sync AND v_session_opened_at < NOW() - INTERVAL '24 hours' THEN
            RAISE EXCEPTION 'El turno de caja ha superado las 24 horas y debe ser cerrado (SHIFT_EXPIRED_24H)' USING ERRCODE = 'P0001';
        END IF;
    END IF;

    SELECT COALESCE(MAX(ticket_number), 0) + 1 INTO v_ticket_number
    FROM public.sales
    WHERE store_id = p_store_id;

    INSERT INTO public.sales (
        store_id, ticket_number, employee_id, client_id, total,
        rounding_difference, payment_method, amount_received, change_given,
        sync_status, local_id, idempotency_key
    ) VALUES (
        p_store_id, v_ticket_number, v_employee_id, v_sale_client_id, 0,
        0, p_payment_method, COALESCE(p_amount_received, 0), 0,
        'synced', p_local_id, p_idempotency_key
    ) RETURNING id INTO v_sale_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_quantity := (v_item->>'quantity')::numeric;

        IF v_quantity <= 0 THEN
            RAISE EXCEPTION 'Cantidad de producto inválida: % (INVALID_QUANTITY)', v_quantity USING ERRCODE = 'P0001';
        END IF;

        SELECT name, price, cost_price, COALESCE(is_weighable, false)
        INTO v_product_name, v_product_price, v_product_cost, v_is_weighable
        FROM public.products
        WHERE id = v_product_id AND store_id = p_store_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto no encontrado: % (PRODUCT_NOT_FOUND)', v_product_id USING ERRCODE = 'P0001';
        END IF;

        v_historical_price := COALESCE(
            (v_item->>'historical_unit_price')::numeric,
            (v_item->>'unit_price')::numeric
        );
        IF p_is_offline_sync AND v_historical_price IS NOT NULL AND v_historical_price > 0 THEN
            v_product_price := v_historical_price;
        END IF;

        INSERT INTO public.sale_items (sale_id, product_id, quantity, unit_price, subtotal, unit_cost)
        VALUES (v_sale_id, v_product_id, v_quantity, 0, 0, 0)
        RETURNING id INTO v_sale_item_id;

        v_item_subtotal := 0;
        v_raw_subtotal := 0;

        FOR v_batch IN SELECT * FROM public.consume_stock_fifo(v_product_id, v_quantity)
        LOOP
            v_raw_subtotal := v_raw_subtotal + (v_batch.quantity_taken * COALESCE(v_batch.sale_price, v_product_price, 0));

            INSERT INTO public.sale_item_batches (sale_item_id, batch_id, quantity_consumed, unit_cost, unit_price)
            VALUES (v_sale_item_id, v_batch.batch_id, v_batch.quantity_taken, v_batch.cost_unit, COALESCE(v_batch.sale_price, v_product_price, 0));
        END LOOP;

        IF v_is_weighable THEN
            v_item_subtotal := FLOOR(v_raw_subtotal / 50.0) * 50;
            v_rounding_difference := v_rounding_difference + (v_raw_subtotal - v_item_subtotal);
        ELSE
            v_item_subtotal := v_raw_subtotal;
        END IF;

        UPDATE public.sale_items
        SET subtotal = v_item_subtotal,
            unit_price = CASE WHEN v_quantity > 0 THEN v_item_subtotal / v_quantity ELSE 0 END,
            unit_cost = COALESCE(v_product_cost, 0)
        WHERE id = v_sale_item_id;

        INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by)
        VALUES (v_product_id, 'venta', v_quantity, 'Venta #' || v_ticket_number, v_employee_id);

        v_total_calculated := v_total_calculated + v_item_subtotal;
        v_items_count := v_items_count + 1;
    END LOOP;

    IF p_payment_method = 'fiado' THEN
        IF v_sale_client_id IS NULL THEN
            RAISE EXCEPTION 'Se requiere especificar el cliente para venta a crédito / fiado (CLIENT_REQUIRED)' USING ERRCODE = 'P0001';
        END IF;

        SELECT balance, credit_limit INTO v_client_balance, v_client_limit
        FROM public.clients
        WHERE id = v_sale_client_id
          AND store_id = p_store_id
          AND COALESCE(is_deleted, false) = false
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Cliente no encontrado (CLIENT_NOT_FOUND)' USING ERRCODE = 'P0001';
        END IF;

        IF (v_client_balance + v_total_calculated) > v_client_limit THEN
            RAISE EXCEPTION 'Cupo de crédito excedido. Disponible: %, Total venta: % (CREDIT_LIMIT_EXCEEDED)',
                (v_client_limit - v_client_balance), v_total_calculated USING ERRCODE = 'P0001';
        END IF;
    END IF;

    IF v_pm_allows_change THEN
        IF p_amount_received < v_total_calculated THEN
            RAISE EXCEPTION 'El monto recibido ($%) es inferior al total a pagar ($%) (INSUFFICIENT_PAYMENT)',
                p_amount_received, v_total_calculated USING ERRCODE = 'P0001';
        END IF;
        v_change := p_amount_received - v_total_calculated;
    ELSE
        v_change := 0;
    END IF;

    UPDATE public.sales
    SET total = v_total_calculated,
        rounding_difference = v_rounding_difference,
        change_given = v_change
    WHERE id = v_sale_id;

    IF p_payment_method IN ('efectivo', 'nequi', 'daviplata', 'bre') THEN
        INSERT INTO public.cash_movements (
            session_id, movement_type, amount, description, sale_id, payment_method, category, actor_id
        ) VALUES (
            v_session_id, 'ingreso', v_total_calculated, 'Venta #' || v_ticket_number, v_sale_id, p_payment_method, 'venta', v_employee_id
        );

        IF v_is_late_sync THEN
            IF p_payment_method = 'efectivo' THEN
                UPDATE public.cash_sessions
                SET expected_balance = COALESCE(expected_balance, 0) + v_total_calculated
                WHERE id = v_session_id;
            END IF;

            INSERT INTO public.audit_logs (
                actor_id, store_id, event_type, resource_id, metadata, severity, created_at
            ) VALUES (
                v_employee_id,
                p_store_id,
                'LATE_SYNC_UPDATE',
                v_sale_id::text,
                jsonb_build_object(
                    'session_id', v_session_id,
                    'sale_id', v_sale_id,
                    'ticket_number', v_ticket_number,
                    'amount', v_total_calculated,
                    'payment_method', p_payment_method,
                    'local_id', p_local_id,
                    'reason', 'Venta offline imputada a turno cerrado histórico'
                ),
                'warning',
                NOW()
            );
        END IF;
    ELSIF p_payment_method = 'fiado' THEN
        UPDATE public.clients
        SET balance = balance + v_total_calculated, updated_at = NOW()
        WHERE id = v_sale_client_id;

        INSERT INTO public.client_ledger (
            client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by
        ) VALUES (
            v_sale_client_id, p_store_id, v_total_calculated, v_client_balance, v_sale_id, 'venta_fiado', v_employee_id
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'sale_id', v_sale_id,
            'ticket_number', v_ticket_number,
            'total', v_total_calculated,
            'rounding_difference', v_rounding_difference,
            'amount_received', COALESCE(p_amount_received, v_total_calculated),
            'change_given', v_change,
            'payment_method', p_payment_method,
            'items_count', v_items_count,
            'created_at', NOW()
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_procesar_venta_v3(uuid, uuid, text, numeric, jsonb, uuid, text, boolean, uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_procesar_venta_v3(uuid, uuid, text, numeric, jsonb, uuid, text, boolean, uuid, uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.rpc_procesar_venta_v2(uuid, uuid, text, numeric, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_procesar_venta_v2(uuid, uuid, text, numeric, jsonb) TO authenticated, service_role;

-- Deshabilitar bypass legado sin assert_store_access ni filtro is_deleted
REVOKE ALL ON FUNCTION public.procesar_venta(uuid, uuid, jsonb, numeric, text, numeric, uuid, text) FROM PUBLIC, anon, authenticated;

-- 5.6 Remediar rpc_anular_venta (assert_store_access pre-lock, rol 'owner'|'manager', guarda archivado/saldo 0)
CREATE OR REPLACE FUNCTION public.rpc_anular_venta(
    p_sale_id uuid,
    p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_store_id uuid;
    v_sale RECORD;
    v_item RECORD;
    v_role text;
    v_employee_id uuid;
    v_client_balance numeric;
    v_client_deleted boolean;
    v_session_id uuid;
    v_session_opened_at timestamptz;
    v_opening numeric := 0;
    v_ingresos numeric := 0;
    v_egresos numeric := 0;
    v_available numeric := 0;
BEGIN
    -- 1. Regla 4: Aislamiento Multi-Tenant ANTES de lockear sales (evita oráculo/lock inter-tenant)
    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED' USING ERRCODE = '42501';
    END IF;
    PERFORM public.assert_store_access(v_store_id);

    -- 2. Obtener Venta dentro de v_store_id
    SELECT * INTO v_sale
    FROM public.sales
    WHERE id = p_sale_id
      AND store_id = v_store_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venta no encontrada (SALE_NOT_FOUND)' USING ERRCODE = 'P0001';
    END IF;

    -- 3. Validación de Rol Administrativo alineada a admin_profiles_role_check ('owner', 'manager')
    SELECT role INTO v_role
    FROM public.admin_profiles
    WHERE id = auth.uid() AND store_id = v_sale.store_id;

    IF v_role IS NULL OR v_role NOT IN ('owner', 'manager') THEN
        RAISE EXCEPTION 'Solo administradores pueden anular ventas (UNAUTHORIZED)' USING ERRCODE = '42501';
    END IF;

    -- 4. Validación de Motivo (mínimo 10 caracteres)
    IF length(trim(COALESCE(p_reason, ''))) < 10 THEN
        RAISE EXCEPTION 'El motivo de anulación debe tener al menos 10 caracteres (REASON_TOO_SHORT)' USING ERRCODE = 'P0001';
    END IF;

    -- 5. Validar si ya está anulada
    IF v_sale.is_voided THEN
        RAISE EXCEPTION 'Esta venta ya fue anulada previamente (SALE_ALREADY_VOIDED)' USING ERRCODE = 'P0001';
    END IF;

    v_employee_id := public.get_employee_id_from_session();
    IF v_employee_id IS NULL THEN
        SELECT id INTO v_employee_id
        FROM public.employees
        WHERE id = auth.uid() AND store_id = v_sale.store_id
        LIMIT 1;
    END IF;
    IF v_employee_id IS NULL THEN
        v_employee_id := auth.uid();
    END IF;

    -- 6. Reversión Financiera Multicanal
    IF v_sale.payment_method IN ('efectivo', 'nequi', 'daviplata', 'bre') THEN
        SELECT id, opened_at INTO v_session_id, v_session_opened_at
        FROM public.cash_sessions
        WHERE store_id = v_sale.store_id AND status = 'open'
        ORDER BY opened_at DESC LIMIT 1;

        IF v_session_id IS NULL THEN
            RAISE EXCEPTION 'Para anular una venta de contado se requiere un turno de caja abierto (NO_OPEN_CASH_SESSION)' USING ERRCODE = 'P0001';
        END IF;

        IF v_sale.payment_method = 'efectivo' THEN
            SELECT COALESCE(opening_balance, 0) INTO v_opening
            FROM public.cash_sessions
            WHERE id = v_session_id;
        END IF;

        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
        FROM public.cash_movements
        WHERE session_id = v_session_id AND payment_method = v_sale.payment_method AND movement_type = 'ingreso';

        SELECT COALESCE(SUM(amount), 0) INTO v_egresos
        FROM public.cash_movements
        WHERE session_id = v_session_id AND payment_method = v_sale.payment_method AND movement_type = 'gasto';

        v_available := (v_opening + v_ingresos) - v_egresos;

        IF v_available < v_sale.total THEN
            RAISE EXCEPTION 'Fondos insuficientes en canal % para revertir la venta (disponible: %, requerido: %) (INSUFFICIENT_CHANNEL_FUNDS)',
                v_sale.payment_method, v_available, v_sale.total USING ERRCODE = 'P0001';
        END IF;

        INSERT INTO public.cash_movements (
            session_id, movement_type, amount, description, sale_id, payment_method, category, actor_id
        ) VALUES (
            v_session_id, 'gasto', v_sale.total, '[ANULACION_VENTA #' || v_sale.ticket_number || '] ' || p_reason, p_sale_id, v_sale.payment_method, 'anulacion_venta', v_employee_id
        );

    ELSIF v_sale.payment_method = 'fiado' AND v_sale.client_id IS NOT NULL THEN
        SELECT balance, COALESCE(is_deleted, false)
        INTO v_client_balance, v_client_deleted
        FROM public.clients
        WHERE id = v_sale.client_id
          AND store_id = v_sale.store_id
        FOR UPDATE;

        IF NOT FOUND OR v_client_deleted THEN
            RAISE EXCEPTION 'No es posible revertir deuda de un cliente archivado contablemente (CLIENT_NOT_FOUND)'
                USING ERRCODE = 'P0001';
        END IF;

        IF COALESCE(v_client_balance, 0) < v_sale.total THEN
            RAISE EXCEPTION 'La venta fiada ya fue abonada o saldada y no admite reversión negativa sobre el saldo ($% < $%) (CREDIT_REVERSAL_BLOCKED)',
                v_client_balance, v_sale.total USING ERRCODE = 'P0001';
        END IF;

        UPDATE public.clients
        SET balance = balance - v_sale.total, updated_at = NOW()
        WHERE id = v_sale.client_id;

        INSERT INTO public.client_ledger (
            client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by
        ) VALUES (
            v_sale.client_id, v_sale.store_id, -v_sale.total, v_client_balance, p_sale_id, 'anulacion_fiado', v_employee_id
        );
    END IF;

    -- 7. Reversión Logística
    FOR v_item IN SELECT * FROM public.sale_items WHERE sale_id = p_sale_id LOOP
        INSERT INTO public.inventory_movements (
            product_id, movement_type, quantity, reason, created_by
        ) VALUES (
            v_item.product_id,
            'CORRECCION_SISTEMA',
            v_item.quantity,
            'ANULACION VENTA #' || v_sale.ticket_number || ': ' || p_reason,
            v_employee_id
        );
    END LOOP;

    -- 8. Sellado Inmutable de la Venta
    UPDATE public.sales
    SET is_voided = true,
        void_reason = p_reason,
        voided_by = v_employee_id,
        void_session_id = v_session_id,
        voided_at = NOW()
    WHERE id = p_sale_id;

    -- 9. Registro de Auditoría
    INSERT INTO public.audit_logs (store_id, actor_id, event_type, resource_id, metadata, severity)
    VALUES (
        v_sale.store_id,
        v_employee_id,
        'SALE_VOIDED',
        p_sale_id::text,
        jsonb_build_object(
            'ticket_number', v_sale.ticket_number,
            'total', v_sale.total,
            'reason', p_reason,
            'payment_method', v_sale.payment_method
        ),
        'warning'
    );

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Venta anulada correctamente',
        'data', jsonb_build_object(
            'sale_id', p_sale_id,
            'ticket_number', v_sale.ticket_number,
            'is_voided', true,
            'void_session_id', v_session_id
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_anular_venta(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_anular_venta(uuid, text) TO authenticated, service_role;

-- 5.7 Corregir rol 'owner'|'manager' en rpc_force_sale y rpc_marcar_auditoria_revisada (G-7 / CONFLICTO-05)
CREATE OR REPLACE FUNCTION public.rpc_force_sale(
    p_store_id uuid,
    p_client_id uuid,
    p_payment_method text,
    p_items jsonb,
    p_justification text,
    p_amount_received numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_role text;
    v_item jsonb;
    v_product_id uuid;
    v_qty numeric;
    v_current_stock numeric;
    v_deficit numeric;
    v_sale_result jsonb;
    v_sale_id uuid;
    v_affected_count int := 0;
    v_grouped_items jsonb;
    v_employee_id uuid;
    v_data jsonb;
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    SELECT role INTO v_role
    FROM public.admin_profiles
    WHERE id = auth.uid() AND store_id = p_store_id;

    IF v_role IS NULL OR v_role NOT IN ('owner', 'manager') THEN
        RAISE EXCEPTION 'Access Denied: Se requiere rol de Administrador para forzar ventas (UNAUTHORIZED)' USING ERRCODE = '42501';
    END IF;

    IF length(trim(COALESCE(p_justification, ''))) < 10 THEN
        RAISE EXCEPTION 'La justificación forense debe tener al menos 10 caracteres legibles (JUSTIFICATION_TOO_SHORT)' USING ERRCODE = 'P0001';
    END IF;

    v_employee_id := public.get_employee_id_from_session();
    IF v_employee_id IS NULL THEN
        v_employee_id := auth.uid();
    END IF;

    SELECT jsonb_agg(jsonb_build_object('product_id', pid, 'quantity', qty)) INTO v_grouped_items
    FROM (
        SELECT (item->>'product_id')::uuid AS pid, SUM((item->>'quantity')::numeric) AS qty
        FROM jsonb_array_elements(p_items) AS item
        GROUP BY 1
    ) agg;

    FOR v_item IN SELECT * FROM jsonb_array_elements(v_grouped_items)
    LOOP
        v_product_id := (v_item->>'product_id')::uuid;
        v_qty := (v_item->>'quantity')::numeric;

        SELECT current_stock INTO v_current_stock
        FROM public.products
        WHERE id = v_product_id AND store_id = p_store_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto no encontrado: % (PRODUCT_NOT_FOUND)', v_product_id USING ERRCODE = 'P0001';
        END IF;

        v_deficit := v_qty - COALESCE(v_current_stock, 0);

        IF v_deficit > 0 THEN
            INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by)
            VALUES (v_product_id, 'CORRECCION_SISTEMA', v_deficit, 'AUTO-CORRECCION: ' || p_justification, v_employee_id);

            v_affected_count := v_affected_count + 1;
        END IF;
    END LOOP;

    v_sale_result := public.rpc_procesar_venta_v3(
        p_store_id,
        p_client_id,
        p_payment_method,
        p_amount_received,
        p_items,
        NULL,
        NULL
    );

    v_data := v_sale_result->'data';
    v_sale_id := (v_data->>'sale_id')::uuid;

    INSERT INTO public.audit_logs (store_id, actor_id, event_type, resource_id, metadata, severity)
    VALUES (
        p_store_id,
        v_employee_id,
        'FORCE_SALE',
        v_sale_id::text,
        jsonb_build_object(
            'reason', p_justification,
            'items_adjusted', v_affected_count,
            'original_items', p_items,
            'status', 'pending'
        ),
        'warning'
    );

    RETURN jsonb_build_object(
        'success', true,
        'sale_id', v_sale_id,
        'adjusted_items', v_affected_count,
        'data', jsonb_build_object(
            'sale_id', v_sale_id,
            'ticket_number', (v_data->>'ticket_number')::int,
            'total', (v_data->>'total')::numeric,
            'change_given', (v_data->>'change_given')::numeric,
            'payment_method', p_payment_method,
            'adjusted_items', v_affected_count,
            'audit_logged', true,
            'created_at', NOW()
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_force_sale(uuid, uuid, text, jsonb, text, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_force_sale(uuid, uuid, text, jsonb, text, numeric) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.rpc_marcar_auditoria_revisada(
    p_audit_id uuid,
    p_notes text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_store_id uuid;
    v_audit RECORD;
    v_role text;
BEGIN
    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED' USING ERRCODE = '42501';
    END IF;
    PERFORM public.assert_store_access(v_store_id);

    SELECT * INTO v_audit
    FROM public.audit_logs
    WHERE id = p_audit_id AND store_id = v_store_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Registro de auditoría no encontrado (AUDIT_NOT_FOUND)' USING ERRCODE = 'P0001';
    END IF;

    SELECT role INTO v_role
    FROM public.admin_profiles
    WHERE id = auth.uid() AND store_id = v_audit.store_id;

    IF v_role IS NULL OR v_role NOT IN ('owner', 'manager') THEN
        RAISE EXCEPTION 'Solo administradores pueden visar auditorías (UNAUTHORIZED)' USING ERRCODE = '42501';
    END IF;

    UPDATE public.audit_logs
    SET reviewed_by = auth.uid(),
        reviewed_at = NOW(),
        review_notes = p_notes,
        metadata = jsonb_set(COALESCE(metadata, '{}'::jsonb), '{status}', '"reviewed"')
    WHERE id = p_audit_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'audit_id', p_audit_id,
            'reviewed_at', NOW(),
            'reviewed_by', auth.uid()
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_marcar_auditoria_revisada(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_marcar_auditoria_revisada(uuid, text) TO authenticated, service_role;

COMMIT;

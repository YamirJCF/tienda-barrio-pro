-- ============================================================================
-- Migración: SDD-029 — Consentimiento Legal Versionado y Bloqueo de Vigencia
-- FRD Asociado: FRD-029 (POL-PRIV-01, POL-AUD-01, POL-AUD-02, POL-SEG-03)
-- SDD Asociado: SDD-029 v1.0.0 (D-LEG-01..D-LEG-07) + Coordinación SDD-030 (D-ARCO-03)
-- Fecha: 2026-11-11
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. DDL: Nuevas Tablas Inmutables (Append-Only)
-- ----------------------------------------------------------------------------

-- 1.1 Catálogo Versionado de Documentos Legales
CREATE TABLE IF NOT EXISTS public.legal_document_versions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_type text NOT NULL CHECK (document_type IN ('terms_of_service', 'privacy_policy')),
    version_code text NOT NULL CHECK (length(trim(version_code)) > 0),
    change_level text NOT NULL CHECK (change_level IN ('major', 'minor')),
    content text NOT NULL CHECK (length(trim(content)) > 0),
    change_summary text NOT NULL CHECK (length(trim(change_summary)) > 0),
    is_active boolean NOT NULL DEFAULT false,
    published_at timestamptz NOT NULL DEFAULT now(),
    published_by uuid REFERENCES auth.users(id),
    CONSTRAINT uq_legal_document_versions_type_code UNIQUE (document_type, version_code)
);

-- Garantiza máximo una versión activa vigente por tipo de documento
CREATE UNIQUE INDEX IF NOT EXISTS uq_legal_document_versions_single_active
    ON public.legal_document_versions (document_type)
    WHERE is_active = true;

-- 1.2 Registro Inmutable de Aceptaciones por Tienda (Append-Only)
CREATE TABLE IF NOT EXISTS public.store_legal_acceptances (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    accepted_by uuid NOT NULL REFERENCES auth.users(id),
    version_id uuid NOT NULL REFERENCES public.legal_document_versions(id) ON DELETE RESTRICT,
    document_type text NOT NULL CHECK (document_type IN ('terms_of_service', 'privacy_policy')),
    version_code text NOT NULL CHECK (length(trim(version_code)) > 0),
    accepted_at timestamptz NOT NULL DEFAULT now(),
    origin_channel text NOT NULL CHECK (length(trim(origin_channel)) > 0),
    ip_address text,
    user_agent text,
    CONSTRAINT uq_store_legal_acceptances_store_version UNIQUE (store_id, version_id)
);

CREATE INDEX IF NOT EXISTS idx_store_legal_acceptances_store_type
    ON public.store_legal_acceptances (store_id, document_type, accepted_at DESC);

-- 1.3 Bitácora Inmutable de Confirmación de Alta de Clientes Fiados (Append-Only)
-- Coordinación SDD-030 (D-ARCO-03):
--   - client_id NO lleva FK restrictiva hacia public.clients(id) para permitir HARD_DELETED (RN-04).
--   - Se admite cardinalidad 1:N por (store_id, client_id) para registrar cada re-alta silenciosa (RN-05).
CREATE TABLE IF NOT EXISTS public.client_registration_confirmations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    client_id uuid NOT NULL,
    created_by_user_id uuid NOT NULL,
    created_by_name text NOT NULL CHECK (length(trim(created_by_name)) > 0),
    confirmed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_client_registration_confirmations_store_client
    ON public.client_registration_confirmations (store_id, client_id, confirmed_at DESC);

-- ----------------------------------------------------------------------------
-- 2. Inmutabilidad Append-Only (Triggers BEFORE UPDATE / DELETE / TRUNCATE)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_enforce_legal_version_immutability()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'LEGAL_LOG_IMMUTABLE: Prohibido eliminar versiones legales históricas.'
            USING ERRCODE = '42501';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        -- Solo rpc_publicar_version_legal puede desactivar is_active (true -> false) sin alterar ningún campo histórico
        IF current_setting('app.allow_version_deactivation', true) = 'on'
           AND OLD.is_active = true
           AND NEW.is_active = false
           AND NEW.id = OLD.id
           AND NEW.document_type = OLD.document_type
           AND NEW.version_code = OLD.version_code
           AND NEW.change_level = OLD.change_level
           AND NEW.content = OLD.content
           AND NEW.change_summary = OLD.change_summary
           AND NEW.published_at = OLD.published_at
           AND NEW.published_by IS NOT DISTINCT FROM OLD.published_by THEN
            RETURN NEW;
        END IF;

        RAISE EXCEPTION 'LEGAL_LOG_IMMUTABLE: Las versiones legales publicadas son inmutables.'
            USING ERRCODE = '42501';
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_block_append_only_table_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
BEGIN
    RAISE EXCEPTION 'AUDIT_LOG_IMMUTABLE: Operación % prohibida sobre la bitácora inmutable %.', TG_OP, TG_TABLE_NAME
        USING ERRCODE = '42501';
END;
$$;

DROP TRIGGER IF EXISTS trg_legal_versions_immutable ON public.legal_document_versions;
CREATE TRIGGER trg_legal_versions_immutable
    BEFORE UPDATE OR DELETE ON public.legal_document_versions
    FOR EACH ROW EXECUTE FUNCTION public.fn_enforce_legal_version_immutability();

DROP TRIGGER IF EXISTS trg_legal_versions_no_truncate ON public.legal_document_versions;
CREATE TRIGGER trg_legal_versions_no_truncate
    BEFORE TRUNCATE ON public.legal_document_versions
    FOR EACH STATEMENT EXECUTE FUNCTION public.fn_block_append_only_table_mutation();

DROP TRIGGER IF EXISTS trg_store_legal_acceptances_immutable ON public.store_legal_acceptances;
CREATE TRIGGER trg_store_legal_acceptances_immutable
    BEFORE UPDATE OR DELETE ON public.store_legal_acceptances
    FOR EACH ROW EXECUTE FUNCTION public.fn_block_append_only_table_mutation();

DROP TRIGGER IF EXISTS trg_store_legal_acceptances_no_truncate ON public.store_legal_acceptances;
CREATE TRIGGER trg_store_legal_acceptances_no_truncate
    BEFORE TRUNCATE ON public.store_legal_acceptances
    FOR EACH STATEMENT EXECUTE FUNCTION public.fn_block_append_only_table_mutation();

DROP TRIGGER IF EXISTS trg_client_reg_confirmations_immutable ON public.client_registration_confirmations;
CREATE TRIGGER trg_client_reg_confirmations_immutable
    BEFORE UPDATE OR DELETE ON public.client_registration_confirmations
    FOR EACH ROW EXECUTE FUNCTION public.fn_block_append_only_table_mutation();

DROP TRIGGER IF EXISTS trg_client_reg_confirmations_no_truncate ON public.client_registration_confirmations;
CREATE TRIGGER trg_client_reg_confirmations_no_truncate
    BEFORE TRUNCATE ON public.client_registration_confirmations
    FOR EACH STATEMENT EXECUTE FUNCTION public.fn_block_append_only_table_mutation();

-- ----------------------------------------------------------------------------
-- 3. RLS y Privilegios Mínimos (Reglas 4 y 8 AGENTS.md)
-- ----------------------------------------------------------------------------

ALTER TABLE public.legal_document_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_legal_acceptances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_registration_confirmations ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.legal_document_versions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.legal_document_versions TO anon, authenticated;
GRANT ALL ON TABLE public.legal_document_versions TO service_role;

REVOKE ALL ON TABLE public.store_legal_acceptances FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.store_legal_acceptances TO authenticated;
GRANT ALL ON TABLE public.store_legal_acceptances TO service_role;

REVOKE ALL ON TABLE public.client_registration_confirmations FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.client_registration_confirmations TO authenticated;
GRANT ALL ON TABLE public.client_registration_confirmations TO service_role;

-- Políticas SELECT (cero políticas INSERT/UPDATE/DELETE para anon o authenticated)
DROP POLICY IF EXISTS "legal_versions_read_active_or_auth" ON public.legal_document_versions;
CREATE POLICY "legal_versions_read_active_or_auth"
    ON public.legal_document_versions
    FOR SELECT
    TO anon, authenticated
    USING (is_active = true OR auth.role() = 'authenticated');

DROP POLICY IF EXISTS "store_legal_acceptances_select_store" ON public.store_legal_acceptances;
CREATE POLICY "store_legal_acceptances_select_store"
    ON public.store_legal_acceptances
    FOR SELECT
    TO authenticated
    USING (store_id = public.get_current_store_id());

DROP POLICY IF EXISTS "client_reg_confirmations_select_store" ON public.client_registration_confirmations;
CREATE POLICY "client_reg_confirmations_select_store"
    ON public.client_registration_confirmations
    FOR SELECT
    TO authenticated
    USING (store_id = public.get_current_store_id());

-- ----------------------------------------------------------------------------
-- 4. Funciones y RPCs de SDD-029
-- ----------------------------------------------------------------------------

-- 4.1 Guardia exclusiva del Dueño de Plataforma (nunca lee employees.permissions->>'isSuperAdmin')
CREATE OR REPLACE FUNCTION public.assert_platform_owner()
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_is_super boolean := false;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'PLATFORM_OWNER_REQUIRED: Autenticación requerida para administrar documentos legales.'
            USING ERRCODE = '42501';
    END IF;

    SELECT (COALESCE(u.is_super_admin, false) AND COALESCE(u.is_anonymous, false) = false)
    INTO v_is_super
    FROM auth.users u
    WHERE u.id = v_uid;

    IF NOT COALESCE(v_is_super, false) THEN
        RAISE EXCEPTION 'PLATFORM_OWNER_REQUIRED: Solo el dueño de la plataforma puede ejecutar esta acción.'
            USING ERRCODE = '42501';
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.assert_platform_owner() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assert_platform_owner() TO authenticated, service_role;

-- 4.2 Consulta Pública Pre-Registro de Documentos Vigentes (RN-03)
CREATE OR REPLACE FUNCTION public.rpc_obtener_documentos_legales_vigentes()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_terms RECORD;
    v_privacy RECORD;
BEGIN
    SELECT id, document_type, version_code, change_level, content, change_summary, published_at
    INTO v_terms
    FROM public.legal_document_versions
    WHERE document_type = 'terms_of_service' AND is_active = true
    LIMIT 1;

    SELECT id, document_type, version_code, change_level, content, change_summary, published_at
    INTO v_privacy
    FROM public.legal_document_versions
    WHERE document_type = 'privacy_policy' AND is_active = true
    LIMIT 1;

    IF v_terms.id IS NULL OR v_privacy.id IS NULL THEN
        RAISE EXCEPTION 'MISSING_ACTIVE_LEGAL_DOCUMENTS: No existen versiones activas vigentes para Términos y Política de Datos.'
            USING ERRCODE = 'P0001';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'terms_of_service', jsonb_build_object(
                'version_id', v_terms.id,
                'document_type', v_terms.document_type,
                'version_code', v_terms.version_code,
                'change_level', v_terms.change_level,
                'content', v_terms.content,
                'change_summary', v_terms.change_summary,
                'published_at', v_terms.published_at
            ),
            'privacy_policy', jsonb_build_object(
                'version_id', v_privacy.id,
                'document_type', v_privacy.document_type,
                'version_code', v_privacy.version_code,
                'change_level', v_privacy.change_level,
                'content', v_privacy.content,
                'change_summary', v_privacy.change_summary,
                'published_at', v_privacy.published_at
            )
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_obtener_documentos_legales_vigentes() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_obtener_documentos_legales_vigentes() TO anon, authenticated, service_role;

-- 4.3 Publicación Exclusiva de Plataforma (Caso B, RN-07 a RN-09)
CREATE OR REPLACE FUNCTION public.rpc_publicar_version_legal(
    p_document_type text,
    p_version_code text,
    p_change_level text,
    p_content text,
    p_change_summary text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
    v_doc_type text := trim(COALESCE(p_document_type, ''));
    v_version_code text := trim(COALESCE(p_version_code, ''));
    v_change_level text := trim(COALESCE(p_change_level, ''));
    v_content text := trim(COALESCE(p_content, ''));
    v_summary text := trim(COALESCE(p_change_summary, ''));
    v_inserted public.legal_document_versions%ROWTYPE;
BEGIN
    PERFORM public.assert_platform_owner();

    IF v_doc_type NOT IN ('terms_of_service', 'privacy_policy') THEN
        RAISE EXCEPTION 'INVALID_DOCUMENT_TYPE: Tipo de documento legal inválido (%).', v_doc_type
            USING ERRCODE = '22023';
    END IF;

    IF v_change_level NOT IN ('major', 'minor') THEN
        RAISE EXCEPTION 'INVALID_CHANGE_LEVEL: Nivel de cambio inválido (%).', v_change_level
            USING ERRCODE = '22023';
    END IF;

    IF v_version_code = '' OR v_content = '' OR v_summary = '' THEN
        RAISE EXCEPTION 'EMPTY_LEGAL_CONTENT: Código de versión, contenido y resumen son obligatorios.'
            USING ERRCODE = '22023';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext('legal_document_versions:' || v_doc_type));

    PERFORM set_config('app.allow_version_deactivation', 'on', true);
    UPDATE public.legal_document_versions
    SET is_active = false
    WHERE document_type = v_doc_type
      AND is_active = true;
    PERFORM set_config('app.allow_version_deactivation', 'off', true);

    BEGIN
        INSERT INTO public.legal_document_versions (
            document_type,
            version_code,
            change_level,
            content,
            change_summary,
            is_active,
            published_by
        ) VALUES (
            v_doc_type,
            v_version_code,
            v_change_level,
            v_content,
            v_summary,
            true,
            auth.uid()
        )
        RETURNING * INTO v_inserted;
    EXCEPTION
        WHEN unique_violation THEN
            RAISE EXCEPTION 'DUPLICATE_VERSION_CODE: Ya existe la versión % para %.', v_version_code, v_doc_type
                USING ERRCODE = '23505';
    END;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'version_id', v_inserted.id,
            'document_type', v_inserted.document_type,
            'version_code', v_inserted.version_code,
            'change_level', v_inserted.change_level,
            'is_active', v_inserted.is_active,
            'published_at', v_inserted.published_at
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_publicar_version_legal(text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_publicar_version_legal(text, text, text, text, text) TO authenticated, service_role;

-- 4.4 Verificación de Estado Legal de Tienda al Iniciar Sesión (RN-10 a RN-13)
CREATE OR REPLACE FUNCTION public.rpc_verificar_estado_legal_tienda(
    p_store_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_has_open_cash boolean := false;
    v_pending_major jsonb := '[]'::jsonb;
    v_pending_minor jsonb := '[]'::jsonb;
    v_compliance_status text := 'up_to_date';
    v_doc_type text;
    v_active RECORD;
    v_has_accepted_active boolean;
    v_has_unaccepted_major boolean;
    v_item jsonb;
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    SELECT EXISTS (
        SELECT 1
        FROM public.cash_sessions cs
        WHERE cs.store_id = p_store_id
          AND cs.status = 'open'
    ) INTO v_has_open_cash;

    FOREACH v_doc_type IN ARRAY ARRAY['terms_of_service', 'privacy_policy'] LOOP
        SELECT id, document_type, version_code, change_level, change_summary, content, published_at
        INTO v_active
        FROM public.legal_document_versions
        WHERE document_type = v_doc_type AND is_active = true
        LIMIT 1;

        IF v_active.id IS NULL THEN
            CONTINUE;
        END IF;

        SELECT EXISTS (
            SELECT 1
            FROM public.store_legal_acceptances sla
            WHERE sla.store_id = p_store_id
              AND sla.version_id = v_active.id
        ) INTO v_has_accepted_active;

        IF v_has_accepted_active THEN
            CONTINUE;
        END IF;

        v_item := jsonb_build_object(
            'version_id', v_active.id,
            'document_type', v_active.document_type,
            'version_code', v_active.version_code,
            'change_level', v_active.change_level,
            'change_summary', v_active.change_summary,
            'content', v_active.content,
            'published_at', v_active.published_at
        );

        -- Bloqueante si la versión vigente es major o si existe una versión major intermedia aún no aceptada (RN-10 / RN-13)
        SELECT EXISTS (
            SELECT 1
            FROM public.legal_document_versions ldv
            WHERE ldv.document_type = v_doc_type
              AND ldv.change_level = 'major'
              AND NOT EXISTS (
                  SELECT 1
                  FROM public.store_legal_acceptances sla
                  WHERE sla.store_id = p_store_id
                    AND sla.document_type = v_doc_type
                    AND sla.accepted_at >= ldv.published_at
              )
        ) INTO v_has_unaccepted_major;

        IF v_active.change_level = 'major' OR v_has_unaccepted_major THEN
            v_pending_major := v_pending_major || jsonb_build_array(v_item);
        ELSE
            v_pending_minor := v_pending_minor || jsonb_build_array(v_item);
        END IF;
    END LOOP;

    IF jsonb_array_length(v_pending_major) > 0 THEN
        v_compliance_status := 'requires_major_acceptance';
    ELSIF jsonb_array_length(v_pending_minor) > 0 THEN
        v_compliance_status := 'minor_notice_available';
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'store_id', p_store_id,
            'compliance_status', v_compliance_status,
            'has_open_cash_session', v_has_open_cash,
            'pending_major_documents', v_pending_major,
            'pending_minor_notices', v_pending_minor,
            'support_channel', jsonb_build_object(
                'contact', 'soporte@tiendabarriopro.co',
                'message', 'Canal oficial de atención para consultas legales o solicitud de cierre de cuenta (RN-12)'
            ),
            'checked_at', now()
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_verificar_estado_legal_tienda(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_verificar_estado_legal_tienda(uuid) TO authenticated, service_role;

-- 4.5 Aceptación de Versiones Legales en Sesión por Administrador (Casos C/D, RN-10 a RN-13)
CREATE OR REPLACE FUNCTION public.rpc_aceptar_version_legal_tienda(
    p_store_id uuid,
    p_version_ids uuid[],
    p_origin_channel text DEFAULT 'web_login_gate'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_role text;
    v_ver_id uuid;
    v_ver RECORD;
    v_origin text := COALESCE(NULLIF(trim(p_origin_channel), ''), 'web_login_gate');
    v_ip text;
    v_user_agent text;
    v_acc_id uuid;
    v_acceptance_ids uuid[] := ARRAY[]::uuid[];
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    SELECT role INTO v_role
    FROM public.admin_profiles
    WHERE id = auth.uid() AND store_id = p_store_id;

    IF v_role IS NULL OR v_role NOT IN ('owner', 'manager') THEN
        RAISE EXCEPTION 'UNAUTHORIZED: Solo administradores de la tienda pueden aceptar versiones legales.'
            USING ERRCODE = '42501';
    END IF;

    IF p_version_ids IS NULL OR COALESCE(array_length(p_version_ids, 1), 0) = 0 THEN
        RAISE EXCEPTION 'EMPTY_VERSION_LIST: Debe especificar al menos una versión legal vigente.'
            USING ERRCODE = '22023';
    END IF;

    BEGIN
        v_ip := NULLIF(trim(current_setting('request.headers', true)::json->>'x-forwarded-for'), '');
        v_user_agent := NULLIF(trim(current_setting('request.headers', true)::json->>'user-agent'), '');
    EXCEPTION WHEN OTHERS THEN
        v_ip := NULL;
        v_user_agent := NULL;
    END;

    FOREACH v_ver_id IN ARRAY p_version_ids LOOP
        SELECT id, document_type, version_code, is_active
        INTO v_ver
        FROM public.legal_document_versions
        WHERE id = v_ver_id
        FOR SHARE;

        IF NOT FOUND OR v_ver.is_active IS NOT TRUE THEN
            RAISE EXCEPTION 'LEGAL_VERSION_SUPERSEDED: La versión legal % ya no se encuentra vigente.', v_ver_id
                USING ERRCODE = 'P0001';
        END IF;

        INSERT INTO public.store_legal_acceptances (
            store_id,
            accepted_by,
            version_id,
            document_type,
            version_code,
            origin_channel,
            ip_address,
            user_agent
        ) VALUES (
            p_store_id,
            auth.uid(),
            v_ver.id,
            v_ver.document_type,
            v_ver.version_code,
            v_origin,
            v_ip,
            v_user_agent
        )
        ON CONFLICT (store_id, version_id) DO NOTHING
        RETURNING id INTO v_acc_id;

        IF v_acc_id IS NULL THEN
            SELECT id INTO v_acc_id
            FROM public.store_legal_acceptances
            WHERE store_id = p_store_id AND version_id = v_ver.id;
        END IF;

        v_acceptance_ids := array_append(v_acceptance_ids, v_acc_id);
    END LOOP;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'store_id', p_store_id,
            'acceptance_ids', to_jsonb(v_acceptance_ids),
            'accepted_at', now()
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_aceptar_version_legal_tienda(uuid, uuid[], text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rpc_aceptar_version_legal_tienda(uuid, uuid[], text) TO authenticated, service_role;

-- 4.6 Endurecimiento de search_path en rpc_verificar_estado_sesion (D-LEG-06)
ALTER FUNCTION public.rpc_verificar_estado_sesion() SET search_path TO 'public';

-- 4.7 Trigger Atómico de Registro con Validación Estricta y Rollback Total (D-LEG-02 / D-LEG-03 / D-LEG-04)
CREATE OR REPLACE FUNCTION public.handle_new_user_atomic()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
    v_store_name text;
    v_slug text;
    v_base_slug text;
    v_counter int := 1;
    v_new_store_id uuid;
    v_terms_version_id uuid;
    v_privacy_version_id uuid;
    v_terms_rec RECORD;
    v_privacy_rec RECORD;
    v_origin text;
    v_user_agent text;
BEGIN
    -- Omitir autocreación de tienda para: cajeros anónimos, Dueño de Plataforma SaaS o miembros internos aprovisionados por servidor
    IF COALESCE(new.is_anonymous, false) IS TRUE
       OR COALESCE(new.is_super_admin, false) IS TRUE
       OR COALESCE(new.raw_app_meta_data->>'account_kind', '') IN ('platform_owner', 'store_member') THEN
        RETURN new;
    END IF;

    BEGIN
        v_terms_version_id := NULLIF(trim(new.raw_user_meta_data->>'accepted_terms_version_id'), '')::uuid;
        v_privacy_version_id := NULLIF(trim(new.raw_user_meta_data->>'accepted_privacy_version_id'), '')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'LEGAL_ACCEPTANCE_REQUIRED: Identificadores de versión legal inválidos.'
            USING ERRCODE = '22023';
    END;

    IF v_terms_version_id IS NULL OR v_privacy_version_id IS NULL THEN
        RAISE EXCEPTION 'LEGAL_ACCEPTANCE_REQUIRED: Se requiere aceptación explícita de Términos y Política vigentes.'
            USING ERRCODE = 'P0001';
    END IF;

    SELECT id, document_type, version_code INTO v_terms_rec
    FROM public.legal_document_versions
    WHERE id = v_terms_version_id
      AND document_type = 'terms_of_service'
      AND is_active = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'LEGAL_VERSION_SUPERSEDED: La versión de Términos y Condiciones (%) no está vigente.', v_terms_version_id
            USING ERRCODE = 'P0001';
    END IF;

    SELECT id, document_type, version_code INTO v_privacy_rec
    FROM public.legal_document_versions
    WHERE id = v_privacy_version_id
      AND document_type = 'privacy_policy'
      AND is_active = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'LEGAL_VERSION_SUPERSEDED: La versión de Política de Tratamiento (%) no está vigente.', v_privacy_version_id
            USING ERRCODE = 'P0001';
    END IF;

    v_store_name := COALESCE(NULLIF(trim(new.raw_user_meta_data->>'store_name'), ''), 'Tienda Principal');
    v_store_name := LEFT(v_store_name, 50);

    v_base_slug := lower(regexp_replace(v_store_name, '[^a-zA-Z0-9]+', '-', 'g'));
    v_base_slug := trim(both '-' from v_base_slug);
    IF v_base_slug = '' THEN
        v_base_slug := 'tienda-' || left(new.id::text, 8);
    END IF;

    v_slug := v_base_slug;
    WHILE EXISTS (SELECT 1 FROM public.stores WHERE slug = v_slug) LOOP
        v_slug := v_base_slug || '-' || v_counter;
        v_counter := v_counter + 1;
    END LOOP;

    INSERT INTO public.stores (name, slug)
    VALUES (v_store_name, v_slug)
    RETURNING id INTO v_new_store_id;

    INSERT INTO public.admin_profiles (id, store_id, role, is_verified)
    VALUES (new.id, v_new_store_id, 'owner', false);

    -- Limpieza D-LEG-02: nunca asignar 'isSuperAdmin': true en employees.permissions de tienda
    INSERT INTO public.employees (
        id, store_id, name, username, pin_hash, permissions, is_active, created_at, updated_at
    ) VALUES (
        new.id,
        v_new_store_id,
        COALESCE(NULLIF(trim(new.raw_user_meta_data->>'owner_name'), ''), 'Propietario'),
        'owner_' || left(new.id::text, 8),
        '$2a$10$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        jsonb_build_object(
            'canSell', true,
            'canFiar', true,
            'canViewInventory', true,
            'canViewReports', true,
            'canOpenCloseCash', true,
            'canManageInventory', true,
            'canManageClients', true
        ),
        true,
        NOW(),
        NOW()
    );

    v_origin := COALESCE(NULLIF(trim(new.raw_user_meta_data->>'origin_channel'), ''), 'web_register');
    v_user_agent := NULLIF(trim(new.raw_user_meta_data->>'client_user_agent'), '');

    INSERT INTO public.store_legal_acceptances (
        store_id, accepted_by, version_id, document_type, version_code, origin_channel, ip_address, user_agent
    ) VALUES
        (v_new_store_id, new.id, v_terms_rec.id, v_terms_rec.document_type, v_terms_rec.version_code, v_origin, NULL, v_user_agent),
        (v_new_store_id, new.id, v_privacy_rec.id, v_privacy_rec.document_type, v_privacy_rec.version_code, v_origin, NULL, v_user_agent);

    RETURN new;
EXCEPTION WHEN OTHERS THEN
    -- Regla 3: prohibido silenciar fallos en alta de usuario; relanza para rollback atómico completo
    RAISE;
END;
$$;

COMMIT;

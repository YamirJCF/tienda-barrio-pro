-- ==============================================================================
-- MIGRACIÓN FASE 3 — OLA 1: CIMIENTOS TRANSVERSALES (CHK-101 a CHK-109)
-- Contrato Marco: SDD-003-01 (ARQ-002 v1.4)
-- Cubre: SDD-003-01, SDD-001, SDD-003, SDD-015 + Canales + Snapshots Inmutables
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- [CHK-108] Columnas de Snapshot Histórico Inmutable en BD + Backfill + GRANT ALL
-- ------------------------------------------------------------------------------
ALTER TABLE public.audit_logs
    ALTER COLUMN actor_id DROP NOT NULL;

ALTER TABLE public.sales
    ALTER COLUMN employee_id DROP NOT NULL;

ALTER TABLE public.sales
    ADD COLUMN IF NOT EXISTS actor_name TEXT,
    ADD COLUMN IF NOT EXISTS actor_role TEXT,
    ADD COLUMN IF NOT EXISTS voided_by_name TEXT,
    ADD COLUMN IF NOT EXISTS voided_by_role TEXT;

ALTER TABLE public.cash_sessions
    ADD COLUMN IF NOT EXISTS opened_by_name TEXT,
    ADD COLUMN IF NOT EXISTS opened_by_role TEXT,
    ADD COLUMN IF NOT EXISTS closed_by_name TEXT,
    ADD COLUMN IF NOT EXISTS closed_by_role TEXT;

ALTER TABLE public.cash_movements
    ADD COLUMN IF NOT EXISTS actor_name TEXT,
    ADD COLUMN IF NOT EXISTS actor_role TEXT;

ALTER TABLE public.inventory_movements
    ADD COLUMN IF NOT EXISTS actor_name TEXT,
    ADD COLUMN IF NOT EXISTS actor_role TEXT;

ALTER TABLE public.client_ledger
    ADD COLUMN IF NOT EXISTS actor_name TEXT,
    ADD COLUMN IF NOT EXISTS actor_role TEXT;

ALTER TABLE public.audit_logs
    ADD COLUMN IF NOT EXISTS actor_name TEXT,
    ADD COLUMN IF NOT EXISTS actor_role TEXT;

ALTER TABLE public.audit_caja
    ADD COLUMN IF NOT EXISTS actor_name TEXT,
    ADD COLUMN IF NOT EXISTS actor_role TEXT;

ALTER TABLE public.audit_ventas
    ADD COLUMN IF NOT EXISTS actor_name TEXT,
    ADD COLUMN IF NOT EXISTS actor_role TEXT;

ALTER TABLE public.audit_precios
    ADD COLUMN IF NOT EXISTS actor_name TEXT,
    ADD COLUMN IF NOT EXISTS actor_role TEXT;

ALTER TABLE public.audit_seguridad
    ADD COLUMN IF NOT EXISTS actor_name TEXT,
    ADD COLUMN IF NOT EXISTS actor_role TEXT;

-- Backfill seguro de filas existentes
UPDATE public.sales s
SET actor_name = COALESCE(
        s.actor_name,
        (SELECT e.name FROM public.employees e WHERE e.id = s.employee_id LIMIT 1),
        'Administrador'
    ),
    actor_role = COALESCE(
        s.actor_role,
        (SELECT ap.role FROM public.admin_profiles ap WHERE ap.id = s.employee_id AND ap.store_id = s.store_id LIMIT 1),
        CASE WHEN EXISTS (SELECT 1 FROM public.employees e WHERE e.id = s.employee_id) THEN 'employee' ELSE 'owner' END
    ),
    voided_by_name = CASE
        WHEN s.is_voided OR s.voided_by IS NOT NULL THEN COALESCE(
            s.voided_by_name,
            (SELECT ev.name FROM public.employees ev WHERE ev.id = s.voided_by LIMIT 1),
            'Administrador'
        )
        ELSE s.voided_by_name
    END,
    voided_by_role = CASE
        WHEN s.is_voided OR s.voided_by IS NOT NULL THEN COALESCE(
            s.voided_by_role,
            (SELECT apv.role FROM public.admin_profiles apv WHERE apv.id = s.voided_by AND apv.store_id = s.store_id LIMIT 1),
            CASE WHEN EXISTS (SELECT 1 FROM public.employees ev WHERE ev.id = s.voided_by) THEN 'employee' ELSE 'owner' END
        )
        ELSE s.voided_by_role
    END
WHERE s.actor_name IS NULL
   OR s.actor_role IS NULL
   OR ((s.is_voided OR s.voided_by IS NOT NULL) AND (s.voided_by_name IS NULL OR s.voided_by_role IS NULL));

UPDATE public.cash_sessions cs
SET opened_by_name = COALESCE(
        cs.opened_by_name,
        (SELECT e.name FROM public.employees e WHERE e.id = cs.opened_by LIMIT 1),
        'Administrador'
    ),
    opened_by_role = COALESCE(
        cs.opened_by_role,
        (SELECT ap.role FROM public.admin_profiles ap WHERE ap.id = cs.opened_by AND ap.store_id = cs.store_id LIMIT 1),
        CASE WHEN EXISTS (SELECT 1 FROM public.employees e WHERE e.id = cs.opened_by) THEN 'employee' ELSE 'owner' END
    ),
    closed_by_name = CASE
        WHEN cs.closed_by IS NOT NULL OR cs.status = 'closed' THEN COALESCE(
            cs.closed_by_name,
            (SELECT ec.name FROM public.employees ec WHERE ec.id = cs.closed_by LIMIT 1),
            'Administrador'
        )
        ELSE cs.closed_by_name
    END,
    closed_by_role = CASE
        WHEN cs.closed_by IS NOT NULL OR cs.status = 'closed' THEN COALESCE(
            cs.closed_by_role,
            (SELECT apc.role FROM public.admin_profiles apc WHERE apc.id = cs.closed_by AND apc.store_id = cs.store_id LIMIT 1),
            CASE WHEN EXISTS (SELECT 1 FROM public.employees ec WHERE ec.id = cs.closed_by) THEN 'employee' ELSE 'owner' END
        )
        ELSE cs.closed_by_role
    END
WHERE cs.opened_by_name IS NULL
   OR cs.opened_by_role IS NULL
   OR ((cs.closed_by IS NOT NULL OR cs.status = 'closed') AND (cs.closed_by_name IS NULL OR cs.closed_by_role IS NULL));

UPDATE public.cash_movements cm
SET actor_name = COALESCE(
        cm.actor_name,
        (SELECT e.name FROM public.employees e WHERE e.id = cm.actor_id LIMIT 1),
        (SELECT public._resolve_store_actor_name(cs.store_id, cm.actor_id)
         FROM public.cash_sessions cs
         WHERE cs.id = cm.session_id
         LIMIT 1),
        'Administrador'
    ),
    actor_role = COALESCE(
        (
            SELECT ap.role
            FROM public.cash_sessions cs
            JOIN public.admin_profiles ap ON ap.id = cm.actor_id AND ap.store_id = cs.store_id
            WHERE cs.id = cm.session_id
            LIMIT 1
        ),
        CASE WHEN EXISTS (SELECT 1 FROM public.employees e WHERE e.id = cm.actor_id) THEN 'employee' ELSE 'owner' END
    )
WHERE cm.actor_name IS NULL OR cm.actor_role IS NULL OR cm.actor_id IS NOT NULL;

UPDATE public.inventory_movements im
SET actor_name = COALESCE(
        im.actor_name,
        (SELECT e.name FROM public.employees e WHERE e.id = im.created_by LIMIT 1),
        (SELECT public._resolve_store_actor_name(p.store_id, im.created_by)
         FROM public.products p
         WHERE p.id = im.product_id
         LIMIT 1),
        'Administrador'
    ),
    actor_role = COALESCE(
        (
            SELECT ap.role
            FROM public.products p
            JOIN public.admin_profiles ap ON ap.id = im.created_by AND ap.store_id = p.store_id
            WHERE p.id = im.product_id
            LIMIT 1
        ),
        CASE WHEN EXISTS (SELECT 1 FROM public.employees e WHERE e.id = im.created_by) THEN 'employee' ELSE 'owner' END
    )
WHERE im.actor_name IS NULL OR im.actor_role IS NULL OR im.created_by IS NOT NULL;

UPDATE public.client_ledger cl
SET actor_name = COALESCE(
        cl.actor_name,
        (SELECT e.name FROM public.employees e WHERE e.id = cl.created_by LIMIT 1),
        'Administrador'
    ),
    actor_role = COALESCE(
        cl.actor_role,
        (SELECT ap.role FROM public.admin_profiles ap WHERE ap.id = cl.created_by AND ap.store_id = cl.store_id LIMIT 1),
        CASE WHEN EXISTS (SELECT 1 FROM public.employees e WHERE e.id = cl.created_by) THEN 'employee' ELSE 'owner' END
    )
WHERE cl.actor_name IS NULL OR cl.actor_role IS NULL;

UPDATE public.audit_logs al
SET actor_name = COALESCE(
        al.actor_name,
        (SELECT e.name FROM public.employees e WHERE e.id = al.actor_id LIMIT 1),
        'Sistema'
    ),
    actor_role = COALESCE(
        al.actor_role,
        (SELECT ap.role FROM public.admin_profiles ap WHERE ap.id = al.actor_id AND ap.store_id = al.store_id LIMIT 1),
        CASE WHEN EXISTS (SELECT 1 FROM public.employees e WHERE e.id = al.actor_id) THEN 'employee' ELSE 'owner' END
    )
WHERE al.actor_name IS NULL OR al.actor_role IS NULL;

UPDATE public.audit_caja ac
SET actor_name = COALESCE(
        ac.actor_name,
        (SELECT e.name FROM public.employees e WHERE e.id = ac.actor_id LIMIT 1),
        'Administrador'
    ),
    actor_role = COALESCE(
        ac.actor_role,
        (SELECT ap.role FROM public.admin_profiles ap WHERE ap.id = ac.actor_id AND ap.store_id = ac.store_id LIMIT 1),
        CASE WHEN EXISTS (SELECT 1 FROM public.employees e WHERE e.id = ac.actor_id) THEN 'employee' ELSE 'owner' END
    )
WHERE ac.actor_name IS NULL OR ac.actor_role IS NULL;

UPDATE public.audit_ventas av
SET actor_name = COALESCE(
        av.actor_name,
        (SELECT e.name FROM public.employees e WHERE e.id = av.actor_id LIMIT 1),
        'Administrador'
    ),
    actor_role = COALESCE(
        av.actor_role,
        (SELECT ap.role FROM public.admin_profiles ap WHERE ap.id = av.actor_id AND ap.store_id = av.store_id LIMIT 1),
        CASE WHEN EXISTS (SELECT 1 FROM public.employees e WHERE e.id = av.actor_id) THEN 'employee' ELSE 'owner' END
    )
WHERE av.actor_name IS NULL OR av.actor_role IS NULL;

UPDATE public.audit_precios apc
SET actor_name = COALESCE(
        apc.actor_name,
        (SELECT e.name FROM public.employees e WHERE e.id = apc.changed_by LIMIT 1),
        'Administrador'
    ),
    actor_role = COALESCE(
        apc.actor_role,
        (SELECT ap.role FROM public.admin_profiles ap WHERE ap.id = apc.changed_by AND ap.store_id = apc.store_id LIMIT 1),
        CASE WHEN EXISTS (SELECT 1 FROM public.employees e WHERE e.id = apc.changed_by) THEN 'employee' ELSE 'owner' END
    )
WHERE apc.actor_name IS NULL OR apc.actor_role IS NULL;

UPDATE public.audit_seguridad aseg
SET actor_name = COALESCE(
        aseg.actor_name,
        (SELECT e.name FROM public.employees e WHERE e.id = aseg.actor_id LIMIT 1),
        'Administrador'
    ),
    actor_role = COALESCE(
        aseg.actor_role,
        (SELECT ap.role FROM public.admin_profiles ap WHERE ap.id = aseg.actor_id AND ap.store_id = aseg.store_id LIMIT 1),
        CASE WHEN EXISTS (SELECT 1 FROM public.employees e WHERE e.id = aseg.actor_id) THEN 'employee' ELSE 'owner' END
    )
WHERE aseg.actor_name IS NULL OR aseg.actor_role IS NULL;

GRANT ALL ON TABLE public.sales TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.cash_sessions TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.cash_movements TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.inventory_movements TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.client_ledger TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.audit_logs TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.audit_caja TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.audit_ventas TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.audit_precios TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.audit_seguridad TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.employees TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.daily_passes TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.payment_methods TO anon, authenticated, service_role;

-- ------------------------------------------------------------------------------
-- [CHK-103] Helper resolve_actor_snapshot(p_store_id UUID)
-- Retorna (actor_id UUID, actor_name TEXT, actor_role TEXT)
-- Roles canónicos: 'owner' | 'manager' | 'employee'
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resolve_actor_snapshot(p_store_id UUID)
RETURNS TABLE(actor_id UUID, actor_name TEXT, actor_role TEXT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_admin_role TEXT;
    v_emp_id UUID;
    v_emp_name TEXT;
    v_resolved_name TEXT;
BEGIN
    -- 1. Verificar si el actor autenticado pertenece a admin_profiles ('owner' o 'manager') en la tienda
    IF v_uid IS NOT NULL THEN
        SELECT ap.role INTO v_admin_role
        FROM public.admin_profiles ap
        WHERE ap.id = v_uid
          AND ap.store_id = p_store_id
          AND ap.role IN ('owner', 'manager')
        LIMIT 1;

        IF v_admin_role IS NOT NULL THEN
            v_resolved_name := public._resolve_store_actor_name(p_store_id, v_uid);
            RETURN QUERY SELECT v_uid, COALESCE(NULLIF(TRIM(v_resolved_name), ''), 'Administrador'), v_admin_role;
            RETURN;
        END IF;
    END IF;

    -- 2. Verificar si es empleado activo vía sesión JWT o pase diario vigente (<24h)
    v_emp_id := public.get_employee_id_from_session();
    IF v_emp_id IS NOT NULL THEN
        SELECT e.name INTO v_emp_name
        FROM public.employees e
        WHERE e.id = v_emp_id
          AND e.store_id = p_store_id
        LIMIT 1;

        IF v_emp_name IS NOT NULL THEN
            RETURN QUERY SELECT v_emp_id, v_emp_name, 'employee'::TEXT;
            RETURN;
        END IF;
    END IF;

    -- 3. Fallback directo por auth.uid() en employees si corresponde a la tienda
    IF v_uid IS NOT NULL THEN
        SELECT e.id, e.name INTO v_emp_id, v_emp_name
        FROM public.employees e
        WHERE e.id = v_uid
          AND e.store_id = p_store_id
        LIMIT 1;

        IF v_emp_id IS NOT NULL THEN
            RETURN QUERY SELECT v_emp_id, v_emp_name, 'employee'::TEXT;
            RETURN;
        END IF;
    END IF;

    -- 4. Fallback neutral cuando el invocador no tiene perfil registrado en la tienda
    RETURN QUERY SELECT
        v_uid,
        COALESCE(
            (SELECT NULLIF(TRIM(u.raw_user_meta_data->>'full_name'), '') FROM auth.users u WHERE u.id = v_uid),
            (SELECT NULLIF(split_part(u.email, '@', 1), '') FROM auth.users u WHERE u.id = v_uid),
            'Sistema'::TEXT
        ),
        'employee'::TEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.resolve_actor_snapshot(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.resolve_actor_snapshot(UUID) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- [CHK-101] Funciones Centralizadas de Autoridad Admin: is_store_admin / assert_store_admin
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_store_admin(p_store_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
    IF p_store_id IS NULL OR auth.uid() IS NULL THEN
        RETURN false;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.admin_profiles ap
        WHERE ap.id = auth.uid()
          AND ap.store_id = p_store_id
          AND ap.role IN ('owner', 'manager')
    );
END;
$$;

REVOKE ALL ON FUNCTION public.is_store_admin(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_store_admin(UUID) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.assert_store_admin(p_store_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    IF public.is_store_admin(p_store_id) THEN
        RETURN;
    END IF;

    -- Aborta atómicamente (SQLSTATE 42501); la auditoría persistente del intento denegado se asienta en transacción dedicada vía rpc_log_security_event
    RAISE EXCEPTION 'ADMIN_ONLY_ACTION: Esta acción es exclusiva del Administrador.'
        USING ERRCODE = '42501';
END;
$$;

REVOKE ALL ON FUNCTION public.assert_store_admin(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assert_store_admin(UUID) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- [CHK-102] Función Centralizada assert_employee_permission(p_store_id, p_permission_key)
-- Únicas 4 llaves válidas: canManageInventory, canFiar, canOpenCloseCash, canManageRefunds
-- Zero-Trust: Todo empleado (aun con auth.uid() = employees.id) requiere pase diario aprobado <24h
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assert_employee_permission(
    p_store_id UUID,
    p_permission_key TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_emp_id UUID;
    v_emp RECORD;
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
    v_has_valid_pass BOOLEAN := false;
    v_allowed BOOLEAN := false;
BEGIN
    -- 1. Validar aislamiento multi-tenant
    PERFORM public.assert_store_access(p_store_id);

    -- 2. Validar esquema cerrado de 4 llaves canónicas (rechaza legacy como 'canViewReports')
    IF p_permission_key IS NULL OR p_permission_key NOT IN (
        'canManageInventory',
        'canFiar',
        'canOpenCloseCash',
        'canManageRefunds'
    ) THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: Permiso no reconocido o fuera del esquema cerrado (%).', COALESCE(p_permission_key, 'NULL')
            USING ERRCODE = '42501';
    END IF;

    -- 3. Administrador (owner/manager) siempre autorizado sin requerir fila en employees
    IF public.is_store_admin(p_store_id) THEN
        RETURN;
    END IF;

    -- 4. Resolver identidad operativa del empleado y exigir pase diario vigente (<24h)
    v_emp_id := public.get_employee_id_from_session();
    IF v_emp_id IS NOT NULL THEN
        SELECT id, store_id, name, is_active, permissions
        INTO v_emp
        FROM public.employees
        WHERE id = v_emp_id
          AND store_id = p_store_id;
    END IF;

    IF v_emp.id IS NOT NULL AND v_emp.is_active IS TRUE THEN
        SELECT EXISTS (
            SELECT 1 FROM public.daily_passes dp
            WHERE dp.employee_id = v_emp.id
              AND dp.store_id = p_store_id
              AND dp.status = 'approved'
              AND (
                  dp.pass_date = v_today
                  OR (
                      dp.pass_date = v_today - 1
                      AND EXISTS (
                          SELECT 1 FROM public.cash_sessions cs
                          WHERE cs.store_id = p_store_id
                            AND cs.status = 'open'
                            AND cs.opened_at >= (now() - interval '24 hours')
                      )
                  )
              )
        ) INTO v_has_valid_pass;

        v_allowed := COALESCE((v_emp.permissions ->> p_permission_key)::BOOLEAN, false);
    END IF;

    IF v_emp.id IS NULL OR v_emp.is_active IS NOT TRUE OR v_has_valid_pass IS NOT TRUE OR v_allowed IS NOT TRUE THEN
        RAISE EXCEPTION 'PERMISSION_DENIED: %', p_permission_key
            USING ERRCODE = '42501';
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.assert_employee_permission(UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assert_employee_permission(UUID, TEXT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- [CHK-104] Saneamiento de employees.permissions a exactamente las 4 llaves canónicas
-- ------------------------------------------------------------------------------
ALTER TABLE public.employees
    DROP CONSTRAINT IF EXISTS chk_employees_permissions_4_keys;

UPDATE public.employees
SET permissions = jsonb_build_object(
        'canManageInventory', COALESCE((permissions->>'canManageInventory')::BOOLEAN, false),
        'canFiar', COALESCE((permissions->>'canFiar')::BOOLEAN, false),
        'canOpenCloseCash', COALESCE((permissions->>'canOpenCloseCash')::BOOLEAN, false),
        'canManageRefunds', COALESCE((permissions->>'canManageRefunds')::BOOLEAN, false)
    ),
    updated_at = COALESCE(updated_at, now());

ALTER TABLE public.employees
    ALTER COLUMN permissions SET DEFAULT '{"canManageInventory": false, "canFiar": false, "canOpenCloseCash": false, "canManageRefunds": false}'::jsonb;

ALTER TABLE public.employees
    ADD CONSTRAINT chk_employees_permissions_4_keys
    CHECK (
        permissions IS NULL
        OR (
            jsonb_typeof(permissions) = 'object'
            AND (permissions - ARRAY['canManageInventory', 'canFiar', 'canOpenCloseCash', 'canManageRefunds']) = '{}'::jsonb
            AND permissions ?& ARRAY['canManageInventory', 'canFiar', 'canOpenCloseCash', 'canManageRefunds']
        )
    );

-- ------------------------------------------------------------------------------
-- [CHK-105] RPCs de Personal: crear_empleado, rpc_actualizar_permisos_empleado, rpc_obtener_empleados
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.crear_empleado(
    p_store_id UUID,
    p_name TEXT,
    p_username TEXT,
    p_pin TEXT,
    p_permissions JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
    v_count INTEGER;
    v_employee_id UUID;
    v_actor_employee_id UUID;
    v_snap RECORD;
    v_clean_perms JSONB;
    v_extra_keys JSONB;
BEGIN
    -- 1. Aislamiento + Rol Admin obligatorio (Regla 4)
    PERFORM public.assert_store_admin(p_store_id);

    -- 2. Validar esquema cerrado de 4 permisos (si viene no-nulo debe ser objeto JSONB)
    IF p_permissions IS NOT NULL THEN
        IF jsonb_typeof(p_permissions) <> 'object' THEN
            RAISE EXCEPTION 'INVALID_PERMISSIONS_SCHEMA: El payload de permisos debe ser un objeto JSONB.'
                USING ERRCODE = '22023';
        END IF;

        v_extra_keys := p_permissions - ARRAY['canManageInventory', 'canFiar', 'canOpenCloseCash', 'canManageRefunds'];
        IF v_extra_keys <> '{}'::jsonb THEN
            RAISE EXCEPTION 'INVALID_PERMISSIONS_SCHEMA: Llaves de permiso no permitidas (%). Use únicamente canManageInventory, canFiar, canOpenCloseCash, canManageRefunds.', v_extra_keys::text
                USING ERRCODE = '22023';
        END IF;
    END IF;

    v_clean_perms := jsonb_build_object(
        'canManageInventory', COALESCE((p_permissions->>'canManageInventory')::BOOLEAN, false),
        'canFiar', COALESCE((p_permissions->>'canFiar')::BOOLEAN, false),
        'canOpenCloseCash', COALESCE((p_permissions->>'canOpenCloseCash')::BOOLEAN, false),
        'canManageRefunds', COALESCE((p_permissions->>'canManageRefunds')::BOOLEAN, false)
    );

    -- 3. Validar formato estricto de PIN de 4 dígitos
    IF p_pin IS NULL OR p_pin !~ '^[0-9]{4}$' THEN
        RAISE EXCEPTION 'INVALID_PIN_FORMAT: El PIN debe ser numérico de exactamente 4 dígitos'
            USING ERRCODE = '22023';
    END IF;

    -- 4. Validar límite estricto de 5 empleados activos simultáneos (excluyendo al dueño/admin)
    SELECT COUNT(*) INTO v_count
    FROM public.employees e
    WHERE e.store_id = p_store_id
      AND e.is_active = true
      AND NOT EXISTS (
          SELECT 1 FROM public.admin_profiles ap
          WHERE ap.id = e.id
      );

    IF v_count >= 5 THEN
        RAISE EXCEPTION 'EMPLOYEE_LIMIT_REACHED: Límite de 5 empleados activos alcanzado para la tienda'
            USING ERRCODE = 'P0001';
    END IF;

    -- 5. Validar unicidad global del alias
    IF EXISTS (SELECT 1 FROM public.employees WHERE LOWER(username) = LOWER(TRIM(p_username))) THEN
        RAISE EXCEPTION 'USERNAME_ALREADY_EXISTS: El alias ya está registrado en el sistema'
            USING ERRCODE = '23505';
    END IF;

    -- 6. Inserción segura con PIN hasheado
    INSERT INTO public.employees (
        store_id,
        name,
        username,
        pin_hash,
        permissions,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        p_store_id,
        TRIM(p_name),
        TRIM(p_username),
        extensions.crypt(p_pin, extensions.gen_salt('bf')),
        v_clean_perms,
        true,
        now(),
        now()
    )
    RETURNING id INTO v_employee_id;

    -- 7. Auditoría segura con snapshot inmutable
    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(p_store_id);
    SELECT id INTO v_actor_employee_id FROM public.employees WHERE id = auth.uid() AND store_id = p_store_id LIMIT 1;

    INSERT INTO public.audit_logs (
        actor_id, actor_name, actor_role, event_type, resource_id, metadata, store_id, severity
    ) VALUES (
        v_actor_employee_id,
        COALESCE(v_snap.actor_name, 'Administrador'),
        COALESCE(v_snap.actor_role, 'owner'),
        'EMPLOYEE_CREATED',
        v_employee_id::text,
        jsonb_build_object('name', TRIM(p_name), 'username', TRIM(p_username), 'permissions', v_clean_perms),
        p_store_id,
        'info'
    );

    RETURN jsonb_build_object(
        'success', true,
        'employee_id', v_employee_id,
        'permissions', v_clean_perms
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_actualizar_permisos_empleado(
    p_employee_id UUID,
    p_permissions JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_emp RECORD;
    v_extra_keys JSONB;
    v_clean_perms JSONB;
    v_snap RECORD;
    v_actor_employee_id UUID;
BEGIN
    SELECT * INTO v_emp
    FROM public.employees
    WHERE id = p_employee_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'EMPLOYEE_NOT_FOUND: Empleado especificado no existe.'
            USING ERRCODE = 'P0002';
    END IF;

    PERFORM public.assert_store_admin(v_emp.store_id);

    IF p_permissions IS NULL OR jsonb_typeof(p_permissions) <> 'object' THEN
        RAISE EXCEPTION 'INVALID_PERMISSIONS_SCHEMA: El payload de permisos debe ser un objeto JSONB.'
            USING ERRCODE = '22023';
    END IF;

    v_extra_keys := p_permissions - ARRAY['canManageInventory', 'canFiar', 'canOpenCloseCash', 'canManageRefunds'];
    IF v_extra_keys <> '{}'::jsonb THEN
        RAISE EXCEPTION 'INVALID_PERMISSIONS_SCHEMA: Llaves de permiso no permitidas (%).', v_extra_keys::text
            USING ERRCODE = '22023';
    END IF;

    v_clean_perms := jsonb_build_object(
        'canManageInventory', COALESCE((p_permissions->>'canManageInventory')::BOOLEAN, false),
        'canFiar', COALESCE((p_permissions->>'canFiar')::BOOLEAN, false),
        'canOpenCloseCash', COALESCE((p_permissions->>'canOpenCloseCash')::BOOLEAN, false),
        'canManageRefunds', COALESCE((p_permissions->>'canManageRefunds')::BOOLEAN, false)
    );

    UPDATE public.employees
    SET permissions = v_clean_perms,
        updated_at = now()
    WHERE id = p_employee_id;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_emp.store_id);
    SELECT id INTO v_actor_employee_id FROM public.employees WHERE id = auth.uid() AND store_id = v_emp.store_id LIMIT 1;

    INSERT INTO public.audit_logs (
        actor_id, actor_name, actor_role, event_type, resource_id, metadata, store_id, severity
    ) VALUES (
        v_actor_employee_id,
        COALESCE(v_snap.actor_name, 'Administrador'),
        COALESCE(v_snap.actor_role, 'owner'),
        'EMPLOYEE_PERMISSIONS_UPDATED',
        p_employee_id::text,
        jsonb_build_object(
            'previous_permissions', v_emp.permissions,
            'new_permissions', v_clean_perms
        ),
        v_emp.store_id,
        'info'
    );

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'employee_id', p_employee_id,
            'permissions', v_clean_perms,
            'updated_at', now()
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

REVOKE ALL ON FUNCTION public.rpc_actualizar_permisos_empleado(UUID, JSONB) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rpc_actualizar_permisos_empleado(UUID, JSONB) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.rpc_obtener_empleados(
    p_store_id UUID,
    p_status_filter TEXT DEFAULT 'all'::text,
    p_search TEXT DEFAULT NULL::text
)
RETURNS TABLE(
    id UUID,
    store_id UUID,
    name TEXT,
    username TEXT,
    pin TEXT,
    is_active BOOLEAN,
    permissions JSONB,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
    -- Blindaje estrictamente Admin-only (SDD-003 §0.3 D-6 / SDD-003-01)
    PERFORM public.assert_store_admin(p_store_id);

    RETURN QUERY
    SELECT
        e.id,
        e.store_id,
        e.name,
        e.username,
        ''::TEXT AS pin,
        COALESCE(e.is_active, false) AS is_active,
        jsonb_build_object(
            'canManageInventory', COALESCE((e.permissions->>'canManageInventory')::BOOLEAN, false),
            'canFiar', COALESCE((e.permissions->>'canFiar')::BOOLEAN, false),
            'canOpenCloseCash', COALESCE((e.permissions->>'canOpenCloseCash')::BOOLEAN, false),
            'canManageRefunds', COALESCE((e.permissions->>'canManageRefunds')::BOOLEAN, false)
        ) AS permissions,
        e.created_at,
        e.updated_at
    FROM public.employees e
    WHERE e.store_id = p_store_id
      AND (
          p_status_filter = 'all'
          OR (p_status_filter = 'active' AND e.is_active = true)
          OR (p_status_filter = 'inactive' AND e.is_active = false)
      )
      AND (
          p_search IS NULL
          OR p_search = ''
          OR e.name ILIKE '%' || TRIM(p_search) || '%'
          OR e.username ILIKE '%' || TRIM(p_search) || '%'
      )
    ORDER BY e.name ASC;
END;
$$;

-- ------------------------------------------------------------------------------
-- [CHK-106] Continuidad <24h en request_employee_access, check_my_pass_status,
--           solicitar_pase_diario y toggle_empleado_activo
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_employee_access(
    p_username TEXT,
    p_pin TEXT,
    p_device_fingerprint TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
    v_employee RECORD;
    v_existing_pass RECORD;
    v_pass_id UUID;
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
    v_pin_matches BOOLEAN := false;
    v_clean_perms JSONB;
BEGIN
    -- 1. Buscar empleado activo por username
    SELECT e.*
    INTO v_employee
    FROM public.employees e
    JOIN public.stores s ON e.store_id = s.id
    WHERE e.username = p_username AND e.is_active = true;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'USER_NOT_FOUND',
            'message', 'Alias no existe o colaborador inactivo'
        );
    END IF;

    -- 2. Validar hash criptográfico de PIN de forma blindada
    IF v_employee.pin_hash IS NULL OR length(trim(v_employee.pin_hash)) < 10 THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'INVALID_CREDENTIALS',
            'message', 'PIN no configurado o incorrecto'
        );
    END IF;

    BEGIN
        v_pin_matches := (v_employee.pin_hash = extensions.crypt(p_pin, v_employee.pin_hash));
    EXCEPTION WHEN SQLSTATE '22023' THEN
        v_pin_matches := false;
    END;

    IF NOT v_pin_matches THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'INVALID_CREDENTIALS',
            'message', 'PIN Incorrecto'
        );
    END IF;

    v_clean_perms := jsonb_build_object(
        'canManageInventory', COALESCE((v_employee.permissions->>'canManageInventory')::BOOLEAN, false),
        'canFiar', COALESCE((v_employee.permissions->>'canFiar')::BOOLEAN, false),
        'canOpenCloseCash', COALESCE((v_employee.permissions->>'canOpenCloseCash')::BOOLEAN, false),
        'canManageRefunds', COALESCE((v_employee.permissions->>'canManageRefunds')::BOOLEAN, false)
    );

    -- 3. Consultar pase de hoy O pase aprobado de ayer vigente por turno abierto <24h (Brecha B-06)
    SELECT dp.* INTO v_existing_pass
    FROM public.daily_passes dp
    WHERE dp.employee_id = v_employee.id
      AND (
          dp.pass_date = v_today
          OR (
              dp.pass_date = v_today - 1
              AND dp.status = 'approved'
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

    IF FOUND THEN
        IF v_existing_pass.status = 'approved' THEN
            RETURN jsonb_build_object(
                'success', true,
                'status', 'approved',
                'pass_id', v_existing_pass.id,
                'employee', jsonb_build_object(
                    'id', v_employee.id,
                    'name', v_employee.name,
                    'role', 'employee',
                    'store_id', v_employee.store_id,
                    'permissions', v_clean_perms
                )
            );
        END IF;

        IF v_existing_pass.status = 'pending' THEN
            IF COALESCE(v_existing_pass.retry_count, 0) >= 3 THEN
                RETURN jsonb_build_object(
                    'success', false,
                    'code', 'MAX_RETRIES',
                    'message', 'Límite de reintentos alcanzado. Contacte a su supervisor.'
                );
            END IF;

            UPDATE public.daily_passes
            SET device_fingerprint = COALESCE(p_device_fingerprint, device_fingerprint, 'N/A'),
                updated_at = now()
            WHERE id = v_existing_pass.id;

            RETURN jsonb_build_object(
                'success', true,
                'status', 'pending',
                'pass_id', v_existing_pass.id,
                'employee', jsonb_build_object(
                    'id', v_employee.id,
                    'name', v_employee.name,
                    'role', 'employee',
                    'store_id', v_employee.store_id,
                    'permissions', v_clean_perms
                )
            );
        END IF;

        RETURN jsonb_build_object(
            'success', false,
            'code', 'ALREADY_PROCESSED',
            'message', 'Pase ya procesado hoy: ' || v_existing_pass.status
        );
    END IF;

    -- 4. Inserción inicial en daily_passes para v_today
    INSERT INTO public.daily_passes (
        employee_id,
        store_id,
        device_fingerprint,
        status,
        pass_date,
        retry_count,
        requested_at,
        updated_at,
        auth_user_id
    ) VALUES (
        v_employee.id,
        v_employee.store_id,
        COALESCE(p_device_fingerprint, 'N/A'),
        'pending',
        v_today,
        0,
        now(),
        now(),
        auth.uid()
    )
    RETURNING id INTO v_pass_id;

    INSERT INTO public.notifications (
        store_id, type, title, message, audience, is_read, metadata
    ) VALUES (
        v_employee.store_id,
        'security',
        'Solicitud de Acceso',
        v_employee.name || ' solicita acceso al sistema',
        'admin',
        false,
        jsonb_build_object(
            'requestId', v_pass_id,
            'employeeName', v_employee.name,
            'status', 'pending',
            'deviceFingerprint', p_device_fingerprint
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'status', 'pending',
        'pass_id', v_pass_id,
        'employee', jsonb_build_object(
            'id', v_employee.id,
            'name', v_employee.name,
            'role', 'employee',
            'store_id', v_employee.store_id,
            'permissions', v_clean_perms
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION public.solicitar_pase_diario(
    p_employee_id UUID,
    p_device_fingerprint TEXT DEFAULT NULL::text
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_employee RECORD;
    v_existing_pass RECORD;
    v_pass_id UUID;
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
BEGIN
    SELECT * INTO v_employee
    FROM public.employees
    WHERE id = p_employee_id;

    IF NOT FOUND OR v_employee.is_active IS NOT TRUE THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Empleado no encontrado o inactivo',
            'code', 'INVALID_CREDENTIALS'
        );
    END IF;

    SELECT dp.* INTO v_existing_pass
    FROM public.daily_passes dp
    WHERE dp.employee_id = p_employee_id
      AND (
          dp.pass_date = v_today
          OR (
              dp.pass_date = v_today - 1
              AND dp.status = 'approved'
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

    IF FOUND THEN
        IF v_existing_pass.status = 'approved' THEN
            RETURN jsonb_build_object(
                'success', true,
                'status', 'approved',
                'pass_id', v_existing_pass.id,
                'retry_count', COALESCE(v_existing_pass.retry_count, 0)
            );
        END IF;

        IF v_existing_pass.status = 'pending' THEN
            IF COALESCE(v_existing_pass.retry_count, 0) >= 3 THEN
                RETURN jsonb_build_object(
                    'success', false,
                    'error', 'Límite de intentos alcanzado. Contacte a su supervisor.',
                    'code', 'MAX_RETRIES',
                    'retry_count', v_existing_pass.retry_count
                );
            END IF;

            UPDATE public.daily_passes
            SET retry_count = COALESCE(retry_count, 0) + 1,
                device_fingerprint = COALESCE(p_device_fingerprint, device_fingerprint, 'N/A'),
                requested_at = now(),
                updated_at = now()
            WHERE id = v_existing_pass.id;

            INSERT INTO public.notifications (
                store_id, type, title, message, audience, is_read, metadata
            ) VALUES (
                v_employee.store_id,
                'security',
                'Reintento de Acceso (' || (COALESCE(v_existing_pass.retry_count, 0) + 1) || '/3)',
                v_employee.name || ' reitera solicitud de acceso diario',
                'admin',
                false,
                jsonb_build_object(
                    'requestId', v_existing_pass.id,
                    'employeeName', v_employee.name,
                    'retryCount', COALESCE(v_existing_pass.retry_count, 0) + 1,
                    'deviceFingerprint', p_device_fingerprint
                )
            );

            RETURN jsonb_build_object(
                'success', true,
                'status', 'pending',
                'pass_id', v_existing_pass.id,
                'retry_count', COALESCE(v_existing_pass.retry_count, 0) + 1
            );
        END IF;

        RETURN jsonb_build_object(
            'success', false,
            'error', 'Pase ya procesado para hoy (' || v_existing_pass.status || ')',
            'code', 'ALREADY_PROCESSED'
        );
    END IF;

    INSERT INTO public.daily_passes (
        employee_id,
        store_id,
        device_fingerprint,
        status,
        pass_date,
        retry_count,
        requested_at,
        updated_at,
        auth_user_id
    ) VALUES (
        p_employee_id,
        v_employee.store_id,
        COALESCE(p_device_fingerprint, 'N/A'),
        'pending',
        v_today,
        0,
        now(),
        now(),
        auth.uid()
    )
    RETURNING id INTO v_pass_id;

    INSERT INTO public.notifications (
        store_id, type, title, message, audience, is_read, metadata
    ) VALUES (
        v_employee.store_id,
        'security',
        'Solicitud de Acceso',
        v_employee.name || ' solicita acceso al sistema',
        'admin',
        false,
        jsonb_build_object(
            'requestId', v_pass_id,
            'employeeName', v_employee.name,
            'status', 'pending',
            'deviceFingerprint', p_device_fingerprint
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'status', 'pending',
        'pass_id', v_pass_id,
        'retry_count', 0
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION public.check_my_pass_status(p_pass_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_result RECORD;
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
    v_is_still_valid BOOLEAN := false;
    v_clean_perms JSONB;
BEGIN
    SELECT
        dp.status AS pass_status,
        dp.pass_date,
        dp.store_id AS dp_store_id,
        e.id,
        e.name,
        e.store_id,
        e.username,
        e.is_active,
        e.permissions
    INTO v_result
    FROM public.daily_passes dp
    JOIN public.employees e ON dp.employee_id = e.id
    WHERE dp.id = p_pass_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('status', 'not_found');
    END IF;

    IF v_result.is_active IS NOT TRUE THEN
        RETURN jsonb_build_object('status', 'rejected');
    END IF;

    IF v_result.pass_status = 'approved' THEN
        v_is_still_valid := (
            v_result.pass_date = v_today
            OR (
                v_result.pass_date = v_today - 1
                AND EXISTS (
                    SELECT 1 FROM public.cash_sessions cs
                    WHERE cs.store_id = v_result.dp_store_id
                      AND cs.status = 'open'
                      AND cs.opened_at >= (now() - interval '24 hours')
                )
            )
        );

        IF NOT v_is_still_valid THEN
            RETURN jsonb_build_object('status', 'expired');
        END IF;

        v_clean_perms := jsonb_build_object(
            'canManageInventory', COALESCE((v_result.permissions->>'canManageInventory')::BOOLEAN, false),
            'canFiar', COALESCE((v_result.permissions->>'canFiar')::BOOLEAN, false),
            'canOpenCloseCash', COALESCE((v_result.permissions->>'canOpenCloseCash')::BOOLEAN, false),
            'canManageRefunds', COALESCE((v_result.permissions->>'canManageRefunds')::BOOLEAN, false)
        );

        RETURN jsonb_build_object(
            'status', 'approved',
            'employee', jsonb_build_object(
                'id', v_result.id,
                'name', v_result.name,
                'role', 'employee',
                'store_id', v_result.store_id,
                'username', v_result.username,
                'permissions', v_clean_perms
            )
        );
    ELSE
        RETURN jsonb_build_object('status', v_result.pass_status);
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.toggle_empleado_activo(
    p_employee_id UUID,
    p_new_status BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_emp RECORD;
    v_count INTEGER;
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
    v_snap RECORD;
    v_actor_emp_id UUID;
BEGIN
    SELECT * INTO v_emp
    FROM public.employees
    WHERE id = p_employee_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'EMPLOYEE_NOT_FOUND: Empleado especificado no existe.'
            USING ERRCODE = 'P0002';
    END IF;

    -- Regla 4: Aislamiento + Admin obligatorio
    PERFORM public.assert_store_admin(v_emp.store_id);

    IF p_new_status IS TRUE THEN
        SELECT COUNT(*) INTO v_count
        FROM public.employees e
        WHERE e.store_id = v_emp.store_id
          AND e.is_active = true
          AND e.id <> p_employee_id
          AND NOT EXISTS (
              SELECT 1 FROM public.admin_profiles ap
              WHERE ap.id = e.id
          );

        IF v_count >= 5 THEN
            RAISE EXCEPTION 'LIMIT_REACHED: Límite de 5 empleados activos alcanzado para la tienda'
                USING ERRCODE = 'P0001';
        END IF;
    END IF;

    -- Si se desactiva, revocar de inmediato pases vigentes de hoy Y de ayer (<24h nocturno)
    IF p_new_status IS FALSE THEN
        UPDATE public.daily_passes
        SET status = 'rejected',
            resolved_at = now(),
            resolved_by = auth.uid(),
            updated_at = now()
        WHERE employee_id = p_employee_id
          AND pass_date IN (v_today, v_today - 1)
          AND status IN ('approved', 'pending');
    END IF;

    UPDATE public.employees
    SET is_active = p_new_status,
        updated_at = now()
    WHERE id = p_employee_id;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_emp.store_id);
    SELECT id INTO v_actor_emp_id FROM public.employees WHERE id = auth.uid() AND store_id = v_emp.store_id LIMIT 1;

    INSERT INTO public.audit_logs (
        actor_id, actor_name, actor_role, event_type, resource_id, metadata, store_id, severity
    ) VALUES (
        v_actor_emp_id,
        COALESCE(v_snap.actor_name, 'Administrador'),
        COALESCE(v_snap.actor_role, 'owner'),
        'EMPLOYEE_STATUS_CHANGED',
        p_employee_id::text,
        jsonb_build_object(
            'is_active', p_new_status,
            'previous_status', v_emp.is_active
        ),
        v_emp.store_id,
        'warning'
    );

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object('new_status', p_new_status)
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

-- ------------------------------------------------------------------------------
-- [CHK-107] rpc_gestionar_dispositivo: Admin ('owner'/'manager') + Tope 5 con <24h
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rpc_gestionar_dispositivo(
    p_pass_id UUID,
    p_action TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_pass RECORD;
    v_actor_id UUID := auth.uid();
    v_new_status TEXT;
    v_active_employees INTEGER;
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
    v_snap RECORD;
    v_actor_emp_id UUID;
BEGIN
    SELECT * INTO v_pass
    FROM public.daily_passes
    WHERE id = p_pass_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PASS_NOT_FOUND: El pase especificado (%) no existe.', p_pass_id
            USING ERRCODE = 'P0002';
    END IF;

    -- Autoridad centralizada en admin_profiles ('owner' | 'manager') + store isolation
    PERFORM public.assert_store_admin(v_pass.store_id);

    IF p_action = 'approve' THEN
        IF v_pass.pass_date <> v_today THEN
            RAISE EXCEPTION 'EXPIRED_PASS_DATE: No se puede aprobar un pase de una fecha distinta al día actual.'
                USING ERRCODE = 'P0001';
        END IF;

        -- Tope 5 terminales activas: incluye hoy + pases nocturnos aprobados de ayer <24h
        SELECT COUNT(DISTINCT dp.employee_id) INTO v_active_employees
        FROM public.daily_passes dp
        WHERE dp.store_id = v_pass.store_id
          AND dp.status = 'approved'
          AND dp.employee_id <> v_pass.employee_id
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
          );

        IF v_active_employees >= 5 THEN
            RAISE EXCEPTION 'SESSION_LIMIT_REACHED: Se alcanzó el límite máximo de 5 terminales de empleados autorizadas simultáneamente.'
                USING ERRCODE = 'P0001';
        END IF;

        v_new_status := 'approved';

        UPDATE public.daily_passes
        SET status = v_new_status,
            resolved_at = now(),
            resolved_by = v_actor_id,
            approved_at = now(),
            approved_by = v_actor_id,
            updated_at = now()
        WHERE id = p_pass_id;

    ELSIF p_action IN ('reject', 'revoke') THEN
        v_new_status := 'rejected';

        UPDATE public.daily_passes
        SET status = v_new_status,
            resolved_at = now(),
            resolved_by = v_actor_id,
            updated_at = now()
        WHERE id = p_pass_id;
    ELSE
        RAISE EXCEPTION 'INVALID_ACTION: Acción (%) no reconocida. Use approve, reject o revoke.', p_action
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_pass.store_id);
    SELECT id INTO v_actor_emp_id FROM public.employees WHERE id = v_actor_id AND store_id = v_pass.store_id LIMIT 1;

    INSERT INTO public.audit_logs (
        actor_id, actor_name, actor_role, event_type, resource_id, metadata, store_id, severity
    ) VALUES (
        v_actor_emp_id,
        COALESCE(v_snap.actor_name, 'Administrador'),
        COALESCE(v_snap.actor_role, 'owner'),
        'DEVICE_ACCESS_' || UPPER(p_action),
        p_pass_id::text,
        jsonb_build_object(
            'employee_id', v_pass.employee_id,
            'previous_status', v_pass.status,
            'new_status', v_new_status,
            'device_fingerprint', v_pass.device_fingerprint,
            'pass_date', v_pass.pass_date
        ),
        v_pass.store_id,
        CASE WHEN p_action = 'revoke' THEN 'warning' ELSE 'info' END
    );

    INSERT INTO public.audit_seguridad (
        actor_id, actor_name, actor_role, store_id, event_type, metadata
    ) VALUES (
        v_actor_emp_id,
        COALESCE(v_snap.actor_name, 'Administrador'),
        COALESCE(v_snap.actor_role, 'owner'),
        v_pass.store_id,
        'DEVICE_ACCESS_' || UPPER(p_action),
        jsonb_build_object(
            'pass_id', p_pass_id,
            'employee_id', v_pass.employee_id,
            'previous_status', v_pass.status,
            'new_status', v_new_status,
            'device_fingerprint', v_pass.device_fingerprint
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'pass_id', p_pass_id,
            'employee_id', v_pass.employee_id,
            'status', v_new_status,
            'resolved_at', now(),
            'resolved_by', v_actor_id
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

-- ------------------------------------------------------------------------------
-- [CHK-109] Unificación de Canales: efectivo, nequi, llave_bre (sin daviplata/bre)
-- + Actualización de RPCs escritores y de consulta para coherencia total
-- ------------------------------------------------------------------------------

-- 1. Migración de datos históricos antes de restringir CHECK constraints
UPDATE public.cash_movements SET payment_method = 'llave_bre' WHERE payment_method = 'bre';
UPDATE public.cash_movements SET payment_method = 'nequi' WHERE payment_method = 'daviplata';

UPDATE public.sales SET payment_method = 'llave_bre' WHERE payment_method = 'bre';
UPDATE public.sales SET payment_method = 'nequi' WHERE payment_method = 'daviplata';

-- 2. Actualizar tabla payment_methods
ALTER TABLE public.payment_methods DROP CONSTRAINT IF EXISTS payment_methods_allowed_codes_check;

DELETE FROM public.payment_methods WHERE code IN ('card', 'daviplata');

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM public.payment_methods WHERE code = 'bre') THEN
        IF EXISTS (SELECT 1 FROM public.payment_methods WHERE code = 'llave_bre') THEN
            DELETE FROM public.payment_methods WHERE code = 'bre';
        ELSE
            UPDATE public.payment_methods
            SET code = 'llave_bre',
                name = 'Llave Bre-B'
            WHERE code = 'bre';
        END IF;
    END IF;
END $$;

UPDATE public.payment_methods
SET name = 'Nequi'
WHERE code = 'nequi';

INSERT INTO public.payment_methods (code, name, is_active, requires_reference, allows_change, sort_order)
SELECT 'llave_bre', 'Llave Bre-B', true, true, false, 3
WHERE NOT EXISTS (SELECT 1 FROM public.payment_methods WHERE code = 'llave_bre');

ALTER TABLE public.payment_methods
    ADD CONSTRAINT payment_methods_allowed_codes_check
    CHECK (code IN ('cash', 'efectivo', 'nequi', 'llave_bre', 'fiado'));

-- 3. Actualizar constraints de cash_movements y sales
ALTER TABLE public.cash_movements DROP CONSTRAINT IF EXISTS chk_cash_movements_payment_method;
ALTER TABLE public.cash_movements
    ADD CONSTRAINT chk_cash_movements_payment_method
    CHECK (payment_method IN ('efectivo', 'nequi', 'llave_bre'));

ALTER TABLE public.sales DROP CONSTRAINT IF EXISTS sales_payment_method_check;
ALTER TABLE public.sales
    ADD CONSTRAINT sales_payment_method_check
    CHECK (payment_method IN ('efectivo', 'nequi', 'llave_bre', 'fiado', 'consumo_personal'));

-- 4. Actualizar trigger fn_audit_sale_created con snapshot
CREATE OR REPLACE FUNCTION public.fn_audit_sale_created()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_emp_fk_id UUID;
BEGIN
    SELECT id INTO v_emp_fk_id FROM public.employees WHERE id = NEW.employee_id LIMIT 1;

    INSERT INTO public.audit_ventas (sale_id, store_id, event_type, actor_id, actor_name, actor_role, metadata)
    VALUES (
        NEW.id,
        NEW.store_id,
        'CREACION',
        v_emp_fk_id,
        COALESCE(NEW.actor_name, 'Administrador'),
        COALESCE(NEW.actor_role, 'owner'),
        jsonb_build_object(
            'total', NEW.total,
            'payment_method', NEW.payment_method,
            'sale_number', NEW.ticket_number,
            'client_id', NEW.client_id
        )
    );
    RETURN NEW;
END;
$$;

-- 5. Actualizar RPCs que validan o consultan payment_method + estampar snapshot
CREATE OR REPLACE FUNCTION public.rpc_procesar_venta_v3(
    p_store_id UUID,
    p_client_id UUID,
    p_payment_method TEXT,
    p_amount_received NUMERIC,
    p_items JSONB,
    p_idempotency_key UUID DEFAULT NULL::uuid,
    p_local_id TEXT DEFAULT NULL::text,
    p_is_offline_sync BOOLEAN DEFAULT false,
    p_origin_session_id UUID DEFAULT NULL::uuid,
    p_sold_by UUID DEFAULT NULL::uuid
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_sale_id UUID;
    v_ticket_number INTEGER;
    v_total_calculated NUMERIC := 0;
    v_total_raw NUMERIC := 0;
    v_rounding_difference NUMERIC := 0;
    v_change NUMERIC := 0;
    v_item JSONB;
    v_product_id UUID;
    v_quantity NUMERIC;
    v_product_price NUMERIC;
    v_product_cost NUMERIC;
    v_product_name TEXT;
    v_is_weighable BOOLEAN;
    v_item_subtotal NUMERIC;
    v_raw_subtotal NUMERIC;
    v_client_balance NUMERIC;
    v_client_limit NUMERIC;
    v_sale_client_id UUID;
    v_employee_id UUID;
    v_emp_fk_id UUID;
    v_actor_name TEXT;
    v_actor_role TEXT;
    v_snap RECORD;
    v_pm_allows_change BOOLEAN;
    v_batch RECORD;
    v_sale_item_id UUID;
    v_session_id UUID;
    v_session_status TEXT;
    v_session_opened_at TIMESTAMPTZ;
    v_items_count INTEGER := 0;
    v_existing_sale RECORD;
    v_historical_price NUMERIC;
    v_is_late_sync BOOLEAN := false;
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(p_store_id);

    IF p_is_offline_sync AND p_sold_by IS NOT NULL THEN
        SELECT e.id, e.name INTO v_employee_id, v_actor_name
        FROM public.employees e
        WHERE e.id = p_sold_by AND e.store_id = p_store_id;
        IF v_employee_id IS NOT NULL THEN
            v_actor_role := 'employee';
        END IF;
    END IF;

    IF v_employee_id IS NULL THEN
        v_employee_id := public.get_employee_id_from_session();
    END IF;

    IF v_employee_id IS NULL THEN
        IF public.is_store_admin(p_store_id) THEN
            v_employee_id := auth.uid();
        ELSE
            RAISE EXCEPTION 'Usuario no autorizado para vender (STORE_ACCESS_DENIED)' USING ERRCODE = 'P0001';
        END IF;
    END IF;

    SELECT e.id INTO v_emp_fk_id FROM public.employees e WHERE e.id = v_employee_id AND e.store_id = p_store_id LIMIT 1;
    v_actor_name := COALESCE(v_actor_name, v_snap.actor_name, 'Administrador');
    v_actor_role := COALESCE(v_actor_role, v_snap.actor_role, 'owner');

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

    IF p_payment_method NOT IN ('efectivo', 'nequi', 'llave_bre', 'fiado') THEN
        RAISE EXCEPTION 'Método de pago inválido: % (INVALID_PAYMENT_METHOD)', p_payment_method USING ERRCODE = 'P0001';
    END IF;

    v_pm_allows_change := (p_payment_method = 'efectivo');
    v_sale_client_id := CASE WHEN p_payment_method = 'fiado' THEN p_client_id ELSE NULL END;

    IF p_payment_method IN ('efectivo', 'nequi', 'llave_bre') THEN
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
        store_id, ticket_number, employee_id, actor_name, actor_role, client_id, total,
        rounding_difference, payment_method, amount_received, change_given,
        sync_status, local_id, idempotency_key
    ) VALUES (
        p_store_id, v_ticket_number, v_emp_fk_id, v_actor_name, v_actor_role, v_sale_client_id, 0,
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

        FOR v_batch IN SELECT * FROM public.consume_stock_fifo(v_product_id, v_quantity) LOOP
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

        INSERT INTO public.inventory_movements (product_id, movement_type, quantity, reason, created_by, actor_name, actor_role)
        VALUES (v_product_id, 'venta', v_quantity, 'Venta #' || v_ticket_number, v_emp_fk_id, v_actor_name, v_actor_role);

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

    IF p_payment_method IN ('efectivo', 'nequi', 'llave_bre') THEN
        INSERT INTO public.cash_movements (
            session_id, movement_type, amount, description, sale_id, payment_method, category, actor_id, actor_name, actor_role
        ) VALUES (
            v_session_id, 'ingreso', v_total_calculated, 'Venta #' || v_ticket_number, v_sale_id, p_payment_method, 'venta', v_emp_fk_id, v_actor_name, v_actor_role
        );

        IF v_is_late_sync THEN
            IF p_payment_method = 'efectivo' THEN
                UPDATE public.cash_sessions
                SET expected_balance = COALESCE(expected_balance, 0) + v_total_calculated
                WHERE id = v_session_id;
            END IF;

            INSERT INTO public.audit_logs (
                actor_id, actor_name, actor_role, store_id, event_type, resource_id, metadata, severity, created_at
            ) VALUES (
                v_emp_fk_id,
                v_actor_name,
                v_actor_role,
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
            client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by, actor_name, actor_role
        ) VALUES (
            v_sale_client_id, p_store_id, v_total_calculated, v_client_balance, v_sale_id, 'venta_fiado', v_emp_fk_id, v_actor_name, v_actor_role
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
            'created_at', NOW(),
            'actor_name', v_actor_name,
            'actor_role', v_actor_role
        )
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_anular_venta(
    p_sale_id UUID,
    p_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_store_id UUID;
    v_sale RECORD;
    v_item RECORD;
    v_employee_id UUID;
    v_snap RECORD;
    v_client_balance NUMERIC;
    v_client_deleted BOOLEAN;
    v_session_id UUID;
    v_session_opened_at TIMESTAMPTZ;
    v_opening NUMERIC := 0;
    v_ingresos NUMERIC := 0;
    v_egresos NUMERIC := 0;
    v_available NUMERIC := 0;
BEGIN
    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED' USING ERRCODE = '42501';
    END IF;
    PERFORM public.assert_store_admin(v_store_id);

    SELECT * INTO v_sale
    FROM public.sales
    WHERE id = p_sale_id
      AND store_id = v_store_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venta no encontrada (SALE_NOT_FOUND)' USING ERRCODE = 'P0001';
    END IF;

    IF length(trim(COALESCE(p_reason, ''))) < 10 THEN
        RAISE EXCEPTION 'El motivo de anulación debe tener al menos 10 caracteres (REASON_TOO_SHORT)' USING ERRCODE = 'P0001';
    END IF;

    IF v_sale.is_voided THEN
        RAISE EXCEPTION 'Esta venta ya fue anulada previamente (SALE_ALREADY_VOIDED)' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_store_id);
    SELECT id INTO v_employee_id FROM public.employees WHERE id = auth.uid() AND store_id = v_store_id LIMIT 1;

    IF v_sale.payment_method IN ('efectivo', 'nequi', 'llave_bre') THEN
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
            session_id, movement_type, amount, description, sale_id, payment_method, category, actor_id, actor_name, actor_role
        ) VALUES (
            v_session_id, 'gasto', v_sale.total, '[ANULACION_VENTA #' || v_sale.ticket_number || '] ' || p_reason, p_sale_id, v_sale.payment_method, 'anulacion_venta', v_employee_id, v_snap.actor_name, v_snap.actor_role
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
            client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by, actor_name, actor_role
        ) VALUES (
            v_sale.client_id, v_sale.store_id, -v_sale.total, v_client_balance, p_sale_id, 'anulacion_fiado', v_employee_id, v_snap.actor_name, v_snap.actor_role
        );
    END IF;

    FOR v_item IN SELECT * FROM public.sale_items WHERE sale_id = p_sale_id LOOP
        INSERT INTO public.inventory_movements (
            product_id, movement_type, quantity, reason, created_by, actor_name, actor_role
        ) VALUES (
            v_item.product_id,
            'CORRECCION_SISTEMA',
            v_item.quantity,
            'ANULACION VENTA #' || v_sale.ticket_number || ': ' || p_reason,
            v_employee_id,
            v_snap.actor_name,
            v_snap.actor_role
        );
    END LOOP;

    UPDATE public.sales
    SET is_voided = true,
        void_reason = p_reason,
        voided_by = v_employee_id,
        voided_by_name = v_snap.actor_name,
        voided_by_role = v_snap.actor_role,
        void_session_id = v_session_id,
        voided_at = NOW()
    WHERE id = p_sale_id;

    INSERT INTO public.audit_logs (store_id, actor_id, actor_name, actor_role, event_type, resource_id, metadata, severity)
    VALUES (
        v_sale.store_id,
        v_employee_id,
        v_snap.actor_name,
        v_snap.actor_role,
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

CREATE OR REPLACE FUNCTION public.rpc_registrar_gasto_v2(
    p_session_id UUID,
    p_amount NUMERIC,
    p_payment_method TEXT,
    p_category TEXT,
    p_description TEXT,
    p_voucher_ref TEXT DEFAULT NULL::text
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $$
DECLARE
    v_session RECORD;
    v_method TEXT := LOWER(TRIM(p_payment_method));
    v_ingresos NUMERIC := 0;
    v_egresos NUMERIC := 0;
    v_available NUMERIC := 0;
    v_movement_id UUID;
    v_snap RECORD;
    v_emp_fk_id UUID;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'INVALID_AMOUNT: El monto del gasto debe ser un valor positivo mayor a cero.'
            USING ERRCODE = '22023';
    END IF;

    IF v_method NOT IN ('efectivo', 'nequi', 'llave_bre') THEN
        RAISE EXCEPTION 'INVALID_PAYMENT_METHOD: Canal de pago (%) no válido. Permitidos: efectivo, nequi, llave_bre.', p_payment_method
            USING ERRCODE = '22023';
    END IF;

    IF p_description IS NULL OR LENGTH(TRIM(p_description)) < 3 THEN
        RAISE EXCEPTION 'INVALID_DESCRIPTION: La descripción del gasto debe contener al menos 3 caracteres.'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_session
    FROM public.cash_sessions
    WHERE id = p_session_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'SESSION_NOT_FOUND: La sesión de caja (%) no existe.', p_session_id
            USING ERRCODE = 'P0002';
    END IF;

    PERFORM public.assert_store_access(v_session.store_id);

    IF v_session.status <> 'open' THEN
        RAISE EXCEPTION 'SHIFT_CLOSED: No se pueden registrar gastos en una caja cerrada.'
            USING ERRCODE = 'P0001';
    END IF;

    IF (now() - v_session.opened_at) > INTERVAL '24 hours' THEN
        RAISE EXCEPTION 'SHIFT_EXPIRED_24H: El turno de caja superó el límite legal de 24 horas. Debe cerrarse antes de registrar nuevos movimientos.'
            USING ERRCODE = 'P0001';
    END IF;

    IF v_method = 'efectivo' THEN
        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
        FROM public.cash_movements
        WHERE session_id = p_session_id AND movement_type = 'ingreso' AND payment_method = 'efectivo';

        SELECT COALESCE(SUM(amount), 0) INTO v_egresos
        FROM public.cash_movements
        WHERE session_id = p_session_id AND movement_type IN ('gasto', 'pago_proveedor') AND payment_method = 'efectivo';

        v_available := v_session.opening_balance + v_ingresos - v_egresos;
    ELSE
        SELECT COALESCE(SUM(amount), 0) INTO v_ingresos
        FROM public.cash_movements
        WHERE session_id = p_session_id AND movement_type = 'ingreso' AND payment_method = v_method;

        SELECT COALESCE(SUM(amount), 0) INTO v_egresos
        FROM public.cash_movements
        WHERE session_id = p_session_id AND movement_type IN ('gasto', 'pago_proveedor') AND payment_method = v_method;

        v_available := v_ingresos - v_egresos;
    END IF;

    IF p_amount > v_available THEN
        RAISE EXCEPTION 'INSUFFICIENT_CHANNEL_FUNDS: Fondos insuficientes en canal % (Disponible: %, Solicitado: %).', v_method, v_available, p_amount
            USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_session.store_id);
    SELECT e.id INTO v_emp_fk_id
    FROM public.employees e
    WHERE e.id = COALESCE(public.get_employee_id_from_session(), auth.uid()) AND e.store_id = v_session.store_id
    LIMIT 1;

    INSERT INTO public.cash_movements (
        session_id, movement_type, amount, description, payment_method, category, voucher_ref, actor_id, actor_name, actor_role
    ) VALUES (
        p_session_id, 'gasto', p_amount, TRIM(p_description), v_method, TRIM(p_category), TRIM(p_voucher_ref), v_emp_fk_id, v_snap.actor_name, v_snap.actor_role
    ) RETURNING id INTO v_movement_id;

    RETURN jsonb_build_object(
        'success', true,
        'data', jsonb_build_object(
            'movement_id', v_movement_id,
            'session_id', p_session_id,
            'amount', p_amount,
            'payment_method', v_method,
            'category', TRIM(p_category),
            'description', TRIM(p_description),
            'voucher_ref', TRIM(p_voucher_ref),
            'remaining_channel_balance', v_available - p_amount,
            'actor_name', v_snap.actor_name,
            'actor_role', v_snap.actor_role,
            'created_at', now()
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_registrar_abono(
    p_client_id UUID,
    p_amount NUMERIC,
    p_payment_method TEXT,
    p_notes TEXT DEFAULT NULL::text
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_store_id UUID;
    v_client public.clients%ROWTYPE;
    v_employee_id UUID;
    v_snap RECORD;
    v_session_id UUID;
    v_session_opened_at TIMESTAMPTZ;
    v_new_balance NUMERIC;
    v_cash_movement_id UUID;
    v_ledger_id UUID;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'El monto del abono debe ser mayor a cero (INVALID_AMOUNT)' USING ERRCODE = 'P0001';
    END IF;

    IF p_payment_method NOT IN ('efectivo', 'nequi', 'llave_bre') THEN
        RAISE EXCEPTION 'Método de pago no válido para abono: % (INVALID_PAYMENT_METHOD)', p_payment_method USING ERRCODE = 'P0001';
    END IF;

    v_store_id := public.get_current_store_id();
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'STORE_ACCESS_DENIED' USING ERRCODE = '42501';
    END IF;
    PERFORM public.assert_store_access(v_store_id);

    SELECT * INTO v_client
    FROM public.clients
    WHERE id = p_client_id
      AND store_id = v_store_id
      AND COALESCE(is_deleted, false) = false
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cliente no encontrado (CLIENT_NOT_FOUND)' USING ERRCODE = 'P0001';
    END IF;

    IF v_client.balance <= 0 THEN
        RAISE EXCEPTION 'El cliente no tiene saldo deudor pendiente (NO_OUTSTANDING_DEBT)' USING ERRCODE = 'P0001';
    END IF;

    IF p_amount > v_client.balance THEN
        RAISE EXCEPTION 'El abono ($%) supera la deuda actual ($%) (AMOUNT_EXCEEDS_DEBT)',
            p_amount, v_client.balance USING ERRCODE = 'P0001';
    END IF;

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

    SELECT * INTO v_snap FROM public.resolve_actor_snapshot(v_store_id);
    SELECT e.id INTO v_employee_id
    FROM public.employees e
    WHERE e.id = COALESCE(public.get_employee_id_from_session(), auth.uid())
      AND e.store_id = v_store_id
    LIMIT 1;

    v_new_balance := v_client.balance - p_amount;
    UPDATE public.clients
    SET balance = v_new_balance, updated_at = NOW()
    WHERE id = p_client_id;

    INSERT INTO public.client_ledger (
        client_id, store_id, amount, previous_balance, reference_id, transaction_type, created_by, actor_name, actor_role
    ) VALUES (
        p_client_id, v_client.store_id, -p_amount, v_client.balance, NULL, 'abono', v_employee_id, v_snap.actor_name, v_snap.actor_role
    ) RETURNING id INTO v_ledger_id;

    INSERT INTO public.cash_movements (
        session_id, movement_type, amount, description, payment_method, category, actor_id, actor_name, actor_role
    ) VALUES (
        v_session_id, 'ingreso', p_amount, '[ABONO_CLIENTE: ' || v_client.name || '] ' || COALESCE(p_notes, ''), p_payment_method, 'abono_cliente', v_employee_id, v_snap.actor_name, v_snap.actor_role
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
            'actor_name', v_snap.actor_name,
            'actor_role', v_snap.actor_role,
            'created_at', NOW()
        )
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_daily_summary(
    p_store_id UUID,
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_total_sales NUMERIC DEFAULT 0;
    v_avg_sales_7d NUMERIC DEFAULT 0;
    v_breakdown JSONB;
    v_alerts JSONB;
    v_traffic_status TEXT;
    v_traffic_message TEXT;
    v_start_date TIMESTAMPTZ;
    v_end_date TIMESTAMPTZ;
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    v_start_date := p_date::TIMESTAMPTZ;
    v_end_date := v_start_date + INTERVAL '1 day';

    SELECT COALESCE(SUM(total), 0) INTO v_total_sales
    FROM public.sales
    WHERE store_id = p_store_id AND created_at >= v_start_date AND created_at < v_end_date AND is_voided = FALSE;

    SELECT jsonb_object_agg(method_group, amount) INTO v_breakdown
    FROM (
        SELECT
            CASE WHEN payment_method IN ('nequi', 'llave_bre') THEN 'transfer' WHEN payment_method = 'fiado' THEN 'credit' ELSE 'cash' END AS method_group,
            SUM(total) AS amount
        FROM public.sales
        WHERE store_id = p_store_id AND created_at >= v_start_date AND created_at < v_end_date AND is_voided = FALSE
        GROUP BY 1
    ) sub;

    v_breakdown := jsonb_build_object(
        'cash', COALESCE((v_breakdown->>'cash')::NUMERIC, 0),
        'transfer', COALESCE((v_breakdown->>'transfer')::NUMERIC, 0),
        'credit', COALESCE((v_breakdown->>'credit')::NUMERIC, 0)
    );

    SELECT COALESCE(AVG(daily_total), 0) INTO v_avg_sales_7d
    FROM (
        SELECT DATE(created_at) AS day, SUM(total) AS daily_total
        FROM public.sales
        WHERE store_id = p_store_id AND created_at >= (v_start_date - INTERVAL '7 days') AND created_at < v_start_date AND is_voided = FALSE
        GROUP BY 1
    ) past_sales;

    IF v_avg_sales_7d = 0 THEN
        v_traffic_status := 'gray';
        v_traffic_message := 'Recopilando datos históricos...';
    ELSIF v_total_sales >= (v_avg_sales_7d * 1.05) THEN
        v_traffic_status := 'green';
        v_traffic_message := '🚀 ¡Vas un ' || ROUND(((v_total_sales - v_avg_sales_7d) / v_avg_sales_7d * 100), 0) || '% arriba de tu promedio!';
    ELSIF v_total_sales <= (v_avg_sales_7d * 0.95) THEN
        v_traffic_status := 'red';
        v_traffic_message := '🔻 Estás un ' || ROUND(((v_avg_sales_7d - v_total_sales) / v_avg_sales_7d * 100), 0) || '% abajo de tu promedio.';
    ELSE
        v_traffic_status := 'green';
        v_traffic_message := '👍 Ventas estables respecto a tu semana.';
    END IF;

    SELECT jsonb_agg(jsonb_build_object(
        'type', 'stock_critical',
        'message', CASE WHEN current_stock <= 0 THEN '❌ Agotado: ' || name ELSE '⚠️ Bajo stock: ' || name END,
        'target_id', id,
        'stock', current_stock
    ))
    INTO v_alerts
    FROM public.products
    WHERE store_id = p_store_id AND current_stock <= min_stock
    LIMIT 5;

    IF v_alerts IS NULL THEN v_alerts := '[]'::JSONB; END IF;

    RETURN jsonb_build_object(
        'traffic_light', jsonb_build_object('status', v_traffic_status, 'message', v_traffic_message),
        'hero_number', v_total_sales,
        'money_breakdown', v_breakdown,
        'alerts', v_alerts,
        'reminder', jsonb_build_object('message', CASE WHEN v_total_sales = 0 THEN '¡Abre caja para empezar a vender!' ELSE 'Recuerda hacer el cierre de caja al final del turno.' END)
    );
END;
$$;

-- Actualizar rpc_log_security_event para estampar actor_name/actor_role y persistir intentos denegados en audit_seguridad + audit_logs
CREATE OR REPLACE FUNCTION public.rpc_log_security_event(
    p_event_type TEXT,
    p_store_id UUID DEFAULT NULL::uuid,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_event TEXT := UPPER(TRIM(COALESCE(p_event_type, '')));
    v_employee_id UUID;
    v_actor_name TEXT := 'Sistema';
    v_actor_role TEXT := 'employee';
    v_snap RECORD;
    v_ip TEXT;
    v_user_agent TEXT;
BEGIN
    IF v_event NOT IN (
        'LOGIN_SUCCESS', 'LOGIN_FAILED', 'PIN_CHANGE',
        'UNAUTHORIZED_ACCESS', 'FORCE_SALE', 'SESSION_EXPIRED',
        'ROLE_CHANGE', 'EMPLOYEE_DEACTIVATED',
        'DEVICE_ACCESS_APPROVE', 'DEVICE_ACCESS_REJECT', 'DEVICE_ACCESS_REVOKE',
        'CONCURRENT_MUTATION_BLOCKED'
    ) THEN
        RAISE EXCEPTION 'Tipo de evento de seguridad no válido: %', p_event_type
            USING ERRCODE = '22023';
    END IF;

    IF p_store_id IS NOT NULL THEN
        PERFORM public.assert_store_access(p_store_id);
        SELECT * INTO v_snap FROM public.resolve_actor_snapshot(p_store_id);
        v_actor_name := COALESCE(v_snap.actor_name, 'Sistema');
        v_actor_role := COALESCE(v_snap.actor_role, 'employee');
    END IF;

    SELECT id INTO v_employee_id
    FROM public.employees
    WHERE id = COALESCE(public.get_employee_id_from_session(), auth.uid())
      AND (p_store_id IS NULL OR store_id = p_store_id)
    LIMIT 1;

    BEGIN
        v_ip := current_setting('request.headers', true)::json->>'x-forwarded-for';
        v_user_agent := current_setting('request.headers', true)::json->>'user-agent';
    EXCEPTION WHEN OTHERS THEN
        v_ip := NULL;
        v_user_agent := NULL;
    END;

    INSERT INTO public.audit_seguridad (
        actor_id, actor_name, actor_role, store_id, event_type, ip_address, user_agent, metadata
    ) VALUES (
        v_employee_id,
        v_actor_name,
        v_actor_role,
        p_store_id,
        v_event,
        v_ip,
        v_user_agent,
        COALESCE(p_metadata, '{}'::jsonb)
    );

    IF p_store_id IS NOT NULL THEN
        INSERT INTO public.audit_logs (
            actor_id, actor_name, actor_role, store_id, event_type, resource_id, metadata, severity
        ) VALUES (
            v_employee_id,
            v_actor_name,
            v_actor_role,
            p_store_id,
            v_event,
            COALESCE(p_metadata->>'resource_id', p_metadata->>'permission_key', p_store_id::text),
            COALESCE(p_metadata, '{}'::jsonb),
            COALESCE(NULLIF(p_metadata->>'severity', ''), 'warning')
        );
    END IF;
END;
$$;

-- Alinear trigger de alta de tienda con el esquema cerrado de 4 permisos (chk_employees_permissions_4_keys)
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

    INSERT INTO public.employees (
        id, store_id, name, username, pin_hash, permissions, is_active, created_at, updated_at
    ) VALUES (
        new.id,
        v_new_store_id,
        COALESCE(NULLIF(trim(new.raw_user_meta_data->>'owner_name'), ''), 'Propietario'),
        'owner_' || left(new.id::text, 8),
        '$2a$10$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        jsonb_build_object(
            'canManageInventory', true,
            'canFiar', true,
            'canOpenCloseCash', true,
            'canManageRefunds', true
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
    RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_history_caja(
    p_store_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_result JSONB;
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    SELECT COALESCE(jsonb_agg(row_data ORDER BY COALESCE(closed_at, opened_at) DESC, opened_at DESC), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT jsonb_build_object(
            'id', cs.id,
            'status', cs.status,
            'event_type', CASE WHEN cs.status = 'closed' THEN 'CIERRE' ELSE 'APERTURA' END,
            'reconciliation_status', CASE
                WHEN cs.status = 'open' THEN 'open'
                WHEN COALESCE(cs.forced_close, false) = true AND cs.actual_balance IS NULL THEN 'forced_pending_reconciliation'
                WHEN COALESCE(cs.forced_close, false) = true AND cs.actual_balance IS NOT NULL THEN 'forced_reconciled'
                ELSE 'closed_reconciled'
            END,
            'opening_balance', cs.opening_balance,
            'actual_balance', cs.actual_balance,
            'expected_balance', cs.expected_balance,
            'difference', cs.difference,
            'net_session_balance', (
                cs.opening_balance
                + COALESCE((
                    SELECT SUM(cm.amount)
                    FROM public.cash_movements cm
                    WHERE cm.session_id = cs.id AND cm.movement_type = 'ingreso'
                ), 0)
                - COALESCE((
                    SELECT SUM(cm.amount)
                    FROM public.cash_movements cm
                    WHERE cm.session_id = cs.id AND cm.movement_type IN ('gasto', 'pago_proveedor')
                ), 0)
            ),
            'opened_by_name', COALESCE(cs.opened_by_name, eo.name, ap_open.id::text, 'Desconocido'),
            'opened_by_role', cs.opened_by_role,
            'closed_by_name', COALESCE(cs.closed_by_name, ec.name, ap_close.id::text, NULL),
            'closed_by_role', cs.closed_by_role,
            'opened_at', cs.opened_at,
            'closed_at', cs.closed_at,
            'forced_close', COALESCE(cs.forced_close, false),
            'total_movements', (SELECT COUNT(*) FROM public.cash_movements cm WHERE cm.session_id = cs.id),
            'total_income', (
                SELECT COALESCE(SUM(cm.amount), 0)
                FROM public.cash_movements cm
                WHERE cm.session_id = cs.id AND cm.movement_type = 'ingreso'
            ),
            'total_expenses', (
                SELECT COALESCE(SUM(cm.amount), 0)
                FROM public.cash_movements cm
                WHERE cm.session_id = cs.id AND cm.movement_type IN ('gasto', 'pago_proveedor')
            ),
            'income_efectivo', (
                SELECT COALESCE(SUM(cm.amount), 0)
                FROM public.cash_movements cm
                WHERE cm.session_id = cs.id AND cm.movement_type = 'ingreso' AND cm.payment_method = 'efectivo'
            ),
            'income_nequi', (
                SELECT COALESCE(SUM(cm.amount), 0)
                FROM public.cash_movements cm
                WHERE cm.session_id = cs.id AND cm.movement_type = 'ingreso' AND cm.payment_method = 'nequi'
            ),
            'income_llave_bre', (
                SELECT COALESCE(SUM(cm.amount), 0)
                FROM public.cash_movements cm
                WHERE cm.session_id = cs.id AND cm.movement_type = 'ingreso' AND cm.payment_method = 'llave_bre'
            )
        ) AS row_data,
        cs.opened_at,
        cs.closed_at
        FROM public.cash_sessions cs
        LEFT JOIN public.employees eo ON eo.id = cs.opened_by
        LEFT JOIN public.employees ec ON ec.id = cs.closed_by
        LEFT JOIN public.admin_profiles ap_open ON ap_open.id = cs.opened_by
        LEFT JOIN public.admin_profiles ap_close ON ap_close.id = cs.closed_by
        WHERE cs.store_id = p_store_id
          AND (
              (cs.opened_at AT TIME ZONE 'America/Bogota')::DATE BETWEEN p_start_date AND p_end_date
              OR (cs.closed_at IS NOT NULL AND (cs.closed_at AT TIME ZONE 'America/Bogota')::DATE BETWEEN p_start_date AND p_end_date)
          )
        LIMIT 100
    ) sub;

    RETURN v_result;
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION public.rpc_get_comprehensive_financial_report(
    p_store_id UUID,
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_employee_id UUID DEFAULT NULL::uuid
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_start_ts          TIMESTAMPTZ;
    v_end_ts            TIMESTAMPTZ;
    v_revenue           NUMERIC DEFAULT 0;
    v_cogs              NUMERIC DEFAULT 0;
    v_gross_profit      NUMERIC DEFAULT 0;
    v_gross_margin      NUMERIC DEFAULT 0;
    v_op_expenses       NUMERIC DEFAULT 0;
    v_net_profit        NUMERIC DEFAULT 0;
    v_inventory_value   NUMERIC DEFAULT 0;
    v_payment_breakdown JSONB;
    v_fiado_pendiente   NUMERIC DEFAULT 0;
    v_avg_sales_7d      NUMERIC DEFAULT 0;
    v_traffic_status    TEXT;
    v_traffic_message   TEXT;
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION 'La fecha de inicio no puede ser posterior a la fecha de fin (INVALID_DATE_RANGE)' USING ERRCODE = 'P0001';
    END IF;

    IF (p_end_date - p_start_date) > 366 THEN
        RAISE EXCEPTION 'El rango máximo permitido para el reporte financiero es de 366 días (RANGE_EXCEEDS_MAX_LIMIT)' USING ERRCODE = 'P0001';
    END IF;

    IF p_employee_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.employees WHERE id = p_employee_id AND store_id = p_store_id) THEN
            RAISE EXCEPTION 'El colaborador seleccionado no pertenece a este establecimiento (EMPLOYEE_NOT_FOUND)' USING ERRCODE = 'P0001';
        END IF;
    END IF;

    v_start_ts := p_start_date::TIMESTAMPTZ;
    v_end_ts   := (p_end_date + INTERVAL '1 day')::TIMESTAMPTZ;

    SELECT COALESCE(SUM(total), 0)
    INTO v_revenue
    FROM public.sales
    WHERE store_id  = p_store_id
      AND created_at >= v_start_ts
      AND created_at <  v_end_ts
      AND is_voided  = FALSE;

    SELECT COALESCE(SUM(sib.quantity_consumed * sib.unit_cost), 0)
    INTO v_cogs
    FROM public.sale_item_batches sib
    JOIN public.sale_items si ON sib.sale_item_id = si.id
    JOIN public.sales s       ON si.sale_id       = s.id
    WHERE s.store_id  = p_store_id
      AND s.created_at >= v_start_ts
      AND s.created_at <  v_end_ts
      AND s.is_voided  = FALSE;

    v_gross_profit := v_revenue - v_cogs;
    IF v_revenue > 0 THEN
        v_gross_margin := ROUND((v_gross_profit / v_revenue) * 100, 2);
    END IF;

    SELECT COALESCE(SUM(cm.amount), 0)
    INTO v_op_expenses
    FROM public.cash_movements cm
    JOIN public.cash_sessions  cs ON cm.session_id = cs.id
    WHERE cs.store_id      = p_store_id
      AND cm.movement_type = 'gasto'
      AND cm.created_at   >= v_start_ts
      AND cm.created_at   <  v_end_ts;

    v_net_profit := v_gross_profit - v_op_expenses;

    SELECT COALESCE(SUM(ib.quantity_remaining * ib.cost_unit), 0)
    INTO v_inventory_value
    FROM public.inventory_batches ib
    JOIN public.products p ON ib.product_id = p.id
    WHERE p.store_id              = p_store_id
      AND ib.is_active            = TRUE
      AND ib.quantity_remaining   > 0;

    SELECT jsonb_build_object(
        'cash',     COALESCE(SUM(total) FILTER (
                        WHERE payment_method = 'efectivo'
                    ), 0),
        'transfer', COALESCE(SUM(total) FILTER (
                        WHERE payment_method IN ('nequi', 'llave_bre')
                    ), 0),
        'credit',   COALESCE(SUM(total) FILTER (
                        WHERE payment_method = 'fiado'
                    ), 0)
    )
    INTO v_payment_breakdown
    FROM public.sales
    WHERE store_id  = p_store_id
      AND created_at >= v_start_ts
      AND created_at <  v_end_ts
      AND is_voided  = FALSE;

    SELECT COALESCE(SUM(balance), 0)
    INTO v_fiado_pendiente
    FROM public.clients
    WHERE store_id  = p_store_id
      AND (is_deleted = FALSE OR is_deleted IS NULL)
      AND balance    > 0;

    SELECT COALESCE(AVG(daily_total), 0)
    INTO v_avg_sales_7d
    FROM (
        SELECT DATE(created_at) AS day, SUM(total) AS daily_total
        FROM public.sales
        WHERE store_id  = p_store_id
          AND created_at >= (v_start_ts - INTERVAL '7 days')
          AND created_at <   v_start_ts
          AND is_voided  = FALSE
        GROUP BY 1
    ) past;

    IF v_avg_sales_7d = 0 THEN
        v_traffic_status  := 'gray';
        v_traffic_message := 'Recopilando datos históricos...';
    ELSIF v_revenue >= (v_avg_sales_7d * 1.05) THEN
        v_traffic_status  := 'green';
        v_traffic_message := '🚀 ¡Vas un '
            || ROUND(((v_revenue - v_avg_sales_7d) / v_avg_sales_7d * 100), 0)
            || '% arriba de tu promedio!';
    ELSIF v_revenue <= (v_avg_sales_7d * 0.95) THEN
        v_traffic_status  := 'red';
        v_traffic_message := '🔻 Estás un '
            || ROUND(((v_avg_sales_7d - v_revenue) / v_avg_sales_7d * 100), 0)
            || '% abajo de tu promedio.';
    ELSE
        v_traffic_status  := 'green';
        v_traffic_message := '👍 Ventas estables respecto a tu semana.';
    END IF;

    RETURN jsonb_build_object(
        'period', jsonb_build_object(
            'start', p_start_date,
            'end',   p_end_date
        ),
        'revenue',               v_revenue,
        'cogs',                  v_cogs,
        'gross_profit',          v_gross_profit,
        'gross_margin',          v_gross_margin,
        'operational_expenses',  v_op_expenses,
        'net_profit',            v_net_profit,
        'inventory_value',       v_inventory_value,
        'payment_breakdown',     v_payment_breakdown,
        'fiado_pendiente',       v_fiado_pendiente,
        'traffic_light', jsonb_build_object(
            'status',  v_traffic_status,
            'message', v_traffic_message
        )
    );
END;
$$;

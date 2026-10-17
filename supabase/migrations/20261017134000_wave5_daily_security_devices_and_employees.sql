-- ==============================================================================
-- Migración Ola 5: Seguridad Diaria (D-03), Dispositivos y Tope de Empleados
-- Archivo: 20261017134000_wave5_daily_security_devices_and_employees.sql
-- SDDs certificados: SDD_001 (Seguridad Diaria), SDD_002, SDD_002_1,
--                    SDD_003 (Gestión de Empleados), SDD_011, SDD_012,
--                    SDD_013 (Gestión de Sesiones), SDD_015 (Gestión Dispositivos),
--                    SDD_028 (Almacenamiento Local)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. DECISIÓN D-03: Desacople Definitivo de Pase Diario y Cierre de Caja
--    (FRD-001 RN-3, RN-4 / SDD_001 Deuda D-1 / CA-FRD-001-08 al 10)
--    El cierre de caja NO revoca el pase diario. Se eliminan el trigger y la
--    función legacy que marcaban status = 'expired' en daily_passes al cerrar caja.
-- ------------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_expire_passes_on_cash_close ON public.cash_sessions;
DROP FUNCTION IF EXISTS public.expire_daily_passes();

-- ------------------------------------------------------------------------------
-- 2. AJUSTES DE ESQUEMA EN daily_passes Y audit_seguridad
--    Flexibilización de FK en resolved_by y approved_by para soportar auth.users(id)
--    Ampliación de audit_seguridad_event_type_check para eventos de dispositivos
-- ------------------------------------------------------------------------------
ALTER TABLE public.daily_passes DROP CONSTRAINT IF EXISTS daily_passes_resolved_by_fkey;
ALTER TABLE public.daily_passes DROP CONSTRAINT IF EXISTS daily_passes_approved_by_fkey;

CREATE INDEX IF NOT EXISTS idx_daily_passes_store_date_status
    ON public.daily_passes (store_id, pass_date, status);

ALTER TABLE public.audit_seguridad DROP CONSTRAINT IF EXISTS audit_seguridad_event_type_check;
ALTER TABLE public.audit_seguridad ADD CONSTRAINT audit_seguridad_event_type_check
CHECK (event_type = ANY (ARRAY[
    'LOGIN_SUCCESS'::text, 
    'LOGIN_FAILED'::text, 
    'PIN_CHANGE'::text, 
    'UNAUTHORIZED_ACCESS'::text, 
    'FORCE_SALE'::text, 
    'SESSION_EXPIRED'::text, 
    'ROLE_CHANGE'::text, 
    'EMPLOYEE_DEACTIVATED'::text,
    'DEVICE_ACCESS_APPROVE'::text,
    'DEVICE_ACCESS_REJECT'::text,
    'DEVICE_ACCESS_REVOKE'::text
]));

-- ------------------------------------------------------------------------------
-- 3. UNIFICACIÓN DE SOLICITUD DE PASE DIARIO: public.solicitar_pase_diario
--    (SDD_001 v2.0 Deuda D-2 / RN-7 / Límite de 3 Reintentos MAX_RETRIES)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.solicitar_pase_diario(uuid, text);

CREATE OR REPLACE FUNCTION public.solicitar_pase_diario(
    p_employee_id UUID,
    p_device_fingerprint TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_employee RECORD;
    v_existing_pass RECORD;
    v_pass_id UUID;
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
BEGIN
    -- 1. Validar existencia y vigencia del empleado
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

    -- 2. Consultar pase del día de hoy en Bogotá
    SELECT * INTO v_existing_pass
    FROM public.daily_passes
    WHERE employee_id = p_employee_id
      AND pass_date = v_today;

    IF FOUND THEN
        -- Si ya está aprobado hoy, conceder acceso inmediato
        IF v_existing_pass.status = 'approved' THEN
            RETURN jsonb_build_object(
                'success', true,
                'status', 'approved',
                'pass_id', v_existing_pass.id,
                'retry_count', COALESCE(v_existing_pass.retry_count, 0)
            );
        END IF;

        -- Si está pendiente, validar límite estricto de 3 intentos (RN-7)
        IF v_existing_pass.status = 'pending' THEN
            IF COALESCE(v_existing_pass.retry_count, 0) >= 3 THEN
                RETURN jsonb_build_object(
                    'success', false,
                    'error', 'Límite de intentos alcanzado. Contacte a su supervisor.',
                    'code', 'MAX_RETRIES',
                    'retry_count', v_existing_pass.retry_count
                );
            END IF;

            -- Incrementar reintento
            UPDATE public.daily_passes
            SET retry_count = COALESCE(retry_count, 0) + 1,
                device_fingerprint = COALESCE(p_device_fingerprint, device_fingerprint, 'N/A'),
                requested_at = now(),
                updated_at = now()
            WHERE id = v_existing_pass.id;

            -- Notificación en tiempo real para el Administrador
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

        -- Si ya fue rechazado o expiró hoy
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Pase ya procesado para hoy (' || v_existing_pass.status || ')',
            'code', 'ALREADY_PROCESSED'
        );
    END IF;

    -- 3. Inserción de nueva solicitud en estado 'pending'
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

    -- Alerta prioritaria para el Administrador
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

-- ------------------------------------------------------------------------------
-- 4. CONSOLIDACIÓN DE INGRESO OPERATIVO: public.request_employee_access
--    (SDD_001 v2.0 §5.1 / Valida username, PIN criptográfico y emite pase)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.request_employee_access(text, text, text);

CREATE OR REPLACE FUNCTION public.request_employee_access(
    p_username TEXT,
    p_pin TEXT,
    p_device_fingerprint TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_employee RECORD;
    v_existing_pass RECORD;
    v_pass_id UUID;
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
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

    -- 2. Validar hash criptográfico de PIN
    IF v_employee.pin_hash IS NULL OR v_employee.pin_hash <> crypt(p_pin, v_employee.pin_hash) THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'INVALID_CREDENTIALS',
            'message', 'PIN Incorrecto'
        );
    END IF;

    -- 3. Consultar pase del día en curso
    SELECT * INTO v_existing_pass
    FROM public.daily_passes
    WHERE employee_id = v_employee.id
      AND pass_date = v_today;

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
                    'permissions', v_employee.permissions
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
                    'permissions', v_employee.permissions
                )
            );
        END IF;

        RETURN jsonb_build_object(
            'success', false,
            'code', 'ALREADY_PROCESSED',
            'message', 'Pase ya procesado hoy: ' || v_existing_pass.status
        );
    END IF;

    -- 4. Inserción inicial en daily_passes
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
        p_device_fingerprint,
        'pending',
        v_today,
        0,
        now(),
        now(),
        auth.uid()
    )
    RETURNING id INTO v_pass_id;

    -- Alerta Realtime para Administrador
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
            'permissions', v_employee.permissions
        )
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

-- ------------------------------------------------------------------------------
-- 5. RPC GESTIÓN CENTRALIZADA DE DISPOSITIVOS: public.rpc_gestionar_dispositivo
--    (SDD_015 v2.0 §3.1 / SDD_013 / Deuda D-2 / Acciones approve, reject, revoke)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.rpc_gestionar_dispositivo(uuid, text);

CREATE OR REPLACE FUNCTION public.rpc_gestionar_dispositivo(
    p_pass_id UUID,
    p_action TEXT -- 'approve', 'reject', 'revoke'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pass RECORD;
    v_actor_id UUID := auth.uid();
    v_is_admin BOOLEAN := false;
    v_new_status TEXT;
    v_active_employees INTEGER;
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
BEGIN
    -- 1. Bloquear fila del pase
    SELECT * INTO v_pass
    FROM public.daily_passes
    WHERE id = p_pass_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PASS_NOT_FOUND: El pase especificado (%) no existe.', p_pass_id
            USING ERRCODE = 'P0002';
    END IF;

    -- 2. Aislamiento multi-tenant estricto (Regla 4)
    PERFORM public.assert_store_access(v_pass.store_id);

    -- 3. Validar perfil administrativo si la llamada proviene de un usuario autenticado
    IF v_actor_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.admin_profiles
            WHERE id = v_actor_id AND store_id = v_pass.store_id
        ) INTO v_is_admin;

        IF NOT v_is_admin THEN
            RAISE EXCEPTION 'UNAUTHORIZED_ACTOR: Solo el Administrador puede gestionar dispositivos.'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- 4. Transición de estado y reglas de negocio
    IF p_action = 'approve' THEN
        IF v_pass.pass_date <> v_today THEN
            RAISE EXCEPTION 'EXPIRED_PASS_DATE: No se puede aprobar un pase de una fecha distinta al día actual.'
                USING ERRCODE = 'P0001';
        END IF;

        -- Límite estricto de concurrencia: Máximo 5 terminales de empleados activas hoy (SDD_013)
        SELECT COUNT(*) INTO v_active_employees
        FROM public.daily_passes
        WHERE store_id = v_pass.store_id
          AND pass_date = v_pass.pass_date
          AND status = 'approved'
          AND id <> v_pass.id;

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

    -- 5. Registro obligatorio atómico en bitácoras de auditoría (CA-015-07)
    INSERT INTO public.audit_logs (
        actor_id, event_type, resource_id, metadata, store_id, severity
    ) VALUES (
        v_actor_id,
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
        actor_id, store_id, event_type, metadata
    ) VALUES (
        v_actor_id,
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

-- Wrapper retrocompatible para aprobar_pase_diario
DROP FUNCTION IF EXISTS public.aprobar_pase_diario(uuid, uuid);

CREATE OR REPLACE FUNCTION public.aprobar_pase_diario(
    p_pass_id UUID,
    p_admin_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN public.rpc_gestionar_dispositivo(p_pass_id, 'approve');
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

-- ------------------------------------------------------------------------------
-- 6. GESTIÓN Y TOPE DE EMPLEADOS: public.crear_empleado
--    (SDD_003 v2.0 §5.1 / Límite de 5 Empleados Activos EMPLOYEE_LIMIT_REACHED)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.crear_empleado(uuid, text, text, text, jsonb);

CREATE OR REPLACE FUNCTION public.crear_empleado(
    p_store_id UUID,
    p_name TEXT,
    p_username TEXT,
    p_pin TEXT,
    p_permissions JSONB DEFAULT '{}'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_count INTEGER;
    v_employee_id UUID;
BEGIN
    -- 1. Aislamiento multi-tenant
    PERFORM public.assert_store_access(p_store_id);

    -- 2. Validar que el actor sea administrador (si viene autenticado)
    IF auth.uid() IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid() AND store_id = p_store_id
    ) THEN
        RAISE EXCEPTION 'UNAUTHORIZED: Solo el administrador puede crear empleados'
            USING ERRCODE = '42501';
    END IF;

    -- 3. Validar formato estricto de PIN de 4 dígitos
    IF p_pin !~ '^[0-9]{4}$' THEN
        RAISE EXCEPTION 'INVALID_PIN_FORMAT: El PIN debe ser numérico de exactamente 4 dígitos'
            USING ERRCODE = '22023';
    END IF;

    -- 4. Validar límite estricto de 5 empleados activos simultáneos
    SELECT COUNT(*) INTO v_count
    FROM public.employees
    WHERE store_id = p_store_id AND is_active = true;

    IF v_count >= 5 THEN
        RAISE EXCEPTION 'EMPLOYEE_LIMIT_REACHED: Límite de 5 empleados activos alcanzado para la tienda'
            USING ERRCODE = 'P0001';
    END IF;

    -- 5. Validar unicidad global del alias
    IF EXISTS (SELECT 1 FROM public.employees WHERE LOWER(username) = LOWER(p_username)) THEN
        RAISE EXCEPTION 'USERNAME_ALREADY_EXISTS: El alias ya está registrado en el sistema'
            USING ERRCODE = '23505';
    END IF;

    -- 6. Inserción segura con PIN hasheado (Blowfish)
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
        crypt(p_pin, gen_salt('bf')),
        COALESCE(p_permissions, '{}'::JSONB),
        true,
        now(),
        now()
    )
    RETURNING id INTO v_employee_id;

    -- 7. Auditoría
    INSERT INTO public.audit_logs (
        actor_id, event_type, resource_id, metadata, store_id, severity
    ) VALUES (
        auth.uid(),
        'EMPLOYEE_CREATED',
        v_employee_id::text,
        jsonb_build_object('name', p_name, 'username', p_username),
        p_store_id,
        'info'
    );

    RETURN jsonb_build_object(
        'success', true,
        'employee_id', v_employee_id
    );
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

-- ------------------------------------------------------------------------------
-- 7. CONMUTACIÓN DE ESTADO Y REVOCACIÓN ATÓMICA: public.toggle_empleado_activo
--    (SDD_003 v2.0 §5.2 / Deuda D-2 / Expulsión inmediata de pases aprobados)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.toggle_empleado_activo(uuid, boolean);

CREATE OR REPLACE FUNCTION public.toggle_empleado_activo(
    p_employee_id UUID,
    p_new_status BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_emp RECORD;
    v_count INTEGER;
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
BEGIN
    -- 1. Bloquear fila del empleado
    SELECT * INTO v_emp
    FROM public.employees
    WHERE id = p_employee_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'EMPLOYEE_NOT_FOUND: Empleado especificado no existe.'
            USING ERRCODE = 'P0002';
    END IF;

    -- 2. Aislamiento multi-tenant
    PERFORM public.assert_store_access(v_emp.store_id);

    -- 3. Validar administrador
    IF auth.uid() IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid() AND store_id = v_emp.store_id
    ) THEN
        RAISE EXCEPTION 'UNAUTHORIZED: Solo el administrador puede modificar el estado de colaboradores'
            USING ERRCODE = '42501';
    END IF;

    -- 4. Si se va a reactivar, validar cupo de 5 activos
    IF p_new_status IS TRUE THEN
        SELECT COUNT(*) INTO v_count
        FROM public.employees
        WHERE store_id = v_emp.store_id AND is_active = true AND id <> p_employee_id;

        IF v_count >= 5 THEN
            RAISE EXCEPTION 'LIMIT_REACHED: Límite de 5 empleados activos alcanzado para la tienda'
                USING ERRCODE = 'P0001';
        END IF;
    END IF;

    -- 5. Si se va a desactivar, revocar de inmediato cualquier pase diario aprobado hoy
    IF p_new_status IS FALSE THEN
        UPDATE public.daily_passes
        SET status = 'rejected',
            resolved_at = now(),
            resolved_by = auth.uid(),
            updated_at = now()
        WHERE employee_id = p_employee_id
          AND pass_date = v_today
          AND status = 'approved';
    END IF;

    -- 6. Actualizar estado
    UPDATE public.employees
    SET is_active = p_new_status,
        updated_at = now()
    WHERE id = p_employee_id;

    -- 7. Registro de auditoría
    INSERT INTO public.audit_logs (
        actor_id, event_type, resource_id, metadata, store_id, severity
    ) VALUES (
        auth.uid(),
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

-- Alias retrocompatible: public.toggle_employee_status
DROP FUNCTION IF EXISTS public.toggle_employee_status(uuid, boolean);

CREATE OR REPLACE FUNCTION public.toggle_employee_status(
    p_employee_id UUID,
    p_new_status BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN public.toggle_empleado_activo(p_employee_id, p_new_status);
END;
$$;

-- ------------------------------------------------------------------------------
-- 8. RESTABLECIMIENTO ADMINISTRATIVO DE PIN: public.actualizar_pin_empleado
--    (SDD_003 v2.0 §5.3 / Blowfish crypt hash / Validación de formato 4 dígitos)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.actualizar_pin_empleado(uuid, text);

CREATE OR REPLACE FUNCTION public.actualizar_pin_empleado(
    p_employee_id UUID,
    p_new_pin TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_emp RECORD;
BEGIN
    -- 1. Bloquear fila del empleado
    SELECT * INTO v_emp
    FROM public.employees
    WHERE id = p_employee_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'EMPLOYEE_NOT_FOUND: Empleado no encontrado'
            USING ERRCODE = 'P0002';
    END IF;

    -- 2. Aislamiento multi-tenant
    PERFORM public.assert_store_access(v_emp.store_id);

    -- 3. Validar administrador
    IF auth.uid() IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.admin_profiles
        WHERE id = auth.uid() AND store_id = v_emp.store_id
    ) THEN
        RAISE EXCEPTION 'UNAUTHORIZED: Solo el administrador puede actualizar el PIN de un empleado'
            USING ERRCODE = '42501';
    END IF;

    -- 4. Validar formato estricto de 4 dígitos
    IF p_new_pin !~ '^[0-9]{4}$' THEN
        RAISE EXCEPTION 'INVALID_PIN_FORMAT: El PIN debe ser numérico de exactamente 4 dígitos'
            USING ERRCODE = '22023';
    END IF;

    -- 5. Actualizar hash de PIN
    UPDATE public.employees
    SET pin_hash = crypt(p_new_pin, gen_salt('bf')),
        updated_at = now()
    WHERE id = p_employee_id;

    -- 6. Auditoría forense sin persistir el PIN en plano
    INSERT INTO public.audit_logs (
        actor_id, event_type, resource_id, metadata, store_id, severity
    ) VALUES (
        auth.uid(),
        'PIN_RESET',
        p_employee_id::text,
        jsonb_build_object('employee_id', p_employee_id),
        v_emp.store_id,
        'warning'
    );

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

-- ------------------------------------------------------------------------------
-- 9. CONSULTA CENTRALIZADA DE EMPLEADOS: public.rpc_obtener_empleados
--    (SDD_003 v2.0 Deuda D-1 / H14 / Filtros de búsqueda y estatus)
-- ------------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.rpc_obtener_empleados(uuid, text, text);

CREATE OR REPLACE FUNCTION public.rpc_obtener_empleados(
    p_store_id UUID,
    p_status_filter TEXT DEFAULT 'all', -- 'all', 'active', 'inactive'
    p_search TEXT DEFAULT NULL
)
RETURNS TABLE (
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
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    PERFORM public.assert_store_access(p_store_id);

    RETURN QUERY
    SELECT 
        e.id,
        e.store_id,
        e.name,
        e.username,
        ''::TEXT AS pin, -- Máscara de seguridad: nunca exponer el hash ni el PIN
        COALESCE(e.is_active, false) AS is_active,
        COALESCE(e.permissions, '{}'::JSONB) AS permissions,
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
-- 10. PRIVILEGIOS BASE Y RLS (Regla 8 AGENTS.md)
-- ------------------------------------------------------------------------------
ALTER TABLE public.daily_passes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_seguridad ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

GRANT ALL ON TABLE public.daily_passes TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.employees TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.audit_seguridad TO anon, authenticated, service_role;
GRANT ALL ON TABLE public.notifications TO anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.solicitar_pase_diario TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.request_employee_access TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_gestionar_dispositivo TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.aprobar_pase_diario TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.crear_empleado TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.toggle_empleado_activo TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.toggle_employee_status TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.actualizar_pin_empleado TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_obtener_empleados TO anon, authenticated, service_role;

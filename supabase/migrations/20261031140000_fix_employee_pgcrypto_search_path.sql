-- Migración: Corrección de search_path y resolución pgcrypto para empleados
-- SDD: SDD_001 / SDD_003
-- Fecha: 2026-10-31
-- Descripción: Agrega el schema 'extensions' al search_path, califica explícitamente
--              las funciones extensions.gen_salt y extensions.crypt en los RPCs de empleados,
--              y añade protección de resiliencia ante hashes corruptos/vacíos.

-- 1. Asegurar extensión pgcrypto en schema extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- 2. Corregir public.crear_empleado
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
SET search_path = public, extensions
AS $$
DECLARE
    v_count INTEGER;
    v_employee_id UUID;
    v_actor_employee_id UUID;
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
    IF EXISTS (SELECT 1 FROM public.employees WHERE LOWER(username) = LOWER(p_username)) THEN
        RAISE EXCEPTION 'USERNAME_ALREADY_EXISTS: El alias ya está registrado en el sistema'
            USING ERRCODE = '23505';
    END IF;

    -- 6. Inserción segura con PIN hasheado (Blowfish via extensions.crypt / extensions.gen_salt)
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
        COALESCE(p_permissions, '{}'::JSONB),
        true,
        now(),
        now()
    )
    RETURNING id INTO v_employee_id;

    -- 7. Auditoría segura (resolviendo actor_id en employees para evitar FK violation)
    SELECT id INTO v_actor_employee_id FROM public.employees WHERE id = auth.uid();

    INSERT INTO public.audit_logs (
        actor_id, event_type, resource_id, metadata, store_id, severity
    ) VALUES (
        v_actor_employee_id,
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

-- 3. Corregir public.actualizar_pin_empleado
CREATE OR REPLACE FUNCTION public.actualizar_pin_empleado(
    p_employee_id UUID,
    p_new_pin TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_emp RECORD;
    v_actor_employee_id UUID;
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

    -- 5. Actualizar hash de PIN (Blowfish via extensions.crypt / extensions.gen_salt)
    UPDATE public.employees
    SET pin_hash = extensions.crypt(p_new_pin, extensions.gen_salt('bf')),
        updated_at = now()
    WHERE id = p_employee_id;

    -- 6. Auditoría forense sin persistir el PIN en plano
    SELECT id INTO v_actor_employee_id FROM public.employees WHERE id = auth.uid();

    INSERT INTO public.audit_logs (
        actor_id, event_type, resource_id, metadata, store_id, severity
    ) VALUES (
        v_actor_employee_id,
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

-- 4. Corregir public.request_employee_access con Resiliencia ante Hashes Inválidos/Corruptos
CREATE OR REPLACE FUNCTION public.request_employee_access(
    p_username TEXT,
    p_pin TEXT,
    p_device_fingerprint TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_employee RECORD;
    v_existing_pass RECORD;
    v_pass_id UUID;
    v_today DATE := (now() AT TIME ZONE 'America/Bogota')::date;
    v_pin_matches BOOLEAN := false;
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

    -- 2. Validar hash criptográfico de PIN de forma blindada contra hashes vacíos o corruptos
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
        -- Captura salt inválido por hash corrupto en BD sin quebrar el runtime
        v_pin_matches := false;
    END;

    IF NOT v_pin_matches THEN
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

-- 5. Privilegios de ejecución explícitos (Regla 8)
GRANT EXECUTE ON FUNCTION public.crear_empleado(UUID, TEXT, TEXT, TEXT, JSONB) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.actualizar_pin_empleado(UUID, TEXT) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION public.request_employee_access(TEXT, TEXT, TEXT) TO authenticated, anon, service_role;

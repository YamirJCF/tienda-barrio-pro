-- ==============================================================================
-- MIGRATION: FIX_REQUESTED_AT_INSERT (Revision 2)
-- Fecha: 2026-02-01
-- Autor: QA & Data Architect
-- Objetivo: Asegurar que 'requested_at' se guarde al crear el pase.
-- ERROR ANTERIOR: La tabla no tiene created_at, usamos now() para reparar.
-- ==============================================================================

-- 1. Reparar datos existentes (Sanity Check)
-- Si requested_at es nulo, le ponemos la fecha actual para que sea visible
UPDATE public.daily_passes
SET requested_at = now()
WHERE requested_at IS NULL;

-- 2. Corregir RPC para insertar explícitamente la fecha
CREATE OR REPLACE FUNCTION public.solicitar_pase_diario(
  p_employee_id UUID,
  p_device_fingerprint TEXT
)
RETURNS JSON 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_pass public.daily_passes%ROWTYPE;
  v_pass_id UUID;
  v_store_id UUID;
  v_employee_name TEXT;
  v_store_owner_email TEXT;
BEGIN
  -- 1. Obtener Dueño (Email)
  SELECT e.store_id, e.name, au.email 
  INTO v_store_id, v_employee_name, v_store_owner_email
  FROM public.employees e
  JOIN public.stores s ON e.store_id = s.id
  JOIN auth.users au ON s.owner_id = au.id
  WHERE e.id = p_employee_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Empleado o Dueño no encontrado', 'code', 'EMP_NOT_FOUND');
  END IF;

  -- 2. Buscar existente hoy
  SELECT * INTO v_existing_pass 
  FROM public.daily_passes 
  WHERE employee_id = p_employee_id AND pass_date = CURRENT_DATE;
  
  IF FOUND THEN
    IF v_existing_pass.status = 'approved' THEN
      RETURN json_build_object('success', true, 'status', 'approved', 'pass_id', v_existing_pass.id);
    END IF;
    IF v_existing_pass.status = 'pending' THEN
       -- Update retry
       UPDATE public.daily_passes 
       SET retry_count = retry_count + 1, 
           device_fingerprint = p_device_fingerprint,
           requested_at = now()
       WHERE id = v_existing_pass.id;
       
       -- Re-notificar...
       INSERT INTO public.notification_queue (type, recipient_email, payload)
       VALUES ('daily_pass_request', v_store_owner_email,
        json_build_object('employee_name', v_employee_name, 'device', p_device_fingerprint, 'attempt', v_existing_pass.retry_count + 1, 'pass_id', v_existing_pass.id)
       );
       RETURN json_build_object('success', true, 'status', 'pending', 'pass_id', v_existing_pass.id);
    END IF;
  END IF;
  
  -- 3. INSERTAR NUEVO (EL FIX ESTA AQUI)
  INSERT INTO public.daily_passes (
    employee_id, 
    device_fingerprint, 
    requested_at, -- <--- FORZAMOS FECHA
    pass_date     -- <--- FORZAMOS FECHA
  ) 
  VALUES (
    p_employee_id, 
    p_device_fingerprint, 
    now(), 
    CURRENT_DATE
  ) 
  RETURNING id INTO v_pass_id;

  INSERT INTO public.notification_queue (type, recipient_email, payload)
  VALUES ('daily_pass_request', v_store_owner_email,
    json_build_object('employee_name', v_employee_name, 'device', p_device_fingerprint, 'attempt', 1, 'pass_id', v_pass_id)
  );

  RETURN json_build_object('success', true, 'status', 'pending', 'pass_id', v_pass_id);

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM, 'code', 'DB_ERROR');
END;
$$;

-- ==============================================================================
-- MIGRATION: FIX_NOTIFICATION_RLS
-- Fecha: 2026-02-01
-- Autor: QA & Data Architect
-- Objetivo: Permitir que employees inserten notificaciones via RPC (Security Definer)
-- ==============================================================================

-- ERROR DETECTADO:
-- Los empleados no tienen permiso INSERT en 'notification_queue'.
-- Al llamar al RPC, la transacción fallaba por violación de RLS.

-- SOLUCIÓN:
-- Marcar la función como SECURITY DEFINER para que se ejecute con privilegios del creador (postgres/service_role),
-- bypassendo las restricciones RLS del usuario que llama.

CREATE OR REPLACE FUNCTION public.solicitar_pase_diario(
  p_employee_id UUID,
  p_device_fingerprint TEXT
)
RETURNS JSON 
LANGUAGE plpgsql
SECURITY DEFINER -- <--- LA CLAVE DE LA SOLUCIÓN
SET search_path = public -- Buena práctica de seguridad para Security Definer
AS $$
DECLARE
  v_existing_pass public.daily_passes%ROWTYPE;
  v_pass_id UUID;
  v_store_id UUID;
  v_employee_name TEXT;
  v_store_owner_email TEXT;
BEGIN
  -- Obtener datos del empleado y su tienda para notificar
  SELECT e.store_id, e.name, s.email 
  INTO v_store_id, v_employee_name, v_store_owner_email
  FROM public.employees e
  JOIN public.stores s ON e.store_id = s.id
  WHERE e.id = p_employee_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Empleado no encontrado', 'code', 'EMP_NOT_FOUND');
  END IF;

  -- Lógica de Existencia (Idéntica a V1)
  SELECT * INTO v_existing_pass 
  FROM public.daily_passes 
  WHERE employee_id = p_employee_id AND pass_date = CURRENT_DATE;
  
  IF FOUND THEN
    IF v_existing_pass.status = 'approved' THEN
      RETURN json_build_object('success', true, 'status', 'approved', 'pass_id', v_existing_pass.id);
    END IF;
    IF v_existing_pass.status = 'pending' THEN
      IF v_existing_pass.retry_count >= 3 THEN
        RETURN json_build_object('success', false, 'error', 'Límite de intentos alcanzado', 'code', 'MAX_RETRIES');
      END IF;
      
      -- Update Retry
      UPDATE public.daily_passes 
      SET retry_count = retry_count + 1, 
          device_fingerprint = p_device_fingerprint,
          requested_at = now()
      WHERE id = v_existing_pass.id;
      
      -- RE-QUEUE Notification (Insistencia)
      INSERT INTO public.notification_queue (type, recipient_email, payload)
      VALUES (
        'daily_pass_request', 
        v_store_owner_email,
        json_build_object(
            'employee_name', v_employee_name,
            'device', p_device_fingerprint,
            'attempt', v_existing_pass.retry_count + 1,
            'pass_id', v_existing_pass.id
        )
      );

      RETURN json_build_object('success', true, 'status', 'pending', 'pass_id', v_existing_pass.id, 'retry_count', v_existing_pass.retry_count + 1);
    END IF;
    RETURN json_build_object('success', false, 'error', 'Estado desconocido', 'code', 'UNKNOWN_STATE');
  END IF;
  
  -- Insert New Pass
  INSERT INTO public.daily_passes (employee_id, device_fingerprint) 
  VALUES (p_employee_id, p_device_fingerprint) 
  RETURNING id INTO v_pass_id;

  -- QUEUE Notification (Nueva)
  INSERT INTO public.notification_queue (type, recipient_email, payload)
  VALUES (
    'daily_pass_request', 
    v_store_owner_email,
    json_build_object(
        'employee_name', v_employee_name,
        'device', p_device_fingerprint,
        'attempt', 1,
        'pass_id', v_pass_id
    )
  );

  RETURN json_build_object('success', true, 'status', 'pending', 'pass_id', v_pass_id);

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM, 'code', 'DB_ERROR');
END;
$$;

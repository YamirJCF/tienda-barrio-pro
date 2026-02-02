-- ==============================================================================
-- MIGRATION: SECURE_GATEKEEPER_BACKEND
-- Fecha: 2026-02-01
-- Autor: Data Architect Agent
-- Objetivo: Implementar lógica de servidor para FRD-001 (Pase Diario)
-- ==============================================================================

-- 1. Tabla de Cola de Notificaciones (System Resilience)
-- Permite desacoplar el envío de emails de la transacción principal
CREATE TABLE IF NOT EXISTS public.notification_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL, -- 'daily_pass_request', etc.
    recipient_email TEXT, -- Opcional si se deduce del contexto
    payload JSONB NOT NULL,
    status TEXT DEFAULT 'pending', -- pending, processing, sent, failed
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    processed_at TIMESTAMP WITH TIME ZONE,
    error_log TEXT
);

-- RLS: Solo el sistema (service_role) o admins deberían ver esto
ALTER TABLE public.notification_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view notifications" ON public.notification_queue
    FOR SELECT TO authenticated
    USING ( public.is_admin() ); -- Asumiendo funcion is_admin() o similar lógica

-- ==============================================================================
-- 2. RPC: Solicitar Pase Diario V2 (Con Notificación)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.solicitar_pase_diario(
  p_employee_id UUID,
  p_device_fingerprint TEXT
)
RETURNS JSON AS $$
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 3. RPC: Cerrar Caja V2 (Con Expiración de Pases)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.cerrar_caja(
  p_session_id UUID,
  p_actual_balance DECIMAL,
  p_employee_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_session public.cash_sessions%ROWTYPE;
  v_expected DECIMAL;
  v_ingresos DECIMAL;
  v_gastos DECIMAL;
  v_difference DECIMAL;
  v_store_id UUID;
BEGIN
  -- Validaciones V1
  SELECT * INTO v_session FROM public.cash_sessions WHERE id = p_session_id;
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Sesión no encontrada', 'code', 'SESSION_NOT_FOUND');
  END IF;
  IF v_session.status = 'closed' THEN
    RETURN json_build_object('success', false, 'error', 'La caja ya está cerrada', 'code', 'ALREADY_CLOSED');
  END IF;
  
  v_store_id := v_session.store_id;

  -- Cálculos V1
  SELECT COALESCE(SUM(amount), 0) INTO v_ingresos FROM public.cash_movements WHERE session_id = p_session_id AND movement_type = 'ingreso';
  SELECT COALESCE(SUM(amount), 0) INTO v_gastos FROM public.cash_movements WHERE session_id = p_session_id AND movement_type = 'gasto';
  
  v_expected := v_session.opening_balance + v_ingresos - v_gastos;
  v_difference := v_expected - p_actual_balance;
  
  -- Update Session
  UPDATE public.cash_sessions 
  SET closed_by = p_employee_id, 
      expected_balance = v_expected, 
      actual_balance = p_actual_balance, 
      difference = v_difference, 
      status = 'closed', 
      closed_at = now() 
  WHERE id = p_session_id;
  
  -- ==========================================================================
  -- NUEVO: Expiración de Pases Diarios (FRD-001 Regla 3)
  -- Invalidar pases 'approved' o 'pending' de empleados de la MISMA tienda
  -- ==========================================================================
  UPDATE public.daily_passes dp
  SET status = 'expired',
      resolved_at = now(),
      resolved_by = p_employee_id -- Audit: Quién cerró la caja expiró los pases
  FROM public.employees e
  WHERE dp.employee_id = e.id
    AND e.store_id = v_store_id
    AND dp.pass_date = CURRENT_DATE
    AND dp.status IN ('approved', 'pending');
    
  RETURN json_build_object(
    'success', true, 
    'expected_balance', v_expected, 
    'actual_balance', p_actual_balance, 
    'difference', v_difference,
    'message', 'Caja cerrada y pases diarios expirados.'
  );

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 4. Helper RPC: Check Status (For Frontend Polling)
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.check_daily_pass_status(
  p_employee_id UUID,
  p_device_fingerprint TEXT
)
RETURNS JSON AS $$
DECLARE
  v_pass public.daily_passes%ROWTYPE;
BEGIN
  SELECT * INTO v_pass 
  FROM public.daily_passes 
  WHERE employee_id = p_employee_id 
    AND pass_date = CURRENT_DATE
  ORDER BY requested_at DESC 
  LIMIT 1;
  
  IF NOT FOUND THEN
    RETURN json_build_object('status', 'none'); -- No ha solicitado hoy
  END IF;
  
  -- Si el fingerprint cambió, podría ser sospechoso, pero por ahora devolvemos el estado del pase
  RETURN json_build_object(
    'status', v_pass.status,
    'pass_id', v_pass.id,
    'retry_count', v_pass.retry_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

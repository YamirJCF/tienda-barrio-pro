-- ==============================================================================
-- MIGRATION: FIX_APPROVAL_RECEPTION_LAG
-- Fecha: 2026-02-01
-- Autor: QA & Data Architect
-- Objetivo: Sincronizar perfectamente la Aprobación (Admin) con la Recepción (Empleado)
-- ==============================================================================

-- 1. RPC: Aprobar Pase Diario (Robustez V2)
-- Asegura que el UPDATE se haga con permisos de sistema (SECURITY DEFINER)
-- para evitar fallos si el Admin no tiene rol de UPDATE explícito en RLS.
CREATE OR REPLACE FUNCTION public.aprobar_pase_diario(
  p_pass_id UUID,
  p_admin_id UUID
)
RETURNS JSON 
LANGUAGE plpgsql
SECURITY DEFINER -- Superpoderes activados
SET search_path = public
AS $$
BEGIN
  UPDATE public.daily_passes
  SET status = 'approved',
      resolved_by = p_admin_id,
      resolved_at = now()
  WHERE id = p_pass_id;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Pase no encontrado');
  END IF;

  RETURN json_build_object('success', true, 'status', 'approved');

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- 2. RPC: Check Status (Robustez V2 - Timezone Safe)
-- El problema anterior era "pass_date = CURRENT_DATE".
-- Si el servidor está en UTC y el cliente en -5, puede haber discrepancia cerca de la medianoche.
-- SOLUCIÓN: Buscar el último pase solicitado en las últimas 24 horas.
CREATE OR REPLACE FUNCTION public.check_daily_pass_status(
  p_employee_id UUID,
  p_device_fingerprint TEXT
)
RETURNS JSON 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pass public.daily_passes%ROWTYPE;
BEGIN
  SELECT * INTO v_pass 
  FROM public.daily_passes 
  WHERE employee_id = p_employee_id 
    -- Buscamos solicitudes recientes (ventana de 24h) en lugar de fecha estricta
    AND requested_at > (now() - interval '24 hours')
  ORDER BY requested_at DESC 
  LIMIT 1;
  
  IF NOT FOUND THEN
    RETURN json_build_object('status', 'none');
  END IF;
  
  RETURN json_build_object(
    'status', v_pass.status,
    'pass_id', v_pass.id,
    'retry_count', v_pass.retry_count
  );
END;
$$;

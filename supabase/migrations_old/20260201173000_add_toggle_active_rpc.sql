-- =============================================
-- RPC: Activar/Desactivar Empleado (Seguro)
-- FRD: FRD_003 + Protocolo HSP
-- Valida límite de 5 empleados activos antes de activar
-- =============================================
CREATE OR REPLACE FUNCTION public.toggle_empleado_activo(
  p_employee_id UUID,
  p_new_status BOOLEAN
)
RETURNS JSON AS $$
DECLARE
  v_store_id UUID;
  v_count INTEGER;
  v_current_status BOOLEAN;
BEGIN
  -- 1. Validar existencia y obtener contexto
  SELECT store_id, is_active INTO v_store_id, v_current_status
  FROM public.employees
  WHERE id = p_employee_id;

  IF NOT FOUND THEN
     RETURN json_build_object('success', false, 'error', 'Empleado no encontrado', 'code', 'EMPLOYEE_NOT_FOUND');
  END IF;

  -- 2. Security Check: Validar autorización (RLS manual)
  IF v_store_id != public.get_current_store_id() THEN
     RETURN json_build_object('success', false, 'error', 'No autorizado', 'code', 'UNAUTHORIZED');
  END IF;

  -- 3. Si se intenta activar (false -> true), validar límite
  IF p_new_status = true AND v_current_status = false THEN
      SELECT COUNT(*) INTO v_count
      FROM public.employees
      WHERE store_id = v_store_id AND is_active = true;

      IF v_count >= 5 THEN
         RETURN json_build_object(
           'success', false, 
           'error', 'Límite de empleados activos (5) alcanzado. Desactive otro usuario primero.', 
           'code', 'LIMIT_REACHED'
         );
      END IF;
  END IF;

  -- 4. Ejecutar cambio
  UPDATE public.employees
  SET 
    is_active = p_new_status,
    updated_at = now()
  WHERE id = p_employee_id;

  RETURN json_build_object('success', true, 'new_status', p_new_status);

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM,
    'code', 'TOGGLE_ERROR'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

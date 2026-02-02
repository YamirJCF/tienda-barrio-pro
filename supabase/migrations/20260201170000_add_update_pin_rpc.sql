-- =============================================
-- RPC: Actualizar PIN de Empleado (Seguro)
-- Feature: Permitir cambio de PIN desde Admin
-- =============================================
CREATE OR REPLACE FUNCTION public.actualizar_pin_empleado(
  p_employee_id UUID,
  p_new_pin TEXT
)
RETURNS JSON AS $$
DECLARE
  v_store_id UUID;
BEGIN
  -- 1. Validar que el empleado existe
  SELECT store_id INTO v_store_id
  FROM public.employees
  WHERE id = p_employee_id;

  IF NOT FOUND THEN
     RETURN json_build_object('success', false, 'error', 'Empleado no encontrado', 'code', 'EMPLOYEE_NOT_FOUND');
  END IF;

  -- 2. Security Check: Validar autorización (RLS manual)
  -- El usuario autenticado debe pertenecer a la misma tienda
  IF v_store_id != public.get_current_store_id() THEN
     RETURN json_build_object('success', false, 'error', 'No autorizado para modificar empleados de otra tienda', 'code', 'UNAUTHORIZED');
  END IF;

  -- 3. Update PIN (Hasheado)
  UPDATE public.employees
  SET 
    pin_hash = crypt(p_new_pin, gen_salt('bf')),
    updated_at = now()
  WHERE id = p_employee_id;

  RETURN json_build_object('success', true);

EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM,
    'code', 'UPDATE_PIN_ERROR'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

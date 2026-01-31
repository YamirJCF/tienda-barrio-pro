-- =============================================
-- MIGRATION: FIX PRODUCTS RLS
-- Fecha: 2026-01-31
-- Descripción: Unifica las políticas RLS de productos
-- aprovechando la nueva arquitectura "Admin es Empleado".
-- =============================================

-- 1. Habilitar RLS (por seguridad, aunque ya debería estarlo)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- 2. Limpiar políticas antiguas (Evitar conflictos)
DROP POLICY IF EXISTS "products_select_own" ON public.products;
DROP POLICY IF EXISTS "products_insert_own" ON public.products;
DROP POLICY IF EXISTS "products_update_own" ON public.products;
DROP POLICY IF EXISTS "products_delete_own" ON public.products;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.products;
DROP POLICY IF EXISTS "Enable insert for authentication users only" ON public.products;
DROP POLICY IF EXISTS "Enable update for users based on email" ON public.products;

-- 3. Crear Política Unificada
-- Lógica: "Un usuario puede ver/editar productos SÓLO si pertenecen a SU tienda actual"
-- Nota: Como el Admin ahora tiene registro en 'employees', esta consulta sirve para ambos roles.

CREATE POLICY "products_policy_unified"
ON public.products
FOR ALL
USING (
  store_id IN (
    SELECT store_id 
    FROM public.employees 
    WHERE id = auth.uid()
  )
)
WITH CHECK (
  store_id IN (
    SELECT store_id 
    FROM public.employees 
    WHERE id = auth.uid()
  )
);

-- 4. Verificación (Opcional)
-- Esta política cubre SELECT, INSERT, UPDATE, DELETE automáticamente.

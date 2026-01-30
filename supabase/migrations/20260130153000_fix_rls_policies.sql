-- =============================================
-- MIGRATION: FIX RLS POLICIES (Schema V2)
-- Fecha: 2026-01-30
-- Autor: @[/qa]
-- Descripción: Corrige las políticas RLS que dependían de un claim 'store_id' inexistente en el JWT.
-- Ahora se valida directamente contra la tabla admin_profiles usando auth.uid().
-- =============================================

-- 1. Deshabilitar RLS temporalmente (Opcional, pero seguro para aplicar cambios)
-- (No necesario si dropeamos y creamos)

-- -------------------------------------------------------------
-- TABLA: ADMIN_PROFILES
-- -------------------------------------------------------------
DROP POLICY IF EXISTS "admin_profiles_select_own" ON public.admin_profiles;

-- Nueva Política: "Un usuario puede ver SU propio perfil de admin"
CREATE POLICY "admin_profiles_select_own"
ON public.admin_profiles
FOR SELECT
USING (id = auth.uid());


-- -------------------------------------------------------------
-- TABLA: STORES
-- -------------------------------------------------------------
DROP POLICY IF EXISTS "stores_select_own" ON public.stores;

-- Nueva Política: "Un usuario puede ver la tienda si tiene un admin_profile asociado a ella"
CREATE POLICY "stores_select_own"
ON public.stores
FOR SELECT
USING (
  id IN (
    SELECT store_id 
    FROM public.admin_profiles 
    WHERE id = auth.uid()
  )
);

-- Nota: Mantenemos la política antigua de owner_id para compatibilidad con datos legacy si fuera necesario,
-- o la incluimos en el OR. Pero dado que estamos migrando a V2, la anterior es más robusta.

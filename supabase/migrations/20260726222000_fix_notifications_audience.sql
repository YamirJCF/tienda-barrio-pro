-- ==============================================================================
-- MIGRATION: FIX NOTIFICATIONS AUDIENCE RLS
-- Propósito: Cierra una fuga de datos. La política anterior permitía que 
-- cualquier usuario de la tienda viera todas las notificaciones de la misma.
-- Esta migración fuerza el filtro por la columna `audience`.
-- ==============================================================================

DROP POLICY IF EXISTS "Users can view store notifications" ON public.notifications;

CREATE POLICY "Users can view store notifications" ON public.notifications
FOR SELECT USING (
    store_id = public.get_current_store_id()
    AND (
        audience = 'all'
        OR (audience = 'admin' AND EXISTS (
            SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()
        ))
        OR (audience = 'employee' AND EXISTS (
            SELECT 1 FROM public.employees WHERE id = auth.uid()
        ))
    )
);

DROP POLICY IF EXISTS "Users can update own store notifications" ON public.notifications;

CREATE POLICY "Users can update own store notifications" ON public.notifications
FOR UPDATE USING (
    store_id = public.get_current_store_id()
    AND (
        audience = 'all'
        OR (audience = 'admin' AND EXISTS (
            SELECT 1 FROM public.admin_profiles WHERE id = auth.uid()
        ))
        OR (audience = 'employee' AND EXISTS (
            SELECT 1 FROM public.employees WHERE id = auth.uid()
        ))
    )
) WITH CHECK (
    store_id = public.get_current_store_id()
);

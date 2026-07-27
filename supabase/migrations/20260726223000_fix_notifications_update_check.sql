-- ==============================================================================
-- MIGRATION: FIX NOTIFICATIONS UPDATE CHECK
-- Propósito: Restringe el WITH CHECK de la política de UPDATE para evitar 
-- que un usuario modifique el valor de la columna `audience` hacia uno
-- al que no tiene acceso, evitando una fuga/manipulación de datos.
-- ==============================================================================

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

-- ==============================================================================
-- MIGRATION: CREATE NOTIFICATIONS TABLE
-- Propósito: Resuelve BUG-005. Crea la tabla `public.notifications` con las 
-- columnas exactas esperadas por `bridge_movement_to_batch` y 
-- `rpc_check_and_force_close_shifts`, evitando rollbacks silenciosos 
-- y permitiendo la trazabilidad de eventos clave para administradores.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
    type TEXT NOT NULL,         
    title TEXT NOT NULL,        
    message TEXT NOT NULL,
    audience TEXT NOT NULL,     
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb 
);

-- Índices de Rendimiento
CREATE INDEX idx_notifications_store ON public.notifications(store_id);
CREATE INDEX idx_notifications_audience ON public.notifications(audience);

-- Seguridad (RLS)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view store notifications"
ON public.notifications FOR SELECT
USING (store_id = public.get_current_store_id());

CREATE POLICY "Users can update own store notifications"
ON public.notifications FOR UPDATE
USING (store_id = public.get_current_store_id())
WITH CHECK (store_id = public.get_current_store_id());

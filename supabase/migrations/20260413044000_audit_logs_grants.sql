-- ==============================================================================
-- MIGRATION: ADD GRANTS TO AUDIT LOGS
-- Soluciona el error 403 Forbidden configurando los permisos de Postgres/PostgREST
-- para los roles autenticados, perdidos durante la consolidación.
-- ==============================================================================

GRANT ALL ON public.audit_logs TO authenticated;
GRANT ALL ON public.audit_logs TO anon;
GRANT ALL ON public.audit_logs TO service_role;

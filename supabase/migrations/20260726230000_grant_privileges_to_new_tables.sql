-- ==============================================================================
-- MIGRATION: GRANT PRIVILEGES TO NEW TABLES (STRICT)
-- Propósito: Las tablas creadas por migraciones SQL puras no reciben 
-- privilegios automáticamente en Supabase Cloud. Esta migración asegura 
-- explícitamente que el rol `authenticated` tenga los permisos mínimos 
-- necesarios. Se excluye explícitamente a `anon` para no exponer 
-- superficie a usuarios no logueados, y se excluye `DELETE` para
-- mantener la inmutabilidad financiera.
-- ==============================================================================

-- Revocamos cualquier ALL previo por seguridad si la migración se re-ejecuta
REVOKE ALL ON TABLE public.notifications FROM anon, authenticated;
REVOKE ALL ON TABLE public.supplier_invoices FROM anon, authenticated;
REVOKE ALL ON TABLE public.inventory_movement_batches FROM anon, authenticated;

-- Otorgamos privilegios a service_role (Admin Supremo de Supabase)
GRANT ALL ON TABLE public.notifications TO service_role;
GRANT ALL ON TABLE public.supplier_invoices TO service_role;
GRANT ALL ON TABLE public.inventory_movement_batches TO service_role;

-- Privilegios Estrictos para Authenticated
GRANT SELECT, INSERT, UPDATE ON TABLE public.notifications TO authenticated;
-- supplier_invoices necesita INSERT (vía cascada) y UPDATE (vía pago/remanente)
GRANT SELECT, INSERT, UPDATE ON TABLE public.supplier_invoices TO authenticated;
-- inventory_movement_batches solo necesita INSERT (vía cascada) y SELECT
GRANT SELECT, INSERT ON TABLE public.inventory_movement_batches TO authenticated;

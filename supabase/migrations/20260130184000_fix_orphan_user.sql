-- =============================================
-- REMEDIATION: FIX ORPHANED USER PROFILE
-- Fecha: 2026-01-30
-- Descripción: Inserta manualmente el perfil de administrador faltante para el usuario 'a267...'
-- que quedó huérfano tras el fallo del trigger de registro.
-- Esto desbloqueará inmediatamente su acceso (Fix 401).
-- =============================================

INSERT INTO public.admin_profiles (id, store_id, role, is_verified)
VALUES (
    'a267fedc-b3e1-4e9f-a1c3-08a757b3de86', -- Auth User ID (Nuevo Owner)
    '2017d2a6-b418-4614-9f02-8145a8434297', -- Store ID (Nueva Tienda MARIA)
    'owner',
    true
)
ON CONFLICT (id) DO NOTHING;

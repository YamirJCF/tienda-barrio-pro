-- 🛠️ REPAIR SCRIPT: Admin Employee Sync
-- Este script soluciona el error "Key (opened_by) is not present in table employees".
-- Crea un registro "espejo" en la tabla 'employees' para cada Dueño/Administrador.

INSERT INTO public.employees (
    id,             -- Mismo ID que el usuario Auth
    store_id,       -- Tienda del usuario
    name,           -- Nombre visible
    username,       -- Username interno
    role,           -- Rol especial
    pin_hash,       -- Hash temporal (se actualizará al configurar PIN)
    created_at,
    updated_at,
    display_name,
    is_active,
    permissions
)
SELECT 
    p.id,                                   -- Auth ID (UUID)
    p.store_id,                             -- ID Tienda
    'Propietario',                          -- Nombre por defecto
    'owner_' || substring(p.id::text from 1 for 8), -- Username único
    'owner',                                -- Rol
    '$2a$10$X7.G1.1.1.1.1.1.1.1.1.1.1.1.1.1.1.1.1.1.1.1.1.1.1', -- Dummy Hash (no usable para login, solo para existir)
    now(),
    now(),
    'Admin',
    true,
    '{"admin": true}'::jsonb
FROM public.admin_profiles p
LEFT JOIN public.employees e ON e.id = p.id
WHERE e.id IS NULL; -- Solo insertar si no existe

-- Verificación
SELECT id, name, role FROM public.employees WHERE role = 'owner';

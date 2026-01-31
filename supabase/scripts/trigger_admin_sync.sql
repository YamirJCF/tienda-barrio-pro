-- 🧠 trigger_admin_sync.sql (CORREGIDO V3)
-- AUTOMATIZACIÓN DE IDENTIDAD: Admin = Super Empleado
-- Versión 3: Sin columnas 'role' ni 'display_name' (Schema Real minimalista)

-- 1. Función Maestra de Sincronización
CREATE OR REPLACE FUNCTION public.sync_admin_to_employee()
RETURNS TRIGGER AS $$
BEGIN
    -- Insertar o Actualizar el registro de empleado del admin
    INSERT INTO public.employees (
        id,             -- Mismo UUID que Auth/Admin
        store_id,
        name,
        username,
        -- role,        -- ❌ REMOVIDO
        -- display_name, -- ❌ REMOVIDO: No existe en la tabla actual
        pin_hash,       -- Hash dummy
        permissions,    -- ⚡ PERMISOS TOTALES (Superuser)
        is_active,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        NEW.store_id,
        'Propietario',          -- Se usa en 'name'
        'owner_' || substring(NEW.id::text from 1 for 8),
        -- 'owner',
        -- 'Admin',
        '$2a$10$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX', -- Hash placeholder
        jsonb_build_object(     -- 🛡️ Permisos Totales
            'canSell', true,
            'canFiar', true,
            'canViewInventory', true,
            'canViewReports', true,
            'canOpenCloseCash', true, -- Fundamental
            'canManageInventory', true,
            'canManageClients', true,
            'isSuperAdmin', true      -- Flag lógico
        ),
        true, -- Siempre activo
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        permissions = jsonb_build_object(
            'canSell', true,
            'canFiar', true,
            'canViewInventory', true,
            'canViewReports', true,
            'canOpenCloseCash', true,
            'canManageInventory', true,
            'canManageClients', true,
            'isSuperAdmin', true
        ),
        store_id = EXCLUDED.store_id,
        updated_at = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Trigger en admin_profiles
DROP TRIGGER IF EXISTS on_admin_created_sync_employee ON public.admin_profiles;

CREATE TRIGGER on_admin_created_sync_employee
AFTER INSERT OR UPDATE ON public.admin_profiles
FOR EACH ROW
EXECUTE FUNCTION public.sync_admin_to_employee();

-- 3. MEDICINA RETROACTIVA: Ejecutar para admins existentes
INSERT INTO public.employees (
    id, store_id, name, username, pin_hash, permissions, is_active
)
SELECT 
    id, 
    store_id, 
    'Propietario', -- name
    'owner_' || substring(id::text from 1 for 8), 
    '$2a$10$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
    jsonb_build_object(
        'canSell', true, 
        'canOpenCloseCash', true,
        'canViewReports', true,
        'isSuperAdmin', true
    ), 
    true
FROM public.admin_profiles
ON CONFLICT (id) DO UPDATE SET
    permissions = jsonb_build_object(
        'canSell', true, 
        'canOpenCloseCash', true,
        'canViewReports', true,
        'isSuperAdmin', true
    ),
    is_active = true;

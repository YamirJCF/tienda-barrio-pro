-- ==============================================================================
-- MIGRATION: FIX REGISTRATION TRIGGER (DEFINITIVE)
-- Date: 2026-02-10
-- 
-- ROOT CAUSE (Traceable Evidence):
-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │ Error: P0001 - ATOMIC REGISTRATION FAILED: column "username" of relation  │
-- │        "employees" does not exist                                         │
-- │ Source: Supabase Auth API POST /auth/v1/signup returned 500               │
-- │                                                                           │
-- │ CASCADE CHAIN:                                                            │
-- │   1. auth.users INSERT (Supabase signUp)                                  │
-- │   2. → trigger on_auth_user_created → handle_new_user_atomic()            │
-- │   3.   → INSERT INTO stores ✅                                            │
-- │   4.   → INSERT INTO admin_profiles ✅                                    │
-- │   5.     → trigger on_admin_created_sync_employee                         │
-- │   6.       → sync_admin_to_employee()                                     │
-- │   7.         → INSERT INTO employees(username) ❌ CRASH                   │
-- │                                                                           │
-- │ The column "username" was renamed to "alias" in migration:                │
-- │   20260202160000_implement_zero_auth_strategy.sql                         │
-- │ But sync_admin_to_employee() was never updated to match.                  │
-- └─────────────────────────────────────────────────────────────────────────────┘
--
-- FIX: Update sync_admin_to_employee() to use 'alias' instead of 'username'
-- ==============================================================================

-- Fix the cascading trigger function that references the old column name
CREATE OR REPLACE FUNCTION public.sync_admin_to_employee()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.employees (
        id,
        store_id,
        name,
        alias,          -- ← FIX: was 'username', renamed to 'alias'
        pin_hash,
        permissions,
        is_active,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        NEW.store_id,
        'Propietario',
        'owner_' || substring(NEW.id::text from 1 for 8),
        '$2a$10$XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
        jsonb_build_object(
            'canSell', true,
            'canFiar', true,
            'canViewInventory', true,
            'canViewReports', true,
            'canOpenCloseCash', true,
            'canManageInventory', true,
            'canManageClients', true,
            'isSuperAdmin', true
        ),
        true,
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

-- MIGRATION: FIX DAILY PASSES RLS
-- Objective: Allow Admins to see "daily_passes" so they can revoke them.
-- Root Cause: Admin UI was empty because no policy allowed SELECT on this table for Admins.

BEGIN;

-- 1. Ensure RLS is enabled
ALTER TABLE public.daily_passes ENABLE ROW LEVEL SECURITY;

-- 2. Policy for Admins (View All in Store)
DROP POLICY IF EXISTS "Admins can view store daily passes" ON public.daily_passes;

CREATE POLICY "Admins can view store daily passes"
ON public.daily_passes
FOR SELECT
USING (
    -- Option A: Direct Store ID check (Faster, if column exists and is populated)
    store_id IN (
        SELECT store_id FROM public.admin_profiles WHERE id = auth.uid()
    )
    OR
    -- Option B: Join via Employee (Robust fallback if store_id is null on old rows)
    EXISTS (
        SELECT 1 FROM public.employees e
        WHERE e.id = daily_passes.employee_id
        AND e.store_id IN (SELECT store_id FROM public.admin_profiles WHERE id = auth.uid())
    )
);

-- 3. Policy for Admins (Update/Revoke)
-- Needed for the "Reject" button to work (Update status='rejected')
DROP POLICY IF EXISTS "Admins can update store daily passes" ON public.daily_passes;

CREATE POLICY "Admins can update store daily passes"
ON public.daily_passes
FOR UPDATE
USING (
    store_id IN (
        SELECT store_id FROM public.admin_profiles WHERE id = auth.uid()
    )
    OR
    EXISTS (
        SELECT 1 FROM public.employees e
        WHERE e.id = daily_passes.employee_id
        AND e.store_id IN (SELECT store_id FROM public.admin_profiles WHERE id = auth.uid())
    )
);

-- 4. Policy for Employees (View Own)
DROP POLICY IF EXISTS "Employees can view own passes" ON public.daily_passes;

CREATE POLICY "Employees can view own passes"
ON public.daily_passes
FOR SELECT
USING (
    employee_id = auth.uid() 
    -- Note: auth.uid() for employee is their ID in auth.users? 
    -- Actually, in our architecture, Employee uses Anonymous Auth linked to Employee ID?
    -- No, currently employees login via 'request_employee_access' which returns a custom token or uses Anon.
    -- If using Anon, auth.uid() is the anon user ID.
    -- Check how `request_employee_access` works. It creates a pass. 
    -- The frontend polls `check_my_pass_status` which is SECURITY DEFINER, so this policy might not be strictly needed for polling
    -- BUT it is good practice.
    -- HOWEVER, if Employee is Anon, they don't match `employee_id` (which is a UUID from employees table).
    -- So we leave this restricted for now or rely on the RPC `check_my_pass_status`.
);

COMMIT;

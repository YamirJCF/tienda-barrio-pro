-- Fix Suppliers RLS Policy
-- QAR Issue #1: Restrict supplier management to admins only
-- Date: 2026-02-09
-- Priority: CRITICAL
-- Note: Admins are in admin_profiles table, employees in employees table

-- =============================================================================
-- Drop existing permissive policy
-- =============================================================================
DROP POLICY IF EXISTS "Admins can manage suppliers" ON public.suppliers;

-- =============================================================================
-- Create restrictive policy checking admin_profiles
-- =============================================================================
CREATE POLICY "Only admins can manage suppliers"
ON public.suppliers FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.admin_profiles 
        WHERE id = auth.uid() 
        AND store_id = suppliers.store_id
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.admin_profiles 
        WHERE id = auth.uid() 
        AND store_id = suppliers.store_id
    )
);

-- =============================================================================
-- Verification
-- =============================================================================
DO $$
BEGIN
  -- Check policy exists with correct name
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'suppliers' 
    AND policyname = 'Only admins can manage suppliers'
  ) THEN
    RAISE EXCEPTION 'Migration failed: RLS policy not created';
  END IF;
  
  RAISE NOTICE '[Migration 20260209171800] SUCCESS: Suppliers RLS policy restricted to admins only';
END $$;

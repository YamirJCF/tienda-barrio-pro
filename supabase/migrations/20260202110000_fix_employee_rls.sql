-- MIGRATION: FIX DATA ISOLATION FOR EMPLOYEES
-- Description: Employees were unable to see Store Data because RLS only checked admin_profiles.
-- Authors: @[/architect] & @[/qa]

BEGIN;

-- 1. FIX STORES VISIBILITY
-- Policy: "I can see the Store if I own it OR if I work there"
DROP POLICY IF EXISTS "stores_select_own" ON public.stores;

CREATE POLICY "stores_select_own"
ON public.stores
FOR SELECT
USING (
  -- Case A: I am the Admin Owner
  id IN (SELECT store_id FROM public.admin_profiles WHERE id = auth.uid())
  OR 
  -- Case B: I am an Employee Working there
  id IN (SELECT store_id FROM public.employees WHERE id = auth.uid())
);

-- 2. FIX PRODUCTS VISIBILITY
-- Policy: "I can see products if they belong to a store I have access to"
DROP POLICY IF EXISTS "products_select_policy" ON public.products;

CREATE POLICY "products_select_policy"
ON public.products
FOR SELECT
USING (
  -- Product's Store must be one I manage (Admin) or work at (Employee)
  store_id IN (
    SELECT store_id FROM public.admin_profiles WHERE id = auth.uid()
    UNION
    SELECT store_id FROM public.employees WHERE id = auth.uid()
  )
);

-- 3. FIX CASH SESSION VISIBILITY
-- Policy: "I can see the active cash session of my store"
DROP POLICY IF EXISTS "cash_sessions_select_policy" ON public.cash_sessions;

CREATE POLICY "cash_sessions_select_policy"
ON public.cash_sessions
FOR SELECT
USING (
  store_id IN (
    SELECT store_id FROM public.admin_profiles WHERE id = auth.uid()
    UNION
    SELECT store_id FROM public.employees WHERE id = auth.uid()
  )
);

-- 4. FIX CASH MOVEMENTS VISIBILITY (To see history of the session)
DROP POLICY IF EXISTS "cash_movements_select_policy" ON public.cash_movements;

CREATE POLICY "cash_movements_select_policy"
ON public.cash_movements
FOR SELECT
USING (
  -- Join via session -> store
  session_id IN (
     SELECT id FROM public.cash_sessions 
     WHERE store_id IN (
        SELECT store_id FROM public.admin_profiles WHERE id = auth.uid()
        UNION
        SELECT store_id FROM public.employees WHERE id = auth.uid()
     )
  )
);

COMMIT;

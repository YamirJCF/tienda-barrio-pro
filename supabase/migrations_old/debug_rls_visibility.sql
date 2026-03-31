-- DIAGNOSTIC: RLS VISIBILITY FOR EMPLOYEE
-- Target: Employee ID ea8577fd-eef6-4900-8b20-fdd36c9cf6f0 (Pedro)

BEGIN;

-- 1. Switch to Authenticated Role to simulate RLS
SET LOCAL ROLE authenticated;
-- 2. Mock JWT (Crucial to trigger auth.uid())
-- Note: We can't easily mock auth.uid() in raw SQL without pgsodium/logic, 
-- but we can verify the policies logic manually.

-- 2a. Check if Employee exists and has Store ID
SELECT id, name, store_id FROM public.employees 
WHERE id = 'ea8577fd-eef6-4900-8b20-fdd36c9cf6f0';

-- 2b. Check if that Store has Products
SELECT count(*) as total_products, store_id 
FROM public.products 
WHERE store_id = (SELECT store_id FROM public.employees WHERE id = 'ea8577fd-eef6-4900-8b20-fdd36c9cf6f0')
GROUP BY store_id;

-- 3. ANALYSIS OF POLICY "products_select_policy" (Hypothetical)
-- Policy usually says: store_id IN (SELECT store_id FROM admin_profiles WHERE id = auth.uid())
-- PROBLEM: Employee auth.uid() is NOT in admin_profiles.

-- 4. Check if there is an "Employee Policy" for products
SELECT * FROM pg_policies WHERE tablename = 'products';

ROLLBACK;

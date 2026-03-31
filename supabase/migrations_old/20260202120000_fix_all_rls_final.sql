-- MIGRATION: FIX ALL RLS POLICIES FOR EMPLOYEES (FINAL)
-- Description: Grant Employees access to Sales, Clients, Expenses, etc.
-- Authors: @[/architect] & @[/qa]

BEGIN;

-- 1. FIX SALES VISIBILITY
DROP POLICY IF EXISTS "sales_select_policy" ON public.sales;

CREATE POLICY "sales_select_policy"
ON public.sales
FOR SELECT
USING (
  store_id IN (
    SELECT store_id FROM public.admin_profiles WHERE id = auth.uid()
    UNION
    SELECT store_id FROM public.employees WHERE id = auth.uid()
  )
);

-- 2. FIX SALE ITEMS VISIBILITY
DROP POLICY IF EXISTS "sale_items_select_policy" ON public.sale_items;

CREATE POLICY "sale_items_select_policy"
ON public.sale_items
FOR SELECT
USING (
  sale_id IN (
    SELECT id FROM public.sales
    WHERE store_id IN (
        SELECT store_id FROM public.admin_profiles WHERE id = auth.uid()
        UNION
        SELECT store_id FROM public.employees WHERE id = auth.uid()
    )
  )
);

-- 3. FIX CLIENTS VISIBILITY
DROP POLICY IF EXISTS "clients_select_policy" ON public.clients;

CREATE POLICY "clients_select_policy"
ON public.clients
FOR SELECT
USING (
  store_id IN (
    SELECT store_id FROM public.admin_profiles WHERE id = auth.uid()
    UNION
    SELECT store_id FROM public.employees WHERE id = auth.uid()
  )
);

-- 4. FIX EXPENSES VISIBILITY (If exists as separate table)
-- Check if table exists first to avoid error
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'expenses') THEN
        DROP POLICY IF EXISTS "expenses_select_policy" ON public.expenses;
        CREATE POLICY "expenses_select_policy" ON public.expenses FOR SELECT USING (
            store_id IN (
                SELECT store_id FROM public.admin_profiles WHERE id = auth.uid()
                UNION
                SELECT store_id FROM public.employees WHERE id = auth.uid()
            )
        );
    END IF;
END
$$;

COMMIT;

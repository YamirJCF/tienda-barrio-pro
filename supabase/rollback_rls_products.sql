-- ROLLBACK SCRIPT: Recreate dropped RLS policies on products table
-- Generated: 2026-02-17 QA Audit
-- Use this script ONLY if product reading breaks after policy cleanup

-- Restore products_select_policy (uses is_store_member)
CREATE POLICY "products_select_policy" ON products
  FOR SELECT
  USING (is_store_member(store_id));

-- Restore products_policy_unified (uses employees join)
CREATE POLICY "products_policy_unified" ON products
  FOR ALL
  USING (store_id IN (SELECT employees.store_id FROM employees WHERE employees.id = auth.uid()))
  WITH CHECK (store_id IN (SELECT employees.store_id FROM employees WHERE employees.id = auth.uid()));
